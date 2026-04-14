import Foundation

public enum CircleWitnessToFFTBasisInputV1: String, Codable, CaseIterable, Sendable {
    case residentMonomialCoefficientColumns = "resident-monomial-coefficient-columns"
}

public enum CircleWitnessToFFTBasisOutputV1: String, Codable, CaseIterable, Sendable {
    case residentCircleFFTBasisBuffer = "resident-circle-fft-basis-buffer"
}

public enum CircleWitnessToFFTBasisTransformStrategyV1: String, Codable, CaseIterable, Sendable {
    case denseMatrix = "dense-matrix"
    case tiledDenseMatrix = "tiled-dense-matrix"
}

public struct CircleWitnessToFFTBasisCommandPlanV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let input: CircleWitnessToFFTBasisInputV1
    public let output: CircleWitnessToFFTBasisOutputV1
    public let coefficientCapacity: Int
    public let outputElementCount: Int
    public let transformMatrixScalarCount: Int
    public let transformStrategy: CircleWitnessToFFTBasisTransformStrategyV1
    public let residentTransformTileScalarCapacity: Int
    public let transformTileRowCapacity: Int
    public let validatesPrivateWitnessCanonicality: Bool
    public let verifiesAIRSemantics: Bool
    public let producesAIRTrace: Bool

    public init(
        version: UInt32 = Self.currentVersion,
        input: CircleWitnessToFFTBasisInputV1,
        output: CircleWitnessToFFTBasisOutputV1,
        coefficientCapacity: Int,
        outputElementCount: Int,
        transformMatrixScalarCount: Int,
        transformStrategy: CircleWitnessToFFTBasisTransformStrategyV1 = .denseMatrix,
        residentTransformTileScalarCapacity: Int? = nil,
        transformTileRowCapacity: Int? = nil,
        validatesPrivateWitnessCanonicality: Bool = true,
        verifiesAIRSemantics: Bool = false,
        producesAIRTrace: Bool = false
    ) throws {
        let expectedOutputElementCount = try checkedBufferLength(coefficientCapacity, 2)
        let expectedTransformScalarCount = try checkedBufferLength(
            coefficientCapacity,
            coefficientCapacity
        )
        let resolvedTileRows = transformTileRowCapacity ?? coefficientCapacity
        let expectedTileScalarCapacity = try checkedBufferLength(
            resolvedTileRows,
            coefficientCapacity
        )
        let resolvedTileScalarCapacity = residentTransformTileScalarCapacity ?? expectedTileScalarCapacity
        guard version == Self.currentVersion,
              input == .residentMonomialCoefficientColumns,
              output == .residentCircleFFTBasisBuffer,
              coefficientCapacity > 0,
              coefficientCapacity.nonzeroBitCount == 1,
              outputElementCount == expectedOutputElementCount,
              transformMatrixScalarCount == expectedTransformScalarCount,
              resolvedTileRows > 0,
              resolvedTileRows <= coefficientCapacity,
              resolvedTileScalarCapacity == expectedTileScalarCapacity,
              (transformStrategy == .denseMatrix
                ? resolvedTileRows == coefficientCapacity
                : resolvedTileRows < coefficientCapacity),
              validatesPrivateWitnessCanonicality,
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
        self.transformStrategy = transformStrategy
        self.residentTransformTileScalarCapacity = resolvedTileScalarCapacity
        self.transformTileRowCapacity = resolvedTileRows
        self.validatesPrivateWitnessCanonicality = validatesPrivateWitnessCanonicality
        self.verifiesAIRSemantics = verifiesAIRSemantics
        self.producesAIRTrace = producesAIRTrace
    }
}

