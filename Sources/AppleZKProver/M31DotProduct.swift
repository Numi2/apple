#if canImport(Metal)
import Foundation
import Metal

private struct M31DotProductParams {
    var count: UInt32
    var fieldModulus: UInt32
    var elementsPerThreadgroup: UInt32
    var threadsPerThreadgroup: UInt32
}

public struct M31DotProductResult: Sendable {
    public let value: UInt32
    public let stats: GPUExecutionStats

    public init(value: UInt32, stats: GPUExecutionStats) {
        self.value = value
        self.stats = stats
    }
}

public final class M31DotProductPlan: @unchecked Sendable {
    private static let defaultUploadRingSlotCount = 3
    private static let preferredThreadsPerThreadgroup = 256

    public let count: Int
    public let threadsPerThreadgroup: Int
    public let elementsPerThread: Int
    public let elementsPerThreadgroup: Int

    private let context: MetalContext
    private let dotProductPipeline: MTLComputePipelineState
    private let sumPartialsPipeline: MTLComputePipelineState
    private let uploadRingLHS: SharedUploadRing
    private let uploadRingRHS: SharedUploadRing
    private let arena: ResidencyArena
    private let lhsVector: ArenaSlice
    private let rhsVector: ArenaSlice
    private let partialsA: ArenaSlice
    private let partialsB: ArenaSlice
    private let outputReadback: MTLBuffer
    private let inputByteCount: Int
    private let maxPartialCount: Int
    private let partialByteCount: Int
    private let threadgroupMemoryByteCount: Int
    private let executionLock = NSLock()

    public init(
        context: MetalContext,
        count: Int,
        elementsPerThread: Int = 4
    ) throws {
        guard count > 0, count <= Int(UInt32.max), elementsPerThread > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }

        self.context = context
        self.count = count
        self.elementsPerThread = elementsPerThread
        self.inputByteCount = try checkedBufferLength(count, MemoryLayout<UInt32>.stride)
        self.dotProductPipeline = try context.pipeline(
            for: KernelSpec(kernel: "m31_dot_product_partials", family: .scalar, queueMode: .metal3)
        )
        self.sumPartialsPipeline = try context.pipeline(
            for: KernelSpec(kernel: "m31_sum_partials", family: .scalar, queueMode: .metal3)
        )

        let selectedThreads = Self.selectThreadsPerThreadgroup(
            dotProductPipeline: dotProductPipeline,
            sumPartialsPipeline: sumPartialsPipeline,
            context: context
        )
        let selectedElementsPerThreadgroup = try checkedBufferLength(selectedThreads, elementsPerThread)
        guard selectedElementsPerThreadgroup <= Int(UInt32.max) else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.threadsPerThreadgroup = selectedThreads
        self.elementsPerThreadgroup = selectedElementsPerThreadgroup
        self.threadgroupMemoryByteCount = try checkedBufferLength(selectedThreads, MemoryLayout<UInt32>.stride)
        guard threadgroupMemoryByteCount <= context.capabilities.maxThreadgroupMemoryLength else {
            throw AppleZKProverError.invalidKernelConfiguration("M31 dot product reduction requires \(threadgroupMemoryByteCount) bytes of threadgroup memory.")
        }

        let maxPartialCount = try Self.roundUpDiv(count, selectedElementsPerThreadgroup)
        self.maxPartialCount = maxPartialCount
        self.partialByteCount = try checkedBufferLength(maxPartialCount, MemoryLayout<UInt32>.stride)

