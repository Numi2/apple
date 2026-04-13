import Foundation

public enum QM31FRIFoldOracle {
    public static let inverseTwo = QM31Element(
        a: 1_073_741_824,
        b: 0,
        c: 0,
        d: 0
    )

    public static func fold(
        evaluations: [QM31Element],
        inverseDomainPoints: [QM31Element],
        challenge: QM31Element
    ) throws -> [QM31Element] {
        guard evaluations.count > 1,
              evaluations.count.isMultiple(of: 2),
              inverseDomainPoints.count == evaluations.count / 2 else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        try QM31Field.validateCanonical(inverseDomainPoints)
        try QM31Field.validateCanonical([challenge])
        guard inverseDomainPoints.allSatisfy({ !QM31Field.isZero($0) }) else {
            throw AppleZKProverError.invalidInputLayout
        }

        let pairCount = evaluations.count / 2
        var folded: [QM31Element] = []
        folded.reserveCapacity(pairCount)
        for index in 0..<pairCount {
            let positive = evaluations[index * 2]
            let negative = evaluations[index * 2 + 1]
            let evenNumerator = QM31Field.add(positive, negative)
            let oddNumerator = QM31Field.subtract(positive, negative)
            let oddAtSquare = QM31Field.multiply(oddNumerator, inverseDomainPoints[index])
            let mixed = QM31Field.add(
                evenNumerator,
                QM31Field.multiply(challenge, oddAtSquare)
            )
            folded.append(QM31Field.multiply(mixed, inverseTwo))
        }
        return folded
    }
}

#if canImport(Metal)
import Metal

private struct QM31FRIFoldParams {
    var pairCount: UInt32
    var fieldModulus: UInt32
    var challengeA: UInt32
    var challengeB: UInt32
    var challengeC: UInt32
    var challengeD: UInt32
}

public struct QM31FRIFoldResult: Sendable {
    public let values: [QM31Element]
    public let stats: GPUExecutionStats

    public init(values: [QM31Element], stats: GPUExecutionStats) {
        self.values = values
        self.stats = stats
    }
}

public final class QM31FRIFoldPlan: @unchecked Sendable {
    private static let defaultUploadRingSlotCount = 3
    private static let elementByteCount = 4 * MemoryLayout<UInt32>.stride

    public let inputCount: Int
    public let outputCount: Int

    private let context: MetalContext
    private let pipeline: MTLComputePipelineState
    private let uploadRingEvaluations: SharedUploadRing
    private let uploadRingInverseDomain: SharedUploadRing
    private let arena: ResidencyArena
    private let evaluationVector: ArenaSlice
    private let inverseDomainVector: ArenaSlice
    private let outputVector: ArenaSlice
    private let outputReadback: MTLBuffer
    private let inputByteCount: Int
    private let outputByteCount: Int
    private let executionLock = NSLock()

