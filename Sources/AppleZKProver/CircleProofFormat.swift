import Foundation

public enum QM31CanonicalEncoding {
    public static let elementByteCount = 4 * MemoryLayout<UInt32>.stride

    public static func pack(_ value: QM31Element) -> Data {
        var data = Data()
        data.reserveCapacity(elementByteCount)
        appendUInt32(value.constant.real, to: &data)
        appendUInt32(value.constant.imaginary, to: &data)
        appendUInt32(value.uCoefficient.real, to: &data)
        appendUInt32(value.uCoefficient.imaginary, to: &data)
        return data
    }

    public static func pack(_ values: [QM31Element]) -> Data {
        var data = Data()
        data.reserveCapacity(values.count * elementByteCount)
        for value in values {
            data.append(pack(value))
        }
        return data
    }

    public static func unpack(_ data: Data) throws -> QM31Element {
        guard data.count == elementByteCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        var reader = CanonicalByteReader(data)
        let value = QM31Element(
            a: try reader.readUInt32(),
            b: try reader.readUInt32(),
            c: try reader.readUInt32(),
            d: try reader.readUInt32()
        )
        try reader.finish()
        try QM31Field.validateCanonical([value])
        return value
    }

    public static func unpackMany(_ data: Data, count: Int) throws -> [QM31Element] {
        guard count >= 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let expectedByteCount = try checkedBufferLength(count, elementByteCount)
        guard data.count == expectedByteCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        var values: [QM31Element] = []
        values.reserveCapacity(count)
        var reader = CanonicalByteReader(data)
        for _ in 0..<count {
            let value = QM31Element(
                a: try reader.readUInt32(),
                b: try reader.readUInt32(),
                c: try reader.readUInt32(),
                d: try reader.readUInt32()
            )
            try QM31Field.validateCanonical([value])
            values.append(value)
        }
        try reader.finish()
        return values
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        CanonicalBinary.appendUInt32(value, to: &data)
    }
}

public enum CircleDomainDescriptorCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x43, 0x44, 0x56, 0x31, 0x00])
    private static let byteCount = 44

    public static func encode(_ descriptor: CircleDomainDescriptor) throws -> Data {
        guard descriptor.version == CircleDomainDescriptor.currentVersion,
              descriptor.isCanonical else {
            throw AppleZKProverError.invalidInputLayout
        }
        var data = Data()
        data.reserveCapacity(byteCount)
        data.append(magic)
        CanonicalBinary.appendUInt32(descriptor.version, to: &data)
        CanonicalBinary.appendUInt32(M31Field.modulus, to: &data)
        CanonicalBinary.appendUInt32(CirclePointIndex.circleLogOrder, to: &data)
        CanonicalBinary.appendUInt32(CirclePointM31.generator.x, to: &data)
        CanonicalBinary.appendUInt32(CirclePointM31.generator.y, to: &data)
        CanonicalBinary.appendUInt32(descriptor.logSize, to: &data)
        CanonicalBinary.appendUInt32(descriptor.halfCosetInitialIndex.rawValue, to: &data)
        CanonicalBinary.appendUInt32(descriptor.halfCosetLogSize, to: &data)
        CanonicalBinary.appendUInt32(descriptor.storageOrder.rawValue, to: &data)
        return data
    }

    public static func decode(_ data: Data) throws -> CircleDomainDescriptor {
        guard data.count == byteCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic,
              try reader.readUInt32() == CircleDomainDescriptor.currentVersion,
              try reader.readUInt32() == M31Field.modulus,
              try reader.readUInt32() == CirclePointIndex.circleLogOrder,
              try reader.readUInt32() == CirclePointM31.generator.x,
              try reader.readUInt32() == CirclePointM31.generator.y else {
            throw AppleZKProverError.invalidInputLayout
        }
        let logSize = try reader.readUInt32()
        let halfCosetInitialIndex = CirclePointIndex(rawValue: UInt64(try reader.readUInt32()))
        let halfCosetLogSize = try reader.readUInt32()
        let storageRaw = try reader.readUInt32()
        guard let storageOrder = CircleDomainStorageOrder(rawValue: storageRaw) else {
            throw AppleZKProverError.invalidInputLayout
        }
        try reader.finish()
        let descriptor = try CircleDomainDescriptor(
            logSize: logSize,
            halfCosetInitialIndex: halfCosetInitialIndex,
            halfCosetLogSize: halfCosetLogSize,
            storageOrder: storageOrder
        )
        guard descriptor.isCanonical else {
            throw AppleZKProverError.invalidInputLayout
        }
        return descriptor
    }
}

public struct CircleFRISecurityParametersV1: Equatable, Sendable {
    public let logBlowupFactor: UInt32
    public let queryCount: UInt32
    public let foldingStep: UInt32
    public let grindingBits: UInt32

    public init(
        logBlowupFactor: UInt32,
        queryCount: UInt32,
        foldingStep: UInt32,
        grindingBits: UInt32
    ) throws {
        let securityBits = UInt64(logBlowupFactor) * UInt64(queryCount) + UInt64(grindingBits)
        guard logBlowupFactor > 0,
              queryCount > 0,
              foldingStep > 0,
              grindingBits <= 64,
              securityBits <= UInt64(UInt32.max) else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.logBlowupFactor = logBlowupFactor
        self.queryCount = queryCount
        self.foldingStep = foldingStep
        self.grindingBits = grindingBits
    }

    public var nominalSecurityBits: UInt32 {
        logBlowupFactor * queryCount + grindingBits
    }
}

public enum CirclePCSFRICodewordCommitmentScheduleV1: String, Codable, CaseIterable, Sendable {
    case materializedCodewordThenCommit = "materialized-codeword-then-commit"
}

public enum CirclePCSFRIOpenBoundaryV1: String, Codable, CaseIterable, Sendable {
    case witnessAIRToCircleFFTBasis = "witness-air-to-circle-fft-basis"
    case airTraceSynthesis = "air-trace-synthesis"
    case sumcheckGKRArtifactIntegration = "sumcheck-gkr-artifact-integration"
    case nonzeroGrinding = "nonzero-grinding"
    case fusedTiledCodewordCommitmentScheduling = "fused-tiled-codeword-commitment-scheduling"
}

public struct CirclePCSFRIArtifactManifestV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1
    public static let artifactName = "CirclePCSFRIProofV1"
    public static let current = CirclePCSFRIArtifactManifestV1()

    public let version: UInt32
    public let artifact: String
    public let includesCirclePCS: Bool
    public let includesWitnessAIR: Bool
    public let includesSumcheck: Bool
    public let includesGKR: Bool
    public let supportsNonzeroGrinding: Bool
    public let residentWitnessToCircleFFTBasis: Bool
    public let codewordCommitmentSchedule: CirclePCSFRICodewordCommitmentScheduleV1
    public let openBoundaries: [CirclePCSFRIOpenBoundaryV1]

    public init() {
        self.version = Self.currentVersion
        self.artifact = Self.artifactName
        self.includesCirclePCS = true
        self.includesWitnessAIR = false
        self.includesSumcheck = false
        self.includesGKR = false
        self.supportsNonzeroGrinding = true
        self.residentWitnessToCircleFFTBasis = true
        self.codewordCommitmentSchedule = .materializedCodewordThenCommit
        self.openBoundaries = [
            .airTraceSynthesis,
            .sumcheckGKRArtifactIntegration,
            .fusedTiledCodewordCommitmentScheduling,
        ]
    }
}

public struct CirclePCSFRIParameterSetV1: Equatable, Sendable {
    public enum ProfileID: String, Sendable {
        case conservative128 = "circle-pcs-fri-v1-conservative-128"
    }

    public let profileID: ProfileID
    public let securityParameters: CircleFRISecurityParametersV1
    public let targetSoundnessBits: UInt32

