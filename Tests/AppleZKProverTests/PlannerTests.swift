import XCTest
#if canImport(Metal)
import Metal
#endif
@testable import AppleZKProver

final class PlannerTests: XCTestCase {
    func testPlanDatabasePersistsLatestWinnerByWorkloadKey() throws {
        let url = temporaryDatabaseURL()
        let database = try PlanDatabase(url: url)
        let device = DeviceFingerprint(
            registryID: 123,
            name: "Test GPU",
            osBuild: "test-os",
            supportsApple4: true,
            supportsApple7: true,
            supportsApple9: false,
            supportsMetal4Queue: false,
            maxThreadsPerThreadgroup: 1024,
            hasUnifiedMemory: true
        )
        let workload = WorkloadSignature(
            stage: .merkleCommit,
            field: .bytes,
            inputLog2: 10,
            leafBytes: 32,
            arity: 2,
            roundsPerSuperstep: 1,
            fixedWidthCase: 32
        )
        let scalar = KernelSpec(
            kernel: "sha3_256_merkle_parents_specialized",
            family: .scalar,
            queueMode: .metal3,
            functionConstants: .plannerConstants([
                (.parentBytes, 32),
                (.treeArity, 2),
            ])
        )
        let treelet = MerkleKernelSpecs.treelet32ByteLeaves(depth: 3)
        let record = PlanRecord(
            device: device,
            workload: workload,
            winner: treelet,
            medianGPUTimeNS: 100,
            medianCPUSubmitNS: 10,
            p95GPUTimeNS: 120,
            readbacks: 1,
            confidence: 1,
            shaderHash: "shader",
            protocolHash: "protocol"
        )

        try database.recordRaceResult(PlanRaceResult(record: record, measuredSpec: scalar, isWinner: false))
        try database.recordRaceResult(PlanRaceResult(record: record, measuredSpec: treelet, isWinner: true))

        let persisted = try database.latestWinner(
            device: device,
            workload: workload,
            shaderHash: "shader",
            protocolHash: "protocol"
        )
        XCTAssertEqual(persisted?.winner, treelet)
        XCTAssertEqual(persisted?.medianGPUTimeNS, 100)
        XCTAssertNil(
            try database.latestWinner(
                device: device,
                workload: workload,
                shaderHash: "other-shader",
                protocolHash: "protocol"
            )
        )
    }

    func testPlanDatabaseMarksLiveObservationStaleAfterSustainedDrift() throws {
        let database = try PlanDatabase(url: temporaryDatabaseURL())
        let record = makePlanRecord(
            medianGPUTimeNS: 100,
            medianCPUSubmitNS: 10
        )
        let policy = PlanDriftPolicy(
            emaAlpha: 1,
            relativeThreshold: 0.25,
            minimumSamples: 2
        )

        let first = try database.recordLiveObservation(
            for: record,
            gpuTimeNS: 105,
            cpuSubmitNS: 10,
            policy: policy
        )
        XCTAssertEqual(first, .stable(sampleCount: 1, emaGPUTimeNS: 105, emaCPUSubmitNS: 10))

        let second = try database.recordLiveObservation(
            for: record,
            gpuTimeNS: 200,
            cpuSubmitNS: 20,
            policy: policy
        )
        guard case let .stale(sampleCount, relativeDrift) = second else {
            return XCTFail("Expected stale drift status, got \(second)")
        }
        XCTAssertEqual(sampleCount, 2)
        XCTAssertGreaterThan(relativeDrift, 0.25)
    }

    func testM31SumcheckCPUOracleRejectsNonCanonicalInput() throws {
        XCTAssertThrowsError(
            try SumcheckOracle.m31Chunk(
                evaluations: [0, M31Field.modulus],
                rounds: 1
            )
        )
    }

    func testTranscriptStateAbsorbsMultipleBlocks() throws {
        var transcript = SHA3Oracle.TranscriptState()
        let bytes = Data((0..<513).map { UInt8(truncatingIfNeeded: $0 &* 31) })

        try transcript.absorb(bytes)

        let challenges = try transcript.squeezeUInt32(count: 8, modulus: M31Field.modulus)
        XCTAssertEqual(challenges.count, 8)
        XCTAssertEqual(challenges, try transcript.squeezeUInt32(count: 8, modulus: M31Field.modulus))
    }

    #if canImport(Metal)
    func testMerkleTunerDifferentialChecksAndPersistsWinner() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 64
        let leafBytes = 32
        let leaves = Self.makeLeaves(count: leafCount, leafLength: leafBytes)
        let database = try PlanDatabase(url: temporaryDatabaseURL())
        let context = try MetalContext(device: device)
        let planner = MetalProofPlanner(context: context, planDatabase: database, protocolHash: "planner-test")

        let result = try planner.tuneMerkleCommitExecutionPlan(
            leaves: leaves,
            leafCount: leafCount,
            leafStride: leafBytes,
            leafBytes: leafBytes,
            configuration: TuningConfiguration(
                warmupRuns: 1,
                measuredRuns: 2,
                maxCandidates: 2,
                randomizedValidationBatches: 2
            )
        )

