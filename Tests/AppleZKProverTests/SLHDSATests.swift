import CryptoKit
import XCTest
@testable import AppleZKProver

final class SLHDSATests: XCTestCase {
    func testParameterSetSizesMatchFIPS205Table2() {
        let expected: [SLHDSA.ParameterSet: (pk: Int, sig: Int)] = [
            .sha2_128s: (32, 7_856),
            .shake_128s: (32, 7_856),
            .sha2_128f: (32, 17_088),
            .shake_128f: (32, 17_088),
            .sha2_192s: (48, 16_224),
            .shake_192s: (48, 16_224),
            .sha2_192f: (48, 35_664),
            .shake_192f: (48, 35_664),
            .sha2_256s: (64, 29_792),
            .shake_256s: (64, 29_792),
            .sha2_256f: (64, 49_856),
            .shake_256f: (64, 49_856),
        ]

        XCTAssertEqual(SLHDSA.ParameterSet.allCases.count, 12)
        XCTAssertEqual(SLHDSA.PreHashFunction.allCases.count, 12)
        for parameterSet in SLHDSA.ParameterSet.allCases {
            let parameters = parameterSet.parameters
            XCTAssertEqual(parameters.publicKeyByteCount, expected[parameterSet]?.pk, parameterSet.rawValue)
            XCTAssertEqual(parameters.signatureByteCount, expected[parameterSet]?.sig, parameterSet.rawValue)
            XCTAssertEqual(parameters.privateKeyByteCount, 4 * parameters.n, parameterSet.rawValue)
        }
    }

