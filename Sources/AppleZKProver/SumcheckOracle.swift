import Foundation

public enum M31Field {
    public static let modulus: UInt32 = 2_147_483_647

    public static func validateCanonical(_ values: [UInt32]) throws {
        guard values.allSatisfy({ $0 < modulus }) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    public static func add(_ lhs: UInt32, _ rhs: UInt32) -> UInt32 {
        let sum = lhs + rhs
        return sum >= modulus ? sum - modulus : sum
    }

    public static func subtract(_ lhs: UInt32, _ rhs: UInt32) -> UInt32 {
        lhs >= rhs ? lhs - rhs : modulus - (rhs - lhs)
    }

    public static func negate(_ value: UInt32) -> UInt32 {
        value == 0 ? 0 : modulus - value
    }

    public static func multiply(_ lhs: UInt32, _ rhs: UInt32) -> UInt32 {
        reduce(UInt64(lhs) * UInt64(rhs))
    }

    public static func square(_ value: UInt32) -> UInt32 {
        multiply(value, value)
    }

    public static func inverse(_ value: UInt32) throws -> UInt32 {
        guard value > 0, value < modulus else {
            throw AppleZKProverError.invalidInputLayout
        }
        return pow(value, exponent: modulus - 2)
    }

    public static func batchInverse(_ values: [UInt32]) throws -> [UInt32] {
        guard !values.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        try validateCanonical(values)
        guard values.allSatisfy({ $0 != 0 }) else {
            throw AppleZKProverError.invalidInputLayout
        }

        var prefixes = Array(repeating: UInt32(1), count: values.count)
        var accumulator: UInt32 = 1
        for index in values.indices {
            prefixes[index] = accumulator
            accumulator = multiply(accumulator, values[index])
        }

        var inverseAccumulator = try inverse(accumulator)
        var inverses = Array(repeating: UInt32(0), count: values.count)
        for index in values.indices.reversed() {
            inverses[index] = multiply(inverseAccumulator, prefixes[index])
            inverseAccumulator = multiply(inverseAccumulator, values[index])
        }
        return inverses
    }

    public static func dotProduct(lhs: [UInt32], rhs: [UInt32]) throws -> UInt32 {
        guard lhs.count == rhs.count, !lhs.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        try validateCanonical(lhs)
        try validateCanonical(rhs)

        var accumulator: UInt32 = 0
        for (left, right) in zip(lhs, rhs) {
            accumulator = add(accumulator, multiply(left, right))
        }
        return accumulator
    }

    public static func apply(
        _ operation: M31VectorOperation,
        lhs: [UInt32],
        rhs: [UInt32]? = nil
    ) throws -> [UInt32] {
        try validateCanonical(lhs)
        if operation.requiresRightHandSide {
            guard let rhs, rhs.count == lhs.count else {
                throw AppleZKProverError.invalidInputLayout
            }
            try validateCanonical(rhs)
            return zip(lhs, rhs).map { left, right in
                switch operation {
                case .add:
                    return add(left, right)
                case .subtract:
                    return subtract(left, right)
                case .multiply:
                    return multiply(left, right)
                case .negate, .square, .inverse:
                    preconditionFailure("unary M31 operation reached binary oracle path")
                }
            }
        }

        guard rhs == nil else {
            throw AppleZKProverError.invalidInputLayout
        }
        if operation == .inverse {
            return try batchInverse(lhs)
        }
        return lhs.map { value in
            switch operation {
            case .negate:
                return negate(value)
            case .square:
                return square(value)
            case .add, .subtract, .multiply:
                preconditionFailure("binary M31 operation reached unary oracle path")
            case .inverse:
                preconditionFailure("M31 inverse reached non-batch oracle path")
            }
        }
    }

    private static func pow(_ base: UInt32, exponent: UInt32) -> UInt32 {
        var result: UInt32 = 1
        var power = base
        var remaining = exponent
        while remaining > 0 {
            if remaining & 1 == 1 {
                result = multiply(result, power)
            }
            remaining >>= 1
            if remaining > 0 {
                power = square(power)
            }
        }
        return result
    }

    private static func reduce(_ value: UInt64) -> UInt32 {
        let modulus64 = UInt64(modulus)
        var reduced = (value & modulus64) + (value >> 31)
        reduced = (reduced & modulus64) + (reduced >> 31)
        reduced = (reduced & modulus64) + (reduced >> 31)
        return UInt32(reduced >= modulus64 ? reduced - modulus64 : reduced)
    }
}

public struct SumcheckChunkOracleResult: Equatable, Sendable {
    public let finalVector: [UInt32]
    public let coefficients: [UInt32]
    public let challenges: [UInt32]

