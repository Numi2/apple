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
    private static let zero = QM31Element(a: 0, b: 0, c: 0, d: 0)
    private static let inverseTwo: UInt32 = 1_073_741_824

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
            evaluations.append(try evaluate(polynomial: polynomial, at: point))
        }
        return evaluations
    }

    public static func evaluate(
        polynomial: CircleCodewordPolynomial,
        at point: CirclePointM31
    ) throws -> QM31Element {
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
        return QM31Field.add(xPart, yPart)
    }

    public static func evaluateWithCircleFFT(
        polynomial: CircleCodewordPolynomial,
        domain: CircleDomainDescriptor
    ) throws -> [QM31Element] {
        var values = try circleFFTCoefficients(
            polynomial: polynomial,
            domain: domain
        )
        let twiddles = try circleFFTTwiddles(for: domain)
        let stages = Array(stride(from: Int(domain.logSize) - 1, through: 1, by: -1)) + [0]
        for stage in stages {
            let stageTwiddleCount = domain.size >> (stage + 1)
            let twiddleOffset = circleFFTTwiddleOffset(stage: stage, domainSize: domain.size)
            for h in 0..<stageTwiddleCount {
                let twiddle = twiddles[twiddleOffset + h]
                for lane in 0..<(1 << stage) {
                    let leftIndex = (h << (stage + 1)) + lane
                    let rightIndex = leftIndex + (1 << stage)
                    let scaledRight = QM31Field.multiplyByM31(values[rightIndex], twiddle)
                    let left = values[leftIndex]
                    values[leftIndex] = QM31Field.add(left, scaledRight)
                    values[rightIndex] = QM31Field.subtract(left, scaledRight)
                }
            }
        }
        return values
    }

    public static func circleFFTCoefficients(
        polynomial: CircleCodewordPolynomial,
        domain: CircleDomainDescriptor
    ) throws -> [QM31Element] {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed,
              polynomial.xCoefficients.count <= domain.halfSize,
              polynomial.yCoefficients.count <= domain.halfSize else {
            throw AppleZKProverError.invalidInputLayout
        }

        let xLineCoefficients = try lineFFTBasisCoefficients(
            monomialCoefficients: polynomial.xCoefficients,
            capacity: domain.halfSize
        )
        let yLineCoefficients = try lineFFTBasisCoefficients(
            monomialCoefficients: polynomial.yCoefficients,
            capacity: domain.halfSize
        )

        var coefficients: [QM31Element] = []
        coefficients.reserveCapacity(domain.size)
        for index in 0..<domain.halfSize {
            coefficients.append(xLineCoefficients[index])
            coefficients.append(yLineCoefficients[index])
        }
        return coefficients
    }

    public static func circleFFTTwiddles(
        for domain: CircleDomainDescriptor
    ) throws -> [UInt32] {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed else {
            throw AppleZKProverError.invalidInputLayout
        }

        var twiddles: [UInt32] = []
        twiddles.reserveCapacity(max(0, domain.size - 1))
        for stage in 0..<Int(domain.logSize) {
            let twiddleCount = domain.size >> (stage + 1)
            for h in 0..<twiddleCount {
                let storageIndex = h << (stage + 1)
                let naturalIndex = try CircleDomainOracle.naturalDomainIndex(
                    forStorageIndex: storageIndex,
                    descriptor: domain
                )
                let point = try CircleDomainOracle.point(
                    in: domain,
                    naturalDomainIndex: naturalIndex
                )
                try CircleDomainOracle.validatePoint(point)
                if stage == 0 {
                    twiddles.append(point.y)
                } else {
                    var x = point.x
                    for _ in 1..<stage {
                        x = CircleDomainOracle.doubleX(x)
                    }
                    twiddles.append(x)
                }
            }
        }
        return twiddles
    }

    public static func circleFFTTwiddleOffset(stage: Int, domainSize: Int) -> Int {
        guard stage > 0 else {
            return 0
        }
        return domainSize - (domainSize >> stage)
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

    private static func lineFFTBasisCoefficients(
        monomialCoefficients: [QM31Element],
        capacity: Int
    ) throws -> [QM31Element] {
        guard capacity > 0,
              capacity.nonzeroBitCount == 1,
              monomialCoefficients.count <= capacity else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(monomialCoefficients)
        var chebyshev = Array(repeating: zero, count: capacity)
        guard !monomialCoefficients.isEmpty else {
            return chebyshev
        }

        var power = [UInt32(1)]
        for degree in 0..<monomialCoefficients.count {
            let coefficient = monomialCoefficients[degree]
            if !QM31Field.isZero(coefficient) {
                for index in 0..<power.count where power[index] != 0 {
                    chebyshev[index] = QM31Field.add(
                        chebyshev[index],
                        QM31Field.multiplyByM31(coefficient, power[index])
                    )
                }
            }
            if degree + 1 < monomialCoefficients.count {
                power = multiplyChebyshevByX(power)
            }
        }
        return try chebyshevToLineBasis(chebyshev)
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

    private static func chebyshevToLineBasis(_ coefficients: [QM31Element]) throws -> [QM31Element] {
        guard !coefficients.isEmpty,
              coefficients.count.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        guard coefficients.count > 1 else {
            return coefficients
        }

        let half = coefficients.count / 2
        var lowChebyshev = Array(coefficients[0..<half])
        var highChebyshev = Array(repeating: zero, count: half)
        highChebyshev[0] = coefficients[half]
        if half > 1 {
            for index in 1..<half {
                highChebyshev[index] = QM31Field.multiplyByM31(coefficients[half + index], 2)
            }
            for lowIndex in 1..<half {
                let highIndex = half - lowIndex
                let lowContribution = QM31Field.multiplyByM31(highChebyshev[highIndex], inverseTwo)
                lowChebyshev[lowIndex] = QM31Field.subtract(lowChebyshev[lowIndex], lowContribution)
            }
        }

        return try chebyshevToLineBasis(lowChebyshev) + chebyshevToLineBasis(highChebyshev)
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

private struct CircleCodewordFFTStageParams {
    var elementCount: UInt32
    var stage: UInt32
    var twiddleOffset: UInt32
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

public enum CircleCodewordPCSFRICoefficientInputV1: String, Codable, CaseIterable, Sendable {
    case hostMonomialPolynomial = "host-monomial-polynomial"
    case cpuVisibleResidentMonomialBuffers = "cpu-visible-resident-monomial-buffers"
    case residentCircleFFTBasisBuffer = "resident-circle-fft-basis-buffer"
}

public enum CircleCodewordPCSFRICommandPhaseV1: String, Codable, CaseIterable, Sendable {
    case coefficientInput = "coefficient-input"
    case codewordGeneration = "circle-fft-codeword-generation"
    case merkleRoots = "merkle-roots"
    case transcriptChallenges = "transcript-challenges"
    case friFolds = "fri-folds"
    case queryExtraction = "query-extraction"
    case proofBytes = "proof-bytes"
}

public enum CircleCodewordPCSFRIPublicReadbackV1: String, Codable, CaseIterable, Sendable {
    case merkleCommitments = "merkle-commitments"
    case finalLayer = "final-layer"
    case queriedLeaves = "queried-leaves"
    case merkleSiblingPaths = "merkle-sibling-paths"
    case proofBytes = "proof-bytes"
}

public struct CircleCodewordPCSFRIResidentCommandPlanV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let codewordEngine: String
    public let coefficientInputs: [CircleCodewordPCSFRICoefficientInputV1]
    public let phases: [CircleCodewordPCSFRICommandPhaseV1]
    public let publicReadbacks: [CircleCodewordPCSFRIPublicReadbackV1]
    public let codewordCommitmentSchedule: CirclePCSFRICodewordCommitmentScheduleV1
    public let usesFusedTiledCodewordCommitment: Bool
    public let forbidsFullCodewordReadback: Bool
    public let forbidsIntermediateFRILayerReadback: Bool
    public let codewordElementCount: Int
    public let finalLayerElementCount: Int
    public let roundCount: Int
    public let queryCount: Int

    public init(
        version: UInt32 = Self.currentVersion,
        codewordEngine: String,
        coefficientInputs: [CircleCodewordPCSFRICoefficientInputV1],
        phases: [CircleCodewordPCSFRICommandPhaseV1],
        publicReadbacks: [CircleCodewordPCSFRIPublicReadbackV1],
        codewordCommitmentSchedule: CirclePCSFRICodewordCommitmentScheduleV1,
        usesFusedTiledCodewordCommitment: Bool,
        forbidsFullCodewordReadback: Bool,
        forbidsIntermediateFRILayerReadback: Bool,
        codewordElementCount: Int,
        finalLayerElementCount: Int,
        roundCount: Int,
        queryCount: Int
    ) throws {
        guard version == Self.currentVersion,
              !codewordEngine.isEmpty,
              !coefficientInputs.isEmpty,
              phases == Self.canonicalPhases,
              publicReadbacks == Self.canonicalPublicReadbacks,
              codewordCommitmentSchedule == .materializedCodewordThenCommit,
              !usesFusedTiledCodewordCommitment,
              forbidsFullCodewordReadback,
              forbidsIntermediateFRILayerReadback,
              codewordElementCount > 1,
              finalLayerElementCount > 0,
              roundCount > 0,
              queryCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.codewordEngine = codewordEngine
        self.coefficientInputs = coefficientInputs
        self.phases = phases
        self.publicReadbacks = publicReadbacks
        self.codewordCommitmentSchedule = codewordCommitmentSchedule
        self.usesFusedTiledCodewordCommitment = usesFusedTiledCodewordCommitment
        self.forbidsFullCodewordReadback = forbidsFullCodewordReadback
        self.forbidsIntermediateFRILayerReadback = forbidsIntermediateFRILayerReadback
        self.codewordElementCount = codewordElementCount
        self.finalLayerElementCount = finalLayerElementCount
        self.roundCount = roundCount
        self.queryCount = queryCount
    }

    public static var canonicalPhases: [CircleCodewordPCSFRICommandPhaseV1] {
        [
            .coefficientInput,
            .codewordGeneration,
            .merkleRoots,
            .transcriptChallenges,
            .friFolds,
            .queryExtraction,
            .proofBytes,
        ]
    }

    public static var canonicalPublicReadbacks: [CircleCodewordPCSFRIPublicReadbackV1] {
        [
            .merkleCommitments,
            .finalLayer,
            .queriedLeaves,
            .merkleSiblingPaths,
            .proofBytes,
        ]
    }
}

public final class CircleCodewordPlan: @unchecked Sendable {
    public static let elementByteCount = QM31CanonicalEncoding.elementByteCount
    public static let twiddleElementByteCount = MemoryLayout<UInt32>.stride

    public let domain: CircleDomainDescriptor
    public let outputCount: Int
    public let twiddleCount: Int
    public let domainMaterializationStats: GPUExecutionStats

    private let context: MetalContext
    private let fftPipeline: MTLComputePipelineState
    private let domainMaterialization: CircleDomainMaterializationPlan
    private let outputByteCount: Int
    private let coefficientByteCount: Int
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
        self.twiddleCount = domain.size - 1
        self.fftPipeline = try context.pipeline(
            for: KernelSpec(kernel: "circle_codeword_fft_stage", family: .scalar, queueMode: .metal3)
        )
        self.outputByteCount = try checkedBufferLength(domain.size, Self.elementByteCount)
        self.coefficientByteCount = outputByteCount
        self.domainMaterialization = try CircleDomainMaterializationPlan(
            context: context,
            domain: domain,
            materializeDomainPoints: false,
            materializeCodewordTwiddles: true,
            inverseDomainRoundCount: 0
        )
        self.domainMaterializationStats = domainMaterialization.materializationStats
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
        let coefficientBytes = QM31CanonicalEncoding.pack(
            try CircleCodewordOracle.circleFFTCoefficients(
                polynomial: polynomial,
                domain: domain
            )
        )
        let coefficientBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            bytes: coefficientBytes,
            declaredLength: coefficientBytes.count,
            label: "AppleZKProver.CircleCodeword.FFTCoefficients"
        )
        return try executeResident(
            circleCoefficientBuffer: coefficientBuffer,
            circleCoefficientOffset: 0,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset
        )
    }

    public func executeResident(
        circleCoefficientBuffer: MTLBuffer,
        circleCoefficientOffset: Int = 0,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0
    ) throws -> GPUExecutionStats {
        executionLock.lock()
        defer { executionLock.unlock() }

        try Self.validateBufferRange(
            buffer: circleCoefficientBuffer,
            offset: circleCoefficientOffset,
            byteCount: coefficientByteCount
        )
        try Self.validateBufferRange(
            buffer: outputBuffer,
            offset: outputOffset,
            byteCount: outputByteCount
        )
        guard !Self.rangesOverlap(
            lhsBuffer: outputBuffer,
            lhsOffset: outputOffset,
            lhsByteCount: outputByteCount,
            rhsBuffer: circleCoefficientBuffer,
            rhsOffset: circleCoefficientOffset,
            rhsByteCount: coefficientByteCount
        ) else {
            throw AppleZKProverError.invalidInputLayout
        }

        return try executeFFTLocked(
            coefficientBuffer: circleCoefficientBuffer,
            coefficientOffset: circleCoefficientOffset,
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
              xCoefficientCount <= domain.halfSize,
              yCoefficientCount <= domain.halfSize,
              xCoefficientCount + yCoefficientCount > 0,
              Self.isCPUReadable(buffer: xCoefficientBuffer, byteCount: xCoefficientByteCount),
              Self.isCPUReadable(buffer: yCoefficientBuffer, byteCount: yCoefficientByteCount),
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

        let polynomial = try CircleCodewordPolynomial(
            xCoefficients: Self.readQM31Buffer(
                xCoefficientBuffer,
                offset: xCoefficientOffset,
                count: xCoefficientCount
            ),
            yCoefficients: Self.readQM31Buffer(
                yCoefficientBuffer,
                offset: yCoefficientOffset,
                count: yCoefficientCount
            )
        )
        return try executeResident(
            polynomial: polynomial,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset
        )
    }

    private func executeFFTLocked(
        coefficientBuffer: MTLBuffer,
        coefficientOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int
    ) throws -> GPUExecutionStats {
        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "Circle.Codeword.FFT"

        guard let uploadBlit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        uploadBlit.label = "Circle.Codeword.FFT.Upload"
        uploadBlit.copy(
            from: coefficientBuffer,
            sourceOffset: coefficientOffset,
            to: outputBuffer,
            destinationOffset: outputOffset,
            size: coefficientByteCount
        )
        uploadBlit.endEncoding()

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "Circle.Codeword.FFT.Stages"
        encoder.setComputePipelineState(fftPipeline)
        encoder.setBuffer(outputBuffer, offset: outputOffset, index: 0)
        encoder.setBuffer(try domainMaterialization.requireCodewordTwiddleBuffer(), offset: 0, index: 1)
        let stages = Array(stride(from: Int(domain.logSize) - 1, through: 1, by: -1)) + [0]
        for stage in stages {
            var params = CircleCodewordFFTStageParams(
                elementCount: try checkedUInt32(outputCount),
                stage: try checkedUInt32(stage),
                twiddleOffset: try checkedUInt32(
                    CircleCodewordOracle.circleFFTTwiddleOffset(stage: stage, domainSize: outputCount)
                ),
                fieldModulus: QM31Field.modulus
            )
            encoder.setBytes(&params, length: MemoryLayout<CircleCodewordFFTStageParams>.stride, index: 2)
            context.dispatch1D(encoder, pipeline: fftPipeline, elementCount: outputCount / 2)
        }
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
        // The FFT evaluator owns only immutable twiddle buffers.
    }

    public func readCodewordTwiddles() throws -> [UInt32] {
        try domainMaterialization.readCodewordTwiddles()
    }

    private static func readQM31Buffer(_ buffer: MTLBuffer, count: Int) throws -> [QM31Element] {
        try readQM31Buffer(buffer, offset: 0, count: count)
    }

    private static func readQM31Buffer(
        _ buffer: MTLBuffer,
        offset: Int,
        count: Int
    ) throws -> [QM31Element] {
        let byteCount = try checkedBufferLength(count, elementByteCount)
        try validateBufferRange(buffer: buffer, offset: offset, byteCount: byteCount)
        guard isCPUReadable(buffer: buffer, byteCount: byteCount) else {
            throw AppleZKProverError.invalidInputLayout
        }
        guard count > 0 else {
            return []
        }
        return try QM31CanonicalEncoding.unpackMany(
            Data(bytes: buffer.contents().advanced(by: offset), count: byteCount),
            count: count
        )
    }

    private static func isCPUReadable(buffer: MTLBuffer, byteCount: Int) -> Bool {
        byteCount == 0 || buffer.storageMode != .private
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
    public let commandPlan: CircleCodewordPCSFRIResidentCommandPlanV1

    private let context: MetalContext
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
        let codewordPlan = try CircleCodewordPlan(context: context, domain: domain)
        let proofProver = try CirclePCSFRIResidentProverV1(
            context: context,
            domain: domain,
            securityParameters: securityParameters,
            publicInputs: publicInputs,
            roundCount: roundCount
        )
        self.domain = domain
        self.securityParameters = securityParameters
        self.publicInputs = publicInputs
        self.roundCount = roundCount
        self.commandPlan = try CircleCodewordPCSFRIResidentCommandPlanV1(
            codewordEngine: "circle-fft-butterfly-v1",
            coefficientInputs: CircleCodewordPCSFRICoefficientInputV1.allCases,
            phases: CircleCodewordPCSFRIResidentCommandPlanV1.canonicalPhases,
            publicReadbacks: CircleCodewordPCSFRIResidentCommandPlanV1.canonicalPublicReadbacks,
            codewordCommitmentSchedule: .materializedCodewordThenCommit,
            usesFusedTiledCodewordCommitment: false,
            forbidsFullCodewordReadback: true,
            forbidsIntermediateFRILayerReadback: true,
            codewordElementCount: domain.size,
            finalLayerElementCount: proofProver.outputCount,
            roundCount: roundCount,
            queryCount: Int(securityParameters.queryCount)
        )
        self.context = context
        self.codewordPlan = codewordPlan
        self.proofProver = proofProver
        self.codewordBuffer = try MetalBufferFactory.makePrivateBuffer(
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

    public func proveCircleFFTCoefficientsResident(
        circleCoefficientBuffer: MTLBuffer,
        circleCoefficientOffset: Int = 0
    ) throws -> CircleCodewordPCSFRIProverV1Result {
        executionLock.lock()
        defer { executionLock.unlock() }

        return try proveCircleFFTCoefficientsResidentLocked(
            circleCoefficientBuffer: circleCoefficientBuffer,
            circleCoefficientOffset: circleCoefficientOffset
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

    public func proveCircleFFTCoefficientsResidentVerified(
        polynomial: CircleCodewordPolynomial,
        circleCoefficientBuffer: MTLBuffer,
        circleCoefficientOffset: Int = 0
    ) throws -> CircleCodewordPCSFRIProverV1Result {
        let expectedCodeword = try CircleCodewordOracle.evaluate(
            polynomial: polynomial,
            domain: domain
        )
        let result = try proveCircleFFTCoefficientsResident(
            circleCoefficientBuffer: circleCoefficientBuffer,
            circleCoefficientOffset: circleCoefficientOffset
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
                "Circle codeword PCS/FRI resident FFT-coefficient prover emitted a proof rejected by the CPU oracle or verifier."
            )
        }
        return result
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
        try MetalBufferFactory.zeroPrivateBuffers(
            [codewordBuffer],
            context: context,
            label: "AppleZKProver.CircleCodewordPCSFRIProver.Clear"
        )
    }

    private func proveCircleFFTCoefficientsResidentLocked(
        circleCoefficientBuffer: MTLBuffer,
        circleCoefficientOffset: Int
    ) throws -> CircleCodewordPCSFRIProverV1Result {
        let start = DispatchTime.now()
        let codewordStats = try codewordPlan.executeResident(
            circleCoefficientBuffer: circleCoefficientBuffer,
            circleCoefficientOffset: circleCoefficientOffset,
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

    private static func sumGPUSeconds(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard let lhs, let rhs else {
            return nil
        }
        return lhs + rhs
    }
}
#endif