    public init(
        profileID: ProfileID,
        logBlowupFactor: UInt32,
        queryCount: UInt32,
        grindingBits: UInt32,
        targetSoundnessBits: UInt32
    ) throws {
        let securityParameters = try CircleFRISecurityParametersV1(
            logBlowupFactor: logBlowupFactor,
            queryCount: queryCount,
            foldingStep: 1,
            grindingBits: grindingBits
        )
        guard targetSoundnessBits > 0,
              securityParameters.nominalSecurityBits >= targetSoundnessBits else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.profileID = profileID
        self.securityParameters = securityParameters
        self.targetSoundnessBits = targetSoundnessBits
    }

    public static let conservative128: CirclePCSFRIParameterSetV1 = {
        do {
            return try CirclePCSFRIParameterSetV1(
                profileID: .conservative128,
                logBlowupFactor: 4,
                queryCount: 36,
                grindingBits: 0,
                targetSoundnessBits: 128
            )
        } catch {
            preconditionFailure("Invalid built-in Circle PCS/FRI parameter set: \(error)")
        }
    }()

    public func roundCount(for domain: CircleDomainDescriptor) throws -> Int {
        try validateDomain(domain)
        return Int(domain.logSize - securityParameters.logBlowupFactor)
    }

    public func committedCoefficientCapacity(for domain: CircleDomainDescriptor) throws -> Int {
        try validateDomain(domain)
        return domain.size >> Int(securityParameters.logBlowupFactor)
    }

    public func validateDomain(_ domain: CircleDomainDescriptor) throws {
        guard domain.storageOrder == .circleDomainBitReversed,
              domain.isCanonical,
              domain.logSize > securityParameters.logBlowupFactor else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    public func acceptsProofShape(_ proof: CirclePCSFRIProofV1) throws -> Bool {
        guard proof.securityParameters == securityParameters,
              proof.commitments.count == (try roundCount(for: proof.domain)),
              proof.finalLayer.count == (1 << Int(securityParameters.logBlowupFactor)),
              Self.finalLayerIsTerminalConstant(proof.finalLayer) else {
            return false
        }
        return true
    }

    public static func finalLayerIsTerminalConstant(_ finalLayer: [QM31Element]) -> Bool {
        guard let first = finalLayer.first else {
            return false
        }
        return finalLayer.allSatisfy { $0 == first }
    }
}

public struct CircleFRIValueOpeningV1: Equatable, Sendable {
    public let leafIndex: UInt64
    public let value: QM31Element
    public let siblingHashes: [Data]

    public init(
        leafIndex: UInt64,
        value: QM31Element,
        siblingHashes: [Data]
    ) throws {
        try QM31Field.validateCanonical([value])
        guard siblingHashes.allSatisfy({ $0.count == 32 }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.leafIndex = leafIndex
        self.value = value
        self.siblingHashes = siblingHashes
    }
}

public struct CircleFRIQueryLayerOpeningV1: Equatable, Sendable {
    public let layerIndex: UInt32
    public let pairIndex: UInt64
    public let left: CircleFRIValueOpeningV1
    public let right: CircleFRIValueOpeningV1

    public init(
        layerIndex: UInt32,
        pairIndex: UInt64,
        left: CircleFRIValueOpeningV1,
        right: CircleFRIValueOpeningV1
    ) {
        self.layerIndex = layerIndex
        self.pairIndex = pairIndex
        self.left = left
        self.right = right
    }
}

public struct CircleFRIQueryV1: Equatable, Sendable {
    public let initialPairIndex: UInt64
    public let layers: [CircleFRIQueryLayerOpeningV1]

    public init(initialPairIndex: UInt64, layers: [CircleFRIQueryLayerOpeningV1]) throws {
        guard !layers.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.initialPairIndex = initialPairIndex
        self.layers = layers
    }
}

public struct CirclePCSFRIProofV1: Equatable, Sendable {
    public static let proofVersion: UInt32 = 1
    public static let currentTranscriptVersion: UInt32 = 1

    public let version: UInt32
    public let transcriptVersion: UInt32
    public let domain: CircleDomainDescriptor
    public let securityParameters: CircleFRISecurityParametersV1
    public let publicInputDigest: Data
    public let commitments: [Data]
    public let finalLayer: [QM31Element]
    public let queries: [CircleFRIQueryV1]
    public let claimedEvaluationOpenings: [CircleFRIValueOpeningV1]
    public let grindingNonce: UInt64?

    public init(
        version: UInt32 = proofVersion,
        transcriptVersion: UInt32 = currentTranscriptVersion,
        domain: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputDigest: Data,
        commitments: [Data],
        finalLayer: [QM31Element],
        queries: [CircleFRIQueryV1],
        claimedEvaluationOpenings: [CircleFRIValueOpeningV1] = [],
        grindingNonce: UInt64? = nil
    ) throws {
        guard version == Self.proofVersion,
              transcriptVersion == Self.currentTranscriptVersion,
              domain.storageOrder == .circleDomainBitReversed,
              domain.isCanonical,
              securityParameters.foldingStep == 1,
              Self.grindingNonceShapeIsValid(
                securityParameters: securityParameters,
                grindingNonce: grindingNonce
              ),
              publicInputDigest.count == 32,
              !commitments.isEmpty,
              commitments.count <= Int(domain.logSize),
              commitments.allSatisfy({ $0.count == 32 }),
              finalLayer.count == (domain.size >> commitments.count),
              queries.count == Int(securityParameters.queryCount) else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(finalLayer)
        self.version = version
        self.transcriptVersion = transcriptVersion
        self.domain = domain
        self.securityParameters = securityParameters
        self.publicInputDigest = publicInputDigest
        self.commitments = commitments
        self.finalLayer = finalLayer
        self.queries = queries
        self.claimedEvaluationOpenings = claimedEvaluationOpenings
        self.grindingNonce = grindingNonce
        try Self.validateQueryShape(
            queries: queries,
            domain: domain,
            commitmentCount: commitments.count
        )
        try Self.validateClaimedEvaluationOpenings(
            claimedEvaluationOpenings,
            domain: domain
        )
    }

    private static func grindingNonceShapeIsValid(
        securityParameters: CircleFRISecurityParametersV1,
        grindingNonce: UInt64?
    ) -> Bool {
        guard securityParameters.grindingBits > 0 else {
            return grindingNonce == nil
        }
        return grindingNonce != nil
    }

    private static func validateQueryShape(
        queries: [CircleFRIQueryV1],
        domain: CircleDomainDescriptor,
        commitmentCount: Int
    ) throws {
        for query in queries {
            guard query.initialPairIndex < UInt64(domain.halfSize),
                  query.layers.count == commitmentCount else {
                throw AppleZKProverError.invalidInputLayout
            }
            for (roundIndex, layer) in query.layers.enumerated() {
                let expectedPairIndex = query.initialPairIndex >> UInt64(roundIndex)
                guard layer.layerIndex == UInt32(roundIndex),
                      layer.pairIndex == expectedPairIndex,
                      layer.layerIndex < UInt32(commitmentCount),
                      layer.layerIndex < domain.logSize else {
                    throw AppleZKProverError.invalidInputLayout
                }
                let layerLeafCount = domain.size >> Int(layer.layerIndex)
                let leftIndex = layer.pairIndex * 2
                let rightIndex = leftIndex + 1
                guard layerLeafCount > 1,
                      layer.pairIndex < UInt64(layerLeafCount / 2),
                      layer.left.leafIndex == leftIndex,
                      layer.right.leafIndex == rightIndex,
                      layer.left.siblingHashes.count == log2(layerLeafCount),
                      layer.right.siblingHashes.count == log2(layerLeafCount) else {
                    throw AppleZKProverError.invalidInputLayout
                }
            }
        }
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

    private static func validateClaimedEvaluationOpenings(
        _ openings: [CircleFRIValueOpeningV1],
        domain: CircleDomainDescriptor
    ) throws {
        var previousLeafIndex: UInt64?
        for opening in openings {
            guard opening.leafIndex < UInt64(domain.size),
                  opening.siblingHashes.count == log2(domain.size),
                  previousLeafIndex.map({ $0 < opening.leafIndex }) ?? true else {
                throw AppleZKProverError.invalidInputLayout
            }
            previousLeafIndex = opening.leafIndex
        }
    }
}

public enum CirclePCSFRIProofCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x50, 0x46, 0x56, 0x31, 0x00])

