#if canImport(Metal)
import Foundation
import Metal

public final class MetalProofPlanner: @unchecked Sendable {
    public let context: MetalContext
    public let planDatabase: PlanDatabase?
    public let protocolHash: String

    public init(
        context: MetalContext,
        planDatabase: PlanDatabase? = nil,
        protocolHash: String = "unversioned"
    ) {
        self.context = context
        self.planDatabase = planDatabase
        self.protocolHash = protocolHash
    }

    public func tuneMerkleCommitExecutionPlan(
        leaves: Data,
        leafCount: Int,
        leafStride: Int,
        leafBytes: Int,
        configuration: TuningConfiguration = .default
    ) throws -> MerkleTuningResult {
        guard leafCount > 0, leafCount.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidLeafCount(leafCount)
        }
        let declaredLeafBytes = try checkedBufferLength(leafCount, leafStride)
        guard leafBytes >= 0,
              leafBytes <= SHA3Oracle.sha3_256Rate,
              leafStride >= leafBytes,
              leaves.count >= declaredLeafBytes else {
            throw AppleZKProverError.invalidInputLayout
        }

        let workload = merkleWorkload(
            leafCount: leafCount,
            leafBytes: leafBytes,
            roundsPerSuperstep: 1
        )
        let cpuRoot = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: leafCount,
            leafStride: leafStride,
            leafLength: leafBytes
        )
        let candidates = merkleCandidates(workload: workload, leafCount: leafCount)
            .sorted {
                heuristicScore($0, leafCount: leafCount, leafBytes: leafBytes)
                    > heuristicScore($1, leafCount: leafCount, leafBytes: leafBytes)
            }
            .prefix(configuration.maxCandidates)

        var measurements: [CandidateMeasurement] = []
        for candidate in candidates {
            guard let measurement = try measureMerkleCandidate(
                candidate,
                leaves: leaves,
                cpuRoot: cpuRoot,
                leafCount: leafCount,
                leafStride: leafStride,
                leafBytes: leafBytes,
                configuration: configuration
            ) else {
                continue
            }
            measurements.append(measurement)
        }

        guard let winner = measurements.min(by: Self.isBetterMerkleMeasurement) else {
            throw AppleZKProverError.invalidInputLayout
        }

        try validateMerkleWinnerForPersistence(
            winner.spec,
            workload: workload,
            leafCount: leafCount,
            leafStride: leafStride,
            leafBytes: leafBytes,
            declaredLeafBytes: declaredLeafBytes,
            validationBatches: configuration.randomizedValidationBatches
        )

        try persistMerkleRace(
            measurements: measurements,
            winner: winner,
            workload: workload
        )

        return MerkleTuningResult(
            executionPlan: makeMerklePlan(
                workload: workload,
                selected: winner.spec,
                leafCount: leafCount,
                leafBytes: leafBytes,
                leafStride: leafStride
            ),
            winner: winner.planRecord(
                device: context.deviceFingerprint,
                workload: workload,
                shaderHash: context.shaderSourceHash,
                protocolHash: protocolHash,
                winner: winner.spec
            ),
            measurements: measurements.map {
                $0.planRecord(
                    device: context.deviceFingerprint,
                    workload: workload,
                    shaderHash: context.shaderSourceHash,
                    protocolHash: protocolHash,
                    winner: winner.spec
                )
            }
        )
    }

    public func makeMerkleCommitExecutionPlan(
        leafCount: Int,
        leafBytes: Int,
        leafStride: Int,
        roundsPerSuperstep: UInt8 = 1
    ) throws -> ExecutionPlan {
        guard leafCount > 0, leafCount.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidLeafCount(leafCount)
        }
        guard leafBytes >= 0, leafStride >= leafBytes else {
            throw AppleZKProverError.invalidInputLayout
        }

        let workload = merkleWorkload(
            leafCount: leafCount,
            leafBytes: leafBytes,
            roundsPerSuperstep: roundsPerSuperstep
        )

        if let persisted = try planDatabase?.latestWinner(
            device: context.deviceFingerprint,
            workload: workload,
            shaderHash: context.shaderSourceHash,
            protocolHash: protocolHash
        ) {
            return makeMerklePlan(
                workload: workload,
                selected: persisted.winner,
                leafCount: leafCount,
                leafBytes: leafBytes,
                leafStride: leafStride
            )
        }

        let selected = try selectMerkleCandidate(
            workload: workload,
            leafCount: leafCount,
            leafBytes: leafBytes
        )
        return makeMerklePlan(
            workload: workload,
            selected: selected,
            leafCount: leafCount,
            leafBytes: leafBytes,
            leafStride: leafStride
        )
    }

    public func makePlannedMerkleCommitPlan(
        leafCount: Int,
        leafBytes: Int,
        leafStride: Int,
        driftPolicy: PlanDriftPolicy = .default
    ) throws -> MetalPlannedMerkleCommitPlan {
        guard leafCount > 0, leafCount.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidLeafCount(leafCount)
        }
        guard leafBytes >= 0,
              leafBytes <= SHA3Oracle.sha3_256Rate,
              leafStride >= leafBytes else {
            throw AppleZKProverError.invalidInputLayout
        }

        let workload = merkleWorkload(
            leafCount: leafCount,
            leafBytes: leafBytes,
            roundsPerSuperstep: 1
        )
        let persisted = try planDatabase?.latestWinner(
            device: context.deviceFingerprint,
            workload: workload,
            shaderHash: context.shaderSourceHash,
            protocolHash: protocolHash
        )
        let selected = try persisted?.winner ?? selectMerkleCandidate(
            workload: workload,
            leafCount: leafCount,
            leafBytes: leafBytes
        )
        let executionPlan = makeMerklePlan(
            workload: workload,
            selected: selected,
            leafCount: leafCount,
            leafBytes: leafBytes,
            leafStride: leafStride
        )
        let commitPlan = try SHA3RawLeavesMerkleCommitPlan(
            context: context,
            leafCount: leafCount,
            leafStride: leafStride,
            leafLength: leafBytes,
            configuration: merklePlanConfiguration(for: selected)
        )
        return MetalPlannedMerkleCommitPlan(
            commitPlan: commitPlan,
            executionPlan: executionPlan,
            planDatabase: planDatabase,
            persistedRecord: persisted,
            driftPolicy: driftPolicy
        )
    }

    public func merkleCandidates(
        workload: WorkloadSignature,
        leafCount: Int
    ) -> [KernelSpec] {
        let leafBytes = Int(workload.leafBytes)
        var candidates: [KernelSpec] = [
            KernelSpec(
                kernel: "sha3_256_merkle_parents_specialized",
                family: .scalar,
                queueMode: .metal3,
                functionConstants: .plannerConstants([
                    (.parentBytes, 32),
                    (.treeArity, 2),
                    (.fixedWidthCase, UInt64(workload.fixedWidthCase)),
                ])
            ),
        ]

        if leafBytes == 32,
           leafCount >= 8,
           leafCount.nonzeroBitCount == 1 {
            candidates.append(MerkleKernelSpecs.treelet32ByteLeaves(depth: 3))
        }

        if leafBytes == 32,
           leafCount >= 16,
           leafCount.nonzeroBitCount == 1,
           context.device.maxThreadgroupMemoryLength >= 16 * 32 {
            candidates.append(MerkleKernelSpecs.treelet32ByteLeaves(depth: 4))
        }

        if context.capabilities.supportsMetal4Queue {
            candidates += candidates.map {
                KernelSpec(
                    kernel: $0.kernel,
                    family: $0.family,
                    queueMode: .metal4,
                    functionConstants: $0.functionConstants,
                    threadsPerThreadgroup: $0.threadsPerThreadgroup,
                    simdgroupsPerThreadgroup: $0.simdgroupsPerThreadgroup
                )
            }
        }

        return candidates.filter { isFeasible($0) }
    }

    public func sumcheckCandidates(
        workload: WorkloadSignature
    ) -> [KernelSpec] {
        let scalar = KernelSpec(
            kernel: "sumcheck_scalar",
            family: .scalar,
            queueMode: .metal3,
            functionConstants: .plannerConstants([
                (.sumcheckMode, 0),
                (.barrierCadence, 1),
            ])
        )
        return [scalar].filter { isFeasible($0) }
    }

    public func makeSumcheckChunkExecutionPlan(
        laneCount: Int,
        roundsPerSuperstep: Int
    ) throws -> ExecutionPlan {
        let plan = try MetalSumcheckChunkPlan(
            context: context,
            descriptor: SumcheckChunkDescriptor(
                laneCount: laneCount,
                roundsPerSuperstep: roundsPerSuperstep
            )
        )
        return plan.executionPlan
    }

    public func makeSumcheckChunkPlan(
        laneCount: Int,
        roundsPerSuperstep: Int
    ) throws -> MetalSumcheckChunkPlan {
        try MetalSumcheckChunkPlan(
            context: context,
            descriptor: SumcheckChunkDescriptor(
                laneCount: laneCount,
                roundsPerSuperstep: roundsPerSuperstep
            )
        )
    }

    private func selectMerkleCandidate(
        workload: WorkloadSignature,
        leafCount: Int,
        leafBytes: Int
    ) throws -> KernelSpec {
        let candidates = merkleCandidates(workload: workload, leafCount: leafCount)
        guard let selected = candidates.sorted(by: {
            heuristicScore($0, leafCount: leafCount, leafBytes: leafBytes)
                > heuristicScore($1, leafCount: leafCount, leafBytes: leafBytes)
        }).first else {
            throw AppleZKProverError.invalidInputLayout
        }
        return selected
    }

    private func makeMerklePlan(
        workload: WorkloadSignature,
        selected: KernelSpec,
        leafCount: Int,
        leafBytes: Int,
        leafStride: Int
    ) -> ExecutionPlan {
        let scratchBytes = max(32, leafCount * 32)
        let arenaBytes = scratchBytes * 2 + 256
        let leafKernel = SHA3OneBlockKernel.spec(forInputLength: leafBytes)
        let kernels: [KernelSpec]
        if selected.family == .treelet {
            kernels = [selected, MerkleKernelSpecs.parent32x32(), MerkleKernelSpecs.fusedUpper32()]
        } else {
            kernels = [leafKernel, selected, MerkleKernelSpecs.fusedUpper32()]
        }

        return ExecutionPlan(
            workload: workload,
            queueMode: selected.queueMode,
            kernels: kernels,
            bufferLayout: ExecutionPlan.BufferLayout(
                uploadBytes: leafCount * leafStride,
                privateArenaBytes: arenaBytes,
                readbackBytes: 32
            ),
            commandBufferChunks: 1,
            readbackPoints: [.finalRoot]
        )
    }

    private func measureMerkleCandidate(
        _ candidate: KernelSpec,
        leaves: Data,
        cpuRoot: Data,
        leafCount: Int,
        leafStride: Int,
        leafBytes: Int,
        configuration: TuningConfiguration
    ) throws -> CandidateMeasurement? {
        let plan = try SHA3RawLeavesMerkleCommitPlan(
            context: context,
            leafCount: leafCount,
            leafStride: leafStride,
            leafLength: leafBytes,
            configuration: merklePlanConfiguration(for: candidate)
        )

        let gate = try plan.commitMeasured(leaves: leaves)
        guard gate.commitment.root == cpuRoot else {
            return nil
        }

        if configuration.warmupRuns > 0 {
            for _ in 0..<configuration.warmupRuns {
                let result = try plan.commitMeasured(leaves: leaves)
                guard result.commitment.root == cpuRoot else {
                    return nil
                }
            }
        }

        var gpuTimes: [Double] = []
        var cpuSubmitTimes: [Double] = []
        for _ in 0..<configuration.measuredRuns {
            let result = try plan.commitMeasured(leaves: leaves)
            guard result.commitment.root == cpuRoot else {
                return nil
            }
            let gpuNS = (result.commitment.stats.gpuSeconds ?? result.commitment.stats.cpuWallSeconds) * 1_000_000_000
            gpuTimes.append(gpuNS)
            cpuSubmitTimes.append(result.cpuSubmitNS)
        }

        return CandidateMeasurement(
            spec: candidate,
            medianGPUTimeNS: Self.median(gpuTimes),
            medianCPUSubmitNS: Self.median(cpuSubmitTimes),
            p95GPUTimeNS: Self.percentile95(gpuTimes),
            readbacks: 1,
            confidence: Self.confidence(measuredRuns: gpuTimes.count)
        )
    }

    private func persistMerkleRace(
        measurements: [CandidateMeasurement],
        winner: CandidateMeasurement,
        workload: WorkloadSignature
    ) throws {
        guard let planDatabase else {
            return
        }

        for measurement in measurements {
            let record = measurement.planRecord(
                device: context.deviceFingerprint,
                workload: workload,
                shaderHash: context.shaderSourceHash,
                protocolHash: protocolHash,
                winner: winner.spec
            )
            try planDatabase.recordRaceResult(
                PlanRaceResult(
                    record: record,
                    measuredSpec: measurement.spec,
                    isWinner: measurement.spec == winner.spec
                )
            )
        }
    }

    private func validateMerkleWinnerForPersistence(
        _ winner: KernelSpec,
        workload: WorkloadSignature,
        leafCount: Int,
        leafStride: Int,
        leafBytes: Int,
        declaredLeafBytes: Int,
        validationBatches: Int
    ) throws {
        guard validationBatches > 0 else {
            return
        }

        let plan = try SHA3RawLeavesMerkleCommitPlan(
            context: context,
            leafCount: leafCount,
            leafStride: leafStride,
            leafLength: leafBytes,
            configuration: merklePlanConfiguration(for: winner)
        )
        var generator = DeterministicByteGenerator(seed: validationSeed(workload: workload, winner: winner))

        for batch in 0..<validationBatches {
            let leaves = generator.makeData(byteCount: declaredLeafBytes)
            let cpuRoot = try MerkleOracle.rootSHA3_256(
                rawLeaves: leaves,
                leafCount: leafCount,
                leafStride: leafStride,
                leafLength: leafBytes
            )
            let gpuRoot = try plan.commitMeasured(leaves: leaves).commitment.root
            guard gpuRoot == cpuRoot else {
                throw AppleZKProverError.correctnessValidationFailed(
                    "Merkle winner \(winner.kernel) failed randomized validation batch \(batch)."
                )
            }
        }
    }

    private func merklePlanConfiguration(for candidate: KernelSpec) -> MerkleCommitPlanConfiguration {
        guard candidate.family == .treelet,
              let depth = candidate.functionConstants[PlannerFunctionConstant.treeletDepth.rawValue] else {
            return MerkleCommitPlanConfiguration(leafSubtreeMode: .disabled)
        }
        return MerkleCommitPlanConfiguration(leafSubtreeMode: .fixed(1 << Int(depth)))
    }

    private func merkleWorkload(
        leafCount: Int,
        leafBytes: Int,
        roundsPerSuperstep: UInt8
    ) -> WorkloadSignature {
        WorkloadSignature(
            stage: .merkleCommit,
            field: .bytes,
            inputLog2: UInt8(clamping: Self.log2(leafCount)),
            leafBytes: UInt16(clamping: leafBytes),
            arity: 2,
            roundsPerSuperstep: roundsPerSuperstep,
            fixedWidthCase: UInt16(clamping: fixedWidthCase(leafBytes))
        )
    }

    private func isFeasible(_ spec: KernelSpec) -> Bool {
        if spec.family == .simdgroup && !context.capabilities.supportsSIMDReductions {
            return false
        }
        if spec.queueMode == .metal4 && !context.capabilities.supportsMetal4Queue {
            return false
        }
        if spec.threadsPerThreadgroup > 0,
           Int(spec.threadsPerThreadgroup) > context.capabilities.maxThreadsPerThreadgroup {
            return false
        }
        if let depth = spec.functionConstants[PlannerFunctionConstant.treeletDepth.rawValue] {
            let scratchBytes = (1 << Int(depth)) * 32
            if scratchBytes > context.device.maxThreadgroupMemoryLength {
                return false
            }
        }
        return true
    }

    private func heuristicScore(_ spec: KernelSpec, leafCount: Int, leafBytes: Int) -> Int {
        var score = 0
        if leafBytes == 32 || leafBytes == 64 {
            score += 20
        }
        switch spec.family {
        case .scalar:
            score += leafCount < 256 || leafBytes == 0 ? 35 : 10
        case .simdgroup:
            score += context.capabilities.supportsSIMDReductions && (leafBytes == 32 || leafBytes == 64) ? 40 : -100
        case .treelet:
            score += leafBytes == 32 && leafCount >= 512 ? 60 : 15
        }
        if spec.queueMode == .metal4 {
            score += leafCount <= 4096 ? 5 : 0
        }
        return score
    }

    private func fixedWidthCase(_ leafBytes: Int) -> Int {
        switch leafBytes {
        case 32, 64, 128, 136:
            return leafBytes
        default:
            return 0
        }
    }

    private static func log2(_ value: Int) -> Int {
        var remaining = max(1, value)
        var result = 0
        while remaining > 1 {
            remaining >>= 1
            result += 1
        }
        return result
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else {
            return .infinity
        }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private static func percentile95(_ values: [Double]) -> Double {
        guard !values.isEmpty else {
            return .infinity
        }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)
        return sorted[index]
    }

    private static func confidence(measuredRuns: Int) -> Double {
        min(1, Double(measuredRuns) / 5)
    }

    private func validationSeed(workload: WorkloadSignature, winner: KernelSpec) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(context.deviceFingerprint.registryID)
        hasher.combine(context.deviceFingerprint.osBuild)
        hasher.combine(context.shaderSourceHash)
        hasher.combine(protocolHash)
        hasher.combine(workload)
        hasher.combine(winner)
        return UInt64(bitPattern: Int64(hasher.finalize())) ^ 0x9e37_79b9_7f4a_7c15
    }

    private static func isBetterMerkleMeasurement(
        _ lhs: CandidateMeasurement,
        than rhs: CandidateMeasurement
    ) -> Bool {
        let lhsObjective = lhs.medianGPUTimeNS + lhs.medianCPUSubmitNS
        let rhsObjective = rhs.medianGPUTimeNS + rhs.medianCPUSubmitNS
        if lhsObjective != rhsObjective {
            return lhsObjective < rhsObjective
        }
        return lhs.p95GPUTimeNS < rhs.p95GPUTimeNS
    }
}

