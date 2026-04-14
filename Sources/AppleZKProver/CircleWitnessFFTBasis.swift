import Foundation

public enum CircleWitnessToFFTBasisInputV1: String, Codable, CaseIterable, Sendable {
    case residentMonomialCoefficientColumns = "resident-monomial-coefficient-columns"
}

public enum CircleWitnessToFFTBasisOutputV1: String, Codable, CaseIterable, Sendable {
    case residentCircleFFTBasisBuffer = "resident-circle-fft-basis-buffer"
}

public struct CircleWitnessToFFTBasisCommandPlanV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let input: CircleWitnessToFFTBasisInputV1
    public let output: CircleWitnessToFFTBasisOutputV1
    public let coefficientCapacity: Int
    public let outputElementCount: Int
    public let transformMatrixScalarCount: Int
    public let verifiesAIRSemantics: Bool
    public let producesAIRTrace: Bool

    public init(
        version: UInt32 = Self.currentVersion,
        input: CircleWitnessToFFTBasisInputV1,
        output: CircleWitnessToFFTBasisOutputV1,
        coefficientCapacity: Int,
        outputElementCount: Int,
        transformMatrixScalarCount: Int,
        verifiesAIRSemantics: Bool = false,
        producesAIRTrace: Bool = false
    ) throws {
        let expectedOutputElementCount = try checkedBufferLength(coefficientCapacity, 2)
        let expectedTransformScalarCount = try checkedBufferLength(
            coefficientCapacity,
            coefficientCapacity
        )
        guard version == Self.currentVersion,
              input == .residentMonomialCoefficientColumns,
              output == .residentCircleFFTBasisBuffer,
              coefficientCapacity > 0,
              coefficientCapacity.nonzeroBitCount == 1,
              outputElementCount == expectedOutputElementCount,
              transformMatrixScalarCount == expectedTransformScalarCount,
              !verifiesAIRSemantics,
              !producesAIRTrace else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.input = input
        self.output = output
        self.coefficientCapacity = coefficientCapacity
        self.outputElementCount = outputElementCount
        self.transformMatrixScalarCount = transformMatrixScalarCount
        self.verifiesAIRSemantics = verifiesAIRSemantics
        self.producesAIRTrace = producesAIRTrace
    }
}

public enum CircleWitnessToFFTBasisOracleV1 {
    public static let maximumMatrixCoefficientCapacity = 4096

    public static func transformMonomialColumns(
        xWitnessCoefficients: [QM31Element],
        yWitnessCoefficients: [QM31Element],
        domain: CircleDomainDescriptor
    ) throws -> [QM31Element] {
        let polynomial = try CircleCodewordPolynomial(
            xCoefficients: xWitnessCoefficients,
            yCoefficients: yWitnessCoefficients
        )
        return try CircleCodewordOracle.circleFFTCoefficients(
            polynomial: polynomial,
            domain: domain
        )
    }

    public static func lineBasisTransformScalars(
        domain: CircleDomainDescriptor
    ) throws -> [UInt32] {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try lineBasisTransformScalars(coefficientCapacity: domain.halfSize)
    }

    static func lineBasisTransformScalars(
        coefficientCapacity: Int
    ) throws -> [UInt32] {
        guard coefficientCapacity > 0,
              coefficientCapacity.nonzeroBitCount == 1,
              coefficientCapacity <= maximumMatrixCoefficientCapacity else {
            throw AppleZKProverError.invalidInputLayout
        }
        var matrix: [UInt32] = []
        matrix.reserveCapacity(try checkedBufferLength(coefficientCapacity, coefficientCapacity))
        let zero = QM31Element(a: 0, b: 0, c: 0, d: 0)
        let one = QM31Element(a: 1, b: 0, c: 0, d: 0)
        let domain = try CircleDomainDescriptor.canonical(
            logSize: UInt32(coefficientCapacity.trailingZeroBitCount + 1)
        )
        for row in 0..<coefficientCapacity {
            for column in 0..<coefficientCapacity {
                var coefficients = Array(repeating: zero, count: column + 1)
                coefficients[column] = one
                let polynomial = try CircleCodewordPolynomial(
                    xCoefficients: coefficients,
                    yCoefficients: []
                )
                let circleCoefficients = try CircleCodewordOracle.circleFFTCoefficients(
                    polynomial: polynomial,
                    domain: domain
                )
                let value = circleCoefficients[2 * row]
                guard value.constant.imaginary == 0,
                      value.uCoefficient.real == 0,
                      value.uCoefficient.imaginary == 0 else {
                    throw AppleZKProverError.correctnessValidationFailed(
                        "Circle FFT-basis transform matrix was not M31-scalar linear."
                    )
                }
                matrix.append(value.constant.real)
            }
        }
        return matrix
    }
}

