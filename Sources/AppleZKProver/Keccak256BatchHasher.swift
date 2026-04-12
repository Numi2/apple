#if canImport(Metal)
import Foundation
import Metal

enum Keccak256OneBlockKernel {
    static func spec(
        forInputLength inputLength: Int,
        family: FixedOneBlockHashKernelFamily = .scalar
    ) -> KernelSpec {
        KernelSpec(
            kernel: family == .simdgroup
                ? "keccak_256_oneblock_simdgroup_specialized"
                : "keccak_256_oneblock_specialized",
            family: family == .simdgroup ? .simdgroup : .scalar,
            queueMode: .metal3,
            functionConstants: .plannerConstants([
                (.leafBytes, UInt64(inputLength)),
                (.domainSuffix, 0x01),
            ])
        )
    }
}

public final class Keccak256BatchHasher: @unchecked Sendable {
    private let context: MetalContext

    public init(context: MetalContext) {
        self.context = context
    }

    public func makeFixedOneBlockPlan(
        descriptor: FixedMessageBatchDescriptor,
        kernelFamily: FixedOneBlockHashKernelFamily = .scalar,
        simdgroupsPerThreadgroup: Int? = nil
    ) throws -> Keccak256FixedOneBlockHashPlan {
        try Keccak256FixedOneBlockHashPlan(
            context: context,
            descriptor: descriptor,
            kernelFamily: kernelFamily,
            simdgroupsPerThreadgroup: simdgroupsPerThreadgroup
        )
    }

    public func hashFixedOneBlock(
        messages: Data,
        descriptor: FixedMessageBatchDescriptor,
        kernelFamily: FixedOneBlockHashKernelFamily = .scalar,
        simdgroupsPerThreadgroup: Int? = nil
    ) throws -> GPUHashBatchResult {
        let plan = try makeFixedOneBlockPlan(
            descriptor: descriptor,
            kernelFamily: kernelFamily,
            simdgroupsPerThreadgroup: simdgroupsPerThreadgroup
        )
        return try plan.hash(messages: messages)
    }
}

public final class Keccak256FixedOneBlockHashPlan: @unchecked Sendable {
    private let context: MetalContext
    private let descriptor: FixedMessageBatchDescriptor
    private let declaredInputLength: Int
    private let outputLength: Int
    private let kernelFamily: FixedOneBlockHashKernelFamily
    public let simdgroupsPerThreadgroup: Int
    private let inputBuffer: MTLBuffer
    private let outputBuffer: MTLBuffer
    private let pipeline: MTLComputePipelineState
    private let executionLock = NSLock()
    private var params: SHA3BatchParams

    init(
        context: MetalContext,
        descriptor: FixedMessageBatchDescriptor,
        kernelFamily: FixedOneBlockHashKernelFamily = .scalar,
        simdgroupsPerThreadgroup requestedSIMDGroupsPerThreadgroup: Int? = nil
    ) throws {
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
        self.kernelFamily = kernelFamily
        self.inputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: declaredInputLength,
            label: "Keccak256.Input"
        )
        self.outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: outputLength,
            label: "Keccak256.Output"
        )
        self.pipeline = try context.pipeline(for: Keccak256OneBlockKernel.spec(
            forInputLength: descriptor.messageLength,
            family: kernelFamily
        ))
        var simdgroupsPerThreadgroup = 1
        if kernelFamily == .simdgroup {
            guard context.capabilities.supportsApple7 || context.capabilities.supportsSIMDReductions else {
                throw AppleZKProverError.unavailableOnThisPlatform
            }
            guard pipeline.threadExecutionWidth >= 25 else {
                throw AppleZKProverError.unavailableOnThisPlatform
            }
            let maxSIMDGroupsPerThreadgroup = context.maxSIMDGroupsPerThreadgroup(for: pipeline)
            if let requestedSIMDGroupsPerThreadgroup {
                guard requestedSIMDGroupsPerThreadgroup > 0,
                      requestedSIMDGroupsPerThreadgroup <= maxSIMDGroupsPerThreadgroup else {
                    throw AppleZKProverError.invalidKernelConfiguration(
                        "SIMD groups per threadgroup must be in 1...\(maxSIMDGroupsPerThreadgroup), got \(requestedSIMDGroupsPerThreadgroup)."
                    )
                }
                simdgroupsPerThreadgroup = requestedSIMDGroupsPerThreadgroup
            } else {
                simdgroupsPerThreadgroup = context.preferredSIMDGroupsPerThreadgroup(for: pipeline)
            }
        } else if let requestedSIMDGroupsPerThreadgroup, requestedSIMDGroupsPerThreadgroup != 1 {
            throw AppleZKProverError.invalidKernelConfiguration(
                "Scalar fixed-hash kernels require one SIMD group per threadgroup, got \(requestedSIMDGroupsPerThreadgroup)."
            )
        }
        self.simdgroupsPerThreadgroup = simdgroupsPerThreadgroup
        self.params = SHA3BatchParams(
            count: count32,
            inputStride: inputStride32,
            inputLength: inputLength32,
            outputStride: outputStride32,
            simdgroupsPerThreadgroup: try checkedUInt32(simdgroupsPerThreadgroup)
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
        commandBuffer.label = "Keccak256.OneBlock"

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "Keccak256.OneBlock.Encode"

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<SHA3BatchParams>.stride, index: 2)
        dispatchHash(encoder)
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

    private func dispatchHash(_ encoder: MTLComputeCommandEncoder) {
        switch kernelFamily {
        case .scalar:
            context.dispatch1D(encoder, pipeline: pipeline, elementCount: descriptor.count)
        case .simdgroup:
            context.dispatchSIMDGroups1D(
                encoder,
                pipeline: pipeline,
                simdgroupCount: descriptor.count,
                simdgroupsPerThreadgroup: Int(params.simdgroupsPerThreadgroup)
            )
        }
    }
}
#endif
