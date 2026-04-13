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

public final class CircleFRIFoldChainPlan: @unchecked Sendable {
    public static let elementByteCount = QM31FRILeafEncoding.elementByteCount

    public let domain: CircleDomainDescriptor
    public let inputCount: Int
    public let roundCount: Int
    public let outputCount: Int
    public let totalInverseDomainCount: Int
    public let inverseDomainLayers: [[QM31Element]]

    private let foldChainPlan: QM31FRIFoldChainPlan
    private let inverseDomainBuffer: MTLBuffer

    public init(
        context: MetalContext,
        domain: CircleDomainDescriptor,
        roundCount: Int
    ) throws {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed,
              roundCount > 0,
              roundCount <= Int(domain.logSize) else {
            throw AppleZKProverError.invalidInputLayout
        }

        let inverseDomainLayers = try CircleFRILayerOracleV1.inverseDomainLayers(
            for: domain,
            roundCount: roundCount
        )
        guard inverseDomainLayers.count == roundCount else {
            throw AppleZKProverError.invalidInputLayout
        }

        var currentCount = domain.size
        var totalInverseDomainCount = 0
        for layer in inverseDomainLayers {
            guard currentCount > 1,
                  currentCount.isMultiple(of: 2),
                  layer.count == currentCount / 2 else {
                throw AppleZKProverError.invalidInputLayout
            }
            try QM31Field.validateCanonical(layer)
            guard layer.allSatisfy({ !QM31Field.isZero($0) }) else {
                throw AppleZKProverError.invalidInputLayout
            }
            let nextTotal = totalInverseDomainCount.addingReportingOverflow(layer.count)
            guard !nextTotal.overflow else {
                throw AppleZKProverError.invalidInputLayout
            }
            totalInverseDomainCount = nextTotal.partialValue
            currentCount /= 2
        }

        self.domain = domain
        self.inputCount = domain.size
        self.roundCount = roundCount
        self.outputCount = currentCount
        self.totalInverseDomainCount = totalInverseDomainCount
        self.inverseDomainLayers = inverseDomainLayers
        self.foldChainPlan = try QM31FRIFoldChainPlan(
            context: context,
            inputCount: domain.size,
            roundCount: roundCount
        )
        self.inverseDomainBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            bytes: QM31FRILeafEncoding.packLittleEndian(inverseDomainLayers.flatMap { $0 }),
            declaredLength: try checkedBufferLength(totalInverseDomainCount, Self.elementByteCount),
            label: "AppleZKProver.CircleFRIFoldChainInverseDomain"
        )
    }

    public func execute(
        evaluations: [QM31Element],
        challenges: [QM31Element]
    ) throws -> QM31FRIFoldChainResult {
        try validateInputs(evaluations: evaluations, challenges: challenges)
        let rounds = zip(inverseDomainLayers, challenges).map {
            QM31FRIFoldRound(inverseDomainPoints: $0.0, challenge: $0.1)
        }
        return try foldChainPlan.execute(evaluations: evaluations, rounds: rounds)
    }

    public func executeVerified(
        evaluations: [QM31Element],
        challenges: [QM31Element]
    ) throws -> QM31FRIFoldChainResult {
        let expected = try CircleFRILayerOracleV1.fold(
            evaluations: evaluations,
            domain: domain,
            challenges: challenges
        )
        let measured = try execute(evaluations: evaluations, challenges: challenges)
        guard measured.values == expected else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Circle FRI fold-chain GPU result did not match the CPU oracle."
            )
        }
        return measured
    }

    public func executeResident(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int = 0,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0,
        challenges: [QM31Element]
    ) throws -> GPUExecutionStats {
        try validateChallenges(challenges)
        return try foldChainPlan.executeResident(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: 0,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset,
            challenges: challenges
        )
    }

    public func clearReusableBuffers() throws {
        try foldChainPlan.clearReusableBuffers()
    }

    private func validateInputs(
        evaluations: [QM31Element],
        challenges: [QM31Element]
    ) throws {
        guard evaluations.count == inputCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        try validateChallenges(challenges)
    }

    private func validateChallenges(_ challenges: [QM31Element]) throws {
        guard challenges.count == roundCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(challenges)
    }
}

public struct CircleFRIMerkleTranscriptFoldChainResult: Sendable {
    public let values: [QM31Element]
    public let commitments: [Data]
    public let challenges: [QM31Element]
    public let stats: GPUExecutionStats

