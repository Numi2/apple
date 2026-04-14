import Foundation
import XCTest
@testable import AppleZKProver
#if canImport(Metal)
import Metal
#endif

final class ApplicationTheoremTests: XCTestCase {
    func testAIRProofManifestRecordsPublicRevealedTraceScope() {
        let manifest = AIRProofManifestV1.current
        XCTAssertEqual(manifest.version, AIRProofManifestV1.currentVersion)
        XCTAssertEqual(manifest.artifact, AIRProofManifestV1.artifactName)
        XCTAssertTrue(manifest.verifiesAIRSemantics)
        XCTAssertTrue(manifest.includesPublicWitnessTrace)
        XCTAssertTrue(manifest.usesTranscriptComposedConstraintEvaluations)
        XCTAssertTrue(manifest.verifiesPublicTraceQuotientDivisibility)
        XCTAssertFalse(manifest.provesQuotientLowDegree)
        XCTAssertFalse(manifest.usesPCSBackedOpenings)
        XCTAssertFalse(manifest.isSuccinct)
        XCTAssertFalse(manifest.isZeroKnowledge)
        XCTAssertEqual(manifest.acceptedClaimScope, .publicRevealedTraceConstraintEvaluation)
        XCTAssertEqual(manifest.rejectedClaimScopes, [.succinctPrivateAIR])
        XCTAssertEqual(manifest.openBoundaries, [
            .quotientPolynomialLowDegreeProof,
            .pcsBackedConstraintOpenings,
            .privateWitness,
            .zeroKnowledge,
        ])
    }

    func testAIRProofQuotientPCSArtifactManifestRecordsPublicPCSScope() {
        let manifest = AIRProofQuotientPCSArtifactManifestV1.current
        XCTAssertEqual(manifest.version, AIRProofQuotientPCSArtifactManifestV1.currentVersion)
        XCTAssertEqual(manifest.artifact, AIRProofQuotientPCSArtifactManifestV1.artifactName)
        XCTAssertTrue(manifest.includesAIRProof)
        XCTAssertTrue(manifest.includesPublicQuotientPCSProofBundle)
        XCTAssertTrue(manifest.verifiesPublicRevealedTraceAIR)
        XCTAssertTrue(manifest.verifiesQuotientPCSBundleAgainstAIRProof)
        XCTAssertTrue(manifest.usesPCSBackedQuotientLowDegreeProof)
        XCTAssertFalse(manifest.isSuccinctAIRGKRProof)
        XCTAssertFalse(manifest.isZeroKnowledge)
        XCTAssertEqual(manifest.openBoundaries, [
            .privateWitness,
            .zeroKnowledge,
            .succinctAIRGKRProof,
        ])
    }

    func testApplicationTheoremManifestRecordsPublicSidecarScope() {
        let manifest = ApplicationTheoremManifestV1.current
        XCTAssertEqual(manifest.version, ApplicationTheoremManifestV1.currentVersion)
        XCTAssertEqual(manifest.artifact, ApplicationTheoremManifestV1.artifactName)
        XCTAssertTrue(manifest.verifiesApplicationProofComponents)
        XCTAssertTrue(manifest.bindsPublicWitnessDigest)
        XCTAssertTrue(manifest.verifiesWitnessToAIRTraceProduction)
        XCTAssertTrue(manifest.verifiesAIRSemantics)
        XCTAssertTrue(manifest.verifiesAIRToSumcheckReduction)
        XCTAssertTrue(manifest.verifiesGKRClaimSemantics)
        XCTAssertFalse(manifest.selfContainedProofArtifact)
        XCTAssertFalse(manifest.isZeroKnowledge)
        XCTAssertEqual(manifest.openBoundaries, [
            .succinctAIRGKRProof,
            .zeroKnowledge,
        ])
    }

    func testApplicationPublicTheoremArtifactManifestRecordsSelfContainedPublicScope() {
        let manifest = ApplicationPublicTheoremArtifactManifestV1.current
        XCTAssertEqual(manifest.version, ApplicationPublicTheoremArtifactManifestV1.currentVersion)
        XCTAssertEqual(manifest.artifact, ApplicationPublicTheoremArtifactManifestV1.artifactName)
        XCTAssertTrue(manifest.includesStatement)
        XCTAssertTrue(manifest.includesApplicationProof)
        XCTAssertTrue(manifest.includesPublicWitnessTrace)
        XCTAssertTrue(manifest.includesAIRDefinition)
        XCTAssertTrue(manifest.includesGKRClaim)
        XCTAssertTrue(manifest.verifiesEndToEndPublicTheorem)
        XCTAssertFalse(manifest.isSuccinctAIRGKRProof)
        XCTAssertFalse(manifest.isZeroKnowledge)
        XCTAssertEqual(manifest.openBoundaries, [
            .succinctAIRGKRProof,
            .zeroKnowledge,
        ])
    }

    func testApplicationPublicTheoremTracePCSArtifactManifestRecordsTracePCSBundleScope() {
        let manifest = ApplicationPublicTheoremTracePCSArtifactManifestV1.current
        XCTAssertEqual(manifest.version, ApplicationPublicTheoremTracePCSArtifactManifestV1.currentVersion)
        XCTAssertEqual(manifest.artifact, ApplicationPublicTheoremTracePCSArtifactManifestV1.artifactName)
        XCTAssertTrue(manifest.includesPublicTheoremArtifact)
        XCTAssertTrue(manifest.includesAIRTracePCSProofBundle)
        XCTAssertTrue(manifest.verifiesEndToEndPublicTheorem)
        XCTAssertTrue(manifest.verifiesTracePCSBundleAgainstAIRTrace)
        XCTAssertTrue(manifest.requiresApplicationPCSProofInTraceBundle)
        XCTAssertFalse(manifest.isSuccinctAIRGKRProof)
        XCTAssertFalse(manifest.isZeroKnowledge)
        XCTAssertEqual(manifest.openBoundaries, [
            .succinctAIRGKRProof,
            .zeroKnowledge,
        ])
    }

    func testApplicationPublicTheoremIntegratedArtifactManifestRecordsPublicAIRPCSScope() {
        let manifest = ApplicationPublicTheoremIntegratedArtifactManifestV1.current
        XCTAssertEqual(manifest.version, ApplicationPublicTheoremIntegratedArtifactManifestV1.currentVersion)
        XCTAssertEqual(manifest.artifact, ApplicationPublicTheoremIntegratedArtifactManifestV1.artifactName)
        XCTAssertTrue(manifest.includesPublicTheoremArtifact)
        XCTAssertTrue(manifest.includesAIRConstraintMultilinearSumcheck)
        XCTAssertTrue(manifest.includesSharedDomainQuotientIdentityPCS)
        XCTAssertTrue(manifest.verifiesPublicAIRGKRTheorem)
        XCTAssertTrue(manifest.verifiesAIRConstraintSumcheck)
        XCTAssertTrue(manifest.verifiesSharedDomainQuotientIdentity)
        XCTAssertTrue(manifest.verifiesGKRClaimSemantics)
        XCTAssertFalse(manifest.isSuccinctAIRGKRProof)
        XCTAssertFalse(manifest.isZeroKnowledge)
        XCTAssertEqual(manifest.openBoundaries, [
            .succinctAIRGKRProof,
            .zeroKnowledge,
        ])
    }

