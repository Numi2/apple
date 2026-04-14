import Foundation
import XCTest
@testable import AppleZKProver
#if canImport(Metal)
import Metal
#endif

final class CircleDomainTests: XCTestCase {
    func testM31CircleGeneratorAndCanonicalDomainDescriptor() throws {
        try CircleDomainOracle.validatePoint(.generator)
        XCTAssertEqual(CirclePointM31.generator.repeatedDouble(31), .identity)
        XCTAssertNotEqual(CirclePointM31.generator.repeatedDouble(30), .identity)

        let descriptor = try CircleDomainDescriptor.canonical(logSize: 3)
        XCTAssertEqual(descriptor.version, CircleDomainDescriptor.currentVersion)
        XCTAssertEqual(descriptor.size, 8)
        XCTAssertEqual(descriptor.halfSize, 4)
        XCTAssertEqual(descriptor.storageOrder, .circleDomainBitReversed)
        XCTAssertTrue(descriptor.isCanonical)

        let encoded = try CircleDomainDescriptorCodecV1.encode(descriptor)
        XCTAssertEqual(try CircleDomainDescriptorCodecV1.decode(encoded), descriptor)

        var trailing = encoded
        trailing.append(0)
        XCTAssertThrowsError(try CircleDomainDescriptorCodecV1.decode(trailing)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testCircleDomainIndexAndLayoutPolicyMatchesCanonicalOrder() throws {
        let descriptor = try CircleDomainDescriptor.canonical(logSize: 3, storageOrder: .circleDomainNatural)
        let scale = 1 << 27
        let expectedNaturalIndices = [
            1, 5, 9, 13, 15, 11, 7, 3,
        ].map { UInt32($0 * scale) }

        let actualNaturalIndices = try (0..<descriptor.size).map {
            try CircleDomainOracle.pointIndex(in: descriptor, naturalDomainIndex: $0).rawValue
        }
        XCTAssertEqual(actualNaturalIndices, expectedNaturalIndices)

        let circleToCoset = (0..<descriptor.size).map {
            CircleDomainOracle.circleDomainIndexToCosetIndex($0, logSize: descriptor.logSize)
        }
        XCTAssertEqual(circleToCoset, [0, 2, 4, 6, 7, 5, 3, 1])

        let cosetToCircle = (0..<descriptor.size).map {
            CircleDomainOracle.cosetIndexToCircleDomainIndex($0, logSize: descriptor.logSize)
        }
        XCTAssertEqual(cosetToCircle, [0, 7, 1, 6, 2, 5, 3, 4])

        let cosetValues = Array(0..<descriptor.size)
        XCTAssertEqual(
            try CircleDomainOracle.cosetOrderToCircleDomainOrder(cosetValues),
            [0, 2, 4, 6, 7, 5, 3, 1]
        )
        XCTAssertEqual(
            try CircleDomainOracle.bitReverseCosetToCircleDomainOrder(cosetValues),
            [0, 7, 4, 3, 2, 5, 6, 1]
        )
    }

    func testCircleFirstFoldUsesBitReversedCirclePairTwiddles() throws {
        let domain = try CircleDomainDescriptor.canonical(logSize: 3)
        let twiddles = try CircleDomainOracle.firstFoldInverseYTwiddles(for: domain)
        XCTAssertEqual(twiddles.count, 4)
        XCTAssertTrue(twiddles.allSatisfy { !QM31Field.isZero($0) })

        let pairNaturalIndices = (0..<domain.halfSize).map {
            CircleDomainOracle.bitReverseIndex($0 << 1, logSize: domain.logSize)
        }
        XCTAssertEqual(pairNaturalIndices, [0, 2, 1, 3])

        var evaluations: [QM31Element] = []
        evaluations.reserveCapacity(domain.size)
        for index in 0..<domain.size {
            let value = QM31Element(
                a: UInt32(10 + index),
                b: UInt32(20 + index),
                c: UInt32(30 + index),
                d: UInt32(40 + index)
            )
            evaluations.append(value)
        }
        let challenge = QM31Element(a: 7, b: 11, c: 13, d: 17)
        let circleFold = try CircleFRIFoldOracle.foldCircleIntoLine(
            evaluations: evaluations,
            domain: domain,
            challenge: challenge
        )
        let directFold = try QM31FRIFoldOracle.fold(
            evaluations: evaluations,
            inverseDomainPoints: twiddles,
            challenge: challenge
        )
        XCTAssertEqual(circleFold, directFold)
    }

    func testCircleMultiLayerInverseDomainScheduleUsesLinePairs() throws {
        let domain = try CircleDomainDescriptor.canonical(logSize: 5)
        let inverseLayers = try CircleFRILayerOracleV1.inverseDomainLayers(
            for: domain,
            roundCount: 4
        )
        XCTAssertEqual(inverseLayers.count, 4)
        XCTAssertEqual(inverseLayers[0], try CircleDomainOracle.firstFoldInverseYTwiddles(for: domain))

        var xCoordinates = try CircleFRILayerOracleV1.firstLineXCoordinates(for: domain)
        for roundIndex in 1..<inverseLayers.count {
            XCTAssertEqual(inverseLayers[roundIndex].count, xCoordinates.count / 2)
            var nextXCoordinates: [UInt32] = []
            nextXCoordinates.reserveCapacity(xCoordinates.count / 2)
            for pairIndex in 0..<(xCoordinates.count / 2) {
                let leftX = xCoordinates[pairIndex * 2]
                let rightX = xCoordinates[pairIndex * 2 + 1]
                XCTAssertEqual(M31Field.add(leftX, rightX), 0)
                XCTAssertNotEqual(leftX, 0)
                XCTAssertEqual(
                    inverseLayers[roundIndex][pairIndex],
                    QM31Element(a: try M31Field.inverse(leftX), b: 0, c: 0, d: 0)
                )
                nextXCoordinates.append(CircleDomainOracle.doubleX(leftX))
            }
            xCoordinates = nextXCoordinates
        }
    }

    func testCircleDomainAndTwiddleStableVectorDigests() throws {
        let domain = try CircleDomainDescriptor.canonical(logSize: 5)
        let inverseLayers = try CircleFRILayerOracleV1.inverseDomainLayers(
            for: domain,
            roundCount: 4
        )

        XCTAssertEqual(
            SHA3Oracle.sha3_256(try Self.packCircleDomainPoints(domain)).hexString,
            "c1180832e84facb97aabb6d64b41699042978bd5593a228ecf75b7ca598e854a"
        )
        XCTAssertEqual(
            SHA3Oracle.sha3_256(try Self.packM31Words(CircleCodewordOracle.circleFFTTwiddles(for: domain))).hexString,
            "714863014a573e4b80fbacb4db39e5fb953e26a61a8d8a2044076ec4795ff3e3"
        )
        XCTAssertEqual(
            SHA3Oracle.sha3_256(QM31CanonicalEncoding.pack(inverseLayers.flatMap { $0 })).hexString,
            "ba4342a7f6493e287af7ada7ceb4b162513e85f89518d07609a6810a99316db7"
        )
    }

    func testCircleProofV1BinaryRoundTripsAndRejectsNonCanonicalFields() throws {
        let proof = try Self.makeProof(queryCount: 2)
        let encoded = try CirclePCSFRIProofCodecV1.encode(proof)
        XCTAssertEqual(try CirclePCSFRIProofCodecV1.decode(encoded), proof)

        var trailing = encoded
        trailing.append(0)
        XCTAssertThrowsError(try CirclePCSFRIProofCodecV1.decode(trailing)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let originalFinalValue = QM31CanonicalEncoding.pack(proof.finalLayer[0])
        guard let range = encoded.range(of: originalFinalValue) else {
            return XCTFail("Encoded proof did not contain the expected final-layer value")
        }
        let nonCanonical = QM31CanonicalEncoding.pack(QM31Element(
            a: QM31Field.modulus,
            b: proof.finalLayer[0].constant.imaginary,
            c: proof.finalLayer[0].uCoefficient.real,
            d: proof.finalLayer[0].uCoefficient.imaginary
        ))
        var tampered = encoded
        tampered.replaceSubrange(range, with: nonCanonical)
        XCTAssertThrowsError(try CirclePCSFRIProofCodecV1.decode(tampered)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testCirclePCSArtifactManifestRecordsConservativeV1Boundary() {
        let manifest = CirclePCSFRIArtifactManifestV1.current
        XCTAssertEqual(manifest.version, CirclePCSFRIArtifactManifestV1.currentVersion)
        XCTAssertEqual(manifest.artifact, CirclePCSFRIArtifactManifestV1.artifactName)
        XCTAssertTrue(manifest.includesCirclePCS)
        XCTAssertFalse(manifest.includesWitnessAIR)
        XCTAssertFalse(manifest.includesSumcheck)
        XCTAssertFalse(manifest.includesGKR)
        XCTAssertTrue(manifest.supportsNonzeroGrinding)
        XCTAssertTrue(manifest.residentWitnessToCircleFFTBasis)
        XCTAssertEqual(manifest.codewordCommitmentSchedule, .materializedCodewordThenCommit)
        XCTAssertEqual(manifest.openBoundaries, [
            .airTraceSynthesis,
            .sumcheckGKRArtifactIntegration,
            .fusedTiledCodewordCommitmentScheduling,
        ])
        XCTAssertFalse(manifest.openBoundaries.contains(.nonzeroGrinding))
    }

    func testM31SumcheckManifestRecordsNarrowNonZKScope() {
        let manifest = M31SumcheckManifestV1.current
        XCTAssertEqual(manifest.version, M31SumcheckManifestV1.currentVersion)
        XCTAssertEqual(manifest.artifact, M31SumcheckManifestV1.artifactName)
        XCTAssertTrue(manifest.verifiesChunkTranscriptFolding)
        XCTAssertFalse(manifest.verifiesAIRConstraintReduction)
        XCTAssertFalse(manifest.verifiesFullSumcheckProtocol)
        XCTAssertFalse(manifest.isZeroKnowledge)
        XCTAssertTrue(manifest.revealsInitialEvaluationVector)
        XCTAssertEqual(manifest.acceptedClaimScope, .revealedEvaluationVectorFoldingTrace)
        XCTAssertEqual(manifest.rejectedClaimScopes, [
            .fullMultilinearSumcheck,
            .airConstraintSumcheck,
            .zeroKnowledgeAIRConstraintSumcheck,
        ])
        XCTAssertEqual(manifest.openBoundaries, [
            .airConstraintReduction,
            .fullSumcheckProtocol,
            .zeroKnowledge,
        ])
    }

    func testM31SumcheckVerificationReportClassifiesOnlyRevealedFoldingTrace() throws {
        let evaluations = (0..<16).map { index in
            UInt32(17 + index * 19)
        }
        let proof = try M31SumcheckProofBuilderV1.prove(
            evaluations: evaluations,
            rounds: 4
        )

        let report = try M31SumcheckVerifierV1.verificationReport(
            proof: proof,
            statement: proof.statement
        )
        XCTAssertTrue(report.proofStatementMatchesExpectedStatement)
        XCTAssertTrue(report.proofShapeMatchesExpectedStatement)
        XCTAssertTrue(report.initialEvaluationDigestMatchesRevealedVector)
        XCTAssertTrue(report.finalVectorDigestMatches)
        XCTAssertTrue(report.transcriptChallengesVerified)
        XCTAssertTrue(report.foldRelationVerified)
        XCTAssertTrue(report.revealedEvaluationVectorFoldingTraceVerified)
        XCTAssertEqual(report.acceptedClaimScope, .revealedEvaluationVectorFoldingTrace)
        XCTAssertTrue(report.verifies(.revealedEvaluationVectorFoldingTrace))
        XCTAssertFalse(report.verifies(.fullMultilinearSumcheck))
        XCTAssertFalse(report.verifies(.airConstraintSumcheck))
        XCTAssertFalse(report.verifies(.zeroKnowledgeAIRConstraintSumcheck))
        XCTAssertFalse(report.airConstraintReductionVerified)
        XCTAssertFalse(report.fullSumcheckProtocolVerified)
        XCTAssertFalse(report.isZeroKnowledge)
        XCTAssertTrue(report.revealsInitialEvaluationVector)
        XCTAssertEqual(report.openBoundaries, M31SumcheckManifestV1.current.openBoundaries)

        var tamperedChallenges = proof.challenges
        tamperedChallenges[0] = M31Field.add(tamperedChallenges[0], 1)
        let tamperedProof = try M31SumcheckProofV1(
            statement: proof.statement,
            finalVector: proof.finalVector,
            coefficients: proof.coefficients,
            challenges: tamperedChallenges
        )
        let tamperedReport = try M31SumcheckVerifierV1.verificationReport(
            proof: tamperedProof,
            statement: proof.statement
        )
        XCTAssertFalse(tamperedReport.transcriptChallengesVerified)
        XCTAssertTrue(tamperedReport.foldRelationVerified)
        XCTAssertFalse(tamperedReport.verifies(.revealedEvaluationVectorFoldingTrace))
        XCTAssertNil(tamperedReport.acceptedClaimScope)
    }

    func testApplicationProofV1BindsPCSAndSumcheckWithOpaqueAIRGKRDigests() throws {
        let manifest = ApplicationProofManifestV1.current
        XCTAssertEqual(manifest.version, ApplicationProofManifestV1.currentVersion)
        XCTAssertEqual(manifest.artifact, ApplicationProofManifestV1.artifactName)
        XCTAssertTrue(manifest.includesFinalApplicationArtifact)
        XCTAssertTrue(manifest.bindsWitnessCommitmentDigest)
        XCTAssertTrue(manifest.bindsAIRDefinitionDigest)
        XCTAssertTrue(manifest.verifiesM31Sumcheck)
        XCTAssertTrue(manifest.verifiesCirclePCS)
        XCTAssertTrue(manifest.bindsGKRClaimDigest)
        XCTAssertFalse(manifest.verifiesAIRSemantics)
        XCTAssertFalse(manifest.verifiesGKR)
        XCTAssertFalse(manifest.producesWitnessAIRTrace)
        XCTAssertFalse(manifest.verifiesAIRToSumcheckReduction)
        XCTAssertFalse(manifest.provesEndToEndApplicationTheorem)
        XCTAssertFalse(manifest.isZeroKnowledge)
        XCTAssertTrue(manifest.m31SumcheckRevealsInitialEvaluationVector)
        XCTAssertEqual(manifest.openBoundaries, [
            .airSemanticVerification,
            .witnessToAIRTraceProduction,
            .sumcheckToAIRConstraintReduction,
            .gkrVerification,
            .endToEndApplicationTheorem,
            .m31SumcheckZeroKnowledge,
        ])

        let domain = try CircleDomainDescriptor.canonical(logSize: 4)
        let parameterSet = try CirclePCSFRIParameterSetV1(
            profileID: .conservative128,
            logBlowupFactor: 2,
            queryCount: 2,
            grindingBits: 0,
            targetSoundnessBits: 4
        )
        let polynomial = try CircleCodewordPolynomial(
            xCoefficients: [QM31Element(a: 3, b: 5, c: 7, d: 11)],
            yCoefficients: [QM31Element(a: 13, b: 17, c: 19, d: 23)]
        )
        let claim = try CirclePCSFRIPolynomialClaimV1.make(
            domain: domain,
            polynomial: polynomial,
            storageIndices: [0, 5]
        )
        let pcsStatement = try CirclePCSFRIStatementV1(
            parameterSet: parameterSet,
            polynomialClaim: claim
        )
        let sumcheckEvaluations = (0..<16).map { index in
            UInt32(91 + index * 17)
        }
        let sumcheckProof = try M31SumcheckProofBuilderV1.prove(
            evaluations: sumcheckEvaluations,
            rounds: 3
        )
        let statement = try ApplicationProofStatementV1(
            applicationIdentifier: "apple-zk-prover.test.application-proof.v1",
            witnessCommitmentDigest: Data(repeating: 0x91, count: 32),
            airDefinitionDigest: Data(repeating: 0x92, count: 32),
            gkrClaimDigest: Data(repeating: 0x93, count: 32),
            sumcheckStatement: sumcheckProof.statement,
            pcsStatement: pcsStatement
        )
        let proof = try ApplicationProofBuilderV1.prove(
            statement: statement,
            sumcheckProof: sumcheckProof
        )
        let assembledProof = try ApplicationProofBuilderV1.assemble(
            statement: statement,
            sumcheckProof: sumcheckProof,
            pcsProof: proof.pcsProof
        )

        XCTAssertEqual(proof.statementDigest, try statement.digest())
        XCTAssertEqual(assembledProof, proof)
        XCTAssertTrue(try ApplicationProofVerifierV1.verify(proof: proof, statement: statement))
        XCTAssertTrue(try ApplicationProofVerifierV1.verify(
            proof: proof,
            statement: statement,
            scope: .implementedPCSAndSumcheckSlice
        ))
        XCTAssertFalse(try ApplicationProofVerifierV1.verify(
            proof: proof,
            statement: statement,
            scope: .fullWitnessAIRGKRTheorem
        ))
        XCTAssertFalse(try ApplicationProofVerifierV1.verifyEndToEndApplicationTheorem(
            proof: proof,
            statement: statement
        ))
        let report = try ApplicationProofVerifierV1.verificationReport(
            proof: proof,
            statement: statement
        )
        XCTAssertTrue(report.statementDigestMatches)
        XCTAssertTrue(report.m31SumcheckVerified)
        XCTAssertTrue(report.circlePCSVerified)
        XCTAssertTrue(report.implementedComponentsVerified)
        XCTAssertEqual(report.acceptedClaimScope, .implementedPCSAndSumcheckSlice)
        XCTAssertFalse(report.fullApplicationTheoremVerified)
        XCTAssertFalse(report.airSemanticsVerified)
        XCTAssertFalse(report.gkrVerified)
        XCTAssertFalse(report.witnessToAIRTraceProduced)
        XCTAssertFalse(report.airToSumcheckReductionVerified)
        XCTAssertFalse(report.m31SumcheckIsZeroKnowledge)
        XCTAssertTrue(report.m31SumcheckRevealsInitialEvaluationVector)
        XCTAssertEqual(report.m31SumcheckClaimScope, .revealedEvaluationVectorFoldingTrace)
        XCTAssertEqual(report.m31SumcheckReport?.acceptedClaimScope, .revealedEvaluationVectorFoldingTrace)
        XCTAssertTrue(report.m31SumcheckReport?.verifies(.revealedEvaluationVectorFoldingTrace) == true)
        XCTAssertTrue(report.m31SumcheckReport?.verifies(.fullMultilinearSumcheck) == false)
        XCTAssertEqual(report.openBoundaries, manifest.openBoundaries)

        let encoded = try ApplicationProofCodecV1.encode(proof)
        XCTAssertEqual(try ApplicationProofCodecV1.decode(encoded), proof)
        XCTAssertTrue(try ApplicationProofVerifierV1.verify(encodedProof: encoded, statement: statement))
        XCTAssertFalse(try ApplicationProofVerifierV1.verify(
            encodedProof: encoded,
            statement: statement,
            scope: .fullWitnessAIRGKRTheorem
        ))
        XCTAssertFalse(try ApplicationProofVerifierV1.verifyEndToEndApplicationTheorem(
            encodedProof: encoded,
            statement: statement
        ))
        XCTAssertEqual(
            try ApplicationProofVerifierV1.verificationReport(
                encodedProof: encoded,
                statement: statement
            ),
            report
        )

        var trailing = encoded
        trailing.append(0)
        XCTAssertThrowsError(try ApplicationProofCodecV1.decode(trailing)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let mismatchedGKRStatement = try ApplicationProofStatementV1(
            applicationIdentifier: statement.applicationIdentifier,
            witnessCommitmentDigest: statement.witnessCommitmentDigest,
            airDefinitionDigest: statement.airDefinitionDigest,
            gkrClaimDigest: Data(repeating: 0x94, count: 32),
            sumcheckStatement: statement.sumcheckStatement,
            pcsStatement: statement.pcsStatement
        )
        XCTAssertFalse(try ApplicationProofVerifierV1.verify(
            proof: proof,
            statement: mismatchedGKRStatement
        ))

        var tamperedChallenges = proof.sumcheckProof.challenges
        tamperedChallenges[0] = M31Field.add(tamperedChallenges[0], 1)
        let tamperedSumcheck = try M31SumcheckProofV1(
            statement: proof.sumcheckProof.statement,
            finalVector: proof.sumcheckProof.finalVector,
            coefficients: proof.sumcheckProof.coefficients,
            challenges: tamperedChallenges
        )
        let tamperedProof = try ApplicationProofV1(
            statementDigest: proof.statementDigest,
            sumcheckProof: tamperedSumcheck,
            pcsProof: proof.pcsProof
        )
        XCTAssertFalse(try ApplicationProofVerifierV1.verify(
            proof: tamperedProof,
            statement: statement
        ))
    }

    func testCircleProofV1SupportsVerifierCheckedGrindingNonce() throws {
        let domain = try CircleDomainDescriptor.canonical(logSize: 4)
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: 3,
            foldingStep: 1,
            grindingBits: 8
        )
        let publicInputs = try CirclePCSFRIPublicInputsV1(
            publicInputDigest: Data((0..<32).map { UInt8(0xe0 + $0) })
        )
        let evaluations = Self.makeStableCircleEvaluations(count: domain.size)
        let proof = try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: 2
        )
        let nonce = try XCTUnwrap(proof.grindingNonce)
        let transcript = try CircleFRITranscriptV1.derive(proof: proof)

        XCTAssertEqual(transcript.queryPairIndices.count, Int(security.queryCount))
        XCTAssertTrue(try CirclePCSFRIProofVerifierV1.verify(proof: proof, publicInputs: publicInputs))
        XCTAssertEqual(
            try CirclePCSFRIProofCodecV1.decode(try CirclePCSFRIProofCodecV1.encode(proof)),
            proof
        )

        XCTAssertThrowsError(try CircleFRITranscriptV1.derive(
            domain: proof.domain,
            securityParameters: security,
            publicInputDigest: proof.publicInputDigest,
            commitments: proof.commitments,
            finalLayer: proof.finalLayer
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        XCTAssertThrowsError(try CirclePCSFRIProofV1(
            domain: proof.domain,
            securityParameters: security,
            publicInputDigest: proof.publicInputDigest,
            commitments: proof.commitments,
            finalLayer: proof.finalLayer,
            queries: proof.queries
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        var rejectedTamperedNonce = false
        var tamperedNonce = nonce &+ 1
        for _ in 0..<512 {
            let tamperedProof = try CirclePCSFRIProofV1(
                domain: proof.domain,
                securityParameters: proof.securityParameters,
                publicInputDigest: proof.publicInputDigest,
                commitments: proof.commitments,
                finalLayer: proof.finalLayer,
                queries: proof.queries,
                grindingNonce: tamperedNonce
            )
            if !(try CirclePCSFRIProofVerifierV1.verify(proof: tamperedProof, publicInputs: publicInputs)) {
                rejectedTamperedNonce = true
                break
            }
            tamperedNonce &+= 1
        }
        XCTAssertTrue(rejectedTamperedNonce)

        let parameterSet = try CirclePCSFRIParameterSetV1(
            profileID: .conservative128,
            logBlowupFactor: 4,
            queryCount: 32,
            grindingBits: 1,
            targetSoundnessBits: 128
        )
        XCTAssertEqual(parameterSet.securityParameters.grindingBits, 1)
        XCTAssertEqual(CirclePCSFRIParameterSetV1.conservative128.securityParameters.grindingBits, 0)

        let locallyTooExpensiveSecurity = try CircleFRISecurityParametersV1(
            logBlowupFactor: security.logBlowupFactor,
            queryCount: security.queryCount,
            foldingStep: security.foldingStep,
            grindingBits: CircleFRIGrindingV1.maximumLocalSearchBits + 1
        )
        XCTAssertThrowsError(try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: locallyTooExpensiveSecurity,
            publicInputs: publicInputs,
            roundCount: 2
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testCircleFRIGrindingTargetChecksLeadingBits() {
        XCTAssertTrue(CircleFRIGrindingV1.digestMeetsTarget(Data([0x80]), grindingBits: 0))
        XCTAssertTrue(CircleFRIGrindingV1.digestMeetsTarget(Data([0x7f]), grindingBits: 1))
        XCTAssertFalse(CircleFRIGrindingV1.digestMeetsTarget(Data([0x80]), grindingBits: 1))
        XCTAssertTrue(CircleFRIGrindingV1.digestMeetsTarget(Data([0x00, 0x7f]), grindingBits: 9))
        XCTAssertFalse(CircleFRIGrindingV1.digestMeetsTarget(Data([0x00, 0x80]), grindingBits: 9))
        XCTAssertFalse(CircleFRIGrindingV1.digestMeetsTarget(Data([0x00]), grindingBits: 9))
    }

    func testCircleFirstFoldProofBuilderVerifierAndTamperRejection() throws {
        let domain = try CircleDomainDescriptor.canonical(logSize: 4)
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: 4,
            foldingStep: 1,
            grindingBits: 0
        )
        let publicInputs = try CirclePCSFRIPublicInputsV1(
            publicInputDigest: Data((0..<32).map { UInt8(0xa0 + $0) })
        )
        let evaluations = Self.makeStableCircleEvaluations(count: domain.size)
        let proof = try CircleFirstFoldPCSProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs
        )

        XCTAssertTrue(try CirclePCSFRIProofVerifierV1.verify(
            proof: proof,
            publicInputs: publicInputs
        ))
        XCTAssertEqual(try CirclePCSFRIProofCodecV1.decode(try CirclePCSFRIProofCodecV1.encode(proof)), proof)

        var badFinalLayer = proof.finalLayer
        badFinalLayer[0] = QM31Field.add(badFinalLayer[0], QM31Element(a: 1, b: 0, c: 0, d: 0))
        let tamperedFinal = try CirclePCSFRIProofV1(
            domain: proof.domain,
            securityParameters: proof.securityParameters,
            publicInputDigest: proof.publicInputDigest,
            commitments: proof.commitments,
            finalLayer: badFinalLayer,
            queries: proof.queries
        )
        XCTAssertFalse(try CirclePCSFRIProofVerifierV1.verify(
            proof: tamperedFinal,
            publicInputs: publicInputs
        ))

        var badCommitment = proof.commitments
        badCommitment[0][0] ^= 0x01
        let tamperedCommitment = try CirclePCSFRIProofV1(
            domain: proof.domain,
            securityParameters: proof.securityParameters,
            publicInputDigest: proof.publicInputDigest,
            commitments: badCommitment,
            finalLayer: proof.finalLayer,
            queries: proof.queries
        )
        XCTAssertFalse(try CirclePCSFRIProofVerifierV1.verify(
            proof: tamperedCommitment,
            publicInputs: publicInputs
        ))

        var badQueries = proof.queries
        let originalLayer = badQueries[0].layers[0]
        let badLeft = try CircleFRIValueOpeningV1(
            leafIndex: originalLayer.left.leafIndex,
            value: QM31Field.add(originalLayer.left.value, QM31Element(a: 1, b: 0, c: 0, d: 0)),
            siblingHashes: originalLayer.left.siblingHashes
        )
        badQueries[0] = try CircleFRIQueryV1(
            initialPairIndex: badQueries[0].initialPairIndex,
            layers: [
                CircleFRIQueryLayerOpeningV1(
                    layerIndex: originalLayer.layerIndex,
                    pairIndex: originalLayer.pairIndex,
                    left: badLeft,
                    right: originalLayer.right
                ),
            ]
        )
        let tamperedOpening = try CirclePCSFRIProofV1(
            domain: proof.domain,
            securityParameters: proof.securityParameters,
            publicInputDigest: proof.publicInputDigest,
            commitments: proof.commitments,
            finalLayer: proof.finalLayer,
            queries: badQueries
        )
        XCTAssertFalse(try CirclePCSFRIProofVerifierV1.verify(
            proof: tamperedOpening,
            publicInputs: publicInputs
        ))

        let wrongPublicInputs = try CirclePCSFRIPublicInputsV1(
            publicInputDigest: Data(repeating: 0x44, count: 32)
        )
        XCTAssertFalse(try CirclePCSFRIProofVerifierV1.verify(
            proof: proof,
            publicInputs: wrongPublicInputs
        ))
    }

    func testCircleFirstFoldStableVectorDigest() throws {
        let domain = try CircleDomainDescriptor.canonical(logSize: 4)
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: 3,
            foldingStep: 1,
            grindingBits: 0
        )
        let publicInputs = try CirclePCSFRIPublicInputsV1(
            publicInputDigest: Data((0..<32).map { UInt8(0x10 + $0) })
        )
        let proof = try CircleFirstFoldPCSProofBuilderV1.prove(
            evaluations: Self.makeStableCircleEvaluations(count: domain.size),
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs
        )
        let encoded = try CirclePCSFRIProofCodecV1.encode(proof)
        XCTAssertEqual(
            SHA3Oracle.sha3_256(encoded).hexString,
            "0d86cc9bd44ab2af1810ebcf3f12cf503986922565599c38c05ead43793f193d"
        )
        XCTAssertTrue(try CirclePCSFRIProofVerifierV1.verify(
            proof: try CirclePCSFRIProofCodecV1.decode(encoded),
            publicInputs: publicInputs
        ))
    }

    func testCircleMultiLayerFRIProofVerifierAndStableDigest() throws {
        let domain = try CircleDomainDescriptor.canonical(logSize: 5)
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: 5,
            foldingStep: 1,
            grindingBits: 0
        )
        let publicInputs = try CirclePCSFRIPublicInputsV1(
            publicInputDigest: Data((0..<32).map { UInt8(0x50 + $0) })
        )
        let evaluations = Self.makeStableCircleEvaluations(count: domain.size)
        let proof = try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: 3
        )

        XCTAssertEqual(proof.commitments.count, 3)
        XCTAssertEqual(proof.finalLayer.count, 4)
        let challenges = try CircleFRITranscriptV1.deriveChallenges(
            domain: domain,
            securityParameters: security,
            publicInputDigest: publicInputs.publicInputDigest,
            commitments: proof.commitments
        )
        XCTAssertEqual(
            proof.finalLayer,
            try CircleFRILayerOracleV1.fold(
                evaluations: evaluations,
                domain: domain,
                challenges: challenges
            )
        )
        XCTAssertTrue(try CirclePCSFRIProofVerifierV1.verify(
            proof: proof,
            publicInputs: publicInputs
        ))

        let encoded = try CirclePCSFRIProofCodecV1.encode(proof)
        XCTAssertEqual(
            SHA3Oracle.sha3_256(encoded).hexString,
            "4797ee419f717c52bb252ad5c01860baa4738b2a8b989afb9a5e28501d2d426b"
        )
        XCTAssertTrue(try CirclePCSFRIProofVerifierV1.verify(
            proof: try CirclePCSFRIProofCodecV1.decode(encoded),
            publicInputs: publicInputs
        ))

        var badQueries = proof.queries
        let middleLayer = badQueries[0].layers[1]
        let badRight = try CircleFRIValueOpeningV1(
            leafIndex: middleLayer.right.leafIndex,
            value: QM31Field.add(middleLayer.right.value, QM31Element(a: 1, b: 0, c: 0, d: 0)),
            siblingHashes: middleLayer.right.siblingHashes
        )
        var layers = badQueries[0].layers
        layers[1] = CircleFRIQueryLayerOpeningV1(
            layerIndex: middleLayer.layerIndex,
            pairIndex: middleLayer.pairIndex,
            left: middleLayer.left,
            right: badRight
        )
        badQueries[0] = try CircleFRIQueryV1(
            initialPairIndex: badQueries[0].initialPairIndex,
            layers: layers
        )
        let tamperedMiddleOpening = try CirclePCSFRIProofV1(
            domain: proof.domain,
            securityParameters: proof.securityParameters,
            publicInputDigest: proof.publicInputDigest,
            commitments: proof.commitments,
            finalLayer: proof.finalLayer,
            queries: badQueries
        )
        XCTAssertFalse(try CirclePCSFRIProofVerifierV1.verify(
            proof: tamperedMiddleOpening,
            publicInputs: publicInputs
        ))
    }

    func testCirclePCSPolynomialVerifierBindsDomainOpeningsAndClaimedEvaluations() throws {
        let domain = try CircleDomainDescriptor.canonical(logSize: 5)
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: 5,
            foldingStep: 1,
            grindingBits: 0
        )
        let polynomial = try Self.makeStableCircleCodewordPolynomial()
        let claimedStorageIndices = [0, 7, 18]
        let claim = try CirclePCSFRIPolynomialClaimV1.make(
            domain: domain,
            polynomial: polynomial,
            storageIndices: claimedStorageIndices
        )
        let publicInputs = try CirclePCSFRIPublicInputsV1(polynomialClaim: claim)
        let evaluations = try CircleCodewordOracle.evaluate(
            polynomial: polynomial,
            domain: domain
        )
        let proof = try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: 3,
            claimedEvaluationIndices: claimedStorageIndices
        )

        XCTAssertTrue(try CirclePCSFRIProofVerifierV1.verify(
            proof: proof,
            publicInputs: publicInputs
        ))
        XCTAssertTrue(try CirclePCSFRIPolynomialVerifierV1.verify(
            proof: proof,
            polynomialClaim: claim
        ))
        XCTAssertEqual(proof.claimedEvaluationOpenings.map(\.leafIndex), claimedStorageIndices.map(UInt64.init))
        XCTAssertEqual(try CirclePCSFRIProofCodecV1.decode(try CirclePCSFRIProofCodecV1.encode(proof)), proof)

        var badClaims = claim.evaluationClaims
        let originalClaim = badClaims[0]
        badClaims[0] = try CirclePCSFRIEvaluationClaimV1(
            storageIndex: originalClaim.storageIndex,
            point: originalClaim.point,
            value: QM31Field.add(originalClaim.value, QM31Element(a: 1, b: 0, c: 0, d: 0))
        )
        let badValueClaim = try CirclePCSFRIPolynomialClaimV1(
            domain: domain,
            polynomial: polynomial,
            evaluationClaims: badClaims
        )
        let badValuePublicInputs = try CirclePCSFRIPublicInputsV1(polynomialClaim: badValueClaim)
        let badValueProof = try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: security,
            publicInputs: badValuePublicInputs,
            roundCount: 3,
            claimedEvaluationIndices: claimedStorageIndices
        )
        XCTAssertTrue(try CirclePCSFRIProofVerifierV1.verify(
            proof: badValueProof,
            publicInputs: badValuePublicInputs
        ))
        XCTAssertFalse(try CirclePCSFRIPolynomialVerifierV1.verify(
            proof: badValueProof,
            polynomialClaim: badValueClaim
        ))

        var badOpenings = proof.claimedEvaluationOpenings
        var badSiblings = badOpenings[0].siblingHashes
        badSiblings[0][0] ^= 0x01
        badOpenings[0] = try CircleFRIValueOpeningV1(
            leafIndex: badOpenings[0].leafIndex,
            value: badOpenings[0].value,
            siblingHashes: badSiblings
        )
        let badOpeningProof = try CirclePCSFRIProofV1(
            domain: proof.domain,
            securityParameters: proof.securityParameters,
            publicInputDigest: proof.publicInputDigest,
            commitments: proof.commitments,
            finalLayer: proof.finalLayer,
            queries: proof.queries,
            claimedEvaluationOpenings: badOpenings
        )
        XCTAssertTrue(try CirclePCSFRIProofVerifierV1.verify(
            proof: badOpeningProof,
            publicInputs: publicInputs
        ))
        XCTAssertFalse(try CirclePCSFRIPolynomialVerifierV1.verify(
            proof: badOpeningProof,
            polynomialClaim: claim
        ))
    }

    func testCircleWitnessToFFTBasisOracleRecordsNarrowNonAIRScope() throws {
        let domain = try CircleDomainDescriptor.canonical(logSize: 5)
        let polynomial = try Self.makeStableCircleCodewordPolynomial()
        XCTAssertEqual(
            try CircleWitnessToFFTBasisOracleV1.transformMonomialColumns(
                xWitnessCoefficients: polynomial.xCoefficients,
                yWitnessCoefficients: polynomial.yCoefficients,
                domain: domain
            ),
            try CircleCodewordOracle.circleFFTCoefficients(
                polynomial: polynomial,
                domain: domain
            )
        )

        let transform = try CircleWitnessToFFTBasisOracleV1.lineBasisTransformScalars(domain: domain)
        XCTAssertEqual(transform.count, domain.halfSize * domain.halfSize)
        let zero = QM31Element(a: 0, b: 0, c: 0, d: 0)
        let one = QM31Element(a: 1, b: 0, c: 0, d: 0)
        for column in 0..<domain.halfSize {
            var coefficients = Array(repeating: zero, count: column + 1)
            coefficients[column] = one
            let basisPolynomial = try CircleCodewordPolynomial(
                xCoefficients: coefficients,
                yCoefficients: []
            )
            let expectedBasis = try CircleCodewordOracle.circleFFTCoefficients(
                polynomial: basisPolynomial,
                domain: domain
            )
            for row in 0..<domain.halfSize {
                XCTAssertEqual(
                    transform[row * domain.halfSize + column],
                    expectedBasis[2 * row].constant.real
                )
                XCTAssertEqual(expectedBasis[2 * row].constant.imaginary, 0)
                XCTAssertEqual(expectedBasis[2 * row].uCoefficient.real, 0)
                XCTAssertEqual(expectedBasis[2 * row].uCoefficient.imaginary, 0)
            }
        }
        let commandPlan = try CircleWitnessToFFTBasisCommandPlanV1(
            input: .residentMonomialCoefficientColumns,
            output: .residentCircleFFTBasisBuffer,
            coefficientCapacity: domain.halfSize,
            outputElementCount: domain.size,
            transformMatrixScalarCount: transform.count
        )
        XCTAssertEqual(commandPlan.transformStrategy, .denseMatrix)
        XCTAssertEqual(commandPlan.residentTransformTileScalarCapacity, transform.count)
        XCTAssertEqual(commandPlan.transformTileRowCapacity, domain.halfSize)
        XCTAssertTrue(commandPlan.validatesPrivateWitnessCanonicality)
        XCTAssertFalse(commandPlan.verifiesAIRSemantics)
        XCTAssertFalse(commandPlan.producesAIRTrace)
        let tiledCommandPlan = try CircleWitnessToFFTBasisCommandPlanV1(
            input: .residentMonomialCoefficientColumns,
            output: .residentCircleFFTBasisBuffer,
            coefficientCapacity: domain.halfSize,
            outputElementCount: domain.size,
            transformMatrixScalarCount: transform.count,
            transformStrategy: .tiledDenseMatrix,
            residentTransformTileScalarCapacity: domain.halfSize * 2,
            transformTileRowCapacity: 2
        )
        XCTAssertEqual(tiledCommandPlan.transformStrategy, .tiledDenseMatrix)
        XCTAssertTrue(tiledCommandPlan.validatesPrivateWitnessCanonicality)
        let tile = try CircleWitnessToFFTBasisOracleV1.lineBasisTransformScalars(
            coefficientCapacity: domain.halfSize,
            rowOffset: 2,
            rowCount: 3
        )
        XCTAssertEqual(tile.count, domain.halfSize * 3)
        for localRow in 0..<3 {
            let fullStart = (2 + localRow) * domain.halfSize
            let tileStart = localRow * domain.halfSize
            XCTAssertEqual(
                Array(tile[tileStart..<(tileStart + domain.halfSize)]),
                Array(transform[fullStart..<(fullStart + domain.halfSize)])
            )
        }
        XCTAssertThrowsError(
            try CircleWitnessToFFTBasisCommandPlanV1(
                input: .residentMonomialCoefficientColumns,
                output: .residentCircleFFTBasisBuffer,
                coefficientCapacity: domain.halfSize,
                outputElementCount: domain.size,
                transformMatrixScalarCount: transform.count,
                verifiesAIRSemantics: true
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try CircleWitnessToFFTBasisCommandPlanV1(
                input: .residentMonomialCoefficientColumns,
                output: .residentCircleFFTBasisBuffer,
                coefficientCapacity: domain.halfSize,
                outputElementCount: domain.size,
                transformMatrixScalarCount: transform.count,
                validatesPrivateWitnessCanonicality: false
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testCirclePCSContractVerifierEnforcesProductionProfileAndTerminalLayer() throws {
        let domain = try CircleDomainDescriptor.canonical(logSize: 6)
        let parameterSet = CirclePCSFRIParameterSetV1.conservative128
        let polynomial = try CircleCodewordPolynomial(
            xCoefficients: [
                QM31Element(a: 3, b: 5, c: 7, d: 11),
                QM31Element(a: 13, b: 17, c: 19, d: 23),
            ],
            yCoefficients: [
                QM31Element(a: 29, b: 31, c: 37, d: 41),
                QM31Element(a: 43, b: 47, c: 53, d: 59),
            ]
        )
        let claim = try CirclePCSFRIPolynomialClaimV1.make(
            domain: domain,
            polynomial: polynomial,
            storageIndices: [0, 17, 42]
        )
        let statement = try CirclePCSFRIStatementV1(
            parameterSet: parameterSet,
            polynomialClaim: claim
        )
        let proof = try CirclePCSFRIContractProverV1.prove(statement: statement)

        XCTAssertEqual(proof.securityParameters, parameterSet.securityParameters)
        XCTAssertEqual(proof.commitments.count, try statement.roundCount())
        XCTAssertEqual(proof.finalLayer.count, 1 << Int(parameterSet.securityParameters.logBlowupFactor))
        XCTAssertTrue(CirclePCSFRIParameterSetV1.finalLayerIsTerminalConstant(proof.finalLayer))
        XCTAssertTrue(try CirclePCSFRIContractVerifierV1.verify(proof: proof, statement: statement))
        XCTAssertTrue(try CirclePCSFRIContractVerifierV1.verify(
            encodedProof: try CirclePCSFRIProofCodecV1.encode(proof),
            statement: statement
        ))

        let artifactOnlySecurity = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: parameterSet.securityParameters.queryCount,
            foldingStep: 1,
            grindingBits: 0
        )
        let artifactOnlyProof = try CircleFRIProofBuilderV1.prove(
            evaluations: try CircleCodewordOracle.evaluate(polynomial: polynomial, domain: domain),
            domain: domain,
            securityParameters: artifactOnlySecurity,
            publicInputs: statement.publicInputs(),
            roundCount: 3,
            claimedEvaluationIndices: try statement.claimedEvaluationIndices()
        )
        XCTAssertTrue(try CirclePCSFRIPolynomialVerifierV1.verify(
            proof: artifactOnlyProof,
            polynomialClaim: claim
        ))
        XCTAssertFalse(try CirclePCSFRIContractVerifierV1.verify(
            proof: artifactOnlyProof,
            statement: statement
        ))

        var nonTerminalFinalLayer = proof.finalLayer
        nonTerminalFinalLayer[1] = QM31Field.add(
            nonTerminalFinalLayer[1],
            QM31Element(a: 1, b: 0, c: 0, d: 0)
        )
        let nonTerminalProof = try CirclePCSFRIProofV1(
            domain: proof.domain,
            securityParameters: proof.securityParameters,
            publicInputDigest: proof.publicInputDigest,
            commitments: proof.commitments,
            finalLayer: nonTerminalFinalLayer,
            queries: proof.queries,
            claimedEvaluationOpenings: proof.claimedEvaluationOpenings
        )
        XCTAssertFalse(try CirclePCSFRIContractVerifierV1.verify(
            proof: nonTerminalProof,
            statement: statement
        ))

        let overBudgetPolynomial = try CircleCodewordPolynomial(
            xCoefficients: Self.makeDeterministicQM31Coefficients(count: 4, salt: 0x120),
            yCoefficients: [QM31Element(a: 1, b: 2, c: 3, d: 4)]
        )
        let overBudgetClaim = try CirclePCSFRIPolynomialClaimV1.make(
            domain: domain,
            polynomial: overBudgetPolynomial,
            storageIndices: [0]
        )
        XCTAssertThrowsError(try CirclePCSFRIStatementV1(
            parameterSet: parameterSet,
            polynomialClaim: overBudgetClaim
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testCirclePCSProofCorpusV1PinsCanonicalBytesDigestsAndRejections() throws {
        let corpus = try Self.loadCirclePCSFRIProofCorpus()
        XCTAssertEqual(corpus.schemaVersion, 1)
        XCTAssertEqual(corpus.artifact, "CirclePCSFRIProofV1")

        let parameterSet = CirclePCSFRIParameterSetV1.conservative128
        XCTAssertEqual(corpus.profile.id, parameterSet.profileID.rawValue)
        XCTAssertEqual(corpus.profile.logBlowupFactor, parameterSet.securityParameters.logBlowupFactor)
        XCTAssertEqual(corpus.profile.queryCount, parameterSet.securityParameters.queryCount)
        XCTAssertEqual(corpus.profile.foldingStep, parameterSet.securityParameters.foldingStep)
        XCTAssertEqual(corpus.profile.grindingBits, parameterSet.securityParameters.grindingBits)
        XCTAssertEqual(corpus.profile.targetSoundnessBits, parameterSet.targetSoundnessBits)
        XCTAssertEqual(corpus.profile.nominalSecurityBits, parameterSet.securityParameters.nominalSecurityBits)

        let statement = try Self.makeCorpusStatement(
            corpus.validCase,
            parameterSet: parameterSet
        )
        XCTAssertEqual(try statement.roundCount(), corpus.validCase.roundCount)
        XCTAssertEqual(
            try statement.claimedEvaluationIndices(),
            corpus.validCase.claimedStorageIndices
        )
        XCTAssertEqual(
            try statement.publicInputs().publicInputDigest.hexString,
            corpus.validCase.publicInputDigestHex
        )

        let validProof = try Self.assertEncodedCorpusProof(
            id: corpus.validCase.id,
            expectedVerifierAccepted: corpus.validCase.expectedVerifierAccepted,
            proofByteCount: corpus.validCase.proofByteCount,
            proofDigestHex: corpus.validCase.proofDigestHex,
            proofHex: corpus.validCase.proofHex,
            statement: statement
        )
        XCTAssertTrue(corpus.validCase.expectedVerifierAccepted)
        XCTAssertEqual(validProof.commitments.count, try statement.roundCount())
        XCTAssertTrue(CirclePCSFRIParameterSetV1.finalLayerIsTerminalConstant(validProof.finalLayer))

        XCTAssertEqual(corpus.tamperVectors.count, 3)
        for vector in corpus.tamperVectors {
            let proof = try Self.assertEncodedCorpusProof(
                id: vector.id,
                expectedVerifierAccepted: vector.expectedVerifierAccepted,
                proofByteCount: vector.proofByteCount,
                proofDigestHex: vector.proofDigestHex,
                proofHex: vector.proofHex,
                statement: statement
            )
            XCTAssertFalse(vector.expectedVerifierAccepted, vector.id)
            if vector.id == "developer-parameter-proof-rejected-by-contract" {
                XCTAssertTrue(try CirclePCSFRIPolynomialVerifierV1.verify(
                    proof: proof,
                    polynomialClaim: statement.polynomialClaim
                ))
            }
        }
    }

    func testApplicationProofCorpusV1PinsCanonicalBytesDigestsAndRejections() throws {
        let corpus = try Self.loadApplicationProofCorpus()
        XCTAssertEqual(corpus.schemaVersion, 1)
        XCTAssertEqual(corpus.artifact, ApplicationProofManifestV1.artifactName)

        let (statement, sumcheckProof) = try Self.makeApplicationCorpusStatement(corpus.statement)
        XCTAssertEqual(try statement.digest().hexString, corpus.statement.statementDigestHex)
        let validProof = try Self.assertEncodedApplicationCorpusProof(
            corpus.validCase,
            statement: statement
        )
        XCTAssertTrue(corpus.validCase.expectedVerifierAccepted)
        XCTAssertEqual(validProof.statementDigest.hexString, corpus.statement.statementDigestHex)
        XCTAssertEqual(validProof.sumcheckProof.statement, sumcheckProof.statement)

        let assembled = try ApplicationProofBuilderV1.assemble(
            statement: statement,
            sumcheckProof: sumcheckProof,
            pcsProof: validProof.pcsProof
        )
        XCTAssertEqual(try ApplicationProofCodecV1.encode(assembled), try Self.decodeHex(corpus.validCase.proofHex))

        XCTAssertEqual(corpus.tamperVectors.count, 3)
        for vector in corpus.tamperVectors {
            XCTAssertFalse(vector.expectedVerifierAccepted, vector.id)
            _ = try Self.assertEncodedApplicationCorpusProof(
                vector,
                statement: statement
            )
        }
    }

    func testCircleCodewordFFTOracleMatchesDirectEvaluatorAcrossEdgeDegrees() throws {
        for logSize in UInt32(1)...6 {
            let domain = try CircleDomainDescriptor.canonical(logSize: logSize)
            let halfSize = domain.halfSize
            let cases = [
                try CircleCodewordPolynomial(
                    xCoefficients: [QM31Element(a: 7, b: 11, c: 13, d: 17)]
                ),
                try CircleCodewordPolynomial(
                    xCoefficients: [],
                    yCoefficients: [QM31Element(a: 19, b: 23, c: 29, d: 31)]
                ),
                try CircleCodewordPolynomial(
                    xCoefficients: Self.makeDeterministicQM31Coefficients(count: halfSize, salt: 0x40),
                    yCoefficients: Self.makeDeterministicQM31Coefficients(count: halfSize, salt: 0x80)
                ),
            ]

            XCTAssertEqual(try CircleCodewordOracle.circleFFTTwiddles(for: domain).count, domain.size - 1)
            for polynomial in cases {
                XCTAssertEqual(
                    try CircleCodewordOracle.evaluateWithCircleFFT(
                        polynomial: polynomial,
                        domain: domain
                    ),
                    try CircleCodewordOracle.evaluate(
                        polynomial: polynomial,
                        domain: domain
                    ),
                    "logSize=\(logSize)"
                )
                XCTAssertEqual(
                    try CircleCodewordOracle.circleFFTCoefficients(
                        polynomial: polynomial,
                        domain: domain
                    ).count,
                    domain.size
                )
            }
        }
    }

    func testCircleTranscriptBindsDomainSecurityCommitmentsPublicInputsAndFinalLayer() throws {
        let proof = try Self.makeProof(queryCount: 2)
        let base = try CircleFRITranscriptV1.derive(proof: proof)

        var commitment = proof.commitments[0]
        commitment[0] ^= 0x80
        var commitments = proof.commitments
        commitments[0] = commitment
        XCTAssertNotEqual(
            try CircleFRITranscriptV1.derive(
                domain: proof.domain,
                securityParameters: proof.securityParameters,
                publicInputDigest: proof.publicInputDigest,
                commitments: commitments,
                finalLayer: proof.finalLayer
            ),
            base
        )

        var publicInputDigest = proof.publicInputDigest
        publicInputDigest[31] ^= 0x01
        XCTAssertNotEqual(
            try CircleFRITranscriptV1.derive(
                domain: proof.domain,
                securityParameters: proof.securityParameters,
                publicInputDigest: publicInputDigest,
                commitments: proof.commitments,
                finalLayer: proof.finalLayer
            ),
            base
        )

        var finalLayer = proof.finalLayer
        finalLayer[0] = QM31Field.add(finalLayer[0], QM31Element(a: 1, b: 0, c: 0, d: 0))
        XCTAssertNotEqual(
            try CircleFRITranscriptV1.derive(
                domain: proof.domain,
                securityParameters: proof.securityParameters,
                publicInputDigest: proof.publicInputDigest,
                commitments: proof.commitments,
                finalLayer: finalLayer
            ),
            base
        )

        let largerDomain = try CircleDomainDescriptor.canonical(logSize: 4)
        XCTAssertNotEqual(
            try CircleFRITranscriptV1.derive(
                domain: largerDomain,
                securityParameters: proof.securityParameters,
                publicInputDigest: proof.publicInputDigest,
                commitments: proof.commitments,
                finalLayer: proof.finalLayer
            ),
            base
        )

        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: proof.securityParameters.logBlowupFactor,
            queryCount: proof.securityParameters.queryCount + 1,
            foldingStep: proof.securityParameters.foldingStep,
            grindingBits: proof.securityParameters.grindingBits
        )
        XCTAssertNotEqual(
            try CircleFRITranscriptV1.derive(
                domain: proof.domain,
                securityParameters: security,
                publicInputDigest: proof.publicInputDigest,
                commitments: proof.commitments,
                finalLayer: proof.finalLayer
            ),
            base
        )
    }

#if canImport(Metal)
    func testCircleDomainMaterializationMatchesCPUCanonicalVectors() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        for (logSize, roundCount) in [(UInt32(1), 1), (UInt32(3), 2), (UInt32(5), 4), (UInt32(6), 5)] {
            let domain = try CircleDomainDescriptor.canonical(logSize: logSize)
            let materialization = try CircleDomainMaterializationPlan(
                context: context,
                domain: domain,
                materializeDomainPoints: true,
                materializeCodewordTwiddles: true,
                inverseDomainRoundCount: roundCount
            )

            XCTAssertEqual(materialization.outputCount, domain.size >> roundCount)
            XCTAssertEqual(materialization.totalInverseDomainCount, domain.size - materialization.outputCount)
            XCTAssertEqual(try materialization.readDomainPoints(), try Self.circleDomainPoints(domain))
            XCTAssertEqual(
                try materialization.readCodewordTwiddles(),
                try CircleCodewordOracle.circleFFTTwiddles(for: domain)
            )
            XCTAssertEqual(
                try materialization.readInverseDomainLayers(),
                try CircleFRILayerOracleV1.inverseDomainLayers(for: domain, roundCount: roundCount)
            )
        }
    }

    func testCircleFRIFoldPlanMatchesCPUOracleAndResidentHotPath() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        let domain = try CircleDomainDescriptor.canonical(logSize: 5)
        var evaluations: [QM31Element] = []
        evaluations.reserveCapacity(domain.size)
        for index in 0..<domain.size {
            evaluations.append(QM31Element(
                a: UInt32(3 + index * 11),
                b: UInt32(5 + index * 13),
                c: UInt32(7 + index * 17),
                d: UInt32(9 + index * 19)
            ))
        }
        let challenge = QM31Element(a: 23, b: 29, c: 31, d: 37)
        let expected = try CircleFRIFoldOracle.foldCircleIntoLine(
            evaluations: evaluations,
            domain: domain,
            challenge: challenge
        )

        let plan = try CircleFRIFoldPlan(context: context, domain: domain)
        XCTAssertEqual(plan.inputCount, domain.size)
        XCTAssertEqual(plan.outputCount, domain.halfSize)
        XCTAssertEqual(try plan.readInverseYTwiddles(), try CircleDomainOracle.firstFoldInverseYTwiddles(for: domain))

        let measured = try plan.executeVerified(evaluations: evaluations, challenge: challenge)
        XCTAssertEqual(measured.values, expected)

        try plan.clearReusableBuffers()
        let reversedEvaluations = Array(evaluations.reversed())
        let reused = try plan.executeVerified(evaluations: reversedEvaluations, challenge: challenge)
        XCTAssertEqual(
            reused.values,
            try CircleFRIFoldOracle.foldCircleIntoLine(
                evaluations: reversedEvaluations,
                domain: domain,
                challenge: challenge
            )
        )

        let evaluationBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: QM31CanonicalEncoding.pack(evaluations),
            declaredLength: domain.size * CircleFRIFoldPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIFoldEvaluations"
        )
        let outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: domain.halfSize * CircleFRIFoldPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIFoldOutput"
        )
        _ = try plan.executeResident(
            evaluationsBuffer: evaluationBuffer,
            outputBuffer: outputBuffer,
            challenge: challenge
        )
        XCTAssertEqual(try Self.readQM31Buffer(outputBuffer, count: domain.halfSize), expected)
    }

    func testCircleFRIFoldChainPlanMatchesCPUOracleAndResidentHotPath() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        let domain = try CircleDomainDescriptor.canonical(logSize: 6)
        let roundCount = 4
        var evaluations: [QM31Element] = []
        evaluations.reserveCapacity(domain.size)
        for index in 0..<domain.size {
            evaluations.append(QM31Element(
                a: UInt32(17 + index * 3),
                b: UInt32(19 + index * 5),
                c: UInt32(23 + index * 7),
                d: UInt32(29 + index * 11)
            ))
        }
        let challenges = [
            QM31Element(a: 31, b: 37, c: 41, d: 43),
            QM31Element(a: 47, b: 53, c: 59, d: 61),
            QM31Element(a: 67, b: 71, c: 73, d: 79),
            QM31Element(a: 83, b: 89, c: 97, d: 101),
        ]
        let expected = try CircleFRILayerOracleV1.fold(
            evaluations: evaluations,
            domain: domain,
            challenges: challenges
        )

        let plan = try CircleFRIFoldChainPlan(
            context: context,
            domain: domain,
            roundCount: roundCount
        )
        XCTAssertEqual(plan.inputCount, domain.size)
        XCTAssertEqual(plan.roundCount, roundCount)
        XCTAssertEqual(plan.outputCount, domain.size >> roundCount)
        XCTAssertEqual(plan.totalInverseDomainCount, domain.size - plan.outputCount)
        XCTAssertEqual(
            try plan.readInverseDomainLayers(),
            try CircleFRILayerOracleV1.inverseDomainLayers(for: domain, roundCount: roundCount)
        )

        let measured = try plan.executeVerified(evaluations: evaluations, challenges: challenges)
        XCTAssertEqual(measured.values, expected)

        try plan.clearReusableBuffers()
        let alternateChallenges = [
            QM31Element(a: 103, b: 107, c: 109, d: 113),
            QM31Element(a: 127, b: 131, c: 137, d: 139),
            QM31Element(a: 149, b: 151, c: 157, d: 163),
            QM31Element(a: 167, b: 173, c: 179, d: 181),
        ]
        let reused = try plan.executeVerified(
            evaluations: Array(evaluations.reversed()),
            challenges: alternateChallenges
        )
        XCTAssertEqual(
            reused.values,
            try CircleFRILayerOracleV1.fold(
                evaluations: Array(evaluations.reversed()),
                domain: domain,
                challenges: alternateChallenges
            )
        )

        let evaluationBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: QM31CanonicalEncoding.pack(evaluations),
            declaredLength: domain.size * CircleFRIFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIFoldChainEvaluations"
        )
        let outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: expected.count * CircleFRIFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIFoldChainOutput"
        )
        _ = try plan.executeResident(
            evaluationsBuffer: evaluationBuffer,
            outputBuffer: outputBuffer,
            challenges: challenges
        )
        XCTAssertEqual(try Self.readQM31Buffer(outputBuffer, count: expected.count), expected)
    }