    public init(
        values: [QM31Element],
        commitments: [Data],
        challenges: [QM31Element],
        stats: GPUExecutionStats
    ) {
        self.values = values
        self.commitments = commitments
        self.challenges = challenges
        self.stats = stats
    }
}

public final class CircleFRIMerkleTranscriptFoldChainPlan: @unchecked Sendable {
    public static let elementByteCount = QM31FRILeafEncoding.elementByteCount
    public static let commitmentByteCount = QM31FRIFoldTranscriptOracle.commitmentByteCount

    public let domain: CircleDomainDescriptor
    public let securityParameters: CircleFRISecurityParametersV1
    public let publicInputDigest: Data
    public let inputCount: Int
    public let roundCount: Int
    public let outputCount: Int
    public let totalInverseDomainCount: Int
    public let inverseDomainLayers: [[QM31Element]]
    public let committedLayerCounts: [Int]
    public let committedLayerElementOffsets: [Int]
    public let totalCommittedLayerCount: Int

    private let foldChainPlan: QM31FRIFoldChainPlan
    private let inverseDomainBuffer: MTLBuffer

    public convenience init(
        context: MetalContext,
        domain: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputs: CirclePCSFRIPublicInputsV1,
        roundCount: Int
    ) throws {
        try self.init(
            context: context,
            domain: domain,
            securityParameters: securityParameters,
            publicInputDigest: publicInputs.publicInputDigest,
            roundCount: roundCount
        )
    }

