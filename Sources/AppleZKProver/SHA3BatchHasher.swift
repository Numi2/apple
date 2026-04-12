#if canImport(Metal)
import Foundation
import Metal

struct SHA3BatchParams {
    var count: UInt32
    var inputStride: UInt32
    var inputLength: UInt32
    var outputStride: UInt32
}

enum SHA3OneBlockKernel {
    static func spec(forInputLength inputLength: Int) -> KernelSpec {
        KernelSpec(
            kernel: "sha3_256_oneblock_specialized",
            family: .scalar,
            queueMode: .metal3,
            functionConstants: .plannerConstants([
                (.leafBytes, UInt64(inputLength)),
                (.domainSuffix, 0x06),
            ])
        )
    }
}

public final class SHA3BatchHasher: @unchecked Sendable {
    private let context: MetalContext

    public init(context: MetalContext) {
        self.context = context
    }

    public func makeFixedOneBlockPlan(descriptor: FixedMessageBatchDescriptor) throws -> SHA3FixedOneBlockHashPlan {
        try SHA3FixedOneBlockHashPlan(context: context, descriptor: descriptor)
    }

    public func hashFixedOneBlock(messages: Data, descriptor: FixedMessageBatchDescriptor) throws -> GPUHashBatchResult {
        let plan = try makeFixedOneBlockPlan(descriptor: descriptor)
        return try plan.hash(messages: messages)
    }
}

public final class SHA3FixedOneBlockHashPlan: @unchecked Sendable {
    private let context: MetalContext
    private let descriptor: FixedMessageBatchDescriptor
    private let declaredInputLength: Int
    private let outputLength: Int
    private let inputBuffer: MTLBuffer
    private let outputBuffer: MTLBuffer
    private let pipeline: MTLComputePipelineState
    private let executionLock = NSLock()
    private var params: SHA3BatchParams

    init(context: MetalContext, descriptor: FixedMessageBatchDescriptor) throws {
        guard descriptor.messageLength >= 0, descriptor.messageLength <= SHA3Oracle.sha3_256Rate else {
            throw AppleZKProverError.unsupportedOneBlockLength(descriptor.messageLength)
        }
        guard descriptor.count > 0,
              descriptor.messageStride >= descriptor.messageLength,
              descriptor.outputStride >= 32 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let count32 = try checkedUInt32(descriptor.count)
        let inputStride32 = try checkedUInt32(descriptor.messageStride)
        let inputLength32 = try checkedUInt32(descriptor.messageLength)
        let outputStride32 = try checkedUInt32(descriptor.outputStride)

        let declaredInputLength = try checkedBufferLength(descriptor.count, descriptor.messageStride)
        let outputLength = try checkedBufferLength(descriptor.count, descriptor.outputStride)

        self.context = context
        self.descriptor = descriptor
        self.declaredInputLength = declaredInputLength
        self.outputLength = outputLength
        self.inputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: declaredInputLength,
            label: "SHA3.Input"
        )
        self.outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: outputLength,
            label: "SHA3.Output"
        )
        self.pipeline = try context.pipeline(for: SHA3OneBlockKernel.spec(forInputLength: descriptor.messageLength))
        self.params = SHA3BatchParams(
            count: count32,
            inputStride: inputStride32,
            inputLength: inputLength32,
            outputStride: outputStride32
        )
    }

    public func hash(messages: Data) throws -> GPUHashBatchResult {
        executionLock.lock()
        defer { executionLock.unlock() }

        try MetalBufferFactory.copy(messages, into: inputBuffer, byteCount: declaredInputLength)

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "SHA3.OneBlock"

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "SHA3.OneBlock.Encode"

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<SHA3BatchParams>.stride, index: 2)
        context.dispatch1D(encoder, pipeline: pipeline, elementCount: descriptor.count)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let gpu = gpuDuration(commandBuffer)
        let data = Data(bytes: outputBuffer.contents(), count: outputLength)
        return GPUHashBatchResult(digests: data, stats: GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpu))
    }

    public func clearReusableBuffers() {
        executionLock.lock()
        defer { executionLock.unlock() }

        MetalBufferFactory.zeroSharedBuffer(inputBuffer)
        MetalBufferFactory.zeroSharedBuffer(outputBuffer)
    }

    private func gpuDuration(_ commandBuffer: MTLCommandBuffer) -> Double? {
        guard commandBuffer.gpuEndTime > commandBuffer.gpuStartTime else {
            return nil
        }
        return commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    }
}
#endif