    func testWitnessLayoutProducesNamedAIRTrace() throws {
        let layout = try ApplicationWitnessLayoutV1(columns: [
            try ApplicationWitnessColumnV1(name: "next", values: [1, 2, 3]),
            try ApplicationWitnessColumnV1(name: "current", values: [5, 8, 13]),
        ])

        XCTAssertEqual(layout.columnCount, 2)
        XCTAssertEqual(layout.rowCount, 3)
        XCTAssertEqual(layout.columnNames, ["next", "current"])
        XCTAssertEqual(try layout.column(named: "current").values, [5, 8, 13])
        XCTAssertEqual(try layout.traceInDeclaredOrder().columns, [
            [1, 2, 3],
            [5, 8, 13],
        ])
        XCTAssertEqual(try layout.trace(columnOrder: ["current", "next"]).columns, [
            [5, 8, 13],
            [1, 2, 3],
        ])

        XCTAssertThrowsError(try ApplicationWitnessColumnV1(name: " ", values: [1]))
        XCTAssertThrowsError(try ApplicationWitnessLayoutV1(columns: [
            try ApplicationWitnessColumnV1(name: "a", values: [1, 2]),
            try ApplicationWitnessColumnV1(name: "a", values: [3, 4]),
        ]))
        XCTAssertThrowsError(try ApplicationWitnessLayoutV1(columns: [
            try ApplicationWitnessColumnV1(name: "a", values: [1, 2]),
            try ApplicationWitnessColumnV1(name: "b", values: [3]),
        ]))
        XCTAssertThrowsError(try layout.trace(columnOrder: ["current", "current"]))
        XCTAssertThrowsError(try layout.trace(columnOrder: ["missing"]))
    }

#if canImport(Metal)
    func testResidentAIRTraceSynthesisMatchesCPUOracleAndFeedsAIRSemantics() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }
        let context = try MetalContext(device: device)
        let witness = try Self.fibonacciWitness()
        let air = try Self.fibonacciAIRDefinition()
        let expectedTrace = try WitnessToAIRTraceProducerV1.produce(witness: witness, for: air)
        let witnessBytes = try AIRTraceResidentSynthesisOracleV1.packColumnMajorWitness(witness)
        let privateWitnessBuffer = try Self.makePrivateBuffer(
            context: context,
            bytes: witnessBytes,
            label: "ApplicationTheoremTests.ResidentAIRTraceWitness"
        )
        let privateTraceBuffer = try MetalBufferFactory.makePrivateBuffer(
            device: device,
            length: witnessBytes.count,
            label: "ApplicationTheoremTests.ResidentAIRTraceOutput"
        )
        let plan = try AIRTraceResidentSynthesisPlanV1(
            context: context,
            rowCount: witness.rowCount,
            columnCount: witness.columnCount
        )

        XCTAssertEqual(plan.commandPlan.inputLayout, .privateColumnMajorM31Witness)
        XCTAssertEqual(plan.commandPlan.outputLayout, .residentRowMajorM31AIRTrace)
        XCTAssertTrue(plan.commandPlan.validatesPrivateWitnessCanonicality)
        XCTAssertTrue(plan.commandPlan.producesAIRTrace)
        XCTAssertFalse(plan.commandPlan.verifiesAIRSemantics)
        XCTAssertFalse(plan.commandPlan.isZeroKnowledge)

        let result = try plan.executeVerified(
            witness: witness,
            definition: air,
            witnessColumnMajorBuffer: privateWitnessBuffer,
            outputTraceBuffer: privateTraceBuffer
        )
        XCTAssertEqual(result.trace, expectedTrace)

        let composition = try AIRCompositionOracleV1.evaluate(
            definition: air,
            trace: result.trace
        )
        XCTAssertTrue(composition.allConstraintsVanish)
    }

    func testResidentAIRTraceSynthesisRejectsNonCanonicalPrivateWitness() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }
        let context = try MetalContext(device: device)
        let witness = try Self.fibonacciWitness()
        var witnessBytes = try AIRTraceResidentSynthesisOracleV1.packColumnMajorWitness(witness)
        witnessBytes.replaceSubrange(0..<4, with: [
            UInt8(M31Field.modulus & 0xff),
            UInt8((M31Field.modulus >> 8) & 0xff),
            UInt8((M31Field.modulus >> 16) & 0xff),
            UInt8((M31Field.modulus >> 24) & 0xff),
        ])
        let privateWitnessBuffer = try Self.makePrivateBuffer(
            context: context,
            bytes: witnessBytes,
            label: "ApplicationTheoremTests.NonCanonicalResidentAIRTraceWitness"
        )
        let privateTraceBuffer = try MetalBufferFactory.makePrivateBuffer(
            device: device,
            length: witnessBytes.count,
            label: "ApplicationTheoremTests.NonCanonicalResidentAIRTraceOutput"
        )
        let plan = try AIRTraceResidentSynthesisPlanV1(
            context: context,
            rowCount: witness.rowCount,
            columnCount: witness.columnCount
        )

        XCTAssertThrowsError(
            try plan.executeResident(
                witnessColumnMajorBuffer: privateWitnessBuffer,
                outputTraceBuffer: privateTraceBuffer
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }
#endif

    func testAIRProofV1BuildsComposesEncodesAndRejectsTampering() throws {
        let witness = try Self.fibonacciWitness()
        let air = try Self.fibonacciAIRDefinition()
        let built = try AIRProofBuilderV1.prove(witness: witness, airDefinition: air)
        let statement = built.statement
        let proof = built.proof
        let trace = try WitnessToAIRTraceProducerV1.produce(witness: witness, for: air)
        let expectedComposition = try AIRCompositionOracleV1.evaluate(
            definition: air,
            trace: trace
        )

        XCTAssertEqual(statement.airDefinitionDigest, try AIRDefinitionDigestV1.digest(air))
        XCTAssertEqual(statement.witnessTraceDigest, try ApplicationWitnessDigestV1.digest(witness))
        XCTAssertEqual(statement.traceRowCount, witness.rowCount)
        XCTAssertEqual(statement.traceColumnCount, witness.columnCount)
        XCTAssertEqual(
            statement.compositionEvaluationDigest,
            try AIRCompositionEvaluationDigestV1.digest(proof.composition)
        )
        XCTAssertEqual(
            statement.publicQuotientProofDigest,
            try AIRPublicQuotientProofDigestV1.digest(proof.publicQuotientProof)
        )
        XCTAssertEqual(proof.statementDigest, try statement.digest())
        XCTAssertEqual(proof.composition, expectedComposition)
        XCTAssertEqual(proof.composition.compositionWeights.count, 5)
        XCTAssertTrue(proof.composition.compositionWeights.allSatisfy { $0 != 0 })
        XCTAssertTrue(proof.composition.allConstraintsVanish)
        XCTAssertEqual(proof.publicQuotientProof.traceRowCount, witness.rowCount)
        XCTAssertEqual(proof.publicQuotientProof.traceColumnCount, witness.columnCount)
        XCTAssertEqual(proof.publicQuotientProof.quotientPolynomials.count, 5)
        XCTAssertTrue(try AIRPublicQuotientOracleV1.verify(
            proof.publicQuotientProof,
            definition: air,
            trace: trace
        ))

        let report = try AIRProofVerifierV1.verificationReport(proof: proof, statement: statement)
        XCTAssertTrue(report.statementDigestMatches)
        XCTAssertTrue(report.airDefinitionDigestMatches)
        XCTAssertTrue(report.witnessTraceDigestMatches)
        XCTAssertTrue(report.witnessToAIRTraceProduced)
        XCTAssertTrue(report.compositionEvaluationDigestMatches)
        XCTAssertTrue(report.compositionMatchesTrace)
        XCTAssertTrue(report.compositionVanishes)
        XCTAssertTrue(report.publicQuotientProofDigestMatches)
        XCTAssertTrue(report.publicQuotientProofVerified)
        XCTAssertTrue(report.airSemanticsVerified)
        XCTAssertTrue(report.verifies(.publicRevealedTraceConstraintEvaluation))
        XCTAssertFalse(report.verifies(.succinctPrivateAIR))
        XCTAssertFalse(report.isSuccinct)
        XCTAssertFalse(report.isZeroKnowledge)
        XCTAssertTrue(try AIRProofVerifierV1.verify(proof: proof, statement: statement))

        let encodedStatement = try AIRProofStatementCodecV1.encode(statement)
        XCTAssertEqual(try AIRProofStatementCodecV1.decode(encodedStatement), statement)
        let encodedComposition = try AIRCompositionEvaluationCodecV1.encode(proof.composition)
        XCTAssertEqual(
            try AIRCompositionEvaluationCodecV1.decode(encodedComposition),
            proof.composition
        )
        let encodedQuotientProof = try AIRPublicQuotientProofCodecV1.encode(proof.publicQuotientProof)
        XCTAssertEqual(
            try AIRPublicQuotientProofCodecV1.decode(encodedQuotientProof),
            proof.publicQuotientProof
        )
        let encodedProof = try AIRProofCodecV1.encode(proof)
        XCTAssertEqual(try AIRProofCodecV1.decode(encodedProof), proof)
        XCTAssertEqual(
            try AIRProofVerifierV1.verificationReport(
                encodedProof: encodedProof,
                statement: statement
            ),
            report
        )
        XCTAssertTrue(try AIRProofVerifierV1.verify(encodedProof: encodedProof, statement: statement))

        var trailingProof = encodedProof
        trailingProof.append(0)
        XCTAssertThrowsError(try AIRProofCodecV1.decode(trailingProof))
        var trailingStatement = encodedStatement
        trailingStatement.append(0)
        XCTAssertThrowsError(try AIRProofStatementCodecV1.decode(trailingStatement))
        var trailingComposition = encodedComposition
        trailingComposition.append(0)
        XCTAssertThrowsError(try AIRCompositionEvaluationCodecV1.decode(trailingComposition))
        var trailingQuotientProof = encodedQuotientProof
        trailingQuotientProof.append(0)
        XCTAssertThrowsError(try AIRPublicQuotientProofCodecV1.decode(trailingQuotientProof))

        let invalidWitness = try ApplicationWitnessTraceV1(columns: [
            [1, 1, 2, 4],
            [1, 2, 3, 5],
        ])
        XCTAssertThrowsError(try AIRProofBuilderV1.prove(
            witness: invalidWitness,
            airDefinition: air
        ))
        let invalidWitnessProof = try AIRProofV1(
            statementDigest: proof.statementDigest,
            airDefinition: air,
            witness: invalidWitness,
            composition: proof.composition,
            publicQuotientProof: proof.publicQuotientProof
        )
        let invalidWitnessReport = try AIRProofVerifierV1.verificationReport(
            proof: invalidWitnessProof,
            statement: statement
        )
        XCTAssertFalse(invalidWitnessReport.witnessTraceDigestMatches)
        XCTAssertFalse(invalidWitnessReport.compositionMatchesTrace)
        XCTAssertFalse(invalidWitnessReport.publicQuotientProofVerified)
        XCTAssertFalse(invalidWitnessReport.airSemanticsVerified)
        XCTAssertFalse(invalidWitnessReport.verifies(.publicRevealedTraceConstraintEvaluation))

        var tamperedCombined = proof.composition.combinedEvaluations
        tamperedCombined[0] = 1
        let tamperedComposition = try AIRCompositionEvaluationV1(
            traceRowCount: proof.composition.traceRowCount,
            traceColumnCount: proof.composition.traceColumnCount,
            transitionConstraintCount: proof.composition.transitionConstraintCount,
            boundaryConstraintCount: proof.composition.boundaryConstraintCount,
            compositionWeights: proof.composition.compositionWeights,
            rawEvaluationDigest: proof.composition.rawEvaluationDigest,
            combinedEvaluations: tamperedCombined
        )
        let tamperedProof = try AIRProofV1(
            statementDigest: proof.statementDigest,
            airDefinition: air,
            witness: witness,
            composition: tamperedComposition,
            publicQuotientProof: proof.publicQuotientProof
        )
        let tamperedReport = try AIRProofVerifierV1.verificationReport(
            proof: tamperedProof,
            statement: statement
        )
        XCTAssertFalse(tamperedReport.compositionEvaluationDigestMatches)
        XCTAssertFalse(tamperedReport.compositionMatchesTrace)
        XCTAssertFalse(tamperedReport.compositionVanishes)
        XCTAssertFalse(tamperedReport.verifies(.publicRevealedTraceConstraintEvaluation))

        var tamperedQuotientDigest = proof.publicQuotientProof.tracePolynomialDigest
        tamperedQuotientDigest[0] ^= 0xff
        let tamperedQuotientProof = try AIRPublicQuotientProofV1(
            traceRowCount: proof.publicQuotientProof.traceRowCount,
            traceColumnCount: proof.publicQuotientProof.traceColumnCount,
            tracePolynomialDigest: tamperedQuotientDigest,
            quotientPolynomials: proof.publicQuotientProof.quotientPolynomials
        )
        let tamperedQuotientAIRProof = try AIRProofV1(
            statementDigest: proof.statementDigest,
            airDefinition: air,
            witness: witness,
            composition: proof.composition,
            publicQuotientProof: tamperedQuotientProof
        )
        let tamperedQuotientReport = try AIRProofVerifierV1.verificationReport(
            proof: tamperedQuotientAIRProof,
            statement: statement
        )
        XCTAssertFalse(tamperedQuotientReport.publicQuotientProofDigestMatches)
        XCTAssertFalse(tamperedQuotientReport.publicQuotientProofVerified)
        XCTAssertFalse(tamperedQuotientReport.verifies(.publicRevealedTraceConstraintEvaluation))
    }

    func testAIRProofQuotientPCSArtifactBuildsEncodesAndRejectsMismatchedBundle() throws {
        let witness = try Self.fibonacciWitness()
        let air = try Self.fibonacciAIRDefinition()
        let domain = try CircleDomainDescriptor.canonical(logSize: 6)
        let parameterSet = try Self.smallPCSParameterSet()
        let artifact = try AIRProofQuotientPCSArtifactBuilderV1.prove(
            witness: witness,
            airDefinition: air,
            domain: domain,
            parameterSet: parameterSet,
            quotientClaimStorageIndices: [5, 0]
        )

        XCTAssertEqual(artifact.quotientPCSProofBundle.witness.domain, domain)
        XCTAssertEqual(artifact.quotientPCSProofBundle.parameterSet, parameterSet)
        XCTAssertEqual(artifact.quotientPCSProofBundle.witness.claimedStorageIndices, [0, 5])
        XCTAssertEqual(artifact.quotientPCSProofBundle.witness.quotientPolynomialCount, 5)
        XCTAssertEqual(artifact.quotientPCSProofBundle.chunks.count, 2)
        XCTAssertEqual(artifact.quotientPCSProofBundle.chunks[0].sourceQuotientIndices, [0, 1, 2, 3])
        XCTAssertEqual(artifact.quotientPCSProofBundle.chunks[1].sourceQuotientIndices, [4])
        XCTAssertEqual(
            artifact.quotientPCSProofBundle.witness.quotientProofDigest,
            try AIRPublicQuotientProofDigestV1.digest(artifact.proof.publicQuotientProof)
        )

        let report = try AIRProofQuotientPCSArtifactVerifierV1.verificationReport(artifact)
        XCTAssertTrue(report.airProofReport.verifies(.publicRevealedTraceConstraintEvaluation))
        XCTAssertTrue(report.quotientPCSBundleProofsVerify)
        XCTAssertTrue(report.quotientPCSBundleMatchesAIRProof)
        XCTAssertTrue(report.usesPCSBackedQuotientLowDegreeProof)
        XCTAssertFalse(report.isSuccinctAIRGKRProof)
        XCTAssertFalse(report.isZeroKnowledge)
        XCTAssertTrue(report.verified)
        XCTAssertTrue(try AIRProofQuotientPCSArtifactVerifierV1.verify(artifact))

        let encodedBundle = try AIRQuotientCirclePCSProofBundleCodecV1.encode(
            artifact.quotientPCSProofBundle
        )
        XCTAssertEqual(
            try AIRQuotientCirclePCSProofBundleCodecV1.decode(encodedBundle),
            artifact.quotientPCSProofBundle
        )
        let encodedArtifact = try AIRProofQuotientPCSArtifactCodecV1.encode(artifact)
        XCTAssertEqual(try AIRProofQuotientPCSArtifactCodecV1.decode(encodedArtifact), artifact)
        XCTAssertTrue(try AIRProofQuotientPCSArtifactVerifierV1.verify(
            encodedArtifact: encodedArtifact
        ))
        XCTAssertEqual(try AIRQuotientCirclePCSProofBundleDigestV1.digest(
            artifact.quotientPCSProofBundle
        ).count, 32)
        XCTAssertEqual(try AIRProofQuotientPCSArtifactDigestV1.digest(artifact).count, 32)

        var trailingBundle = encodedBundle
        trailingBundle.append(0)
        XCTAssertThrowsError(try AIRQuotientCirclePCSProofBundleCodecV1.decode(trailingBundle))
        var trailingArtifact = encodedArtifact
        trailingArtifact.append(0)
        XCTAssertThrowsError(try AIRProofQuotientPCSArtifactCodecV1.decode(trailingArtifact))

        var tamperedQuotientDigest = artifact.proof.publicQuotientProof.tracePolynomialDigest
        tamperedQuotientDigest[0] ^= 0x7f
        let mismatchedQuotientProof = try AIRPublicQuotientProofV1(
            traceRowCount: artifact.proof.publicQuotientProof.traceRowCount,
            traceColumnCount: artifact.proof.publicQuotientProof.traceColumnCount,
            tracePolynomialDigest: tamperedQuotientDigest,
            quotientPolynomials: artifact.proof.publicQuotientProof.quotientPolynomials
        )
        let mismatchedBundle = try AIRQuotientCirclePCSProofBundleBuilderV1.prove(
            quotientProof: mismatchedQuotientProof,
            domain: domain,
            parameterSet: parameterSet,
            claimStorageIndices: [0, 5]
        )
        let mismatchedArtifact = try AIRProofQuotientPCSArtifactV1(
            statement: artifact.statement,
            proof: artifact.proof,
            quotientPCSProofBundle: mismatchedBundle
        )
        let mismatchedReport = try AIRProofQuotientPCSArtifactVerifierV1.verificationReport(
            mismatchedArtifact
        )
        XCTAssertTrue(mismatchedReport.airProofReport.verifies(.publicRevealedTraceConstraintEvaluation))
        XCTAssertTrue(mismatchedReport.quotientPCSBundleProofsVerify)
        XCTAssertFalse(mismatchedReport.quotientPCSBundleMatchesAIRProof)
        XCTAssertFalse(mismatchedReport.verified)
        XCTAssertFalse(try AIRProofQuotientPCSArtifactVerifierV1.verify(mismatchedArtifact))
    }

    func testAIRTraceCirclePCSBridgeInterpolatesArbitraryTraceColumns() throws {
        let layout = try ApplicationWitnessLayoutV1(columns: [
            try ApplicationWitnessColumnV1(name: "a", values: [1, 2, 4, 8]),
            try ApplicationWitnessColumnV1(name: "b", values: [3, 5, 7, 11]),
            try ApplicationWitnessColumnV1(name: "c", values: [13, 17, 19, 23]),
            try ApplicationWitnessColumnV1(name: "d", values: [29, 31, 37, 41]),
            try ApplicationWitnessColumnV1(name: "e", values: [43, 47, 53, 59]),
        ])
        let witness = try layout.trace(columnOrder: ["a", "b", "c", "d", "e"])
        let trace = try WitnessToAIRTraceProducerV1.produce(witness: witness)
        let domain = try CircleDomainDescriptor.canonical(logSize: 4)

        let pcsWitness = try AIRTraceToCirclePCSWitnessV1.make(
            trace: trace,
            domain: domain,
            claimRowIndices: [3, 0]
        )

        XCTAssertEqual(pcsWitness.rowCount, 4)
        XCTAssertEqual(pcsWitness.columnCount, 5)
        XCTAssertEqual(pcsWitness.rowStorageIndices, [0, 8, 4, 12])
        XCTAssertEqual(pcsWitness.claimedRowIndices, [0, 3])
        XCTAssertEqual(pcsWitness.chunks.count, 2)
        XCTAssertEqual(pcsWitness.polynomialClaims.count, 2)
        XCTAssertEqual(pcsWitness.chunks[0].sourceColumnIndices, [0, 1, 2, 3])
        XCTAssertEqual(pcsWitness.chunks[1].sourceColumnIndices, [4])
        XCTAssertEqual(pcsWitness.chunks[0].polynomial, pcsWitness.chunks[0].polynomialClaim.polynomial)
        XCTAssertEqual(pcsWitness.chunks[1].polynomial, pcsWitness.chunks[1].polynomialClaim.polynomial)

        for row in 0..<trace.rowCount {
            let point = try CircleDomainOracle.point(in: domain, naturalDomainIndex: row)
            XCTAssertEqual(
                try CircleCodewordOracle.evaluate(
                    polynomial: pcsWitness.chunks[0].polynomial,
                    at: point
                ),
                try Self.packedTraceValue(trace: trace, row: row, firstColumn: 0)
            )
            XCTAssertEqual(
                try CircleCodewordOracle.evaluate(
                    polynomial: pcsWitness.chunks[1].polynomial,
                    at: point
                ),
                try Self.packedTraceValue(trace: trace, row: row, firstColumn: 4)
            )
        }

        let firstChunkClaims = Dictionary(
            uniqueKeysWithValues: pcsWitness.chunks[0].polynomialClaim.evaluationClaims.map {
                (Int($0.storageIndex), $0.value)
            }
        )
        XCTAssertEqual(firstChunkClaims.count, 2)
        XCTAssertEqual(
            firstChunkClaims[pcsWitness.rowStorageIndices[0]],
            try Self.packedTraceValue(trace: trace, row: 0, firstColumn: 0)
        )
        XCTAssertEqual(
            firstChunkClaims[pcsWitness.rowStorageIndices[3]],
            try Self.packedTraceValue(trace: trace, row: 3, firstColumn: 0)
        )

        XCTAssertThrowsError(try AIRTraceToCirclePCSWitnessV1.make(
            trace: trace,
            domain: domain,
            claimRowIndices: [0, 0]
        ))
        XCTAssertThrowsError(try AIRTraceToCirclePCSWitnessV1.make(
            trace: trace,
            domain: CircleDomainDescriptor.canonical(logSize: 2)
        ))
    }

    func testAIRTraceCircleFFTBasisWitnessCoversArbitraryTraceLayouts() throws {
        let layout = try ApplicationWitnessLayoutV1(columns: [
            try ApplicationWitnessColumnV1(name: "a", values: [1, 2, 4, 8]),
            try ApplicationWitnessColumnV1(name: "b", values: [3, 5, 7, 11]),
            try ApplicationWitnessColumnV1(name: "c", values: [13, 17, 19, 23]),
            try ApplicationWitnessColumnV1(name: "d", values: [29, 31, 37, 41]),
            try ApplicationWitnessColumnV1(name: "e", values: [43, 47, 53, 59]),
        ])
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: layout.trace(columnOrder: ["a", "b", "c", "d", "e"])
        )
        let domain = try CircleDomainDescriptor.canonical(logSize: 4)
        let pcsWitness = try AIRTraceToCirclePCSWitnessV1.make(
            trace: trace,
            domain: domain,
            claimRowIndices: [0, 3]
        )

        let fftBasisWitness = try AIRTraceToCircleFFTBasisWitnessV1.make(
            pcsWitness: pcsWitness
        )

        XCTAssertEqual(fftBasisWitness.domain, pcsWitness.domain)
        XCTAssertEqual(fftBasisWitness.rowCount, pcsWitness.rowCount)
        XCTAssertEqual(fftBasisWitness.columnCount, pcsWitness.columnCount)
        XCTAssertEqual(fftBasisWitness.rowStorageIndices, pcsWitness.rowStorageIndices)
        XCTAssertEqual(fftBasisWitness.claimedRowIndices, pcsWitness.claimedRowIndices)
        XCTAssertEqual(fftBasisWitness.polynomialClaims, pcsWitness.polynomialClaims)
        XCTAssertEqual(fftBasisWitness.chunks.count, 2)
        XCTAssertEqual(fftBasisWitness.chunks[0].sourceColumnIndices, [0, 1, 2, 3])
        XCTAssertEqual(fftBasisWitness.chunks[1].sourceColumnIndices, [4])
        XCTAssertTrue(fftBasisWitness.usesPublicTraceRows)
        XCTAssertFalse(fftBasisWitness.isResidentPrivateWitness)
        XCTAssertFalse(fftBasisWitness.verifiesAIRSemantics)
        XCTAssertFalse(fftBasisWitness.isZeroKnowledge)

        for chunk in fftBasisWitness.chunks {
            XCTAssertEqual(chunk.circleFFTBasisCoefficients.count, domain.size)
            XCTAssertEqual(
                chunk.circleFFTBasisCoefficients,
                try CircleCodewordOracle.circleFFTCoefficients(
                    polynomial: chunk.polynomial,
                    domain: domain
                )
            )
            XCTAssertEqual(
                try CircleCodewordOracle.evaluateWithCircleFFT(
                    polynomial: chunk.polynomial,
                    domain: domain
                ),
                try CircleCodewordOracle.evaluate(
                    polynomial: chunk.polynomial,
                    domain: domain
                )
            )
        }

        var corruptedBasis = fftBasisWitness.chunks[0].circleFFTBasisCoefficients
        corruptedBasis[0] = QM31Field.add(
            corruptedBasis[0],
            QM31Element(a: 1, b: 0, c: 0, d: 0)
        )
        XCTAssertThrowsError(try AIRTraceCircleFFTBasisChunkV1(
            chunkIndex: fftBasisWitness.chunks[0].chunkIndex,
            sourceColumnIndices: fftBasisWitness.chunks[0].sourceColumnIndices,
            polynomial: fftBasisWitness.chunks[0].polynomial,
            polynomialClaim: fftBasisWitness.chunks[0].polynomialClaim,
            circleFFTBasisCoefficients: corruptedBasis
        ))
        XCTAssertThrowsError(try AIRTraceCircleFFTBasisWitnessV1(
            domain: fftBasisWitness.domain,
            rowCount: fftBasisWitness.rowCount,
            columnCount: fftBasisWitness.columnCount,
            rowStorageIndices: fftBasisWitness.rowStorageIndices,
            claimedRowIndices: fftBasisWitness.claimedRowIndices,
            chunks: fftBasisWitness.chunks,
            isResidentPrivateWitness: true
        ))
    }

    func testAIRTraceCirclePCSProofBundleProvesAllChunksAndBindsTrace() throws {
        let layout = try ApplicationWitnessLayoutV1(columns: [
            try ApplicationWitnessColumnV1(name: "a", values: [1, 2, 4, 8]),
            try ApplicationWitnessColumnV1(name: "b", values: [3, 5, 7, 11]),
            try ApplicationWitnessColumnV1(name: "c", values: [13, 17, 19, 23]),
            try ApplicationWitnessColumnV1(name: "d", values: [29, 31, 37, 41]),
            try ApplicationWitnessColumnV1(name: "e", values: [43, 47, 53, 59]),
        ])
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: layout.trace(columnOrder: ["a", "b", "c", "d", "e"])
        )
        let domain = try CircleDomainDescriptor.canonical(logSize: 6)
        let parameterSet = try Self.smallPCSParameterSet()

        let bundle = try AIRTraceCirclePCSProofBundleBuilderV1.prove(
            trace: trace,
            domain: domain,
            parameterSet: parameterSet,
            claimRowIndices: [3, 0]
        )

        XCTAssertEqual(bundle.parameterSet, parameterSet)
        XCTAssertEqual(bundle.witness.rowCount, 4)
        XCTAssertEqual(bundle.witness.columnCount, 5)
        XCTAssertEqual(bundle.witness.claimedRowIndices, [0, 3])
        XCTAssertEqual(bundle.chunks.count, 2)
        XCTAssertEqual(bundle.statements.count, 2)
        XCTAssertEqual(bundle.proofs.count, 2)
        XCTAssertEqual(bundle.chunks[0].sourceColumnIndices, [0, 1, 2, 3])
        XCTAssertEqual(bundle.chunks[1].sourceColumnIndices, [4])
        XCTAssertTrue(try AIRTraceCirclePCSProofBundleVerifierV1.verify(bundle))
        XCTAssertTrue(try AIRTraceCirclePCSProofBundleVerifierV1.verify(bundle, against: trace))

        let encodedBundle = try AIRTraceCirclePCSProofBundleCodecV1.encode(bundle)
        let decodedBundle = try AIRTraceCirclePCSProofBundleCodecV1.decode(encodedBundle)
        XCTAssertEqual(decodedBundle, bundle)
        XCTAssertEqual(
            try AIRTraceCirclePCSProofBundleDigestV1.digest(decodedBundle),
            try AIRTraceCirclePCSProofBundleDigestV1.digest(bundle)
        )
        XCTAssertTrue(try AIRTraceCirclePCSProofBundleVerifierV1.verify(encodedBundle: encodedBundle))
        XCTAssertTrue(try AIRTraceCirclePCSProofBundleVerifierV1.verify(
            encodedBundle: encodedBundle,
            against: trace
        ))

        let alteredTrace = try WitnessToAIRTraceProducerV1.produce(witness: ApplicationWitnessTraceV1(columns: [
            [1, 2, 4, 9],
            [3, 5, 7, 11],
            [13, 17, 19, 23],
            [29, 31, 37, 41],
            [43, 47, 53, 59],
        ]))
        XCTAssertFalse(try AIRTraceCirclePCSProofBundleVerifierV1.verify(bundle, against: alteredTrace))
        XCTAssertFalse(try AIRTraceCirclePCSProofBundleVerifierV1.verify(
            encodedBundle: encodedBundle,
            against: alteredTrace
        ))

        var trailingByteBundle = encodedBundle
        trailingByteBundle.append(0)
        XCTAssertThrowsError(try AIRTraceCirclePCSProofBundleCodecV1.decode(trailingByteBundle))

        XCTAssertThrowsError(try AIRTraceCirclePCSProofBundleV1(
            witness: bundle.witness,
            parameterSet: parameterSet,
            chunks: Array(bundle.chunks.reversed())
        ))
    }

    func testAIRTracePCSOpeningConstraintVerifierChecksOpenedRowsAndCoverage() throws {
        let air = try Self.fibonacciAIRDefinition()
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: Self.fibonacciWitness(),
            for: air
        )
        let domain = try CircleDomainDescriptor.canonical(logSize: 6)
        let parameterSet = try Self.smallPCSParameterSet()

        let fullBundle = try AIRTraceCirclePCSProofBundleBuilderV1.prove(
            trace: trace,
            domain: domain,
            parameterSet: parameterSet
        )
        let fullReport = try AIRTracePCSOpeningConstraintVerifierV1.verificationReport(
            bundle: fullBundle,
            definition: air
        )
        XCTAssertTrue(fullReport.tracePCSBundleProofsVerify)
        XCTAssertTrue(fullReport.traceShapeMatchesAIR)
        XCTAssertEqual(fullReport.openedTransitionRows, [0, 1, 2])
        XCTAssertEqual(fullReport.openedBoundaryRows, [0, 3])
        XCTAssertTrue(fullReport.transitionOpeningCoverageComplete)
        XCTAssertTrue(fullReport.boundaryOpeningCoverageComplete)
        XCTAssertTrue(fullReport.transitionOpeningsSatisfyAIR)
        XCTAssertTrue(fullReport.boundaryOpeningsSatisfyAIR)
        XCTAssertTrue(fullReport.openedConstraintsVerified)
        XCTAssertTrue(fullReport.allAIRConstraintsCoveredAndVerified)
        XCTAssertFalse(fullReport.isZeroKnowledge)
        XCTAssertTrue(try AIRTracePCSOpeningConstraintVerifierV1.verifyOpenedConstraints(
            bundle: fullBundle,
            definition: air
        ))
        XCTAssertTrue(try AIRTracePCSOpeningConstraintVerifierV1.verifyAllAIRConstraintsFromOpenings(
            bundle: fullBundle,
            definition: air
        ))

        let encodedFullBundle = try AIRTraceCirclePCSProofBundleCodecV1.encode(fullBundle)
        XCTAssertEqual(
            try AIRTracePCSOpeningConstraintVerifierV1.verificationReport(
                encodedBundle: encodedFullBundle,
                definition: air
            ),
            fullReport
        )

        let partialBundle = try AIRTraceCirclePCSProofBundleBuilderV1.prove(
            trace: trace,
            domain: domain,
            parameterSet: parameterSet,
            claimRowIndices: [1, 0]
        )
        let partialReport = try AIRTracePCSOpeningConstraintVerifierV1.verificationReport(
            bundle: partialBundle,
            definition: air
        )
        XCTAssertTrue(partialReport.tracePCSBundleProofsVerify)
        XCTAssertTrue(partialReport.traceShapeMatchesAIR)
        XCTAssertEqual(partialReport.openedTransitionRows, [0])
        XCTAssertEqual(partialReport.openedBoundaryRows, [0])
        XCTAssertFalse(partialReport.transitionOpeningCoverageComplete)
        XCTAssertFalse(partialReport.boundaryOpeningCoverageComplete)
        XCTAssertTrue(partialReport.transitionOpeningsSatisfyAIR)
        XCTAssertTrue(partialReport.boundaryOpeningsSatisfyAIR)
        XCTAssertTrue(partialReport.openedConstraintsVerified)
        XCTAssertFalse(partialReport.allAIRConstraintsCoveredAndVerified)
        XCTAssertTrue(try AIRTracePCSOpeningConstraintVerifierV1.verifyOpenedConstraints(
            bundle: partialBundle,
            definition: air
        ))
        XCTAssertFalse(try AIRTracePCSOpeningConstraintVerifierV1.verifyAllAIRConstraintsFromOpenings(
            bundle: partialBundle,
            definition: air
        ))

        let invalidTransitionTrace = try WitnessToAIRTraceProducerV1.produce(
            witness: ApplicationWitnessTraceV1(columns: [
                [1, 1, 2, 4],
                [1, 2, 3, 5],
            ]),
            for: air
        )
        let invalidTransitionBundle = try AIRTraceCirclePCSProofBundleBuilderV1.prove(
            trace: invalidTransitionTrace,
            domain: domain,
            parameterSet: parameterSet
        )
        let invalidTransitionReport = try AIRTracePCSOpeningConstraintVerifierV1.verificationReport(
            bundle: invalidTransitionBundle,
            definition: air
        )
        XCTAssertTrue(invalidTransitionReport.tracePCSBundleProofsVerify)
        XCTAssertTrue(invalidTransitionReport.traceShapeMatchesAIR)
        XCTAssertFalse(invalidTransitionReport.transitionOpeningsSatisfyAIR)
        XCTAssertTrue(invalidTransitionReport.boundaryOpeningsSatisfyAIR)
        XCTAssertFalse(invalidTransitionReport.openedConstraintsVerified)
        XCTAssertFalse(invalidTransitionReport.allAIRConstraintsCoveredAndVerified)

        let invalidBoundaryTrace = try WitnessToAIRTraceProducerV1.produce(
            witness: ApplicationWitnessTraceV1(columns: [
                [2, 2, 4, 6],
                [2, 4, 6, 10],
            ]),
            for: air
        )
        let invalidBoundaryBundle = try AIRTraceCirclePCSProofBundleBuilderV1.prove(
            trace: invalidBoundaryTrace,
            domain: domain,
            parameterSet: parameterSet
        )
        let invalidBoundaryReport = try AIRTracePCSOpeningConstraintVerifierV1.verificationReport(
            bundle: invalidBoundaryBundle,
            definition: air
        )
        XCTAssertTrue(invalidBoundaryReport.tracePCSBundleProofsVerify)
        XCTAssertTrue(invalidBoundaryReport.traceShapeMatchesAIR)
        XCTAssertTrue(invalidBoundaryReport.transitionOpeningsSatisfyAIR)
        XCTAssertFalse(invalidBoundaryReport.boundaryOpeningsSatisfyAIR)
        XCTAssertFalse(invalidBoundaryReport.openedConstraintsVerified)
        XCTAssertFalse(invalidBoundaryReport.allAIRConstraintsCoveredAndVerified)

        let wrongShapeAIR = try AIRDefinitionV1(
            columnCount: 3,
            transitionConstraints: air.transitionConstraints,
            boundaryConstraints: air.boundaryConstraints
        )
        let wrongShapeReport = try AIRTracePCSOpeningConstraintVerifierV1.verificationReport(
            bundle: fullBundle,
            definition: wrongShapeAIR
        )
        XCTAssertTrue(wrongShapeReport.tracePCSBundleProofsVerify)
        XCTAssertFalse(wrongShapeReport.traceShapeMatchesAIR)
        XCTAssertFalse(wrongShapeReport.openedConstraintsVerified)
        XCTAssertFalse(wrongShapeReport.allAIRConstraintsCoveredAndVerified)
    }

    func testAIRTracePCSQueriedOpeningBundleDerivesRowsFromInitialCommitments() throws {
        let air = try Self.fibonacciAIRDefinition()
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: Self.fibonacciWitness(),
            for: air
        )
        let domain = try CircleDomainDescriptor.canonical(logSize: 6)
        let parameterSet = try Self.smallPCSParameterSet()

        let queriedBundle = try AIRTracePCSQueriedOpeningBundleBuilderV1.prove(
            trace: trace,
            definition: air,
            domain: domain,
            parameterSet: parameterSet,
            transitionQueryCount: 1
        )
        let report = try AIRTracePCSQueriedOpeningBundleVerifierV1.verificationReport(
            queriedBundle,
            definition: air
        )

        XCTAssertTrue(report.verified)
        XCTAssertTrue(report.openingConstraintReport.tracePCSBundleProofsVerify)
        XCTAssertTrue(report.openingConstraintReport.openedConstraintsVerified)
        XCTAssertTrue(report.queryPlanMatchesCommitments)
        XCTAssertTrue(report.bundleClaimsExactlyQueryRows)
        XCTAssertFalse(report.isZeroKnowledge)
        XCTAssertEqual(
            queriedBundle.tracePCSProofBundle.witness.claimedRowIndices,
            queriedBundle.queryPlan.requiredTraceRows
        )
        XCTAssertEqual(queriedBundle.queryPlan.transitionQueryCount, 1)
        XCTAssertEqual(queriedBundle.queryPlan.sampledTransitionRows.count, 1)
        XCTAssertEqual(
            queriedBundle.queryPlan.airDefinitionDigest,
            try AIRDefinitionDigestV1.digest(air)
        )
        XCTAssertEqual(
            queriedBundle.queryPlan.initialTraceCommitmentDigest,
            try AIRTracePCSOpeningQueryPlannerV1.initialTraceCommitmentDigest(
                bundle: queriedBundle.tracePCSProofBundle
            )
        )
        XCTAssertEqual(
            queriedBundle.queryPlan,
            try AIRTracePCSOpeningQueryPlannerV1.make(
                definition: air,
                bundle: queriedBundle.tracePCSProofBundle,
                transitionQueryCount: 1
            )
        )
        XCTAssertTrue(try AIRTracePCSQueriedOpeningBundleVerifierV1.verify(
            queriedBundle,
            definition: air
        ))

        var tamperedInitialDigest = queriedBundle.queryPlan.initialTraceCommitmentDigest
        tamperedInitialDigest[0] ^= 0xff
        let tamperedQueryPlan = try AIRTracePCSOpeningQueryPlanV1(
            traceRowCount: queriedBundle.queryPlan.traceRowCount,
            traceColumnCount: queriedBundle.queryPlan.traceColumnCount,
            transitionQueryCount: queriedBundle.queryPlan.transitionQueryCount,
            airDefinitionDigest: queriedBundle.queryPlan.airDefinitionDigest,
            initialTraceCommitmentDigest: tamperedInitialDigest,
            sampledTransitionRows: queriedBundle.queryPlan.sampledTransitionRows,
            boundaryRows: queriedBundle.queryPlan.boundaryRows,
            requiredTraceRows: queriedBundle.queryPlan.requiredTraceRows
        )
        let wrongPlanBundle = try AIRTracePCSQueriedOpeningBundleV1(
            queryPlan: tamperedQueryPlan,
            tracePCSProofBundle: queriedBundle.tracePCSProofBundle
        )
        let wrongPlanReport = try AIRTracePCSQueriedOpeningBundleVerifierV1.verificationReport(
            wrongPlanBundle,
            definition: air
        )
        XCTAssertFalse(wrongPlanReport.queryPlanMatchesCommitments)
        XCTAssertFalse(wrongPlanReport.verified)

        let allRowsQueryPlan = try AIRTracePCSOpeningQueryPlannerV1.make(
            definition: air,
            trace: trace,
            domain: domain,
            parameterSet: parameterSet,
            transitionQueryCount: 3
        )
        XCTAssertEqual(allRowsQueryPlan.requiredTraceRows, [0, 1, 2, 3])
        let manuallyClaimedBundle = try AIRTraceCirclePCSProofBundleBuilderV1.prove(
            trace: trace,
            domain: domain,
            parameterSet: parameterSet,
            claimRowIndices: [0, 3]
        )
        let wrongRowsBundle = try AIRTracePCSQueriedOpeningBundleV1(
            queryPlan: allRowsQueryPlan,
            tracePCSProofBundle: manuallyClaimedBundle
        )
        let wrongRowsReport = try AIRTracePCSQueriedOpeningBundleVerifierV1.verificationReport(
            wrongRowsBundle,
            definition: air
        )
        XCTAssertTrue(wrongRowsReport.queryPlanMatchesCommitments)
        XCTAssertFalse(wrongRowsReport.bundleClaimsExactlyQueryRows)
        XCTAssertFalse(wrongRowsReport.verified)

        let invalidTransitionTrace = try WitnessToAIRTraceProducerV1.produce(
            witness: ApplicationWitnessTraceV1(columns: [
                [1, 1, 2, 4],
                [1, 2, 3, 5],
            ]),
            for: air
        )
        XCTAssertThrowsError(try AIRTracePCSQueriedOpeningBundleBuilderV1.prove(
            trace: invalidTransitionTrace,
            definition: air,
            domain: domain,
            parameterSet: parameterSet,
            transitionQueryCount: 3
        ))
    }

    func testAIRTraceQuotientPCSQueryAlignmentChecksSharedPublicOpeningsOnly() throws {
        let witness = try Self.fibonacciWitness()
        let air = try Self.fibonacciAIRDefinition()
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: witness,
            for: air
        )
        let domain = try CircleDomainDescriptor.canonical(logSize: 6)
        let parameterSet = try Self.smallPCSParameterSet()
        let traceQueriedBundle = try AIRTracePCSQueriedOpeningBundleBuilderV1.prove(
            trace: trace,
            definition: air,
            domain: domain,
            parameterSet: parameterSet,
            transitionQueryCount: 3
        )
        let airProof = try AIRProofBuilderV1.prove(
            witness: witness,
            airDefinition: air
        )
        let requiredQuotientStorageIndices = try AIRTraceQuotientPCSQueryAlignmentVerifierV1
            .requiredQuotientStorageIndices(traceQueriedOpeningBundle: traceQueriedBundle)
        let quotientBundle = try AIRQuotientCirclePCSProofBundleBuilderV1.prove(
            quotientProof: airProof.proof.publicQuotientProof,
            domain: domain,
            parameterSet: parameterSet,
            claimStorageIndices: requiredQuotientStorageIndices
        )

        XCTAssertEqual(traceQueriedBundle.queryPlan.requiredTraceRows, [0, 1, 2, 3])
        XCTAssertEqual(requiredQuotientStorageIndices, [0, 16, 32, 48])

        let report = try AIRTraceQuotientPCSQueryAlignmentVerifierV1.verificationReport(
            traceQueriedOpeningBundle: traceQueriedBundle,
            quotientPCSProofBundle: quotientBundle,
            quotientProof: airProof.proof.publicQuotientProof,
            definition: air
        )
        XCTAssertTrue(report.traceQueriedOpeningReport.verified)
        XCTAssertTrue(report.quotientPCSBundleProofsVerify)
        XCTAssertTrue(report.quotientPCSBundleMatchesQuotientProof)
        XCTAssertTrue(report.domainsMatch)
        XCTAssertTrue(report.parameterSetsMatch)
        XCTAssertEqual(report.requiredQuotientStorageIndices, requiredQuotientStorageIndices)
        XCTAssertEqual(report.openedQuotientStorageIndices, requiredQuotientStorageIndices)
        XCTAssertTrue(report.quotientOpeningsMatchTraceQueryRows)
        XCTAssertTrue(report.verifiedPublicOpeningAlignment)
        XCTAssertFalse(report.coordinateDomainsAlignedForAIRQuotientIdentity)
        XCTAssertFalse(report.quotientIdentityChecked)
        XCTAssertFalse(report.provesAIRQuotientIdentity)
        XCTAssertFalse(report.isZeroKnowledge)
        XCTAssertTrue(try AIRTraceQuotientPCSQueryAlignmentVerifierV1.verifyPublicOpeningAlignment(
            traceQueriedOpeningBundle: traceQueriedBundle,
            quotientPCSProofBundle: quotientBundle,
            quotientProof: airProof.proof.publicQuotientProof,
            definition: air
        ))

        let underOpenedQuotientBundle = try AIRQuotientCirclePCSProofBundleBuilderV1.prove(
            quotientProof: airProof.proof.publicQuotientProof,
            domain: domain,
            parameterSet: parameterSet,
            claimStorageIndices: [requiredQuotientStorageIndices[0]]
        )
        let underOpenedReport = try AIRTraceQuotientPCSQueryAlignmentVerifierV1.verificationReport(
            traceQueriedOpeningBundle: traceQueriedBundle,
            quotientPCSProofBundle: underOpenedQuotientBundle,
            quotientProof: airProof.proof.publicQuotientProof,
            definition: air
        )
        XCTAssertTrue(underOpenedReport.quotientPCSBundleProofsVerify)
        XCTAssertTrue(underOpenedReport.quotientPCSBundleMatchesQuotientProof)
        XCTAssertFalse(underOpenedReport.quotientOpeningsMatchTraceQueryRows)
        XCTAssertFalse(underOpenedReport.verifiedPublicOpeningAlignment)

        let largerDomain = try CircleDomainDescriptor.canonical(logSize: 7)
        let wrongDomainQuotientBundle = try AIRQuotientCirclePCSProofBundleBuilderV1.prove(
            quotientProof: airProof.proof.publicQuotientProof,
            domain: largerDomain,
            parameterSet: parameterSet,
            claimStorageIndices: requiredQuotientStorageIndices
        )
        let wrongDomainReport = try AIRTraceQuotientPCSQueryAlignmentVerifierV1.verificationReport(
            traceQueriedOpeningBundle: traceQueriedBundle,
            quotientPCSProofBundle: wrongDomainQuotientBundle,
            quotientProof: airProof.proof.publicQuotientProof,
            definition: air
        )
        XCTAssertTrue(wrongDomainReport.quotientPCSBundleProofsVerify)
        XCTAssertTrue(wrongDomainReport.quotientPCSBundleMatchesQuotientProof)
        XCTAssertFalse(wrongDomainReport.domainsMatch)
        XCTAssertTrue(wrongDomainReport.quotientOpeningsMatchTraceQueryRows)
        XCTAssertFalse(wrongDomainReport.verifiedPublicOpeningAlignment)

        var tamperedQuotientDigest = airProof.proof.publicQuotientProof.tracePolynomialDigest
        tamperedQuotientDigest[0] ^= 0xa5
        let tamperedQuotientProof = try AIRPublicQuotientProofV1(
            traceRowCount: airProof.proof.publicQuotientProof.traceRowCount,
            traceColumnCount: airProof.proof.publicQuotientProof.traceColumnCount,
            tracePolynomialDigest: tamperedQuotientDigest,
            quotientPolynomials: airProof.proof.publicQuotientProof.quotientPolynomials
        )
        let mismatchedQuotientBundle = try AIRQuotientCirclePCSProofBundleBuilderV1.prove(
            quotientProof: tamperedQuotientProof,
            domain: domain,
            parameterSet: parameterSet,
            claimStorageIndices: requiredQuotientStorageIndices
        )
        let mismatchedReport = try AIRTraceQuotientPCSQueryAlignmentVerifierV1.verificationReport(
            traceQueriedOpeningBundle: traceQueriedBundle,
            quotientPCSProofBundle: mismatchedQuotientBundle,
            quotientProof: airProof.proof.publicQuotientProof,
            definition: air
        )
        XCTAssertTrue(mismatchedReport.quotientPCSBundleProofsVerify)
        XCTAssertFalse(mismatchedReport.quotientPCSBundleMatchesQuotientProof)
        XCTAssertTrue(mismatchedReport.quotientOpeningsMatchTraceQueryRows)
        XCTAssertFalse(mismatchedReport.verifiedPublicOpeningAlignment)
    }

    func testSharedDomainQuotientIdentityChecksAIREquationFromPCSOpenings() throws {
        let witness = try Self.fibonacciWitness()
        let air = try Self.fibonacciAIRDefinition()
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: witness,
            for: air
        )
        let domain = try CircleDomainDescriptor.canonical(logSize: 6)
        let parameterSet = try Self.smallPCSParameterSet()
        let airProof = try AIRProofBuilderV1.prove(
            witness: witness,
            airDefinition: air
        )

        let identityBundle = try AIRSharedDomainQuotientIdentityPCSProofBundleBuilderV1.prove(
            proof: airProof.proof,
            domain: domain,
            parameterSet: parameterSet,
            queryCount: 2
        )
        let report = try AIRSharedDomainQuotientIdentityPCSProofBundleVerifierV1
            .verificationReport(
                identityBundle,
                definition: air,
                quotientProof: airProof.proof.publicQuotientProof
            )

        XCTAssertEqual(identityBundle.queryPlan.queryCount, 2)
        XCTAssertEqual(identityBundle.queryPlan.traceRowCount, witness.rowCount)
        XCTAssertEqual(identityBundle.queryPlan.traceColumnCount, witness.columnCount)
        XCTAssertEqual(identityBundle.queryPlan.quotientPolynomialCount, 5)
        XCTAssertEqual(
            identityBundle.currentTracePCSProofBundle.witness.claimedStorageIndices,
            identityBundle.queryPlan.claimedStorageIndices
        )
        XCTAssertEqual(
            identityBundle.nextTracePCSProofBundle.witness.claimedStorageIndices,
            identityBundle.queryPlan.claimedStorageIndices
        )
        XCTAssertEqual(
            identityBundle.quotientPCSProofBundle.witness.claimedStorageIndices,
            identityBundle.queryPlan.claimedStorageIndices
        )
        XCTAssertTrue(identityBundle.queryPlan.claimedStorageIndices.allSatisfy { storageIndex in
            guard let naturalIndex = try? CircleDomainOracle.naturalDomainIndex(
                forStorageIndex: storageIndex,
                descriptor: domain
            ),
                  let point = try? CircleDomainOracle.point(
                    in: domain,
                    naturalDomainIndex: naturalIndex
                  ) else {
                return false
            }
            return point.x >= UInt32(witness.rowCount)
        })
        XCTAssertTrue(report.currentTracePCSBundleProofsVerify)
        XCTAssertTrue(report.nextTracePCSBundleProofsVerify)
        XCTAssertTrue(report.quotientPCSBundleProofsVerify)
        XCTAssertTrue(report.currentTraceBundleMatchesQuotientTraceDigest)
        XCTAssertTrue(report.nextTraceBundleMatchesShiftedTrace)
        XCTAssertTrue(report.quotientPCSBundleMatchesQuotientProof)
        XCTAssertTrue(report.queryPlanMatchesCommitments)
        XCTAssertTrue(report.bundlesOpenExactlyQueryPoints)
        XCTAssertTrue(report.domainsMatch)
        XCTAssertTrue(report.parameterSetsMatch)
        XCTAssertTrue(report.coordinateDomainsAlignedForAIRQuotientIdentity)
        XCTAssertTrue(report.quotientIdentityChecked)
        XCTAssertTrue(report.verifiesPCSOpeningInputs)
        XCTAssertTrue(report.provesAIRQuotientIdentity)
        XCTAssertFalse(report.isZeroKnowledge)
        XCTAssertTrue(try AIRSharedDomainQuotientIdentityPCSProofBundleVerifierV1.verify(
            identityBundle,
            definition: air,
            quotientProof: airProof.proof.publicQuotientProof
        ))
        XCTAssertEqual(
            identityBundle.queryPlan,
            try AIRQuotientIdentityOpeningQueryPlannerV1.make(
                definition: air,
                quotientProof: airProof.proof.publicQuotientProof,
                currentTraceBundle: identityBundle.currentTracePCSProofBundle,
                nextTraceBundle: identityBundle.nextTracePCSProofBundle,
                quotientBundle: identityBundle.quotientPCSProofBundle,
                queryCount: 2
            )
        )

        var tamperedRecords = airProof.proof.publicQuotientProof.quotientPolynomials
        let firstRecord = tamperedRecords[0]
        var tamperedCoefficients = firstRecord.quotientCoefficients
        tamperedCoefficients[0] = M31Field.add(
            tamperedCoefficients[0],
            tamperedCoefficients[0] == M31Field.modulus - 1 ? 2 : 1
        )
        tamperedRecords[0] = try AIRConstraintQuotientPolynomialV1(
            kind: firstRecord.kind,
            constraintIndex: firstRecord.constraintIndex,
            numeratorDegreeBound: firstRecord.numeratorDegreeBound,
            vanishingDegree: firstRecord.vanishingDegree,
            quotientDegreeBound: firstRecord.quotientDegreeBound,
            quotientCoefficients: tamperedCoefficients
        )
        let tamperedQuotientProof = try AIRPublicQuotientProofV1(
            traceRowCount: airProof.proof.publicQuotientProof.traceRowCount,
            traceColumnCount: airProof.proof.publicQuotientProof.traceColumnCount,
            tracePolynomialDigest: airProof.proof.publicQuotientProof.tracePolynomialDigest,
            quotientPolynomials: tamperedRecords
        )
        XCTAssertThrowsError(try AIRSharedDomainQuotientIdentityPCSProofBundleBuilderV1.prove(
            trace: trace,
            definition: air,
            quotientProof: tamperedQuotientProof,
            domain: domain,
            parameterSet: parameterSet,
            queryCount: 2
        ))
    }

    func testPublicSidecarTheoremVerifiesAIRReductionAndGKRClaim() throws {
        let witness = try Self.fibonacciWitness()
        let air = try Self.fibonacciAIRDefinition()
        let trace = try WitnessToAIRTraceProducerV1.produce(witness: witness, for: air)
        XCTAssertTrue(try AIRSemanticVerifierV1.verify(definition: air, trace: trace))

        let airEvaluations = try AIRToSumcheckReductionV1.paddedEvaluationVector(
            definition: air,
            trace: trace
        )
        XCTAssertEqual(airEvaluations.count, 16)
        XCTAssertTrue(airEvaluations.allSatisfy { $0 == 0 })

        let sumcheckProof = try M31SumcheckProofBuilderV1.prove(
            evaluations: airEvaluations,
            rounds: 4
        )
        let gkrClaim = try Self.validGKRClaim()
        let statement = try Self.applicationStatement(
            witness: witness,
            air: air,
            gkrClaim: gkrClaim,
            sumcheckStatement: sumcheckProof.statement
        )
        let proof = try ApplicationProofBuilderV1.prove(
            statement: statement,
            sumcheckProof: sumcheckProof
        )

        let report = try ApplicationTheoremVerifierV1.verificationReport(
            proof: proof,
            statement: statement,
            witness: witness,
            airDefinition: air,
            gkrClaim: gkrClaim
        )

        XCTAssertTrue(report.componentReport.implementedComponentsVerified)
        XCTAssertFalse(report.componentReport.fullApplicationTheoremVerified)
        XCTAssertTrue(report.witnessCommitmentDigestMatches)
        XCTAssertTrue(report.airDefinitionDigestMatches)
        XCTAssertTrue(report.gkrClaimDigestMatches)
        XCTAssertTrue(report.witnessToAIRTraceProduced)
        XCTAssertTrue(report.airSemanticsVerified)
        XCTAssertTrue(report.airToSumcheckReductionVerified)
        XCTAssertTrue(report.gkrVerified)
        XCTAssertTrue(report.publicSidecarTheoremVerified)
        XCTAssertFalse(report.isZeroKnowledge)
        XCTAssertFalse(try ApplicationProofVerifierV1.verifyEndToEndApplicationTheorem(
            proof: proof,
            statement: statement
        ))
        XCTAssertTrue(try ApplicationTheoremVerifierV1.verifyPublicSidecarTheorem(
            proof: proof,
            statement: statement,
            witness: witness,
            airDefinition: air,
            gkrClaim: gkrClaim
        ))

        let encoded = try ApplicationProofCodecV1.encode(proof)
        XCTAssertEqual(
            try ApplicationTheoremVerifierV1.verificationReport(
                encodedProof: encoded,
                statement: statement,
                witness: witness,
                airDefinition: air,
                gkrClaim: gkrClaim
            ),
            report
        )
        XCTAssertTrue(try ApplicationTheoremVerifierV1.verifyPublicSidecarTheorem(
            encodedProof: encoded,
            statement: statement,
            witness: witness,
            airDefinition: air,
            gkrClaim: gkrClaim
        ))
    }

    func testAIRConstraintMultilinearSumcheckBindsReductionVector() throws {
        let witness = try Self.fibonacciWitness()
        let air = try Self.fibonacciAIRDefinition()
        let trace = try WitnessToAIRTraceProducerV1.produce(witness: witness, for: air)
        let proof = try AIRConstraintMultilinearSumcheckProofBuilderV1.prove(
            definition: air,
            trace: trace
        )
        let report = try AIRConstraintMultilinearSumcheckVerifierV1.verificationReport(
            proof,
            definition: air,
            trace: trace
        )

        XCTAssertEqual(proof.traceRowCount, trace.rowCount)
        XCTAssertEqual(proof.traceColumnCount, trace.columnCount)
        XCTAssertEqual(proof.sumcheckProof.statement.claimedHypercubeSum, 0)
        XCTAssertTrue(report.sumcheckReport.fullMultilinearSumcheckVerified)
        XCTAssertTrue(report.airDefinitionDigestMatches)
        XCTAssertTrue(report.traceShapeMatches)
        XCTAssertTrue(report.airEvaluationDigestMatches)
        XCTAssertTrue(report.sumcheckInitialDigestMatchesAIRReduction)
        XCTAssertTrue(report.zeroSumClaimVerified)
        XCTAssertTrue(report.airSemanticsVerified)
        XCTAssertTrue(report.provesAIRConstraintSumcheck)
        XCTAssertTrue(report.provesPublicAIRSemantics)
        XCTAssertFalse(report.isZeroKnowledge)
        XCTAssertTrue(try AIRConstraintMultilinearSumcheckVerifierV1.verify(
            proof,
            definition: air,
            trace: trace
        ))

        let encodedProof = try AIRConstraintMultilinearSumcheckProofCodecV1.encode(proof)
        XCTAssertEqual(
            try AIRConstraintMultilinearSumcheckProofCodecV1.decode(encodedProof),
            proof
        )
        XCTAssertEqual(try AIRConstraintMultilinearSumcheckProofDigestV1.digest(proof).count, 32)
        var trailingProof = encodedProof
        trailingProof.append(0)
        XCTAssertThrowsError(try AIRConstraintMultilinearSumcheckProofCodecV1.decode(trailingProof))

        let invalidTrace = try WitnessToAIRTraceProducerV1.produce(
            witness: ApplicationWitnessTraceV1(columns: [
                [1, 1, 2, 3],
                [1, 2, 4, 5],
            ]),
            for: air
        )
        let invalidReport = try AIRConstraintMultilinearSumcheckVerifierV1.verificationReport(
            proof,
            definition: air,
            trace: invalidTrace
        )
        XCTAssertTrue(invalidReport.sumcheckReport.fullMultilinearSumcheckVerified)
        XCTAssertFalse(invalidReport.airEvaluationDigestMatches)
        XCTAssertFalse(invalidReport.sumcheckInitialDigestMatchesAIRReduction)
        XCTAssertFalse(invalidReport.airSemanticsVerified)
        XCTAssertFalse(invalidReport.provesAIRConstraintSumcheck)
        XCTAssertFalse(invalidReport.provesPublicAIRSemantics)
    }

    func testIntegratedPublicTheoremArtifactVerifiesAIRSumcheckQuotientAndGKR() throws {
        let witness = try Self.fibonacciWitness()
        let air = try Self.fibonacciAIRDefinition()
        let gkrClaim = try Self.validGKRClaim()
        let domain = try CircleDomainDescriptor.canonical(logSize: 6)
        let parameterSet = try Self.smallPCSParameterSet()
        let artifact = try ApplicationPublicTheoremIntegratedArtifactBuilderV1.prove(
            applicationIdentifier: "apple-zk-prover.test.integrated-public-theorem.v1",
            witness: witness,
            airDefinition: air,
            gkrClaim: gkrClaim,
            pcsStatement: Self.pcsStatement(),
            domain: domain,
            parameterSet: parameterSet,
            quotientIdentityQueryCount: 2
        )

        let report = try ApplicationPublicTheoremIntegratedArtifactVerifierV1
            .verificationReport(artifact)
        XCTAssertTrue(report.publicTheoremReport.publicSidecarTheoremVerified)
        XCTAssertTrue(report.airConstraintSumcheckReport.provesPublicAIRSemantics)
        XCTAssertTrue(report.quotientIdentityReport.provesAIRQuotientIdentity)
        XCTAssertTrue(report.quotientProofDerivedFromPublicTrace)
        XCTAssertTrue(report.airConstraintSumcheckMatchesPublicTheoremTrace)
        XCTAssertTrue(report.quotientIdentityMatchesPublicTheoremTrace)
        XCTAssertTrue(report.verifiesIntegratedPublicTheorem)
        XCTAssertFalse(report.isSuccinctAIRGKRProof)
        XCTAssertFalse(report.isZeroKnowledge)
        XCTAssertTrue(try ApplicationPublicTheoremIntegratedArtifactVerifierV1.verify(artifact))

        let encodedAirSumcheck = try AIRConstraintMultilinearSumcheckProofCodecV1.encode(
            artifact.airConstraintSumcheckProof
        )
        XCTAssertEqual(
            try AIRConstraintMultilinearSumcheckProofCodecV1.decode(encodedAirSumcheck),
            artifact.airConstraintSumcheckProof
        )
        let encodedQueryPlan = try AIRQuotientIdentityOpeningQueryPlanCodecV1.encode(
            artifact.quotientIdentityPCSProofBundle.queryPlan
        )
        XCTAssertEqual(
            try AIRQuotientIdentityOpeningQueryPlanCodecV1.decode(encodedQueryPlan),
            artifact.quotientIdentityPCSProofBundle.queryPlan
        )
        let encodedCurrentTraceBundle = try AIRRowDomainTracePCSProofBundleCodecV1.encode(
            artifact.quotientIdentityPCSProofBundle.currentTracePCSProofBundle
        )
        XCTAssertEqual(
            try AIRRowDomainTracePCSProofBundleCodecV1.decode(encodedCurrentTraceBundle),
            artifact.quotientIdentityPCSProofBundle.currentTracePCSProofBundle
        )
        let encodedQuotientIdentityBundle = try AIRSharedDomainQuotientIdentityPCSProofBundleCodecV1
            .encode(artifact.quotientIdentityPCSProofBundle)
        XCTAssertEqual(
            try AIRSharedDomainQuotientIdentityPCSProofBundleCodecV1.decode(
                encodedQuotientIdentityBundle
            ),
            artifact.quotientIdentityPCSProofBundle
        )
        XCTAssertEqual(
            try AIRSharedDomainQuotientIdentityPCSProofBundleDigestV1.digest(
                artifact.quotientIdentityPCSProofBundle
            ).count,
            32
        )
        let encodedArtifact = try ApplicationPublicTheoremIntegratedArtifactCodecV1.encode(artifact)
        XCTAssertEqual(
            try ApplicationPublicTheoremIntegratedArtifactCodecV1.decode(encodedArtifact),
            artifact
        )
        XCTAssertEqual(
            try ApplicationPublicTheoremIntegratedArtifactDigestV1.digest(artifact).count,
            32
        )
        XCTAssertEqual(
            try ApplicationPublicTheoremIntegratedArtifactVerifierV1.verificationReport(
                encodedArtifact: encodedArtifact
            ),
            report
        )
        XCTAssertTrue(try ApplicationPublicTheoremIntegratedArtifactVerifierV1.verify(
            encodedArtifact: encodedArtifact
        ))
        var trailingArtifact = encodedArtifact
        trailingArtifact.append(0)
        XCTAssertThrowsError(try ApplicationPublicTheoremIntegratedArtifactCodecV1.decode(trailingArtifact))

        var tamperedDigest = artifact.airConstraintSumcheckProof.airEvaluationDigest
        tamperedDigest[0] ^= 0x42
        let tamperedAirSumcheck = try AIRConstraintMultilinearSumcheckProofV1(
            airDefinitionDigest: artifact.airConstraintSumcheckProof.airDefinitionDigest,
            traceRowCount: artifact.airConstraintSumcheckProof.traceRowCount,
            traceColumnCount: artifact.airConstraintSumcheckProof.traceColumnCount,
            airEvaluationDigest: tamperedDigest,
            sumcheckProof: artifact.airConstraintSumcheckProof.sumcheckProof
        )
        let tamperedArtifact = try ApplicationPublicTheoremIntegratedArtifactV1(
            publicTheoremArtifact: artifact.publicTheoremArtifact,
            airConstraintSumcheckProof: tamperedAirSumcheck,
            quotientIdentityPCSProofBundle: artifact.quotientIdentityPCSProofBundle
        )
        let tamperedReport = try ApplicationPublicTheoremIntegratedArtifactVerifierV1
            .verificationReport(tamperedArtifact)
        XCTAssertTrue(tamperedReport.publicTheoremReport.publicSidecarTheoremVerified)
        XCTAssertTrue(tamperedReport.airConstraintSumcheckReport.sumcheckReport.fullMultilinearSumcheckVerified)
        XCTAssertFalse(tamperedReport.airConstraintSumcheckReport.airEvaluationDigestMatches)
        XCTAssertFalse(tamperedReport.airConstraintSumcheckReport.provesAIRConstraintSumcheck)
        XCTAssertTrue(tamperedReport.quotientIdentityReport.provesAIRQuotientIdentity)
        XCTAssertFalse(tamperedReport.verifiesIntegratedPublicTheorem)
        XCTAssertFalse(try ApplicationPublicTheoremIntegratedArtifactVerifierV1.verify(tamperedArtifact))
    }

    func testPublicTheoremArtifactBuildsEncodesAndVerifiesEndToEnd() throws {
        let witness = try Self.fibonacciWitness()
        let air = try Self.fibonacciAIRDefinition()
        let gkrClaim = try Self.validGKRClaim()
        let artifact = try ApplicationPublicTheoremBuilderV1.prove(
            applicationIdentifier: "apple-zk-prover.test.public-theorem-artifact.v1",
            witness: witness,
            airDefinition: air,
            gkrClaim: gkrClaim,
            pcsStatement: Self.pcsStatement()
        )

        XCTAssertEqual(artifact.statement.witnessCommitmentDigest, try ApplicationWitnessDigestV1.digest(witness))
        XCTAssertEqual(artifact.statement.airDefinitionDigest, try AIRDefinitionDigestV1.digest(air))
        XCTAssertEqual(artifact.statement.gkrClaimDigest, try GKRClaimDigestV1.digest(gkrClaim))
        XCTAssertTrue(try ApplicationProofVerifierV1.verify(
            proof: artifact.proof,
            statement: artifact.statement
        ))
        XCTAssertFalse(try ApplicationProofVerifierV1.verifyEndToEndApplicationTheorem(
            proof: artifact.proof,
            statement: artifact.statement
        ))

        let report = try ApplicationTheoremVerifierV1.verificationReport(artifact: artifact)
        XCTAssertTrue(report.componentReport.implementedComponentsVerified)
        XCTAssertTrue(report.witnessCommitmentDigestMatches)
        XCTAssertTrue(report.airDefinitionDigestMatches)
        XCTAssertTrue(report.gkrClaimDigestMatches)
        XCTAssertTrue(report.witnessToAIRTraceProduced)
        XCTAssertTrue(report.airSemanticsVerified)
        XCTAssertTrue(report.airToSumcheckReductionVerified)
        XCTAssertTrue(report.gkrVerified)
        XCTAssertTrue(report.publicSidecarTheoremVerified)
        XCTAssertFalse(report.isZeroKnowledge)
        XCTAssertTrue(try ApplicationTheoremVerifierV1.verifyPublicTheoremArtifact(artifact))

        XCTAssertEqual(
            try ApplicationProofStatementCodecV1.decode(
                try ApplicationProofStatementCodecV1.encode(artifact.statement)
            ),
            artifact.statement
        )
        XCTAssertEqual(
            try ApplicationWitnessTraceCodecV1.decode(
                try ApplicationWitnessTraceCodecV1.encode(witness)
            ),
            witness
        )
        XCTAssertEqual(
            try AIRDefinitionCodecV1.decode(try AIRDefinitionCodecV1.encode(air)),
            air
        )
        XCTAssertEqual(
            try GKRClaimCodecV1.decode(try GKRClaimCodecV1.encode(gkrClaim)),
            gkrClaim
        )

        let encodedArtifact = try ApplicationPublicTheoremArtifactCodecV1.encode(artifact)
        XCTAssertEqual(
            try ApplicationPublicTheoremArtifactCodecV1.decode(encodedArtifact),
            artifact
        )
        XCTAssertEqual(
            try ApplicationTheoremVerifierV1.verificationReport(encodedArtifact: encodedArtifact),
            report
        )
        XCTAssertTrue(try ApplicationTheoremVerifierV1.verifyPublicTheoremArtifact(
            encodedArtifact: encodedArtifact
        ))

        var trailing = encodedArtifact
        trailing.append(0)
        XCTAssertThrowsError(try ApplicationPublicTheoremArtifactCodecV1.decode(trailing))
    }

    func testPublicTheoremTracePCSArtifactBindsTraceBundleAndApplicationPCSProof() throws {
        let witness = try Self.fibonacciWitness()
        let air = try Self.fibonacciAIRDefinition()
        let gkrClaim = try Self.validGKRClaim()
        let domain = try CircleDomainDescriptor.canonical(logSize: 6)
        let parameterSet = try Self.smallPCSParameterSet()

        let artifact = try ApplicationPublicTheoremTracePCSArtifactBuilderV1.prove(
            applicationIdentifier: "apple-zk-prover.test.public-theorem-trace-pcs-artifact.v1",
            witness: witness,
            airDefinition: air,
            gkrClaim: gkrClaim,
            domain: domain,
            parameterSet: parameterSet,
            claimRowIndices: [0, 3],
            sumcheckRounds: 4
        )

        XCTAssertEqual(artifact.tracePCSProofBundle.witness.claimedRowIndices, [0, 3])
        XCTAssertEqual(artifact.tracePCSProofBundle.chunks.count, 1)
        XCTAssertEqual(
            artifact.publicTheoremArtifact.statement.pcsStatement,
            artifact.tracePCSProofBundle.chunks[0].statement
        )
        XCTAssertEqual(
            artifact.publicTheoremArtifact.proof.pcsProof,
            artifact.tracePCSProofBundle.chunks[0].proof
        )

        let report = try ApplicationPublicTheoremTracePCSArtifactVerifierV1.verificationReport(artifact)
        XCTAssertTrue(report.publicTheoremReport.publicSidecarTheoremVerified)
        XCTAssertTrue(report.tracePCSBundleProofsVerify)
        XCTAssertTrue(report.tracePCSBundleMatchesAIRTrace)
        XCTAssertTrue(report.applicationPCSProofIsInTraceBundle)
        XCTAssertTrue(report.verified)
        XCTAssertFalse(report.isZeroKnowledge)
        XCTAssertTrue(try ApplicationPublicTheoremTracePCSArtifactVerifierV1.verify(artifact))

        let encodedArtifact = try ApplicationPublicTheoremTracePCSArtifactCodecV1.encode(artifact)
        let decodedArtifact = try ApplicationPublicTheoremTracePCSArtifactCodecV1.decode(encodedArtifact)
        XCTAssertEqual(decodedArtifact, artifact)
        XCTAssertEqual(
            try ApplicationPublicTheoremTracePCSArtifactDigestV1.digest(decodedArtifact),
            try ApplicationPublicTheoremTracePCSArtifactDigestV1.digest(artifact)
        )
        XCTAssertEqual(
            try ApplicationPublicTheoremTracePCSArtifactVerifierV1.verificationReport(
                encodedArtifact: encodedArtifact
            ),
            report
        )
        XCTAssertTrue(try ApplicationPublicTheoremTracePCSArtifactVerifierV1.verify(
            encodedArtifact: encodedArtifact
        ))

        var trailing = encodedArtifact
        trailing.append(0)
        XCTAssertThrowsError(try ApplicationPublicTheoremTracePCSArtifactCodecV1.decode(trailing))

        let trace = try WitnessToAIRTraceProducerV1.produce(witness: witness, for: air)
        let mismatchedTrace = try WitnessToAIRTraceProducerV1.produce(witness: ApplicationWitnessTraceV1(columns: [
            [1, 1, 2, 4],
            [1, 2, 3, 5],
        ]))
        let mismatchedBundle = try AIRTraceCirclePCSProofBundleBuilderV1.prove(
            trace: mismatchedTrace,
            domain: domain,
            parameterSet: parameterSet,
            claimRowIndices: [0, 3]
        )
        XCTAssertNotEqual(
            mismatchedBundle.witness,
            try AIRTraceToCirclePCSWitnessV1.make(
                trace: trace,
                domain: domain,
                claimRowIndices: [0, 3]
            )
        )
        let mismatchedArtifact = try ApplicationPublicTheoremTracePCSArtifactV1(
            publicTheoremArtifact: artifact.publicTheoremArtifact,
            tracePCSProofBundle: mismatchedBundle
        )
        let mismatchedReport = try ApplicationPublicTheoremTracePCSArtifactVerifierV1.verificationReport(
            mismatchedArtifact
        )
        XCTAssertTrue(mismatchedReport.tracePCSBundleProofsVerify)
        XCTAssertFalse(mismatchedReport.tracePCSBundleMatchesAIRTrace)
        XCTAssertFalse(mismatchedReport.verified)

        let externalPCSArtifact = try ApplicationPublicTheoremBuilderV1.prove(
            applicationIdentifier: "apple-zk-prover.test.public-theorem-external-pcs.v1",
            witness: witness,
            airDefinition: air,
            gkrClaim: gkrClaim,
            pcsStatement: Self.pcsStatement(),
            sumcheckRounds: 4
        )
        let unboundArtifact = try ApplicationPublicTheoremTracePCSArtifactV1(
            publicTheoremArtifact: externalPCSArtifact,
            tracePCSProofBundle: artifact.tracePCSProofBundle
        )
        let unboundReport = try ApplicationPublicTheoremTracePCSArtifactVerifierV1.verificationReport(
            unboundArtifact
        )
        XCTAssertTrue(unboundReport.tracePCSBundleMatchesAIRTrace)
        XCTAssertFalse(unboundReport.applicationPCSProofIsInTraceBundle)
        XCTAssertFalse(unboundReport.verified)

        XCTAssertThrowsError(try ApplicationPublicTheoremTracePCSArtifactBuilderV1.assemble(
            publicTheoremArtifact: externalPCSArtifact,
            tracePCSProofBundle: artifact.tracePCSProofBundle
        ))
    }

    func testApplicationPublicTheoremArtifactCorpusV1PinsCanonicalDigestsAndRejections() throws {
        let corpus = try Self.loadApplicationPublicTheoremArtifactCorpus()
        XCTAssertEqual(corpus.schemaVersion, 1)
        XCTAssertEqual(corpus.artifact, ApplicationPublicTheoremArtifactManifestV1.artifactName)

        let fixture = try Self.makePublicTheoremCorpusFixture(corpus.statement)
        let artifact = fixture.artifact
        let encodedArtifact = try ApplicationPublicTheoremArtifactCodecV1.encode(artifact)
        let encodedProof = try ApplicationProofCodecV1.encode(artifact.proof)

        XCTAssertEqual(encodedArtifact.count, corpus.statement.expected.artifactByteCount)
        XCTAssertEqual(SHA3Oracle.sha3_256(encodedArtifact).hexString, corpus.statement.expected.artifactDigestHex)
        XCTAssertEqual(encodedProof.count, corpus.statement.expected.proofByteCount)
        XCTAssertEqual(SHA3Oracle.sha3_256(encodedProof).hexString, corpus.statement.expected.proofDigestHex)
        XCTAssertEqual(try artifact.statement.digest().hexString, corpus.statement.expected.statementDigestHex)
        XCTAssertEqual(try ApplicationWitnessDigestV1.digest(fixture.witness).hexString, corpus.statement.expected.witnessDigestHex)
        XCTAssertEqual(try AIRDefinitionDigestV1.digest(fixture.airDefinition).hexString, corpus.statement.expected.airDefinitionDigestHex)
        XCTAssertEqual(try GKRClaimDigestV1.digest(fixture.gkrClaim).hexString, corpus.statement.expected.gkrClaimDigestHex)
        XCTAssertEqual(
            artifact.statement.sumcheckStatement.initialEvaluationDigest.hexString,
            corpus.statement.expected.sumcheckInitialDigestHex
        )
        XCTAssertEqual(
            artifact.statement.sumcheckStatement.finalVectorDigest.hexString,
            corpus.statement.expected.sumcheckFinalDigestHex
        )
        XCTAssertEqual(
            try ApplicationPublicTheoremArtifactCodecV1.decode(encodedArtifact),
            artifact
        )
        XCTAssertTrue(try ApplicationTheoremVerifierV1.verifyPublicTheoremArtifact(
            encodedArtifact: encodedArtifact
        ))

        XCTAssertEqual(corpus.tamperVectors.count, 4)
        for vector in corpus.tamperVectors {
            XCTAssertFalse(vector.expectedVerifierAccepted, vector.id)
            switch vector.id {
            case "public-witness-sidecar-digest-mismatch":
                let report = try ApplicationTheoremVerifierV1.verificationReport(
                    artifact: Self.publicWitnessMismatchArtifact(from: fixture)
                )
                XCTAssertFalse(report.witnessCommitmentDigestMatches, vector.id)
                XCTAssertFalse(report.publicSidecarTheoremVerified, vector.id)
            case "false-gkr-output-with-matching-digest":
                let report = try ApplicationTheoremVerifierV1.verificationReport(
                    artifact: Self.falseGKRArtifact(from: fixture)
                )
                XCTAssertTrue(report.gkrClaimDigestMatches, vector.id)
                XCTAssertFalse(report.gkrVerified, vector.id)
                XCTAssertFalse(report.publicSidecarTheoremVerified, vector.id)
            case "invalid-air-semantics-with-matching-reduction":
                let report = try ApplicationTheoremVerifierV1.verificationReport(
                    artifact: Self.invalidAIRArtifact(from: fixture)
                )
                XCTAssertTrue(report.witnessCommitmentDigestMatches, vector.id)
                XCTAssertTrue(report.airToSumcheckReductionVerified, vector.id)
                XCTAssertFalse(report.airSemanticsVerified, vector.id)
                XCTAssertFalse(report.publicSidecarTheoremVerified, vector.id)
            case "trailing-byte-decode-rejection":
                var trailing = encodedArtifact
                trailing.append(0)
                XCTAssertThrowsError(
                    try ApplicationPublicTheoremArtifactCodecV1.decode(trailing),
                    vector.id
                )
            default:
                XCTFail("Unhandled corpus tamper vector \(vector.id)")
            }
        }
    }

    func testApplicationPublicTheoremIntegratedArtifactCorpusV1PinsCanonicalDigestsAndRejections() throws {
        let corpus = try Self.loadApplicationPublicTheoremIntegratedArtifactCorpus()
        XCTAssertEqual(corpus.schemaVersion, 1)
        XCTAssertEqual(corpus.artifact, ApplicationPublicTheoremIntegratedArtifactManifestV1.artifactName)
        XCTAssertEqual(corpus.sourceCorpus, "ApplicationPublicTheoremArtifactCorpusV1")

        let sourceCorpus = try Self.loadApplicationPublicTheoremArtifactCorpus()
        let fixture = try Self.makePublicTheoremCorpusFixture(sourceCorpus.statement)
        let artifact = try ApplicationPublicTheoremIntegratedArtifactBuilderV1.prove(
            applicationIdentifier: fixture.artifact.statement.applicationIdentifier,
            witness: fixture.witness,
            airDefinition: fixture.airDefinition,
            gkrClaim: fixture.gkrClaim,
            pcsStatement: fixture.pcsStatement,
            domain: CircleDomainDescriptor.canonical(logSize: corpus.statement.quotientIdentityDomainLogSize),
            parameterSet: Self.smallPCSParameterSet(),
            quotientIdentityQueryCount: corpus.statement.quotientIdentityQueryCount
        )
        let encodedArtifact = try ApplicationPublicTheoremIntegratedArtifactCodecV1.encode(artifact)
        let encodedAIRSumcheck = try AIRConstraintMultilinearSumcheckProofCodecV1.encode(
            artifact.airConstraintSumcheckProof
        )
        let encodedQuotientIdentityBundle =
            try AIRSharedDomainQuotientIdentityPCSProofBundleCodecV1.encode(
                artifact.quotientIdentityPCSProofBundle
            )

        XCTAssertEqual(encodedArtifact.count, corpus.statement.expected.artifactByteCount)
        XCTAssertEqual(SHA3Oracle.sha3_256(encodedArtifact).hexString, corpus.statement.expected.artifactDigestHex)
        XCTAssertEqual(
            try ApplicationPublicTheoremIntegratedArtifactDigestV1.digest(artifact).hexString,
            corpus.statement.expected.artifactDomainDigestHex
        )
        XCTAssertEqual(encodedAIRSumcheck.count, corpus.statement.expected.airSumcheckByteCount)
        XCTAssertEqual(SHA3Oracle.sha3_256(encodedAIRSumcheck).hexString, corpus.statement.expected.airSumcheckDigestHex)
        XCTAssertEqual(
            try AIRConstraintMultilinearSumcheckProofDigestV1.digest(artifact.airConstraintSumcheckProof).hexString,
            corpus.statement.expected.airSumcheckDomainDigestHex
        )
        XCTAssertEqual(
            encodedQuotientIdentityBundle.count,
            corpus.statement.expected.quotientIdentityBundleByteCount
        )
        XCTAssertEqual(
            SHA3Oracle.sha3_256(encodedQuotientIdentityBundle).hexString,
            corpus.statement.expected.quotientIdentityBundleDigestHex
        )
        XCTAssertEqual(
            try AIRSharedDomainQuotientIdentityPCSProofBundleDigestV1.digest(
                artifact.quotientIdentityPCSProofBundle
            ).hexString,
            corpus.statement.expected.quotientIdentityBundleDomainDigestHex
        )
        XCTAssertEqual(
            artifact.quotientIdentityPCSProofBundle.queryPlan.commitmentDigest.hexString,
            corpus.statement.expected.quotientIdentityQueryPlanCommitmentDigestHex
        )
        XCTAssertEqual(try ApplicationPublicTheoremIntegratedArtifactCodecV1.decode(encodedArtifact), artifact)
        XCTAssertTrue(try ApplicationPublicTheoremIntegratedArtifactVerifierV1.verify(
            encodedArtifact: encodedArtifact
        ))

        XCTAssertEqual(corpus.tamperVectors.count, 3)
        for vector in corpus.tamperVectors {
            XCTAssertFalse(vector.expectedVerifierAccepted, vector.id)
            switch vector.id {
            case "air-sumcheck-evaluation-digest-mismatch":
                var digest = artifact.airConstraintSumcheckProof.airEvaluationDigest
                digest[0] ^= 0x42
                let tamperedAIR = try AIRConstraintMultilinearSumcheckProofV1(
                    airDefinitionDigest: artifact.airConstraintSumcheckProof.airDefinitionDigest,
                    traceRowCount: artifact.airConstraintSumcheckProof.traceRowCount,
                    traceColumnCount: artifact.airConstraintSumcheckProof.traceColumnCount,
                    airEvaluationDigest: digest,
                    sumcheckProof: artifact.airConstraintSumcheckProof.sumcheckProof
                )
                let tamperedArtifact = try ApplicationPublicTheoremIntegratedArtifactV1(
                    publicTheoremArtifact: artifact.publicTheoremArtifact,
                    airConstraintSumcheckProof: tamperedAIR,
                    quotientIdentityPCSProofBundle: artifact.quotientIdentityPCSProofBundle
                )
                let report = try ApplicationPublicTheoremIntegratedArtifactVerifierV1
                    .verificationReport(tamperedArtifact)
                XCTAssertFalse(report.airConstraintSumcheckReport.airEvaluationDigestMatches, vector.id)
                XCTAssertFalse(report.verifiesIntegratedPublicTheorem, vector.id)
            case "quotient-identity-query-plan-commitment-mismatch":
                var commitmentDigest = artifact.quotientIdentityPCSProofBundle.queryPlan.commitmentDigest
                commitmentDigest[0] ^= 0x24
                let queryPlan = artifact.quotientIdentityPCSProofBundle.queryPlan
                let tamperedQueryPlan = try AIRQuotientIdentityOpeningQueryPlanV1(
                    traceRowCount: queryPlan.traceRowCount,
                    traceColumnCount: queryPlan.traceColumnCount,
                    quotientPolynomialCount: queryPlan.quotientPolynomialCount,
                    queryCount: queryPlan.queryCount,
                    airDefinitionDigest: queryPlan.airDefinitionDigest,
                    quotientProofDigest: queryPlan.quotientProofDigest,
                    commitmentDigest: commitmentDigest,
                    claimedStorageIndices: queryPlan.claimedStorageIndices
                )
                let tamperedBundle = try AIRSharedDomainQuotientIdentityPCSProofBundleV1(
                    queryPlan: tamperedQueryPlan,
                    currentTracePCSProofBundle: artifact.quotientIdentityPCSProofBundle.currentTracePCSProofBundle,
                    nextTracePCSProofBundle: artifact.quotientIdentityPCSProofBundle.nextTracePCSProofBundle,
                    quotientPCSProofBundle: artifact.quotientIdentityPCSProofBundle.quotientPCSProofBundle
                )
                let tamperedArtifact = try ApplicationPublicTheoremIntegratedArtifactV1(
                    publicTheoremArtifact: artifact.publicTheoremArtifact,
                    airConstraintSumcheckProof: artifact.airConstraintSumcheckProof,
                    quotientIdentityPCSProofBundle: tamperedBundle
                )
                let report = try ApplicationPublicTheoremIntegratedArtifactVerifierV1
                    .verificationReport(tamperedArtifact)
                XCTAssertFalse(report.quotientIdentityReport.queryPlanMatchesCommitments, vector.id)
                XCTAssertFalse(report.quotientIdentityReport.provesAIRQuotientIdentity, vector.id)
                XCTAssertFalse(report.verifiesIntegratedPublicTheorem, vector.id)
            case "trailing-byte-decode-rejection":
                var trailing = encodedArtifact
                trailing.append(0)
                XCTAssertThrowsError(
                    try ApplicationPublicTheoremIntegratedArtifactCodecV1.decode(trailing),
                    vector.id
                )
            default:
                XCTFail("Unhandled integrated corpus tamper vector \(vector.id)")
            }
        }
    }

    func testPublicTheoremArtifactBuilderRejectsFalseTheoremInputs() throws {
        XCTAssertThrowsError(try ApplicationPublicTheoremBuilderV1.prove(
            applicationIdentifier: "apple-zk-prover.test.invalid-air-artifact.v1",
            witness: ApplicationWitnessTraceV1(columns: [
                [1, 1, 2, 3],
                [1, 2, 4, 5],
            ]),
            airDefinition: Self.fibonacciAIRDefinition(),
            gkrClaim: Self.validGKRClaim(),
            pcsStatement: Self.pcsStatement()
        ))

        XCTAssertThrowsError(try ApplicationPublicTheoremBuilderV1.prove(
            applicationIdentifier: "apple-zk-prover.test.invalid-gkr-artifact.v1",
            witness: Self.fibonacciWitness(),
            airDefinition: Self.fibonacciAIRDefinition(),
            gkrClaim: GKRClaimV1(
                inputValues: [2, 3],
                layers: [
                    try GKRLayerV1(gates: [
                        try GKRGateV1(operation: .add, leftInputIndex: 0, rightInputIndex: 1),
                        try GKRGateV1(operation: .multiply, leftInputIndex: 0, rightInputIndex: 1),
                    ]),
                ],
                claimedOutputs: [5, 7]
            ),
            pcsStatement: Self.pcsStatement()
        ))
    }

    func testPublicTheoremArtifactVerifierRejectsDigestMismatchedSidecar() throws {
        let artifact = try ApplicationPublicTheoremBuilderV1.prove(
            applicationIdentifier: "apple-zk-prover.test.sidecar-mismatch-artifact.v1",
            witness: Self.fibonacciWitness(),
            airDefinition: Self.fibonacciAIRDefinition(),
            gkrClaim: Self.validGKRClaim(),
            pcsStatement: Self.pcsStatement()
        )
        let mismatched = try ApplicationPublicTheoremArtifactV1(
            statement: artifact.statement,
            proof: artifact.proof,
            witness: ApplicationWitnessTraceV1(columns: [
                [1, 1, 2, 3],
                [1, 2, 4, 5],
            ]),
            airDefinition: artifact.airDefinition,
            gkrClaim: artifact.gkrClaim
        )

        let report = try ApplicationTheoremVerifierV1.verificationReport(artifact: mismatched)
        XCTAssertTrue(report.componentReport.implementedComponentsVerified)
        XCTAssertFalse(report.witnessCommitmentDigestMatches)
        XCTAssertFalse(report.airSemanticsVerified)
        XCTAssertFalse(report.publicSidecarTheoremVerified)
        XCTAssertFalse(try ApplicationTheoremVerifierV1.verifyPublicTheoremArtifact(mismatched))
    }

    func testPublicSidecarTheoremRejectsInvalidAIRSemanticsEvenWhenReductionMatchesSumcheck() throws {
        let witness = try ApplicationWitnessTraceV1(columns: [
            [1, 1, 2, 3],
            [1, 2, 4, 5],
        ])
        let air = try Self.fibonacciAIRDefinition()
        let trace = try WitnessToAIRTraceProducerV1.produce(witness: witness, for: air)
        XCTAssertFalse(try AIRSemanticVerifierV1.verify(definition: air, trace: trace))

        let airEvaluations = try AIRToSumcheckReductionV1.paddedEvaluationVector(
            definition: air,
            trace: trace
        )
        XCTAssertEqual(airEvaluations.count, 16)
        XCTAssertFalse(airEvaluations.allSatisfy { $0 == 0 })

        let sumcheckProof = try M31SumcheckProofBuilderV1.prove(
            evaluations: airEvaluations,
            rounds: 4
        )
        let gkrClaim = try Self.validGKRClaim()
        let statement = try Self.applicationStatement(
            witness: witness,
            air: air,
            gkrClaim: gkrClaim,
            sumcheckStatement: sumcheckProof.statement
        )
        let proof = try ApplicationProofBuilderV1.prove(
            statement: statement,
            sumcheckProof: sumcheckProof
        )

        let report = try ApplicationTheoremVerifierV1.verificationReport(
            proof: proof,
            statement: statement,
            witness: witness,
            airDefinition: air,
            gkrClaim: gkrClaim
        )

        XCTAssertTrue(report.componentReport.implementedComponentsVerified)
        XCTAssertTrue(report.witnessCommitmentDigestMatches)
        XCTAssertTrue(report.airDefinitionDigestMatches)
        XCTAssertTrue(report.gkrClaimDigestMatches)
        XCTAssertTrue(report.airToSumcheckReductionVerified)
        XCTAssertTrue(report.gkrVerified)
        XCTAssertFalse(report.airSemanticsVerified)
        XCTAssertFalse(report.publicSidecarTheoremVerified)
    }

    func testGKRClaimVerifierRejectsFalseClaimWithMatchingDigest() throws {
        let falseClaim = try GKRClaimV1(
            inputValues: [2, 3],
            layers: [
                try GKRLayerV1(gates: [
                    try GKRGateV1(operation: .add, leftInputIndex: 0, rightInputIndex: 1),
                    try GKRGateV1(operation: .multiply, leftInputIndex: 0, rightInputIndex: 1),
                ]),
            ],
            claimedOutputs: [5, 7]
        )
        XCTAssertEqual(try GKRSemanticVerifierV1.evaluate(falseClaim), [5, 6])
        XCTAssertFalse(try GKRSemanticVerifierV1.verify(falseClaim))
        XCTAssertEqual(try GKRClaimDigestV1.digest(falseClaim).count, 32)
    }

    private struct ApplicationPublicTheoremCorpusFixture: Decodable {
        let artifact: String
        let schemaVersion: Int
        let statement: ApplicationPublicTheoremCorpusStatement
        let tamperVectors: [ApplicationPublicTheoremCorpusTamperVector]
    }

    private struct ApplicationPublicTheoremCorpusStatement: Decodable {
        let airDefinition: String
        let applicationIdentifier: String
        let claimedStorageIndices: [Int]
        let domainLogSize: UInt32
        let expected: ApplicationPublicTheoremCorpusExpected
        let gkrClaim: ApplicationPublicTheoremCorpusGKRClaim
        let parameterSet: ApplicationPublicTheoremCorpusParameterSet
        let storageOrder: String
        let witnessColumns: [[UInt32]]
        let xCoefficientHex: [String]
        let yCoefficientHex: [String]
    }

    private struct ApplicationPublicTheoremCorpusExpected: Decodable {
        let airDefinitionDigestHex: String
        let artifactByteCount: Int
        let artifactDigestHex: String
        let gkrClaimDigestHex: String
        let proofByteCount: Int
        let proofDigestHex: String
        let statementDigestHex: String
        let sumcheckFinalDigestHex: String
        let sumcheckInitialDigestHex: String
        let witnessDigestHex: String
    }

    private struct ApplicationPublicTheoremCorpusGKRClaim: Decodable {
        let claimedOutputs: [UInt32]
        let inputValues: [UInt32]
        let layers: [[ApplicationPublicTheoremCorpusGKRGate]]
    }

    private struct ApplicationPublicTheoremCorpusGKRGate: Decodable {
        let leftInputIndex: Int
        let operation: String
        let rightInputIndex: Int
    }

    private struct ApplicationPublicTheoremCorpusParameterSet: Decodable {
        let foldingStep: UInt32
        let grindingBits: UInt32
        let id: String
        let logBlowupFactor: UInt32
        let nominalSecurityBits: UInt32
        let queryCount: UInt32
        let targetSoundnessBits: UInt32
    }

    private struct ApplicationPublicTheoremCorpusTamperVector: Decodable {
        let description: String
        let expectedVerifierAccepted: Bool
        let id: String
    }

    private struct ApplicationPublicTheoremIntegratedCorpusFixture: Decodable {
        let artifact: String
        let schemaVersion: Int
        let sourceCorpus: String
        let statement: ApplicationPublicTheoremIntegratedCorpusStatement
        let tamperVectors: [ApplicationPublicTheoremCorpusTamperVector]
    }

    private struct ApplicationPublicTheoremIntegratedCorpusStatement: Decodable {
        let quotientIdentityDomainLogSize: UInt32
        let quotientIdentityQueryCount: Int
        let expected: ApplicationPublicTheoremIntegratedCorpusExpected
    }

    private struct ApplicationPublicTheoremIntegratedCorpusExpected: Decodable {
        let airSumcheckByteCount: Int
        let airSumcheckDigestHex: String
        let airSumcheckDomainDigestHex: String
        let artifactByteCount: Int
        let artifactDigestHex: String
        let artifactDomainDigestHex: String
        let quotientIdentityBundleByteCount: Int
        let quotientIdentityBundleDigestHex: String
        let quotientIdentityBundleDomainDigestHex: String
        let quotientIdentityQueryPlanCommitmentDigestHex: String
    }

    private struct PublicTheoremCorpusFixture {
        let artifact: ApplicationPublicTheoremArtifactV1
        let witness: ApplicationWitnessTraceV1
        let airDefinition: AIRDefinitionV1
        let gkrClaim: GKRClaimV1
        let pcsStatement: CirclePCSFRIStatementV1
    }

    private static func loadApplicationPublicTheoremArtifactCorpus() throws -> ApplicationPublicTheoremCorpusFixture {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "ApplicationPublicTheoremArtifactCorpusV1",
            withExtension: "json"
        ))
        return try JSONDecoder().decode(
            ApplicationPublicTheoremCorpusFixture.self,
            from: try Data(contentsOf: url)
        )
    }

    private static func loadApplicationPublicTheoremIntegratedArtifactCorpus()
        throws -> ApplicationPublicTheoremIntegratedCorpusFixture {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "ApplicationPublicTheoremIntegratedArtifactCorpusV1",
            withExtension: "json"
        ))
        return try JSONDecoder().decode(
            ApplicationPublicTheoremIntegratedCorpusFixture.self,
            from: try Data(contentsOf: url)
        )
    }

    private static func makePublicTheoremCorpusFixture(
        _ statement: ApplicationPublicTheoremCorpusStatement
    ) throws -> PublicTheoremCorpusFixture {
        let witness = try ApplicationWitnessTraceV1(columns: statement.witnessColumns)
        let airDefinition = try namedAIRDefinition(statement.airDefinition)
        let gkrClaim = try makeGKRClaim(statement.gkrClaim)
        let pcsStatement = try makePCSStatement(
            parameterSet: statement.parameterSet,
            domainLogSize: statement.domainLogSize,
            storageOrder: statement.storageOrder,
            claimedStorageIndices: statement.claimedStorageIndices,
            xCoefficientHex: statement.xCoefficientHex,
            yCoefficientHex: statement.yCoefficientHex
        )
        let artifact = try ApplicationPublicTheoremBuilderV1.prove(
            applicationIdentifier: statement.applicationIdentifier,
            witness: witness,
            airDefinition: airDefinition,
            gkrClaim: gkrClaim,
            pcsStatement: pcsStatement
        )
        return PublicTheoremCorpusFixture(
            artifact: artifact,
            witness: witness,
            airDefinition: airDefinition,
            gkrClaim: gkrClaim,
            pcsStatement: pcsStatement
        )
    }

    private static func makePCSStatement(
        parameterSet proofParameterSet: ApplicationPublicTheoremCorpusParameterSet,
        domainLogSize: UInt32,
        storageOrder: String,
        claimedStorageIndices: [Int],
        xCoefficientHex: [String],
        yCoefficientHex: [String]
    ) throws -> CirclePCSFRIStatementV1 {
        XCTAssertEqual(storageOrder, "circle-domain-bit-reversed")
        XCTAssertEqual(proofParameterSet.id, CirclePCSFRIParameterSetV1.ProfileID.conservative128.rawValue)
        XCTAssertEqual(proofParameterSet.foldingStep, 1)
        let parameterSet = try CirclePCSFRIParameterSetV1(
            profileID: .conservative128,
            logBlowupFactor: proofParameterSet.logBlowupFactor,
            queryCount: proofParameterSet.queryCount,
            grindingBits: proofParameterSet.grindingBits,
            targetSoundnessBits: proofParameterSet.targetSoundnessBits
        )
        XCTAssertEqual(parameterSet.securityParameters.nominalSecurityBits, proofParameterSet.nominalSecurityBits)
        let domain = try CircleDomainDescriptor.canonical(logSize: domainLogSize)
        let polynomial = try CircleCodewordPolynomial(
            xCoefficients: try qm31Elements(fromHexStrings: xCoefficientHex),
            yCoefficients: try qm31Elements(fromHexStrings: yCoefficientHex)
        )
        return try CirclePCSFRIStatementV1(
            parameterSet: parameterSet,
            polynomialClaim: CirclePCSFRIPolynomialClaimV1.make(
                domain: domain,
                polynomial: polynomial,
                storageIndices: claimedStorageIndices
            )
        )
    }

    private static func namedAIRDefinition(_ name: String) throws -> AIRDefinitionV1 {
        switch name {
        case "fibonacci-m31-v1":
            return try fibonacciAIRDefinition()
        default:
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private static func makeGKRClaim(
        _ fixture: ApplicationPublicTheoremCorpusGKRClaim
    ) throws -> GKRClaimV1 {
        try GKRClaimV1(
            inputValues: fixture.inputValues,
            layers: fixture.layers.map { gates in
                try GKRLayerV1(gates: gates.map { gate in
                    try GKRGateV1(
                        operation: gkrOperation(gate.operation),
                        leftInputIndex: gate.leftInputIndex,
                        rightInputIndex: gate.rightInputIndex
                    )
                })
            },
            claimedOutputs: fixture.claimedOutputs
        )
    }

    private static func gkrOperation(_ operation: String) throws -> GKRGateOperationV1 {
        switch operation {
        case "add":
            return .add
        case "subtract":
            return .subtract
        case "multiply":
            return .multiply
        default:
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private static func publicWitnessMismatchArtifact(
        from fixture: PublicTheoremCorpusFixture
    ) throws -> ApplicationPublicTheoremArtifactV1 {
        try ApplicationPublicTheoremArtifactV1(
            statement: fixture.artifact.statement,
            proof: fixture.artifact.proof,
            witness: ApplicationWitnessTraceV1(columns: [
                [1, 1, 2, 3],
                [1, 2, 4, 5],
            ]),
            airDefinition: fixture.airDefinition,
            gkrClaim: fixture.gkrClaim
        )
    }

    private static func falseGKRArtifact(
        from fixture: PublicTheoremCorpusFixture
    ) throws -> ApplicationPublicTheoremArtifactV1 {
        let falseGKR = try GKRClaimV1(
            inputValues: fixture.gkrClaim.inputValues,
            layers: fixture.gkrClaim.layers,
            claimedOutputs: [5, 7]
        )
        return try assemblePublicTheoremArtifact(
            applicationIdentifier: fixture.artifact.statement.applicationIdentifier,
            witness: fixture.witness,
            airDefinition: fixture.airDefinition,
            gkrClaim: falseGKR,
            pcsStatement: fixture.pcsStatement
        )
    }

    private static func invalidAIRArtifact(
        from fixture: PublicTheoremCorpusFixture
    ) throws -> ApplicationPublicTheoremArtifactV1 {
        try assemblePublicTheoremArtifact(
            applicationIdentifier: fixture.artifact.statement.applicationIdentifier,
            witness: ApplicationWitnessTraceV1(columns: [
                [1, 1, 2, 3],
                [1, 2, 4, 5],
            ]),
            airDefinition: fixture.airDefinition,
            gkrClaim: fixture.gkrClaim,
            pcsStatement: fixture.pcsStatement
        )
    }

    private static func assemblePublicTheoremArtifact(
        applicationIdentifier: String,
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1,
        gkrClaim: GKRClaimV1,
        pcsStatement: CirclePCSFRIStatementV1
    ) throws -> ApplicationPublicTheoremArtifactV1 {
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: witness,
            for: airDefinition
        )
        let evaluations = try AIRToSumcheckReductionV1.paddedEvaluationVector(
            definition: airDefinition,
            trace: trace
        )
        let sumcheckProof = try M31SumcheckProofBuilderV1.prove(
            evaluations: evaluations,
            rounds: 4
        )
        let statement = try ApplicationProofStatementV1(
            applicationIdentifier: applicationIdentifier,
            witnessCommitmentDigest: ApplicationWitnessDigestV1.digest(witness),
            airDefinitionDigest: AIRDefinitionDigestV1.digest(airDefinition),
            gkrClaimDigest: GKRClaimDigestV1.digest(gkrClaim),
            sumcheckStatement: sumcheckProof.statement,
            pcsStatement: pcsStatement
        )
        let proof = try ApplicationProofBuilderV1.prove(
            statement: statement,
            sumcheckProof: sumcheckProof
        )
        return try ApplicationPublicTheoremArtifactV1(
            statement: statement,
            proof: proof,
            witness: witness,
            airDefinition: airDefinition,
            gkrClaim: gkrClaim
        )
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

#if canImport(Metal)
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
            blit.copy(
                from: staging,
                sourceOffset: 0,
                to: buffer,
                destinationOffset: 0,
                size: bytes.count
            )
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

    private static func fibonacciWitness() throws -> ApplicationWitnessTraceV1 {
        try ApplicationWitnessTraceV1(columns: [
            [1, 1, 2, 3],
            [1, 2, 3, 5],
        ])
    }

    private static func packedTraceValue(
        trace: AIRExecutionTraceV1,
        row: Int,
        firstColumn: Int
    ) throws -> QM31Element {
        var limbs = Array(repeating: UInt32(0), count: 4)
        for offset in 0..<4 where firstColumn + offset < trace.columnCount {
            limbs[offset] = try trace.value(row: row, column: firstColumn + offset)
        }
        return QM31Element(a: limbs[0], b: limbs[1], c: limbs[2], d: limbs[3])
    }

    private static func smallPCSParameterSet() throws -> CirclePCSFRIParameterSetV1 {
        try CirclePCSFRIParameterSetV1(
            profileID: .conservative128,
            logBlowupFactor: 2,
            queryCount: 2,
            grindingBits: 0,
            targetSoundnessBits: 4
        )
    }

    private static func fibonacciAIRDefinition() throws -> AIRDefinitionV1 {
        let currentA = try AIRTraceReferenceV1(kind: .current, column: 0)
        let currentB = try AIRTraceReferenceV1(kind: .current, column: 1)
        let nextA = try AIRTraceReferenceV1(kind: .next, column: 0)
        let nextB = try AIRTraceReferenceV1(kind: .next, column: 1)
        let minusOne = M31Field.modulus - 1

        let nextAMatchesCurrentB = try AIRConstraintPolynomialV1(terms: [
            try AIRConstraintTermV1(coefficient: 1, factors: [nextA]),
            try AIRConstraintTermV1(coefficient: minusOne, factors: [currentB]),
        ])
        let nextBMatchesSum = try AIRConstraintPolynomialV1(terms: [
            try AIRConstraintTermV1(coefficient: 1, factors: [nextB]),
            try AIRConstraintTermV1(coefficient: minusOne, factors: [currentA]),
            try AIRConstraintTermV1(coefficient: minusOne, factors: [currentB]),
        ])

        return try AIRDefinitionV1(
            columnCount: 2,
            transitionConstraints: [
                nextAMatchesCurrentB,
                nextBMatchesSum,
            ],
            boundaryConstraints: [
                try boundaryEquals(row: 0, column: 0, value: 1),
                try boundaryEquals(row: 0, column: 1, value: 1),
                try boundaryEquals(row: 3, column: 1, value: 5),
            ]
        )
    }

    private static func boundaryEquals(
        row: Int,
        column: Int,
        value: UInt32
    ) throws -> AIRBoundaryConstraintV1 {
        let reference = try AIRTraceReferenceV1(kind: .current, column: column)
        return try AIRBoundaryConstraintV1(
            rowIndex: row,
            polynomial: AIRConstraintPolynomialV1(terms: [
                try AIRConstraintTermV1(coefficient: 1, factors: [reference]),
                try AIRConstraintTermV1(coefficient: M31Field.negate(value)),
            ])
        )
    }

    private static func validGKRClaim() throws -> GKRClaimV1 {
        try GKRClaimV1(
            inputValues: [2, 3],
            layers: [
                try GKRLayerV1(gates: [
                    try GKRGateV1(operation: .add, leftInputIndex: 0, rightInputIndex: 1),
                    try GKRGateV1(operation: .multiply, leftInputIndex: 0, rightInputIndex: 1),
                ]),
            ],
            claimedOutputs: [5, 6]
        )
    }

    private static func applicationStatement(
        witness: ApplicationWitnessTraceV1,
        air: AIRDefinitionV1,
        gkrClaim: GKRClaimV1,
        sumcheckStatement: M31SumcheckStatementV1
    ) throws -> ApplicationProofStatementV1 {
        try ApplicationProofStatementV1(
            applicationIdentifier: "apple-zk-prover.test.public-sidecar-theorem.v1",
            witnessCommitmentDigest: ApplicationWitnessDigestV1.digest(witness),
            airDefinitionDigest: AIRDefinitionDigestV1.digest(air),
            gkrClaimDigest: GKRClaimDigestV1.digest(gkrClaim),
            sumcheckStatement: sumcheckStatement,
            pcsStatement: pcsStatement()
        )
    }

    private static func pcsStatement() throws -> CirclePCSFRIStatementV1 {
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
        return try CirclePCSFRIStatementV1(
            parameterSet: parameterSet,
            polynomialClaim: CirclePCSFRIPolynomialClaimV1.make(
                domain: domain,
                polynomial: polynomial,
                storageIndices: [0, 5]
            )
        )
    }
}