    public init(
        context: MetalContext,
        domain: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputDigest: Data,
        roundCount: Int
    ) throws {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed,
              securityParameters.foldingStep == 1,
              publicInputDigest.count == 32,
              roundCount > 0,
              roundCount <= Int(domain.logSize) else {
            throw AppleZKProverError.invalidInputLayout
        }

        let preparedLayers = try Self.prepareInverseDomainLayers(domain: domain, roundCount: roundCount)
        let committedLayerLayout = try Self.committedLayerLayout(
            inputCount: domain.size,
            roundCount: roundCount
        )
        let transcriptFrameData = try Self.makeTranscriptFrameData(
            domain: domain,
            securityParameters: securityParameters,
            publicInputDigest: publicInputDigest,
            roundCount: roundCount
        )

        self.domain = domain
        self.securityParameters = securityParameters
        self.publicInputDigest = publicInputDigest
        self.inputCount = domain.size
        self.roundCount = roundCount
        self.outputCount = preparedLayers.outputCount
        self.totalInverseDomainCount = preparedLayers.totalInverseDomainCount
        self.inverseDomainLayers = preparedLayers.layers
        self.committedLayerCounts = committedLayerLayout.counts
        self.committedLayerElementOffsets = committedLayerLayout.offsets
        self.totalCommittedLayerCount = committedLayerLayout.totalElementCount
        self.foldChainPlan = try QM31FRIFoldChainPlan(
            context: context,
            inputCount: domain.size,
            roundCount: roundCount,
            transcriptFrameData: transcriptFrameData
        )
        self.inverseDomainBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            bytes: QM31FRILeafEncoding.packLittleEndian(preparedLayers.layers.flatMap { $0 }),
            declaredLength: try checkedBufferLength(preparedLayers.totalInverseDomainCount, Self.elementByteCount),
            label: "AppleZKProver.CircleFRIMerkleTranscriptInverseDomain"
        )
    }

    public func execute(evaluations: [QM31Element]) throws -> CircleFRIMerkleTranscriptFoldChainResult {
        try validateEvaluations(evaluations)
        let measured = try foldChainPlan.executeMerkleTranscriptDerived(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers
        )
        return CircleFRIMerkleTranscriptFoldChainResult(
            values: measured.values,
            commitments: measured.commitments,
            challenges: measured.challenges,
            stats: measured.stats
        )
    }

    public func executeVerified(evaluations: [QM31Element]) throws -> CircleFRIMerkleTranscriptFoldChainResult {
        let expected = try Self.commitAndFoldOracle(
            evaluations: evaluations,
            domain: domain,
            securityParameters: securityParameters,
            publicInputDigest: publicInputDigest,
            inverseDomainLayers: inverseDomainLayers
        )
        let measured = try execute(evaluations: evaluations)
        guard measured.values == expected.values,
              measured.commitments == expected.commitments,
              measured.challenges == expected.challenges else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Circle FRI Merkle-transcript GPU fold chain did not match the CPU oracle."
            )
        }
        return measured
    }

    public func executeResident(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int = 0,
        commitmentOutputBuffer: MTLBuffer,
        commitmentOutputOffset: Int = 0,
        commitmentOutputStride: Int = CircleFRIMerkleTranscriptFoldChainPlan.commitmentByteCount,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0
    ) throws -> GPUExecutionStats {
        try foldChainPlan.executeMerkleTranscriptDerivedResident(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: 0,
            commitmentOutputBuffer: commitmentOutputBuffer,
            commitmentOutputOffset: commitmentOutputOffset,
            commitmentOutputStride: commitmentOutputStride,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset
        )
    }

    public func executeMaterializedResident(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int = 0,
        committedLayerBuffer: MTLBuffer,
        committedLayerOffset: Int = 0,
        commitmentOutputBuffer: MTLBuffer,
        commitmentOutputOffset: Int = 0,
        commitmentOutputStride: Int = CircleFRIMerkleTranscriptFoldChainPlan.commitmentByteCount,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0
    ) throws -> GPUExecutionStats {
        try foldChainPlan.executeMerkleTranscriptDerivedResident(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: 0,
            commitmentOutputBuffer: commitmentOutputBuffer,
            commitmentOutputOffset: commitmentOutputOffset,
            commitmentOutputStride: commitmentOutputStride,
            materializedLayerBuffer: committedLayerBuffer,
            materializedLayerOffset: committedLayerOffset,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset
        )
    }

    public func clearReusableBuffers() throws {
        try foldChainPlan.clearReusableBuffers()
    }

    private func validateEvaluations(_ evaluations: [QM31Element]) throws {
        guard evaluations.count == inputCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
    }

    private static func prepareInverseDomainLayers(
        domain: CircleDomainDescriptor,
        roundCount: Int
    ) throws -> (layers: [[QM31Element]], totalInverseDomainCount: Int, outputCount: Int) {
        let layers = try CircleFRILayerOracleV1.inverseDomainLayers(
            for: domain,
            roundCount: roundCount
        )
        guard layers.count == roundCount else {
            throw AppleZKProverError.invalidInputLayout
        }

        var currentCount = domain.size
        var totalInverseDomainCount = 0
        for layer in layers {
            guard currentCount > 1,
                  currentCount.isMultiple(of: 2),
                  layer.count == currentCount / 2 else {
                throw AppleZKProverError.invalidInputLayout
            }
            try QM31Field.validateCanonical(layer)
            guard layer.allSatisfy({ !QM31Field.isZero($0) }) else {
                throw AppleZKProverError.invalidInputLayout
            }
            let nextTotal = totalInverseDomainCount.addingReportingOverflow(layer.count)
            guard !nextTotal.overflow else {
                throw AppleZKProverError.invalidInputLayout
            }
            totalInverseDomainCount = nextTotal.partialValue
            currentCount /= 2
        }
        return (layers, totalInverseDomainCount, currentCount)
    }

    private static func committedLayerLayout(
        inputCount: Int,
        roundCount: Int
    ) throws -> (counts: [Int], offsets: [Int], totalElementCount: Int) {
        guard inputCount > 1, roundCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var counts: [Int] = []
        var offsets: [Int] = []
        counts.reserveCapacity(roundCount)
        offsets.reserveCapacity(roundCount)

        var currentCount = inputCount
        var total = 0
        for _ in 0..<roundCount {
            guard currentCount > 1, currentCount.isMultiple(of: 2) else {
                throw AppleZKProverError.invalidInputLayout
            }
            counts.append(currentCount)
            offsets.append(total)
            let nextTotal = total.addingReportingOverflow(currentCount)
            guard !nextTotal.overflow else {
                throw AppleZKProverError.invalidInputLayout
            }
            total = nextTotal.partialValue
            currentCount /= 2
        }
        return (counts, offsets, total)
    }

    private static func makeTranscriptFrameData(
        domain: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputDigest: Data,
        roundCount: Int
    ) throws -> QM31FRIFoldTranscriptFrameData {
        let prefix = [
            CircleFRITranscriptV1.headerFrame(
                transcriptVersion: CirclePCSFRIProofV1.currentTranscriptVersion
            ),
            try CircleDomainDescriptorCodecV1.encode(domain),
            CircleFRITranscriptV1.securityFrame(securityParameters),
            try CircleFRITranscriptV1.publicInputFrame(byteCount: publicInputDigest.count),
            publicInputDigest,
        ]

        var commitmentFrames: [Data] = []
        var challengeFrames: [Data] = []
        commitmentFrames.reserveCapacity(roundCount)
        challengeFrames.reserveCapacity(roundCount)
        for roundIndex in 0..<roundCount {
            commitmentFrames.append(
                try CircleFRITranscriptV1.commitmentFrame(
                    index: roundIndex,
                    byteCount: Self.commitmentByteCount
                )
            )
            challengeFrames.append(try CircleFRITranscriptV1.challengeFrame(index: roundIndex))
        }
        return try QM31FRIFoldTranscriptFrameData(
            prefix: prefix,
            rounds: commitmentFrames,
            challenges: challengeFrames
        )
    }

    private static func commitAndFoldOracle(
        evaluations: [QM31Element],
        domain: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputDigest: Data,
        inverseDomainLayers: [[QM31Element]]
    ) throws -> (values: [QM31Element], commitments: [Data], challenges: [QM31Element]) {
        guard evaluations.count == domain.size,
              inverseDomainLayers.count > 0,
              inverseDomainLayers.count <= Int(domain.logSize) else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)

        var current = evaluations
        var commitments: [Data] = []
        var challenges: [QM31Element] = []
        commitments.reserveCapacity(inverseDomainLayers.count)
        challenges.reserveCapacity(inverseDomainLayers.count)

        for (roundIndex, inverseDomainLayer) in inverseDomainLayers.enumerated() {
            guard current.count > 1,
                  current.count.isMultiple(of: 2),
                  inverseDomainLayer.count == current.count / 2 else {
                throw AppleZKProverError.invalidInputLayout
            }

            let commitment = try MerkleOracle.rootSHA3_256(
                rawLeaves: QM31CanonicalEncoding.pack(current),
                leafCount: current.count,
                leafStride: QM31CanonicalEncoding.elementByteCount,
                leafLength: QM31CanonicalEncoding.elementByteCount
            )
            commitments.append(commitment)

            let prefixChallenges = try CircleFRITranscriptV1.deriveChallenges(
                domain: domain,
                securityParameters: securityParameters,
                publicInputDigest: publicInputDigest,
                commitments: commitments
            )
            guard prefixChallenges.count == commitments.count else {
                throw AppleZKProverError.invalidInputLayout
            }

            let challenge = prefixChallenges[roundIndex]
            challenges.append(challenge)
            current = try QM31FRIFoldOracle.fold(
                evaluations: current,
                inverseDomainPoints: inverseDomainLayer,
                challenge: challenge
            )
        }

        return (current, commitments, challenges)
    }
}