    public init(finalVector: [UInt32], coefficients: [UInt32], challenges: [UInt32]) {
        self.finalVector = finalVector
        self.coefficients = coefficients
        self.challenges = challenges
    }
}

public enum M31SumcheckOpenBoundaryV1: String, Codable, CaseIterable, Sendable {
    case airConstraintReduction = "air-constraint-reduction"
    case fullSumcheckProtocol = "full-sumcheck-protocol"
    case zeroKnowledge = "zero-knowledge"
}

public enum M31SumcheckClaimScopeV1: String, Codable, CaseIterable, Sendable {
    case revealedEvaluationVectorFoldingTrace = "revealed-evaluation-vector-folding-trace"
    case fullMultilinearSumcheck = "full-multilinear-sumcheck"
    case airConstraintSumcheck = "air-constraint-sumcheck"
    case zeroKnowledgeAIRConstraintSumcheck = "zero-knowledge-air-constraint-sumcheck"
}

public struct M31SumcheckManifestV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1
    public static let artifactName = "M31SumcheckProofV1"
    public static let current = M31SumcheckManifestV1()

    public let version: UInt32
    public let artifact: String
    public let verifiesChunkTranscriptFolding: Bool
    public let verifiesAIRConstraintReduction: Bool
    public let verifiesFullSumcheckProtocol: Bool
    public let isZeroKnowledge: Bool
    public let revealsInitialEvaluationVector: Bool
    public let acceptedClaimScope: M31SumcheckClaimScopeV1
    public let rejectedClaimScopes: [M31SumcheckClaimScopeV1]
    public let openBoundaries: [M31SumcheckOpenBoundaryV1]

    public init() {
        self.version = Self.currentVersion
        self.artifact = Self.artifactName
        self.verifiesChunkTranscriptFolding = true
        self.verifiesAIRConstraintReduction = false
        self.verifiesFullSumcheckProtocol = false
        self.isZeroKnowledge = false
        self.revealsInitialEvaluationVector = true
        self.acceptedClaimScope = .revealedEvaluationVectorFoldingTrace
        self.rejectedClaimScopes = [
            .fullMultilinearSumcheck,
            .airConstraintSumcheck,
            .zeroKnowledgeAIRConstraintSumcheck,
        ]
        self.openBoundaries = [
            .airConstraintReduction,
            .fullSumcheckProtocol,
            .zeroKnowledge,
        ]
    }
}

public enum SumcheckOracle {
    public static func m31Chunk(
        evaluations: [UInt32],
        rounds: Int
    ) throws -> SumcheckChunkOracleResult {
        guard evaluations.count > 1,
              evaluations.count.nonzeroBitCount == 1,
              rounds > 0,
              rounds <= log2(evaluations.count) else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(evaluations)

        var transcript = SHA3Oracle.TranscriptState()
        var current = evaluations
        var allCoefficients: [UInt32] = []
        var challenges: [UInt32] = []

        try transcript.absorb(SumcheckTranscriptFraming.header(
            laneCount: evaluations.count,
            rounds: rounds,
            fieldModulus: M31Field.modulus
        ))

        for round in 0..<rounds {
            let pairCount = current.count / 2
            var roundCoefficients: [UInt32] = []
            roundCoefficients.reserveCapacity(pairCount * 2)

            for index in 0..<pairCount {
                roundCoefficients.append(current[index * 2])
                roundCoefficients.append(current[index * 2 + 1])
            }

            try transcript.absorb(SumcheckTranscriptFraming.round(
                roundIndex: round,
                activeLaneCount: current.count,
                coefficientWordCount: roundCoefficients.count
            ))
            try transcript.absorb(packLittleEndian(roundCoefficients))
            try transcript.absorb(SumcheckTranscriptFraming.challenge(
                roundIndex: round,
                fieldModulus: M31Field.modulus
            ))
            let challenge = try transcript.squeezeUInt32(count: 1, modulus: M31Field.modulus)[0]
            challenges.append(challenge)
            allCoefficients.append(contentsOf: roundCoefficients)

            var next = Array(repeating: UInt32(0), count: pairCount)
            for index in 0..<pairCount {
                next[index] = fold(
                    current[index * 2],
                    current[index * 2 + 1],
                    challenge: challenge
                )
            }
            current = next
        }

        return SumcheckChunkOracleResult(
            finalVector: current,
            coefficients: allCoefficients,
            challenges: challenges
        )
    }

