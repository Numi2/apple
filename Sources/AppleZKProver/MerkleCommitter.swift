#if canImport(Metal)
import Foundation
import Metal

private struct MerkleParentParams {
    var pairCount: UInt32
}

private struct MerkleFuseParams {
    var nodeCount: UInt32
}

private struct MerkleTreeletParams {
    var leafCount: UInt32
    var inputStride: UInt32
    var subtreeLeafCount: UInt32
}

struct MerkleCommitMeasurement {
    let commitment: MerkleCommitment
    let cpuSubmitNS: Double
}

enum MerkleKernelSpecs {
    static func parent32x32(family: KernelSpec.Family = .scalar) -> KernelSpec {
        KernelSpec(
            kernel: "sha3_256_merkle_parents_specialized",
            family: family,
            queueMode: .metal3,
            functionConstants: .plannerConstants([
                (.parentBytes, 32),
                (.treeArity, 2),
                (.fixedWidthCase, 32),
            ])
        )
    }

    static func fusedUpper32() -> KernelSpec {
        KernelSpec(
            kernel: "sha3_256_merkle_fuse_upper_32",
            family: .treelet,
            queueMode: .metal3
        )
    }

    static func treeletLeaves(
        leafBytes: Int,
        depth: Int,
        family: KernelSpec.Family = .treelet
    ) -> KernelSpec {
        KernelSpec(
            kernel: "sha3_256_merkle_treelet_leaves_specialized",
            family: family,
            queueMode: .metal3,
            functionConstants: .plannerConstants([
                (.leafBytes, UInt64(leafBytes)),
                (.parentBytes, 32),
                (.treeArity, 2),
                (.treeletDepth, UInt64(depth)),
                (.fixedWidthCase, UInt64(fixedWidthCase(forLeafBytes: leafBytes))),
                (.barrierCadence, 1),
            ]),
            threadsPerThreadgroup: UInt16(1 << max(0, min(depth, 15)))
        )
    }

    private static func fixedWidthCase(forLeafBytes leafBytes: Int) -> Int {
        switch leafBytes {
        case 32, 64, 128, 136:
            return leafBytes
        default:
            return 0
        }
    }
}

public struct MerkleCommitPlanConfiguration: Sendable {
    public enum LeafSubtreeMode: Sendable, Equatable {
        case disabled
        case automatic
        case fixed(Int)
    }

    public var leafSubtreeMode: LeafSubtreeMode
    public var uploadRingSlotCount: Int

    public init(
        leafSubtreeMode: LeafSubtreeMode = .disabled,
        uploadRingSlotCount: Int = 3
    ) {
        self.leafSubtreeMode = leafSubtreeMode
        self.uploadRingSlotCount = uploadRingSlotCount
    }

    public static let `default` = MerkleCommitPlanConfiguration()
}

public final class SHA3MerkleCommitter: @unchecked Sendable {
    private let context: MetalContext

    public init(context: MetalContext) {
        self.context = context
    }

    public func makeRawLeavesCommitPlan(
        leafCount: Int,
        leafStride: Int,
        leafLength: Int,
        configuration: MerkleCommitPlanConfiguration = .default
    ) throws -> SHA3RawLeavesMerkleCommitPlan {
        try SHA3RawLeavesMerkleCommitPlan(
            context: context,
            leafCount: leafCount,
            leafStride: leafStride,
            leafLength: leafLength,
            configuration: configuration
        )
    }

    public func commitRawLeaves(
        leaves: Data,
        leafCount: Int,
        leafStride: Int,
        leafLength: Int
    ) throws -> MerkleCommitment {
        let plan = try makeRawLeavesCommitPlan(
            leafCount: leafCount,
            leafStride: leafStride,
            leafLength: leafLength
        )
        return try plan.commit(leaves: leaves)
    }

    public func commitRawLeavesVerified(
        leaves: Data,
        leafCount: Int,
        leafStride: Int,
        leafLength: Int
    ) throws -> MerkleCommitment {
        let plan = try makeRawLeavesCommitPlan(
            leafCount: leafCount,
            leafStride: leafStride,
            leafLength: leafLength
        )
        return try plan.commitVerified(leaves: leaves)
    }