public struct CircleFRIResidentQueryExtractionResult: Sendable {
    public let queries: [CircleFRIQueryV1]
    public let openingCount: Int
    public let stats: GPUExecutionStats

    public init(
        queries: [CircleFRIQueryV1],
        openingCount: Int,
        stats: GPUExecutionStats
    ) {
        self.queries = queries
        self.openingCount = openingCount
        self.stats = stats
    }
}

public struct CirclePCSFRIResidentProverV1Result: Sendable {
    public let proof: CirclePCSFRIProofV1
    public let encodedProof: Data
    public let foldStats: GPUExecutionStats
    public let queryExtractionStats: GPUExecutionStats
    public let stats: GPUExecutionStats

    public init(
        proof: CirclePCSFRIProofV1,
        encodedProof: Data,
        foldStats: GPUExecutionStats,
        queryExtractionStats: GPUExecutionStats,
        stats: GPUExecutionStats
    ) {
        self.proof = proof
        self.encodedProof = encodedProof
        self.foldStats = foldStats
        self.queryExtractionStats = queryExtractionStats
        self.stats = stats
    }

    public var proofByteCount: Int {
        encodedProof.count
    }
}

public final class CirclePCSFRIResidentProverV1: @unchecked Sendable {
    public static let elementByteCount = CircleFRIMerkleTranscriptFoldChainPlan.elementByteCount
    public static let commitmentByteCount = CircleFRIMerkleTranscriptFoldChainPlan.commitmentByteCount

