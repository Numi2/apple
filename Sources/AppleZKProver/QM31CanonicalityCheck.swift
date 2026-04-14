import Foundation

#if canImport(Metal)
import Metal

private struct QM31CanonicalityCheckParams {
    var count: UInt32
    var fieldModulus: UInt32
}

public final class QM31CanonicalityCheckPlan: @unchecked Sendable {
    public static let elementByteCount = QM31CanonicalEncoding.elementByteCount

    private let context: MetalContext
    private let pipeline: MTLComputePipelineState
    private let failureFlagBuffer: MTLBuffer
    private let executionLock = NSLock()

    public init(context: MetalContext) throws {
        self.context = context
        self.pipeline = try context.pipeline(
            for: KernelSpec(kernel: "qm31_check_canonical", family: .scalar, queueMode: .metal3)
        )
        self.failureFlagBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: MemoryLayout<UInt32>.stride,
            label: "AppleZKProver.QM31CanonicalityCheck.FailureFlag"
        )
    }

    public func validateResident(
        buffer: MTLBuffer,
        offset: Int = 0,
        count: Int,
        label: String = "QM31.CanonicalityCheck"
    ) throws -> GPUExecutionStats {
        let byteCount = try checkedBufferLength(count, Self.elementByteCount)
        try Self.validateBufferRange(buffer: buffer, offset: offset, byteCount: byteCount)
        guard count >= 0,
              count <= Int(UInt32.max) else {
            throw AppleZKProverError.invalidInputLayout
        }
        guard count > 0 else {
            return GPUExecutionStats(cpuWallSeconds: 0, gpuSeconds: 0)
        }

        executionLock.lock()
        defer { executionLock.unlock() }

        try MetalBufferFactory.zeroSharedBuffer(
            failureFlagBuffer,
            offset: 0,
            byteCount: MemoryLayout<UInt32>.stride
        )

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = label

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "\(label).Scan"
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(buffer, offset: offset, index: 0)
        encoder.setBuffer(failureFlagBuffer, offset: 0, index: 1)
        var params = QM31CanonicalityCheckParams(
            count: try checkedUInt32(count),
            fieldModulus: QM31Field.modulus
        )
        encoder.setBytes(&params, length: MemoryLayout<QM31CanonicalityCheckParams>.stride, index: 2)
        context.dispatch1D(encoder, pipeline: pipeline, elementCount: count)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }
        let end = DispatchTime.now()

        let failed = failureFlagBuffer.contents().load(as: UInt32.self) != 0
        guard !failed else {
            throw AppleZKProverError.invalidInputLayout
        }

        return GPUExecutionStats(
            cpuWallSeconds: Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000,
            gpuSeconds: gpuDuration(commandBuffer)
        )
    }

    private static func validateBufferRange(
        buffer: MTLBuffer,
        offset: Int,
        byteCount: Int
    ) throws {
        let end = offset.addingReportingOverflow(max(1, byteCount))
        guard offset >= 0,
              byteCount >= 0,
              !end.overflow,
              buffer.length >= end.partialValue else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private func gpuDuration(_ commandBuffer: MTLCommandBuffer) -> Double? {
        guard commandBuffer.gpuEndTime > commandBuffer.gpuStartTime else {
            return nil
        }
        return commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    }
}
#endif