public enum CircleWitnessToFFTBasisOracleV1 {
    public static let maximumMatrixCoefficientCapacity = 4096
    public static let preferredResidentTransformTileScalarCapacity = 1_048_576
    private static let inverseTwo: UInt32 = 1_073_741_824

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
        return try lineBasisTransformScalars(
            coefficientCapacity: coefficientCapacity,
            rowOffset: 0,
            rowCount: coefficientCapacity
        )
    }

    static func lineBasisTransformScalars(
        coefficientCapacity: Int,
        rowOffset: Int,
        rowCount: Int
    ) throws -> [UInt32] {
        let rowEnd = rowOffset.addingReportingOverflow(rowCount)
        guard coefficientCapacity > 0,
              coefficientCapacity.nonzeroBitCount == 1,
              rowOffset >= 0,
              rowCount > 0,
              !rowEnd.overflow,
              rowEnd.partialValue <= coefficientCapacity else {
            throw AppleZKProverError.invalidInputLayout
        }

        var matrix = Array(
            repeating: UInt32(0),
            count: try checkedBufferLength(rowCount, coefficientCapacity)
        )
        var power = [UInt32(1)]
        for column in 0..<coefficientCapacity {
            var chebyshev = Array(repeating: UInt32(0), count: coefficientCapacity)
            for index in power.indices {
                chebyshev[index] = power[index]
            }
            let lineBasis = try chebyshevToLineBasisScalars(chebyshev)
            for localRow in 0..<rowCount {
                matrix[localRow * coefficientCapacity + column] = lineBasis[rowOffset + localRow]
            }
            if column + 1 < coefficientCapacity {
                power = multiplyChebyshevByX(power)
            }
        }
        return matrix
    }

    private static func multiplyChebyshevByX(_ coefficients: [UInt32]) -> [UInt32] {
        var result = Array(repeating: UInt32(0), count: coefficients.count + 1)
        for index in coefficients.indices {
            let coefficient = coefficients[index]
            guard coefficient != 0 else {
                continue
            }
            if index == 0 {
                result[1] = M31Field.add(result[1], coefficient)
            } else {
                let half = M31Field.multiply(coefficient, inverseTwo)
                result[index - 1] = M31Field.add(result[index - 1], half)
                result[index + 1] = M31Field.add(result[index + 1], half)
            }
        }
        return result
    }

    private static func chebyshevToLineBasisScalars(_ coefficients: [UInt32]) throws -> [UInt32] {
        guard !coefficients.isEmpty,
              coefficients.count.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        guard coefficients.count > 1 else {
            return coefficients
        }

        let half = coefficients.count / 2
        var lowChebyshev = Array(coefficients[0..<half])
        var highChebyshev = Array(repeating: UInt32(0), count: half)
        highChebyshev[0] = coefficients[half]
        if half > 1 {
            for index in 1..<half {
                highChebyshev[index] = M31Field.multiply(coefficients[half + index], 2)
            }
            for lowIndex in 1..<half {
                let highIndex = half - lowIndex
                let lowContribution = M31Field.multiply(highChebyshev[highIndex], inverseTwo)
                lowChebyshev[lowIndex] = M31Field.subtract(lowChebyshev[lowIndex], lowContribution)
            }
        }

        return try chebyshevToLineBasisScalars(lowChebyshev)
            + chebyshevToLineBasisScalars(highChebyshev)
    }
}

#if canImport(Metal)
import Metal

private struct CircleWitnessToFFTBasisParams {
    var coefficientCapacity: UInt32
    var xCoefficientCount: UInt32
    var yCoefficientCount: UInt32
    var fieldModulus: UInt32
    var transformRowOffset: UInt32
    var transformRowCount: UInt32
}

public final class CircleWitnessToFFTBasisPlanV1: @unchecked Sendable {
    public static let elementByteCount = QM31CanonicalEncoding.elementByteCount
    public static let scalarByteCount = MemoryLayout<UInt32>.stride

    public let domain: CircleDomainDescriptor
    public let commandPlan: CircleWitnessToFFTBasisCommandPlanV1

    private let context: MetalContext
    private let pipeline: MTLComputePipelineState
    private let canonicalityCheckPlan: QM31CanonicalityCheckPlan
    private let transformMatrixBuffer: MTLBuffer
    private let coefficientCapacity: Int
    private let outputByteCount: Int
    private let transformStrategy: CircleWitnessToFFTBasisTransformStrategyV1
    private let transformTileRowCapacity: Int
    private let executionLock = NSLock()