    public let domain: CircleDomainDescriptor
    public let securityParameters: CircleFRISecurityParametersV1
    public let publicInputs: CirclePCSFRIPublicInputsV1
    public let inputCount: Int
    public let roundCount: Int
    public let outputCount: Int
    public let totalCommittedLayerCount: Int

    private let context: MetalContext
    private let foldPlan: CircleFRIMerkleTranscriptFoldChainPlan
    private let queryExtractor: CircleFRIResidentQueryExtractorV1
    private let committedLayerBuffer: MTLBuffer
    private let commitmentOutputBuffer: MTLBuffer
    private let finalLayerBuffer: MTLBuffer
    private let executionLock = NSLock()

    public init(
        context: MetalContext,
        domain: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputs: CirclePCSFRIPublicInputsV1,
        roundCount: Int
    ) throws {
        let foldPlan = try CircleFRIMerkleTranscriptFoldChainPlan(
            context: context,
            domain: domain,
            securityParameters: securityParameters,
            publicInputs: publicInputs,
            roundCount: roundCount
        )
        let queryExtractor = try CircleFRIResidentQueryExtractorV1(
            context: context,
            domain: domain,
            roundCount: roundCount
        )

        self.context = context
        self.domain = domain
        self.securityParameters = securityParameters
        self.publicInputs = publicInputs
        self.inputCount = foldPlan.inputCount
        self.roundCount = foldPlan.roundCount
        self.outputCount = foldPlan.outputCount
        self.totalCommittedLayerCount = foldPlan.totalCommittedLayerCount
        self.foldPlan = foldPlan
        self.queryExtractor = queryExtractor
        self.committedLayerBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: try checkedBufferLength(foldPlan.totalCommittedLayerCount, Self.elementByteCount),
            label: "AppleZKProver.CirclePCSFRIResidentProver.CommittedLayers"
        )
        self.commitmentOutputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: try checkedBufferLength(roundCount, Self.commitmentByteCount),
            label: "AppleZKProver.CirclePCSFRIResidentProver.Commitments"
        )
        self.finalLayerBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: try checkedBufferLength(foldPlan.outputCount, Self.elementByteCount),
            label: "AppleZKProver.CirclePCSFRIResidentProver.FinalLayer"
        )
    }

    public func prove(
        evaluations: [QM31Element]
    ) throws -> CirclePCSFRIResidentProverV1Result {
        guard evaluations.count == inputCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        let evaluationBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            bytes: QM31CanonicalEncoding.pack(evaluations),
            declaredLength: try checkedBufferLength(evaluations.count, Self.elementByteCount),
            label: "AppleZKProver.CirclePCSFRIResidentProver.UploadedEvaluations"
        )
        return try prove(
            evaluationsBuffer: evaluationBuffer,
            evaluationsOffset: 0
        )
    }

    public func prove(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int = 0
    ) throws -> CirclePCSFRIResidentProverV1Result {
        executionLock.lock()
        defer { executionLock.unlock() }

        let start = DispatchTime.now()
        let foldStats = try foldPlan.executeMaterializedResident(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            committedLayerBuffer: committedLayerBuffer,
            commitmentOutputBuffer: commitmentOutputBuffer,
            outputBuffer: finalLayerBuffer
        )

        let commitments = try Self.readCommitments(
            commitmentOutputBuffer,
            count: roundCount
        )
        let finalLayer = try Self.readQM31Buffer(
            finalLayerBuffer,
            count: outputCount
        )
        let transcript = try CircleFRITranscriptV1.derive(
            domain: domain,
            securityParameters: securityParameters,
            publicInputDigest: publicInputs.publicInputDigest,
            commitments: commitments,
            finalLayer: finalLayer
        )
        let extracted = try queryExtractor.extractQueries(
            committedLayerBuffer: committedLayerBuffer,
            commitments: commitments,
            queryPairIndices: transcript.queryPairIndices
        )
        let proof = try CirclePCSFRIProofV1(
            domain: domain,
            securityParameters: securityParameters,
            publicInputDigest: publicInputs.publicInputDigest,
            commitments: commitments,
            finalLayer: finalLayer,
            queries: extracted.queries
        )
        let encodedProof = try CirclePCSFRIProofCodecV1.encode(proof)
        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        return CirclePCSFRIResidentProverV1Result(
            proof: proof,
            encodedProof: encodedProof,
            foldStats: foldStats,
            queryExtractionStats: extracted.stats,
            stats: GPUExecutionStats(
                cpuWallSeconds: wall,
                gpuSeconds: Self.sumGPUSeconds(foldStats.gpuSeconds, extracted.stats.gpuSeconds)
            )
        )
    }

    public func proveVerified(
        evaluations: [QM31Element]
    ) throws -> CirclePCSFRIResidentProverV1Result {
        let result = try prove(evaluations: evaluations)
        try verifyResult(result)
        return result
    }

    public func proveVerified(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int = 0
    ) throws -> CirclePCSFRIResidentProverV1Result {
        let result = try prove(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset
        )
        try verifyResult(result)
        return result
    }

    public func clearReusableBuffers() throws {
        executionLock.lock()
        defer { executionLock.unlock() }

        try foldPlan.clearReusableBuffers()
        try queryExtractor.clearReusableBuffers()
        MetalBufferFactory.zeroSharedBuffer(committedLayerBuffer)
        MetalBufferFactory.zeroSharedBuffer(commitmentOutputBuffer)
        MetalBufferFactory.zeroSharedBuffer(finalLayerBuffer)
    }

    private func verifyResult(_ result: CirclePCSFRIResidentProverV1Result) throws {
        let decoded = try CirclePCSFRIProofCodecV1.decode(result.encodedProof)
        guard decoded == result.proof,
              try CirclePCSFRIProofVerifierV1.verify(
                proof: result.proof,
                publicInputs: publicInputs
              ) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Resident Circle PCS/FRI prover emitted a proof rejected by the independent verifier."
            )
        }
    }

    private static func sumGPUSeconds(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard let lhs, let rhs else {
            return nil
        }
        return lhs + rhs
    }

    private static func readCommitments(_ buffer: MTLBuffer, count: Int) throws -> [Data] {
        guard count >= 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let byteCount = try checkedBufferLength(count, commitmentByteCount)
        try validateBufferRange(buffer: buffer, offset: 0, byteCount: byteCount)
        var commitments: [Data] = []
        commitments.reserveCapacity(count)
        for index in 0..<count {
            commitments.append(Data(
                bytes: buffer.contents().advanced(by: index * commitmentByteCount),
                count: commitmentByteCount
            ))
        }
        return commitments
    }

    private static func readQM31Buffer(_ buffer: MTLBuffer, count: Int) throws -> [QM31Element] {
        guard count >= 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
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
}

