import Foundation

public enum ApplicationProofOpenBoundaryV1: String, Codable, CaseIterable, Sendable {
    case airSemanticVerification = "air-semantic-verification"
    case gkrVerification = "gkr-verification"
    case witnessToAIRTraceProduction = "witness-to-air-trace-production"
    case sumcheckToAIRConstraintReduction = "sumcheck-to-air-constraint-reduction"
}

public struct ApplicationProofManifestV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1
    public static let artifactName = "ApplicationProofV1"
    public static let current = ApplicationProofManifestV1()

    public let version: UInt32
    public let artifact: String
    public let includesFinalApplicationArtifact: Bool
    public let bindsWitnessCommitmentDigest: Bool
    public let bindsAIRDefinitionDigest: Bool
    public let verifiesM31Sumcheck: Bool
    public let verifiesCirclePCS: Bool
    public let bindsGKRClaimDigest: Bool
    public let verifiesAIRSemantics: Bool
    public let verifiesGKR: Bool
    public let openBoundaries: [ApplicationProofOpenBoundaryV1]

    public init() {
        self.version = Self.currentVersion
        self.artifact = Self.artifactName
        self.includesFinalApplicationArtifact = true
        self.bindsWitnessCommitmentDigest = true
        self.bindsAIRDefinitionDigest = true
        self.verifiesM31Sumcheck = true
        self.verifiesCirclePCS = true
        self.bindsGKRClaimDigest = true
        self.verifiesAIRSemantics = false
        self.verifiesGKR = false
        self.openBoundaries = [
            .airSemanticVerification,
            .gkrVerification,
            .witnessToAIRTraceProduction,
            .sumcheckToAIRConstraintReduction,
        ]
    }
}

public struct ApplicationProofStatementV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let applicationIdentifier: String
    public let witnessCommitmentDigest: Data
    public let airDefinitionDigest: Data
    public let gkrClaimDigest: Data
    public let sumcheckStatement: M31SumcheckStatementV1
    public let pcsStatement: CirclePCSFRIStatementV1

    public init(
        version: UInt32 = currentVersion,
        applicationIdentifier: String,
        witnessCommitmentDigest: Data,
        airDefinitionDigest: Data,
        gkrClaimDigest: Data,
        sumcheckStatement: M31SumcheckStatementV1,
        pcsStatement: CirclePCSFRIStatementV1
    ) throws {
        guard version == Self.currentVersion,
              !applicationIdentifier.isEmpty,
              witnessCommitmentDigest.count == 32,
              airDefinitionDigest.count == 32,
              gkrClaimDigest.count == 32 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.applicationIdentifier = applicationIdentifier
        self.witnessCommitmentDigest = witnessCommitmentDigest
        self.airDefinitionDigest = airDefinitionDigest
        self.gkrClaimDigest = gkrClaimDigest
        self.sumcheckStatement = sumcheckStatement
        self.pcsStatement = pcsStatement
    }

    public func digest() throws -> Data {
        var data = Data()
        data.append(Self.headerFrame())
        try CanonicalBinary.appendLengthPrefixed(Data(applicationIdentifier.utf8), to: &data)
        data.append(witnessCommitmentDigest)
        data.append(airDefinitionDigest)
        data.append(gkrClaimDigest)
        data.append(try Self.sumcheckFrame(sumcheckStatement))
        data.append(try Self.pcsFrame(pcsStatement))
        return SHA3Oracle.sha3_256(data)
    }

    private static func headerFrame() -> Data {
        var frame = baseFrame(type: 0)
        CanonicalBinary.appendUInt32(currentVersion, to: &frame)
        return frame
    }

    private static func sumcheckFrame(_ statement: M31SumcheckStatementV1) throws -> Data {
        var frame = baseFrame(type: 1)
        CanonicalBinary.appendUInt64(UInt64(statement.laneCount), to: &frame)
        CanonicalBinary.appendUInt32(try checkedUInt32(statement.rounds), to: &frame)
        Self.dataAppendDigest(statement.initialEvaluationDigest, to: &frame)
        Self.dataAppendDigest(statement.finalVectorDigest, to: &frame)
        try CanonicalBinary.appendLengthPrefixed(try statement.digest(), to: &frame)
        return frame
    }

    private static func pcsFrame(_ statement: CirclePCSFRIStatementV1) throws -> Data {
        var frame = baseFrame(type: 2)
        try CanonicalBinary.appendLengthPrefixed(
            Data(statement.parameterSet.profileID.rawValue.utf8),
            to: &frame
        )
        CanonicalBinary.appendUInt32(statement.parameterSet.securityParameters.logBlowupFactor, to: &frame)
        CanonicalBinary.appendUInt32(statement.parameterSet.securityParameters.queryCount, to: &frame)
        CanonicalBinary.appendUInt32(statement.parameterSet.securityParameters.foldingStep, to: &frame)
        CanonicalBinary.appendUInt32(statement.parameterSet.securityParameters.grindingBits, to: &frame)
        CanonicalBinary.appendUInt32(statement.parameterSet.targetSoundnessBits, to: &frame)
        try CanonicalBinary.appendLengthPrefixed(
            try CircleDomainDescriptorCodecV1.encode(statement.polynomialClaim.domain),
            to: &frame
        )
        try CanonicalBinary.appendLengthPrefixed(
            try statement.publicInputs().publicInputDigest,
            to: &frame
        )
        CanonicalBinary.appendUInt32(
            try checkedUInt32(statement.polynomialClaim.evaluationClaims.count),
            to: &frame
        )
        return frame
    }

    private static func baseFrame(type: UInt8) -> Data {
        var frame = Data()
        let domain = Data("AppleZKProver.ApplicationProof.Statement.V1".utf8)
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &frame)
        frame.append(domain)
        frame.append(type)
        return frame
    }

    private static func dataAppendDigest(_ digest: Data, to data: inout Data) {
        precondition(digest.count == 32)
        data.append(digest)
    }
}