    public static func encode(_ proof: CirclePCSFRIProofV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(proof.version, to: &data)
        CanonicalBinary.appendUInt32(proof.transcriptVersion, to: &data)

        let domainBytes = try CircleDomainDescriptorCodecV1.encode(proof.domain)
        try CanonicalBinary.appendLengthPrefixed(domainBytes, to: &data)

        CanonicalBinary.appendUInt32(proof.securityParameters.logBlowupFactor, to: &data)
        CanonicalBinary.appendUInt32(proof.securityParameters.queryCount, to: &data)
        CanonicalBinary.appendUInt32(proof.securityParameters.foldingStep, to: &data)
        CanonicalBinary.appendUInt32(proof.securityParameters.grindingBits, to: &data)

        try CanonicalBinary.appendLengthPrefixed(proof.publicInputDigest, to: &data)
        CanonicalBinary.appendUInt32(try checkedUInt32(proof.commitments.count), to: &data)
        for commitment in proof.commitments {
            guard commitment.count == 32 else {
                throw AppleZKProverError.invalidInputLayout
            }
            data.append(commitment)
        }

        CanonicalBinary.appendUInt64(UInt64(proof.finalLayer.count), to: &data)
        data.append(QM31CanonicalEncoding.pack(proof.finalLayer))

        CanonicalBinary.appendUInt32(try checkedUInt32(proof.queries.count), to: &data)
        for query in proof.queries {
            CanonicalBinary.appendUInt64(query.initialPairIndex, to: &data)
            CanonicalBinary.appendUInt32(try checkedUInt32(query.layers.count), to: &data)
            for layer in query.layers {
                CanonicalBinary.appendUInt32(layer.layerIndex, to: &data)
                CanonicalBinary.appendUInt64(layer.pairIndex, to: &data)
                try encodeOpening(layer.left, to: &data)
                try encodeOpening(layer.right, to: &data)
            }
        }
        if !proof.claimedEvaluationOpenings.isEmpty || proof.grindingNonce != nil {
            CanonicalBinary.appendUInt32(try checkedUInt32(proof.claimedEvaluationOpenings.count), to: &data)
            for opening in proof.claimedEvaluationOpenings {
                try encodeOpening(opening, to: &data)
            }
        }
        if let grindingNonce = proof.grindingNonce {
            CanonicalBinary.appendUInt64(grindingNonce, to: &data)
        }
        return data
    }

    public static func decode(_ data: Data) throws -> CirclePCSFRIProofV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let transcriptVersion = try reader.readUInt32()
        let domain = try CircleDomainDescriptorCodecV1.decode(try reader.readLengthPrefixed())
        let security = try CircleFRISecurityParametersV1(
            logBlowupFactor: try reader.readUInt32(),
            queryCount: try reader.readUInt32(),
            foldingStep: try reader.readUInt32(),
            grindingBits: try reader.readUInt32()
        )
        let publicInputDigest = try reader.readLengthPrefixed()
        let commitmentCount = Int(try reader.readUInt32())
        var commitments: [Data] = []
        commitments.reserveCapacity(commitmentCount)
        for _ in 0..<commitmentCount {
            commitments.append(try reader.readBytes(count: 32))
        }

        let finalLayerCount = try reader.readUInt64()
        guard finalLayerCount <= UInt64(Int.max) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let finalLayerElementCount = Int(finalLayerCount)
        let finalLayerByteCount = try checkedBufferLength(
            finalLayerElementCount,
            QM31CanonicalEncoding.elementByteCount
        )
        let finalLayerBytes = try reader.readBytes(count: finalLayerByteCount)
        let finalLayer = try QM31CanonicalEncoding.unpackMany(
            finalLayerBytes,
            count: finalLayerElementCount
        )

        let queryCount = Int(try reader.readUInt32())
        var queries: [CircleFRIQueryV1] = []
        queries.reserveCapacity(queryCount)
        for _ in 0..<queryCount {
            let initialPairIndex = try reader.readUInt64()
            let layerCount = Int(try reader.readUInt32())
            var layers: [CircleFRIQueryLayerOpeningV1] = []
            layers.reserveCapacity(layerCount)
            for _ in 0..<layerCount {
                let layerIndex = try reader.readUInt32()
                let pairIndex = try reader.readUInt64()
                let left = try decodeOpening(from: &reader)
                let right = try decodeOpening(from: &reader)
                layers.append(CircleFRIQueryLayerOpeningV1(
                    layerIndex: layerIndex,
                    pairIndex: pairIndex,
                    left: left,
                    right: right
                ))
            }
            queries.append(try CircleFRIQueryV1(
                initialPairIndex: initialPairIndex,
                layers: layers
            ))
        }
        var claimedEvaluationOpenings: [CircleFRIValueOpeningV1] = []
        var grindingNonce: UInt64?
        if !reader.isAtEnd {
            let openingCount = Int(try reader.readUInt32())
            claimedEvaluationOpenings.reserveCapacity(openingCount)
            for _ in 0..<openingCount {
                claimedEvaluationOpenings.append(try decodeOpening(from: &reader))
            }
            if !reader.isAtEnd {
                grindingNonce = try reader.readUInt64()
            }
        }
        try reader.finish()
        return try CirclePCSFRIProofV1(
            version: version,
            transcriptVersion: transcriptVersion,
            domain: domain,
            securityParameters: security,
            publicInputDigest: publicInputDigest,
            commitments: commitments,
            finalLayer: finalLayer,
            queries: queries,
            claimedEvaluationOpenings: claimedEvaluationOpenings,
            grindingNonce: grindingNonce
        )
    }

    private static func encodeOpening(_ opening: CircleFRIValueOpeningV1, to data: inout Data) throws {
        CanonicalBinary.appendUInt64(opening.leafIndex, to: &data)
        data.append(QM31CanonicalEncoding.pack(opening.value))
        CanonicalBinary.appendUInt32(try checkedUInt32(opening.siblingHashes.count), to: &data)
        for sibling in opening.siblingHashes {
            guard sibling.count == 32 else {
                throw AppleZKProverError.invalidInputLayout
            }
            data.append(sibling)
        }
    }

    private static func decodeOpening(from reader: inout CanonicalByteReader) throws -> CircleFRIValueOpeningV1 {
        let leafIndex = try reader.readUInt64()
        let value = try QM31CanonicalEncoding.unpack(
            try reader.readBytes(count: QM31CanonicalEncoding.elementByteCount)
        )
        let siblingCount = Int(try reader.readUInt32())
        var siblings: [Data] = []
        siblings.reserveCapacity(siblingCount)
        for _ in 0..<siblingCount {
            siblings.append(try reader.readBytes(count: 32))
        }
        return try CircleFRIValueOpeningV1(
            leafIndex: leafIndex,
            value: value,
            siblingHashes: siblings
        )
    }
}

public struct CircleFRITranscriptV1Result: Equatable, Sendable {
    public let challenges: [QM31Element]
    public let queryPairIndices: [Int]
}

public enum CircleFRIGrindingV1 {
    public static let nonceByteCount = MemoryLayout<UInt64>.stride
    public static let maximumLocalSearchBits: UInt32 = 20

    public static func nonceBytes(_ nonce: UInt64) -> Data {
        var data = Data()
        data.reserveCapacity(nonceByteCount)
        CanonicalBinary.appendUInt64(nonce, to: &data)
        return data
    }