public struct TuningConfiguration: Sendable {
    public var warmupRuns: Int
    public var measuredRuns: Int
    public var maxCandidates: Int
    public var randomizedValidationBatches: Int

    public init(
        warmupRuns: Int = 2,
        measuredRuns: Int = 5,
        maxCandidates: Int = 5,
        randomizedValidationBatches: Int = 3
    ) {
        self.warmupRuns = max(0, warmupRuns)
        self.measuredRuns = max(1, measuredRuns)
        self.maxCandidates = max(1, maxCandidates)
        self.randomizedValidationBatches = max(0, randomizedValidationBatches)
    }

    public static let `default` = TuningConfiguration()
}

public struct MerkleTuningResult: Sendable {
    public let executionPlan: ExecutionPlan
    public let winner: PlanRecord
    public let measurements: [PlanRecord]

    public init(executionPlan: ExecutionPlan, winner: PlanRecord, measurements: [PlanRecord]) {
        self.executionPlan = executionPlan
        self.winner = winner
        self.measurements = measurements
    }
}

public struct PlannedMerkleCommitment: Sendable {
    public let commitment: MerkleCommitment
    public let driftStatus: PlanDriftStatus?

    public init(commitment: MerkleCommitment, driftStatus: PlanDriftStatus?) {
        self.commitment = commitment
        self.driftStatus = driftStatus
    }
}

