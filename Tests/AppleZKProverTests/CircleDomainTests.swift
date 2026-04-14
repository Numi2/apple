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
        XCTAssertEqual(plan.inverseYTwiddles, try CircleDomainOracle.firstFoldInverseYTwiddles(for: domain))

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
            plan.inverseDomainLayers,
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
            plan.inverseDomainLayers,
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
        let proofResult = try codewordProver.proveVerified(polynomial: polynomial)
        XCTAssertEqual(proofResult.proof, expectedProof)
        XCTAssertEqual(try CirclePCSFRIProofCodecV1.decode(proofResult.encodedProof), expectedProof)
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
#endif
}
