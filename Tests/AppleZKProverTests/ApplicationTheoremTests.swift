import Foundation
import XCTest
@testable import AppleZKProver

final class ApplicationTheoremTests: XCTestCase {
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