public final class MetalPlannedMerkleCommitPlan: @unchecked Sendable {
    public let executionPlan: ExecutionPlan
    public let persistedRecord: PlanRecord?

    private let commitPlan: SHA3RawLeavesMerkleCommitPlan
    private let planDatabase: PlanDatabase?
    private let driftPolicy: PlanDriftPolicy

    init(
        commitPlan: SHA3RawLeavesMerkleCommitPlan,
        executionPlan: ExecutionPlan,
        planDatabase: PlanDatabase?,
        persistedRecord: PlanRecord?,
        driftPolicy: PlanDriftPolicy
    ) {
        self.commitPlan = commitPlan
        self.executionPlan = executionPlan
        self.planDatabase = planDatabase
        self.persistedRecord = persistedRecord
        self.driftPolicy = driftPolicy
    }

    public func commit(leaves: Data) throws -> MerkleCommitment {
        try commitWithObservation(leaves: leaves).commitment
    }

    public func commitWithObservation(leaves: Data) throws -> PlannedMerkleCommitment {
        let measured = try commitPlan.commitMeasured(leaves: leaves)
        return try makeObservedCommitment(measured)
    }

    public func commitUploadedLeaves(
        buffer: MTLBuffer,
        offset: Int = 0
    ) throws -> PlannedMerkleCommitment {
        let measured = try commitPlan.commitMeasured(uploadBuffer: buffer, uploadOffset: offset)
        return try makeObservedCommitment(measured)
    }

