#if canImport(Metal)
import Foundation
import Metal

public final class CircleFRIFoldPlan: @unchecked Sendable {
    public static let elementByteCount = QM31FRILeafEncoding.elementByteCount

    public let domain: CircleDomainDescriptor
    public let inputCount: Int
    public let outputCount: Int
    public let inverseYTwiddles: [QM31Element]

    private let foldPlan: QM31FRIFoldPlan
    private let inverseYTwiddleBuffer: MTLBuffer

    public init(context: MetalContext, domain: CircleDomainDescriptor) throws {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed,
              domain.size > 1 else {
            throw AppleZKProverError.invalidInputLayout
        }

        let inverseYTwiddles = try CircleDomainOracle.firstFoldInverseYTwiddles(for: domain)
        guard inverseYTwiddles.count == domain.halfSize,
              inverseYTwiddles.allSatisfy({ !QM31Field.isZero($0) }) else {
            throw AppleZKProverError.invalidInputLayout
        }

        self.domain = domain
        self.inputCount = domain.size
        self.outputCount = domain.halfSize
        self.inverseYTwiddles = inverseYTwiddles
        self.foldPlan = try QM31FRIFoldPlan(context: context, inputCount: domain.size)
        self.inverseYTwiddleBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            bytes: QM31FRILeafEncoding.packLittleEndian(inverseYTwiddles),
            declaredLength: try checkedBufferLength(domain.halfSize, Self.elementByteCount),
            label: "AppleZKProver.CircleFRIFoldInverseYTwiddles"
        )
    }

    public func execute(
        evaluations: [QM31Element],
        challenge: QM31Element
    ) throws -> QM31FRIFoldResult {
        try validateInputs(evaluations: evaluations, challenge: challenge)
        return try foldPlan.execute(
            evaluations: evaluations,
            inverseDomainPoints: inverseYTwiddles,
            challenge: challenge
        )
    }

    public func executeVerified(
        evaluations: [QM31Element],
        challenge: QM31Element
    ) throws -> QM31FRIFoldResult {
        let expected = try CircleFRIFoldOracle.foldCircleIntoLine(
            evaluations: evaluations,
            domain: domain,
            challenge: challenge
        )
        let measured = try execute(evaluations: evaluations, challenge: challenge)
        guard measured.values == expected else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Circle FRI first-fold GPU result did not match the CPU oracle."
            )
        }
        return measured
    }

    public func executeResident(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int = 0,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0,
        challenge: QM31Element
    ) throws -> GPUExecutionStats {
        try foldPlan.executeResident(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseYTwiddleBuffer,
            inverseDomainOffset: 0,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset,
            challenge: challenge
        )
    }

    public func clearReusableBuffers() throws {
        try foldPlan.clearReusableBuffers()
    }

    private func validateInputs(
        evaluations: [QM31Element],
        challenge: QM31Element
    ) throws {
        guard evaluations.count == inputCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        try QM31Field.validateCanonical([challenge])
    }
}
#endif