    private static func fold(_ a: UInt32, _ b: UInt32, challenge: UInt32) -> UInt32 {
        M31Field.add(a, M31Field.multiply(b, challenge))
    }

    private static func packLittleEndian(_ words: [UInt32]) -> Data {
        var data = Data()
        data.reserveCapacity(words.count * MemoryLayout<UInt32>.stride)
        for word in words {
            data.append(UInt8(word & 0xff))
            data.append(UInt8((word >> 8) & 0xff))
            data.append(UInt8((word >> 16) & 0xff))
            data.append(UInt8((word >> 24) & 0xff))
        }
        return data
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
}

public struct M31SumcheckStatementV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let laneCount: Int
    public let rounds: Int
    public let initialEvaluationDigest: Data
    public let finalVectorDigest: Data

    public init(
        version: UInt32 = currentVersion,
        laneCount: Int,
        rounds: Int,
        initialEvaluationDigest: Data,
        finalVectorDigest: Data
    ) throws {
        guard version == Self.currentVersion,
              laneCount > 1,
              laneCount.nonzeroBitCount == 1,
              rounds > 0,
              rounds <= Self.log2(laneCount),
              initialEvaluationDigest.count == 32,
              finalVectorDigest.count == 32 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.laneCount = laneCount
        self.rounds = rounds
        self.initialEvaluationDigest = initialEvaluationDigest
        self.finalVectorDigest = finalVectorDigest
    }

    public var finalLaneCount: Int {
        laneCount >> rounds
    }

    public func digest() throws -> Data {
        var data = Data()
        data.append(Self.statementFrame())
        CanonicalBinary.appendUInt64(UInt64(laneCount), to: &data)
        CanonicalBinary.appendUInt32(try checkedUInt32(rounds), to: &data)
        data.append(initialEvaluationDigest)
        data.append(finalVectorDigest)
        return SHA3Oracle.sha3_256(data)
    }

    static func totalCoefficientWords(laneCount: Int, rounds: Int) throws -> Int {
        guard laneCount > 1,
              laneCount.nonzeroBitCount == 1,
              rounds > 0,
              rounds <= log2(laneCount) else {
            throw AppleZKProverError.invalidInputLayout
        }
        var activeLaneCount = laneCount
        var total = 0
        for _ in 0..<rounds {
            let next = total.addingReportingOverflow(activeLaneCount)
            guard !next.overflow else {
                throw AppleZKProverError.invalidInputLayout
            }
            total = next.partialValue
            activeLaneCount >>= 1
        }
        return total
    }

    static func coefficientOffsets(laneCount: Int, rounds: Int) throws -> [Int] {
        guard laneCount > 1,
              laneCount.nonzeroBitCount == 1,
              rounds > 0,
              rounds <= log2(laneCount) else {
            throw AppleZKProverError.invalidInputLayout
        }
        var offsets: [Int] = []
        offsets.reserveCapacity(rounds)
        var activeLaneCount = laneCount
        var offset = 0
        for _ in 0..<rounds {
            offsets.append(offset)
            let next = offset.addingReportingOverflow(activeLaneCount)
            guard !next.overflow else {
                throw AppleZKProverError.invalidInputLayout
            }
            offset = next.partialValue
            activeLaneCount >>= 1
        }
        return offsets
    }

    private static func statementFrame() -> Data {
        var frame = Data()
        let domain = Data("AppleZKProver.M31Sumcheck.Statement.V1".utf8)
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &frame)
        frame.append(domain)
        CanonicalBinary.appendUInt32(currentVersion, to: &frame)
        return frame
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
}

