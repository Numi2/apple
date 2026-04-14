import Foundation

public enum AIRTraceSynthesisInputLayoutV1: String, Codable, CaseIterable, Sendable {
    case privateColumnMajorM31Witness = "private-column-major-m31-witness"
}

public enum AIRTraceSynthesisOutputLayoutV1: String, Codable, CaseIterable, Sendable {
    case residentRowMajorM31AIRTrace = "resident-row-major-m31-air-trace"
}

public struct AIRTraceResidentSynthesisCommandPlanV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let inputLayout: AIRTraceSynthesisInputLayoutV1
    public let outputLayout: AIRTraceSynthesisOutputLayoutV1
    public let rowCount: Int
    public let columnCount: Int
    public let validatesPrivateWitnessCanonicality: Bool
    public let producesAIRTrace: Bool
    public let verifiesAIRSemantics: Bool
    public let isZeroKnowledge: Bool

    public init(
        version: UInt32 = currentVersion,
        inputLayout: AIRTraceSynthesisInputLayoutV1 = .privateColumnMajorM31Witness,
        outputLayout: AIRTraceSynthesisOutputLayoutV1 = .residentRowMajorM31AIRTrace,
        rowCount: Int,
        columnCount: Int,
        validatesPrivateWitnessCanonicality: Bool = true,
        producesAIRTrace: Bool = true,
        verifiesAIRSemantics: Bool = false,
        isZeroKnowledge: Bool = false
    ) throws {
        guard version == Self.currentVersion,
              rowCount > 0,
              columnCount > 0,
              validatesPrivateWitnessCanonicality,
              producesAIRTrace,
              !verifiesAIRSemantics,
              !isZeroKnowledge else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.inputLayout = inputLayout
        self.outputLayout = outputLayout
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.validatesPrivateWitnessCanonicality = validatesPrivateWitnessCanonicality
        self.producesAIRTrace = producesAIRTrace
        self.verifiesAIRSemantics = verifiesAIRSemantics
        self.isZeroKnowledge = isZeroKnowledge
    }
}

public enum AIRTraceResidentSynthesisOracleV1 {
    public static let elementByteCount = MemoryLayout<UInt32>.stride

    public static func synthesize(
        witness: ApplicationWitnessTraceV1,
        definition: AIRDefinitionV1? = nil
    ) throws -> AIRExecutionTraceV1 {
        if let definition, definition.columnCount != witness.columnCount {
            throw AppleZKProverError.invalidInputLayout
        }
        return try WitnessToAIRTraceProducerV1.produce(witness: witness)
    }

    public static func packColumnMajorWitness(_ witness: ApplicationWitnessTraceV1) throws -> Data {
        var data = Data()
        data.reserveCapacity(try checkedBufferLength(
            try checkedBufferLength(witness.rowCount, witness.columnCount),
            elementByteCount
        ))
        for column in witness.columns {
            for value in column {
                appendUInt32LittleEndian(value, to: &data)
            }
        }
        return data
    }

    private static func appendUInt32LittleEndian(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }
}

#if canImport(Metal)
import Metal

private struct AIRTraceSynthesisParams {
    var elementCount: UInt32
    var rowCount: UInt32
    var columnCount: UInt32
    var fieldModulus: UInt32
}

public struct AIRTraceResidentSynthesisReadbackV1: Sendable {
    public let trace: AIRExecutionTraceV1
    public let stats: GPUExecutionStats

    public init(trace: AIRExecutionTraceV1, stats: GPUExecutionStats) {
        self.trace = trace
        self.stats = stats
    }
}

public final class AIRTraceResidentSynthesisPlanV1: @unchecked Sendable {
    public static let elementByteCount = MemoryLayout<UInt32>.stride

    public let rowCount: Int
    public let columnCount: Int
    public let commandPlan: AIRTraceResidentSynthesisCommandPlanV1

    private let context: MetalContext
    private let pipeline: MTLComputePipelineState
    private let elementCount: Int
    private let traceByteCount: Int
    private let failureFlagBuffer: MTLBuffer
    private let traceReadbackBuffer: MTLBuffer
    private let executionLock = NSLock()

