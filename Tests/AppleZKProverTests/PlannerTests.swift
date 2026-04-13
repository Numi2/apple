import XCTest
#if canImport(Metal)
import Metal
#endif
@testable import AppleZKProver

final class PlannerTests: XCTestCase {
    func testPlanDatabasePersistsLatestWinnerByWorkloadKey() throws {
        let url = temporaryDatabaseURL()
        let database = try PlanDatabase(url: url)
        let device = DeviceFingerprint(
            registryID: 123,
            name: "Test GPU",
            osBuild: "test-os",
            supportsApple4: true,
            supportsApple7: true,
            supportsApple9: false,
            supportsMetal4Queue: false,
            maxThreadsPerThreadgroup: 1024,
            hasUnifiedMemory: true
        )
        let workload = WorkloadSignature(
            stage: .merkleCommit,
            field: .bytes,
            inputLog2: 10,
            leafBytes: 32,
            arity: 2,
            roundsPerSuperstep: 1,
            fixedWidthCase: 32
        )
        let scalar = KernelSpec(
            kernel: "sha3_256_merkle_parents_specialized",
            family: .scalar,
            queueMode: .metal3,
            functionConstants: .plannerConstants([
                (.parentBytes, 32),
                (.treeArity, 2),
            ])
        )
        let treelet = MerkleKernelSpecs.treeletLeaves(leafBytes: 32, depth: 3)
        let record = PlanRecord(
            device: device,
            workload: workload,
            winner: treelet,
            medianGPUTimeNS: 100,
            medianCPUSubmitNS: 10,
            p95GPUTimeNS: 120,
            readbacks: 1,
            confidence: 1,
            shaderHash: "shader",
            protocolHash: "protocol"
        )

        try database.recordRaceResult(PlanRaceResult(record: record, measuredSpec: scalar, isWinner: false))
        try database.recordRaceResult(PlanRaceResult(record: record, measuredSpec: treelet, isWinner: true))

        let persisted = try database.latestWinner(
            device: device,
            workload: workload,
            shaderHash: "shader",
            protocolHash: "protocol"
        )
        XCTAssertEqual(persisted?.winner, treelet)
        XCTAssertEqual(persisted?.medianGPUTimeNS, 100)
        XCTAssertNil(
            try database.latestWinner(
                device: device,
                workload: workload,
                shaderHash: "other-shader",
                protocolHash: "protocol"
            )
        )
    }

    func testPlanDatabaseMarksLiveObservationStaleAfterSustainedDrift() throws {
        let database = try PlanDatabase(url: temporaryDatabaseURL())
        let record = makePlanRecord(
            medianGPUTimeNS: 100,
            medianCPUSubmitNS: 10
        )
        let policy = PlanDriftPolicy(
            emaAlpha: 1,
            relativeThreshold: 0.25,
            minimumSamples: 2
        )

        let first = try database.recordLiveObservation(
            for: record,
            gpuTimeNS: 105,
            cpuSubmitNS: 10,
            policy: policy
        )
        XCTAssertEqual(first, .stable(sampleCount: 1, emaGPUTimeNS: 105, emaCPUSubmitNS: 10))

        let second = try database.recordLiveObservation(
            for: record,
            gpuTimeNS: 200,
            cpuSubmitNS: 20,
            policy: policy
        )
        guard case let .stale(sampleCount, relativeDrift) = second else {
            return XCTFail("Expected stale drift status, got \(second)")
        }
        XCTAssertEqual(sampleCount, 2)
        XCTAssertGreaterThan(relativeDrift, 0.25)
    }

    func testM31SumcheckCPUOracleRejectsNonCanonicalInput() throws {
        XCTAssertThrowsError(
            try SumcheckOracle.m31Chunk(
                evaluations: [0, M31Field.modulus],
                rounds: 1
            )
        )
    }