public struct M31SumcheckProofV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let statement: M31SumcheckStatementV1
    public let finalVector: [UInt32]
    public let coefficients: [UInt32]
    public let challenges: [UInt32]

    public init(
        version: UInt32 = currentVersion,
        statement: M31SumcheckStatementV1,
        finalVector: [UInt32],
        coefficients: [UInt32],
        challenges: [UInt32]
    ) throws {
        guard version == Self.currentVersion,
              finalVector.count == statement.finalLaneCount,
              coefficients.count == (try M31SumcheckStatementV1.totalCoefficientWords(
                laneCount: statement.laneCount,
                rounds: statement.rounds
              )),
              challenges.count == statement.rounds else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(finalVector)
        try M31Field.validateCanonical(coefficients)
        try M31Field.validateCanonical(challenges)
        self.version = version
        self.statement = statement
        self.finalVector = finalVector
        self.coefficients = coefficients
        self.challenges = challenges
    }
}

public struct M31SumcheckVerificationReportV1: Equatable, Sendable {
    public let proofStatementMatchesExpectedStatement: Bool
    public let proofShapeMatchesExpectedStatement: Bool
    public let initialEvaluationDigestMatchesRevealedVector: Bool
    public let finalVectorDigestMatches: Bool
    public let transcriptChallengesVerified: Bool
    public let foldRelationVerified: Bool
    public let airConstraintReductionVerified: Bool
    public let fullSumcheckProtocolVerified: Bool
    public let isZeroKnowledge: Bool
    public let revealsInitialEvaluationVector: Bool
    public let openBoundaries: [M31SumcheckOpenBoundaryV1]

    public init(
        proofStatementMatchesExpectedStatement: Bool,
        proofShapeMatchesExpectedStatement: Bool,
        initialEvaluationDigestMatchesRevealedVector: Bool,
        finalVectorDigestMatches: Bool,
        transcriptChallengesVerified: Bool,
        foldRelationVerified: Bool,
        airConstraintReductionVerified: Bool,
        fullSumcheckProtocolVerified: Bool,
        isZeroKnowledge: Bool,
        revealsInitialEvaluationVector: Bool,
        openBoundaries: [M31SumcheckOpenBoundaryV1]
    ) {
        self.proofStatementMatchesExpectedStatement = proofStatementMatchesExpectedStatement
        self.proofShapeMatchesExpectedStatement = proofShapeMatchesExpectedStatement
        self.initialEvaluationDigestMatchesRevealedVector = initialEvaluationDigestMatchesRevealedVector
        self.finalVectorDigestMatches = finalVectorDigestMatches
        self.transcriptChallengesVerified = transcriptChallengesVerified
        self.foldRelationVerified = foldRelationVerified
        self.airConstraintReductionVerified = airConstraintReductionVerified
        self.fullSumcheckProtocolVerified = fullSumcheckProtocolVerified
        self.isZeroKnowledge = isZeroKnowledge
        self.revealsInitialEvaluationVector = revealsInitialEvaluationVector
        self.openBoundaries = openBoundaries
    }

    public var revealedEvaluationVectorFoldingTraceVerified: Bool {
        proofStatementMatchesExpectedStatement &&
            proofShapeMatchesExpectedStatement &&
            initialEvaluationDigestMatchesRevealedVector &&
            finalVectorDigestMatches &&
            transcriptChallengesVerified &&
            foldRelationVerified
    }

    public var fullMultilinearSumcheckVerified: Bool {
        revealedEvaluationVectorFoldingTraceVerified && fullSumcheckProtocolVerified
    }

    public var airConstraintSumcheckVerified: Bool {
        fullMultilinearSumcheckVerified && airConstraintReductionVerified
    }

    public var zeroKnowledgeAIRConstraintSumcheckVerified: Bool {
        airConstraintSumcheckVerified && isZeroKnowledge && !revealsInitialEvaluationVector
    }

    public var acceptedClaimScope: M31SumcheckClaimScopeV1? {
        if zeroKnowledgeAIRConstraintSumcheckVerified {
            return .zeroKnowledgeAIRConstraintSumcheck
        }
        if airConstraintSumcheckVerified {
            return .airConstraintSumcheck
        }
        if fullMultilinearSumcheckVerified {
            return .fullMultilinearSumcheck
        }
        if revealedEvaluationVectorFoldingTraceVerified {
            return .revealedEvaluationVectorFoldingTrace
        }
        return nil
    }

