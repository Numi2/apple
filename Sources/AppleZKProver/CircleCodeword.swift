import Foundation

public struct CircleCodewordPolynomial: Equatable, Sendable {
    public let xCoefficients: [QM31Element]
    public let yCoefficients: [QM31Element]

    public init(
        xCoefficients: [QM31Element],
        yCoefficients: [QM31Element] = []
    ) throws {
        guard !xCoefficients.isEmpty || !yCoefficients.isEmpty,
              xCoefficients.count <= Int(UInt32.max),
              yCoefficients.count <= Int(UInt32.max) else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(xCoefficients)
        try QM31Field.validateCanonical(yCoefficients)
        self.xCoefficients = xCoefficients
        self.yCoefficients = yCoefficients
    }
}

public enum CircleCodewordOracle {
    public static func evaluate(
        polynomial: CircleCodewordPolynomial,
        domain: CircleDomainDescriptor
    ) throws -> [QM31Element] {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed else {
            throw AppleZKProverError.invalidInputLayout
        }

        var evaluations: [QM31Element] = []
        evaluations.reserveCapacity(domain.size)
        for storageIndex in 0..<domain.size {
            let naturalIndex = try CircleDomainOracle.naturalDomainIndex(
                forStorageIndex: storageIndex,
                descriptor: domain
            )
            let point = try CircleDomainOracle.point(
                in: domain,
                naturalDomainIndex: naturalIndex
            )
            try CircleDomainOracle.validatePoint(point)
            let xPart = evaluateUnivariate(
                coefficients: polynomial.xCoefficients,
                at: point.x
            )
            let yPart = QM31Field.multiplyByM31(
                evaluateUnivariate(
                    coefficients: polynomial.yCoefficients,
                    at: point.x
                ),
                point.y
            )
            evaluations.append(QM31Field.add(xPart, yPart))
        }
        return evaluations
    }

    private static func evaluateUnivariate(
        coefficients: [QM31Element],
        at x: UInt32
    ) -> QM31Element {
        var accumulator = QM31Element(a: 0, b: 0, c: 0, d: 0)
        for coefficient in coefficients.reversed() {
            accumulator = QM31Field.add(
                QM31Field.multiplyByM31(accumulator, x),
                coefficient
            )
        }
        return accumulator
    }
}

extension QM31Field {
    public static func multiplyByM31(_ value: QM31Element, _ scalar: UInt32) -> QM31Element {
        QM31Element(
            constant: CM31Element(
                real: M31Field.multiply(value.constant.real, scalar),
                imaginary: M31Field.multiply(value.constant.imaginary, scalar)
            ),
            uCoefficient: CM31Element(
                real: M31Field.multiply(value.uCoefficient.real, scalar),
                imaginary: M31Field.multiply(value.uCoefficient.imaginary, scalar)
            )
        )
    }
}

#if canImport(Metal)
import Metal

private struct CircleCodewordDirectEvalParams {
    var pointCount: UInt32
    var xCoefficientCount: UInt32
    var yCoefficientCount: UInt32
    var fieldModulus: UInt32
}

public struct CircleCodewordResult: Sendable {
    public let evaluations: [QM31Element]
    public let stats: GPUExecutionStats

    public init(evaluations: [QM31Element], stats: GPUExecutionStats) {
        self.evaluations = evaluations
        self.stats = stats
    }
}

public final class CircleCodewordPlan: @unchecked Sendable {
    public static let elementByteCount = QM31CanonicalEncoding.elementByteCount
    public static let domainPointByteCount = 2 * MemoryLayout<UInt32>.stride

    public let domain: CircleDomainDescriptor
    public let outputCount: Int