        XCTAssertFalse(result.measurements.isEmpty)
        XCTAssertEqual(result.executionPlan.readbackPoints, [.finalRoot])
        XCTAssertEqual(result.executionPlan.bufferLayout.readbackBytes, 32)

        let persisted = try database.latestWinner(
            device: context.deviceFingerprint,
            workload: result.winner.workload,
            shaderHash: context.shaderSourceHash,
            protocolHash: "planner-test"
        )
        XCTAssertEqual(persisted?.winner, result.winner.winner)
        XCTAssertEqual(persisted?.confidence, result.winner.confidence)
    }

    func testPlannedMerkleCommitUsesPersistedWinnerAndRecordsLiveObservation() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 64
        let leafBytes = 32
        let leaves = Self.makeLeaves(count: leafCount, leafLength: leafBytes, salt: 17)
        let database = try PlanDatabase(url: temporaryDatabaseURL())
        let context = try MetalContext(device: device)
        let planner = MetalProofPlanner(context: context, planDatabase: database, protocolHash: "planner-live-test")

        _ = try planner.tuneMerkleCommitExecutionPlan(
            leaves: Self.makeLeaves(count: leafCount, leafLength: leafBytes, salt: 5),
            leafCount: leafCount,
            leafStride: leafBytes,
            leafBytes: leafBytes,
            configuration: TuningConfiguration(
                warmupRuns: 1,
                measuredRuns: 2,
                maxCandidates: 2,
                randomizedValidationBatches: 1
            )
        )

        let planned = try planner.makePlannedMerkleCommitPlan(
            leafCount: leafCount,
            leafBytes: leafBytes,
            leafStride: leafBytes,
            driftPolicy: PlanDriftPolicy(emaAlpha: 1, relativeThreshold: 100, minimumSamples: 1)
        )
        XCTAssertNotNil(planned.persistedRecord)

        let result = try planned.commitWithObservation(leaves: leaves)
        let cpuRoot = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: leafCount,
            leafStride: leafBytes,
            leafLength: leafBytes
        )
        XCTAssertEqual(result.commitment.root, cpuRoot)
        guard case let .stable(sampleCount, _, _) = result.driftStatus else {
            return XCTFail("Expected stable drift observation, got \(String(describing: result.driftStatus))")
        }
        XCTAssertEqual(sampleCount, 1)
    }

    func testPlannedMerkleCommitAcceptsUploadedBufferHotPath() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 32
        let leafBytes = 32
        let leaves = Self.makeLeaves(count: leafCount, leafLength: leafBytes, salt: 29)
        let context = try MetalContext(device: device)
        let planner = MetalProofPlanner(context: context)
        let planned = try planner.makePlannedMerkleCommitPlan(
            leafCount: leafCount,
            leafBytes: leafBytes,
            leafStride: leafBytes
        )
        let upload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: leaves,
            declaredLength: leaves.count,
            label: "PlannerTests.UploadedLeaves"
        )

        let result = try planned.commitUploadedLeaves(buffer: upload)
        let cpuRoot = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: leafCount,
            leafStride: leafBytes,
            leafLength: leafBytes
        )
        XCTAssertEqual(result.commitment.root, cpuRoot)
        XCTAssertNil(result.driftStatus)
    }

    func testSumcheckChunkMatchesCPUOracleWithoutIntermediateReadback() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let evaluations = Self.makeM31Evaluations(count: 128, salt: 41)
        let expected = try SumcheckOracle.m31Chunk(evaluations: evaluations, rounds: 4)
        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        let plan = try planner.makeSumcheckChunkPlan(laneCount: evaluations.count, roundsPerSuperstep: 4)

        XCTAssertEqual(plan.executionPlan.workload.stage, .sumcheckChunk)
        XCTAssertEqual(plan.executionPlan.workload.field, .m31)
        XCTAssertEqual(plan.executionPlan.commandBufferChunks, 1)
        XCTAssertEqual(plan.executionPlan.readbackPoints, [.finalProofBytes])

        let measured = try plan.execute(evaluations: evaluations)
        XCTAssertEqual(measured.result.finalVector, expected.finalVector)
        XCTAssertEqual(measured.result.coefficients, expected.coefficients)
        XCTAssertEqual(measured.result.challenges, expected.challenges)
    }

    func testSumcheckChunkAcceptsUploadedVectorHotPath() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let evaluations = Self.makeM31Evaluations(count: 16, salt: 7)
        let expected = try SumcheckOracle.m31Chunk(evaluations: evaluations, rounds: 2)
        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        let plan = try planner.makeSumcheckChunkPlan(laneCount: evaluations.count, roundsPerSuperstep: 2)
        let upload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packUInt32LittleEndian(evaluations),
            declaredLength: evaluations.count * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.SumcheckUpload"
        )

        let measured = try plan.executeUploadedVector(buffer: upload)
        XCTAssertEqual(measured.result.finalVector, expected.finalVector)
        XCTAssertEqual(measured.result.coefficients, expected.coefficients)
        XCTAssertEqual(measured.result.challenges, expected.challenges)
    }

    func testSumcheckChunkSupportsMultiBlockTranscriptAbsorb() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let evaluations = Self.makeM31Evaluations(count: 64, salt: 103)
        let expected = try SumcheckOracle.m31Chunk(evaluations: evaluations, rounds: 1)
        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        let plan = try planner.makeSumcheckChunkPlan(laneCount: evaluations.count, roundsPerSuperstep: 1)

        let measured = try plan.execute(evaluations: evaluations)
        XCTAssertEqual(measured.result.finalVector, expected.finalVector)
        XCTAssertEqual(measured.result.coefficients, expected.coefficients)
        XCTAssertEqual(measured.result.challenges, expected.challenges)
    }

    func testSumcheckChunkRandomizedLargerLaneBatches() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        let cases = [
            (laneCount: 64, rounds: 2, salt: UInt32(19)),
            (laneCount: 128, rounds: 4, salt: UInt32(23)),
            (laneCount: 256, rounds: 5, salt: UInt32(31)),
        ]

        for testCase in cases {
            let evaluations = Self.makeM31Evaluations(count: testCase.laneCount, salt: testCase.salt)
            let expected = try SumcheckOracle.m31Chunk(evaluations: evaluations, rounds: testCase.rounds)
            let plan = try planner.makeSumcheckChunkPlan(
                laneCount: testCase.laneCount,
                roundsPerSuperstep: testCase.rounds
            )

            let measured = try plan.execute(evaluations: evaluations)
            XCTAssertEqual(measured.result.finalVector, expected.finalVector)
            XCTAssertEqual(measured.result.coefficients, expected.coefficients)
            XCTAssertEqual(measured.result.challenges, expected.challenges)
        }
    }

    func testSumcheckChunkRejectsInvalidRoundLayout() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        XCTAssertThrowsError(
            try planner.makeSumcheckChunkPlan(laneCount: 64, roundsPerSuperstep: 0)
        )
        XCTAssertThrowsError(
            try planner.makeSumcheckChunkPlan(laneCount: 96, roundsPerSuperstep: 1)
        )
        XCTAssertThrowsError(
            try planner.makeSumcheckChunkPlan(laneCount: 64, roundsPerSuperstep: 7)
        )
    }
    #endif

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AppleZKProverTests-\(UUID().uuidString)")
            .appendingPathComponent("plans.sqlite")
    }

    private func makePlanRecord(
        medianGPUTimeNS: Double,
        medianCPUSubmitNS: Double
    ) -> PlanRecord {
        let device = DeviceFingerprint(
            registryID: 123,
            name: "Test GPU",
            osBuild: "test-os",
            supportsApple4: true,
            supportsApple7: true,
            supportsApple9: false,
            supportsMetal4Queue: false,
            maxThreadsPerThreadgroup: 1024,
            hasUnifiedMemory: true
        )
        let workload = WorkloadSignature(
            stage: .merkleCommit,
            field: .bytes,
            inputLog2: 10,
            leafBytes: 32,
            arity: 2,
            roundsPerSuperstep: 1,
            fixedWidthCase: 32
        )
        let treelet = MerkleKernelSpecs.treelet32ByteLeaves(depth: 3)
        return PlanRecord(
            device: device,
            workload: workload,
            winner: treelet,
            medianGPUTimeNS: medianGPUTimeNS,
            medianCPUSubmitNS: medianCPUSubmitNS,
            p95GPUTimeNS: medianGPUTimeNS,
            readbacks: 1,
            confidence: 1,
            shaderHash: "shader",
            protocolHash: "protocol"
        )
    }

    private static func makeLeaves(count: Int, leafLength: Int, salt: Int = 0) -> Data {
        var bytes = [UInt8](repeating: 0xa5, count: count * leafLength)
        for leaf in 0..<count {
            for j in 0..<leafLength {
                bytes[leaf * leafLength + j] = UInt8(truncatingIfNeeded: (leaf &* 29) &+ (j &* 7) &+ salt &+ 3)
            }
        }
        return Data(bytes)
    }

    private static func makeM31Evaluations(count: Int, salt: UInt32) -> [UInt32] {
        (0..<count).map { index in
            let value = UInt64(index + 1) * 1_048_573 + UInt64(salt) * 65_537
            return UInt32(value % UInt64(M31Field.modulus))
        }
    }

    private static func packUInt32LittleEndian(_ values: [UInt32]) -> Data {
        var data = Data()
        data.reserveCapacity(values.count * MemoryLayout<UInt32>.stride)
        for value in values {
            data.append(UInt8(value & 0xff))
            data.append(UInt8((value >> 8) & 0xff))
            data.append(UInt8((value >> 16) & 0xff))
            data.append(UInt8((value >> 24) & 0xff))
        }
        return data
    }
}