    public func verifies(_ scope: M31SumcheckClaimScopeV1) -> Bool {
        switch scope {
        case .revealedEvaluationVectorFoldingTrace:
            return revealedEvaluationVectorFoldingTraceVerified
        case .fullMultilinearSumcheck:
            return fullMultilinearSumcheckVerified
        case .airConstraintSumcheck:
            return airConstraintSumcheckVerified
        case .zeroKnowledgeAIRConstraintSumcheck:
            return zeroKnowledgeAIRConstraintSumcheckVerified
        }
    }
}

public enum M31SumcheckProofBuilderV1 {
    public static func prove(evaluations: [UInt32], rounds: Int) throws -> M31SumcheckProofV1 {
        let result = try SumcheckOracle.m31Chunk(evaluations: evaluations, rounds: rounds)
        let statement = try M31SumcheckStatementV1(
            laneCount: evaluations.count,
            rounds: rounds,
            initialEvaluationDigest: try M31SumcheckEncodingV1.digestWords(evaluations),
            finalVectorDigest: try M31SumcheckEncodingV1.digestWords(result.finalVector)
        )
        return try M31SumcheckProofV1(
            statement: statement,
            finalVector: result.finalVector,
            coefficients: result.coefficients,
            challenges: result.challenges
        )
    }
}

public enum M31SumcheckVerifierV1 {
    public static func verificationReport(
        proof: M31SumcheckProofV1,
        statement: M31SumcheckStatementV1
    ) throws -> M31SumcheckVerificationReportV1 {
        let manifest = M31SumcheckManifestV1.current
        let proofStatementMatchesExpectedStatement = proof.statement == statement
        let proofShapeMatchesExpectedStatement = try proof.finalVector.count == statement.finalLaneCount &&
            proof.coefficients.count == M31SumcheckStatementV1.totalCoefficientWords(
                laneCount: statement.laneCount,
                rounds: statement.rounds
            ) &&
            proof.challenges.count == statement.rounds

        var initialEvaluationDigestMatchesRevealedVector = false
        var finalVectorDigestMatches = false
        var transcriptChallengesVerified = false
        var foldRelationVerified = false

        if proofShapeMatchesExpectedStatement {
            initialEvaluationDigestMatchesRevealedVector =
                statement.initialEvaluationDigest == (try M31SumcheckEncodingV1.digestWords(
                    Array(proof.coefficients[0..<statement.laneCount])
                ))
            finalVectorDigestMatches =
                statement.finalVectorDigest == (try M31SumcheckEncodingV1.digestWords(proof.finalVector))

            let replay = try replayTranscriptAndFolds(proof: proof, statement: statement)
            transcriptChallengesVerified = replay.transcriptChallengesVerified
            foldRelationVerified = replay.foldRelationVerified
        }

        return M31SumcheckVerificationReportV1(
            proofStatementMatchesExpectedStatement: proofStatementMatchesExpectedStatement,
            proofShapeMatchesExpectedStatement: proofShapeMatchesExpectedStatement,
            initialEvaluationDigestMatchesRevealedVector: initialEvaluationDigestMatchesRevealedVector,
            finalVectorDigestMatches: finalVectorDigestMatches,
            transcriptChallengesVerified: transcriptChallengesVerified,
            foldRelationVerified: foldRelationVerified,
            airConstraintReductionVerified: manifest.verifiesAIRConstraintReduction,
            fullSumcheckProtocolVerified: manifest.verifiesFullSumcheckProtocol,
            isZeroKnowledge: manifest.isZeroKnowledge,
            revealsInitialEvaluationVector: manifest.revealsInitialEvaluationVector,
            openBoundaries: manifest.openBoundaries
        )
    }

    public static func verify(
        proof: M31SumcheckProofV1,
        statement: M31SumcheckStatementV1
    ) throws -> Bool {
        try verificationReport(proof: proof, statement: statement)
            .verifies(.revealedEvaluationVectorFoldingTrace)
    }