    public init(
        context: MetalContext,
        rowCount: Int,
        columnCount: Int
    ) throws {
        guard rowCount > 0,
              columnCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let elementCount = try checkedBufferLength(rowCount, columnCount)
        _ = try checkedUInt32(rowCount)
        _ = try checkedUInt32(columnCount)
        _ = try checkedUInt32(elementCount)
        let traceByteCount = try checkedBufferLength(elementCount, Self.elementByteCount)

        self.context = context
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.elementCount = elementCount
        self.traceByteCount = traceByteCount
        self.commandPlan = try AIRTraceResidentSynthesisCommandPlanV1(
            rowCount: rowCount,
            columnCount: columnCount
        )
        self.pipeline = try context.pipeline(
            for: KernelSpec(kernel: "air_trace_synthesize_row_major_m31", family: .scalar, queueMode: .metal3)
        )
        self.failureFlagBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: MemoryLayout<UInt32>.stride,
            label: "AppleZKProver.AIRTraceResidentSynthesis.FailureFlag"
        )
        self.traceReadbackBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: traceByteCount,
            label: "AppleZKProver.AIRTraceResidentSynthesis.Readback"
        )
    }

    public func executeResident(
        witnessColumnMajorBuffer: MTLBuffer,
        witnessColumnMajorOffset: Int = 0,
        outputTraceBuffer: MTLBuffer,
        outputTraceOffset: Int = 0
    ) throws -> GPUExecutionStats {
        executionLock.lock()
        defer { executionLock.unlock() }

        return try executeLocked(
            witnessColumnMajorBuffer: witnessColumnMajorBuffer,
            witnessColumnMajorOffset: witnessColumnMajorOffset,
            outputTraceBuffer: outputTraceBuffer,
            outputTraceOffset: outputTraceOffset,
            readTrace: false
        ).stats
    }

    public func executeResidentAndReadback(
        witnessColumnMajorBuffer: MTLBuffer,
        witnessColumnMajorOffset: Int = 0,
        outputTraceBuffer: MTLBuffer,
        outputTraceOffset: Int = 0
    ) throws -> AIRTraceResidentSynthesisReadbackV1 {
        executionLock.lock()
        defer { executionLock.unlock() }

        let result = try executeLocked(
            witnessColumnMajorBuffer: witnessColumnMajorBuffer,
            witnessColumnMajorOffset: witnessColumnMajorOffset,
            outputTraceBuffer: outputTraceBuffer,
            outputTraceOffset: outputTraceOffset,
            readTrace: true
        )
        guard let trace = result.trace else {
            throw AppleZKProverError.correctnessValidationFailed("AIR trace synthesis readback did not return a trace.")
        }
        return AIRTraceResidentSynthesisReadbackV1(trace: trace, stats: result.stats)
    }

    public func executeVerified(
        witness: ApplicationWitnessTraceV1,
        definition: AIRDefinitionV1? = nil,
        witnessColumnMajorBuffer: MTLBuffer,
        witnessColumnMajorOffset: Int = 0,
        outputTraceBuffer: MTLBuffer,
        outputTraceOffset: Int = 0
    ) throws -> AIRTraceResidentSynthesisReadbackV1 {
        guard witness.rowCount == rowCount,
              witness.columnCount == columnCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        let expected = try AIRTraceResidentSynthesisOracleV1.synthesize(
            witness: witness,
            definition: definition
        )
        let measured = try executeResidentAndReadback(
            witnessColumnMajorBuffer: witnessColumnMajorBuffer,
            witnessColumnMajorOffset: witnessColumnMajorOffset,
            outputTraceBuffer: outputTraceBuffer,
            outputTraceOffset: outputTraceOffset
        )
        guard measured.trace == expected else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Resident AIR trace synthesis did not match the CPU witness-to-AIR trace oracle."
            )
        }
        return measured
    }

    public func clearReusableBuffers() throws {
        executionLock.lock()
        defer { executionLock.unlock() }

        MetalBufferFactory.zeroSharedBuffer(failureFlagBuffer)
        MetalBufferFactory.zeroSharedBuffer(traceReadbackBuffer)
    }

    private func executeLocked(
        witnessColumnMajorBuffer: MTLBuffer,
        witnessColumnMajorOffset: Int,
        outputTraceBuffer: MTLBuffer,
        outputTraceOffset: Int,
        readTrace: Bool
    ) throws -> (trace: AIRExecutionTraceV1?, stats: GPUExecutionStats) {
        try Self.validateBufferRange(
            buffer: witnessColumnMajorBuffer,
            offset: witnessColumnMajorOffset,
            byteCount: traceByteCount
        )
        try Self.validateBufferRange(
            buffer: outputTraceBuffer,
            offset: outputTraceOffset,
            byteCount: traceByteCount
        )
        guard !Self.rangesOverlap(
            lhsBuffer: outputTraceBuffer,
            lhsOffset: outputTraceOffset,
            lhsByteCount: traceByteCount,
            rhsBuffer: witnessColumnMajorBuffer,
            rhsOffset: witnessColumnMajorOffset,
            rhsByteCount: traceByteCount
        ) else {
            throw AppleZKProverError.invalidInputLayout
        }

        try MetalBufferFactory.zeroSharedBuffer(
            failureFlagBuffer,
            offset: 0,
            byteCount: MemoryLayout<UInt32>.stride
        )

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "AIR.TraceResidentSynthesis"

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "AIR.TraceResidentSynthesis.Kernel"
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(witnessColumnMajorBuffer, offset: witnessColumnMajorOffset, index: 0)
        encoder.setBuffer(outputTraceBuffer, offset: outputTraceOffset, index: 1)
        encoder.setBuffer(failureFlagBuffer, offset: 0, index: 2)
        var params = AIRTraceSynthesisParams(
            elementCount: try checkedUInt32(elementCount),
            rowCount: try checkedUInt32(rowCount),
            columnCount: try checkedUInt32(columnCount),
            fieldModulus: M31Field.modulus
        )
        encoder.setBytes(&params, length: MemoryLayout<AIRTraceSynthesisParams>.stride, index: 3)
        context.dispatch1D(encoder, pipeline: pipeline, elementCount: elementCount)
        encoder.endEncoding()

        if readTrace {
            guard let readbackBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            readbackBlit.label = "AIR.TraceResidentSynthesis.Readback"
            readbackBlit.copy(
                from: outputTraceBuffer,
                sourceOffset: outputTraceOffset,
                to: traceReadbackBuffer,
                destinationOffset: 0,
                size: traceByteCount
            )
            readbackBlit.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let failed = failureFlagBuffer.contents().load(as: UInt32.self) != 0
        guard !failed else {
            throw AppleZKProverError.invalidInputLayout
        }

        let end = DispatchTime.now()
        let stats = GPUExecutionStats(
            cpuWallSeconds: Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000,
            gpuSeconds: gpuDuration(commandBuffer)
        )
        let trace: AIRExecutionTraceV1?
        if readTrace {
            trace = try AIRExecutionTraceV1(
                rowCount: rowCount,
                columnCount: columnCount,
                rowMajorValues: Self.readUInt32Buffer(traceReadbackBuffer, count: elementCount)
            )
        } else {
            trace = nil
        }
        return (trace, stats)
    }

    private static func readUInt32Buffer(_ buffer: MTLBuffer, count: Int) -> [UInt32] {
        let raw = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        return (0..<count).map { raw[$0] }
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

    private static func rangesOverlap(
        lhsBuffer: MTLBuffer,
        lhsOffset: Int,
        lhsByteCount: Int,
        rhsBuffer: MTLBuffer,
        rhsOffset: Int,
        rhsByteCount: Int
    ) -> Bool {
        guard lhsBuffer === rhsBuffer,
              lhsByteCount > 0,
              rhsByteCount > 0 else {
            return false
        }
        let lhsEnd = lhsOffset + lhsByteCount
        let rhsEnd = rhsOffset + rhsByteCount
        return lhsOffset < rhsEnd && rhsOffset < lhsEnd
    }

    private func gpuDuration(_ commandBuffer: MTLCommandBuffer) -> Double? {
        guard commandBuffer.gpuEndTime > commandBuffer.gpuStartTime else {
            return nil
        }
        return commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    }
}
#endif