    func testStructuredParsersRejectNonExactLengthsAndExposeLayouts() throws {
        let parameterSet = SLHDSA.ParameterSet.sha2_128f
        let n = parameterSet.parameters.n
        let skSeed = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 3 + 1) })
        let skPrf = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 5 + 2) })
        let pkSeed = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 7 + 3) })
        let randomness = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 11 + 4) })
        let pair = try SLHDSA.keygenInternalStructured(
            parameterSet: parameterSet,
            skSeed: skSeed,
            skPrf: skPrf,
            pkSeed: pkSeed
        )
        let signature = try SLHDSA.sign(
            message: Data("abc".utf8),
            context: Data("ctx".utf8),
            privateKey: pair.privateKey,
            additionalRandomness: randomness
        )

        XCTAssertEqual(pair.publicKey.encoded.count, parameterSet.parameters.publicKeyByteCount)
        XCTAssertEqual(pair.privateKey.encoded.count, parameterSet.parameters.privateKeyByteCount)
        XCTAssertEqual(signature.encoded.count, parameterSet.parameters.signatureByteCount)
        XCTAssertTrue(try SLHDSA.slh_verify(
            message: Data("abc".utf8),
            signature: signature,
            context: Data("ctx".utf8),
            publicKey: pair.publicKey
        ))
        XCTAssertTrue(try SLHDSA.slh_verify(
            message: Data("abc".utf8),
            signature: signature.encoded,
            context: Data("ctx".utf8),
            publicKey: pair.publicKey.encoded,
            parameterSet: parameterSet
        ))
        XCTAssertTrue(try SLHDSA.slh_verify_internal(
            message: Data([0, 3]) + Data("ctxabc".utf8),
            signature: signature.encoded,
            publicKey: pair.publicKey.encoded,
            parameterSet: parameterSet
        ))

        XCTAssertThrowsError(try SLHDSA.PublicKey(encoded: pair.publicKey.encoded.dropLast(), parameterSet: parameterSet))
        XCTAssertThrowsError(try SLHDSA.PrivateKey(encoded: pair.privateKey.encoded.dropLast(), parameterSet: parameterSet))
        XCTAssertThrowsError(try SLHDSA.Signature(encoded: signature.encoded.dropLast(), parameterSet: parameterSet))
        XCTAssertThrowsError(try SLHDSA.slh_verify(
            message: Data("abc".utf8),
            signature: signature.encoded.dropLast(),
            context: Data("ctx".utf8),
            publicKey: pair.publicKey.encoded,
            parameterSet: parameterSet
        ))

        let layout = SLHDSA.ComponentLayout(parameterSet: parameterSet)
        XCTAssertEqual(layout.forsSignatureBytes + layout.hypertreeSignatureBytes + layout.randomnessBytes, layout.signatureBytes)
        XCTAssertEqual(layout.compressedSHA2AddressBytes, 22)
    }

    func testFIPSHelpersAndArithmetizationDescriptors() throws {
        XCTAssertEqual(try SLHDSA.FIPSHelper.to_byte(0x0102, byteCount: 2).hexString, "0102")
        XCTAssertEqual(try SLHDSA.FIPSHelper.to_int(Data([0x01, 0x02])), 0x0102)
        XCTAssertEqual(try SLHDSA.FIPSHelper.base_2b(Data([0xab]), bits: 4, outputLength: 2), [10, 11])
        XCTAssertEqual(
            SLHDSA.PreHashFunction.sha2_256.derEncodedOID.hexString,
            "0609608648016503040201"
        )
        XCTAssertEqual(SLHDSA.PreHashFunction.sha2_256.phOID, SLHDSA.PreHashFunction.sha2_256.derEncodedOID)
        XCTAssertEqual(SLHDSA.DomainSeparator.pure, 0)
        XCTAssertEqual(SLHDSA.DomainSeparator.preHash, 1)

        var address = SLHDSA.Address()
        address.setLayerAddress(1)
        address.setTreeAddress(0x0203)
        address.setTypeAndClear(.wotsHash)
        address.setKeyPairAddress(4)
        address.setChainAddress(5)
        address.setHashAddress(6)
        XCTAssertEqual(address.encoded.count, 32)
        XCTAssertEqual(address.compressedSHA2Encoded.count, 22)

        let plan = SLHDSA.ArithmetizationPlan(parameterSet: .sha2_128f)
        XCTAssertEqual(plan.descriptors.count, SLHDSA.ArithmetizationGadget.allCases.count)
        XCTAssertEqual(
            SLHDSA.VerificationSurface.slhVerifyInternal
                .descriptor(parameters: SLHDSA.ParameterSet.sha2_128f.parameters)
                .inputByteCount,
            SLHDSA.ParameterSet.sha2_128f.parameters.signatureByteCount +
            SLHDSA.ParameterSet.sha2_128f.parameters.publicKeyByteCount
        )
    }

    func testSHAKEVectors() throws {
        XCTAssertEqual(
            try SHA3Oracle.shake128(Data(), outputByteCount: 32).hexString,
            "7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26"
        )
        XCTAssertEqual(
            try SHA3Oracle.shake256(Data(), outputByteCount: 64).hexString,
            "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f" +
            "d75dc4ddd8c0f200cb05019d67b592f6fc821c49479ab48640292eacb3b7c4be"
        )
    }

    func testSHAKE128fReferenceVectorAndTamperRejection() throws {
        try assertReferenceVector(
            parameterSet: .shake_128f,
            expectedPublicKeyHex: "030a11181f262d343b424950575e656c20b5b936bb3425dd9dc5d6aff657fd9d",
            expectedSignatureDigestHex: "235b637399fac2ed88a585564f1c0dbe94ca9fb6d476a2a7edc8e3f7351a8121"
        )
    }

    func testSHA2128fReferenceVectorAndTamperRejection() throws {
        try assertReferenceVector(
            parameterSet: .sha2_128f,
            expectedPublicKeyHex: "030a11181f262d343b424950575e656c8198b58ef7a43e5c38f3f7b63ddfbe1e",
            expectedSignatureDigestHex: "1a0d8ef3bc1397400c22400267da45b5c52cd4fba9f7cadb6f8e28d8e4c8b5eb"
        )
    }

    func testPreHashReferenceVectors() throws {
        try assertPreHashReferenceVector(
            preHashFunction: .sha2_512_256,
            expectedSignatureDigestHex: "2bb52b63f9954b758a8301f4640aa13562245ac38c399d5c812ea205cd1b96bb"
        )
        try assertPreHashReferenceVector(
            preHashFunction: .sha3_512,
            expectedSignatureDigestHex: "eb3ad67fc02af43125ffff8334f4372291094242fd368bec045356b5eb80e20b"
        )
        try assertPreHashReferenceVector(
            preHashFunction: .shake256,
            expectedSignatureDigestHex: "1116991c7c42afebebed7b400e0d48a6d767e99c88b68de18ae954d7e5db9be7"
        )
    }

    func testPublicAPIRejectsMalformedInputsAndSeparatesDomains() throws {
        let parameterSet = SLHDSA.ParameterSet.sha2_128f
        let n = parameterSet.parameters.n
        let skSeed = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 3 + 1) })
        let skPrf = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 5 + 2) })
        let pkSeed = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 7 + 3) })
        let randomness = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 11 + 4) })
        let message = Data("abc".utf8)
        let context = Data("ctx".utf8)
        let keyPair = try SLHDSA.keygenInternal(
            parameterSet: parameterSet,
            skSeed: skSeed,
            skPrf: skPrf,
            pkSeed: pkSeed
        )

        let signature = try SLHDSA.sign(
            message: message,
            context: context,
            privateKey: keyPair.privateKey,
            parameterSet: parameterSet,
            additionalRandomness: randomness
        )
        let preHashSignature = try SLHDSA.hashSign(
            message: message,
            context: context,
            preHashFunction: .sha2_256,
            privateKey: keyPair.privateKey,
            parameterSet: parameterSet,
            additionalRandomness: randomness
        )

        XCTAssertFalse(try SLHDSA.verify(
            message: message,
            signature: signature.dropLast(),
            context: context,
            publicKey: keyPair.publicKey,
            parameterSet: parameterSet
        ))
        XCTAssertFalse(try SLHDSA.verify(
            message: message,
            signature: signature,
            context: context,
            publicKey: keyPair.publicKey.dropLast(),
            parameterSet: parameterSet
        ))
        XCTAssertFalse(try SLHDSA.verify(
            message: message,
            signature: preHashSignature,
            context: context,
            publicKey: keyPair.publicKey,
            parameterSet: parameterSet
        ))
        XCTAssertFalse(try SLHDSA.hashVerify(
            message: message,
            signature: signature,
            context: context,
            preHashFunction: .sha2_256,
            publicKey: keyPair.publicKey,
            parameterSet: parameterSet
        ))

        let oversizedContext = Data(repeating: 0x42, count: 256)
        XCTAssertThrowsError(try SLHDSA.sign(
            message: message,
            context: oversizedContext,
            privateKey: keyPair.privateKey,
            parameterSet: parameterSet,
            additionalRandomness: randomness
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try SLHDSA.sign(
            message: message,
            context: context,
            privateKey: keyPair.privateKey,
            parameterSet: parameterSet,
            additionalRandomness: randomness.dropLast()
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try SLHDSA.keygenInternal(
            parameterSet: parameterSet,
            skSeed: skSeed.dropLast(),
            skPrf: skPrf,
            pkSeed: pkSeed
        )) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    private func assertReferenceVector(
        parameterSet: SLHDSA.ParameterSet,
        expectedPublicKeyHex: String,
        expectedSignatureDigestHex: String
    ) throws {
        let n = parameterSet.parameters.n
        let skSeed = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 3 + 1) })
        let skPrf = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 5 + 2) })
        let pkSeed = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 7 + 3) })
        let randomness = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 11 + 4) })
        let message = Data("abc".utf8)
        let context = Data("ctx".utf8)

        let keyPair = try SLHDSA.keygenInternal(
            parameterSet: parameterSet,
            skSeed: skSeed,
            skPrf: skPrf,
            pkSeed: pkSeed
        )
        XCTAssertEqual(keyPair.publicKey.hexString, expectedPublicKeyHex)
        XCTAssertEqual(keyPair.privateKey.count, parameterSet.parameters.privateKeyByteCount)

        let signature = try SLHDSA.sign(
            message: message,
            context: context,
            privateKey: keyPair.privateKey,
            parameterSet: parameterSet,
            additionalRandomness: randomness
        )
        XCTAssertEqual(signature.count, parameterSet.parameters.signatureByteCount)
        XCTAssertEqual(Data(SHA256.hash(data: signature)).hexString, expectedSignatureDigestHex)
        XCTAssertTrue(try SLHDSA.verify(
            message: message,
            signature: signature,
            context: context,
            publicKey: keyPair.publicKey,
            parameterSet: parameterSet
        ))

        var tampered = signature
        tampered[tampered.startIndex + 17] ^= 0x01
        XCTAssertFalse(try SLHDSA.verify(
            message: message,
            signature: tampered,
            context: context,
            publicKey: keyPair.publicKey,
            parameterSet: parameterSet
        ))
    }

    private func assertPreHashReferenceVector(
        preHashFunction: SLHDSA.PreHashFunction,
        expectedSignatureDigestHex: String
    ) throws {
        let parameterSet = SLHDSA.ParameterSet.sha2_128f
        let n = parameterSet.parameters.n
        let skSeed = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 3 + 1) })
        let skPrf = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 5 + 2) })
        let pkSeed = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 7 + 3) })
        let randomness = Data((0..<n).map { UInt8(truncatingIfNeeded: $0 * 11 + 4) })
        let keyPair = try SLHDSA.keygenInternal(
            parameterSet: parameterSet,
            skSeed: skSeed,
            skPrf: skPrf,
            pkSeed: pkSeed
        )

        let signature = try SLHDSA.hashSign(
            message: Data("abc".utf8),
            context: Data("ctx".utf8),
            preHashFunction: preHashFunction,
            privateKey: keyPair.privateKey,
            parameterSet: parameterSet,
            additionalRandomness: randomness
        )
        XCTAssertEqual(Data(SHA256.hash(data: signature)).hexString, expectedSignatureDigestHex)
        XCTAssertTrue(try SLHDSA.hashVerify(
            message: Data("abc".utf8),
            signature: signature,
            context: Data("ctx".utf8),
            preHashFunction: preHashFunction,
            publicKey: keyPair.publicKey,
            parameterSet: parameterSet
        ))
    }
}