        self.uploadRingLHS = try SharedUploadRing(
            device: context.device,
            slotCapacity: inputByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.M31DotProductUploadLHS"
        )
        self.uploadRingRHS = try SharedUploadRing(
            device: context.device,
            slotCapacity: inputByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.M31DotProductUploadRHS"
        )
        self.arena = try ResidencyArena(
            device: context.device,
            capacity: try Self.checkedSum([
                inputByteCount,
                inputByteCount,
                partialByteCount,
                partialByteCount,
                4 * 256,
            ]),
            label: "AppleZKProver.M31DotProductArena"
        )
        self.lhsVector = try arena.allocate(length: inputByteCount, role: .sumcheckVector)
        self.rhsVector = try arena.allocate(length: inputByteCount, role: .sumcheckVector)
        self.partialsA = try arena.allocate(length: partialByteCount, role: .scratch)
        self.partialsB = try arena.allocate(length: partialByteCount, role: .scratch)
        self.outputReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: MemoryLayout<UInt32>.stride,
            label: "AppleZKProver.M31DotProductReadback"
        )
    }

    public func execute(lhs: [UInt32], rhs: [UInt32]) throws -> M31DotProductResult {
        try validateInputs(lhs: lhs, rhs: rhs)
        let lhsBytes = Self.packLittleEndian(lhs)
        let rhsBytes = Self.packLittleEndian(rhs)

        executionLock.lock()
        defer { executionLock.unlock() }

        let lhsSlot = try uploadRingLHS.copy(lhsBytes, byteCount: inputByteCount)
        let rhsSlot = try uploadRingRHS.copy(rhsBytes, byteCount: inputByteCount)
        return try executeLocked(
            lhsBuffer: lhsSlot.buffer,
            lhsOffset: lhsSlot.offset,
            rhsBuffer: rhsSlot.buffer,
            rhsOffset: rhsSlot.offset
        )
    }

    public func executeVerified(lhs: [UInt32], rhs: [UInt32]) throws -> M31DotProductResult {
        let expected = try M31Field.dotProduct(lhs: lhs, rhs: rhs)
        let measured = try execute(lhs: lhs, rhs: rhs)
        guard measured.value == expected else {
            throw AppleZKProverError.correctnessValidationFailed("M31 dot product GPU result did not match the CPU oracle.")
        }
        return measured
    }

    public func executeUploadedVectors(
        lhsBuffer: MTLBuffer,
        lhsOffset: Int = 0,
        rhsBuffer: MTLBuffer,
        rhsOffset: Int = 0
    ) throws -> M31DotProductResult {
        executionLock.lock()
        defer { executionLock.unlock() }

        return try executeLocked(
            lhsBuffer: lhsBuffer,
            lhsOffset: lhsOffset,
            rhsBuffer: rhsBuffer,
            rhsOffset: rhsOffset
        )
    }

    public func clearReusableBuffers() throws {
        executionLock.lock()
        defer { executionLock.unlock() }

        uploadRingLHS.clear()
        uploadRingRHS.clear()
        MetalBufferFactory.zeroSharedBuffer(outputReadback)
        try MetalBufferFactory.zeroPrivateBuffers(
            [arena.buffer],
            context: context,
            label: "M31DotProduct.PlanClear"
        )
    }

    private func executeLocked(
        lhsBuffer: MTLBuffer,
        lhsOffset: Int,
        rhsBuffer: MTLBuffer,
        rhsOffset: Int
    ) throws -> M31DotProductResult {
        try validateBufferRange(buffer: lhsBuffer, offset: lhsOffset, byteCount: inputByteCount)
        try validateBufferRange(buffer: rhsBuffer, offset: rhsOffset, byteCount: inputByteCount)

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "M31.DotProduct"

        guard let uploadBlit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        uploadBlit.label = "M31.DotProduct.Upload"
        uploadBlit.copy(
            from: lhsBuffer,
            sourceOffset: lhsOffset,
            to: lhsVector.buffer,
            destinationOffset: lhsVector.offset,
            size: inputByteCount
        )
        uploadBlit.copy(
            from: rhsBuffer,
            sourceOffset: rhsOffset,
            to: rhsVector.buffer,
            destinationOffset: rhsVector.offset,
            size: inputByteCount
        )
        uploadBlit.fill(buffer: partialsA.buffer, range: partialsA.offset..<(partialsA.offset + partialsA.length), value: 0)
        uploadBlit.fill(buffer: partialsB.buffer, range: partialsB.offset..<(partialsB.offset + partialsB.length), value: 0)
        uploadBlit.endEncoding()

        var params = makeParams(count: count)
        let firstPartialCount = try Self.roundUpDiv(count, elementsPerThreadgroup)
        guard firstPartialCount <= maxPartialCount else {
            throw AppleZKProverError.invalidInputLayout
        }

        guard let dotEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        dotEncoder.label = "M31.DotProduct.Partials"
        dotEncoder.setComputePipelineState(dotProductPipeline)
        dotEncoder.setBuffer(lhsVector.buffer, offset: lhsVector.offset, index: 0)
        dotEncoder.setBuffer(rhsVector.buffer, offset: rhsVector.offset, index: 1)
        dotEncoder.setBuffer(partialsA.buffer, offset: partialsA.offset, index: 2)
        dotEncoder.setBytes(&params, length: MemoryLayout<M31DotProductParams>.stride, index: 3)
        dotEncoder.setThreadgroupMemoryLength(threadgroupMemoryByteCount, index: 0)
        dotEncoder.dispatchThreadgroups(
            MTLSize(width: firstPartialCount, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadsPerThreadgroup, height: 1, depth: 1)
        )
        dotEncoder.endEncoding()

        var activeSlice = partialsA
        var inactiveSlice = partialsB
        var activeCount = firstPartialCount
        while activeCount > 1 {
            let reducedCount = try Self.roundUpDiv(activeCount, elementsPerThreadgroup)
            var sumParams = makeParams(count: activeCount)

            guard let sumEncoder = commandBuffer.makeComputeCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            sumEncoder.label = "M31.DotProduct.SumPartials"
            sumEncoder.setComputePipelineState(sumPartialsPipeline)
            sumEncoder.setBuffer(activeSlice.buffer, offset: activeSlice.offset, index: 0)
            sumEncoder.setBuffer(inactiveSlice.buffer, offset: inactiveSlice.offset, index: 1)
            sumEncoder.setBytes(&sumParams, length: MemoryLayout<M31DotProductParams>.stride, index: 2)
            sumEncoder.setThreadgroupMemoryLength(threadgroupMemoryByteCount, index: 0)
            sumEncoder.dispatchThreadgroups(
                MTLSize(width: reducedCount, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: threadsPerThreadgroup, height: 1, depth: 1)
            )
            sumEncoder.endEncoding()

            activeCount = reducedCount
            swap(&activeSlice, &inactiveSlice)
        }

        guard let readbackBlit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        readbackBlit.label = "M31.DotProduct.Readback"
        readbackBlit.copy(
            from: activeSlice.buffer,
            sourceOffset: activeSlice.offset,
            to: outputReadback,
            destinationOffset: 0,
            size: MemoryLayout<UInt32>.stride
        )
        readbackBlit.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        return M31DotProductResult(
            value: outputReadback.contents().bindMemory(to: UInt32.self, capacity: 1)[0],
            stats: GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpuDuration(commandBuffer))
        )
    }

    private func validateInputs(lhs: [UInt32], rhs: [UInt32]) throws {
        guard lhs.count == count, rhs.count == count else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(lhs)
        try M31Field.validateCanonical(rhs)
    }

    private func validateBufferRange(buffer: MTLBuffer, offset: Int, byteCount: Int) throws {
        let end = offset.addingReportingOverflow(max(1, byteCount))
        guard offset >= 0,
              byteCount >= 0,
              !end.overflow,
              buffer.length >= end.partialValue else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private func makeParams(count: Int) -> M31DotProductParams {
        M31DotProductParams(
            count: UInt32(count),
            fieldModulus: M31Field.modulus,
            elementsPerThreadgroup: UInt32(elementsPerThreadgroup),
            threadsPerThreadgroup: UInt32(threadsPerThreadgroup)
        )
    }

    private static func packLittleEndian(_ values: [UInt32]) -> Data {
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

    private static func selectThreadsPerThreadgroup(
        dotProductPipeline: MTLComputePipelineState,
        sumPartialsPipeline: MTLComputePipelineState,
        context: MetalContext
    ) -> Int {
        let pipelineLimit = min(
            dotProductPipeline.maxTotalThreadsPerThreadgroup,
            sumPartialsPipeline.maxTotalThreadsPerThreadgroup,
            context.capabilities.maxThreadsPerThreadgroup,
            preferredThreadsPerThreadgroup
        )
        return highestPowerOfTwo(lessThanOrEqualTo: max(1, pipelineLimit))
    }

    private static func highestPowerOfTwo(lessThanOrEqualTo value: Int) -> Int {
        var power = 1
        while power <= value / 2 {
            power <<= 1
        }
        return power
    }

    private static func roundUpDiv(_ value: Int, _ divisor: Int) throws -> Int {
        guard value >= 0, divisor > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let adjusted = value.addingReportingOverflow(divisor - 1)
        guard !adjusted.overflow else {
            throw AppleZKProverError.invalidInputLayout
        }
        return adjusted.partialValue / divisor
    }

    private static func checkedSum(_ values: [Int]) throws -> Int {
        var total = 0
        for value in values {
            let next = total.addingReportingOverflow(value)
            guard value >= 0, !next.overflow else {
                throw AppleZKProverError.invalidInputLayout
            }
            total = next.partialValue
        }
        return total
    }

    private func gpuDuration(_ commandBuffer: MTLCommandBuffer) -> Double? {
        guard commandBuffer.gpuEndTime > commandBuffer.gpuStartTime else {
            return nil
        }
        return commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    }
}
#endif