    public static func digestMeetsTarget(_ digest: Data, grindingBits: UInt32) -> Bool {
        guard grindingBits <= UInt32(digest.count * 8) else {
            return false
        }
        var remaining = Int(grindingBits)
        var index = 0
        while remaining >= 8 {
            guard digest[index] == 0 else {
                return false
            }
            index += 1
            remaining -= 8
        }
        guard remaining > 0 else {
            return true
        }
        let mask = UInt8(0xff) << UInt8(8 - remaining)
        return (digest[index] & mask) == 0
    }
}

public enum CircleFRITranscriptV1 {
    private static let domain = Data("AppleZKProver.CircleFRI.PCS.V1".utf8)

    public static func derive(
        domain descriptor: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputDigest: Data,
        commitments: [Data],
        finalLayer: [QM31Element],
        grindingNonce: UInt64? = nil,
        transcriptVersion: UInt32 = CirclePCSFRIProofV1.currentTranscriptVersion
    ) throws -> CircleFRITranscriptV1Result {
        var (transcript, challenges) = try transcriptAfterFinalLayer(
            descriptor: descriptor,
            securityParameters: securityParameters,
            publicInputDigest: publicInputDigest,
            commitments: commitments,
            finalLayer: finalLayer,
            transcriptVersion: transcriptVersion
        )

        try applyGrindingIfNeeded(
            transcript: &transcript,
            securityParameters: securityParameters,
            grindingNonce: grindingNonce
        )
        try transcript.absorb(queryFrame(
            queryCount: Int(securityParameters.queryCount),
            initialPairCount: descriptor.halfSize
        ))
        let queryWords = try transcript.squeezeUInt32(
            count: Int(securityParameters.queryCount),
            modulus: UInt32(descriptor.halfSize)
        )
        return CircleFRITranscriptV1Result(
            challenges: challenges,
            queryPairIndices: queryWords.map(Int.init)
        )
    }

    public static func deriveChallenges(
        domain descriptor: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputDigest: Data,
        commitments: [Data],
        transcriptVersion: UInt32 = CirclePCSFRIProofV1.currentTranscriptVersion
    ) throws -> [QM31Element] {
        let (_, challenges) = try prefixTranscriptAndChallenges(
            descriptor: descriptor,
            securityParameters: securityParameters,
            publicInputDigest: publicInputDigest,
            commitments: commitments,
            transcriptVersion: transcriptVersion
        )
        return challenges
    }

    public static func derive(proof: CirclePCSFRIProofV1) throws -> CircleFRITranscriptV1Result {
        try derive(
            domain: proof.domain,
            securityParameters: proof.securityParameters,
            publicInputDigest: proof.publicInputDigest,
            commitments: proof.commitments,
            finalLayer: proof.finalLayer,
            grindingNonce: proof.grindingNonce,
            transcriptVersion: proof.transcriptVersion
        )
    }

    public static func findGrindingNonce(
        domain descriptor: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputDigest: Data,
        commitments: [Data],
        finalLayer: [QM31Element],
        transcriptVersion: UInt32 = CirclePCSFRIProofV1.currentTranscriptVersion
    ) throws -> UInt64? {
        guard securityParameters.grindingBits > 0 else {
            return nil
        }
        guard securityParameters.grindingBits <= CircleFRIGrindingV1.maximumLocalSearchBits else {
            throw AppleZKProverError.invalidInputLayout
        }
        let (transcript, _) = try transcriptAfterFinalLayer(
            descriptor: descriptor,
            securityParameters: securityParameters,
            publicInputDigest: publicInputDigest,
            commitments: commitments,
            finalLayer: finalLayer,
            transcriptVersion: transcriptVersion
        )
        var nonce: UInt64 = 0
        while true {
            var candidateTranscript = transcript
            let digest = try absorbGrindingNonce(
                into: &candidateTranscript,
                grindingBits: securityParameters.grindingBits,
                nonce: nonce
            )
            if CircleFRIGrindingV1.digestMeetsTarget(
                digest,
                grindingBits: securityParameters.grindingBits
            ) {
                return nonce
            }
            guard nonce < UInt64.max else {
                throw AppleZKProverError.invalidInputLayout
            }
            nonce += 1
        }
    }

    private static func prefixTranscriptAndChallenges(
        descriptor: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputDigest: Data,
        commitments: [Data],
        transcriptVersion: UInt32
    ) throws -> (SHA3Oracle.TranscriptState, [QM31Element]) {
        guard descriptor.storageOrder == .circleDomainBitReversed,
              descriptor.isCanonical,
              transcriptVersion == CirclePCSFRIProofV1.currentTranscriptVersion,
              publicInputDigest.count == 32,
              !commitments.isEmpty,
              commitments.allSatisfy({ $0.count == 32 }) else {
            throw AppleZKProverError.invalidInputLayout
        }

        var transcript = SHA3Oracle.TranscriptState()
        try transcript.absorb(headerFrame(transcriptVersion: transcriptVersion))
        try transcript.absorb(try CircleDomainDescriptorCodecV1.encode(descriptor))
        try transcript.absorb(securityFrame(securityParameters))
        try transcript.absorb(publicInputFrame(byteCount: publicInputDigest.count))
        try transcript.absorb(publicInputDigest)

        var challenges: [QM31Element] = []
        challenges.reserveCapacity(commitments.count)
        for (index, commitment) in commitments.enumerated() {
            try transcript.absorb(try commitmentFrame(index: index, byteCount: commitment.count))
            try transcript.absorb(commitment)
            try transcript.absorb(try challengeFrame(index: index))
            let limbs = try transcript.squeezeUInt32(count: 4, modulus: QM31Field.modulus)
            challenges.append(QM31Element(a: limbs[0], b: limbs[1], c: limbs[2], d: limbs[3]))
        }
        return (transcript, challenges)
    }

    private static func transcriptAfterFinalLayer(
        descriptor: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputDigest: Data,
        commitments: [Data],
        finalLayer: [QM31Element],
        transcriptVersion: UInt32
    ) throws -> (SHA3Oracle.TranscriptState, [QM31Element]) {
        guard descriptor.storageOrder == .circleDomainBitReversed,
              descriptor.isCanonical,
              transcriptVersion == CirclePCSFRIProofV1.currentTranscriptVersion,
              publicInputDigest.count == 32,
              !commitments.isEmpty,
              commitments.allSatisfy({ $0.count == 32 }),
              !finalLayer.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(finalLayer)

        var (transcript, challenges) = try prefixTranscriptAndChallenges(
            descriptor: descriptor,
            securityParameters: securityParameters,
            publicInputDigest: publicInputDigest,
            commitments: commitments,
            transcriptVersion: transcriptVersion
        )
        let finalLayerBytes = QM31CanonicalEncoding.pack(finalLayer)
        try transcript.absorb(finalLayerFrame(
            elementCount: finalLayer.count,
            byteCount: finalLayerBytes.count
        ))
        try transcript.absorb(finalLayerBytes)
        return (transcript, challenges)
    }