public final class CircleFRIResidentQueryExtractorV1: @unchecked Sendable {
    public static let elementByteCount = QM31FRILeafEncoding.elementByteCount

    public let domain: CircleDomainDescriptor
    public let roundCount: Int
    public let committedLayerCounts: [Int]
    public let committedLayerElementOffsets: [Int]
    public let totalCommittedLayerCount: Int

    private let merklePlans: [SHA3RawLeavesMerkleCommitPlan]

    public init(
        context: MetalContext,
        domain: CircleDomainDescriptor,
        roundCount: Int
    ) throws {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed,
              roundCount > 0,
              roundCount <= Int(domain.logSize) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let layout = try Self.committedLayerLayout(inputCount: domain.size, roundCount: roundCount)
        self.domain = domain
        self.roundCount = roundCount
        self.committedLayerCounts = layout.counts
        self.committedLayerElementOffsets = layout.offsets
        self.totalCommittedLayerCount = layout.totalElementCount
        self.merklePlans = try layout.counts.map { layerCount in
            try SHA3RawLeavesMerkleCommitPlan(
                context: context,
                leafCount: layerCount,
                leafStride: Self.elementByteCount,
                leafLength: Self.elementByteCount,
                configuration: .default
            )
        }
    }

    public func extractQueries(
        committedLayerBuffer: MTLBuffer,
        committedLayerOffset: Int = 0,
        commitments: [Data],
        queryPairIndices: [Int]
    ) throws -> CircleFRIResidentQueryExtractionResult {
        guard commitments.count == roundCount,
              commitments.allSatisfy({ $0.count == 32 }),
              !queryPairIndices.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        let byteCount = try checkedBufferLength(totalCommittedLayerCount, Self.elementByteCount)
        try Self.validateBufferRange(
            buffer: committedLayerBuffer,
            offset: committedLayerOffset,
            byteCount: byteCount
        )

        let start = DispatchTime.now()
        var gpuSecondsTotal: Double? = 0
        var queries: [CircleFRIQueryV1] = []
        queries.reserveCapacity(queryPairIndices.count)
        var openingCount = 0

        for initialPairIndex in queryPairIndices {
            guard initialPairIndex >= 0,
                  initialPairIndex < domain.halfSize else {
                throw AppleZKProverError.invalidInputLayout
            }

            var layers: [CircleFRIQueryLayerOpeningV1] = []
            layers.reserveCapacity(roundCount)
            var pairIndex = initialPairIndex
            for layerIndex in 0..<roundCount {
                let layerCount = committedLayerCounts[layerIndex]
                guard pairIndex >= 0,
                      pairIndex < layerCount / 2 else {
                    throw AppleZKProverError.invalidInputLayout
                }
                let layerByteOffset = committedLayerOffset
                    + committedLayerElementOffsets[layerIndex] * Self.elementByteCount
                let leftIndex = pairIndex * 2
                let rightIndex = leftIndex + 1
                let left = try extractOpening(
                    layerIndex: layerIndex,
                    leafIndex: leftIndex,
                    committedLayerBuffer: committedLayerBuffer,
                    layerByteOffset: layerByteOffset,
                    expectedRoot: commitments[layerIndex],
                    gpuSecondsTotal: &gpuSecondsTotal
                )
                let right = try extractOpening(
                    layerIndex: layerIndex,
                    leafIndex: rightIndex,
                    committedLayerBuffer: committedLayerBuffer,
                    layerByteOffset: layerByteOffset,
                    expectedRoot: commitments[layerIndex],
                    gpuSecondsTotal: &gpuSecondsTotal
                )
                openingCount += 2
                layers.append(CircleFRIQueryLayerOpeningV1(
                    layerIndex: UInt32(layerIndex),
                    pairIndex: UInt64(pairIndex),
                    left: left,
                    right: right
                ))
                pairIndex >>= 1
            }

            queries.append(try CircleFRIQueryV1(
                initialPairIndex: UInt64(initialPairIndex),
                layers: layers
            ))
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        return CircleFRIResidentQueryExtractionResult(
            queries: queries,
            openingCount: openingCount,
            stats: GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpuSecondsTotal)
        )
    }