    public init(
        context: MetalContext,
        domain: CircleDomainDescriptor,
        transformTileRowCapacity requestedTransformTileRowCapacity: Int? = nil
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
        self.canonicalityCheckPlan = try QM31CanonicalityCheckPlan(context: context)
        let transformTileRows: Int
        let transformStrategy: CircleWitnessToFFTBasisTransformStrategyV1
        if let requestedTransformTileRowCapacity {
            guard requestedTransformTileRowCapacity > 0,
                  requestedTransformTileRowCapacity <= domain.halfSize else {
                throw AppleZKProverError.invalidInputLayout
            }
            transformTileRows = requestedTransformTileRowCapacity
            transformStrategy = requestedTransformTileRowCapacity == domain.halfSize
                ? .denseMatrix
                : .tiledDenseMatrix
        } else if domain.halfSize <= CircleWitnessToFFTBasisOracleV1.maximumMatrixCoefficientCapacity {
            transformTileRows = domain.halfSize
            transformStrategy = .denseMatrix
        } else {
            transformTileRows = max(
                1,
                min(
                    domain.halfSize,
                    CircleWitnessToFFTBasisOracleV1.preferredResidentTransformTileScalarCapacity
                        / domain.halfSize
                )
            )
            transformStrategy = .tiledDenseMatrix
        }
        self.transformStrategy = transformStrategy
        self.transformTileRowCapacity = transformTileRows
        let transformTileScalarCapacity = try checkedBufferLength(transformTileRows, domain.halfSize)
        let matrixBytes: Data
        if transformStrategy == .denseMatrix {
            matrixBytes = Self.packScalars(try CircleWitnessToFFTBasisOracleV1.lineBasisTransformScalars(domain: domain))
        } else {
            matrixBytes = Data(count: try checkedBufferLength(
                transformTileScalarCapacity,
                Self.scalarByteCount
            ))
        }
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
            transformMatrixScalarCount: try checkedBufferLength(domain.halfSize, domain.halfSize),
            transformStrategy: transformStrategy,
            residentTransformTileScalarCapacity: transformTileScalarCapacity,
            transformTileRowCapacity: transformTileRows,
            validatesPrivateWitnessCanonicality: true
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
        let xCanonicalityStats = try canonicalityCheckPlan.validateResident(
            buffer: xWitnessCoefficientBuffer,
            offset: xWitnessCoefficientOffset,
            count: xWitnessCoefficientCount,
            label: "Circle.WitnessToFFTBasis.XCanonicality"
        )
        let yCanonicalityStats = try canonicalityCheckPlan.validateResident(
            buffer: yWitnessCoefficientBuffer,
            offset: yWitnessCoefficientOffset,
            count: yWitnessCoefficientCount,
            label: "Circle.WitnessToFFTBasis.YCanonicality"
        )
        var accumulatedGPUSeconds = Self.sumGPUSeconds(
            xCanonicalityStats.gpuSeconds,
            yCanonicalityStats.gpuSeconds
        )
        var rowOffset = 0
        repeat {
            let rowCount = min(transformTileRowCapacity, coefficientCapacity - rowOffset)
            if transformStrategy == .tiledDenseMatrix {
                let tile = try CircleWitnessToFFTBasisOracleV1.lineBasisTransformScalars(
                    coefficientCapacity: coefficientCapacity,
                    rowOffset: rowOffset,
                    rowCount: rowCount
                )
                let tileBytes = Self.packScalars(tile)
                try MetalBufferFactory.copy(
                    tileBytes,
                    into: transformMatrixBuffer,
                    byteCount: tileBytes.count
                )
            }
            let tileStats = try executeTransformTileLocked(
                xWitnessCoefficientBuffer: xWitnessCoefficientBuffer,
                xWitnessCoefficientOffset: xWitnessCoefficientOffset,
                xWitnessCoefficientCount: xWitnessCoefficientCount,
                yWitnessCoefficientBuffer: yWitnessCoefficientBuffer,
                yWitnessCoefficientOffset: yWitnessCoefficientOffset,
                yWitnessCoefficientCount: yWitnessCoefficientCount,
                outputCircleCoefficientBuffer: outputCircleCoefficientBuffer,
                outputCircleCoefficientOffset: outputCircleCoefficientOffset,
                transformRowOffset: rowOffset,
                transformRowCount: rowCount
            )
            accumulatedGPUSeconds = Self.sumGPUSeconds(accumulatedGPUSeconds, tileStats.gpuSeconds)
            rowOffset += rowCount
        } while rowOffset < coefficientCapacity

        let end = DispatchTime.now()
        return GPUExecutionStats(
            cpuWallSeconds: Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000,
            gpuSeconds: accumulatedGPUSeconds
        )
    }

    private func executeTransformTileLocked(
        xWitnessCoefficientBuffer: MTLBuffer,
        xWitnessCoefficientOffset: Int,
        xWitnessCoefficientCount: Int,
        yWitnessCoefficientBuffer: MTLBuffer,
        yWitnessCoefficientOffset: Int,
        yWitnessCoefficientCount: Int,
        outputCircleCoefficientBuffer: MTLBuffer,
        outputCircleCoefficientOffset: Int,
        transformRowOffset: Int,
        transformRowCount: Int
    ) throws -> GPUExecutionStats {
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
            fieldModulus: QM31Field.modulus,
            transformRowOffset: try checkedUInt32(transformRowOffset),
            transformRowCount: try checkedUInt32(transformRowCount)
        )
        encoder.setBytes(&params, length: MemoryLayout<CircleWitnessToFFTBasisParams>.stride, index: 4)
        context.dispatch1D(encoder, pipeline: pipeline, elementCount: transformRowCount)
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

    private static func sumGPUSeconds(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard let lhs, let rhs else {
            return nil
        }
        return lhs + rhs
    }
}
#endif