public struct ApplicationProofV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let statementDigest: Data
    public let sumcheckProof: M31SumcheckProofV1
    public let pcsProof: CirclePCSFRIProofV1

    public init(
        version: UInt32 = currentVersion,
        statementDigest: Data,
        sumcheckProof: M31SumcheckProofV1,
        pcsProof: CirclePCSFRIProofV1
    ) throws {
        guard version == Self.currentVersion,
              statementDigest.count == 32 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.statementDigest = statementDigest
        self.sumcheckProof = sumcheckProof
        self.pcsProof = pcsProof
    }
}

public enum ApplicationProofBuilderV1 {
    public static func prove(
        statement: ApplicationProofStatementV1,
        sumcheckProof: M31SumcheckProofV1
    ) throws -> ApplicationProofV1 {
        let pcsProof = try CirclePCSFRIContractProverV1.prove(statement: statement.pcsStatement)
        return try assemble(
            statement: statement,
            sumcheckProof: sumcheckProof,
            pcsProof: pcsProof
        )
    }

    public static func assemble(
        statement: ApplicationProofStatementV1,
        sumcheckProof: M31SumcheckProofV1,
        pcsProof: CirclePCSFRIProofV1
    ) throws -> ApplicationProofV1 {
        guard try M31SumcheckVerifierV1.verify(
            proof: sumcheckProof,
            statement: statement.sumcheckStatement
        ) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "M31 sum-check proof does not match the application statement."
            )
        }
        guard try CirclePCSFRIContractVerifierV1.verify(
            proof: pcsProof,
            statement: statement.pcsStatement
        ) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Circle PCS/FRI proof does not match the application statement."
            )
        }
        return try ApplicationProofV1(
            statementDigest: statement.digest(),
            sumcheckProof: sumcheckProof,
            pcsProof: pcsProof
        )
    }
}

public enum ApplicationProofVerifierV1 {
    public static func verify(
        proof: ApplicationProofV1,
        statement: ApplicationProofStatementV1
    ) throws -> Bool {
        guard proof.statementDigest == (try statement.digest()),
              try M31SumcheckVerifierV1.verify(
                proof: proof.sumcheckProof,
                statement: statement.sumcheckStatement
              ),
              try CirclePCSFRIContractVerifierV1.verify(
                proof: proof.pcsProof,
                statement: statement.pcsStatement
              ) else {
            return false
        }
        return true
    }

    public static func verify(
        encodedProof: Data,
        statement: ApplicationProofStatementV1
    ) throws -> Bool {
        try verify(
            proof: ApplicationProofCodecV1.decode(encodedProof),
            statement: statement
        )
    }
}

public enum ApplicationProofCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x41, 0x50, 0x56, 0x31, 0x00])

    public static func encode(_ proof: ApplicationProofV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(proof.version, to: &data)
        data.append(proof.statementDigest)
        try CanonicalBinary.appendLengthPrefixed(
            try M31SumcheckProofCodecV1.encode(proof.sumcheckProof),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try CirclePCSFRIProofCodecV1.encode(proof.pcsProof),
            to: &data
        )
        return data
    }

    public static func decode(_ data: Data) throws -> ApplicationProofV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let statementDigest = try reader.readBytes(count: 32)
        let sumcheckProof = try M31SumcheckProofCodecV1.decode(try reader.readLengthPrefixed())
        let pcsProof = try CirclePCSFRIProofCodecV1.decode(try reader.readLengthPrefixed())
        try reader.finish()
        return try ApplicationProofV1(
            version: version,
            statementDigest: statementDigest,
            sumcheckProof: sumcheckProof,
            pcsProof: pcsProof
        )
    }
}
