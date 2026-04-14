import Foundation

public enum ApplicationProofOpenBoundaryV1: String, Codable, CaseIterable, Sendable {
    case airSemanticVerification = "air-semantic-verification"
    case witnessToAIRTraceProduction = "witness-to-air-trace-production"
    case sumcheckToAIRConstraintReduction = "sumcheck-to-air-constraint-reduction"
    case gkrVerification = "gkr-verification"
    case endToEndApplicationTheorem = "end-to-end-application-theorem"
    case m31SumcheckZeroKnowledge = "m31-sumcheck-zero-knowledge"
}

public enum ApplicationProofClaimScopeV1: String, Codable, CaseIterable, Sendable {
    case implementedPCSAndSumcheckSlice = "implemented-pcs-and-sumcheck-slice"
    case fullWitnessAIRGKRTheorem = "full-witness-air-gkr-theorem"
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
    public let producesWitnessAIRTrace: Bool
    public let verifiesAIRToSumcheckReduction: Bool
    public let provesEndToEndApplicationTheorem: Bool
    public let isZeroKnowledge: Bool
    public let m31SumcheckRevealsInitialEvaluationVector: Bool
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
        self.producesWitnessAIRTrace = false
        self.verifiesAIRToSumcheckReduction = false
        self.provesEndToEndApplicationTheorem = false
        self.isZeroKnowledge = false
        self.m31SumcheckRevealsInitialEvaluationVector = true
        self.openBoundaries = [
            .airSemanticVerification,
            .witnessToAIRTraceProduction,
            .sumcheckToAIRConstraintReduction,
            .gkrVerification,
            .endToEndApplicationTheorem,
            .m31SumcheckZeroKnowledge,
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

public struct ApplicationProofVerificationReportV1: Equatable, Sendable {
    public let statementDigestMatches: Bool
    public let m31SumcheckVerified: Bool
    public let circlePCSVerified: Bool
    public let airSemanticsVerified: Bool
    public let gkrVerified: Bool
    public let witnessToAIRTraceProduced: Bool
    public let airToSumcheckReductionVerified: Bool
    public let m31SumcheckIsZeroKnowledge: Bool
    public let m31SumcheckRevealsInitialEvaluationVector: Bool
    public let m31SumcheckClaimScope: M31SumcheckClaimScopeV1?
    public let m31SumcheckReport: M31SumcheckVerificationReportV1?
    public let openBoundaries: [ApplicationProofOpenBoundaryV1]

    public init(
        statementDigestMatches: Bool,
        m31SumcheckVerified: Bool,
        circlePCSVerified: Bool,
        airSemanticsVerified: Bool,
        gkrVerified: Bool,
        witnessToAIRTraceProduced: Bool,
        airToSumcheckReductionVerified: Bool,
        m31SumcheckIsZeroKnowledge: Bool,
        m31SumcheckRevealsInitialEvaluationVector: Bool,
        m31SumcheckClaimScope: M31SumcheckClaimScopeV1? = nil,
        m31SumcheckReport: M31SumcheckVerificationReportV1? = nil,
        openBoundaries: [ApplicationProofOpenBoundaryV1]
    ) {
        self.statementDigestMatches = statementDigestMatches
        self.m31SumcheckVerified = m31SumcheckVerified
        self.circlePCSVerified = circlePCSVerified
        self.airSemanticsVerified = airSemanticsVerified
        self.gkrVerified = gkrVerified
        self.witnessToAIRTraceProduced = witnessToAIRTraceProduced
        self.airToSumcheckReductionVerified = airToSumcheckReductionVerified
        self.m31SumcheckIsZeroKnowledge = m31SumcheckIsZeroKnowledge
        self.m31SumcheckRevealsInitialEvaluationVector = m31SumcheckRevealsInitialEvaluationVector
        self.m31SumcheckClaimScope = m31SumcheckClaimScope
        self.m31SumcheckReport = m31SumcheckReport
        self.openBoundaries = openBoundaries
    }

    public var implementedComponentsVerified: Bool {
        statementDigestMatches && m31SumcheckVerified && circlePCSVerified
    }

    public var fullApplicationTheoremVerified: Bool {
        implementedComponentsVerified &&
            airSemanticsVerified &&
            gkrVerified &&
            witnessToAIRTraceProduced &&
            airToSumcheckReductionVerified
    }

    public var acceptedClaimScope: ApplicationProofClaimScopeV1? {
        if fullApplicationTheoremVerified {
            return .fullWitnessAIRGKRTheorem
        }
        if implementedComponentsVerified {
            return .implementedPCSAndSumcheckSlice
        }
        return nil
    }

    public func verifies(_ scope: ApplicationProofClaimScopeV1) -> Bool {
        switch scope {
        case .implementedPCSAndSumcheckSlice:
            return implementedComponentsVerified
        case .fullWitnessAIRGKRTheorem:
            return fullApplicationTheoremVerified
        }
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
    public static func verificationReport(
        proof: ApplicationProofV1,
        statement: ApplicationProofStatementV1
    ) throws -> ApplicationProofVerificationReportV1 {
        let manifest = ApplicationProofManifestV1.current
        let sumcheckReport = try M31SumcheckVerifierV1.verificationReport(
            proof: proof.sumcheckProof,
            statement: statement.sumcheckStatement
        )
        return try ApplicationProofVerificationReportV1(
            statementDigestMatches: proof.statementDigest == statement.digest(),
            m31SumcheckVerified: sumcheckReport.verifies(.revealedEvaluationVectorFoldingTrace),
            circlePCSVerified: CirclePCSFRIContractVerifierV1.verify(
                proof: proof.pcsProof,
                statement: statement.pcsStatement
            ),
            airSemanticsVerified: manifest.verifiesAIRSemantics,
            gkrVerified: manifest.verifiesGKR,
            witnessToAIRTraceProduced: manifest.producesWitnessAIRTrace,
            airToSumcheckReductionVerified: manifest.verifiesAIRToSumcheckReduction,
            m31SumcheckIsZeroKnowledge: manifest.isZeroKnowledge,
            m31SumcheckRevealsInitialEvaluationVector: manifest.m31SumcheckRevealsInitialEvaluationVector,
            m31SumcheckClaimScope: sumcheckReport.acceptedClaimScope,
            m31SumcheckReport: sumcheckReport,
            openBoundaries: manifest.openBoundaries
        )
    }

    public static func verificationReport(
        encodedProof: Data,
        statement: ApplicationProofStatementV1
    ) throws -> ApplicationProofVerificationReportV1 {
        try verificationReport(
            proof: ApplicationProofCodecV1.decode(encodedProof),
            statement: statement
        )
    }

    public static func verify(
        proof: ApplicationProofV1,
        statement: ApplicationProofStatementV1
    ) throws -> Bool {
        try verificationReport(proof: proof, statement: statement)
            .verifies(.implementedPCSAndSumcheckSlice)
    }

    public static func verify(
        proof: ApplicationProofV1,
        statement: ApplicationProofStatementV1,
        scope: ApplicationProofClaimScopeV1
    ) throws -> Bool {
        try verificationReport(proof: proof, statement: statement).verifies(scope)
    }

    public static func verifyEndToEndApplicationTheorem(
        proof: ApplicationProofV1,
        statement: ApplicationProofStatementV1
    ) throws -> Bool {
        try verify(proof: proof, statement: statement, scope: .fullWitnessAIRGKRTheorem)
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

    public static func verify(
        encodedProof: Data,
        statement: ApplicationProofStatementV1,
        scope: ApplicationProofClaimScopeV1
    ) throws -> Bool {
        try verify(
            proof: ApplicationProofCodecV1.decode(encodedProof),
            statement: statement,
            scope: scope
        )
    }

    public static func verifyEndToEndApplicationTheorem(
        encodedProof: Data,
        statement: ApplicationProofStatementV1
    ) throws -> Bool {
        try verify(
            encodedProof: encodedProof,
            statement: statement,
            scope: .fullWitnessAIRGKRTheorem
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