    public func commitPrehashedLeaves(_ leafHashes: Data) throws -> MerkleCommitment {
        guard leafHashes.count >= 32, leafHashes.count % 32 == 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let leafCount = leafHashes.count / 32
        guard leafCount.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidLeafCount(leafCount)
        }
        _ = try checkedUInt32(leafCount)

        let parentPipeline = try context.pipeline(for: MerkleKernelSpecs.parent32x32())
        let upload = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            bytes: leafHashes,
            declaredLength: leafHashes.count,
            label: "Merkle.PrehashedUpload"
        )
        let scratchLength = max(32, leafHashes.count)
        let arena = try ResidencyArena(
            device: context.device,
            capacity: scratchLength * 2 + 256,
            label: "Merkle.PrehashedArena"
        )
        let scratchA = try arena.allocate(length: scratchLength, role: .leafHashes)
        let scratchB = try arena.allocate(length: scratchLength, role: .frontierNodes)
        let rootReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: 32,
            label: "Merkle.PrehashedRoot"
        )

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "Merkle.CommitPrehashed"

        guard let blitIn = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        blitIn.copy(from: upload, sourceOffset: 0, to: scratchA.buffer, destinationOffset: scratchA.offset, size: leafHashes.count)
        blitIn.endEncoding()

        var current = scratchA
        var alternate = scratchB
        var currentCount = leafCount
        while currentCount > 1 {
            var parentParams = MerkleParentParams(pairCount: try checkedUInt32(currentCount / 2))
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            encoder.setComputePipelineState(parentPipeline)
            encoder.setBuffer(current.buffer, offset: current.offset, index: 0)
            encoder.setBuffer(alternate.buffer, offset: alternate.offset, index: 1)
            encoder.setBytes(&parentParams, length: MemoryLayout<MerkleParentParams>.stride, index: 2)
            context.dispatch1D(encoder, pipeline: parentPipeline, elementCount: currentCount / 2)
            encoder.endEncoding()
            swap(&current, &alternate)
            currentCount /= 2
        }

        guard let blitOut = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        blitOut.copy(from: current.buffer, sourceOffset: current.offset, to: rootReadback, destinationOffset: 0, size: 32)
        blitOut.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let gpu = gpuDuration(commandBuffer)
        let root = Data(bytes: rootReadback.contents(), count: 32)
        return MerkleCommitment(root: root, stats: GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpu))
    }

    private func gpuDuration(_ commandBuffer: MTLCommandBuffer) -> Double? {
        guard commandBuffer.gpuEndTime > commandBuffer.gpuStartTime else {
            return nil
        }
        return commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    }
}

public final class SHA3RawLeavesMerkleCommitPlan: @unchecked Sendable {
    private let context: MetalContext
    private let leafCount: Int
    private let leafStride: Int
    private let leafLength: Int
    private let declaredLeafBytes: Int
    private let uploadRing: SharedUploadRing
    private let arena: ResidencyArena
    private let scratchA: ArenaSlice
    private let scratchB: ArenaSlice
    private let rootReadback: MTLBuffer
    private let leafHashPipeline: MTLComputePipelineState
    private let parentPipeline: MTLComputePipelineState
    private let fusedUpperPipeline: MTLComputePipelineState
    private let subtreePipeline: MTLComputePipelineState?
    public let fusedUpperNodeLimit: Int
    public let subtreeLeafCount: Int
    private let executionLock = NSLock()
    private var leafParams: SHA3BatchParams
    private var subtreeParams: MerkleTreeletParams?