    func testM31VectorCPUOracleCoversEdgeValues() throws {
        let lhs: [UInt32] = [
            0,
            1,
            2,
            M31Field.modulus - 2,
            M31Field.modulus - 1,
        ]
        let rhs: [UInt32] = [
            0,
            M31Field.modulus - 1,
            M31Field.modulus - 2,
            2,
            1,
        ]

        XCTAssertEqual(try M31Field.apply(.add, lhs: lhs, rhs: rhs), [0, 0, 0, 0, 0])
        XCTAssertEqual(try M31Field.apply(.subtract, lhs: lhs, rhs: rhs), [0, 2, 4, M31Field.modulus - 4, M31Field.modulus - 2])
        XCTAssertEqual(try M31Field.apply(.negate, lhs: lhs), [0, M31Field.modulus - 1, M31Field.modulus - 2, 2, 1])
        XCTAssertEqual(try M31Field.apply(.multiply, lhs: lhs, rhs: rhs), [0, M31Field.modulus - 1, M31Field.modulus - 4, M31Field.modulus - 4, M31Field.modulus - 1])
        XCTAssertEqual(try M31Field.apply(.square, lhs: lhs), [0, 1, 4, 4, 1])

        let nonzero: [UInt32] = [1, 2, 3, M31Field.modulus - 2, M31Field.modulus - 1]
        let inverses = try M31Field.batchInverse(nonzero)
        XCTAssertEqual(inverses, [1, 1_073_741_824, 1_431_655_765, 1_073_741_823, M31Field.modulus - 1])
        XCTAssertEqual(try M31Field.apply(.inverse, lhs: nonzero), inverses)
        for (value, inverse) in zip(nonzero, inverses) {
            XCTAssertEqual(M31Field.multiply(value, inverse), 1)
        }

        XCTAssertThrowsError(try M31Field.apply(.add, lhs: [M31Field.modulus], rhs: [0])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try M31Field.batchInverse([0, 1])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try M31Field.batchInverse([M31Field.modulus])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testM31DotProductCPUOracleCoversEdgeValues() throws {
        let lhs: [UInt32] = [
            0,
            1,
            2,
            M31Field.modulus - 2,
            M31Field.modulus - 1,
        ]
        let rhs: [UInt32] = [
            0,
            M31Field.modulus - 1,
            M31Field.modulus - 2,
            2,
            1,
        ]

        XCTAssertEqual(try M31Field.dotProduct(lhs: lhs, rhs: rhs), M31Field.modulus - 10)
        XCTAssertEqual(
            try M31Field.dotProduct(
                lhs: [M31Field.modulus - 1, M31Field.modulus - 1, M31Field.modulus - 1],
                rhs: [M31Field.modulus - 1, M31Field.modulus - 1, M31Field.modulus - 1]
            ),
            3
        )
        XCTAssertThrowsError(try M31Field.dotProduct(lhs: [], rhs: [])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try M31Field.dotProduct(lhs: [0], rhs: [0, 1])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try M31Field.dotProduct(lhs: [M31Field.modulus], rhs: [0])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testCM31CPUOracleCoversEdgeValues() throws {
        let modulus = CM31Field.modulus
        let lhs: [CM31Element] = [
            CM31Element(real: 0, imaginary: 0),
            CM31Element(real: 1, imaginary: 0),
            CM31Element(real: 0, imaginary: 1),
            CM31Element(real: modulus - 1, imaginary: 0),
            CM31Element(real: modulus - 1, imaginary: modulus - 1),
        ]
        let rhs: [CM31Element] = [
            CM31Element(real: 0, imaginary: 0),
            CM31Element(real: 0, imaginary: 1),
            CM31Element(real: 0, imaginary: 1),
            CM31Element(real: modulus - 1, imaginary: modulus - 1),
            CM31Element(real: 1, imaginary: modulus - 1),
        ]

        XCTAssertEqual(
            try CM31Field.apply(.add, lhs: lhs, rhs: rhs),
            [
                CM31Element(real: 0, imaginary: 0),
                CM31Element(real: 1, imaginary: 1),
                CM31Element(real: 0, imaginary: 2),
                CM31Element(real: modulus - 2, imaginary: modulus - 1),
                CM31Element(real: 0, imaginary: modulus - 2),
            ]
        )
        XCTAssertEqual(
            try CM31Field.apply(.subtract, lhs: lhs, rhs: rhs),
            [
                CM31Element(real: 0, imaginary: 0),
                CM31Element(real: 1, imaginary: modulus - 1),
                CM31Element(real: 0, imaginary: 0),
                CM31Element(real: 0, imaginary: 1),
                CM31Element(real: modulus - 2, imaginary: 0),
            ]
        )
        XCTAssertEqual(
            try CM31Field.apply(.negate, lhs: lhs),
            [
                CM31Element(real: 0, imaginary: 0),
                CM31Element(real: modulus - 1, imaginary: 0),
                CM31Element(real: 0, imaginary: modulus - 1),
                CM31Element(real: 1, imaginary: 0),
                CM31Element(real: 1, imaginary: 1),
            ]
        )
        XCTAssertEqual(
            try CM31Field.apply(.multiply, lhs: lhs, rhs: rhs),
            [
                CM31Element(real: 0, imaginary: 0),
                CM31Element(real: 0, imaginary: 1),
                CM31Element(real: modulus - 1, imaginary: 0),
                CM31Element(real: 1, imaginary: 1),
                CM31Element(real: modulus - 2, imaginary: 0),
            ]
        )
        XCTAssertEqual(
            try CM31Field.apply(.square, lhs: lhs),
            [
                CM31Element(real: 0, imaginary: 0),
                CM31Element(real: 1, imaginary: 0),
                CM31Element(real: modulus - 1, imaginary: 0),
                CM31Element(real: 1, imaginary: 0),
                CM31Element(real: 0, imaginary: 2),
            ]
        )

        XCTAssertThrowsError(try CM31Field.apply(.multiply, lhs: [CM31Element(real: modulus, imaginary: 0)], rhs: [lhs[0]])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try CM31Field.apply(.multiply, lhs: [lhs[0]], rhs: nil)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try CM31Field.apply(.square, lhs: [lhs[0]], rhs: [rhs[0]])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let value = CM31Element(real: 1, imaginary: 2)
        let inverse = try CM31Field.inverse(value)
        XCTAssertEqual(CM31Field.multiply(value, inverse), CM31Element(real: 1, imaginary: 0))
        XCTAssertThrowsError(try CM31Field.inverse(CM31Element(real: 0, imaginary: 0))) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testQM31CPUOracleCoversEdgeValuesAndInverse() throws {
        let modulus = QM31Field.modulus
        let lhs = QM31Element(a: 1, b: 2, c: 3, d: 4)
        let rhs = QM31Element(a: 4, b: 5, c: 6, d: 7)

        XCTAssertEqual(
            QM31Field.add(lhs, rhs),
            QM31Element(a: 5, b: 7, c: 9, d: 11)
        )
        XCTAssertEqual(
            QM31Field.subtract(lhs, rhs),
            QM31Element(a: modulus - 3, b: modulus - 3, c: modulus - 3, d: modulus - 3)
        )
        XCTAssertEqual(
            QM31Field.negate(lhs),
            QM31Element(a: modulus - 1, b: modulus - 2, c: modulus - 3, d: modulus - 4)
        )
        XCTAssertEqual(
            QM31Field.multiply(lhs, rhs),
            QM31Element(a: modulus - 71, b: 93, c: modulus - 16, d: 50)
        )
        XCTAssertEqual(
            QM31Field.square(lhs),
            QM31Element(a: modulus - 41, b: 45, c: modulus - 10, d: 20)
        )

        let inverse = try QM31Field.inverse(lhs)
        XCTAssertEqual(QM31Field.multiply(lhs, inverse), QM31Element(a: 1, b: 0, c: 0, d: 0))
        let inverses = try QM31Field.batchInverse([
            lhs,
            rhs,
            QM31Element(a: modulus - 1, b: 1, c: 0, d: modulus - 1),
        ])
        for (value, inverse) in zip([lhs, rhs, QM31Element(a: modulus - 1, b: 1, c: 0, d: modulus - 1)], inverses) {
            XCTAssertEqual(QM31Field.multiply(value, inverse), QM31Element(a: 1, b: 0, c: 0, d: 0))
        }

        XCTAssertThrowsError(try QM31Field.apply(.multiply, lhs: [QM31Element(a: modulus, b: 0, c: 0, d: 0)], rhs: [lhs])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try QM31Field.apply(.multiply, lhs: [lhs], rhs: nil)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try QM31Field.apply(.square, lhs: [lhs], rhs: [rhs])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try QM31Field.batchInverse([QM31Element(a: 0, b: 0, c: 0, d: 0)])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testQM31FRIFoldCPUOracleCoversRadix2FormulaAndRejections() throws {
        let modulus = QM31Field.modulus
        let positive = QM31Element(a: 1, b: 2, c: 3, d: 4)
        let negative = QM31Element(a: 4, b: 5, c: 6, d: 7)
        let challenge = QM31Element(a: 2, b: 0, c: 0, d: 0)
        let one = QM31Element(a: 1, b: 0, c: 0, d: 0)

        let folded = try QM31FRIFoldOracle.fold(
            evaluations: [positive, negative],
            inverseDomainPoints: [one],
            challenge: challenge
        )
        XCTAssertEqual(
            folded,
            [
                QM31Element(
                    a: QM31FRIFoldOracle.inverseTwo.constant.real - 1,
                    b: QM31FRIFoldOracle.inverseTwo.constant.real,
                    c: QM31FRIFoldOracle.inverseTwo.constant.real + 1,
                    d: QM31FRIFoldOracle.inverseTwo.constant.real + 2
                ),
            ]
        )

        let arbitraryChallenge = QM31Element(a: 9, b: 7, c: 5, d: 3)
        XCTAssertEqual(
            try QM31FRIFoldOracle.fold(
                evaluations: [positive, positive],
                inverseDomainPoints: [one],
                challenge: arbitraryChallenge
            ),
            [positive]
        )

        XCTAssertThrowsError(
            try QM31FRIFoldOracle.fold(
                evaluations: [positive, negative, positive],
                inverseDomainPoints: [one],
                challenge: challenge
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try QM31FRIFoldOracle.fold(
                evaluations: [positive, negative],
                inverseDomainPoints: [],
                challenge: challenge
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try QM31FRIFoldOracle.fold(
                evaluations: [positive, negative],
                inverseDomainPoints: [QM31Element(a: 0, b: 0, c: 0, d: 0)],
                challenge: challenge
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try QM31FRIFoldOracle.fold(
                evaluations: [QM31Element(a: modulus, b: 0, c: 0, d: 0), negative],
                inverseDomainPoints: [one],
                challenge: challenge
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try QM31FRIFoldOracle.fold(
                evaluations: [positive, negative],
                inverseDomainPoints: [one],
                challenge: QM31Element(a: 0, b: modulus, c: 0, d: 0)
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testM31SumcheckCPUOracleStableFramedTranscriptVector() throws {
        let evaluations = (0..<16).map { UInt32(($0 + 1) * 17) }
        let result = try SumcheckOracle.m31Chunk(evaluations: evaluations, rounds: 3)

        XCTAssertEqual(result.finalVector, [47_995_132, 403_760_185])
        XCTAssertEqual(result.challenges, [1_881_734_986, 98_454_187, 1_942_862_365])
        XCTAssertEqual(result.coefficients, [
            17, 34, 51, 68, 85, 102, 119, 136,
            153, 170, 187, 204, 221, 238, 255, 272,
            1_701_963_778, 1_256_443_926, 810_924_074, 365_404_222,
            2_067_368_017, 1_621_848_165, 1_176_328_313, 730_808_461,
            709_310_370, 499_338_437, 289_366_504, 79_394_571,
        ])
    }

    func testTranscriptStateAbsorbsMultipleBlocks() throws {
        var transcript = SHA3Oracle.TranscriptState()
        let bytes = Data((0..<513).map { UInt8(truncatingIfNeeded: $0 &* 31) })

        try transcript.absorb(bytes)

        let challenges = try transcript.squeezeUInt32(count: 8, modulus: M31Field.modulus)
        XCTAssertEqual(challenges.count, 8)
        XCTAssertEqual(challenges, try transcript.squeezeUInt32(count: 8, modulus: M31Field.modulus))
    }

    func testTranscriptSqueezeUsesFullRateAndAdditionalBlocks() throws {
        var transcript = SHA3Oracle.TranscriptState()
        let bytes = Data((0..<513).map { UInt8(truncatingIfNeeded: $0 &* 31) })
        let expected: [UInt32] = [
            2_127_244_439, 2_006_685_240, 365_476_064, 325_825_389,
            748_474_199, 1_574_807_894, 1_702_599_380, 1_638_745_504,
            119_529_931, 1_982_750_828, 2_081_507_940, 98_603_085,
            245_063_869, 1_571_176_274, 407_642_607, 869_703_177,
            1_884_659_589, 579_968_773, 522_851_100, 684_430_966,
            856_568_228, 588_718_645, 410_141_074, 1_143_554_196,
            1_136_193_723, 248_491_159, 1_736_217_753, 1_984_458_058,
            196_165_745, 57_049_776, 259_472_649, 135_497_590,
            140_823_932, 1_710_230_381, 1_848_732_132, 1_219_297_182,
            97_705_825, 1_371_638_320, 2_029_813_781, 1_986_135_364,
        ]

        try transcript.absorb(bytes)

        let challenges = try transcript.squeezeUInt32(count: expected.count, modulus: M31Field.modulus)
        XCTAssertEqual(challenges, expected)
        XCTAssertNotEqual(challenges[0..<6], challenges[34..<40])
    }

    #if canImport(Metal)
    func testSharedUploadRingCyclesCopiesAndClearsSlots() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let ring = try SharedUploadRing(
            device: device,
            slotCapacity: 3,
            slotCount: 2,
            label: "PlannerTests.UploadRing"
        )

        let first = try ring.copy(Data([1, 2, 3]), byteCount: 3)
        let second = try ring.copy(Data([4, 5]), byteCount: 2)
        let wrapped = try ring.copy(Data([6]), byteCount: 1)

        XCTAssertEqual(first.index, 0)
        XCTAssertEqual(second.index, 1)
        XCTAssertEqual(wrapped.index, 0)
        XCTAssertEqual(wrapped.offset, first.offset)
        XCTAssertNotEqual(second.offset, first.offset)
        XCTAssertGreaterThanOrEqual(ring.slotStride, ring.slotCapacity)
        XCTAssertEqual(Self.readBytes(ring.buffer, offset: wrapped.offset, count: 3), [6, 0, 0])
        XCTAssertEqual(Self.readBytes(ring.buffer, offset: second.offset, count: 3), [4, 5, 0])
        XCTAssertEqual(
            Self.readBytes(ring.buffer, offset: wrapped.offset + 3, count: ring.slotStride - 3),
            Array(repeating: UInt8(0), count: ring.slotStride - 3)
        )
        XCTAssertEqual(
            Self.readBytes(ring.buffer, offset: second.offset + 3, count: ring.slotStride - 3),
            Array(repeating: UInt8(0), count: ring.slotStride - 3)
        )

        XCTAssertThrowsError(try ring.reserve(byteCount: 4)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try ring.copy(Data([9]), byteCount: 2)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        let afterRejectedCopy = try ring.reserve(byteCount: 0)
        XCTAssertEqual(afterRejectedCopy.index, 1)
        XCTAssertThrowsError(
            try SharedUploadRing(
                device: device,
                slotCapacity: Int.max,
                slotCount: 2,
                label: "PlannerTests.UploadRingOverflow"
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        ring.clear()
        XCTAssertEqual(
            Self.readBytes(ring.buffer, offset: 0, count: ring.buffer.length),
            Array(repeating: UInt8(0), count: ring.buffer.length)
        )
    }

    func testMerkleTunerDifferentialChecksAndPersistsWinner() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 64
        let leafBytes = 32
        let leaves = Self.makeLeaves(count: leafCount, leafLength: leafBytes)
        let database = try PlanDatabase(url: temporaryDatabaseURL())
        let context = try MetalContext(device: device)
        let planner = MetalProofPlanner(context: context, planDatabase: database, protocolHash: "planner-test")

        let result = try planner.tuneMerkleCommitExecutionPlan(
            leaves: leaves,
            leafCount: leafCount,
            leafStride: leafBytes,
            leafBytes: leafBytes,
            configuration: TuningConfiguration(
                warmupRuns: 1,
                measuredRuns: 2,
                maxCandidates: 2,
                randomizedValidationBatches: 2
            )
        )

        XCTAssertFalse(result.measurements.isEmpty)
        XCTAssertEqual(result.executionPlan.readbackPoints, [.finalRoot])
        XCTAssertEqual(result.executionPlan.bufferLayout.readbackBytes, 32)

        let persisted = try database.latestWinner(
            device: context.deviceFingerprint,
            workload: result.winner.workload,
            shaderHash: context.shaderSourceHash,
            protocolHash: "planner-test"
        )
        XCTAssertEqual(persisted?.winner, result.winner.winner)
        XCTAssertEqual(persisted?.confidence, result.winner.confidence)
    }

    func testMerklePlannerIncludesNon32ByteTreeletCandidates() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        let workload = WorkloadSignature(
            stage: .merkleCommit,
            field: .bytes,
            inputLog2: 10,
            leafBytes: 64,
            arity: 2,
            roundsPerSuperstep: 1,
            fixedWidthCase: 64
        )

        let candidates = planner.merkleCandidates(workload: workload, leafCount: 1024)
        XCTAssertTrue(candidates.contains { candidate in
            candidate.family == .treelet
                && candidate.functionConstants[PlannerFunctionConstant.leafBytes.rawValue] == 64
                && candidate.functionConstants[PlannerFunctionConstant.treeletDepth.rawValue] == 3
        })
    }

    func testPlannedMerkleCommitUsesPersistedWinnerAndRecordsLiveObservation() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 64
        let leafBytes = 32
        let leaves = Self.makeLeaves(count: leafCount, leafLength: leafBytes, salt: 17)
        let database = try PlanDatabase(url: temporaryDatabaseURL())
        let context = try MetalContext(device: device)
        let planner = MetalProofPlanner(context: context, planDatabase: database, protocolHash: "planner-live-test")

        _ = try planner.tuneMerkleCommitExecutionPlan(
            leaves: Self.makeLeaves(count: leafCount, leafLength: leafBytes, salt: 5),
            leafCount: leafCount,
            leafStride: leafBytes,
            leafBytes: leafBytes,
            configuration: TuningConfiguration(
                warmupRuns: 1,
                measuredRuns: 2,
                maxCandidates: 2,
                randomizedValidationBatches: 1
            )
        )

        let planned = try planner.makePlannedMerkleCommitPlan(
            leafCount: leafCount,
            leafBytes: leafBytes,
            leafStride: leafBytes,
            driftPolicy: PlanDriftPolicy(emaAlpha: 1, relativeThreshold: 100, minimumSamples: 1)
        )
        XCTAssertNotNil(planned.persistedRecord)

        let result = try planned.commitWithObservation(leaves: leaves)
        let cpuRoot = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: leafCount,
            leafStride: leafBytes,
            leafLength: leafBytes
        )
        XCTAssertEqual(result.commitment.root, cpuRoot)
        guard case let .stable(sampleCount, _, _) = result.driftStatus else {
            return XCTFail("Expected stable drift observation, got \(String(describing: result.driftStatus))")
        }
        XCTAssertEqual(sampleCount, 1)
    }

    func testPlannedMerkleCommitAcceptsUploadedBufferHotPath() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 32
        let leafBytes = 32
        let leaves = Self.makeLeaves(count: leafCount, leafLength: leafBytes, salt: 29)
        let context = try MetalContext(device: device)
        let planner = MetalProofPlanner(context: context)
        let planned = try planner.makePlannedMerkleCommitPlan(
            leafCount: leafCount,
            leafBytes: leafBytes,
            leafStride: leafBytes
        )
        let upload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: leaves,
            declaredLength: leaves.count,
            label: "PlannerTests.UploadedLeaves"
        )

        let result = try planned.commitUploadedLeaves(buffer: upload)
        let cpuRoot = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: leafCount,
            leafStride: leafBytes,
            leafLength: leafBytes
        )
        XCTAssertEqual(result.commitment.root, cpuRoot)
        XCTAssertNil(result.driftStatus)
    }

    func testSumcheckChunkMatchesCPUOracleWithoutIntermediateReadback() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let evaluations = Self.makeM31Evaluations(count: 128, salt: 41)
        let expected = try SumcheckOracle.m31Chunk(evaluations: evaluations, rounds: 4)
        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        let plan = try planner.makeSumcheckChunkPlan(laneCount: evaluations.count, roundsPerSuperstep: 4)

        XCTAssertEqual(plan.executionPlan.workload.stage, .sumcheckChunk)
        XCTAssertEqual(plan.executionPlan.workload.field, .m31)
        XCTAssertEqual(plan.executionPlan.commandBufferChunks, 1)
        XCTAssertEqual(plan.executionPlan.readbackPoints, [.finalProofBytes])

        let measured = try plan.execute(evaluations: evaluations)
        XCTAssertEqual(measured.result.finalVector, expected.finalVector)
        XCTAssertEqual(measured.result.coefficients, expected.coefficients)
        XCTAssertEqual(measured.result.challenges, expected.challenges)
    }

    func testM31VectorArithmeticPlansMatchCPUOracle() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        var lhs = Self.makeM31Evaluations(count: 257, salt: 131)
        var rhs = Self.makeM31Evaluations(count: 257, salt: 197)
        lhs.replaceSubrange(0..<5, with: [0, 1, 2, M31Field.modulus - 2, M31Field.modulus - 1])
        rhs.replaceSubrange(0..<5, with: [0, M31Field.modulus - 1, M31Field.modulus - 2, 2, 1])

        for operation in M31VectorOperation.allCases {
            let operationLHS = operation == .inverse
                ? lhs.map { $0 == 0 ? UInt32(1) : $0 }
                : lhs
            let operationRHS = operation.requiresRightHandSide ? rhs : nil
            let plan = try M31VectorArithmeticPlan(
                context: context,
                operation: operation,
                count: operationLHS.count
            )
            let measured = try plan.executeVerified(
                lhs: operationLHS,
                rhs: operationRHS
            )
            let expected = try M31Field.apply(
                operation,
                lhs: operationLHS,
                rhs: operationRHS
            )

            XCTAssertEqual(measured.values, expected, "M31 \(operation) mismatch")
            if operation == .inverse {
                for (value, inverse) in zip(operationLHS, measured.values) {
                    XCTAssertEqual(M31Field.multiply(value, inverse), 1)
                }
            }
            try plan.clearReusableBuffers()

            let reusedLHS = operation == .inverse
                ? rhs.map { $0 == 0 ? UInt32(1) : $0 }
                : rhs
            let reusedRHS = operation.requiresRightHandSide ? lhs : nil
            let reused = try plan.executeVerified(
                lhs: reusedLHS,
                rhs: reusedRHS
            )
            let reusedExpected = try M31Field.apply(
                operation,
                lhs: reusedLHS,
                rhs: reusedRHS
            )
            XCTAssertEqual(reused.values, reusedExpected, "M31 \(operation) mismatch after clear/reuse")
        }
    }

    func testM31VectorArithmeticRejectsInvalidLayouts() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        XCTAssertThrowsError(try M31VectorArithmeticPlan(context: context, operation: .add, count: 0)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let plan = try M31VectorArithmeticPlan(context: context, operation: .add, count: 2)
        XCTAssertThrowsError(try plan.execute(lhs: [0, 1], rhs: nil)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try plan.execute(lhs: [0, M31Field.modulus], rhs: [0, 1])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        let unaryPlan = try M31VectorArithmeticPlan(context: context, operation: .square, count: 2)
        XCTAssertThrowsError(try unaryPlan.execute(lhs: [0, 1], rhs: [0, 1])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        let inversePlan = try M31VectorArithmeticPlan(context: context, operation: .inverse, count: 2)
        XCTAssertThrowsError(try inversePlan.execute(lhs: [0, 1])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testCM31VectorArithmeticPlansMatchCPUOracle() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        var lhs = Self.makeCM31Evaluations(count: 257, realSalt: 331, imaginarySalt: 337)
        var rhs = Self.makeCM31Evaluations(count: 257, realSalt: 397, imaginarySalt: 401)
        lhs.replaceSubrange(0..<5, with: [
            CM31Element(real: 0, imaginary: 0),
            CM31Element(real: 1, imaginary: 0),
            CM31Element(real: 0, imaginary: 1),
            CM31Element(real: CM31Field.modulus - 1, imaginary: 0),
            CM31Element(real: CM31Field.modulus - 1, imaginary: CM31Field.modulus - 1),
        ])
        rhs.replaceSubrange(0..<5, with: [
            CM31Element(real: 0, imaginary: 0),
            CM31Element(real: 0, imaginary: 1),
            CM31Element(real: 0, imaginary: 1),
            CM31Element(real: CM31Field.modulus - 1, imaginary: CM31Field.modulus - 1),
            CM31Element(real: 1, imaginary: CM31Field.modulus - 1),
        ])

        for operation in CM31VectorOperation.allCases {
            let operationRHS = operation.requiresRightHandSide ? rhs : nil
            let plan = try CM31VectorArithmeticPlan(
                context: context,
                operation: operation,
                count: lhs.count
            )
            let measured = try plan.executeVerified(lhs: lhs, rhs: operationRHS)
            let expected = try CM31Field.apply(operation, lhs: lhs, rhs: operationRHS)
            XCTAssertEqual(measured.values, expected, "CM31 \(operation) mismatch")

            try plan.clearReusableBuffers()
            let reusedRHS = operation.requiresRightHandSide ? lhs : nil
            let reused = try plan.executeVerified(lhs: rhs, rhs: reusedRHS)
            let reusedExpected = try CM31Field.apply(operation, lhs: rhs, rhs: reusedRHS)
            XCTAssertEqual(reused.values, reusedExpected, "CM31 \(operation) mismatch after clear/reuse")
        }
    }

    func testCM31VectorArithmeticRejectsInvalidLayouts() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        XCTAssertThrowsError(try CM31VectorArithmeticPlan(context: context, operation: .multiply, count: 0)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let binaryPlan = try CM31VectorArithmeticPlan(context: context, operation: .multiply, count: 2)
        XCTAssertThrowsError(
            try binaryPlan.execute(
                lhs: [CM31Element(real: 0, imaginary: 0), CM31Element(real: 1, imaginary: 1)]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try binaryPlan.execute(
                lhs: [CM31Element(real: 0, imaginary: CM31Field.modulus), CM31Element(real: 1, imaginary: 1)],
                rhs: [CM31Element(real: 0, imaginary: 0), CM31Element(real: 1, imaginary: 1)]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let unaryPlan = try CM31VectorArithmeticPlan(context: context, operation: .square, count: 2)
        XCTAssertThrowsError(
            try unaryPlan.execute(
                lhs: [CM31Element(real: 0, imaginary: 0), CM31Element(real: 1, imaginary: 1)],
                rhs: [CM31Element(real: 0, imaginary: 0), CM31Element(real: 1, imaginary: 1)]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testQM31VectorArithmeticPlansMatchCPUOracleAndUploadedHotPath() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        var lhs = Self.makeQM31Evaluations(count: 257, aSalt: 503, bSalt: 509, cSalt: 521, dSalt: 523)
        var rhs = Self.makeQM31Evaluations(count: 257, aSalt: 541, bSalt: 547, cSalt: 557, dSalt: 563)
        lhs.replaceSubrange(0..<4, with: [
            QM31Element(a: 0, b: 0, c: 0, d: 0),
            QM31Element(a: 1, b: 0, c: 0, d: 0),
            QM31Element(a: 1, b: 2, c: 3, d: 4),
            QM31Element(a: QM31Field.modulus - 1, b: 1, c: 0, d: QM31Field.modulus - 1),
        ])
        rhs.replaceSubrange(0..<4, with: [
            QM31Element(a: 0, b: 0, c: 0, d: 0),
            QM31Element(a: 0, b: 1, c: 0, d: 0),
            QM31Element(a: 4, b: 5, c: 6, d: 7),
            QM31Element(a: 2, b: QM31Field.modulus - 1, c: 1, d: 1),
        ])

        for operation in QM31VectorOperation.allCases {
            let operationLHS = operation == .inverse
                ? lhs.map { QM31Field.isZero($0) ? QM31Element(a: 1, b: 0, c: 0, d: 0) : $0 }
                : lhs
            let operationRHS = operation.requiresRightHandSide ? rhs : nil
            let plan = try QM31VectorArithmeticPlan(
                context: context,
                operation: operation,
                count: operationLHS.count
            )
            let measured = try plan.executeVerified(lhs: operationLHS, rhs: operationRHS)
            let expected = try QM31Field.apply(operation, lhs: operationLHS, rhs: operationRHS)
            XCTAssertEqual(measured.values, expected, "QM31 \(operation) mismatch")
            if operation == .inverse {
                for (value, inverse) in zip(operationLHS, measured.values) {
                    XCTAssertEqual(QM31Field.multiply(value, inverse), QM31Element(a: 1, b: 0, c: 0, d: 0))
                }
            }

            try plan.clearReusableBuffers()
            let reusedLHS = operation == .inverse
                ? rhs.map { QM31Field.isZero($0) ? QM31Element(a: 1, b: 0, c: 0, d: 0) : $0 }
                : rhs
            let reusedRHS = operation.requiresRightHandSide ? lhs : nil
            let reused = try plan.executeVerified(lhs: reusedLHS, rhs: reusedRHS)
            let reusedExpected = try QM31Field.apply(operation, lhs: reusedLHS, rhs: reusedRHS)
            XCTAssertEqual(reused.values, reusedExpected, "QM31 \(operation) mismatch after clear/reuse")
        }

        let uploadPlan = try QM31VectorArithmeticPlan(context: context, operation: .multiply, count: lhs.count)
        let lhsUpload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packQM31LittleEndian(lhs),
            declaredLength: lhs.count * 4 * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.QM31VectorLHS"
        )
        let rhsUpload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packQM31LittleEndian(rhs),
            declaredLength: rhs.count * 4 * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.QM31VectorRHS"
        )
        let uploaded = try uploadPlan.executeUploadedVectors(
            lhsBuffer: lhsUpload,
            rhsBuffer: rhsUpload
        )
        XCTAssertEqual(uploaded.values, try QM31Field.apply(.multiply, lhs: lhs, rhs: rhs))
    }

    func testQM31VectorArithmeticRejectsInvalidLayouts() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        XCTAssertThrowsError(try QM31VectorArithmeticPlan(context: context, operation: .multiply, count: 0)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let binaryPlan = try QM31VectorArithmeticPlan(context: context, operation: .multiply, count: 2)
        XCTAssertThrowsError(
            try binaryPlan.execute(
                lhs: [QM31Element(a: 0, b: 0, c: 0, d: 0), QM31Element(a: 1, b: 0, c: 0, d: 0)]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try binaryPlan.execute(
                lhs: [QM31Element(a: 0, b: QM31Field.modulus, c: 0, d: 0), QM31Element(a: 1, b: 0, c: 0, d: 0)],
                rhs: [QM31Element(a: 0, b: 0, c: 0, d: 0), QM31Element(a: 1, b: 0, c: 0, d: 0)]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let inversePlan = try QM31VectorArithmeticPlan(context: context, operation: .inverse, count: 2)
        XCTAssertThrowsError(
            try inversePlan.execute(
                lhs: [QM31Element(a: 0, b: 0, c: 0, d: 0), QM31Element(a: 1, b: 0, c: 0, d: 0)]
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let shortUpload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packQM31LittleEndian([QM31Element(a: 1, b: 0, c: 0, d: 0)]),
            declaredLength: 4 * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.QM31VectorShortUpload"
        )
        XCTAssertThrowsError(
            try binaryPlan.executeUploadedVectors(lhsBuffer: shortUpload, rhsBuffer: shortUpload)
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testQM31FRIFoldPlanMatchesCPUOracleAndResidentHotPath() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        let inputCount = 258
        var evaluations = Self.makeQM31Evaluations(
            count: inputCount,
            aSalt: 701,
            bSalt: 709,
            cSalt: 719,
            dSalt: 727
        )
        evaluations.replaceSubrange(0..<4, with: [
            QM31Element(a: 1, b: 2, c: 3, d: 4),
            QM31Element(a: 4, b: 5, c: 6, d: 7),
            QM31Element(a: 9, b: 8, c: 7, d: 6),
            QM31Element(a: 9, b: 8, c: 7, d: 6),
        ])
        let inverseDomainPoints = Self.makeQM31Evaluations(
            count: inputCount / 2,
            aSalt: 733,
            bSalt: 739,
            cSalt: 743,
            dSalt: 751
        ).map { QM31Field.isZero($0) ? QM31Element(a: 1, b: 0, c: 0, d: 0) : $0 }
        let challenge = QM31Element(a: 9, b: 7, c: 5, d: 3)
        let expected = try QM31FRIFoldOracle.fold(
            evaluations: evaluations,
            inverseDomainPoints: inverseDomainPoints,
            challenge: challenge
        )

        let plan = try QM31FRIFoldPlan(context: context, inputCount: inputCount)
        XCTAssertEqual(plan.outputCount, inputCount / 2)
        let measured = try plan.executeVerified(
            evaluations: evaluations,
            inverseDomainPoints: inverseDomainPoints,
            challenge: challenge
        )
        XCTAssertEqual(measured.values, expected)

        try plan.clearReusableBuffers()
        let reversedEvaluations = Array(evaluations.reversed())
        let reused = try plan.executeVerified(
            evaluations: reversedEvaluations,
            inverseDomainPoints: inverseDomainPoints,
            challenge: challenge
        )
        XCTAssertEqual(
            reused.values,
            try QM31FRIFoldOracle.fold(
                evaluations: reversedEvaluations,
                inverseDomainPoints: inverseDomainPoints,
                challenge: challenge
            )
        )

        let evaluationBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packQM31LittleEndian(evaluations),
            declaredLength: inputCount * 4 * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.QM31FRIFoldEvaluations"
        )
        let inverseDomainBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packQM31LittleEndian(inverseDomainPoints),
            declaredLength: inverseDomainPoints.count * 4 * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.QM31FRIFoldInverseDomain"
        )
        let outputBuffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: expected.count * 4 * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.QM31FRIFoldOutput"
        )

        _ = try plan.executeResident(
            evaluationsBuffer: evaluationBuffer,
            inverseDomainBuffer: inverseDomainBuffer,
            outputBuffer: outputBuffer,
            challenge: challenge
        )
        XCTAssertEqual(Self.readQM31Buffer(outputBuffer, count: expected.count), expected)
    }

    func testQM31FRIFoldRejectsInvalidLayouts() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        XCTAssertThrowsError(try QM31FRIFoldPlan(context: context, inputCount: 0)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try QM31FRIFoldPlan(context: context, inputCount: 3)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let plan = try QM31FRIFoldPlan(context: context, inputCount: 2)
        let one = QM31Element(a: 1, b: 0, c: 0, d: 0)
        let zero = QM31Element(a: 0, b: 0, c: 0, d: 0)
        XCTAssertThrowsError(
            try plan.execute(
                evaluations: [one, one],
                inverseDomainPoints: [zero],
                challenge: one
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try plan.execute(
                evaluations: [one, QM31Element(a: QM31Field.modulus, b: 0, c: 0, d: 0)],
                inverseDomainPoints: [one],
                challenge: one
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let shortUpload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packQM31LittleEndian([one]),
            declaredLength: 4 * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.QM31FRIFoldShortUpload"
        )
        let output = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: 4 * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.QM31FRIFoldShortOutput"
        )
        XCTAssertThrowsError(
            try plan.executeResident(
                evaluationsBuffer: shortUpload,
                inverseDomainBuffer: shortUpload,
                outputBuffer: output,
                challenge: one
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try plan.executeResident(
                evaluationsBuffer: shortUpload,
                inverseDomainBuffer: shortUpload,
                outputBuffer: output,
                challenge: QM31Element(a: QM31Field.modulus, b: 0, c: 0, d: 0)
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let fullUpload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packQM31LittleEndian([one, one]),
            declaredLength: 8 * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.QM31FRIFoldAliasedUpload"
        )
        XCTAssertThrowsError(
            try plan.executeResident(
                evaluationsBuffer: fullUpload,
                inverseDomainBuffer: shortUpload,
                outputBuffer: fullUpload,
                challenge: one
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(
            try plan.executeResident(
                evaluationsBuffer: fullUpload,
                inverseDomainBuffer: shortUpload,
                outputBuffer: shortUpload,
                challenge: one
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testM31DotProductPlanMatchesCPUOracleAndUploadedHotPath() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        var lhs = Self.makeM31Evaluations(count: 4097, salt: 313)
        var rhs = Self.makeM31Evaluations(count: 4097, salt: 571)
        lhs.replaceSubrange(0..<5, with: [0, 1, 2, M31Field.modulus - 2, M31Field.modulus - 1])
        rhs.replaceSubrange(0..<5, with: [0, M31Field.modulus - 1, M31Field.modulus - 2, 2, 1])

        let plan = try M31DotProductPlan(context: context, count: lhs.count)
        let measured = try plan.executeVerified(lhs: lhs, rhs: rhs)
        XCTAssertEqual(measured.value, try M31Field.dotProduct(lhs: lhs, rhs: rhs))
        XCTAssertGreaterThan(plan.threadsPerThreadgroup, 0)
        XCTAssertGreaterThan(plan.elementsPerThreadgroup, plan.threadsPerThreadgroup - 1)

        try plan.clearReusableBuffers()
        let reused = try plan.executeVerified(lhs: rhs, rhs: lhs)
        XCTAssertEqual(reused.value, try M31Field.dotProduct(lhs: rhs, rhs: lhs))

        let lhsUpload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packUInt32LittleEndian(lhs),
            declaredLength: lhs.count * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.M31DotProductLHS"
        )
        let rhsUpload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packUInt32LittleEndian(rhs),
            declaredLength: rhs.count * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.M31DotProductRHS"
        )
        let uploaded = try plan.executeUploadedVectors(lhsBuffer: lhsUpload, rhsBuffer: rhsUpload)
        XCTAssertEqual(uploaded.value, try M31Field.dotProduct(lhs: lhs, rhs: rhs))
    }

    func testM31DotProductRejectsInvalidLayouts() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        XCTAssertThrowsError(try M31DotProductPlan(context: context, count: 0)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try M31DotProductPlan(context: context, count: 2, elementsPerThread: 0)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let plan = try M31DotProductPlan(context: context, count: 2)
        XCTAssertThrowsError(try plan.execute(lhs: [0, 1], rhs: [0])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try plan.execute(lhs: [0, M31Field.modulus], rhs: [0, 1])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        let shortUpload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packUInt32LittleEndian([0]),
            declaredLength: MemoryLayout<UInt32>.stride,
            label: "PlannerTests.M31DotProductShortUpload"
        )
        XCTAssertThrowsError(
            try plan.executeUploadedVectors(lhsBuffer: shortUpload, rhsBuffer: shortUpload)
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testSumcheckChunkVerifiedExecutionMatchesCPUOracle() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let evaluations = Self.makeM31Evaluations(count: 64, salt: 79)
        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        let plan = try planner.makeSumcheckChunkPlan(laneCount: evaluations.count, roundsPerSuperstep: 3)
        let measured = try plan.executeVerified(evaluations: evaluations)
        let expected = try SumcheckOracle.m31Chunk(evaluations: evaluations, rounds: 3)

        XCTAssertEqual(measured.result, expected)
    }

    func testSumcheckChunkAcceptsUploadedVectorHotPath() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let evaluations = Self.makeM31Evaluations(count: 16, salt: 7)
        let expected = try SumcheckOracle.m31Chunk(evaluations: evaluations, rounds: 2)
        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        let plan = try planner.makeSumcheckChunkPlan(laneCount: evaluations.count, roundsPerSuperstep: 2)
        let upload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: Self.packUInt32LittleEndian(evaluations),
            declaredLength: evaluations.count * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.SumcheckUpload"
        )

        let measured = try plan.executeUploadedVector(buffer: upload)
        XCTAssertEqual(measured.result.finalVector, expected.finalVector)
        XCTAssertEqual(measured.result.coefficients, expected.coefficients)
        XCTAssertEqual(measured.result.challenges, expected.challenges)
    }

    func testSumcheckChunkSupportsMultiBlockTranscriptAbsorb() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let evaluations = Self.makeM31Evaluations(count: 64, salt: 103)
        let expected = try SumcheckOracle.m31Chunk(evaluations: evaluations, rounds: 1)
        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        let plan = try planner.makeSumcheckChunkPlan(laneCount: evaluations.count, roundsPerSuperstep: 1)

        let measured = try plan.execute(evaluations: evaluations)
        XCTAssertEqual(measured.result.finalVector, expected.finalVector)
        XCTAssertEqual(measured.result.coefficients, expected.coefficients)
        XCTAssertEqual(measured.result.challenges, expected.challenges)
    }

    func testSumcheckChunkRandomizedLargerLaneBatches() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        let cases = [
            (laneCount: 64, rounds: 2, salt: UInt32(19)),
            (laneCount: 128, rounds: 4, salt: UInt32(23)),
            (laneCount: 256, rounds: 5, salt: UInt32(31)),
        ]

        for testCase in cases {
            let evaluations = Self.makeM31Evaluations(count: testCase.laneCount, salt: testCase.salt)
            let expected = try SumcheckOracle.m31Chunk(evaluations: evaluations, rounds: testCase.rounds)
            let plan = try planner.makeSumcheckChunkPlan(
                laneCount: testCase.laneCount,
                roundsPerSuperstep: testCase.rounds
            )

            let measured = try plan.execute(evaluations: evaluations)
            XCTAssertEqual(measured.result.finalVector, expected.finalVector)
            XCTAssertEqual(measured.result.coefficients, expected.coefficients)
            XCTAssertEqual(measured.result.challenges, expected.challenges)
        }
    }

    func testSumcheckChunkRejectsInvalidRoundLayout() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let planner = MetalProofPlanner(context: try MetalContext(device: device))
        XCTAssertThrowsError(
            try planner.makeSumcheckChunkPlan(laneCount: 64, roundsPerSuperstep: 0)
        )
        XCTAssertThrowsError(
            try planner.makeSumcheckChunkPlan(laneCount: 96, roundsPerSuperstep: 1)
        )
        XCTAssertThrowsError(
            try planner.makeSumcheckChunkPlan(laneCount: 64, roundsPerSuperstep: 7)
        )
    }

    func testGPUTranscriptSqueezeMatchesCPUAcrossSqueezeBlocks() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let bytes = Data((0..<513).map { UInt8(truncatingIfNeeded: $0 &* 31) })
        var cpuTranscript = SHA3Oracle.TranscriptState()
        try cpuTranscript.absorb(bytes)
        let expected = try cpuTranscript.squeezeUInt32(count: 40, modulus: M31Field.modulus)

        let context = try MetalContext(device: device)
        let arena = try ResidencyArena(device: device, capacity: 4096, label: "PlannerTests.TranscriptArena")
        let transcript = try TranscriptEngine(context: context, arena: arena)
        let packed = try arena.allocate(length: bytes.count, role: .scratch)
        let challenges = try arena.allocate(
            length: expected.count * MemoryLayout<UInt32>.stride,
            role: .challenges
        )
        let upload = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: bytes,
            declaredLength: bytes.count,
            label: "PlannerTests.TranscriptUpload"
        )
        let readback = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: expected.count * MemoryLayout<UInt32>.stride,
            label: "PlannerTests.TranscriptReadback"
        )

        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        try transcript.encodeReset(on: commandBuffer)
        try transcript.encodeCanonicalPack(
            input: upload,
            output: packed,
            byteCount: bytes.count,
            on: commandBuffer
        )
        try transcript.encodeAbsorb(packed: packed, byteCount: bytes.count, on: commandBuffer)
        try transcript.encodeSqueezeChallenges(
            output: challenges,
            challengeCount: expected.count,
            fieldModulus: M31Field.modulus,
            on: commandBuffer
        )
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        blit.copy(
            from: challenges.buffer,
            sourceOffset: challenges.offset,
            to: readback,
            destinationOffset: 0,
            size: expected.count * MemoryLayout<UInt32>.stride
        )
        blit.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let words = readback.contents().bindMemory(to: UInt32.self, capacity: expected.count)
        let actual = (0..<expected.count).map { words[$0] }
        XCTAssertEqual(actual, expected)
    }

    func testGPUTranscriptEngineRejectsInvalidChallengeLayouts() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext(device: device)
        let arena = try ResidencyArena(device: device, capacity: 1024, label: "PlannerTests.InvalidTranscriptArena")
        let transcript = try TranscriptEngine(context: context, arena: arena)
        let emptyOutput = try arena.allocate(length: 0, role: .challenges)
        let oneWordOutput = try arena.allocate(length: MemoryLayout<UInt32>.stride, role: .challenges)
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }

        XCTAssertThrowsError(
            try transcript.encodeSqueezeChallenges(
                output: emptyOutput,
                challengeCount: 1,
                fieldModulus: M31Field.modulus,
                on: commandBuffer
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }

        XCTAssertThrowsError(
            try transcript.encodeSqueezeChallenges(
                output: oneWordOutput,
                challengeCount: 1,
                fieldModulus: 0,
                on: commandBuffer
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }
    #endif

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AppleZKProverTests-\(UUID().uuidString)")
            .appendingPathComponent("plans.sqlite")
    }

    private func makePlanRecord(
        medianGPUTimeNS: Double,
        medianCPUSubmitNS: Double
    ) -> PlanRecord {
        let device = DeviceFingerprint(
            registryID: 123,
            name: "Test GPU",
            osBuild: "test-os",
            supportsApple4: true,
            supportsApple7: true,
            supportsApple9: false,
            supportsMetal4Queue: false,
            maxThreadsPerThreadgroup: 1024,
            hasUnifiedMemory: true
        )
        let workload = WorkloadSignature(
            stage: .merkleCommit,
            field: .bytes,
            inputLog2: 10,
            leafBytes: 32,
            arity: 2,
            roundsPerSuperstep: 1,
            fixedWidthCase: 32
        )
        let treelet = MerkleKernelSpecs.treeletLeaves(leafBytes: 32, depth: 3)
        return PlanRecord(
            device: device,
            workload: workload,
            winner: treelet,
            medianGPUTimeNS: medianGPUTimeNS,
            medianCPUSubmitNS: medianCPUSubmitNS,
            p95GPUTimeNS: medianGPUTimeNS,
            readbacks: 1,
            confidence: 1,
            shaderHash: "shader",
            protocolHash: "protocol"
        )
    }

    private static func makeLeaves(count: Int, leafLength: Int, salt: Int = 0) -> Data {
        var bytes = [UInt8](repeating: 0xa5, count: count * leafLength)
        for leaf in 0..<count {
            for j in 0..<leafLength {
                bytes[leaf * leafLength + j] = UInt8(truncatingIfNeeded: (leaf &* 29) &+ (j &* 7) &+ salt &+ 3)
            }
        }
        return Data(bytes)
    }

    private static func makeM31Evaluations(count: Int, salt: UInt32) -> [UInt32] {
        (0..<count).map { index in
            let value = UInt64(index + 1) * 1_048_573 + UInt64(salt) * 65_537
            return UInt32(value % UInt64(M31Field.modulus))
        }
    }

    private static func makeCM31Evaluations(
        count: Int,
        realSalt: UInt32,
        imaginarySalt: UInt32
    ) -> [CM31Element] {
        let real = makeM31Evaluations(count: count, salt: realSalt)
        let imaginary = makeM31Evaluations(count: count, salt: imaginarySalt)
        return zip(real, imaginary).map { CM31Element(real: $0, imaginary: $1) }
    }

    private static func makeQM31Evaluations(
        count: Int,
        aSalt: UInt32,
        bSalt: UInt32,
        cSalt: UInt32,
        dSalt: UInt32
    ) -> [QM31Element] {
        let a = makeM31Evaluations(count: count, salt: aSalt)
        let b = makeM31Evaluations(count: count, salt: bSalt)
        let c = makeM31Evaluations(count: count, salt: cSalt)
        let d = makeM31Evaluations(count: count, salt: dSalt)
        return (0..<count).map { index in
            QM31Element(a: a[index], b: b[index], c: c[index], d: d[index])
        }
    }

    private static func packUInt32LittleEndian(_ values: [UInt32]) -> Data {
        var data = Data()
        data.reserveCapacity(values.count * MemoryLayout<UInt32>.stride)
        for value in values {
            data.append(UInt8(value & 0xff))
            data.append(UInt8((value >> 8) & 0xff))
            data.append(UInt8((value >> 16) & 0xff))
            data.append(UInt8((value >> 24) & 0xff))
        }
        return data
    }

    private static func packQM31LittleEndian(_ values: [QM31Element]) -> Data {
        var data = Data()
        data.reserveCapacity(values.count * 4 * MemoryLayout<UInt32>.stride)
        for value in values {
            data.append(UInt8(value.constant.real & 0xff))
            data.append(UInt8((value.constant.real >> 8) & 0xff))
            data.append(UInt8((value.constant.real >> 16) & 0xff))
            data.append(UInt8((value.constant.real >> 24) & 0xff))
            data.append(UInt8(value.constant.imaginary & 0xff))
            data.append(UInt8((value.constant.imaginary >> 8) & 0xff))
            data.append(UInt8((value.constant.imaginary >> 16) & 0xff))
            data.append(UInt8((value.constant.imaginary >> 24) & 0xff))
            data.append(UInt8(value.uCoefficient.real & 0xff))
            data.append(UInt8((value.uCoefficient.real >> 8) & 0xff))
            data.append(UInt8((value.uCoefficient.real >> 16) & 0xff))
            data.append(UInt8((value.uCoefficient.real >> 24) & 0xff))
            data.append(UInt8(value.uCoefficient.imaginary & 0xff))
            data.append(UInt8((value.uCoefficient.imaginary >> 8) & 0xff))
            data.append(UInt8((value.uCoefficient.imaginary >> 16) & 0xff))
            data.append(UInt8((value.uCoefficient.imaginary >> 24) & 0xff))
        }
        return data
    }

    #if canImport(Metal)
    private static func readBytes(_ buffer: MTLBuffer, offset: Int, count: Int) -> [UInt8] {
        let bytes = buffer.contents()
            .advanced(by: offset)
            .bindMemory(to: UInt8.self, capacity: count)
        return (0..<count).map { bytes[$0] }
    }

    private static func readQM31Buffer(_ buffer: MTLBuffer, count: Int) -> [QM31Element] {
        let words = buffer.contents().bindMemory(to: UInt32.self, capacity: count * 4)
        return (0..<count).map { index in
            QM31Element(
                a: words[index * 4],
                b: words[index * 4 + 1],
                c: words[index * 4 + 2],
                d: words[index * 4 + 3]
            )
        }
    }
    #endif
}