    func testCircleFRIMerkleTranscriptFoldChainPlanMatchesProofBuilderAndResidentHotPath() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        let domain = try CircleDomainDescriptor.canonical(logSize: 5)
        let roundCount = 3
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: 3,
            foldingStep: 1,
            grindingBits: 0
        )
        let publicInputs = try CirclePCSFRIPublicInputsV1(
            publicInputDigest: Data((0..<32).map { UInt8(0x70 + $0) })
        )
        let evaluations = Self.makeStableCircleEvaluations(count: domain.size)
        let proof = try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: roundCount
        )
        let expectedChallenges = try CircleFRITranscriptV1.deriveChallenges(
            domain: domain,
            securityParameters: security,
            publicInputDigest: publicInputs.publicInputDigest,
            commitments: proof.commitments
        )

        let plan = try CircleFRIMerkleTranscriptFoldChainPlan(
            context: context,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: roundCount
        )
        XCTAssertEqual(plan.inputCount, domain.size)
        XCTAssertEqual(plan.roundCount, roundCount)
        XCTAssertEqual(plan.outputCount, proof.finalLayer.count)
        XCTAssertEqual(plan.totalInverseDomainCount, domain.size - proof.finalLayer.count)
        XCTAssertEqual(
            try plan.readInverseDomainLayers(),
            try CircleFRILayerOracleV1.inverseDomainLayers(for: domain, roundCount: roundCount)
        )

        let measured = try plan.executeVerified(evaluations: evaluations)
        XCTAssertEqual(measured.values, proof.finalLayer)
        XCTAssertEqual(measured.commitments, proof.commitments)
        XCTAssertEqual(measured.challenges, expectedChallenges)
        XCTAssertTrue(try CirclePCSFRIProofVerifierV1.verify(proof: proof, publicInputs: publicInputs))

        try plan.clearReusableBuffers()
        let reused = try plan.executeVerified(evaluations: evaluations)
        XCTAssertEqual(reused.values, proof.finalLayer)
        XCTAssertEqual(reused.commitments, proof.commitments)
        XCTAssertEqual(reused.challenges, expectedChallenges)

        let evaluationBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: QM31CanonicalEncoding.pack(evaluations),
            declaredLength: domain.size * CircleFRIMerkleTranscriptFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIMerkleTranscriptEvaluations"
        )
        let commitmentBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: roundCount * CircleFRIMerkleTranscriptFoldChainPlan.commitmentByteCount,
            label: "CircleDomainTests.CircleFRIMerkleTranscriptCommitments"
        )
        let outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: proof.finalLayer.count * CircleFRIMerkleTranscriptFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIMerkleTranscriptOutput"
        )
        _ = try plan.executeResident(
            evaluationsBuffer: evaluationBuffer,
            commitmentOutputBuffer: commitmentBuffer,
            outputBuffer: outputBuffer
        )
        XCTAssertEqual(try Self.readQM31Buffer(outputBuffer, count: proof.finalLayer.count), proof.finalLayer)
        XCTAssertEqual(Self.readCommitmentBuffer(commitmentBuffer, count: roundCount), proof.commitments)
    }

    func testCircleFRIResidentQueryExtractorBuildsVerifierCompatibleQueries() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        let domain = try CircleDomainDescriptor.canonical(logSize: 5)
        let roundCount = 3
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: 3,
            foldingStep: 1,
            grindingBits: 0
        )
        let publicInputs = try CirclePCSFRIPublicInputsV1(
            publicInputDigest: Data((0..<32).map { UInt8(0x91 + $0) })
        )
        let evaluations = Self.makeStableCircleEvaluations(count: domain.size)
        let cpuProof = try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: roundCount
        )

        let plan = try CircleFRIMerkleTranscriptFoldChainPlan(
            context: context,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: roundCount
        )
        let evaluationBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: QM31CanonicalEncoding.pack(evaluations),
            declaredLength: domain.size * CircleFRIMerkleTranscriptFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIResidentQueryEvaluations"
        )
        let committedLayerBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: plan.totalCommittedLayerCount * CircleFRIMerkleTranscriptFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIResidentCommittedLayers"
        )
        let commitmentBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: roundCount * CircleFRIMerkleTranscriptFoldChainPlan.commitmentByteCount,
            label: "CircleDomainTests.CircleFRIResidentQueryCommitments"
        )
        let outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: cpuProof.finalLayer.count * CircleFRIMerkleTranscriptFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIResidentQueryFinalLayer"
        )

        _ = try plan.executeMaterializedResident(
            evaluationsBuffer: evaluationBuffer,
            committedLayerBuffer: committedLayerBuffer,
            commitmentOutputBuffer: commitmentBuffer,
            outputBuffer: outputBuffer
        )
        let commitments = Self.readCommitmentBuffer(commitmentBuffer, count: roundCount)
        let finalLayer = try Self.readQM31Buffer(outputBuffer, count: cpuProof.finalLayer.count)
        XCTAssertEqual(commitments, cpuProof.commitments)
        XCTAssertEqual(finalLayer, cpuProof.finalLayer)

        let transcript = try CircleFRITranscriptV1.derive(
            domain: domain,
            securityParameters: security,
            publicInputDigest: publicInputs.publicInputDigest,
            commitments: commitments,
            finalLayer: finalLayer
        )
        let extractor = try CircleFRIResidentQueryExtractorV1(
            context: context,
            domain: domain,
            roundCount: roundCount
        )
        let extracted = try extractor.extractQueries(
            committedLayerBuffer: committedLayerBuffer,
            commitments: commitments,
            queryPairIndices: transcript.queryPairIndices
        )
        XCTAssertEqual(extracted.openingCount, Int(security.queryCount) * roundCount * 2)
        XCTAssertEqual(extracted.queries, cpuProof.queries)

        let residentProof = try CirclePCSFRIProofV1(
            domain: domain,
            securityParameters: security,
            publicInputDigest: publicInputs.publicInputDigest,
            commitments: commitments,
            finalLayer: finalLayer,
            queries: extracted.queries
        )
        XCTAssertTrue(try CirclePCSFRIProofVerifierV1.verify(
            proof: residentProof,
            publicInputs: publicInputs
        ))
    }

    func testCirclePCSFRIResidentProverEmitsVerifierCompatibleProof() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        let domain = try CircleDomainDescriptor.canonical(logSize: 5)
        let roundCount = 3
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: 3,
            foldingStep: 1,
            grindingBits: 0
        )
        let publicInputs = try CirclePCSFRIPublicInputsV1(
            publicInputDigest: Data((0..<32).map { UInt8(0xc0 + $0) })
        )
        let evaluations = Self.makeStableCircleEvaluations(count: domain.size)
        let expectedProof = try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: roundCount
        )

        let prover = try CirclePCSFRIResidentProverV1(
            context: context,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: roundCount
        )
        let offset = 64
        let evaluationBytes = QM31CanonicalEncoding.pack(evaluations)
        let evaluationBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: offset + evaluationBytes.count,
            label: "CircleDomainTests.CirclePCSFRIResidentProverEvaluations"
        )
        try MetalBufferFactory.copy(
            evaluationBytes,
            into: evaluationBuffer,
            destinationOffset: offset,
            byteCount: evaluationBytes.count
        )

        let result = try prover.proveVerified(
            evaluationsBuffer: evaluationBuffer,
            evaluationsOffset: offset
        )
        XCTAssertEqual(result.proof, expectedProof)
        XCTAssertEqual(try CirclePCSFRIProofCodecV1.decode(result.encodedProof), expectedProof)
        XCTAssertEqual(result.proofByteCount, result.encodedProof.count)
        XCTAssertTrue(try CirclePCSFRIProofVerifierV1.verify(
            proof: result.proof,
            publicInputs: publicInputs
        ))

        try prover.clearReusableBuffers()
        let arrayResult = try prover.proveVerified(evaluations: evaluations)
        XCTAssertEqual(arrayResult.proof, expectedProof)
    }

    func testCircleCodewordPlanMatchesCPUOracleAndFeedsResidentProver() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        let domain = try CircleDomainDescriptor.canonical(logSize: 5)
        let roundCount = 3
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: 3,
            foldingStep: 1,
            grindingBits: 0
        )
        let publicInputs = try CirclePCSFRIPublicInputsV1(
            publicInputDigest: Data((0..<32).map { UInt8(0xd0 + $0) })
        )
        let polynomial = try Self.makeStableCircleCodewordPolynomial()
        let expectedCodeword = try CircleCodewordOracle.evaluate(
            polynomial: polynomial,
            domain: domain
        )
        let expectedProof = try CircleFRIProofBuilderV1.prove(
            evaluations: expectedCodeword,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: roundCount
        )

        let codewordPlan = try CircleCodewordPlan(context: context, domain: domain)
        XCTAssertEqual(
            try codewordPlan.readCodewordTwiddles(),
            try CircleCodewordOracle.circleFFTTwiddles(for: domain)
        )
        let measuredCodeword = try codewordPlan.execute(polynomial: polynomial)
        XCTAssertEqual(
            Array(measuredCodeword.evaluations.prefix(8)),
            Array(expectedCodeword.prefix(8))
        )
        let measured = try codewordPlan.executeVerified(polynomial: polynomial)
        XCTAssertEqual(measured.evaluations, expectedCodeword)

        let xOnlyPolynomial = try CircleCodewordPolynomial(
            xCoefficients: polynomial.xCoefficients,
            yCoefficients: []
        )
        XCTAssertEqual(
            try codewordPlan.executeVerified(polynomial: xOnlyPolynomial).evaluations,
            try CircleCodewordOracle.evaluate(polynomial: xOnlyPolynomial, domain: domain)
        )
        let yOnlyPolynomial = try CircleCodewordPolynomial(
            xCoefficients: [],
            yCoefficients: polynomial.yCoefficients
        )
        XCTAssertEqual(
            try codewordPlan.executeVerified(polynomial: yOnlyPolynomial).evaluations,
            try CircleCodewordOracle.evaluate(polynomial: yOnlyPolynomial, domain: domain)
        )

        let outputOffset = 32
        let outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: outputOffset + domain.size * CircleCodewordPlan.elementByteCount,
            label: "CircleDomainTests.CircleCodewordOutput"
        )
        _ = try codewordPlan.executeResident(
            polynomial: polynomial,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset
        )
        XCTAssertEqual(
            try Self.readQM31Buffer(
                outputBuffer,
                offset: outputOffset,
                count: domain.size
            ),
            expectedCodeword
        )

        let coefficientOffset = 64
        let xCoefficientBytes = QM31CanonicalEncoding.pack(polynomial.xCoefficients)
        let yCoefficientBytes = QM31CanonicalEncoding.pack(polynomial.yCoefficients)
        let xCoefficientBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: coefficientOffset + xCoefficientBytes.count,
            label: "CircleDomainTests.CircleCodewordXCoefficients"
        )
        let yCoefficientBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: coefficientOffset + yCoefficientBytes.count,
            label: "CircleDomainTests.CircleCodewordYCoefficients"
        )
        try MetalBufferFactory.copy(
            xCoefficientBytes,
            into: xCoefficientBuffer,
            destinationOffset: coefficientOffset,
            byteCount: xCoefficientBytes.count
        )
        try MetalBufferFactory.copy(
            yCoefficientBytes,
            into: yCoefficientBuffer,
            destinationOffset: coefficientOffset,
            byteCount: yCoefficientBytes.count
        )
        let residentCoefficientOutput = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: domain.size * CircleCodewordPlan.elementByteCount,
            label: "CircleDomainTests.CircleCodewordResidentCoefficientOutput"
        )
        _ = try codewordPlan.executeResident(
            xCoefficientBuffer: xCoefficientBuffer,
            xCoefficientOffset: coefficientOffset,
            xCoefficientCount: polynomial.xCoefficients.count,
            yCoefficientBuffer: yCoefficientBuffer,
            yCoefficientOffset: coefficientOffset,
            yCoefficientCount: polynomial.yCoefficients.count,
            outputBuffer: residentCoefficientOutput
        )
        XCTAssertEqual(
            try Self.readQM31Buffer(residentCoefficientOutput, count: domain.size),
            expectedCodeword
        )
        let expectedCircleCoefficients = try CircleCodewordOracle.circleFFTCoefficients(
            polynomial: polynomial,
            domain: domain
        )
        let privateXWitnessBuffer = try Self.makePrivateBuffer(
            context: context,
            bytes: xCoefficientBytes,
            label: "CircleDomainTests.CircleCodewordPrivateXWitness"
        )
        let privateYWitnessBuffer = try Self.makePrivateBuffer(
            context: context,
            bytes: yCoefficientBytes,
            label: "CircleDomainTests.CircleCodewordPrivateYWitness"
        )
        let witnessBasisPlan = try CircleWitnessToFFTBasisPlanV1(context: context, domain: domain)
        XCTAssertEqual(witnessBasisPlan.commandPlan.input, .residentMonomialCoefficientColumns)
        XCTAssertEqual(witnessBasisPlan.commandPlan.output, .residentCircleFFTBasisBuffer)
        XCTAssertEqual(witnessBasisPlan.commandPlan.transformStrategy, .denseMatrix)
        XCTAssertEqual(witnessBasisPlan.commandPlan.transformTileRowCapacity, domain.halfSize)
        XCTAssertTrue(witnessBasisPlan.commandPlan.validatesPrivateWitnessCanonicality)
        XCTAssertFalse(witnessBasisPlan.commandPlan.verifiesAIRSemantics)
        XCTAssertFalse(witnessBasisPlan.commandPlan.producesAIRTrace)
        let witnessBasisOutput = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: domain.size * CircleWitnessToFFTBasisPlanV1.elementByteCount,
            label: "CircleDomainTests.CircleWitnessToFFTBasisOutput"
        )
        _ = try witnessBasisPlan.executeVerified(
            polynomial: polynomial,
            xWitnessCoefficientBuffer: privateXWitnessBuffer,
            yWitnessCoefficientBuffer: privateYWitnessBuffer,
            outputCircleCoefficientBuffer: witnessBasisOutput
        )
        XCTAssertEqual(
            try Self.readQM31Buffer(witnessBasisOutput, count: domain.size),
            expectedCircleCoefficients
        )
        let tiledWitnessBasisPlan = try CircleWitnessToFFTBasisPlanV1(
            context: context,
            domain: domain,
            transformTileRowCapacity: 3
        )
        XCTAssertEqual(tiledWitnessBasisPlan.commandPlan.transformStrategy, .tiledDenseMatrix)
        XCTAssertEqual(tiledWitnessBasisPlan.commandPlan.transformTileRowCapacity, 3)
        let tiledWitnessBasisOutput = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: domain.size * CircleWitnessToFFTBasisPlanV1.elementByteCount,
            label: "CircleDomainTests.CircleWitnessToFFTBasisTiledOutput"
        )
        _ = try tiledWitnessBasisPlan.executeResident(
            xWitnessCoefficientBuffer: privateXWitnessBuffer,
            xWitnessCoefficientCount: polynomial.xCoefficients.count,
            yWitnessCoefficientBuffer: privateYWitnessBuffer,
            yWitnessCoefficientCount: polynomial.yCoefficients.count,
            outputCircleCoefficientBuffer: tiledWitnessBasisOutput
        )
        XCTAssertEqual(
            try Self.readQM31Buffer(tiledWitnessBasisOutput, count: domain.size),
            expectedCircleCoefficients
        )
        let nonCanonicalWitnessBytes = QM31CanonicalEncoding.pack([
            QM31Element(a: QM31Field.modulus, b: 0, c: 0, d: 0)
        ])
        let nonCanonicalPrivateWitness = try Self.makePrivateBuffer(
            context: context,
            bytes: nonCanonicalWitnessBytes,
            label: "CircleDomainTests.CircleCodewordNonCanonicalPrivateWitness"
        )
        XCTAssertThrowsError(
            try witnessBasisPlan.executeResident(
                xWitnessCoefficientBuffer: nonCanonicalPrivateWitness,
                xWitnessCoefficientCount: 1,
                yWitnessCoefficientBuffer: privateYWitnessBuffer,
                yWitnessCoefficientCount: polynomial.yCoefficients.count,
                outputCircleCoefficientBuffer: witnessBasisOutput
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let residentProver = try CirclePCSFRIResidentProverV1(
            context: context,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: roundCount
        )
        let residentProof = try residentProver.proveVerified(
            evaluationsBuffer: outputBuffer,
            evaluationsOffset: outputOffset
        )
        XCTAssertEqual(residentProof.proof, expectedProof)

        let codewordProver = try CircleCodewordPCSFRIProverV1(
            context: context,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: roundCount
        )
        XCTAssertEqual(
            codewordProver.commandPlan.phases,
            CircleCodewordPCSFRIResidentCommandPlanV1.canonicalPhases
        )
        XCTAssertEqual(
            codewordProver.commandPlan.publicReadbacks,
            CircleCodewordPCSFRIResidentCommandPlanV1.canonicalPublicReadbacks
        )
        XCTAssertTrue(codewordProver.commandPlan.forbidsFullCodewordReadback)
        XCTAssertTrue(codewordProver.commandPlan.forbidsIntermediateFRILayerReadback)
        XCTAssertEqual(codewordProver.commandPlan.codewordCommitmentSchedule, .materializedCodewordThenCommit)
        XCTAssertFalse(codewordProver.commandPlan.usesFusedTiledCodewordCommitment)
        XCTAssertTrue(codewordProver.commandPlan.coefficientInputs.contains(.residentCircleFFTBasisBuffer))
        XCTAssertTrue(codewordProver.commandPlan.coefficientInputs.contains(.residentWitnessMonomialCoefficientColumns))
        let proofResult = try codewordProver.proveVerified(polynomial: polynomial)
        XCTAssertEqual(proofResult.proof, expectedProof)
        XCTAssertEqual(try CirclePCSFRIProofCodecV1.decode(proofResult.encodedProof), expectedProof)
        let residentCoefficientProof = try codewordProver.proveResidentCoefficientsVerified(
            polynomial: polynomial,
            xCoefficientBuffer: xCoefficientBuffer,
            xCoefficientOffset: coefficientOffset,
            yCoefficientBuffer: yCoefficientBuffer,
            yCoefficientOffset: coefficientOffset
        )
        XCTAssertEqual(residentCoefficientProof.proof, expectedProof)
        XCTAssertEqual(
            try CirclePCSFRIProofCodecV1.decode(residentCoefficientProof.encodedProof),
            expectedProof
        )
        let residentWitnessProof = try codewordProver.proveResidentWitnessCoefficientsVerified(
            polynomial: polynomial,
            xWitnessCoefficientBuffer: privateXWitnessBuffer,
            yWitnessCoefficientBuffer: privateYWitnessBuffer
        )
        XCTAssertNotNil(residentWitnessProof.witnessBasisStats)
        XCTAssertEqual(residentWitnessProof.proof, expectedProof)
        XCTAssertEqual(
            try CirclePCSFRIProofCodecV1.decode(residentWitnessProof.encodedProof),
            expectedProof
        )
        let circleCoefficientBytes = QM31CanonicalEncoding.pack(expectedCircleCoefficients)
        let circleCoefficientBuffer = try Self.makePrivateBuffer(
            context: context,
            bytes: circleCoefficientBytes,
            label: "CircleDomainTests.CircleCodewordCircleFFTCoefficients"
        )
        let residentFFTCoefficientProof = try codewordProver.proveCircleFFTCoefficientsResidentVerified(
            polynomial: polynomial,
            circleCoefficientBuffer: circleCoefficientBuffer
        )
        XCTAssertEqual(residentFFTCoefficientProof.proof, expectedProof)
        XCTAssertEqual(
            try CirclePCSFRIProofCodecV1.decode(residentFFTCoefficientProof.encodedProof),
            expectedProof
        )
        try codewordProver.clearReusableBuffers()
    }

    func testCircleFRIFoldPlanRejectsInvalidDomainsAndResidentLayouts() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        let naturalDomain = try CircleDomainDescriptor.canonical(
            logSize: 3,
            storageOrder: .circleDomainNatural
        )
        XCTAssertThrowsError(try CircleFRIFoldPlan(context: context, domain: naturalDomain)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let nonCanonicalDomain = try CircleDomainDescriptor(
            logSize: 3,
            halfCosetInitialIndex: .zero,
            halfCosetLogSize: 2,
            storageOrder: .circleDomainBitReversed
        )
        XCTAssertFalse(nonCanonicalDomain.isCanonical)
        XCTAssertThrowsError(try CircleFRIFoldPlan(context: context, domain: nonCanonicalDomain)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let domain = try CircleDomainDescriptor.canonical(logSize: 3)
        let plan = try CircleFRIFoldPlan(context: context, domain: domain)
        let one = QM31Element(a: 1, b: 0, c: 0, d: 0)
        XCTAssertThrowsError(try plan.execute(evaluations: [one], challenge: one)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try plan.execute(
                evaluations: Array(repeating: one, count: domain.size),
                challenge: QM31Element(a: QM31Field.modulus, b: 0, c: 0, d: 0)
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let shortEvaluationBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: QM31CanonicalEncoding.pack([one]),
            declaredLength: CircleFRIFoldPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIFoldShortEvaluations"
        )
        let outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: domain.halfSize * CircleFRIFoldPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIFoldInvalidOutput"
        )
        XCTAssertThrowsError(
            try plan.executeResident(
                evaluationsBuffer: shortEvaluationBuffer,
                outputBuffer: outputBuffer,
                challenge: one
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let fullEvaluationBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: QM31CanonicalEncoding.pack(Array(repeating: one, count: domain.size)),
            declaredLength: domain.size * CircleFRIFoldPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIFoldAliasedEvaluations"
        )
        XCTAssertThrowsError(
            try plan.executeResident(
                evaluationsBuffer: fullEvaluationBuffer,
                outputBuffer: fullEvaluationBuffer,
                challenge: one
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testCircleFRIFoldChainPlanRejectsInvalidDomainsAndResidentLayouts() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        let naturalDomain = try CircleDomainDescriptor.canonical(
            logSize: 4,
            storageOrder: .circleDomainNatural
        )
        XCTAssertThrowsError(try CircleFRIFoldChainPlan(
            context: context,
            domain: naturalDomain,
            roundCount: 2
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let domain = try CircleDomainDescriptor.canonical(logSize: 4)
        XCTAssertThrowsError(try CircleFRIFoldChainPlan(
            context: context,
            domain: domain,
            roundCount: 0
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try CircleFRIFoldChainPlan(
            context: context,
            domain: domain,
            roundCount: Int(domain.logSize) + 1
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let plan = try CircleFRIFoldChainPlan(context: context, domain: domain, roundCount: 2)
        let one = QM31Element(a: 1, b: 0, c: 0, d: 0)
        XCTAssertThrowsError(
            try plan.execute(
                evaluations: Array(repeating: one, count: domain.size),
                challenges: [one]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try plan.execute(
                evaluations: Array(repeating: one, count: domain.size),
                challenges: [one, QM31Element(a: QM31Field.modulus, b: 0, c: 0, d: 0)]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let fullEvaluationBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: QM31CanonicalEncoding.pack(Array(repeating: one, count: domain.size)),
            declaredLength: domain.size * CircleFRIFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIFoldChainAliasedEvaluations"
        )
        let shortOutputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: CircleFRIFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIFoldChainShortOutput"
        )
        XCTAssertThrowsError(
            try plan.executeResident(
                evaluationsBuffer: fullEvaluationBuffer,
                outputBuffer: shortOutputBuffer,
                challenges: [one, one]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try plan.executeResident(
                evaluationsBuffer: fullEvaluationBuffer,
                outputBuffer: fullEvaluationBuffer,
                challenges: [one, one]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testCircleFRIMerkleTranscriptFoldChainPlanRejectsInvalidInputsAndResidentLayouts() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: 2,
            foldingStep: 1,
            grindingBits: 0
        )
        let badFoldingSecurity = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: 2,
            foldingStep: 2,
            grindingBits: 0
        )
        let publicInputs = try CirclePCSFRIPublicInputsV1(publicInputDigest: Data(repeating: 0x31, count: 32))
        let naturalDomain = try CircleDomainDescriptor.canonical(
            logSize: 4,
            storageOrder: .circleDomainNatural
        )
        XCTAssertThrowsError(try CircleFRIMerkleTranscriptFoldChainPlan(
            context: context,
            domain: naturalDomain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: 2
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let domain = try CircleDomainDescriptor.canonical(logSize: 4)
        XCTAssertThrowsError(try CircleFRIMerkleTranscriptFoldChainPlan(
            context: context,
            domain: domain,
            securityParameters: badFoldingSecurity,
            publicInputs: publicInputs,
            roundCount: 2
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try CircleFRIMerkleTranscriptFoldChainPlan(
            context: context,
            domain: domain,
            securityParameters: security,
            publicInputDigest: Data(repeating: 0x31, count: 31),
            roundCount: 2
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try CircleFRIMerkleTranscriptFoldChainPlan(
            context: context,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: 0
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let plan = try CircleFRIMerkleTranscriptFoldChainPlan(
            context: context,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: 2
        )
        let one = QM31Element(a: 1, b: 0, c: 0, d: 0)
        XCTAssertThrowsError(try plan.execute(evaluations: [one])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let fullEvaluationBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: QM31CanonicalEncoding.pack(Array(repeating: one, count: domain.size)),
            declaredLength: domain.size * CircleFRIMerkleTranscriptFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIMerkleTranscriptAliasedEvaluations"
        )
        let shortCommitmentBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: CircleFRIMerkleTranscriptFoldChainPlan.commitmentByteCount,
            label: "CircleDomainTests.CircleFRIMerkleTranscriptShortCommitments"
        )
        let shortOutputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: CircleFRIMerkleTranscriptFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIMerkleTranscriptShortOutput"
        )
        XCTAssertThrowsError(
            try plan.executeResident(
                evaluationsBuffer: fullEvaluationBuffer,
                commitmentOutputBuffer: shortCommitmentBuffer,
                outputBuffer: shortOutputBuffer
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let commitmentBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: 2 * CircleFRIMerkleTranscriptFoldChainPlan.commitmentByteCount,
            label: "CircleDomainTests.CircleFRIMerkleTranscriptCommitments"
        )
        XCTAssertThrowsError(
            try plan.executeResident(
                evaluationsBuffer: fullEvaluationBuffer,
                commitmentOutputBuffer: commitmentBuffer,
                outputBuffer: shortOutputBuffer
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        let outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: (domain.size >> 2) * CircleFRIMerkleTranscriptFoldChainPlan.elementByteCount,
            label: "CircleDomainTests.CircleFRIMerkleTranscriptOutput"
        )
        XCTAssertThrowsError(
            try plan.executeResident(
                evaluationsBuffer: fullEvaluationBuffer,
                commitmentOutputBuffer: fullEvaluationBuffer,
                outputBuffer: outputBuffer
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let extractor = try CircleFRIResidentQueryExtractorV1(
            context: context,
            domain: domain,
            roundCount: 2
        )
        let dummyCommitments = [
            Data(repeating: 0x11, count: 32),
            Data(repeating: 0x22, count: 32),
        ]
        XCTAssertThrowsError(
            try extractor.extractQueries(
                committedLayerBuffer: fullEvaluationBuffer,
                commitments: dummyCommitments,
                queryPairIndices: [0]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        let committedLayerBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: extractor.totalCommittedLayerCount * CircleFRIResidentQueryExtractorV1.elementByteCount,
            label: "CircleDomainTests.CircleFRIExtractorCommittedLayers"
        )
        XCTAssertThrowsError(
            try extractor.extractQueries(
                committedLayerBuffer: committedLayerBuffer,
                commitments: dummyCommitments,
                queryPairIndices: [domain.halfSize]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let prover = try CirclePCSFRIResidentProverV1(
            context: context,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: 2
        )
        XCTAssertThrowsError(
            try prover.proveVerified(evaluationsBuffer: shortOutputBuffer)
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        XCTAssertThrowsError(try CircleCodewordPolynomial(xCoefficients: [], yCoefficients: [])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        let polynomial = try Self.makeStableCircleCodewordPolynomial()
        XCTAssertThrowsError(try CircleCodewordPlan(context: context, domain: naturalDomain)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        let codewordPlan = try CircleCodewordPlan(context: context, domain: domain)
        XCTAssertThrowsError(
            try codewordPlan.executeResident(
                polynomial: polynomial,
                outputBuffer: shortOutputBuffer
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        let oversizedPolynomial = try CircleCodewordPolynomial(
            xCoefficients: Array(repeating: one, count: domain.halfSize + 1),
            yCoefficients: []
        )
        XCTAssertThrowsError(
            try CircleCodewordOracle.evaluateWithCircleFFT(
                polynomial: oversizedPolynomial,
                domain: domain
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try codewordPlan.executeResident(
                polynomial: oversizedPolynomial,
                outputBuffer: fullEvaluationBuffer
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        let coefficientBytes = QM31CanonicalEncoding.pack(polynomial.xCoefficients)
        let aliasedCoefficientBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: domain.size * CircleCodewordPlan.elementByteCount,
            label: "CircleDomainTests.CircleCodewordAliasedCoefficients"
        )
        try MetalBufferFactory.copy(
            coefficientBytes,
            into: aliasedCoefficientBuffer,
            byteCount: coefficientBytes.count
        )
        let yCoefficientBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: QM31CanonicalEncoding.pack(polynomial.yCoefficients),
            declaredLength: polynomial.yCoefficients.count * CircleCodewordPlan.elementByteCount,
            label: "CircleDomainTests.CircleCodewordYCoefficients"
        )
        XCTAssertThrowsError(
            try codewordPlan.executeResident(
                xCoefficientBuffer: aliasedCoefficientBuffer,
                xCoefficientCount: polynomial.xCoefficients.count,
                yCoefficientBuffer: yCoefficientBuffer,
                yCoefficientCount: polynomial.yCoefficients.count,
                outputBuffer: aliasedCoefficientBuffer
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }
#endif

    private struct CirclePCSFRIProofCorpusFixture: Decodable {
        let artifact: String
        let profile: CirclePCSFRIProofCorpusProfile
        let schemaVersion: Int
        let tamperVectors: [CirclePCSFRIProofCorpusTamperVector]
        let validCase: CirclePCSFRIProofCorpusCase
    }

    private struct CirclePCSFRIProofCorpusProfile: Decodable {
        let foldingStep: UInt32
        let grindingBits: UInt32
        let id: String
        let logBlowupFactor: UInt32
        let nominalSecurityBits: UInt32
        let queryCount: UInt32
        let targetSoundnessBits: UInt32
    }

    private struct CirclePCSFRIProofCorpusCase: Decodable {
        let claimedStorageIndices: [Int]
        let domainLogSize: UInt32
        let expectedVerifierAccepted: Bool
        let id: String
        let proofByteCount: Int
        let proofDigestHex: String
        let proofHex: String
        let publicInputDigestHex: String
        let roundCount: Int
        let storageOrder: String
        let xCoefficientHex: [String]
        let yCoefficientHex: [String]
    }

    private struct CirclePCSFRIProofCorpusTamperVector: Decodable {
        let description: String
        let expectedVerifierAccepted: Bool
        let id: String
        let proofByteCount: Int
        let proofDigestHex: String
        let proofHex: String
    }

    private struct ApplicationProofCorpusFixture: Decodable {
        let artifact: String
        let schemaVersion: Int
        let statement: ApplicationProofCorpusStatement
        let tamperVectors: [ApplicationProofCorpusCase]
        let validCase: ApplicationProofCorpusCase
    }

    private struct ApplicationProofCorpusStatement: Decodable {
        let airDefinitionDigestHex: String
        let applicationIdentifier: String
        let claimedStorageIndices: [Int]
        let domainLogSize: UInt32
        let gkrClaimDigestHex: String
        let parameterSet: ApplicationProofCorpusParameterSet
        let statementDigestHex: String
        let storageOrder: String
        let sumcheckEvaluationWords: [UInt32]
        let sumcheckRounds: Int
        let witnessCommitmentDigestHex: String
        let xCoefficientHex: [String]
        let yCoefficientHex: [String]
    }

    private struct ApplicationProofCorpusParameterSet: Decodable {
        let foldingStep: UInt32
        let grindingBits: UInt32
        let id: String
        let logBlowupFactor: UInt32
        let nominalSecurityBits: UInt32
        let queryCount: UInt32
        let targetSoundnessBits: UInt32
    }

    private struct ApplicationProofCorpusCase: Decodable {
        let description: String?
        let expectedVerifierAccepted: Bool
        let id: String
        let proofByteCount: Int
        let proofDigestHex: String
        let proofHex: String
    }

    private static func loadCirclePCSFRIProofCorpus() throws -> CirclePCSFRIProofCorpusFixture {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "CirclePCSFRIProofCorpusV1",
            withExtension: "json"
        ))
        return try JSONDecoder().decode(
            CirclePCSFRIProofCorpusFixture.self,
            from: try Data(contentsOf: url)
        )
    }

    private static func loadApplicationProofCorpus() throws -> ApplicationProofCorpusFixture {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "ApplicationProofCorpusV1",
            withExtension: "json"
        ))
        return try JSONDecoder().decode(
            ApplicationProofCorpusFixture.self,
            from: try Data(contentsOf: url)
        )
    }

    private static func makeApplicationCorpusStatement(
        _ proofStatement: ApplicationProofCorpusStatement
    ) throws -> (ApplicationProofStatementV1, M31SumcheckProofV1) {
        XCTAssertEqual(proofStatement.storageOrder, "circle-domain-bit-reversed")
        XCTAssertEqual(proofStatement.parameterSet.id, CirclePCSFRIParameterSetV1.ProfileID.conservative128.rawValue)
        XCTAssertEqual(proofStatement.parameterSet.foldingStep, 1)
        let parameterSet = try CirclePCSFRIParameterSetV1(
            profileID: .conservative128,
            logBlowupFactor: proofStatement.parameterSet.logBlowupFactor,
            queryCount: proofStatement.parameterSet.queryCount,
            grindingBits: proofStatement.parameterSet.grindingBits,
            targetSoundnessBits: proofStatement.parameterSet.targetSoundnessBits
        )
        XCTAssertEqual(parameterSet.securityParameters.nominalSecurityBits, proofStatement.parameterSet.nominalSecurityBits)

        let domain = try CircleDomainDescriptor.canonical(logSize: proofStatement.domainLogSize)
        let polynomial = try CircleCodewordPolynomial(
            xCoefficients: try qm31Elements(fromHexStrings: proofStatement.xCoefficientHex),
            yCoefficients: try qm31Elements(fromHexStrings: proofStatement.yCoefficientHex)
        )
        let claim = try CirclePCSFRIPolynomialClaimV1.make(
            domain: domain,
            polynomial: polynomial,
            storageIndices: proofStatement.claimedStorageIndices
        )
        let pcsStatement = try CirclePCSFRIStatementV1(
            parameterSet: parameterSet,
            polynomialClaim: claim
        )
        let sumcheckProof = try M31SumcheckProofBuilderV1.prove(
            evaluations: proofStatement.sumcheckEvaluationWords,
            rounds: proofStatement.sumcheckRounds
        )
        let statement = try ApplicationProofStatementV1(
            applicationIdentifier: proofStatement.applicationIdentifier,
            witnessCommitmentDigest: try decodeHex(proofStatement.witnessCommitmentDigestHex),
            airDefinitionDigest: try decodeHex(proofStatement.airDefinitionDigestHex),
            gkrClaimDigest: try decodeHex(proofStatement.gkrClaimDigestHex),
            sumcheckStatement: sumcheckProof.statement,
            pcsStatement: pcsStatement
        )
        return (statement, sumcheckProof)
    }

    @discardableResult
    private static func assertEncodedApplicationCorpusProof(
        _ proofCase: ApplicationProofCorpusCase,
        statement: ApplicationProofStatementV1
    ) throws -> ApplicationProofV1 {
        let proofBytes = try decodeHex(proofCase.proofHex)
        XCTAssertEqual(proofBytes.count, proofCase.proofByteCount, proofCase.id)
        XCTAssertEqual(SHA3Oracle.sha3_256(proofBytes).hexString, proofCase.proofDigestHex, proofCase.id)

        let proof = try ApplicationProofCodecV1.decode(proofBytes)
        XCTAssertEqual(try ApplicationProofCodecV1.encode(proof), proofBytes, proofCase.id)
        XCTAssertEqual(
            try ApplicationProofVerifierV1.verify(proof: proof, statement: statement),
            proofCase.expectedVerifierAccepted,
            proofCase.id
        )
        XCTAssertEqual(
            try ApplicationProofVerifierV1.verify(encodedProof: proofBytes, statement: statement),
            proofCase.expectedVerifierAccepted,
            proofCase.id
        )
        return proof
    }

    private static func makeCorpusStatement(
        _ proofCase: CirclePCSFRIProofCorpusCase,
        parameterSet: CirclePCSFRIParameterSetV1
    ) throws -> CirclePCSFRIStatementV1 {
        XCTAssertEqual(proofCase.storageOrder, "circle-domain-bit-reversed")
        let domain = try CircleDomainDescriptor.canonical(logSize: proofCase.domainLogSize)
        let polynomial = try CircleCodewordPolynomial(
            xCoefficients: try qm31Elements(fromHexStrings: proofCase.xCoefficientHex),
            yCoefficients: try qm31Elements(fromHexStrings: proofCase.yCoefficientHex)
        )
        let claim = try CirclePCSFRIPolynomialClaimV1.make(
            domain: domain,
            polynomial: polynomial,
            storageIndices: proofCase.claimedStorageIndices
        )
        return try CirclePCSFRIStatementV1(
            parameterSet: parameterSet,
            polynomialClaim: claim
        )
    }

    @discardableResult
    private static func assertEncodedCorpusProof(
        id: String,
        expectedVerifierAccepted: Bool,
        proofByteCount: Int,
        proofDigestHex: String,
        proofHex: String,
        statement: CirclePCSFRIStatementV1
    ) throws -> CirclePCSFRIProofV1 {
        let proofBytes = try decodeHex(proofHex)
        XCTAssertEqual(proofBytes.count, proofByteCount, id)
        XCTAssertEqual(SHA3Oracle.sha3_256(proofBytes).hexString, proofDigestHex, id)

        let proof = try CirclePCSFRIProofCodecV1.decode(proofBytes)
        XCTAssertEqual(try CirclePCSFRIProofCodecV1.encode(proof), proofBytes, id)
        XCTAssertEqual(
            try CirclePCSFRIContractVerifierV1.verify(proof: proof, statement: statement),
            expectedVerifierAccepted,
            id
        )
        XCTAssertEqual(
            try CirclePCSFRIContractVerifierV1.verify(encodedProof: proofBytes, statement: statement),
            expectedVerifierAccepted,
            id
        )
        return proof
    }

    private static func qm31Elements(fromHexStrings hexStrings: [String]) throws -> [QM31Element] {
        try hexStrings.map { hexString in
            try QM31CanonicalEncoding.unpack(try decodeHex(hexString))
        }
    }

    private static func decodeHex(_ hexString: String) throws -> Data {
        guard hexString.utf8.count.isMultiple(of: 2) else {
            throw AppleZKProverError.invalidInputLayout
        }
        var data = Data()
        data.reserveCapacity(hexString.utf8.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else {
                throw AppleZKProverError.invalidInputLayout
            }
            data.append(byte)
            index = nextIndex
        }
        return data
    }

    private static func makeProof(queryCount: UInt32) throws -> CirclePCSFRIProofV1 {
        let domain = try CircleDomainDescriptor.canonical(logSize: 3)
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: 2,
            queryCount: queryCount,
            foldingStep: 1,
            grindingBits: 0
        )
        let commitments = [
            Data(repeating: 0x11, count: 32),
            Data(repeating: 0x22, count: 32),
        ]
        let finalLayer = [
            QM31Element(a: 11, b: 22, c: 33, d: 44),
            QM31Element(a: 55, b: 66, c: 77, d: 88),
        ]
        var queries: [CircleFRIQueryV1] = []
        queries.reserveCapacity(Int(queryCount))
        for queryIndex in 0..<Int(queryCount) {
            let initialPairIndex = queryIndex == 0 ? 0 : 3
            let firstLayer = try Self.makeDummyLayerOpening(
                layerIndex: 0,
                pairIndex: UInt64(initialPairIndex),
                siblingCount: 3,
                salt: UInt8(0x30 + queryIndex)
            )
            let secondLayer = try Self.makeDummyLayerOpening(
                layerIndex: 1,
                pairIndex: UInt64(initialPairIndex >> 1),
                siblingCount: 2,
                salt: UInt8(0x60 + queryIndex)
            )
            queries.append(try CircleFRIQueryV1(
                initialPairIndex: UInt64(initialPairIndex),
                layers: [firstLayer, secondLayer]
            ))
        }
        return try CirclePCSFRIProofV1(
            domain: domain,
            securityParameters: security,
            publicInputDigest: Data(repeating: 0x42, count: 32),
            commitments: commitments,
            finalLayer: finalLayer,
            queries: queries
        )
    }

    private static func makeDummyLayerOpening(
        layerIndex: UInt32,
        pairIndex: UInt64,
        siblingCount: Int,
        salt: UInt8
    ) throws -> CircleFRIQueryLayerOpeningV1 {
        let leftIndex = pairIndex * 2
        let rightIndex = leftIndex + 1
        let left = try CircleFRIValueOpeningV1(
            leafIndex: leftIndex,
            value: QM31Element(
                a: UInt32(100 + Int(salt)),
                b: UInt32(200 + Int(salt)),
                c: UInt32(300 + Int(salt)),
                d: UInt32(400 + Int(salt))
            ),
            siblingHashes: (0..<siblingCount).map {
                Data(repeating: UInt8(Int(salt) + $0), count: 32)
            }
        )
        let right = try CircleFRIValueOpeningV1(
            leafIndex: rightIndex,
            value: QM31Element(
                a: UInt32(500 + Int(salt)),
                b: UInt32(600 + Int(salt)),
                c: UInt32(700 + Int(salt)),
                d: UInt32(800 + Int(salt))
            ),
            siblingHashes: (0..<siblingCount).map {
                Data(repeating: UInt8(Int(salt) + 16 + $0), count: 32)
            }
        )
        return CircleFRIQueryLayerOpeningV1(
            layerIndex: layerIndex,
            pairIndex: pairIndex,
            left: left,
            right: right
        )
    }

    private static func makeStableCircleEvaluations(count: Int) -> [QM31Element] {
        var evaluations: [QM31Element] = []
        evaluations.reserveCapacity(count)
        for index in 0..<count {
            evaluations.append(QM31Element(
                a: UInt32(17 + index * 3),
                b: UInt32(29 + index * 5),
                c: UInt32(31 + index * 7),
                d: UInt32(43 + index * 11)
            ))
        }
        return evaluations
    }

    private static func makeDeterministicQM31Coefficients(count: Int, salt: UInt32) -> [QM31Element] {
        (0..<count).map { index in
            let value = UInt32(index)
            return QM31Element(
                a: 3 &+ salt &+ value &* 5,
                b: 7 &+ salt &+ value &* 11,
                c: 13 &+ salt &+ value &* 17,
                d: 19 &+ salt &+ value &* 23
            )
        }
    }

    private static func makeStableCircleCodewordPolynomial() throws -> CircleCodewordPolynomial {
        try CircleCodewordPolynomial(
            xCoefficients: [
                QM31Element(a: 3, b: 5, c: 7, d: 11),
                QM31Element(a: 13, b: 17, c: 19, d: 23),
                QM31Element(a: 29, b: 31, c: 37, d: 41),
                QM31Element(a: 43, b: 47, c: 53, d: 59),
            ],
            yCoefficients: [
                QM31Element(a: 61, b: 67, c: 71, d: 73),
                QM31Element(a: 79, b: 83, c: 89, d: 97),
                QM31Element(a: 101, b: 103, c: 107, d: 109),
            ]
        )
    }

    private static func circleDomainPoints(_ domain: CircleDomainDescriptor) throws -> [CirclePointM31] {
        try (0..<domain.size).map { storageIndex in
            let naturalIndex = try CircleDomainOracle.naturalDomainIndex(
                forStorageIndex: storageIndex,
                descriptor: domain
            )
            let point = try CircleDomainOracle.point(
                in: domain,
                naturalDomainIndex: naturalIndex
            )
            try CircleDomainOracle.validatePoint(point)
            return point
        }
    }

    private static func packCircleDomainPoints(_ domain: CircleDomainDescriptor) throws -> Data {
        var data = Data()
        data.reserveCapacity(try checkedBufferLength(domain.size, 2 * MemoryLayout<UInt32>.stride))
        for point in try circleDomainPoints(domain) {
            CanonicalBinary.appendUInt32(point.x, to: &data)
            CanonicalBinary.appendUInt32(point.y, to: &data)
        }
        return data
    }

    private static func packM31Words(_ words: [UInt32]) throws -> Data {
        try M31Field.validateCanonical(words)
        var data = Data()
        data.reserveCapacity(try checkedBufferLength(words.count, MemoryLayout<UInt32>.stride))
        for word in words {
            CanonicalBinary.appendUInt32(word, to: &data)
        }
        return data
    }

#if canImport(Metal)
    private static func readQM31Buffer(_ buffer: MTLBuffer, count: Int) throws -> [QM31Element] {
        let byteCount = count * CircleFRIFoldPlan.elementByteCount
        let data = Data(bytes: buffer.contents(), count: byteCount)
        return try QM31CanonicalEncoding.unpackMany(data, count: count)
    }

    private static func readQM31Buffer(
        _ buffer: MTLBuffer,
        offset: Int,
        count: Int
    ) throws -> [QM31Element] {
        let byteCount = count * CircleFRIFoldPlan.elementByteCount
        let data = Data(bytes: buffer.contents().advanced(by: offset), count: byteCount)
        return try QM31CanonicalEncoding.unpackMany(data, count: count)
    }

    private static func readCommitmentBuffer(_ buffer: MTLBuffer, count: Int) -> [Data] {
        let commitmentByteCount = CircleFRIMerkleTranscriptFoldChainPlan.commitmentByteCount
        let bytes = buffer.contents().bindMemory(to: UInt8.self, capacity: count * commitmentByteCount)
        return (0..<count).map { index in
            Data(bytes: bytes.advanced(by: index * commitmentByteCount), count: commitmentByteCount)
        }
    }

    private static func makePrivateBuffer(
        context: MetalContext,
        bytes: Data,
        label: String
    ) throws -> MTLBuffer {
        let buffer = try MetalBufferFactory.makePrivateBuffer(
            device: context.device,
            length: bytes.count,
            label: label
        )
        let staging = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            bytes: bytes,
            declaredLength: bytes.count,
            label: "\(label).Staging"
        )
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "\(label).Upload"
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        blit.label = "\(label).Upload.Copy"
        if bytes.count > 0 {
            blit.copy(from: staging, sourceOffset: 0, to: buffer, destinationOffset: 0, size: bytes.count)
        }
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }
        return buffer
    }
#endif
}
