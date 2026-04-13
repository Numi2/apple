#if canImport(Metal)
import Foundation
import Metal

private struct TranscriptPackWordsParams {
    var wordCount: UInt32
}

private struct SumcheckParams {
    var laneCount: UInt32
    var challenge: UInt32
    var fieldModulus: UInt32
}

private struct TranscriptFrameUpload {
    let buffer: MTLBuffer
    let byteCount: Int
}

public struct SumcheckChunkDescriptor: Hashable, Sendable {
    public let laneCount: Int
    public let roundsPerSuperstep: Int

    public init(laneCount: Int, roundsPerSuperstep: Int) {
        self.laneCount = laneCount
        self.roundsPerSuperstep = roundsPerSuperstep
    }
}

public struct SumcheckChunkMeasurement: Sendable {
    public let result: SumcheckChunkOracleResult
    public let stats: GPUExecutionStats
    public let cpuSubmitNS: Double

    public init(result: SumcheckChunkOracleResult, stats: GPUExecutionStats, cpuSubmitNS: Double) {
        self.result = result
        self.stats = stats
        self.cpuSubmitNS = cpuSubmitNS
    }
}

public final class MetalSumcheckChunkPlan: @unchecked Sendable {
    private static let defaultUploadRingSlotCount = 3

    public let descriptor: SumcheckChunkDescriptor
    public let executionPlan: ExecutionPlan

    private let context: MetalContext
    private let arena: ResidencyArena
    private let transcript: TranscriptEngine
    private let roundEvalPipeline: MTLComputePipelineState
    private let packWordsPipeline: MTLComputePipelineState
    private let foldPipeline: MTLComputePipelineState
    private let uploadRing: SharedUploadRing
    private let finalReadback: MTLBuffer
    private let coefficientReadback: MTLBuffer
    private let challengeReadback: MTLBuffer
    private let transcriptHeaderFrame: TranscriptFrameUpload
    private let transcriptRoundFrames: [TranscriptFrameUpload]
    private let transcriptChallengeFrames: [TranscriptFrameUpload]
    private let currentVector: ArenaSlice
    private let nextVector: ArenaSlice
    private let coefficientLog: ArenaSlice
    private let packedScratch: ArenaSlice
    private let challengeScratch: ArenaSlice
    private let challengeLog: ArenaSlice
    private let inputByteCount: Int
    private let totalCoefficientWords: Int
    private let finalLaneCount: Int
    private let executionLock = NSLock()

