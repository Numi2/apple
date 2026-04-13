#if canImport(Metal)
import Foundation
import Metal

private struct KeccakPermutationParams {
    var count: UInt32
    var inputStride: UInt32
    var outputStride: UInt32
    var simdgroupsPerThreadgroup: UInt32
}

enum KeccakF1600PermutationKernel {
    static func spec(family: KeccakF1600PermutationKernelFamily = .scalar) -> KernelSpec {
        KernelSpec(
            kernel: family == .simdgroup
                ? "keccak_f1600_permutation_simdgroup"
                : "keccak_f1600_permutation_scalar",
            family: family == .simdgroup ? .simdgroup : .scalar,
            queueMode: .metal3
        )
    }
}

public final class KeccakF1600PermutationBatcher: @unchecked Sendable {
    private let context: MetalContext

    public init(context: MetalContext) {
        self.context = context
    }

    public func makePermutationPlan(
        descriptor: KeccakF1600PermutationBatchDescriptor,
        kernelFamily: KeccakF1600PermutationKernelFamily = .scalar,
        simdgroupsPerThreadgroup: Int? = nil
    ) throws -> KeccakF1600PermutationBatchPlan {
        try KeccakF1600PermutationBatchPlan(
            context: context,
            descriptor: descriptor,
            kernelFamily: kernelFamily,
            simdgroupsPerThreadgroup: simdgroupsPerThreadgroup
        )
    }

    public func permute(
        states: Data,
        descriptor: KeccakF1600PermutationBatchDescriptor,
        kernelFamily: KeccakF1600PermutationKernelFamily = .scalar,
        simdgroupsPerThreadgroup: Int? = nil
    ) throws -> KeccakF1600PermutationBatchResult {
        let plan = try makePermutationPlan(
            descriptor: descriptor,
            kernelFamily: kernelFamily,
            simdgroupsPerThreadgroup: simdgroupsPerThreadgroup
        )
        return try plan.permute(states: states)
    }

    public func permuteVerified(
        states: Data,
        descriptor: KeccakF1600PermutationBatchDescriptor,
        kernelFamily: KeccakF1600PermutationKernelFamily = .scalar,
        simdgroupsPerThreadgroup: Int? = nil
    ) throws -> KeccakF1600PermutationBatchResult {
        let plan = try makePermutationPlan(
            descriptor: descriptor,
            kernelFamily: kernelFamily,
            simdgroupsPerThreadgroup: simdgroupsPerThreadgroup
        )
        return try plan.permuteVerified(states: states)
    }
}

public final class KeccakF1600PermutationBatchPlan: @unchecked Sendable {
    private let context: MetalContext
    private let descriptor: KeccakF1600PermutationBatchDescriptor
    private let declaredInputLength: Int
    private let outputLength: Int
    private let kernelFamily: KeccakF1600PermutationKernelFamily
    public let simdgroupsPerThreadgroup: Int
    private let inputRing: SharedUploadRing
    private let outputBuffer: MTLBuffer
    private let pipeline: MTLComputePipelineState
    private let executionLock = NSLock()
    private var params: KeccakPermutationParams

    init(
        context: MetalContext,
        descriptor: KeccakF1600PermutationBatchDescriptor,
        kernelFamily: KeccakF1600PermutationKernelFamily = .scalar,
        simdgroupsPerThreadgroup requestedSIMDGroupsPerThreadgroup: Int? = nil,
        uploadRingSlotCount: Int = 3
    ) throws {
        try Self.validate(descriptor)
        guard uploadRingSlotCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }

        let count32 = try checkedUInt32(descriptor.count)
        let inputStride32 = try checkedUInt32(descriptor.inputStride)
        let outputStride32 = try checkedUInt32(descriptor.outputStride)
        let declaredInputLength = try checkedBufferLength(descriptor.count, descriptor.inputStride)
        let outputLength = try checkedBufferLength(descriptor.count, descriptor.outputStride)