    public func clearReusableBuffers() throws {
        for plan in merklePlans {
            try plan.clearReusableBuffers()
        }
    }

    private func extractOpening(
        layerIndex: Int,
        leafIndex: Int,
        committedLayerBuffer: MTLBuffer,
        layerByteOffset: Int,
        expectedRoot: Data,
        gpuSecondsTotal: inout Double?
    ) throws -> CircleFRIValueOpeningV1 {
        let opening = try merklePlans[layerIndex].openRawLeafResidentVerified(
            uploadBuffer: committedLayerBuffer,
            uploadOffset: layerByteOffset,
            leafIndex: leafIndex
        )
        guard opening.proof.root == expectedRoot else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Resident Circle FRI query opening root did not match the committed layer root."
            )
        }
        let value = try QM31CanonicalEncoding.unpack(opening.proof.leaf)
        if let currentGPUSecondsTotal = gpuSecondsTotal,
           let gpuSeconds = opening.stats.gpuSeconds {
            gpuSecondsTotal = currentGPUSecondsTotal + gpuSeconds
        } else {
            gpuSecondsTotal = nil
        }
        return try CircleFRIValueOpeningV1(
            leafIndex: UInt64(leafIndex),
            value: value,
            siblingHashes: opening.proof.siblingHashes
        )
    }

    private static func committedLayerLayout(
        inputCount: Int,
        roundCount: Int
    ) throws -> (counts: [Int], offsets: [Int], totalElementCount: Int) {
        guard inputCount > 1, roundCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var counts: [Int] = []
        var offsets: [Int] = []
        counts.reserveCapacity(roundCount)
        offsets.reserveCapacity(roundCount)

        var currentCount = inputCount
        var total = 0
        for _ in 0..<roundCount {
            guard currentCount > 1, currentCount.isMultiple(of: 2) else {
                throw AppleZKProverError.invalidInputLayout
            }
            counts.append(currentCount)
            offsets.append(total)
            let nextTotal = total.addingReportingOverflow(currentCount)
            guard !nextTotal.overflow else {
                throw AppleZKProverError.invalidInputLayout
            }
            total = nextTotal.partialValue
            currentCount /= 2
        }
        return (counts, offsets, total)
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
}
#endif