    init(
        context: MetalContext,
        leafCount: Int,
        leafStride: Int,
        leafLength: Int,
        configuration: MerkleCommitPlanConfiguration
    ) throws {
        guard leafCount > 0, leafCount.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidLeafCount(leafCount)
        }
        guard leafLength >= 0, leafLength <= SHA3Oracle.sha3_256Rate else {
            throw AppleZKProverError.unsupportedOneBlockLength(leafLength)
        }
        guard leafStride >= leafLength else {
            throw AppleZKProverError.invalidInputLayout
        }
        guard configuration.uploadRingSlotCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let leafCount32 = try checkedUInt32(leafCount)
        let leafStride32 = try checkedUInt32(leafStride)
        let leafLength32 = try checkedUInt32(leafLength)
        let declaredLeafBytes = try checkedBufferLength(leafCount, leafStride)

        let scratchLength = max(32, try checkedBufferLength(leafCount, 32))
        self.context = context
        self.leafCount = leafCount
        self.leafStride = leafStride
        self.leafLength = leafLength
        self.declaredLeafBytes = declaredLeafBytes
        self.uploadRing = try SharedUploadRing(
            device: context.device,
            slotCapacity: declaredLeafBytes,
            slotCount: configuration.uploadRingSlotCount,
            label: "Merkle.UploadRing"
        )
        self.arena = try ResidencyArena(
            device: context.device,
            capacity: scratchLength * 2 + 256,
            label: "Merkle.Arena"
        )
        self.scratchA = try arena.allocate(length: scratchLength, role: .leafHashes)
        self.scratchB = try arena.allocate(length: scratchLength, role: .frontierNodes)
        self.rootReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: 32,
            label: "Merkle.RootReadback"
        )
        self.leafHashPipeline = try context.pipeline(for: SHA3OneBlockKernel.spec(forInputLength: leafLength))
        self.parentPipeline = try context.pipeline(for: MerkleKernelSpecs.parent32x32())
        self.fusedUpperPipeline = try context.pipeline(for: MerkleKernelSpecs.fusedUpper32())
        self.fusedUpperNodeLimit = Self.fusedUpperNodeLimit(
            device: context.device,
            pipeline: fusedUpperPipeline
        )
        let selectedSubtreeLeafCount = try Self.subtreeLeafCount(
            mode: configuration.leafSubtreeMode,
            leafCount: leafCount,
            leafLength: leafLength,
            device: context.device,
            pipelineProvider: {
                try context.pipeline(for: MerkleKernelSpecs.treeletLeaves(leafBytes: leafLength, depth: 3))
            }
        )
        if selectedSubtreeLeafCount > 0 {
            let subtreePipeline = try context.pipeline(
                for: MerkleKernelSpecs.treeletLeaves(
                    leafBytes: leafLength,
                    depth: Self.log2(selectedSubtreeLeafCount)
                )
            )
            self.subtreePipeline = subtreePipeline
            self.subtreeLeafCount = selectedSubtreeLeafCount
        } else {
            self.subtreePipeline = nil
            self.subtreeLeafCount = 0
        }
        self.leafParams = SHA3BatchParams(
            count: leafCount32,
            inputStride: leafStride32,
            inputLength: leafLength32,
            outputStride: 32
        )
        if subtreeLeafCount > 1 {
            self.subtreeParams = MerkleTreeletParams(
                leafCount: leafCount32,
                inputStride: leafStride32,
                subtreeLeafCount: try checkedUInt32(subtreeLeafCount)
            )
        } else {
            self.subtreeParams = nil
        }
    }

    public func commit(leaves: Data) throws -> MerkleCommitment {
        try commitMeasured(leaves: leaves).commitment
    }

    public func commitVerified(leaves: Data) throws -> MerkleCommitment {
        try commitMeasuredVerified(leaves: leaves).commitment
    }

    func commitMeasured(leaves: Data) throws -> MerkleCommitMeasurement {
        executionLock.lock()
        defer { executionLock.unlock() }

        let slot = try uploadRing.copy(leaves, byteCount: declaredLeafBytes)
        return try commitMeasuredLocked(uploadBuffer: slot.buffer, uploadOffset: slot.offset)
    }

    func commitMeasured(uploadBuffer: MTLBuffer, uploadOffset: Int = 0) throws -> MerkleCommitMeasurement {
        executionLock.lock()
        defer { executionLock.unlock() }

        return try commitMeasuredLocked(uploadBuffer: uploadBuffer, uploadOffset: uploadOffset)
    }

    func commitMeasuredVerified(leaves: Data) throws -> MerkleCommitMeasurement {
        let measured = try commitMeasured(leaves: leaves)
        try verifyCommitment(leaves: leaves, root: measured.commitment.root)
        return measured
    }

    private func commitMeasuredLocked(uploadBuffer: MTLBuffer, uploadOffset: Int = 0) throws -> MerkleCommitMeasurement {

        let uploadEnd = uploadOffset.addingReportingOverflow(max(1, declaredLeafBytes))
        guard uploadOffset >= 0,
              !uploadEnd.overflow,
              uploadBuffer.length >= uploadEnd.partialValue else {
            throw AppleZKProverError.invalidInputLayout
        }

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "Merkle.Commit"

        var current = scratchA
        var alternate = scratchB
        var currentCount: Int

        if let subtreePipeline, var subtreeParams {
            guard let subtreeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            subtreeEncoder.label = "Merkle.Subtrees.\(subtreeLeafCount)"
            subtreeEncoder.setComputePipelineState(subtreePipeline)
            subtreeEncoder.setBuffer(uploadBuffer, offset: uploadOffset, index: 0)
            subtreeEncoder.setBuffer(scratchA.buffer, offset: scratchA.offset, index: 1)
            subtreeEncoder.setBytes(&subtreeParams, length: MemoryLayout<MerkleTreeletParams>.stride, index: 2)
            subtreeEncoder.setThreadgroupMemoryLength(subtreeLeafCount * 32, index: 0)
            subtreeEncoder.dispatchThreadgroups(
                MTLSize(width: leafCount / subtreeLeafCount, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: subtreeLeafCount, height: 1, depth: 1)
            )
            subtreeEncoder.endEncoding()
            currentCount = leafCount / subtreeLeafCount
        } else {
            guard let hashEncoder = commandBuffer.makeComputeCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            hashEncoder.label = "Merkle.LeafHash"
            hashEncoder.setComputePipelineState(leafHashPipeline)
            hashEncoder.setBuffer(uploadBuffer, offset: uploadOffset, index: 0)
            hashEncoder.setBuffer(scratchA.buffer, offset: scratchA.offset, index: 1)
            hashEncoder.setBytes(&leafParams, length: MemoryLayout<SHA3BatchParams>.stride, index: 2)
            context.dispatch1D(hashEncoder, pipeline: leafHashPipeline, elementCount: leafCount)
            hashEncoder.endEncoding()
            currentCount = leafCount
        }

        while currentCount > max(1, fusedUpperNodeLimit) {
            var parentParams = MerkleParentParams(pairCount: try checkedUInt32(currentCount / 2))
            guard let parentEncoder = commandBuffer.makeComputeCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            parentEncoder.label = "Merkle.Reduce.\(currentCount)"
            parentEncoder.setComputePipelineState(parentPipeline)
            parentEncoder.setBuffer(current.buffer, offset: current.offset, index: 0)
            parentEncoder.setBuffer(alternate.buffer, offset: alternate.offset, index: 1)
            parentEncoder.setBytes(&parentParams, length: MemoryLayout<MerkleParentParams>.stride, index: 2)
            context.dispatch1D(parentEncoder, pipeline: parentPipeline, elementCount: currentCount / 2)
            parentEncoder.endEncoding()

            swap(&current, &alternate)
            currentCount /= 2
        }

        if currentCount > 1 {
            var fuseParams = MerkleFuseParams(nodeCount: try checkedUInt32(currentCount))
            guard let fusedEncoder = commandBuffer.makeComputeCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            fusedEncoder.label = "Merkle.FuseUpper.\(currentCount)"
            fusedEncoder.setComputePipelineState(fusedUpperPipeline)
            fusedEncoder.setBuffer(current.buffer, offset: current.offset, index: 0)
            fusedEncoder.setBuffer(rootReadback, offset: 0, index: 1)
            fusedEncoder.setBytes(&fuseParams, length: MemoryLayout<MerkleFuseParams>.stride, index: 2)
            fusedEncoder.setThreadgroupMemoryLength(currentCount * 32, index: 0)
            fusedEncoder.dispatchThreadgroups(
                MTLSize(width: 1, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: currentCount, height: 1, depth: 1)
            )
            fusedEncoder.endEncoding()
        } else {
            guard let blit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            blit.label = "Merkle.RootReadback"
            blit.copy(from: current.buffer, sourceOffset: current.offset, to: rootReadback, destinationOffset: 0, size: 32)
            blit.endEncoding()
        }

        let submitStart = DispatchTime.now()
        commandBuffer.commit()
        let submitEnd = DispatchTime.now()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let gpu = gpuDuration(commandBuffer)
        let root = Data(bytes: rootReadback.contents(), count: 32)
        return MerkleCommitMeasurement(
            commitment: MerkleCommitment(root: root, stats: GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpu)),
            cpuSubmitNS: Double(submitEnd.uptimeNanoseconds - submitStart.uptimeNanoseconds)
        )
    }

    private func verifyCommitment(leaves: Data, root: Data) throws {
        let cpuRoot = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: leafCount,
            leafStride: leafStride,
            leafLength: leafLength
        )
        guard root == cpuRoot else {
            throw AppleZKProverError.correctnessValidationFailed("SHA3 Merkle GPU root did not match the CPU oracle.")
        }
    }

    public func clearReusableBuffers() throws {
        executionLock.lock()
        defer { executionLock.unlock() }

        uploadRing.clear()
        MetalBufferFactory.zeroSharedBuffer(rootReadback)
        try MetalBufferFactory.zeroPrivateBuffers(
            [arena.buffer],
            context: context,
            label: "Merkle.PlanClear"
        )
    }

    private static func fusedUpperNodeLimit(device: MTLDevice, pipeline: MTLComputePipelineState) -> Int {
        let maxNodesByThreadgroupMemory = device.maxThreadgroupMemoryLength / 32
        let maxNodesByThreads = pipeline.maxTotalThreadsPerThreadgroup
        let candidate = min(512, min(maxNodesByThreadgroupMemory, maxNodesByThreads))
        guard candidate >= 2 else {
            return 0
        }
        return floorPowerOfTwo(candidate)
    }

    private static func subtreeLeafCount(
        mode: MerkleCommitPlanConfiguration.LeafSubtreeMode,
        leafCount: Int,
        leafLength: Int,
        device: MTLDevice,
        pipelineProvider: () throws -> MTLComputePipelineState
    ) throws -> Int {
        guard mode != .disabled else {
            return 0
        }

        let pipeline = try pipelineProvider()
        let maxLeavesByThreadgroupMemory = device.maxThreadgroupMemoryLength / 32
        let maxLeavesByThreads = pipeline.maxTotalThreadsPerThreadgroup

        switch mode {
        case .disabled:
            return 0
        case .automatic:
            let candidate = min(64, min(leafCount, min(maxLeavesByThreadgroupMemory, maxLeavesByThreads)))
            guard candidate >= 2 else {
                return 0
            }
            return floorPowerOfTwo(candidate)
        case let .fixed(value):
            guard value >= 2,
                  value <= leafCount,
                  value.nonzeroBitCount == 1,
                  leafCount.isMultiple(of: value),
                  value <= maxLeavesByThreadgroupMemory,
                  value <= maxLeavesByThreads else {
                throw AppleZKProverError.invalidInputLayout
            }
            return value
        }
    }

    private static func floorPowerOfTwo(_ value: Int) -> Int {
        var power = 1
        while power <= value / 2 {
            power <<= 1
        }
        return power
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

    private func gpuDuration(_ commandBuffer: MTLCommandBuffer) -> Double? {
        guard commandBuffer.gpuEndTime > commandBuffer.gpuStartTime else {
            return nil
        }
        return commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    }
}
#endif