    private static func applyGrindingIfNeeded(
        transcript: inout SHA3Oracle.TranscriptState,
        securityParameters: CircleFRISecurityParametersV1,
        grindingNonce: UInt64?
    ) throws {
        guard securityParameters.grindingBits > 0 else {
            guard grindingNonce == nil else {
                throw AppleZKProverError.invalidInputLayout
            }
            return
        }
        guard let grindingNonce else {
            throw AppleZKProverError.invalidInputLayout
        }
        let digest = try absorbGrindingNonce(
            into: &transcript,
            grindingBits: securityParameters.grindingBits,
            nonce: grindingNonce
        )
        guard CircleFRIGrindingV1.digestMeetsTarget(
            digest,
            grindingBits: securityParameters.grindingBits
        ) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private static func absorbGrindingNonce(
        into transcript: inout SHA3Oracle.TranscriptState,
        grindingBits: UInt32,
        nonce: UInt64
    ) throws -> Data {
        try transcript.absorb(try grindingFrame(
            grindingBits: grindingBits,
            nonceByteCount: CircleFRIGrindingV1.nonceByteCount
        ))
        try transcript.absorb(CircleFRIGrindingV1.nonceBytes(nonce))
        return try transcript.squeezeBytes(count: 32)
    }

    static func headerFrame(transcriptVersion: UInt32) -> Data {
        var frame = baseFrame(type: 0)
        CanonicalBinary.appendUInt32(CirclePCSFRIProofV1.proofVersion, to: &frame)
        CanonicalBinary.appendUInt32(transcriptVersion, to: &frame)
        CanonicalBinary.appendUInt32(M31Field.modulus, to: &frame)
        CanonicalBinary.appendUInt32(CirclePointM31.generator.x, to: &frame)
        CanonicalBinary.appendUInt32(CirclePointM31.generator.y, to: &frame)
        return frame
    }

    static func securityFrame(_ security: CircleFRISecurityParametersV1) -> Data {
        var frame = baseFrame(type: 1)
        CanonicalBinary.appendUInt32(security.logBlowupFactor, to: &frame)
        CanonicalBinary.appendUInt32(security.queryCount, to: &frame)
        CanonicalBinary.appendUInt32(security.foldingStep, to: &frame)
        CanonicalBinary.appendUInt32(security.grindingBits, to: &frame)
        CanonicalBinary.appendUInt32(security.nominalSecurityBits, to: &frame)
        return frame
    }

    static func publicInputFrame(byteCount: Int) throws -> Data {
        var frame = baseFrame(type: 2)
        CanonicalBinary.appendUInt32(try checkedUInt32(byteCount), to: &frame)
        return frame
    }

    static func commitmentFrame(index: Int, byteCount: Int) throws -> Data {
        var frame = baseFrame(type: 3)
        CanonicalBinary.appendUInt32(try checkedUInt32(index), to: &frame)
        CanonicalBinary.appendUInt32(try checkedUInt32(byteCount), to: &frame)
        return frame
    }

    static func challengeFrame(index: Int) throws -> Data {
        var frame = baseFrame(type: 4)
        CanonicalBinary.appendUInt32(try checkedUInt32(index), to: &frame)
        CanonicalBinary.appendUInt32(QM31Field.modulus, to: &frame)
        CanonicalBinary.appendUInt32(4, to: &frame)
        return frame
    }

    static func finalLayerFrame(elementCount: Int, byteCount: Int) throws -> Data {
        var frame = baseFrame(type: 5)
        CanonicalBinary.appendUInt64(UInt64(try checkedNonNegative(elementCount)), to: &frame)
        CanonicalBinary.appendUInt64(UInt64(try checkedNonNegative(byteCount)), to: &frame)
        return frame
    }

    static func queryFrame(queryCount: Int, initialPairCount: Int) throws -> Data {
        var frame = baseFrame(type: 6)
        CanonicalBinary.appendUInt32(try checkedUInt32(queryCount), to: &frame)
        CanonicalBinary.appendUInt64(UInt64(try checkedNonNegative(initialPairCount)), to: &frame)
        return frame
    }

    static func grindingFrame(grindingBits: UInt32, nonceByteCount: Int) throws -> Data {
        var frame = baseFrame(type: 7)
        CanonicalBinary.appendUInt32(grindingBits, to: &frame)
        CanonicalBinary.appendUInt32(try checkedUInt32(nonceByteCount), to: &frame)
        return frame
    }

    private static func baseFrame(type: UInt8) -> Data {
        var frame = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &frame)
        frame.append(domain)
        CanonicalBinary.appendUInt32(CirclePCSFRIProofV1.currentTranscriptVersion, to: &frame)
        frame.append(type)
        return frame
    }

    private static func checkedNonNegative(_ value: Int) throws -> Int {
        guard value >= 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        return value
    }
}

public struct CirclePCSFRIPublicInputsV1: Equatable, Sendable {
    public let publicInputDigest: Data

    public init(publicInputDigest: Data) throws {
        guard publicInputDigest.count == 32 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.publicInputDigest = publicInputDigest
    }

    public init(polynomialClaim: CirclePCSFRIPolynomialClaimV1) throws {
        self.publicInputDigest = try CirclePCSFRIPolynomialClaimDigestV1.digest(polynomialClaim)
    }
}

public struct CirclePCSFRIEvaluationClaimV1: Equatable, Sendable {
    public let storageIndex: UInt64
    public let point: CirclePointM31
    public let value: QM31Element

    public init(
        storageIndex: UInt64,
        point: CirclePointM31,
        value: QM31Element
    ) throws {
        try CircleDomainOracle.validatePoint(point)
        try QM31Field.validateCanonical([value])
        self.storageIndex = storageIndex
        self.point = point
        self.value = value
    }
}

public struct CirclePCSFRIPolynomialClaimV1: Equatable, Sendable {
    public let domain: CircleDomainDescriptor
    public let polynomial: CircleCodewordPolynomial
    public let evaluationClaims: [CirclePCSFRIEvaluationClaimV1]

    public init(
        domain: CircleDomainDescriptor,
        polynomial: CircleCodewordPolynomial,
        evaluationClaims: [CirclePCSFRIEvaluationClaimV1]
    ) throws {
        guard domain.storageOrder == .circleDomainBitReversed,
              domain.isCanonical,
              !evaluationClaims.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        var previousStorageIndex: UInt64?
        for claim in evaluationClaims {
            guard claim.storageIndex < UInt64(domain.size),
                  previousStorageIndex.map({ $0 < claim.storageIndex }) ?? true else {
                throw AppleZKProverError.invalidInputLayout
            }
            previousStorageIndex = claim.storageIndex
        }
        self.domain = domain
        self.polynomial = polynomial
        self.evaluationClaims = evaluationClaims
    }

    public static func make(
        domain: CircleDomainDescriptor,
        polynomial: CircleCodewordPolynomial,
        storageIndices: [Int]
    ) throws -> CirclePCSFRIPolynomialClaimV1 {
        let normalizedIndices = try normalizeStorageIndices(storageIndices, domain: domain)
        let claims = try normalizedIndices.map { storageIndex in
            let naturalIndex = try CircleDomainOracle.naturalDomainIndex(
                forStorageIndex: storageIndex,
                descriptor: domain
            )
            let point = try CircleDomainOracle.point(
                in: domain,
                naturalDomainIndex: naturalIndex
            )
            return try CirclePCSFRIEvaluationClaimV1(
                storageIndex: UInt64(storageIndex),
                point: point,
                value: try CircleCodewordOracle.evaluate(polynomial: polynomial, at: point)
            )
        }
        return try CirclePCSFRIPolynomialClaimV1(
            domain: domain,
            polynomial: polynomial,
            evaluationClaims: claims
        )
    }

    private static func normalizeStorageIndices(
        _ storageIndices: [Int],
        domain: CircleDomainDescriptor
    ) throws -> [Int] {
        guard !storageIndices.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        let sorted = storageIndices.sorted()
        var previous: Int?
        for storageIndex in sorted {
            guard storageIndex >= 0,
                  storageIndex < domain.size,
                  previous.map({ $0 < storageIndex }) ?? true else {
                throw AppleZKProverError.invalidInputLayout
            }
            previous = storageIndex
        }
        return sorted
    }
}

public enum CirclePCSFRIPolynomialClaimDigestV1 {
    private static let domain = Data("AppleZKProver.CirclePCS.PolynomialClaim.V1".utf8)