    public init(context: MetalContext, descriptor: SumcheckChunkDescriptor) throws {
        try Self.validate(descriptor)

        self.context = context
        self.descriptor = descriptor
        let inputByteCount = try checkedBufferLength(descriptor.laneCount, MemoryLayout<UInt32>.stride)
        let totalCoefficientWords = try Self.totalCoefficientWords(
            laneCount: descriptor.laneCount,
            rounds: descriptor.roundsPerSuperstep
        )
        let finalLaneCount = descriptor.laneCount >> descriptor.roundsPerSuperstep
        self.inputByteCount = inputByteCount
        self.totalCoefficientWords = totalCoefficientWords
        self.finalLaneCount = finalLaneCount

        let coefficientBytes = try checkedBufferLength(totalCoefficientWords, MemoryLayout<UInt32>.stride)
        let challengeBytes = try checkedBufferLength(descriptor.roundsPerSuperstep, MemoryLayout<UInt32>.stride)
        let vectorBytes = inputByteCount
        let frameData = try Self.makeTranscriptFrames(descriptor: descriptor)
        let maxFrameBytes = frameData.all.map(\.count).max() ?? 0
        let packedScratchBytes = max(vectorBytes, maxFrameBytes)
        let arenaBytes = try Self.checkedSum([
            vectorBytes,
            vectorBytes,
            coefficientBytes,
            packedScratchBytes,
            challengeBytes,
            MemoryLayout<UInt32>.stride,
            25 * MemoryLayout<UInt64>.stride,
            4096,
        ])

        self.arena = try ResidencyArena(
            device: context.device,
            capacity: arenaBytes,
            label: "AppleZKProver.SumcheckArena"
        )
        self.currentVector = try arena.allocate(length: vectorBytes, role: .sumcheckVector)
        self.nextVector = try arena.allocate(length: vectorBytes, role: .sumcheckVector)
        self.coefficientLog = try arena.allocate(length: coefficientBytes, role: .coefficients)
        self.packedScratch = try arena.allocate(length: packedScratchBytes, role: .scratch)
        self.challengeScratch = try arena.allocate(length: MemoryLayout<UInt32>.stride, role: .challenges)
        self.challengeLog = try arena.allocate(length: challengeBytes, role: .challenges)
        self.transcript = try TranscriptEngine(context: context, arena: arena)
        self.transcriptHeaderFrame = try Self.makeFrameUpload(
            device: context.device,
            data: frameData.header,
            label: "AppleZKProver.SumcheckTranscriptHeader"
        )
        self.transcriptRoundFrames = try frameData.rounds.enumerated().map { index, data in
            try Self.makeFrameUpload(
                device: context.device,
                data: data,
                label: "AppleZKProver.SumcheckRoundFrame.\(index)"
            )
        }
        self.transcriptChallengeFrames = try frameData.challenges.enumerated().map { index, data in
            try Self.makeFrameUpload(
                device: context.device,
                data: data,
                label: "AppleZKProver.SumcheckChallengeFrame.\(index)"
            )
        }

        self.roundEvalPipeline = try context.pipeline(
            for: KernelSpec(
                kernel: "sumcheck_round_eval_u32",
                family: .scalar,
                queueMode: .metal3,
                functionConstants: .plannerConstants([
                    (.sumcheckMode, 0),
                    (.barrierCadence, 1),
                ])
            )
        )
        self.packWordsPipeline = try context.pipeline(
            for: KernelSpec(kernel: "transcript_pack_u32_words", family: .scalar, queueMode: .metal3)
        )
        self.foldPipeline = try context.pipeline(
            for: KernelSpec(
                kernel: "sumcheck_fold_halve_u32",
                family: .scalar,
                queueMode: .metal3,
                functionConstants: .plannerConstants([
                    (.sumcheckMode, 0),
                    (.barrierCadence, 1),
                ])
            )
        )

        self.uploadRing = try SharedUploadRing(
            device: context.device,
            slotCapacity: inputByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.SumcheckUploadRing"
        )
        self.finalReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: finalLaneCount * MemoryLayout<UInt32>.stride,
            label: "AppleZKProver.SumcheckFinalReadback"
        )
        self.coefficientReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: coefficientBytes,
            label: "AppleZKProver.SumcheckCoefficientReadback"
        )
        self.challengeReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: challengeBytes,
            label: "AppleZKProver.SumcheckChallengeReadback"
        )

        self.executionPlan = ExecutionPlan(
            workload: WorkloadSignature(
                stage: .sumcheckChunk,
                field: .m31,
                inputLog2: UInt8(clamping: Self.log2(descriptor.laneCount)),
                leafBytes: 0,
                arity: 2,
                roundsPerSuperstep: UInt8(clamping: descriptor.roundsPerSuperstep),
                fixedWidthCase: 0
            ),
            queueMode: .metal3,
            kernels: [
                KernelSpec(kernel: "sumcheck_round_eval_u32", family: .scalar, queueMode: .metal3),
                KernelSpec(kernel: "transcript_pack_u32_words", family: .scalar, queueMode: .metal3),
                KernelSpec(kernel: "transcript_absorb_keccak", family: .scalar, queueMode: .metal3),
                KernelSpec(kernel: "transcript_squeeze_challenges", family: .scalar, queueMode: .metal3),
                KernelSpec(kernel: "sumcheck_fold_halve_u32", family: .scalar, queueMode: .metal3),
            ],
            bufferLayout: ExecutionPlan.BufferLayout(
                uploadBytes: inputByteCount,
                privateArenaBytes: arena.capacity,
                readbackBytes: finalReadback.length + coefficientReadback.length + challengeReadback.length
            ),
            commandBufferChunks: 1,
            readbackPoints: [.finalProofBytes]
        )
    }

    public func execute(evaluations: [UInt32]) throws -> SumcheckChunkMeasurement {
        try validateCanonicalEvaluations(evaluations)
        let bytes = Self.packLittleEndian(evaluations)

        executionLock.lock()
        defer { executionLock.unlock() }

        let slot = try uploadRing.copy(bytes, byteCount: inputByteCount)
        return try executeLocked(inputBuffer: slot.buffer, inputOffset: slot.offset)
    }

    public func executeVerified(evaluations: [UInt32]) throws -> SumcheckChunkMeasurement {
        let expected = try SumcheckOracle.m31Chunk(
            evaluations: evaluations,
            rounds: descriptor.roundsPerSuperstep
        )
        let measured = try execute(evaluations: evaluations)
        guard measured.result == expected else {
            throw AppleZKProverError.correctnessValidationFailed("M31 sum-check GPU chunk did not match the CPU oracle.")
        }
        return measured
    }

    public func executeUploadedVector(
        buffer: MTLBuffer,
        offset: Int = 0
    ) throws -> SumcheckChunkMeasurement {
        executionLock.lock()
        defer { executionLock.unlock() }

        return try executeLocked(inputBuffer: buffer, inputOffset: offset)
    }

    public func clearReusableBuffers() throws {
        executionLock.lock()
        defer { executionLock.unlock() }

        uploadRing.clear()
        MetalBufferFactory.zeroSharedBuffer(finalReadback)
        MetalBufferFactory.zeroSharedBuffer(coefficientReadback)
        MetalBufferFactory.zeroSharedBuffer(challengeReadback)
        try MetalBufferFactory.zeroPrivateBuffers(
            [arena.buffer],
            context: context,
            label: "Sumcheck.PlanClear"
        )
    }

    private func executeLocked(inputBuffer: MTLBuffer, inputOffset: Int) throws -> SumcheckChunkMeasurement {
        let inputEnd = inputOffset.addingReportingOverflow(max(1, inputByteCount))
        guard inputOffset >= 0,
              !inputEnd.overflow,
              inputBuffer.length >= inputEnd.partialValue else {
            throw AppleZKProverError.invalidInputLayout
        }

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "Sumcheck.Chunk"

        guard let uploadBlit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        uploadBlit.label = "Sumcheck.UploadToPrivate"
        uploadBlit.copy(
            from: inputBuffer,
            sourceOffset: inputOffset,
            to: currentVector.buffer,
            destinationOffset: currentVector.offset,
            size: inputByteCount
        )
        uploadBlit.fill(buffer: nextVector.buffer, range: nextVector.offset..<(nextVector.offset + nextVector.length), value: 0)
        uploadBlit.fill(buffer: coefficientLog.buffer, range: coefficientLog.offset..<(coefficientLog.offset + coefficientLog.length), value: 0)
        uploadBlit.fill(buffer: challengeLog.buffer, range: challengeLog.offset..<(challengeLog.offset + challengeLog.length), value: 0)
        uploadBlit.endEncoding()

        try transcript.encodeReset(on: commandBuffer)
        try encodeTranscriptFrame(transcriptHeaderFrame, on: commandBuffer)

        var activeLaneCount = descriptor.laneCount
        var current = currentVector
        var next = nextVector
        var coefficientOffsetBytes = 0

        for round in 0..<descriptor.roundsPerSuperstep {
            let coefficientWordCount = activeLaneCount
            let coefficientByteCount = coefficientWordCount * MemoryLayout<UInt32>.stride
            try encodeRoundEval(
                current: current,
                coefficientOffsetBytes: coefficientOffsetBytes,
                activeLaneCount: activeLaneCount,
                on: commandBuffer
            )
            try encodeTranscriptFrame(transcriptRoundFrames[round], on: commandBuffer)
            try encodePackWords(
                coefficientOffsetBytes: coefficientOffsetBytes,
                wordCount: coefficientWordCount,
                on: commandBuffer
            )
            try transcript.encodeAbsorb(
                packed: packedScratch,
                byteCount: coefficientByteCount,
                on: commandBuffer
            )
            try encodeTranscriptFrame(transcriptChallengeFrames[round], on: commandBuffer)
            try transcript.encodeSqueezeChallenges(
                output: challengeScratch,
                challengeCount: 1,
                fieldModulus: M31Field.modulus,
                on: commandBuffer
            )

            guard let challengeBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            challengeBlit.label = "Sumcheck.ChallengeLog.\(round)"
            challengeBlit.copy(
                from: challengeScratch.buffer,
                sourceOffset: challengeScratch.offset,
                to: challengeLog.buffer,
                destinationOffset: challengeLog.offset + round * MemoryLayout<UInt32>.stride,
                size: MemoryLayout<UInt32>.stride
            )
            challengeBlit.endEncoding()

            try encodeFold(
                current: current,
                next: next,
                activeLaneCount: activeLaneCount,
                on: commandBuffer
            )

            coefficientOffsetBytes += coefficientByteCount
            activeLaneCount >>= 1
            swap(&current, &next)
        }

        guard let readbackBlit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        readbackBlit.label = "Sumcheck.FinalReadback"
        readbackBlit.copy(
            from: current.buffer,
            sourceOffset: current.offset,
            to: finalReadback,
            destinationOffset: 0,
            size: finalLaneCount * MemoryLayout<UInt32>.stride
        )
        readbackBlit.copy(
            from: coefficientLog.buffer,
            sourceOffset: coefficientLog.offset,
            to: coefficientReadback,
            destinationOffset: 0,
            size: coefficientLog.length
        )
        readbackBlit.copy(
            from: challengeLog.buffer,
            sourceOffset: challengeLog.offset,
            to: challengeReadback,
            destinationOffset: 0,
            size: challengeLog.length
        )
        readbackBlit.endEncoding()

        let submitStart = DispatchTime.now()
        commandBuffer.commit()
        let submitEnd = DispatchTime.now()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let result = SumcheckChunkOracleResult(
            finalVector: Self.readUInt32Buffer(finalReadback, count: finalLaneCount),
            coefficients: Self.readUInt32Buffer(coefficientReadback, count: totalCoefficientWords),
            challenges: Self.readUInt32Buffer(challengeReadback, count: descriptor.roundsPerSuperstep)
        )
        return SumcheckChunkMeasurement(
            result: result,
            stats: GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpuDuration(commandBuffer)),
            cpuSubmitNS: Double(submitEnd.uptimeNanoseconds - submitStart.uptimeNanoseconds)
        )
    }

    private func encodeRoundEval(
        current: ArenaSlice,
        coefficientOffsetBytes: Int,
        activeLaneCount: Int,
        on commandBuffer: MTLCommandBuffer
    ) throws {
        var params = SumcheckParams(
            laneCount: try checkedUInt32(activeLaneCount),
            challenge: 0,
            fieldModulus: M31Field.modulus
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "Sumcheck.RoundEval.\(activeLaneCount)"
        encoder.setComputePipelineState(roundEvalPipeline)
        encoder.setBuffer(current.buffer, offset: current.offset, index: 0)
        encoder.setBuffer(coefficientLog.buffer, offset: coefficientLog.offset + coefficientOffsetBytes, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<SumcheckParams>.stride, index: 2)
        context.dispatch1D(encoder, pipeline: roundEvalPipeline, elementCount: activeLaneCount / 2)
        encoder.endEncoding()
    }

    private func encodePackWords(
        coefficientOffsetBytes: Int,
        wordCount: Int,
        on commandBuffer: MTLCommandBuffer
    ) throws {
        var params = TranscriptPackWordsParams(wordCount: try checkedUInt32(wordCount))
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "Sumcheck.CoeffPack.\(wordCount)"
        encoder.setComputePipelineState(packWordsPipeline)
        encoder.setBuffer(coefficientLog.buffer, offset: coefficientLog.offset + coefficientOffsetBytes, index: 0)
        encoder.setBuffer(packedScratch.buffer, offset: packedScratch.offset, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<TranscriptPackWordsParams>.stride, index: 2)
        context.dispatch1D(encoder, pipeline: packWordsPipeline, elementCount: wordCount)
        encoder.endEncoding()
    }

    private func encodeFold(
        current: ArenaSlice,
        next: ArenaSlice,
        activeLaneCount: Int,
        on commandBuffer: MTLCommandBuffer
    ) throws {
        var params = SumcheckParams(
            laneCount: try checkedUInt32(activeLaneCount),
            challenge: 0,
            fieldModulus: M31Field.modulus
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "Sumcheck.Fold.\(activeLaneCount)"
        encoder.setComputePipelineState(foldPipeline)
        encoder.setBuffer(current.buffer, offset: current.offset, index: 0)
        encoder.setBuffer(challengeScratch.buffer, offset: challengeScratch.offset, index: 1)
        encoder.setBuffer(next.buffer, offset: next.offset, index: 2)
        encoder.setBytes(&params, length: MemoryLayout<SumcheckParams>.stride, index: 3)
        context.dispatch1D(encoder, pipeline: foldPipeline, elementCount: activeLaneCount / 2)
        encoder.endEncoding()
    }

    private func encodeTranscriptFrame(
        _ frame: TranscriptFrameUpload,
        on commandBuffer: MTLCommandBuffer
    ) throws {
        try transcript.encodeCanonicalPack(
            input: frame.buffer,
            output: packedScratch,
            byteCount: frame.byteCount,
            on: commandBuffer
        )
        try transcript.encodeAbsorb(
            packed: packedScratch,
            byteCount: frame.byteCount,
            on: commandBuffer
        )
    }

    private func validateCanonicalEvaluations(_ evaluations: [UInt32]) throws {
        guard evaluations.count == descriptor.laneCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(evaluations)
    }

    private static func validate(_ descriptor: SumcheckChunkDescriptor) throws {
        guard descriptor.laneCount > 1,
              descriptor.laneCount.nonzeroBitCount == 1,
              descriptor.roundsPerSuperstep > 0,
              descriptor.roundsPerSuperstep <= log2(descriptor.laneCount),
              descriptor.laneCount <= Int(UInt32.max) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private static func totalCoefficientWords(laneCount: Int, rounds: Int) throws -> Int {
        var active = laneCount
        var total = 0
        for _ in 0..<rounds {
            let next = total.addingReportingOverflow(active)
            guard !next.overflow else {
                throw AppleZKProverError.invalidInputLayout
            }
            total = next.partialValue
            active >>= 1
        }
        return total
    }

    private static func makeTranscriptFrames(
        descriptor: SumcheckChunkDescriptor
    ) throws -> (header: Data, rounds: [Data], challenges: [Data], all: [Data]) {
        let header = try SumcheckTranscriptFraming.header(
            laneCount: descriptor.laneCount,
            rounds: descriptor.roundsPerSuperstep,
            fieldModulus: M31Field.modulus
        )
        var roundFrames: [Data] = []
        var challengeFrames: [Data] = []
        roundFrames.reserveCapacity(descriptor.roundsPerSuperstep)
        challengeFrames.reserveCapacity(descriptor.roundsPerSuperstep)

        var activeLaneCount = descriptor.laneCount
        for round in 0..<descriptor.roundsPerSuperstep {
            roundFrames.append(try SumcheckTranscriptFraming.round(
                roundIndex: round,
                activeLaneCount: activeLaneCount,
                coefficientWordCount: activeLaneCount
            ))
            challengeFrames.append(try SumcheckTranscriptFraming.challenge(
                roundIndex: round,
                fieldModulus: M31Field.modulus
            ))
            activeLaneCount >>= 1
        }

        return (header, roundFrames, challengeFrames, [header] + roundFrames + challengeFrames)
    }

    private static func makeFrameUpload(
        device: MTLDevice,
        data: Data,
        label: String
    ) throws -> TranscriptFrameUpload {
        let buffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: data,
            declaredLength: data.count,
            label: label
        )
        return TranscriptFrameUpload(buffer: buffer, byteCount: data.count)
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
        guard count > 0 else {
            return []
        }
        let raw = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        return (0..<count).map { raw[$0] }
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