    private let context: MetalContext
    private let pipeline: MTLComputePipelineState
    private let domainPointBuffer: MTLBuffer
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
        self.outputCount = domain.size
        self.pipeline = try context.pipeline(
            for: KernelSpec(kernel: "circle_codeword_direct_eval", family: .scalar, queueMode: .metal3)
        )
        self.outputByteCount = try checkedBufferLength(domain.size, Self.elementByteCount)
        self.domainPointBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            bytes: try Self.packDomainPoints(domain),
            declaredLength: try checkedBufferLength(domain.size, Self.domainPointByteCount),
            label: "AppleZKProver.CircleCodeword.DomainPoints"
        )
    }

    public func execute(
        polynomial: CircleCodewordPolynomial
    ) throws -> CircleCodewordResult {
        let outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: outputByteCount,
            label: "AppleZKProver.CircleCodeword.Output"
        )
        let stats = try executeResident(
            polynomial: polynomial,
            outputBuffer: outputBuffer
        )
        let evaluations = try Self.readQM31Buffer(outputBuffer, count: outputCount)
        return CircleCodewordResult(evaluations: evaluations, stats: stats)
    }

    public func executeVerified(
        polynomial: CircleCodewordPolynomial
    ) throws -> CircleCodewordResult {
        let expected = try CircleCodewordOracle.evaluate(
            polynomial: polynomial,
            domain: domain
        )
        let measured = try execute(polynomial: polynomial)
        guard measured.evaluations == expected else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Circle codeword GPU result did not match the CPU oracle."
            )
        }
        return measured
    }

    public func executeResident(
        polynomial: CircleCodewordPolynomial,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0
    ) throws -> GPUExecutionStats {
        let xCoefficientBytes = QM31CanonicalEncoding.pack(polynomial.xCoefficients)
        let yCoefficientBytes = QM31CanonicalEncoding.pack(polynomial.yCoefficients)
        let xCoefficientBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            bytes: xCoefficientBytes,
            declaredLength: xCoefficientBytes.count,
            label: "AppleZKProver.CircleCodeword.XCoefficients"
        )
        let yCoefficientBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            bytes: yCoefficientBytes,
            declaredLength: yCoefficientBytes.count,
            label: "AppleZKProver.CircleCodeword.YCoefficients"
        )
        return try executeResident(
            xCoefficientBuffer: xCoefficientBuffer,
            xCoefficientOffset: 0,
            xCoefficientCount: polynomial.xCoefficients.count,
            yCoefficientBuffer: yCoefficientBuffer,
            yCoefficientOffset: 0,
            yCoefficientCount: polynomial.yCoefficients.count,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset
        )
    }

    public func executeResident(
        xCoefficientBuffer: MTLBuffer,
        xCoefficientOffset: Int = 0,
        xCoefficientCount: Int,
        yCoefficientBuffer: MTLBuffer,
        yCoefficientOffset: Int = 0,
        yCoefficientCount: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0
    ) throws -> GPUExecutionStats {
        executionLock.lock()
        defer { executionLock.unlock() }

        let xCoefficientByteCount = try checkedBufferLength(xCoefficientCount, Self.elementByteCount)
        let yCoefficientByteCount = try checkedBufferLength(yCoefficientCount, Self.elementByteCount)
        try Self.validateBufferRange(
            buffer: xCoefficientBuffer,
            offset: xCoefficientOffset,
            byteCount: xCoefficientByteCount
        )
        try Self.validateBufferRange(
            buffer: yCoefficientBuffer,
            offset: yCoefficientOffset,
            byteCount: yCoefficientByteCount
        )
        try Self.validateBufferRange(
            buffer: outputBuffer,
            offset: outputOffset,
            byteCount: outputByteCount
        )
        guard xCoefficientCount >= 0,
              yCoefficientCount >= 0,
              xCoefficientCount <= Int(UInt32.max),
              yCoefficientCount <= Int(UInt32.max),
              xCoefficientCount + yCoefficientCount > 0,
              !Self.rangesOverlap(
                lhsBuffer: outputBuffer,
                lhsOffset: outputOffset,
                lhsByteCount: outputByteCount,
                rhsBuffer: xCoefficientBuffer,
                rhsOffset: xCoefficientOffset,
                rhsByteCount: xCoefficientByteCount
              ),
              !Self.rangesOverlap(
                lhsBuffer: outputBuffer,
                lhsOffset: outputOffset,
                lhsByteCount: outputByteCount,
                rhsBuffer: yCoefficientBuffer,
                rhsOffset: yCoefficientOffset,
                rhsByteCount: yCoefficientByteCount
              ) else {
            throw AppleZKProverError.invalidInputLayout
        }

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "Circle.Codeword.DirectEval"

        guard let clearBlit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        clearBlit.label = "Circle.Codeword.DirectEval.Clear"
        clearBlit.fill(buffer: outputBuffer, range: outputOffset..<(outputOffset + outputByteCount), value: 0)
        clearBlit.endEncoding()

        var params = CircleCodewordDirectEvalParams(
            pointCount: try checkedUInt32(outputCount),
            xCoefficientCount: try checkedUInt32(xCoefficientCount),
            yCoefficientCount: try checkedUInt32(yCoefficientCount),
            fieldModulus: QM31Field.modulus
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "Circle.Codeword.DirectEval.Kernel"
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(domainPointBuffer, offset: 0, index: 0)
        encoder.setBuffer(xCoefficientBuffer, offset: xCoefficientOffset, index: 1)
        encoder.setBuffer(yCoefficientBuffer, offset: yCoefficientOffset, index: 2)
        encoder.setBuffer(outputBuffer, offset: outputOffset, index: 3)
        encoder.setBytes(&params, length: MemoryLayout<CircleCodewordDirectEvalParams>.stride, index: 4)
        context.dispatch1D(encoder, pipeline: pipeline, elementCount: outputCount)
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

    public func clearReusableBuffers() {
        // The direct evaluator owns only immutable domain point buffers.
    }

    private static func packDomainPoints(_ domain: CircleDomainDescriptor) throws -> Data {
        var data = Data()
        data.reserveCapacity(try checkedBufferLength(domain.size, domainPointByteCount))
        for storageIndex in 0..<domain.size {
            let naturalIndex = try CircleDomainOracle.naturalDomainIndex(
                forStorageIndex: storageIndex,
                descriptor: domain
            )
            let point = try CircleDomainOracle.point(in: domain, naturalDomainIndex: naturalIndex)
            try CircleDomainOracle.validatePoint(point)
            CanonicalBinary.appendUInt32(point.x, to: &data)
            CanonicalBinary.appendUInt32(point.y, to: &data)
        }
        return data
    }

    private static func readQM31Buffer(_ buffer: MTLBuffer, count: Int) throws -> [QM31Element] {
        let byteCount = try checkedBufferLength(count, elementByteCount)
        try validateBufferRange(buffer: buffer, offset: 0, byteCount: byteCount)
        return try QM31CanonicalEncoding.unpackMany(
            Data(bytes: buffer.contents(), count: byteCount),
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

public struct CircleCodewordPCSFRIProverV1Result: Sendable {
    public let proofResult: CirclePCSFRIResidentProverV1Result
    public let codewordStats: GPUExecutionStats
    public let stats: GPUExecutionStats

    public init(
        proofResult: CirclePCSFRIResidentProverV1Result,
        codewordStats: GPUExecutionStats,
        stats: GPUExecutionStats
    ) {
        self.proofResult = proofResult
        self.codewordStats = codewordStats
        self.stats = stats
    }

    public var proof: CirclePCSFRIProofV1 {
        proofResult.proof
    }

    public var encodedProof: Data {
        proofResult.encodedProof
    }

    public var proofByteCount: Int {
        proofResult.proofByteCount
    }
}

public final class CircleCodewordPCSFRIProverV1: @unchecked Sendable {
    public let domain: CircleDomainDescriptor
    public let securityParameters: CircleFRISecurityParametersV1
    public let publicInputs: CirclePCSFRIPublicInputsV1
    public let roundCount: Int

    private let codewordPlan: CircleCodewordPlan
    private let proofProver: CirclePCSFRIResidentProverV1
    private let codewordBuffer: MTLBuffer
    private let executionLock = NSLock()

    public init(
        context: MetalContext,
        domain: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputs: CirclePCSFRIPublicInputsV1,
        roundCount: Int
    ) throws {
        self.domain = domain
        self.securityParameters = securityParameters
        self.publicInputs = publicInputs
        self.roundCount = roundCount
        self.codewordPlan = try CircleCodewordPlan(context: context, domain: domain)
        self.proofProver = try CirclePCSFRIResidentProverV1(
            context: context,
            domain: domain,
            securityParameters: securityParameters,
            publicInputs: publicInputs,
            roundCount: roundCount
        )
        self.codewordBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: try checkedBufferLength(domain.size, CircleCodewordPlan.elementByteCount),
            label: "AppleZKProver.CircleCodewordPCSFRIProver.Codeword"
        )
    }

    public func prove(
        polynomial: CircleCodewordPolynomial
    ) throws -> CircleCodewordPCSFRIProverV1Result {
        executionLock.lock()
        defer { executionLock.unlock() }

        let start = DispatchTime.now()
        let codewordStats = try codewordPlan.executeResident(
            polynomial: polynomial,
            outputBuffer: codewordBuffer
        )
        let proofResult = try proofProver.prove(evaluationsBuffer: codewordBuffer)
        let end = DispatchTime.now()
        return CircleCodewordPCSFRIProverV1Result(
            proofResult: proofResult,
            codewordStats: codewordStats,
            stats: GPUExecutionStats(
                cpuWallSeconds: Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000,
                gpuSeconds: Self.sumGPUSeconds(codewordStats.gpuSeconds, proofResult.stats.gpuSeconds)
            )
        )
    }

    public func proveResidentCoefficients(
        xCoefficientBuffer: MTLBuffer,
        xCoefficientOffset: Int = 0,
        xCoefficientCount: Int,
        yCoefficientBuffer: MTLBuffer,
        yCoefficientOffset: Int = 0,
        yCoefficientCount: Int
    ) throws -> CircleCodewordPCSFRIProverV1Result {
        executionLock.lock()
        defer { executionLock.unlock() }

        let start = DispatchTime.now()
        let codewordStats = try codewordPlan.executeResident(
            xCoefficientBuffer: xCoefficientBuffer,
            xCoefficientOffset: xCoefficientOffset,
            xCoefficientCount: xCoefficientCount,
            yCoefficientBuffer: yCoefficientBuffer,
            yCoefficientOffset: yCoefficientOffset,
            yCoefficientCount: yCoefficientCount,
            outputBuffer: codewordBuffer
        )
        let proofResult = try proofProver.prove(evaluationsBuffer: codewordBuffer)
        let end = DispatchTime.now()
        return CircleCodewordPCSFRIProverV1Result(
            proofResult: proofResult,
            codewordStats: codewordStats,
            stats: GPUExecutionStats(
                cpuWallSeconds: Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000,
                gpuSeconds: Self.sumGPUSeconds(codewordStats.gpuSeconds, proofResult.stats.gpuSeconds)
            )
        )
    }

    public func proveVerified(
        polynomial: CircleCodewordPolynomial
    ) throws -> CircleCodewordPCSFRIProverV1Result {
        let expectedCodeword = try CircleCodewordOracle.evaluate(
            polynomial: polynomial,
            domain: domain
        )
        let result = try prove(polynomial: polynomial)
        let expectedProof = try CircleFRIProofBuilderV1.prove(
            evaluations: expectedCodeword,
            domain: domain,
            securityParameters: securityParameters,
            publicInputs: publicInputs,
            roundCount: roundCount
        )
        guard result.proof == expectedProof,
              try CirclePCSFRIProofVerifierV1.verify(
                proof: result.proof,
                publicInputs: publicInputs
              ) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Circle codeword PCS/FRI resident prover emitted a proof rejected by the CPU oracle or verifier."
            )
        }
        return result
    }

    public func proveResidentCoefficientsVerified(
        polynomial: CircleCodewordPolynomial,
        xCoefficientBuffer: MTLBuffer,
        xCoefficientOffset: Int = 0,
        yCoefficientBuffer: MTLBuffer,
        yCoefficientOffset: Int = 0
    ) throws -> CircleCodewordPCSFRIProverV1Result {
        let expectedCodeword = try CircleCodewordOracle.evaluate(
            polynomial: polynomial,
            domain: domain
        )
        let result = try proveResidentCoefficients(
            xCoefficientBuffer: xCoefficientBuffer,
            xCoefficientOffset: xCoefficientOffset,
            xCoefficientCount: polynomial.xCoefficients.count,
            yCoefficientBuffer: yCoefficientBuffer,
            yCoefficientOffset: yCoefficientOffset,
            yCoefficientCount: polynomial.yCoefficients.count
        )
        let expectedProof = try CircleFRIProofBuilderV1.prove(
            evaluations: expectedCodeword,
            domain: domain,
            securityParameters: securityParameters,
            publicInputs: publicInputs,
            roundCount: roundCount
        )
        guard result.proof == expectedProof,
              try CirclePCSFRIProofVerifierV1.verify(
                proof: result.proof,
                publicInputs: publicInputs
              ) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Circle codeword PCS/FRI resident-coefficient prover emitted a proof rejected by the CPU oracle or verifier."
            )
        }
        return result
    }

    public func clearReusableBuffers() throws {
        executionLock.lock()
        defer { executionLock.unlock() }

        codewordPlan.clearReusableBuffers()
        try proofProver.clearReusableBuffers()
        MetalBufferFactory.zeroSharedBuffer(codewordBuffer)
    }

    private static func sumGPUSeconds(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard let lhs, let rhs else {
            return nil
        }
        return lhs + rhs
    }
}
#endif