    public static func digest(_ claim: CirclePCSFRIPolynomialClaimV1) throws -> Data {
        var data = Data()
        data.append(try domainFrame())
        data.append(try CircleDomainDescriptorCodecV1.encode(claim.domain))
        data.append(try polynomialFrame(
            xCoefficientCount: claim.polynomial.xCoefficients.count,
            yCoefficientCount: claim.polynomial.yCoefficients.count
        ))
        data.append(QM31CanonicalEncoding.pack(claim.polynomial.xCoefficients))
        data.append(QM31CanonicalEncoding.pack(claim.polynomial.yCoefficients))
        data.append(try evaluationClaimFrame(count: claim.evaluationClaims.count))
        for evaluationClaim in claim.evaluationClaims {
            CanonicalBinary.appendUInt64(evaluationClaim.storageIndex, to: &data)
            CanonicalBinary.appendUInt32(evaluationClaim.point.x, to: &data)
            CanonicalBinary.appendUInt32(evaluationClaim.point.y, to: &data)
            data.append(QM31CanonicalEncoding.pack(evaluationClaim.value))
        }
        return SHA3Oracle.sha3_256(data)
    }

    private static func domainFrame() throws -> Data {
        var frame = baseFrame(type: 0)
        CanonicalBinary.appendUInt32(try checkedUInt32(domain.count), to: &frame)
        frame.append(domain)
        CanonicalBinary.appendUInt32(CirclePCSFRIProofV1.proofVersion, to: &frame)
        CanonicalBinary.appendUInt32(CirclePCSFRIProofV1.currentTranscriptVersion, to: &frame)
        return frame
    }

    private static func polynomialFrame(
        xCoefficientCount: Int,
        yCoefficientCount: Int
    ) throws -> Data {
        var frame = baseFrame(type: 1)
        CanonicalBinary.appendUInt32(try checkedUInt32(xCoefficientCount), to: &frame)
        CanonicalBinary.appendUInt32(try checkedUInt32(yCoefficientCount), to: &frame)
        CanonicalBinary.appendUInt32(try checkedUInt32(QM31CanonicalEncoding.elementByteCount), to: &frame)
        return frame
    }

    private static func evaluationClaimFrame(count: Int) throws -> Data {
        var frame = baseFrame(type: 2)
        CanonicalBinary.appendUInt32(try checkedUInt32(count), to: &frame)
        return frame
    }

    private static func baseFrame(type: UInt8) -> Data {
        var frame = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &frame)
        frame.append(domain)
        frame.append(type)
        return frame
    }
}

public enum CircleFirstFoldPCSProofBuilderV1 {
    public static func prove(
        evaluations: [QM31Element],
        domain: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputs: CirclePCSFRIPublicInputsV1,
        claimedEvaluationIndices: [Int] = []
    ) throws -> CirclePCSFRIProofV1 {
        try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: securityParameters,
            publicInputs: publicInputs,
            roundCount: 1,
            claimedEvaluationIndices: claimedEvaluationIndices
        )
    }
}

public enum CircleFRIProofBuilderV1 {
    public static func prove(
        evaluations: [QM31Element],
        domain: CircleDomainDescriptor,
        securityParameters: CircleFRISecurityParametersV1,
        publicInputs: CirclePCSFRIPublicInputsV1,
        roundCount: Int,
        claimedEvaluationIndices: [Int] = []
    ) throws -> CirclePCSFRIProofV1 {
        guard domain.storageOrder == .circleDomainBitReversed,
              domain.isCanonical,
              evaluations.count == domain.size,
              securityParameters.foldingStep == 1,
              securityParameters.grindingBits <= CircleFRIGrindingV1.maximumLocalSearchBits,
              roundCount > 0,
              roundCount <= Int(domain.logSize) else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        let normalizedClaimedIndices = try normalizeClaimedEvaluationIndices(
            claimedEvaluationIndices,
            domain: domain
        )

        let inverseDomainLayers = try CircleFRILayerOracleV1.inverseDomainLayers(
            for: domain,
            roundCount: roundCount
        )
        var committedLayers: [[QM31Element]] = []
        var commitments: [Data] = []
        var challenges: [QM31Element] = []
        committedLayers.reserveCapacity(roundCount)
        commitments.reserveCapacity(roundCount)
        challenges.reserveCapacity(roundCount)

        var current = evaluations
        for roundIndex in 0..<roundCount {
            committedLayers.append(current)
            let layerBytes = QM31CanonicalEncoding.pack(current)
            let commitment = try MerkleOracle.rootSHA3_256(
                rawLeaves: layerBytes,
                leafCount: current.count,
                leafStride: QM31CanonicalEncoding.elementByteCount,
                leafLength: QM31CanonicalEncoding.elementByteCount
            )
            commitments.append(commitment)
            let prefixChallenges = try CircleFRITranscriptV1.deriveChallenges(
                domain: domain,
                securityParameters: securityParameters,
                publicInputDigest: publicInputs.publicInputDigest,
                commitments: commitments
            )
            guard prefixChallenges.count == commitments.count else {
                throw AppleZKProverError.invalidInputLayout
            }
            let challenge = prefixChallenges[roundIndex]
            challenges.append(challenge)
            if roundIndex == 0 {
                current = try CircleFRIFoldOracle.foldCircleIntoLine(
                    evaluations: current,
                    domain: domain,
                    challenge: challenge
                )
            } else {
                current = try QM31FRIFoldOracle.fold(
                    evaluations: current,
                    inverseDomainPoints: inverseDomainLayers[roundIndex],
                    challenge: challenge
                )
            }
        }
        let finalLayer = current
        let grindingNonce = try CircleFRITranscriptV1.findGrindingNonce(
            domain: domain,
            securityParameters: securityParameters,
            publicInputDigest: publicInputs.publicInputDigest,
            commitments: commitments,
            finalLayer: finalLayer
        )
        let transcript = try CircleFRITranscriptV1.derive(
            domain: domain,
            securityParameters: securityParameters,
            publicInputDigest: publicInputs.publicInputDigest,
            commitments: commitments,
            finalLayer: finalLayer,
            grindingNonce: grindingNonce
        )
        guard transcript.challenges == challenges else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Circle FRI transcript challenge changed after final-layer binding."
            )
        }

        let queries = try transcript.queryPairIndices.map { pairIndex in
            try makeQuery(
                pairIndex: pairIndex,
                layers: committedLayers
            )
        }
        let claimedEvaluationOpenings = try makeClaimedEvaluationOpenings(
            storageIndices: normalizedClaimedIndices,
            evaluations: evaluations
        )
        return try CirclePCSFRIProofV1(
            domain: domain,
            securityParameters: securityParameters,
            publicInputDigest: publicInputs.publicInputDigest,
            commitments: commitments,
            finalLayer: finalLayer,
            queries: queries,
            claimedEvaluationOpenings: claimedEvaluationOpenings,
            grindingNonce: grindingNonce
        )
    }

    private static func makeQuery(
        pairIndex: Int,
        layers: [[QM31Element]]
    ) throws -> CircleFRIQueryV1 {
        guard pairIndex >= 0,
              !layers.isEmpty,
              pairIndex < layers[0].count / 2 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var queryLayers: [CircleFRIQueryLayerOpeningV1] = []
        queryLayers.reserveCapacity(layers.count)
        var currentPairIndex = pairIndex
        for (layerIndex, layer) in layers.enumerated() {
            guard currentPairIndex >= 0,
                  currentPairIndex < layer.count / 2 else {
                throw AppleZKProverError.invalidInputLayout
            }
            let layerBytes = QM31CanonicalEncoding.pack(layer)
            let leftIndex = currentPairIndex * 2
            let rightIndex = leftIndex + 1
            let left = try makeOpening(
                leafIndex: leftIndex,
                value: layer[leftIndex],
                layerBytes: layerBytes,
                leafCount: layer.count
            )
            let right = try makeOpening(
                leafIndex: rightIndex,
                value: layer[rightIndex],
                layerBytes: layerBytes,
                leafCount: layer.count
            )
            queryLayers.append(CircleFRIQueryLayerOpeningV1(
                layerIndex: UInt32(layerIndex),
                pairIndex: UInt64(currentPairIndex),
                left: left,
                right: right
            ))
            currentPairIndex >>= 1
        }
        return try CircleFRIQueryV1(
            initialPairIndex: UInt64(pairIndex),
            layers: queryLayers
        )
    }

    private static func makeOpening(
        leafIndex: Int,
        value: QM31Element,
        layerBytes: Data,
        leafCount: Int
    ) throws -> CircleFRIValueOpeningV1 {
        let opening = try MerkleOracle.openingSHA3_256(
            rawLeaves: layerBytes,
            leafCount: leafCount,
            leafStride: QM31CanonicalEncoding.elementByteCount,
            leafLength: QM31CanonicalEncoding.elementByteCount,
            leafIndex: leafIndex
        )
        guard opening.leaf == QM31CanonicalEncoding.pack(value) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Circle FRI query opening leaf did not match the selected evaluation."
            )
        }
        return try CircleFRIValueOpeningV1(
            leafIndex: UInt64(leafIndex),
            value: value,
            siblingHashes: opening.siblingHashes
        )
    }

    private static func makeClaimedEvaluationOpenings(
        storageIndices: [Int],
        evaluations: [QM31Element]
    ) throws -> [CircleFRIValueOpeningV1] {
        guard !storageIndices.isEmpty else {
            return []
        }
        let layerBytes = QM31CanonicalEncoding.pack(evaluations)
        return try storageIndices.map { storageIndex in
            try makeOpening(
                leafIndex: storageIndex,
                value: evaluations[storageIndex],
                layerBytes: layerBytes,
                leafCount: evaluations.count
            )
        }
    }

    private static func normalizeClaimedEvaluationIndices(
        _ storageIndices: [Int],
        domain: CircleDomainDescriptor
    ) throws -> [Int] {
        guard !storageIndices.isEmpty else {
            return []
        }
        let sorted = storageIndices.sorted()
        var previous: Int?
        for storageIndex in sorted {
            guard storageIndex >= 0,
                  storageIndex < domain.size,
                  previous.map({ $0 < storageIndex }) ?? true else {
                throw AppleZKProverError.invalidInputLayout
            }
            previous = storageIndex
        }
        return sorted
    }
}

