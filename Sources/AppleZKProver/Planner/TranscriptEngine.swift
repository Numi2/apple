#if canImport(Metal)
import Foundation
import Metal

private struct TranscriptPackParams {
    var byteCount: UInt32
}

private struct TranscriptAbsorbParams {
    var byteCount: UInt32
}

private struct TranscriptSqueezeParams {
    var challengeCount: UInt32
    var fieldModulus: UInt32
}

public final class TranscriptEngine: @unchecked Sendable {
    public let state: ArenaSlice

    private let context: MetalContext
    private let packPipeline: MTLComputePipelineState
    private let absorbPipeline: MTLComputePipelineState
    private let squeezePipeline: MTLComputePipelineState

    public init(context: MetalContext, arena: ResidencyArena) throws {
        self.context = context
        self.state = try arena.allocate(length: 25 * MemoryLayout<UInt64>.stride, role: .transcriptState)
        self.packPipeline = try context.pipeline(
            for: KernelSpec(kernel: "transcript_pack_bytes", family: .scalar, queueMode: .metal3)
        )
        self.absorbPipeline = try context.pipeline(
            for: KernelSpec(
                kernel: "transcript_absorb_keccak",
                family: .scalar,
                queueMode: .metal3,
                functionConstants: .plannerConstants([
                    (.domainSuffix, 0x06),
                ])
            )
        )
        self.squeezePipeline = try context.pipeline(
            for: KernelSpec(kernel: "transcript_squeeze_challenges", family: .scalar, queueMode: .metal3)
        )
    }

    public func encodeReset(on commandBuffer: MTLCommandBuffer) throws {
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        blit.label = "Transcript.Reset"
        blit.fill(buffer: state.buffer, range: state.offset..<(state.offset + state.length), value: 0)
        blit.endEncoding()
    }

    public func encodeCanonicalPack(
        input: MTLBuffer,
        inputOffset: Int = 0,
        output: ArenaSlice,
        byteCount: Int,
        on commandBuffer: MTLCommandBuffer
    ) throws {
        let byteCount32 = try checkedUInt32(byteCount)
        let inputEnd = inputOffset.addingReportingOverflow(byteCount)
        guard inputOffset >= 0,
              !inputEnd.overflow,
              input.length >= inputEnd.partialValue,
              output.length >= byteCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        guard byteCount > 0 else {
            return
        }

        var params = TranscriptPackParams(byteCount: byteCount32)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "Transcript.Pack"
        encoder.setComputePipelineState(packPipeline)
        encoder.setBuffer(input, offset: inputOffset, index: 0)
        encoder.setBuffer(output.buffer, offset: output.offset, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<TranscriptPackParams>.stride, index: 2)
        context.dispatch1D(encoder, pipeline: packPipeline, elementCount: byteCount)
        encoder.endEncoding()
    }

    public func encodeAbsorb(
        packed: ArenaSlice,
        byteCount: Int,
        on commandBuffer: MTLCommandBuffer
    ) throws {
        let byteCount32 = try checkedUInt32(byteCount)
        guard packed.length >= byteCount else {
            throw AppleZKProverError.invalidInputLayout
        }

        var params = TranscriptAbsorbParams(byteCount: byteCount32)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "Transcript.Absorb"
        encoder.setComputePipelineState(absorbPipeline)
        encoder.setBuffer(packed.buffer, offset: packed.offset, index: 0)
        encoder.setBuffer(state.buffer, offset: state.offset, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<TranscriptAbsorbParams>.stride, index: 2)
        context.dispatch1D(encoder, pipeline: absorbPipeline, elementCount: 1)
        encoder.endEncoding()
    }

    public func encodeSqueezeChallenges(
        output: ArenaSlice,
        challengeCount: Int,
        fieldModulus: UInt32,
        on commandBuffer: MTLCommandBuffer
    ) throws {
        let challengeCount32 = try checkedUInt32(challengeCount)
        let outputBytes = try checkedBufferLength(challengeCount, MemoryLayout<UInt32>.stride)
        guard fieldModulus > 0, output.length >= outputBytes else {
            throw AppleZKProverError.invalidInputLayout
        }
        guard challengeCount > 0 else {
            return
        }
        var params = TranscriptSqueezeParams(
            challengeCount: challengeCount32,
            fieldModulus: fieldModulus
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "Transcript.Squeeze"
        encoder.setComputePipelineState(squeezePipeline)
        encoder.setBuffer(state.buffer, offset: state.offset, index: 0)
        encoder.setBuffer(output.buffer, offset: output.offset, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<TranscriptSqueezeParams>.stride, index: 2)
        context.dispatch1D(encoder, pipeline: squeezePipeline, elementCount: challengeCount)
        encoder.endEncoding()
    }
}
#endif
