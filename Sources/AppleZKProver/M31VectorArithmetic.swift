#if canImport(Metal)
import Foundation
import Metal

private struct M31VectorParams {
    var count: UInt32
    var operation: UInt32
    var fieldModulus: UInt32
}

public struct M31VectorArithmeticResult: Sendable {
    public let values: [UInt32]
    public let stats: GPUExecutionStats

    public init(values: [UInt32], stats: GPUExecutionStats) {
        self.values = values
        self.stats = stats
    }
}

public final class M31VectorArithmeticPlan: @unchecked Sendable {
    private static let defaultUploadRingSlotCount = 3

    public let operation: M31VectorOperation
    public let count: Int

    private let context: MetalContext
    private let pipeline: MTLComputePipelineState
    private let uploadRingLHS: SharedUploadRing
    private let uploadRingRHS: SharedUploadRing
    private let arena: ResidencyArena
    private let lhsVector: ArenaSlice
    private let rhsVector: ArenaSlice
    private let outputVector: ArenaSlice
    private let outputReadback: MTLBuffer
    private let inputByteCount: Int
    private let executionLock = NSLock()

    public init(
        context: MetalContext,
        operation: M31VectorOperation,
        count: Int
    ) throws {
        guard count > 0, count <= Int(UInt32.max) else {
            throw AppleZKProverError.invalidInputLayout
        }

        self.context = context
        self.operation = operation
        self.count = count

        let inputByteCount = try checkedBufferLength(count, MemoryLayout<UInt32>.stride)
        self.inputByteCount = inputByteCount
        self.pipeline = try context.pipeline(
            for: KernelSpec(kernel: "m31_vector_arithmetic", family: .scalar, queueMode: .metal3)
        )
        self.uploadRingLHS = try SharedUploadRing(
            device: context.device,
            slotCapacity: inputByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.M31VectorUploadLHS"
        )
        self.uploadRingRHS = try SharedUploadRing(
            device: context.device,
            slotCapacity: inputByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.M31VectorUploadRHS"
        )
        self.arena = try ResidencyArena(
            device: context.device,
            capacity: try Self.checkedSum([
                inputByteCount,
                inputByteCount,
                inputByteCount,
                3 * 256,
            ]),
            label: "AppleZKProver.M31VectorArena"
        )
        self.lhsVector = try arena.allocate(length: inputByteCount, role: .sumcheckVector)
        self.rhsVector = try arena.allocate(length: inputByteCount, role: .sumcheckVector)
        self.outputVector = try arena.allocate(length: inputByteCount, role: .sumcheckVector)
        self.outputReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: inputByteCount,
            label: "AppleZKProver.M31VectorReadback"
        )
    }

    public func execute(
        lhs: [UInt32],
        rhs: [UInt32]? = nil
    ) throws -> M31VectorArithmeticResult {
        try validateInputs(lhs: lhs, rhs: rhs)
        let lhsBytes = Self.packLittleEndian(lhs)
        let rhsBytes = Self.packLittleEndian(rhs ?? lhs)

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

    public func executeVerified(
        lhs: [UInt32],
        rhs: [UInt32]? = nil
    ) throws -> M31VectorArithmeticResult {
        let expected = try M31Field.apply(operation, lhs: lhs, rhs: rhs)
        let measured = try execute(lhs: lhs, rhs: rhs)
        guard measured.values == expected else {
            throw AppleZKProverError.correctnessValidationFailed("M31 vector arithmetic GPU result did not match the CPU oracle.")
        }
        return measured
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
            label: "M31Vector.PlanClear"
        )
    }

    private func executeLocked(
        lhsBuffer: MTLBuffer,
        lhsOffset: Int,
        rhsBuffer: MTLBuffer,
        rhsOffset: Int
    ) throws -> M31VectorArithmeticResult {
        let lhsEnd = lhsOffset.addingReportingOverflow(max(1, inputByteCount))
        let rhsEnd = rhsOffset.addingReportingOverflow(max(1, inputByteCount))
        guard lhsOffset >= 0,
              rhsOffset >= 0,
              !lhsEnd.overflow,
              !rhsEnd.overflow,
              lhsBuffer.length >= lhsEnd.partialValue,
              rhsBuffer.length >= rhsEnd.partialValue else {
            throw AppleZKProverError.invalidInputLayout
        }

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "M31.VectorArithmetic.\(operation)"

        guard let uploadBlit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        uploadBlit.label = "M31.VectorArithmetic.Upload"
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
        uploadBlit.fill(buffer: outputVector.buffer, range: outputVector.offset..<(outputVector.offset + outputVector.length), value: 0)
        uploadBlit.endEncoding()

        var params = M31VectorParams(
            count: try checkedUInt32(count),
            operation: operation.rawValue,
            fieldModulus: M31Field.modulus
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "M31.VectorArithmetic.Kernel"
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(lhsVector.buffer, offset: lhsVector.offset, index: 0)
        encoder.setBuffer(rhsVector.buffer, offset: rhsVector.offset, index: 1)
        encoder.setBuffer(outputVector.buffer, offset: outputVector.offset, index: 2)
        encoder.setBytes(&params, length: MemoryLayout<M31VectorParams>.stride, index: 3)
        context.dispatch1D(encoder, pipeline: pipeline, elementCount: count)
        encoder.endEncoding()

        guard let readbackBlit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        readbackBlit.label = "M31.VectorArithmetic.Readback"
        readbackBlit.copy(
            from: outputVector.buffer,
            sourceOffset: outputVector.offset,
            to: outputReadback,
            destinationOffset: 0,
            size: inputByteCount
        )
        readbackBlit.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        return M31VectorArithmeticResult(
            values: Self.readUInt32Buffer(outputReadback, count: count),
            stats: GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpuDuration(commandBuffer))
        )
    }

    private func validateInputs(lhs: [UInt32], rhs: [UInt32]?) throws {
        guard lhs.count == count else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(lhs)
        if operation.requiresRightHandSide {
            guard let rhs, rhs.count == count else {
                throw AppleZKProverError.invalidInputLayout
            }
            try M31Field.validateCanonical(rhs)
        } else if rhs != nil {
            throw AppleZKProverError.invalidInputLayout
        }
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

    private static func readUInt32Buffer(_ buffer: MTLBuffer, count: Int) -> [UInt32] {
        let raw = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        return (0..<count).map { raw[$0] }
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