    public static func verify(
        proof: M31SumcheckProofV1,
        statement: M31SumcheckStatementV1,
        scope: M31SumcheckClaimScopeV1
    ) throws -> Bool {
        try verificationReport(proof: proof, statement: statement).verifies(scope)
    }

    private static func replayTranscriptAndFolds(
        proof: M31SumcheckProofV1,
        statement: M31SumcheckStatementV1
    ) throws -> (transcriptChallengesVerified: Bool, foldRelationVerified: Bool) {
        let offsets = try M31SumcheckStatementV1.coefficientOffsets(
            laneCount: statement.laneCount,
            rounds: statement.rounds
        )
        var transcript = SHA3Oracle.TranscriptState()
        try transcript.absorb(SumcheckTranscriptFraming.header(
            laneCount: statement.laneCount,
            rounds: statement.rounds,
            fieldModulus: M31Field.modulus
        ))

        var transcriptChallengesVerified = true
        var foldRelationVerified = true
        var activeLaneCount = statement.laneCount
        for round in 0..<statement.rounds {
            let offset = offsets[round]
            let coefficients = Array(proof.coefficients[offset..<(offset + activeLaneCount)])
            try transcript.absorb(SumcheckTranscriptFraming.round(
                roundIndex: round,
                activeLaneCount: activeLaneCount,
                coefficientWordCount: coefficients.count
            ))
            try transcript.absorb(M31SumcheckEncodingV1.packWords(coefficients))
            try transcript.absorb(SumcheckTranscriptFraming.challenge(
                roundIndex: round,
                fieldModulus: M31Field.modulus
            ))
            let challenge = try transcript.squeezeUInt32(count: 1, modulus: M31Field.modulus)[0]
            if proof.challenges[round] != challenge {
                transcriptChallengesVerified = false
            }

            let folded = try fold(coefficients, challenge: challenge)
            if round + 1 == statement.rounds {
                if folded != proof.finalVector {
                    foldRelationVerified = false
                }
            } else {
                let nextOffset = offsets[round + 1]
                let nextCoefficients = Array(proof.coefficients[nextOffset..<(nextOffset + folded.count)])
                if folded != nextCoefficients {
                    foldRelationVerified = false
                }
            }
            activeLaneCount >>= 1
        }
        return (transcriptChallengesVerified, foldRelationVerified)
    }

    private static func fold(_ values: [UInt32], challenge: UInt32) throws -> [UInt32] {
        guard values.count > 1, values.count.isMultiple(of: 2) else {
            throw AppleZKProverError.invalidInputLayout
        }
        var folded: [UInt32] = []
        folded.reserveCapacity(values.count / 2)
        for index in 0..<(values.count / 2) {
            folded.append(M31Field.add(
                values[index * 2],
                M31Field.multiply(values[index * 2 + 1], challenge)
            ))
        }
        return folded
    }
}

public enum M31SumcheckProofCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x53, 0x43, 0x56, 0x31, 0x00])

    public static func encode(_ proof: M31SumcheckProofV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(proof.version, to: &data)
        CanonicalBinary.appendUInt32(proof.statement.version, to: &data)
        CanonicalBinary.appendUInt64(UInt64(proof.statement.laneCount), to: &data)
        CanonicalBinary.appendUInt32(try checkedUInt32(proof.statement.rounds), to: &data)
        data.append(proof.statement.initialEvaluationDigest)
        data.append(proof.statement.finalVectorDigest)
        appendWords(proof.finalVector, to: &data)
        appendWords(proof.coefficients, to: &data)
        appendWords(proof.challenges, to: &data)
        return data
    }

    public static func decode(_ data: Data) throws -> M31SumcheckProofV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let proofVersion = try reader.readUInt32()
        let statementVersion = try reader.readUInt32()
        let laneCount = try checkedInt(try reader.readUInt64())
        let rounds = Int(try reader.readUInt32())
        let initialEvaluationDigest = try reader.readBytes(count: 32)
        let finalVectorDigest = try reader.readBytes(count: 32)
        let finalVector = try readWords(from: &reader)
        let coefficients = try readWords(from: &reader)
        let challenges = try readWords(from: &reader)
        try reader.finish()
        let statement = try M31SumcheckStatementV1(
            version: statementVersion,
            laneCount: laneCount,
            rounds: rounds,
            initialEvaluationDigest: initialEvaluationDigest,
            finalVectorDigest: finalVectorDigest
        )
        return try M31SumcheckProofV1(
            version: proofVersion,
            statement: statement,
            finalVector: finalVector,
            coefficients: coefficients,
            challenges: challenges
        )
    }

    private static func appendWords(_ words: [UInt32], to data: inout Data) {
        CanonicalBinary.appendUInt64(UInt64(words.count), to: &data)
        for word in words {
            CanonicalBinary.appendUInt32(word, to: &data)
        }
    }

    private static func readWords(from reader: inout CanonicalByteReader) throws -> [UInt32] {
        let count = try checkedInt(try reader.readUInt64())
        var words: [UInt32] = []
        words.reserveCapacity(count)
        for _ in 0..<count {
            words.append(try reader.readUInt32())
        }
        try M31Field.validateCanonical(words)
        return words
    }

    private static func checkedInt(_ value: UInt64) throws -> Int {
        guard value <= UInt64(Int.max) else {
            throw AppleZKProverError.invalidInputLayout
        }
        return Int(value)
    }
}