#if canImport(Metal)
import Metal

private struct CircleWitnessToFFTBasisParams {
    var coefficientCapacity: UInt32
    var xCoefficientCount: UInt32
    var yCoefficientCount: UInt32
    var fieldModulus: UInt32
}

public final class CircleWitnessToFFTBasisPlanV1: @unchecked Sendable {
    public static let elementByteCount = QM31CanonicalEncoding.elementByteCount
    public static let scalarByteCount = MemoryLayout<UInt32>.stride

    public let domain: CircleDomainDescriptor
    public let commandPlan: CircleWitnessToFFTBasisCommandPlanV1

    private let context: MetalContext
    private let pipeline: MTLComputePipelineState
    private let transformMatrixBuffer: MTLBuffer
    private let coefficientCapacity: Int
    private let outputByteCount: Int
    private let executionLock = NSLock()

    public init(
        context: MetalContext,
        domain: CircleDomainDescriptor
    ) throws {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.context = context
        self.domain = domain
        self.coefficientCapacity = domain.halfSize
        self.pipeline = try context.pipeline(
            for: KernelSpec(kernel: "circle_witness_to_fft_basis", family: .scalar, queueMode: .metal3)
        )
        let matrix = try CircleWitnessToFFTBasisOracleV1.lineBasisTransformScalars(domain: domain)
        let matrixBytes = Self.packScalars(matrix)
        self.transformMatrixBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            bytes: matrixBytes,
            declaredLength: matrixBytes.count,
            label: "AppleZKProver.CircleWitnessToFFTBasis.TransformMatrix"
        )
        self.outputByteCount = try checkedBufferLength(domain.size, Self.elementByteCount)
        self.commandPlan = try CircleWitnessToFFTBasisCommandPlanV1(
            input: .residentMonomialCoefficientColumns,
            output: .residentCircleFFTBasisBuffer,
            coefficientCapacity: domain.halfSize,
            outputElementCount: domain.size,
            transformMatrixScalarCount: matrix.count
        )
    }

    public func executeResident(
        xWitnessCoefficientBuffer: MTLBuffer,
        xWitnessCoefficientOffset: Int = 0,
        xWitnessCoefficientCount: Int,
        yWitnessCoefficientBuffer: MTLBuffer,
        yWitnessCoefficientOffset: Int = 0,
        yWitnessCoefficientCount: Int,
        outputCircleCoefficientBuffer: MTLBuffer,
        outputCircleCoefficientOffset: Int = 0
    ) throws -> GPUExecutionStats {
        executionLock.lock()
        defer { executionLock.unlock() }

        let xByteCount = try checkedBufferLength(xWitnessCoefficientCount, Self.elementByteCount)
        let yByteCount = try checkedBufferLength(yWitnessCoefficientCount, Self.elementByteCount)
        try Self.validateBufferRange(
            buffer: xWitnessCoefficientBuffer,
            offset: xWitnessCoefficientOffset,
            byteCount: xByteCount
        )
        try Self.validateBufferRange(
            buffer: yWitnessCoefficientBuffer,
            offset: yWitnessCoefficientOffset,
            byteCount: yByteCount
        )
        try Self.validateBufferRange(
            buffer: outputCircleCoefficientBuffer,
            offset: outputCircleCoefficientOffset,
            byteCount: outputByteCount
        )
        guard xWitnessCoefficientCount >= 0,
              yWitnessCoefficientCount >= 0,
              xWitnessCoefficientCount <= coefficientCapacity,
              yWitnessCoefficientCount <= coefficientCapacity,
              xWitnessCoefficientCount + yWitnessCoefficientCount > 0,
              !Self.rangesOverlap(
                lhsBuffer: outputCircleCoefficientBuffer,
                lhsOffset: outputCircleCoefficientOffset,
                lhsByteCount: outputByteCount,
                rhsBuffer: xWitnessCoefficientBuffer,
                rhsOffset: xWitnessCoefficientOffset,
                rhsByteCount: xByteCount
              ),
              !Self.rangesOverlap(
                lhsBuffer: outputCircleCoefficientBuffer,
                lhsOffset: outputCircleCoefficientOffset,
                lhsByteCount: outputByteCount,
                rhsBuffer: yWitnessCoefficientBuffer,
                rhsOffset: yWitnessCoefficientOffset,
                rhsByteCount: yByteCount
              ) else {
            throw AppleZKProverError.invalidInputLayout
        }

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "Circle.WitnessToFFTBasis"

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "Circle.WitnessToFFTBasis.Matrix"
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(xWitnessCoefficientBuffer, offset: xWitnessCoefficientOffset, index: 0)
        encoder.setBuffer(yWitnessCoefficientBuffer, offset: yWitnessCoefficientOffset, index: 1)
        encoder.setBuffer(transformMatrixBuffer, offset: 0, index: 2)
        encoder.setBuffer(outputCircleCoefficientBuffer, offset: outputCircleCoefficientOffset, index: 3)
        var params = CircleWitnessToFFTBasisParams(
            coefficientCapacity: try checkedUInt32(coefficientCapacity),
            xCoefficientCount: try checkedUInt32(xWitnessCoefficientCount),
            yCoefficientCount: try checkedUInt32(yWitnessCoefficientCount),
            fieldModulus: QM31Field.modulus
        )
        encoder.setBytes(&params, length: MemoryLayout<CircleWitnessToFFTBasisParams>.stride, index: 4)
        context.dispatch1D(encoder, pipeline: pipeline, elementCount: coefficientCapacity)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        return GPUExecutionStats(
            cpuWallSeconds: Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000,
            gpuSeconds: gpuDuration(commandBuffer)
        )
    }

    public func executeVerified(
        polynomial: CircleCodewordPolynomial,
        xWitnessCoefficientBuffer: MTLBuffer,
        xWitnessCoefficientOffset: Int = 0,
        yWitnessCoefficientBuffer: MTLBuffer,
        yWitnessCoefficientOffset: Int = 0,
        outputCircleCoefficientBuffer: MTLBuffer,
        outputCircleCoefficientOffset: Int = 0
    ) throws -> GPUExecutionStats {
        let stats = try executeResident(
            xWitnessCoefficientBuffer: xWitnessCoefficientBuffer,
            xWitnessCoefficientOffset: xWitnessCoefficientOffset,
            xWitnessCoefficientCount: polynomial.xCoefficients.count,
            yWitnessCoefficientBuffer: yWitnessCoefficientBuffer,
            yWitnessCoefficientOffset: yWitnessCoefficientOffset,
            yWitnessCoefficientCount: polynomial.yCoefficients.count,
            outputCircleCoefficientBuffer: outputCircleCoefficientBuffer,
            outputCircleCoefficientOffset: outputCircleCoefficientOffset
        )
        let expected = try CircleCodewordOracle.circleFFTCoefficients(
            polynomial: polynomial,
            domain: domain
        )
        let measured = try Self.readQM31Buffer(
            outputCircleCoefficientBuffer,
            offset: outputCircleCoefficientOffset,
            count: domain.size
        )
        guard measured == expected else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Resident witness-to-Circle-FFT-basis output did not match the CPU oracle."
            )
        }
        return stats
    }

    private static func packScalars(_ scalars: [UInt32]) -> Data {
        var data = Data()
        data.reserveCapacity(scalars.count * MemoryLayout<UInt32>.stride)
        for scalar in scalars {
            CanonicalBinary.appendUInt32(scalar, to: &data)
        }
        return data
    }

    private static func readQM31Buffer(
        _ buffer: MTLBuffer,
        offset: Int,
        count: Int
    ) throws -> [QM31Element] {
        let byteCount = try checkedBufferLength(count, Self.elementByteCount)
        try validateBufferRange(buffer: buffer, offset: offset, byteCount: byteCount)
        guard buffer.storageMode != .private else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try QM31CanonicalEncoding.unpackMany(
            Data(bytes: buffer.contents().advanced(by: offset), count: byteCount),
            count: count
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