public enum CirclePCSFRIProofVerifierV1 {
    public static func verify(
        proof: CirclePCSFRIProofV1,
        publicInputs: CirclePCSFRIPublicInputsV1
    ) throws -> Bool {
        guard proof.publicInputDigest == publicInputs.publicInputDigest,
              proof.securityParameters.foldingStep == 1,
              !proof.commitments.isEmpty,
              proof.commitments.count <= Int(proof.domain.logSize),
              proof.finalLayer.count == (proof.domain.size >> proof.commitments.count) else {
            return false
        }
        try QM31Field.validateCanonical(proof.finalLayer)

        guard let transcript = try? CircleFRITranscriptV1.derive(proof: proof) else {
            return false
        }
        guard transcript.challenges.count == proof.commitments.count,
              transcript.queryPairIndices.count == proof.queries.count else {
            return false
        }
        let inverseDomainLayers = try CircleFRILayerOracleV1.inverseDomainLayers(
            for: proof.domain,
            roundCount: proof.commitments.count
        )

        for queryOffset in 0..<proof.queries.count {
            let expectedPairIndex = transcript.queryPairIndices[queryOffset]
            let query = proof.queries[queryOffset]
            guard query.initialPairIndex == UInt64(expectedPairIndex),
                  query.layers.count == proof.commitments.count else {
                return false
            }

            var pairIndex = expectedPairIndex
            var expectedLayerValue: (index: Int, value: QM31Element)?
            for roundIndex in 0..<proof.commitments.count {
                let layer = query.layers[roundIndex]
                let layerCount = proof.domain.size >> roundIndex
                guard layer.layerIndex == UInt32(roundIndex),
                      layer.pairIndex == UInt64(pairIndex),
                      pairIndex >= 0,
                      pairIndex < layerCount / 2 else {
                    return false
                }

                let leftIndex = pairIndex * 2
                let rightIndex = leftIndex + 1
                guard try verifyOpening(
                    layer.left,
                    expectedRoot: proof.commitments[roundIndex],
                    expectedLeafIndex: leftIndex,
                    expectedSiblingCount: log2(layerCount)
                ),
                try verifyOpening(
                    layer.right,
                    expectedRoot: proof.commitments[roundIndex],
                    expectedLeafIndex: rightIndex,
                    expectedSiblingCount: log2(layerCount)
                ) else {
                    return false
                }

                if let expectedLayerValue {
                    if expectedLayerValue.index == leftIndex {
                        guard expectedLayerValue.value == layer.left.value else { return false }
                    } else if expectedLayerValue.index == rightIndex {
                        guard expectedLayerValue.value == layer.right.value else { return false }
                    } else {
                        return false
                    }
                }

                let folded = try foldPair(
                    left: layer.left.value,
                    right: layer.right.value,
                    inverseDomainPoint: inverseDomainLayers[roundIndex][pairIndex],
                    challenge: transcript.challenges[roundIndex]
                )
                expectedLayerValue = (index: pairIndex, value: folded)
                pairIndex >>= 1
            }

            guard let expectedLayerValue,
                  expectedLayerValue.index >= 0,
                  expectedLayerValue.index < proof.finalLayer.count,
                  proof.finalLayer[expectedLayerValue.index] == expectedLayerValue.value else {
                return false
            }
        }
        return true
    }

    public static func verify(
        proof: CirclePCSFRIProofV1,
        publicInputDigest: Data
    ) throws -> Bool {
        try verify(
            proof: proof,
            publicInputs: try CirclePCSFRIPublicInputsV1(publicInputDigest: publicInputDigest)
        )
    }

    private static func verifyOpening(
        _ opening: CircleFRIValueOpeningV1,
        expectedRoot: Data,
        expectedLeafIndex: Int,
        expectedSiblingCount: Int
    ) throws -> Bool {
        guard expectedRoot.count == 32,
              opening.leafIndex == UInt64(expectedLeafIndex),
              opening.siblingHashes.count == expectedSiblingCount else {
            return false
        }
        let merkleOpening = MerkleOpeningProof(
            leafIndex: expectedLeafIndex,
            leaf: QM31CanonicalEncoding.pack(opening.value),
            siblingHashes: opening.siblingHashes,
            root: expectedRoot
        )
        return try MerkleOracle.verifySHA3_256(opening: merkleOpening)
    }