enum M31SumcheckEncodingV1 {
    static func digestWords(_ words: [UInt32]) throws -> Data {
        try M31Field.validateCanonical(words)
        var framed = Data()
        let domain = Data("AppleZKProver.M31Sumcheck.Words.V1".utf8)
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &framed)
        framed.append(domain)
        CanonicalBinary.appendUInt32(M31SumcheckStatementV1.currentVersion, to: &framed)
        CanonicalBinary.appendUInt64(UInt64(words.count), to: &framed)
        framed.append(packWords(words))
        return SHA3Oracle.sha3_256(framed)
    }

    static func packWords(_ words: [UInt32]) -> Data {
        var data = Data()
        data.reserveCapacity(words.count * MemoryLayout<UInt32>.stride)
        for word in words {
            CanonicalBinary.appendUInt32(word, to: &data)
        }
        return data
    }
}

enum SumcheckTranscriptFraming {
    static let version: UInt32 = 1

    private static let domain = Data("AppleZKProver.SumcheckChunk".utf8)

    static func header(
        laneCount: Int,
        rounds: Int,
        fieldModulus: UInt32
    ) throws -> Data {
        var frame = baseFrame(type: 0)
        let laneCount = try checkedNonNegative(laneCount)
        let rounds = try checkedUInt32(rounds)
        appendUInt64(UInt64(laneCount), to: &frame)
        appendUInt32(rounds, to: &frame)
        appendUInt32(fieldModulus, to: &frame)
        return frame
    }

    static func round(
        roundIndex: Int,
        activeLaneCount: Int,
        coefficientWordCount: Int
    ) throws -> Data {
        var frame = baseFrame(type: 1)
        let roundIndex = try checkedUInt32(roundIndex)
        let activeLaneCount = try checkedNonNegative(activeLaneCount)
        let coefficientWordCount = try checkedNonNegative(coefficientWordCount)
        appendUInt32(roundIndex, to: &frame)
        appendUInt64(UInt64(activeLaneCount), to: &frame)
        appendUInt64(UInt64(coefficientWordCount), to: &frame)
        return frame
    }

    static func challenge(roundIndex: Int, fieldModulus: UInt32) throws -> Data {
        var frame = baseFrame(type: 2)
        let roundIndex = try checkedUInt32(roundIndex)
        appendUInt32(roundIndex, to: &frame)
        appendUInt32(fieldModulus, to: &frame)
        return frame
    }

    private static func baseFrame(type: UInt8) -> Data {
        var frame = Data()
        appendUInt32(UInt32(domain.count), to: &frame)
        frame.append(domain)
        appendUInt32(version, to: &frame)
        frame.append(type)
        return frame
    }

    private static func checkedNonNegative(_ value: Int) throws -> Int {
        guard value >= 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        return value
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }

    private static func appendUInt64(_ value: UInt64, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
        data.append(UInt8((value >> 32) & 0xff))
        data.append(UInt8((value >> 40) & 0xff))
        data.append(UInt8((value >> 48) & 0xff))
        data.append(UInt8((value >> 56) & 0xff))
    }
}