    public init(context: MetalContext, inputCount: Int) throws {
        guard inputCount > 1,
              inputCount.isMultiple(of: 2),
              inputCount <= Int(UInt32.max) else {
            throw AppleZKProverError.invalidInputLayout
        }

        self.context = context
        self.inputCount = inputCount
        self.outputCount = inputCount / 2
        self.inputByteCount = try checkedBufferLength(inputCount, Self.elementByteCount)
        self.outputByteCount = try checkedBufferLength(inputCount / 2, Self.elementByteCount)
        self.pipeline = try context.pipeline(
            for: KernelSpec(kernel: "qm31_fri_fold", family: .scalar, queueMode: .metal3)
        )
        self.uploadRingEvaluations = try SharedUploadRing(
            device: context.device,
            slotCapacity: inputByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.QM31FRIFoldEvaluations"
        )
        self.uploadRingInverseDomain = try SharedUploadRing(
            device: context.device,
            slotCapacity: outputByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.QM31FRIFoldInverseDomain"
        )
        self.arena = try ResidencyArena(
            device: context.device,
            capacity: try Self.checkedSum([
                inputByteCount,
                outputByteCount,
                outputByteCount,
                3 * 256,
            ]),
            label: "AppleZKProver.QM31FRIFoldArena"
        )
        self.evaluationVector = try arena.allocate(length: inputByteCount, role: .sumcheckVector)
        self.inverseDomainVector = try arena.allocate(length: outputByteCount, role: .sumcheckVector)
        self.outputVector = try arena.allocate(length: outputByteCount, role: .sumcheckVector)
        self.outputReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: outputByteCount,
            label: "AppleZKProver.QM31FRIFoldReadback"
        )
    }

    public func execute(
        evaluations: [QM31Element],
        inverseDomainPoints: [QM31Element],
        challenge: QM31Element
    ) throws -> QM31FRIFoldResult {
        try validateInputs(
            evaluations: evaluations,
            inverseDomainPoints: inverseDomainPoints,
            challenge: challenge
        )
        let evaluationBytes = Self.packLittleEndian(evaluations)
        let inverseDomainBytes = Self.packLittleEndian(inverseDomainPoints)

        executionLock.lock()
        defer { executionLock.unlock() }

        let evaluationSlot = try uploadRingEvaluations.copy(evaluationBytes, byteCount: inputByteCount)
        let inverseDomainSlot = try uploadRingInverseDomain.copy(inverseDomainBytes, byteCount: outputByteCount)
        return try executeLocked(
            evaluationsBuffer: evaluationSlot.buffer,
            evaluationsOffset: evaluationSlot.offset,
            inverseDomainBuffer: inverseDomainSlot.buffer,
            inverseDomainOffset: inverseDomainSlot.offset,
            outputBuffer: outputVector.buffer,
            outputOffset: outputVector.offset,
            challenge: challenge,
            readOutput: true
        )
    }

    public func executeVerified(
        evaluations: [QM31Element],
        inverseDomainPoints: [QM31Element],
        challenge: QM31Element
    ) throws -> QM31FRIFoldResult {
        let expected = try QM31FRIFoldOracle.fold(
            evaluations: evaluations,
            inverseDomainPoints: inverseDomainPoints,
            challenge: challenge
        )
        let measured = try execute(
            evaluations: evaluations,
            inverseDomainPoints: inverseDomainPoints,
            challenge: challenge
        )
        guard measured.values == expected else {
            throw AppleZKProverError.correctnessValidationFailed("QM31 FRI fold GPU result did not match the CPU oracle.")
        }
        return measured
    }

    public func executeResident(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int = 0,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int = 0,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0,
        challenge: QM31Element
    ) throws -> GPUExecutionStats {
        try QM31Field.validateCanonical([challenge])

        executionLock.lock()
        defer { executionLock.unlock() }

        let result = try executeLocked(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: inverseDomainOffset,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset,
            challenge: challenge,
            readOutput: false
        )
        return result.stats
    }

    public func clearReusableBuffers() throws {
        executionLock.lock()
        defer { executionLock.unlock() }

        uploadRingEvaluations.clear()
        uploadRingInverseDomain.clear()
        MetalBufferFactory.zeroSharedBuffer(outputReadback)
        try MetalBufferFactory.zeroPrivateBuffers(
            [arena.buffer],
            context: context,
            label: "QM31FRIFold.PlanClear"
        )
    }

    private func executeLocked(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int,
        challenge: QM31Element,
        readOutput: Bool
    ) throws -> QM31FRIFoldResult {
        try validateBufferRange(buffer: evaluationsBuffer, offset: evaluationsOffset, byteCount: inputByteCount)
        try validateBufferRange(buffer: inverseDomainBuffer, offset: inverseDomainOffset, byteCount: outputByteCount)
        try validateBufferRange(buffer: outputBuffer, offset: outputOffset, byteCount: outputByteCount)
        try validateNoOutputAliasing(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: inverseDomainOffset,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset
        )

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "QM31.FRI.Fold"

        var kernelInputBuffer = evaluationsBuffer
        var kernelInputOffset = evaluationsOffset
        var kernelInverseBuffer = inverseDomainBuffer
        var kernelInverseOffset = inverseDomainOffset
        var kernelOutputBuffer = outputBuffer
        var kernelOutputOffset = outputOffset

        if readOutput {
            guard let uploadBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            uploadBlit.label = "QM31.FRI.Fold.Upload"
            uploadBlit.copy(
                from: evaluationsBuffer,
                sourceOffset: evaluationsOffset,
                to: evaluationVector.buffer,
                destinationOffset: evaluationVector.offset,
                size: inputByteCount
            )
            uploadBlit.copy(
                from: inverseDomainBuffer,
                sourceOffset: inverseDomainOffset,
                to: inverseDomainVector.buffer,
                destinationOffset: inverseDomainVector.offset,
                size: outputByteCount
            )
            uploadBlit.fill(buffer: outputVector.buffer, range: outputVector.offset..<(outputVector.offset + outputVector.length), value: 0)
            uploadBlit.endEncoding()
            kernelInputBuffer = evaluationVector.buffer
            kernelInputOffset = evaluationVector.offset
            kernelInverseBuffer = inverseDomainVector.buffer
            kernelInverseOffset = inverseDomainVector.offset
            kernelOutputBuffer = outputVector.buffer
            kernelOutputOffset = outputVector.offset
        }

        var params = QM31FRIFoldParams(
            pairCount: try checkedUInt32(outputCount),
            fieldModulus: QM31Field.modulus,
            challengeA: challenge.constant.real,
            challengeB: challenge.constant.imaginary,
            challengeC: challenge.uCoefficient.real,
            challengeD: challenge.uCoefficient.imaginary
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "QM31.FRI.Fold.Kernel"
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(kernelInputBuffer, offset: kernelInputOffset, index: 0)
        encoder.setBuffer(kernelInverseBuffer, offset: kernelInverseOffset, index: 1)
        encoder.setBuffer(kernelOutputBuffer, offset: kernelOutputOffset, index: 2)
        encoder.setBytes(&params, length: MemoryLayout<QM31FRIFoldParams>.stride, index: 3)
        context.dispatch1D(encoder, pipeline: pipeline, elementCount: outputCount)
        encoder.endEncoding()

        if readOutput {
            guard let readbackBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            readbackBlit.label = "QM31.FRI.Fold.Readback"
            readbackBlit.copy(
                from: outputVector.buffer,
                sourceOffset: outputVector.offset,
                to: outputReadback,
                destinationOffset: 0,
                size: outputByteCount
            )
            readbackBlit.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let stats = GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpuDuration(commandBuffer))
        let values = readOutput ? Self.readQM31Buffer(outputReadback, count: outputCount) : []
        return QM31FRIFoldResult(values: values, stats: stats)
    }

    private func validateInputs(
        evaluations: [QM31Element],
        inverseDomainPoints: [QM31Element],
        challenge: QM31Element
    ) throws {
        guard evaluations.count == inputCount,
              inverseDomainPoints.count == outputCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        try QM31Field.validateCanonical(inverseDomainPoints)
        try QM31Field.validateCanonical([challenge])
        guard inverseDomainPoints.allSatisfy({ !QM31Field.isZero($0) }) else {
            throw AppleZKProverError.invalidInputLayout
        }
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

    private func validateNoOutputAliasing(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int
    ) throws {
        guard !rangesOverlap(
            lhsBuffer: outputBuffer,
            lhsOffset: outputOffset,
            lhsByteCount: outputByteCount,
            rhsBuffer: evaluationsBuffer,
            rhsOffset: evaluationsOffset,
            rhsByteCount: inputByteCount
        ),
        !rangesOverlap(
            lhsBuffer: outputBuffer,
            lhsOffset: outputOffset,
            lhsByteCount: outputByteCount,
            rhsBuffer: inverseDomainBuffer,
            rhsOffset: inverseDomainOffset,
            rhsByteCount: outputByteCount
        ) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private func rangesOverlap(
        lhsBuffer: MTLBuffer,
        lhsOffset: Int,
        lhsByteCount: Int,
        rhsBuffer: MTLBuffer,
        rhsOffset: Int,
        rhsByteCount: Int
    ) -> Bool {
        guard lhsBuffer === rhsBuffer else {
            return false
        }
        let lhsEnd = lhsOffset + lhsByteCount
        let rhsEnd = rhsOffset + rhsByteCount
        return lhsOffset < rhsEnd && rhsOffset < lhsEnd
    }

    private static func packLittleEndian(_ values: [QM31Element]) -> Data {
        var data = Data()
        data.reserveCapacity(values.count * elementByteCount)
        for value in values {
            appendUInt32LittleEndian(value.constant.real, to: &data)
            appendUInt32LittleEndian(value.constant.imaginary, to: &data)
            appendUInt32LittleEndian(value.uCoefficient.real, to: &data)
            appendUInt32LittleEndian(value.uCoefficient.imaginary, to: &data)
        }
        return data
    }

    private static func appendUInt32LittleEndian(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }

    private static func readQM31Buffer(_ buffer: MTLBuffer, count: Int) -> [QM31Element] {
        let wordCount = count * 4
        let raw = buffer.contents().bindMemory(to: UInt32.self, capacity: wordCount)
        return (0..<count).map { index in
            QM31Element(
                a: raw[index * 4],
                b: raw[index * 4 + 1],
                c: raw[index * 4 + 2],
                d: raw[index * 4 + 3]
            )
        }
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