    private func makeObservedCommitment(_ measured: MerkleCommitMeasurement) throws -> PlannedMerkleCommitment {
        let driftStatus: PlanDriftStatus?
        if let persistedRecord, let planDatabase {
            let gpuTimeNS = (measured.commitment.stats.gpuSeconds ?? measured.commitment.stats.cpuWallSeconds) * 1_000_000_000
            driftStatus = try planDatabase.recordLiveObservation(
                for: persistedRecord,
                gpuTimeNS: gpuTimeNS,
                cpuSubmitNS: measured.cpuSubmitNS,
                policy: driftPolicy
            )
        } else {
            driftStatus = nil
        }
        return PlannedMerkleCommitment(
            commitment: measured.commitment,
            driftStatus: driftStatus
        )
    }

    public func clearReusableBuffers() throws {
        try commitPlan.clearReusableBuffers()
    }
}

private struct CandidateMeasurement {
    let spec: KernelSpec
    let medianGPUTimeNS: Double
    let medianCPUSubmitNS: Double
    let p95GPUTimeNS: Double
    let readbacks: Int
    let confidence: Double

    func planRecord(
        device: DeviceFingerprint,
        workload: WorkloadSignature,
        shaderHash: String,
        protocolHash: String,
        winner: KernelSpec
    ) -> PlanRecord {
        PlanRecord(
            device: device,
            workload: workload,
            winner: winner,
            medianGPUTimeNS: medianGPUTimeNS,
            medianCPUSubmitNS: medianCPUSubmitNS,
            p95GPUTimeNS: p95GPUTimeNS,
            readbacks: readbacks,
            confidence: confidence,
            shaderHash: shaderHash,
            protocolHash: protocolHash
        )
    }
}

private struct DeterministicByteGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x243f_6a88_85a3_08d3 : seed
    }

    mutating func makeData(byteCount: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        var current: UInt64 = 0
        var remaining = 0

        for index in bytes.indices {
            if remaining == 0 {
                current = next()
                remaining = 8
            }
            bytes[index] = UInt8(truncatingIfNeeded: current)
            current >>= 8
            remaining -= 1
        }
        return Data(bytes)
    }

    private mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }
}
#endif