        self.context = context
        self.descriptor = descriptor
        self.declaredInputLength = declaredInputLength
        self.outputLength = outputLength
        self.kernelFamily = kernelFamily
        self.inputRing = try SharedUploadRing(
            device: context.device,
            slotCapacity: declaredInputLength,
            slotCount: uploadRingSlotCount,
            label: "KeccakF1600Permutation.InputRing"
        )
        self.outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: outputLength,
            label: "KeccakF1600Permutation.Output"
        )
        self.pipeline = try context.pipeline(for: KeccakF1600PermutationKernel.spec(family: kernelFamily))

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
                "Scalar Keccak-F1600 permutation kernels require one SIMD group per threadgroup, got \(requestedSIMDGroupsPerThreadgroup)."
            )
        }

        self.simdgroupsPerThreadgroup = simdgroupsPerThreadgroup
        self.params = KeccakPermutationParams(
            count: count32,
            inputStride: inputStride32,
            outputStride: outputStride32,
            simdgroupsPerThreadgroup: try checkedUInt32(simdgroupsPerThreadgroup)
        )
    }

    public func permute(states: Data) throws -> KeccakF1600PermutationBatchResult {
        executionLock.lock()
        defer { executionLock.unlock() }

        let slot = try inputRing.copy(states, byteCount: declaredInputLength)
        if descriptor.outputStride > KeccakF1600PermutationBatchDescriptor.stateByteCount {
            MetalBufferFactory.zeroSharedBuffer(outputBuffer)
        }

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "KeccakF1600Permutation.Batch"

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "KeccakF1600Permutation.Encode"
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(slot.buffer, offset: slot.offset, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<KeccakPermutationParams>.stride, index: 2)
        dispatchPermutation(encoder)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let output = Data(bytes: outputBuffer.contents(), count: outputLength)
        return KeccakF1600PermutationBatchResult(
            states: output,
            stats: GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpuDuration(commandBuffer))
        )
    }

    public func permuteVerified(states: Data) throws -> KeccakF1600PermutationBatchResult {
        let result = try permute(states: states)
        try verifyCPU(states: states, result: result)
        return result
    }

    public func clearReusableBuffers() {
        executionLock.lock()
        defer { executionLock.unlock() }

        inputRing.clear()
        MetalBufferFactory.zeroSharedBuffer(outputBuffer)
    }

    private static func validate(_ descriptor: KeccakF1600PermutationBatchDescriptor) throws {
        guard descriptor.count > 0,
              descriptor.inputStride >= KeccakF1600PermutationBatchDescriptor.stateByteCount,
              descriptor.outputStride >= KeccakF1600PermutationBatchDescriptor.stateByteCount,
              descriptor.inputStride.isMultiple(of: MemoryLayout<UInt64>.stride),
              descriptor.outputStride.isMultiple(of: MemoryLayout<UInt64>.stride) else {
            throw AppleZKProverError.invalidInputLayout
        }
        _ = try checkedUInt32(descriptor.count)
    }

    private func dispatchPermutation(_ encoder: MTLComputeCommandEncoder) {
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

    private func gpuDuration(_ commandBuffer: MTLCommandBuffer) -> Double? {
        guard commandBuffer.gpuEndTime > commandBuffer.gpuStartTime else {
            return nil
        }
        return commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    }

    private func verifyCPU(
        states: Data,
        result: KeccakF1600PermutationBatchResult
    ) throws {
        guard states.count >= declaredInputLength,
              result.states.count >= outputLength else {
            throw AppleZKProverError.invalidInputLayout
        }

        for index in 0..<descriptor.count {
            let inputByteOffset = index * descriptor.inputStride
            let outputByteOffset = index * descriptor.outputStride
            let inputWords = try Self.readStateWords(
                states,
                offset: inputByteOffset
            )
            let expected = try SHA3Oracle.keccakF1600Permutation(inputWords)
            let actual = try Self.readStateWords(
                result.states,
                offset: outputByteOffset
            )
            guard actual == expected else {
                throw AppleZKProverError.correctnessValidationFailed(
                    "Keccak-F1600 GPU permutation did not match the CPU oracle at state \(index)."
                )
            }
        }
    }

    private static func readStateWords(_ data: Data, offset: Int) throws -> [UInt64] {
        let stateByteCount = KeccakF1600PermutationBatchDescriptor.stateByteCount
        let end = offset.addingReportingOverflow(stateByteCount)
        guard offset >= 0,
              !end.overflow,
              data.count >= end.partialValue else {
            throw AppleZKProverError.invalidInputLayout
        }
        var words: [UInt64] = []
        words.reserveCapacity(25)
        for wordIndex in 0..<25 {
            let base = offset + wordIndex * MemoryLayout<UInt64>.stride
            var word: UInt64 = 0
            for byteIndex in 0..<MemoryLayout<UInt64>.stride {
                word |= UInt64(data[base + byteIndex]) << UInt64(byteIndex * 8)
            }
            words.append(word)
        }
        return words
    }
}
#endif