    private static func foldPair(
        left: QM31Element,
        right: QM31Element,
        inverseDomainPoint: QM31Element,
        challenge: QM31Element
    ) throws -> QM31Element {
        try QM31Field.validateCanonical([left, right, inverseDomainPoint, challenge])
        guard !QM31Field.isZero(inverseDomainPoint) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let evenNumerator = QM31Field.add(left, right)
        let oddNumerator = QM31Field.subtract(left, right)
        let oddAtSquare = QM31Field.multiply(oddNumerator, inverseDomainPoint)
        let mixed = QM31Field.add(evenNumerator, QM31Field.multiply(challenge, oddAtSquare))
        return QM31Field.multiply(mixed, QM31FRIFoldOracle.inverseTwo)
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

public enum CirclePCSFRIPolynomialVerifierV1 {
    public static func verify(
        proof: CirclePCSFRIProofV1,
        polynomialClaim: CirclePCSFRIPolynomialClaimV1
    ) throws -> Bool {
        let publicInputs = try CirclePCSFRIPublicInputsV1(polynomialClaim: polynomialClaim)
        guard proof.publicInputDigest == publicInputs.publicInputDigest,
              proof.domain == polynomialClaim.domain,
              proof.claimedEvaluationOpenings.count == polynomialClaim.evaluationClaims.count,
              coefficientCountsFitDomainAndSecurity(
                polynomialClaim.polynomial,
                proof: proof
              ),
              try CirclePCSFRIProofVerifierV1.verify(
                proof: proof,
                publicInputs: publicInputs
              ) else {
            return false
        }

        for (claim, opening) in zip(polynomialClaim.evaluationClaims, proof.claimedEvaluationOpenings) {
            guard try claimMatchesDomainAndPolynomial(
                claim,
                polynomial: polynomialClaim.polynomial,
                domain: proof.domain
            ),
            opening.leafIndex == claim.storageIndex,
            opening.value == claim.value,
            try verifyClaimOpening(
                opening,
                expectedRoot: proof.commitments[0],
                domain: proof.domain
            ) else {
                return false
            }
        }
        return true
    }

    private static func coefficientCountsFitDomainAndSecurity(
        _ polynomial: CircleCodewordPolynomial,
        proof: CirclePCSFRIProofV1
    ) -> Bool {
        guard proof.securityParameters.logBlowupFactor <= proof.domain.logSize else {
            return false
        }
        let maxCoefficientCount = max(
            1,
            proof.domain.size >> Int(proof.securityParameters.logBlowupFactor)
        )
        return polynomial.xCoefficients.count <= maxCoefficientCount
            && polynomial.yCoefficients.count <= maxCoefficientCount
    }

    private static func claimMatchesDomainAndPolynomial(
        _ claim: CirclePCSFRIEvaluationClaimV1,
        polynomial: CircleCodewordPolynomial,
        domain: CircleDomainDescriptor
    ) throws -> Bool {
        guard claim.storageIndex < UInt64(domain.size),
              claim.storageIndex <= UInt64(Int.max) else {
            return false
        }
        let storageIndex = Int(claim.storageIndex)
        let naturalIndex = try CircleDomainOracle.naturalDomainIndex(
            forStorageIndex: storageIndex,
            descriptor: domain
        )
        let expectedPoint = try CircleDomainOracle.point(
            in: domain,
            naturalDomainIndex: naturalIndex
        )
        guard claim.point == expectedPoint else {
            return false
        }
        return try CircleCodewordOracle.evaluate(
            polynomial: polynomial,
            at: claim.point
        ) == claim.value
    }

    private static func verifyClaimOpening(
        _ opening: CircleFRIValueOpeningV1,
        expectedRoot: Data,
        domain: CircleDomainDescriptor
    ) throws -> Bool {
        guard expectedRoot.count == 32,
              opening.leafIndex <= UInt64(Int.max),
              opening.leafIndex < UInt64(domain.size),
              opening.siblingHashes.count == log2(domain.size) else {
            return false
        }
        let merkleOpening = MerkleOpeningProof(
            leafIndex: Int(opening.leafIndex),
            leaf: QM31CanonicalEncoding.pack(opening.value),
            siblingHashes: opening.siblingHashes,
            root: expectedRoot
        )
        return try MerkleOracle.verifySHA3_256(opening: merkleOpening)
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

public struct CirclePCSFRIStatementV1: Equatable, Sendable {
    public let parameterSet: CirclePCSFRIParameterSetV1
    public let polynomialClaim: CirclePCSFRIPolynomialClaimV1

    public init(
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128,
        polynomialClaim: CirclePCSFRIPolynomialClaimV1
    ) throws {
        try parameterSet.validateDomain(polynomialClaim.domain)
        guard try Self.coefficientBudgetFits(
            polynomialClaim.polynomial,
            parameterSet: parameterSet,
            domain: polynomialClaim.domain
        ) else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.parameterSet = parameterSet
        self.polynomialClaim = polynomialClaim
    }

    public func publicInputs() throws -> CirclePCSFRIPublicInputsV1 {
        try CirclePCSFRIPublicInputsV1(polynomialClaim: polynomialClaim)
    }

    public func roundCount() throws -> Int {
        try parameterSet.roundCount(for: polynomialClaim.domain)
    }

    public func claimedEvaluationIndices() throws -> [Int] {
        try polynomialClaim.evaluationClaims.map { claim in
            guard claim.storageIndex <= UInt64(Int.max) else {
                throw AppleZKProverError.invalidInputLayout
            }
            return Int(claim.storageIndex)
        }
    }

    private static func coefficientBudgetFits(
        _ polynomial: CircleCodewordPolynomial,
        parameterSet: CirclePCSFRIParameterSetV1,
        domain: CircleDomainDescriptor
    ) throws -> Bool {
        let capacity = try parameterSet.committedCoefficientCapacity(for: domain)
        let used = polynomial.xCoefficients.count + polynomial.yCoefficients.count
        return used > 0 && used <= capacity
    }
}

public enum CirclePCSFRIContractProverV1 {
    public static func prove(statement: CirclePCSFRIStatementV1) throws -> CirclePCSFRIProofV1 {
        let domain = statement.polynomialClaim.domain
        let evaluations = try CircleCodewordOracle.evaluate(
            polynomial: statement.polynomialClaim.polynomial,
            domain: domain
        )
        return try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: statement.parameterSet.securityParameters,
            publicInputs: statement.publicInputs(),
            roundCount: statement.roundCount(),
            claimedEvaluationIndices: statement.claimedEvaluationIndices()
        )
    }
}

public enum CirclePCSFRIContractVerifierV1 {
    public static func verify(
        proof: CirclePCSFRIProofV1,
        statement: CirclePCSFRIStatementV1
    ) throws -> Bool {
        guard proof.domain == statement.polynomialClaim.domain,
              try statement.parameterSet.acceptsProofShape(proof),
              proof.claimedEvaluationOpenings.count == statement.polynomialClaim.evaluationClaims.count,
              try CirclePCSFRIPolynomialVerifierV1.verify(
                proof: proof,
                polynomialClaim: statement.polynomialClaim
              ) else {
            return false
        }
        return true
    }

    public static func verify(
        encodedProof: Data,
        statement: CirclePCSFRIStatementV1
    ) throws -> Bool {
        try verify(
            proof: CirclePCSFRIProofCodecV1.decode(encodedProof),
            statement: statement
        )
    }
}

enum CanonicalBinary {
    static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }

    static func appendUInt64(_ value: UInt64, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
        data.append(UInt8((value >> 32) & 0xff))
        data.append(UInt8((value >> 40) & 0xff))
        data.append(UInt8((value >> 48) & 0xff))
        data.append(UInt8((value >> 56) & 0xff))
    }

    static func appendLengthPrefixed(_ payload: Data, to data: inout Data) throws {
        appendUInt32(try checkedUInt32(payload.count), to: &data)
        data.append(payload)
    }
}

struct CanonicalByteReader {
    private let bytes: [UInt8]
    private var offset: Int

    init(_ data: Data) {
        self.bytes = Array(data)
        self.offset = 0
    }

    var isAtEnd: Bool {
        offset == bytes.count
    }

    mutating func readUInt32() throws -> UInt32 {
        let data = try readBytes(count: 4)
        return UInt32(data[0])
            | (UInt32(data[1]) << 8)
            | (UInt32(data[2]) << 16)
            | (UInt32(data[3]) << 24)
    }

    mutating func readUInt64() throws -> UInt64 {
        let data = try readBytes(count: 8)
        return UInt64(data[0])
            | (UInt64(data[1]) << 8)
            | (UInt64(data[2]) << 16)
            | (UInt64(data[3]) << 24)
            | (UInt64(data[4]) << 32)
            | (UInt64(data[5]) << 40)
            | (UInt64(data[6]) << 48)
            | (UInt64(data[7]) << 56)
    }

    mutating func readLengthPrefixed() throws -> Data {
        let count = try readUInt32()
        guard UInt64(count) <= UInt64(Int.max) else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try readBytes(count: Int(count))
    }

    mutating func readBytes(count: Int) throws -> Data {
        let end = offset.addingReportingOverflow(count)
        guard count >= 0,
              !end.overflow,
              end.partialValue <= bytes.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        defer { offset = end.partialValue }
        return Data(bytes[offset..<end.partialValue])
    }

    func finish() throws {
        guard offset == bytes.count else {
            throw AppleZKProverError.invalidInputLayout
        }
    }
}
