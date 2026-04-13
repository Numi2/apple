import Foundation

public enum QM31FRIFoldOracle {
    public static let inverseTwo = QM31Element(
        a: 1_073_741_824,
        b: 0,
        c: 0,
        d: 0
    )

    public static func fold(
        evaluations: [QM31Element],
        inverseDomainPoints: [QM31Element],
        challenge: QM31Element
    ) throws -> [QM31Element] {
        guard evaluations.count > 1,
              evaluations.count.isMultiple(of: 2),
              inverseDomainPoints.count == evaluations.count / 2 else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        try QM31Field.validateCanonical(inverseDomainPoints)
        try QM31Field.validateCanonical([challenge])
        guard inverseDomainPoints.allSatisfy({ !QM31Field.isZero($0) }) else {
            throw AppleZKProverError.invalidInputLayout
        }

        let pairCount = evaluations.count / 2
        var folded: [QM31Element] = []
        folded.reserveCapacity(pairCount)
        for index in 0..<pairCount {
            let positive = evaluations[index * 2]
            let negative = evaluations[index * 2 + 1]
            let evenNumerator = QM31Field.add(positive, negative)
            let oddNumerator = QM31Field.subtract(positive, negative)
            let oddAtSquare = QM31Field.multiply(oddNumerator, inverseDomainPoints[index])
            let mixed = QM31Field.add(
                evenNumerator,
                QM31Field.multiply(challenge, oddAtSquare)
            )
            folded.append(QM31Field.multiply(mixed, inverseTwo))
        }
        return folded
    }
}

public struct QM31FRIFoldRound: Equatable, Sendable {
    public let inverseDomainPoints: [QM31Element]
    public let challenge: QM31Element

    public init(inverseDomainPoints: [QM31Element], challenge: QM31Element) {
        self.inverseDomainPoints = inverseDomainPoints
        self.challenge = challenge
    }
}

public enum QM31FRIFoldChainOracle {
    public static func fold(
        evaluations: [QM31Element],
        rounds: [QM31FRIFoldRound]
    ) throws -> [QM31Element] {
        guard !rounds.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }

        var current = evaluations
        for round in rounds {
            current = try QM31FRIFoldOracle.fold(
                evaluations: current,
                inverseDomainPoints: round.inverseDomainPoints,
                challenge: round.challenge
            )
        }
        return current
    }
}

public struct QM31FRIFoldTranscriptOracleResult: Equatable, Sendable {
    public let values: [QM31Element]
    public let challenges: [QM31Element]

    public init(values: [QM31Element], challenges: [QM31Element]) {
        self.values = values
        self.challenges = challenges
    }
}

public enum QM31FRIFoldTranscriptOracle {
    public static let commitmentByteCount = 32

    public static func deriveChallenges(
        inputCount: Int,
        roundCommitments: [Data]
    ) throws -> [QM31Element] {
        let roundCounts = try QM31FRIFoldTranscriptFraming.roundCounts(
            inputCount: inputCount,
            roundCount: roundCommitments.count
        )
        var transcript = SHA3Oracle.TranscriptState()
        try transcript.absorb(QM31FRIFoldTranscriptFraming.header(
            inputCount: inputCount,
            roundCount: roundCommitments.count,
            commitmentByteCount: commitmentByteCount
        ))

        var challenges: [QM31Element] = []
        challenges.reserveCapacity(roundCommitments.count)
        for roundIndex in 0..<roundCommitments.count {
            let commitment = roundCommitments[roundIndex]
            guard commitment.count == commitmentByteCount else {
                throw AppleZKProverError.invalidInputLayout
            }

            try transcript.absorb(QM31FRIFoldTranscriptFraming.roundCommitment(
                roundIndex: roundIndex,
                inputCount: roundCounts[roundIndex].input,
                outputCount: roundCounts[roundIndex].output,
                commitmentByteCount: commitmentByteCount
            ))
            try transcript.absorb(commitment)
            try transcript.absorb(QM31FRIFoldTranscriptFraming.challenge(roundIndex: roundIndex))

            let limbs = try transcript.squeezeUInt32(count: 4, modulus: QM31Field.modulus)
            challenges.append(QM31Element(a: limbs[0], b: limbs[1], c: limbs[2], d: limbs[3]))
        }
        return challenges
    }

    public static func fold(
        evaluations: [QM31Element],
        inverseDomainLayers: [[QM31Element]],
        roundCommitments: [Data]
    ) throws -> QM31FRIFoldTranscriptOracleResult {
        guard inverseDomainLayers.count == roundCommitments.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        let challenges = try deriveChallenges(
            inputCount: evaluations.count,
            roundCommitments: roundCommitments
        )
        let rounds = zip(inverseDomainLayers, challenges).map {
            QM31FRIFoldRound(inverseDomainPoints: $0.0, challenge: $0.1)
        }
        let values = try QM31FRIFoldChainOracle.fold(evaluations: evaluations, rounds: rounds)
        return QM31FRIFoldTranscriptOracleResult(values: values, challenges: challenges)
    }
}

public struct QM31FRIMerkleFoldChainOracleResult: Equatable, Sendable {
    public let values: [QM31Element]
    public let commitments: [Data]
    public let challenges: [QM31Element]

    public init(values: [QM31Element], commitments: [Data], challenges: [QM31Element]) {
        self.values = values
        self.commitments = commitments
        self.challenges = challenges
    }
}

public enum QM31FRIMerkleFoldChainOracle {
    public static let leafByteCount = QM31FRILeafEncoding.elementByteCount

    public static func commitAndFold(
        evaluations: [QM31Element],
        inverseDomainLayers: [[QM31Element]]
    ) throws -> QM31FRIMerkleFoldChainOracleResult {
        guard !inverseDomainLayers.isEmpty,
              evaluations.count > 1,
              evaluations.count.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)

        let roundCounts = try QM31FRIFoldTranscriptFraming.roundCounts(
            inputCount: evaluations.count,
            roundCount: inverseDomainLayers.count
        )
        guard inverseDomainLayers.enumerated().allSatisfy({ index, layer in
            layer.count == roundCounts[index].output
        }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        for layer in inverseDomainLayers {
            try QM31Field.validateCanonical(layer)
            guard layer.allSatisfy({ !QM31Field.isZero($0) }) else {
                throw AppleZKProverError.invalidInputLayout
            }
        }

        var transcript = SHA3Oracle.TranscriptState()
        try transcript.absorb(QM31FRIFoldTranscriptFraming.header(
            inputCount: evaluations.count,
            roundCount: inverseDomainLayers.count,
            commitmentByteCount: QM31FRIFoldTranscriptOracle.commitmentByteCount
        ))

        var current = evaluations
        var commitments: [Data] = []
        var challenges: [QM31Element] = []
        commitments.reserveCapacity(inverseDomainLayers.count)
        challenges.reserveCapacity(inverseDomainLayers.count)

        for roundIndex in 0..<inverseDomainLayers.count {
            let root = try MerkleOracle.rootSHA3_256(
                rawLeaves: QM31FRILeafEncoding.packLittleEndian(current),
                leafCount: current.count,
                leafStride: leafByteCount,
                leafLength: leafByteCount
            )
            commitments.append(root)

            try transcript.absorb(QM31FRIFoldTranscriptFraming.roundCommitment(
                roundIndex: roundIndex,
                inputCount: roundCounts[roundIndex].input,
                outputCount: roundCounts[roundIndex].output,
                commitmentByteCount: QM31FRIFoldTranscriptOracle.commitmentByteCount
            ))
            try transcript.absorb(root)
            try transcript.absorb(QM31FRIFoldTranscriptFraming.challenge(roundIndex: roundIndex))
            let limbs = try transcript.squeezeUInt32(count: 4, modulus: QM31Field.modulus)
            let challenge = QM31Element(a: limbs[0], b: limbs[1], c: limbs[2], d: limbs[3])
            challenges.append(challenge)

            current = try QM31FRIFoldOracle.fold(
                evaluations: current,
                inverseDomainPoints: inverseDomainLayers[roundIndex],
                challenge: challenge
            )
        }

        return QM31FRIMerkleFoldChainOracleResult(
            values: current,
            commitments: commitments,
            challenges: challenges
        )
    }
}

public struct QM31FRIProof: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let inputCount: Int
    public let roundCount: Int
    public let queryCount: Int
    public let commitments: [Data]
    public let finalValues: [QM31Element]
    public let queries: [QM31FRIQueryProof]

    public init(
        version: UInt32 = currentVersion,
        inputCount: Int,
        roundCount: Int,
        queryCount: Int,
        commitments: [Data],
        finalValues: [QM31Element],
        queries: [QM31FRIQueryProof]
    ) {
        self.version = version
        self.inputCount = inputCount
        self.roundCount = roundCount
        self.queryCount = queryCount
        self.commitments = commitments
        self.finalValues = finalValues
        self.queries = queries
    }

    public func serialized() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func deserialize(_ data: Data) throws -> QM31FRIProof {
        do {
            return try JSONDecoder().decode(QM31FRIProof.self, from: data)
        } catch {
            throw AppleZKProverError.invalidInputLayout
        }
    }
}

public struct QM31FRIQueryProof: Equatable, Codable, Sendable {
    public let initialPairIndex: Int
    public let layers: [QM31FRILayerQueryProof]

    public init(initialPairIndex: Int, layers: [QM31FRILayerQueryProof]) {
        self.initialPairIndex = initialPairIndex
        self.layers = layers
    }
}

public struct QM31FRILayerQueryProof: Equatable, Codable, Sendable {
    public let layerIndex: Int
    public let pairIndex: Int
    public let leftOpening: MerkleOpeningProof
    public let rightOpening: MerkleOpeningProof

    public init(
        layerIndex: Int,
        pairIndex: Int,
        leftOpening: MerkleOpeningProof,
        rightOpening: MerkleOpeningProof
    ) {
        self.layerIndex = layerIndex
        self.pairIndex = pairIndex
        self.leftOpening = leftOpening
        self.rightOpening = rightOpening
    }
}

public enum QM31FRIProofBuilder {
    public static func prove(
        evaluations: [QM31Element],
        inverseDomainLayers: [[QM31Element]],
        queryCount: Int
    ) throws -> QM31FRIProof {
        try validatePublicInputs(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers,
            queryCount: queryCount
        )

        let committed = try QM31FRIMerkleFoldChainOracle.commitAndFold(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers
        )
        let transcript = try QM31FRIProofTranscript.derive(
            inputCount: evaluations.count,
            commitments: committed.commitments,
            finalValues: committed.values,
            queryCount: queryCount
        )
        guard transcript.challenges == committed.challenges else {
            throw AppleZKProverError.correctnessValidationFailed("QM31 FRI proof transcript did not reproduce fold challenges.")
        }

        var layers: [[QM31Element]] = []
        layers.reserveCapacity(inverseDomainLayers.count)
        var current = evaluations
        for roundIndex in 0..<inverseDomainLayers.count {
            layers.append(current)
            current = try QM31FRIFoldOracle.fold(
                evaluations: current,
                inverseDomainPoints: inverseDomainLayers[roundIndex],
                challenge: committed.challenges[roundIndex]
            )
        }
        guard current == committed.values else {
            throw AppleZKProverError.correctnessValidationFailed("QM31 FRI proof layer reconstruction diverged from committed oracle.")
        }

        let queryProofs = try transcript.queryPairIndices.map { initialPairIndex in
            try makeQueryProof(initialPairIndex: initialPairIndex, layers: layers)
        }

        return QM31FRIProof(
            inputCount: evaluations.count,
            roundCount: inverseDomainLayers.count,
            queryCount: queryCount,
            commitments: committed.commitments,
            finalValues: committed.values,
            queries: queryProofs
        )
    }

    private static func makeQueryProof(
        initialPairIndex: Int,
        layers: [[QM31Element]]
    ) throws -> QM31FRIQueryProof {
        var layerProofs: [QM31FRILayerQueryProof] = []
        layerProofs.reserveCapacity(layers.count)
        var pairIndex = initialPairIndex
        for (layerIndex, layer) in layers.enumerated() {
            guard pairIndex >= 0, pairIndex < layer.count / 2 else {
                throw AppleZKProverError.invalidInputLayout
            }
            let layerBytes = QM31FRILeafEncoding.packLittleEndian(layer)
            let leftIndex = pairIndex * 2
            let rightIndex = leftIndex + 1
            let left = try MerkleOracle.openingSHA3_256(
                rawLeaves: layerBytes,
                leafCount: layer.count,
                leafStride: QM31FRILeafEncoding.elementByteCount,
                leafLength: QM31FRILeafEncoding.elementByteCount,
                leafIndex: leftIndex
            )
            let right = try MerkleOracle.openingSHA3_256(
                rawLeaves: layerBytes,
                leafCount: layer.count,
                leafStride: QM31FRILeafEncoding.elementByteCount,
                leafLength: QM31FRILeafEncoding.elementByteCount,
                leafIndex: rightIndex
            )
            layerProofs.append(QM31FRILayerQueryProof(
                layerIndex: layerIndex,
                pairIndex: pairIndex,
                leftOpening: left,
                rightOpening: right
            ))
            pairIndex >>= 1
        }
        return QM31FRIQueryProof(initialPairIndex: initialPairIndex, layers: layerProofs)
    }
}

public enum QM31FRIProofVerifier {
    public static func verify(
        proof: QM31FRIProof,
        inverseDomainLayers: [[QM31Element]]
    ) throws -> Bool {
        try validateProofShape(proof, inverseDomainLayers: inverseDomainLayers)
        let transcript = try QM31FRIProofTranscript.derive(
            inputCount: proof.inputCount,
            commitments: proof.commitments,
            finalValues: proof.finalValues,
            queryCount: proof.queryCount
        )

        for queryIndex in 0..<proof.queryCount {
            let expectedInitialPair = transcript.queryPairIndices[queryIndex]
            let query = proof.queries[queryIndex]
            guard query.initialPairIndex == expectedInitialPair,
                  query.layers.count == proof.roundCount else {
                return false
            }

            var pairIndex = expectedInitialPair
            var expectedLayerValue: (index: Int, value: QM31Element)?
            for roundIndex in 0..<proof.roundCount {
                let layerProof = query.layers[roundIndex]
                let layerCount = proof.inputCount >> roundIndex
                guard layerProof.layerIndex == roundIndex,
                      layerProof.pairIndex == pairIndex,
                      pairIndex >= 0,
                      pairIndex < layerCount / 2 else {
                    return false
                }

                let root = proof.commitments[roundIndex]
                let leftIndex = pairIndex * 2
                let rightIndex = leftIndex + 1
                guard try verifyOpening(
                    layerProof.leftOpening,
                    expectedRoot: root,
                    expectedLeafIndex: leftIndex,
                    expectedSiblingCount: log2(layerCount)
                ),
                try verifyOpening(
                    layerProof.rightOpening,
                    expectedRoot: root,
                    expectedLeafIndex: rightIndex,
                    expectedSiblingCount: log2(layerCount)
                ) else {
                    return false
                }

                let left = try QM31FRILeafEncoding.unpackLittleEndian(layerProof.leftOpening.leaf)
                let right = try QM31FRILeafEncoding.unpackLittleEndian(layerProof.rightOpening.leaf)
                try QM31Field.validateCanonical([left, right])
                if let expectedLayerValue {
                    if expectedLayerValue.index == leftIndex {
                        guard expectedLayerValue.value == left else { return false }
                    } else if expectedLayerValue.index == rightIndex {
                        guard expectedLayerValue.value == right else { return false }
                    } else {
                        return false
                    }
                }

                let folded = try foldPair(
                    left: left,
                    right: right,
                    inverseDomainPoint: inverseDomainLayers[roundIndex][pairIndex],
                    challenge: transcript.challenges[roundIndex]
                )
                expectedLayerValue = (index: pairIndex, value: folded)
                pairIndex >>= 1
            }

            guard let expectedLayerValue,
                  expectedLayerValue.index >= 0,
                  expectedLayerValue.index < proof.finalValues.count,
                  proof.finalValues[expectedLayerValue.index] == expectedLayerValue.value else {
                return false
            }
        }

        return true
    }

    private static func verifyOpening(
        _ opening: MerkleOpeningProof,
        expectedRoot: Data,
        expectedLeafIndex: Int,
        expectedSiblingCount: Int
    ) throws -> Bool {
        guard opening.root == expectedRoot,
              opening.leafIndex == expectedLeafIndex,
              opening.leaf.count == QM31FRILeafEncoding.elementByteCount,
              opening.siblingHashes.count == expectedSiblingCount else {
            return false
        }
        return try MerkleOracle.verifySHA3_256(opening: opening)
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
}

struct QM31FRIProofTranscriptResult: Equatable, Sendable {
    let challenges: [QM31Element]
    let queryPairIndices: [Int]
}

enum QM31FRIProofTranscript {
    static func derive(
        inputCount: Int,
        commitments: [Data],
        finalValues: [QM31Element],
        queryCount: Int
    ) throws -> QM31FRIProofTranscriptResult {
        guard queryCount > 0,
              inputCount > 1,
              inputCount.nonzeroBitCount == 1,
              !commitments.isEmpty,
              commitments.allSatisfy({ $0.count == QM31FRIFoldTranscriptOracle.commitmentByteCount }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let roundCounts = try QM31FRIFoldTranscriptFraming.roundCounts(
            inputCount: inputCount,
            roundCount: commitments.count
        )
        let finalCount = inputCount >> commitments.count
        guard finalCount > 0,
              finalValues.count == finalCount,
              inputCount / 2 <= Int(UInt32.max) else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(finalValues)

        var transcript = SHA3Oracle.TranscriptState()
        try transcript.absorb(QM31FRIFoldTranscriptFraming.header(
            inputCount: inputCount,
            roundCount: commitments.count,
            commitmentByteCount: QM31FRIFoldTranscriptOracle.commitmentByteCount
        ))

        var challenges: [QM31Element] = []
        challenges.reserveCapacity(commitments.count)
        for roundIndex in 0..<commitments.count {
            try transcript.absorb(QM31FRIFoldTranscriptFraming.roundCommitment(
                roundIndex: roundIndex,
                inputCount: roundCounts[roundIndex].input,
                outputCount: roundCounts[roundIndex].output,
                commitmentByteCount: QM31FRIFoldTranscriptOracle.commitmentByteCount
            ))
            try transcript.absorb(commitments[roundIndex])
            try transcript.absorb(QM31FRIFoldTranscriptFraming.challenge(roundIndex: roundIndex))
            let limbs = try transcript.squeezeUInt32(count: 4, modulus: QM31Field.modulus)
            challenges.append(QM31Element(a: limbs[0], b: limbs[1], c: limbs[2], d: limbs[3]))
        }

        let finalLayerBytes = QM31FRILeafEncoding.packLittleEndian(finalValues)
        try transcript.absorb(QM31FRIProofTranscriptFraming.finalLayer(
            outputCount: finalValues.count,
            byteCount: finalLayerBytes.count
        ))
        try transcript.absorb(finalLayerBytes)
        try transcript.absorb(QM31FRIProofTranscriptFraming.queryRequest(
            queryCount: queryCount,
            initialPairCount: inputCount / 2
        ))
        let queryWords = try transcript.squeezeUInt32(count: queryCount, modulus: UInt32(inputCount / 2))
        return QM31FRIProofTranscriptResult(
            challenges: challenges,
            queryPairIndices: queryWords.map(Int.init)
        )
    }
}

enum QM31FRIProofTranscriptFraming {
    static let version: UInt32 = 1
    private static let domain = Data("AppleZKProver.QM31FRI.LinearProof".utf8)

    static func finalLayer(outputCount: Int, byteCount: Int) throws -> Data {
        var frame = baseFrame(type: 0)
        appendUInt64(UInt64(try checkedNonNegative(outputCount)), to: &frame)
        appendUInt64(UInt64(try checkedNonNegative(byteCount)), to: &frame)
        return frame
    }

    static func queryRequest(queryCount: Int, initialPairCount: Int) throws -> Data {
        var frame = baseFrame(type: 1)
        appendUInt32(try checkedUInt32(queryCount), to: &frame)
        appendUInt64(UInt64(try checkedNonNegative(initialPairCount)), to: &frame)
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

private func validatePublicInputs(
    evaluations: [QM31Element],
    inverseDomainLayers: [[QM31Element]],
    queryCount: Int
) throws {
    guard queryCount > 0,
          !inverseDomainLayers.isEmpty,
          evaluations.count > 1,
          evaluations.count.nonzeroBitCount == 1 else {
        throw AppleZKProverError.invalidInputLayout
    }
    try QM31Field.validateCanonical(evaluations)
    let roundCounts = try QM31FRIFoldTranscriptFraming.roundCounts(
        inputCount: evaluations.count,
        roundCount: inverseDomainLayers.count
    )
    for (index, layer) in inverseDomainLayers.enumerated() {
        guard layer.count == roundCounts[index].output else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(layer)
        guard layer.allSatisfy({ !QM31Field.isZero($0) }) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }
}

private func validateProofShape(
    _ proof: QM31FRIProof,
    inverseDomainLayers: [[QM31Element]]
) throws {
    guard proof.version == QM31FRIProof.currentVersion,
          proof.inputCount > 1,
          proof.inputCount.nonzeroBitCount == 1,
          proof.roundCount > 0,
          proof.queryCount > 0,
          proof.commitments.count == proof.roundCount,
          proof.queries.count == proof.queryCount,
          inverseDomainLayers.count == proof.roundCount else {
        throw AppleZKProverError.invalidInputLayout
    }
    let roundCounts = try QM31FRIFoldTranscriptFraming.roundCounts(
        inputCount: proof.inputCount,
        roundCount: proof.roundCount
    )
    guard proof.finalValues.count == (proof.inputCount >> proof.roundCount),
          proof.commitments.allSatisfy({ $0.count == QM31FRIFoldTranscriptOracle.commitmentByteCount }) else {
        throw AppleZKProverError.invalidInputLayout
    }
    try QM31Field.validateCanonical(proof.finalValues)
    for (index, layer) in inverseDomainLayers.enumerated() {
        guard layer.count == roundCounts[index].output else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(layer)
        guard layer.allSatisfy({ !QM31Field.isZero($0) }) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }
}

private func log2(_ value: Int) -> Int {
    var remaining = max(1, value)
    var result = 0
    while remaining > 1 {
        remaining >>= 1
        result += 1
    }
    return result
}

enum QM31FRILeafEncoding {
    static let elementByteCount = 4 * MemoryLayout<UInt32>.stride

    static func packLittleEndian(_ values: [QM31Element]) -> Data {
        var data = Data()
        data.reserveCapacity(values.count * elementByteCount)
        for value in values {
            appendUInt32LittleEndian(value.constant.real, to: &data)
            appendUInt32LittleEndian(value.constant.imaginary, to: &data)
            appendUInt32LittleEndian(value.uCoefficient.real, to: &data)
            appendUInt32LittleEndian(value.uCoefficient.imaginary, to: &data)
        }
        return data
    }

    static func unpackLittleEndian(_ data: Data) throws -> QM31Element {
        guard data.count == elementByteCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        return data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            return QM31Element(
                a: readUInt32LittleEndian(bytes, offset: 0),
                b: readUInt32LittleEndian(bytes, offset: 4),
                c: readUInt32LittleEndian(bytes, offset: 8),
                d: readUInt32LittleEndian(bytes, offset: 12)
            )
        }
    }

    private static func appendUInt32LittleEndian(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }

    private static func readUInt32LittleEndian(
        _ bytes: UnsafeBufferPointer<UInt8>,
        offset: Int
    ) -> UInt32 {
        UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }
}

enum QM31FRIFoldTranscriptFraming {
    static let version: UInt32 = 1
    static let challengeLimbCount: UInt32 = 4

    private static let domain = Data("AppleZKProver.QM31FRI.FoldChain".utf8)

    static func roundCounts(inputCount: Int, roundCount: Int) throws -> [(input: Int, output: Int)] {
        guard inputCount > 1, roundCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var counts: [(input: Int, output: Int)] = []
        counts.reserveCapacity(roundCount)
        var current = inputCount
        for _ in 0..<roundCount {
            guard current > 1, current.isMultiple(of: 2) else {
                throw AppleZKProverError.invalidInputLayout
            }
            let next = current / 2
            counts.append((input: current, output: next))
            current = next
        }
        return counts
    }

    static func header(
        inputCount: Int,
        roundCount: Int,
        commitmentByteCount: Int
    ) throws -> Data {
        var frame = baseFrame(type: 0)
        appendUInt64(UInt64(try checkedNonNegative(inputCount)), to: &frame)
        appendUInt32(try checkedUInt32(roundCount), to: &frame)
        appendUInt32(QM31Field.modulus, to: &frame)
        appendUInt32(challengeLimbCount, to: &frame)
        appendUInt32(try checkedUInt32(commitmentByteCount), to: &frame)
        return frame
    }

    static func roundCommitment(
        roundIndex: Int,
        inputCount: Int,
        outputCount: Int,
        commitmentByteCount: Int
    ) throws -> Data {
        var frame = baseFrame(type: 1)
        appendUInt32(try checkedUInt32(roundIndex), to: &frame)
        appendUInt64(UInt64(try checkedNonNegative(inputCount)), to: &frame)
        appendUInt64(UInt64(try checkedNonNegative(outputCount)), to: &frame)
        appendUInt32(try checkedUInt32(commitmentByteCount), to: &frame)
        return frame
    }

    static func challenge(roundIndex: Int) throws -> Data {
        var frame = baseFrame(type: 2)
        appendUInt32(try checkedUInt32(roundIndex), to: &frame)
        appendUInt32(QM31Field.modulus, to: &frame)
        appendUInt32(challengeLimbCount, to: &frame)
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

#if canImport(Metal)
import Metal

private struct QM31FRIFoldParams {
    var pairCount: UInt32
    var fieldModulus: UInt32
    var challengeA: UInt32
    var challengeB: UInt32
    var challengeC: UInt32
    var challengeD: UInt32
}

struct QM31FRIFoldTranscriptFrameData: Sendable {
    let prefix: [Data]
    let rounds: [Data]
    let challenges: [Data]
    let all: [Data]

    init(prefix: [Data], rounds: [Data], challenges: [Data]) throws {
        guard !prefix.isEmpty,
              rounds.count == challenges.count,
              prefix.allSatisfy({ !$0.isEmpty }),
              rounds.allSatisfy({ !$0.isEmpty }),
              challenges.allSatisfy({ !$0.isEmpty }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.prefix = prefix
        self.rounds = rounds
        self.challenges = challenges
        self.all = prefix + rounds + challenges
    }
}

public struct QM31FRIFoldResult: Sendable {
    public let values: [QM31Element]
    public let stats: GPUExecutionStats

    public init(values: [QM31Element], stats: GPUExecutionStats) {
        self.values = values
        self.stats = stats
    }
}

public struct QM31FRIFoldChainResult: Sendable {
    public let values: [QM31Element]
    public let stats: GPUExecutionStats

    public init(values: [QM31Element], stats: GPUExecutionStats) {
        self.values = values
        self.stats = stats
    }
}

public struct QM31FRIFoldTranscriptChainResult: Sendable {
    public let values: [QM31Element]
    public let challenges: [QM31Element]
    public let stats: GPUExecutionStats

    public init(values: [QM31Element], challenges: [QM31Element], stats: GPUExecutionStats) {
        self.values = values
        self.challenges = challenges
        self.stats = stats
    }
}

public struct QM31FRIMerkleFoldChainResult: Sendable {
    public let values: [QM31Element]
    public let commitments: [Data]
    public let challenges: [QM31Element]
    public let stats: GPUExecutionStats

    public init(
        values: [QM31Element],
        commitments: [Data],
        challenges: [QM31Element],
        stats: GPUExecutionStats
    ) {
        self.values = values
        self.commitments = commitments
        self.challenges = challenges
        self.stats = stats
    }
}

private struct QM31FRIFoldTranscriptFrameUpload {
    let buffer: MTLBuffer
    let byteCount: Int
}

public final class QM31FRIFoldPlan: @unchecked Sendable {
    private static let defaultUploadRingSlotCount = 3
    private static let elementByteCount = 4 * MemoryLayout<UInt32>.stride

    public let inputCount: Int
    public let outputCount: Int

    private let context: MetalContext
    private let pipeline: MTLComputePipelineState
    private let uploadRingEvaluations: SharedUploadRing
    private let uploadRingInverseDomain: SharedUploadRing
    private let arena: ResidencyArena
    private let evaluationVector: ArenaSlice
    private let inverseDomainVector: ArenaSlice
    private let outputVector: ArenaSlice
    private let outputReadback: MTLBuffer
    private let inputByteCount: Int
    private let outputByteCount: Int
    private let executionLock = NSLock()

    public init(context: MetalContext, inputCount: Int) throws {
        guard inputCount > 1,
              inputCount.isMultiple(of: 2),
              inputCount <= Int(UInt32.max) else {
            throw AppleZKProverError.invalidInputLayout
        }

        self.context = context
        self.inputCount = inputCount
        self.outputCount = inputCount / 2
        self.inputByteCount = try checkedBufferLength(inputCount, Self.elementByteCount)
        self.outputByteCount = try checkedBufferLength(inputCount / 2, Self.elementByteCount)
        self.pipeline = try context.pipeline(
            for: KernelSpec(kernel: "qm31_fri_fold", family: .scalar, queueMode: .metal3)
        )
        self.uploadRingEvaluations = try SharedUploadRing(
            device: context.device,
            slotCapacity: inputByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.QM31FRIFoldEvaluations"
        )
        self.uploadRingInverseDomain = try SharedUploadRing(
            device: context.device,
            slotCapacity: outputByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.QM31FRIFoldInverseDomain"
        )
        self.arena = try ResidencyArena(
            device: context.device,
            capacity: try Self.checkedSum([
                inputByteCount,
                outputByteCount,
                outputByteCount,
                3 * 256,
            ]),
            label: "AppleZKProver.QM31FRIFoldArena"
        )
        self.evaluationVector = try arena.allocate(length: inputByteCount, role: .sumcheckVector)
        self.inverseDomainVector = try arena.allocate(length: outputByteCount, role: .sumcheckVector)
        self.outputVector = try arena.allocate(length: outputByteCount, role: .sumcheckVector)
        self.outputReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: outputByteCount,
            label: "AppleZKProver.QM31FRIFoldReadback"
        )
    }

    public func execute(
        evaluations: [QM31Element],
        inverseDomainPoints: [QM31Element],
        challenge: QM31Element
    ) throws -> QM31FRIFoldResult {
        try validateInputs(
            evaluations: evaluations,
            inverseDomainPoints: inverseDomainPoints,
            challenge: challenge
        )
        let evaluationBytes = Self.packLittleEndian(evaluations)
        let inverseDomainBytes = Self.packLittleEndian(inverseDomainPoints)

        executionLock.lock()
        defer { executionLock.unlock() }

        let evaluationSlot = try uploadRingEvaluations.copy(evaluationBytes, byteCount: inputByteCount)
        let inverseDomainSlot = try uploadRingInverseDomain.copy(inverseDomainBytes, byteCount: outputByteCount)
        return try executeLocked(
            evaluationsBuffer: evaluationSlot.buffer,
            evaluationsOffset: evaluationSlot.offset,
            inverseDomainBuffer: inverseDomainSlot.buffer,
            inverseDomainOffset: inverseDomainSlot.offset,
            outputBuffer: outputVector.buffer,
            outputOffset: outputVector.offset,
            challenge: challenge,
            readOutput: true
        )
    }

    public func executeVerified(
        evaluations: [QM31Element],
        inverseDomainPoints: [QM31Element],
        challenge: QM31Element
    ) throws -> QM31FRIFoldResult {
        let expected = try QM31FRIFoldOracle.fold(
            evaluations: evaluations,
            inverseDomainPoints: inverseDomainPoints,
            challenge: challenge
        )
        let measured = try execute(
            evaluations: evaluations,
            inverseDomainPoints: inverseDomainPoints,
            challenge: challenge
        )
        guard measured.values == expected else {
            throw AppleZKProverError.correctnessValidationFailed("QM31 FRI fold GPU result did not match the CPU oracle.")
        }
        return measured
    }

    public func executeResident(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int = 0,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int = 0,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0,
        challenge: QM31Element
    ) throws -> GPUExecutionStats {
        try QM31Field.validateCanonical([challenge])

        executionLock.lock()
        defer { executionLock.unlock() }

        let result = try executeLocked(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: inverseDomainOffset,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset,
            challenge: challenge,
            readOutput: false
        )
        return result.stats
    }

    public func clearReusableBuffers() throws {
        executionLock.lock()
        defer { executionLock.unlock() }

        uploadRingEvaluations.clear()
        uploadRingInverseDomain.clear()
        MetalBufferFactory.zeroSharedBuffer(outputReadback)
        try MetalBufferFactory.zeroPrivateBuffers(
            [arena.buffer],
            context: context,
            label: "QM31FRIFold.PlanClear"
        )
    }

    private func executeLocked(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int,
        challenge: QM31Element,
        readOutput: Bool
    ) throws -> QM31FRIFoldResult {
        try validateBufferRange(buffer: evaluationsBuffer, offset: evaluationsOffset, byteCount: inputByteCount)
        try validateBufferRange(buffer: inverseDomainBuffer, offset: inverseDomainOffset, byteCount: outputByteCount)
        try validateBufferRange(buffer: outputBuffer, offset: outputOffset, byteCount: outputByteCount)
        try validateNoOutputAliasing(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: inverseDomainOffset,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset
        )

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "QM31.FRI.Fold"

        var kernelInputBuffer = evaluationsBuffer
        var kernelInputOffset = evaluationsOffset
        var kernelInverseBuffer = inverseDomainBuffer
        var kernelInverseOffset = inverseDomainOffset
        var kernelOutputBuffer = outputBuffer
        var kernelOutputOffset = outputOffset

        if readOutput {
            guard let uploadBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            uploadBlit.label = "QM31.FRI.Fold.Upload"
            uploadBlit.copy(
                from: evaluationsBuffer,
                sourceOffset: evaluationsOffset,
                to: evaluationVector.buffer,
                destinationOffset: evaluationVector.offset,
                size: inputByteCount
            )
            uploadBlit.copy(
                from: inverseDomainBuffer,
                sourceOffset: inverseDomainOffset,
                to: inverseDomainVector.buffer,
                destinationOffset: inverseDomainVector.offset,
                size: outputByteCount
            )
            uploadBlit.fill(buffer: outputVector.buffer, range: outputVector.offset..<(outputVector.offset + outputVector.length), value: 0)
            uploadBlit.endEncoding()
            kernelInputBuffer = evaluationVector.buffer
            kernelInputOffset = evaluationVector.offset
            kernelInverseBuffer = inverseDomainVector.buffer
            kernelInverseOffset = inverseDomainVector.offset
            kernelOutputBuffer = outputVector.buffer
            kernelOutputOffset = outputVector.offset
        }

        var params = QM31FRIFoldParams(
            pairCount: try checkedUInt32(outputCount),
            fieldModulus: QM31Field.modulus,
            challengeA: challenge.constant.real,
            challengeB: challenge.constant.imaginary,
            challengeC: challenge.uCoefficient.real,
            challengeD: challenge.uCoefficient.imaginary
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "QM31.FRI.Fold.Kernel"
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(kernelInputBuffer, offset: kernelInputOffset, index: 0)
        encoder.setBuffer(kernelInverseBuffer, offset: kernelInverseOffset, index: 1)
        encoder.setBuffer(kernelOutputBuffer, offset: kernelOutputOffset, index: 2)
        encoder.setBytes(&params, length: MemoryLayout<QM31FRIFoldParams>.stride, index: 3)
        context.dispatch1D(encoder, pipeline: pipeline, elementCount: outputCount)
        encoder.endEncoding()

        if readOutput {
            guard let readbackBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            readbackBlit.label = "QM31.FRI.Fold.Readback"
            readbackBlit.copy(
                from: outputVector.buffer,
                sourceOffset: outputVector.offset,
                to: outputReadback,
                destinationOffset: 0,
                size: outputByteCount
            )
            readbackBlit.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let stats = GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpuDuration(commandBuffer))
        let values = readOutput ? Self.readQM31Buffer(outputReadback, count: outputCount) : []
        return QM31FRIFoldResult(values: values, stats: stats)
    }

    private func validateInputs(
        evaluations: [QM31Element],
        inverseDomainPoints: [QM31Element],
        challenge: QM31Element
    ) throws {
        guard evaluations.count == inputCount,
              inverseDomainPoints.count == outputCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        try QM31Field.validateCanonical(inverseDomainPoints)
        try QM31Field.validateCanonical([challenge])
        guard inverseDomainPoints.allSatisfy({ !QM31Field.isZero($0) }) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private func validateBufferRange(buffer: MTLBuffer, offset: Int, byteCount: Int) throws {
        let end = offset.addingReportingOverflow(max(1, byteCount))
        guard offset >= 0,
              byteCount >= 0,
              !end.overflow,
              buffer.length >= end.partialValue else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private func validateNoOutputAliasing(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int
    ) throws {
        guard !rangesOverlap(
            lhsBuffer: outputBuffer,
            lhsOffset: outputOffset,
            lhsByteCount: outputByteCount,
            rhsBuffer: evaluationsBuffer,
            rhsOffset: evaluationsOffset,
            rhsByteCount: inputByteCount
        ),
        !rangesOverlap(
            lhsBuffer: outputBuffer,
            lhsOffset: outputOffset,
            lhsByteCount: outputByteCount,
            rhsBuffer: inverseDomainBuffer,
            rhsOffset: inverseDomainOffset,
            rhsByteCount: outputByteCount
        ) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private func rangesOverlap(
        lhsBuffer: MTLBuffer,
        lhsOffset: Int,
        lhsByteCount: Int,
        rhsBuffer: MTLBuffer,
        rhsOffset: Int,
        rhsByteCount: Int
    ) -> Bool {
        guard lhsBuffer === rhsBuffer else {
            return false
        }
        let lhsEnd = lhsOffset + lhsByteCount
        let rhsEnd = rhsOffset + rhsByteCount
        return lhsOffset < rhsEnd && rhsOffset < lhsEnd
    }

    private static func packLittleEndian(_ values: [QM31Element]) -> Data {
        QM31FRILeafEncoding.packLittleEndian(values)
    }

    private static func readQM31Buffer(_ buffer: MTLBuffer, count: Int) -> [QM31Element] {
        let wordCount = count * 4
        let raw = buffer.contents().bindMemory(to: UInt32.self, capacity: wordCount)
        return (0..<count).map { index in
            QM31Element(
                a: raw[index * 4],
                b: raw[index * 4 + 1],
                c: raw[index * 4 + 2],
                d: raw[index * 4 + 3]
            )
        }
    }

    private static func checkedSum(_ values: [Int]) throws -> Int {
        var total = 0
        for value in values {
            let next = total.addingReportingOverflow(value)
            guard value >= 0, !next.overflow else {
                throw AppleZKProverError.invalidInputLayout
            }
            total = next.partialValue
        }
        return total
    }

    private func gpuDuration(_ commandBuffer: MTLCommandBuffer) -> Double? {
        guard commandBuffer.gpuEndTime > commandBuffer.gpuStartTime else {
            return nil
        }
        return commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    }
}

public final class QM31FRIFoldChainPlan: @unchecked Sendable {
    private static let defaultUploadRingSlotCount = 3
    private static let elementByteCount = 4 * MemoryLayout<UInt32>.stride
    private static let commitmentByteCount = QM31FRIFoldTranscriptOracle.commitmentByteCount

    public let inputCount: Int
    public let roundCount: Int
    public let outputCount: Int
    public let totalInverseDomainCount: Int

    private let context: MetalContext
    private let pipeline: MTLComputePipelineState
    private let challengeBufferPipeline: MTLComputePipelineState
    private let uploadRingEvaluations: SharedUploadRing
    private let uploadRingInverseDomain: SharedUploadRing
    private let uploadRingRoundCommitments: SharedUploadRing
    private let arena: ResidencyArena
    private let transcript: TranscriptEngine
    private let evaluationVector: ArenaSlice
    private let inverseDomainVector: ArenaSlice
    private let scratchA: ArenaSlice
    private let scratchB: ArenaSlice
    private let outputVector: ArenaSlice
    private let transcriptFrameScratch: ArenaSlice
    private let challengeScratch: ArenaSlice
    private let challengeLog: ArenaSlice
    private let commitmentRootLog: ArenaSlice
    private let outputReadback: MTLBuffer
    private let challengeReadback: MTLBuffer
    private let commitmentRootReadback: MTLBuffer
    private let transcriptPrefixFrames: [QM31FRIFoldTranscriptFrameUpload]
    private let transcriptRoundFrames: [QM31FRIFoldTranscriptFrameUpload]
    private let transcriptChallengeFrames: [QM31FRIFoldTranscriptFrameUpload]
    private let roundInputCounts: [Int]
    private let roundInputElementOffsets: [Int]
    private let roundOutputCounts: [Int]
    private let roundInverseDomainElementOffsets: [Int]
    private let inputByteCount: Int
    private let outputByteCount: Int
    private let totalInverseDomainByteCount: Int
    private let roundCommitmentByteCount: Int
    private let roundCommitmentsByteCount: Int
    private let transcriptFrameScratchByteCount: Int
    private let challengeLogByteCount: Int
    private let commitmentRootLogByteCount: Int
    private let materializedLayerLogByteCount: Int
    private let scratchByteCount: Int
    private let executionLock = NSLock()
    private var merkleCommitPlans: [SHA3RawLeavesMerkleCommitPlan]?

    public convenience init(context: MetalContext, inputCount: Int, roundCount: Int) throws {
        try self.init(
            context: context,
            inputCount: inputCount,
            roundCount: roundCount,
            transcriptFrameData: nil
        )
    }

    init(
        context: MetalContext,
        inputCount: Int,
        roundCount: Int,
        transcriptFrameData customTranscriptFrameData: QM31FRIFoldTranscriptFrameData?
    ) throws {
        guard inputCount > 1,
              roundCount > 0,
              inputCount <= Int(UInt32.max) else {
            throw AppleZKProverError.invalidInputLayout
        }

        var currentCount = inputCount
        var roundInputCounts: [Int] = []
        var roundInputElementOffsets: [Int] = []
        var roundOutputCounts: [Int] = []
        var roundInverseDomainElementOffsets: [Int] = []
        var materializedLayerElementCount = 0
        var inverseDomainCount = 0
        for _ in 0..<roundCount {
            guard currentCount > 1, currentCount.isMultiple(of: 2) else {
                throw AppleZKProverError.invalidInputLayout
            }
            roundInputCounts.append(currentCount)
            roundInputElementOffsets.append(materializedLayerElementCount)
            materializedLayerElementCount = try Self.checkedAdd(materializedLayerElementCount, currentCount)
            let nextCount = currentCount / 2
            roundOutputCounts.append(nextCount)
            roundInverseDomainElementOffsets.append(inverseDomainCount)
            inverseDomainCount = try Self.checkedAdd(inverseDomainCount, nextCount)
            currentCount = nextCount
        }

        self.context = context
        self.inputCount = inputCount
        self.roundCount = roundCount
        self.outputCount = currentCount
        self.totalInverseDomainCount = inverseDomainCount
        self.roundInputCounts = roundInputCounts
        self.roundInputElementOffsets = roundInputElementOffsets
        self.roundOutputCounts = roundOutputCounts
        self.roundInverseDomainElementOffsets = roundInverseDomainElementOffsets
        self.inputByteCount = try checkedBufferLength(inputCount, Self.elementByteCount)
        self.outputByteCount = try checkedBufferLength(currentCount, Self.elementByteCount)
        self.totalInverseDomainByteCount = try checkedBufferLength(inverseDomainCount, Self.elementByteCount)
        self.scratchByteCount = try checkedBufferLength(roundOutputCounts.max() ?? currentCount, Self.elementByteCount)
        self.roundCommitmentByteCount = Self.commitmentByteCount
        self.roundCommitmentsByteCount = try checkedBufferLength(roundCount, Self.commitmentByteCount)
        self.challengeLogByteCount = try checkedBufferLength(roundCount, Self.elementByteCount)
        self.commitmentRootLogByteCount = try checkedBufferLength(roundCount, Self.commitmentByteCount)
        self.materializedLayerLogByteCount = try checkedBufferLength(
            materializedLayerElementCount,
            Self.elementByteCount
        )
        let transcriptFrameData = try customTranscriptFrameData ?? Self.makeTranscriptFrames(
            inputCount: inputCount,
            roundOutputCounts: roundOutputCounts
        )
        guard transcriptFrameData.rounds.count == roundCount,
              transcriptFrameData.challenges.count == roundCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.transcriptFrameScratchByteCount = max(
            Self.commitmentByteCount,
            transcriptFrameData.all.map(\.count).max() ?? 0
        )
        self.pipeline = try context.pipeline(
            for: KernelSpec(kernel: "qm31_fri_fold", family: .scalar, queueMode: .metal3)
        )
        self.challengeBufferPipeline = try context.pipeline(
            for: KernelSpec(kernel: "qm31_fri_fold_challenge_buffer", family: .scalar, queueMode: .metal3)
        )
        self.uploadRingEvaluations = try SharedUploadRing(
            device: context.device,
            slotCapacity: inputByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.QM31FRIFoldChainEvaluations"
        )
        self.uploadRingInverseDomain = try SharedUploadRing(
            device: context.device,
            slotCapacity: totalInverseDomainByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.QM31FRIFoldChainInverseDomain"
        )
        self.uploadRingRoundCommitments = try SharedUploadRing(
            device: context.device,
            slotCapacity: roundCommitmentsByteCount,
            slotCount: Self.defaultUploadRingSlotCount,
            label: "AppleZKProver.QM31FRIFoldChainCommitments"
        )
        self.arena = try ResidencyArena(
            device: context.device,
            capacity: try Self.checkedSum([
                inputByteCount,
                totalInverseDomainByteCount,
                scratchByteCount,
                scratchByteCount,
                outputByteCount,
                transcriptFrameScratchByteCount,
                Self.elementByteCount,
                challengeLogByteCount,
                commitmentRootLogByteCount,
                25 * MemoryLayout<UInt64>.stride,
                8 * 256,
            ]),
            label: "AppleZKProver.QM31FRIFoldChainArena"
        )
        self.evaluationVector = try arena.allocate(length: inputByteCount, role: .sumcheckVector)
        self.inverseDomainVector = try arena.allocate(length: totalInverseDomainByteCount, role: .sumcheckVector)
        self.scratchA = try arena.allocate(length: scratchByteCount, role: .sumcheckVector)
        self.scratchB = try arena.allocate(length: scratchByteCount, role: .sumcheckVector)
        self.outputVector = try arena.allocate(length: outputByteCount, role: .sumcheckVector)
        self.transcriptFrameScratch = try arena.allocate(length: transcriptFrameScratchByteCount, role: .scratch)
        self.challengeScratch = try arena.allocate(length: Self.elementByteCount, role: .challenges)
        self.challengeLog = try arena.allocate(length: challengeLogByteCount, role: .challenges)
        self.commitmentRootLog = try arena.allocate(length: commitmentRootLogByteCount, role: .frontierNodes)
        self.transcript = try TranscriptEngine(context: context, arena: arena)
        self.outputReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: outputByteCount,
            label: "AppleZKProver.QM31FRIFoldChainReadback"
        )
        self.challengeReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: challengeLogByteCount,
            label: "AppleZKProver.QM31FRIFoldChainChallengeReadback"
        )
        self.commitmentRootReadback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: commitmentRootLogByteCount,
            label: "AppleZKProver.QM31FRIFoldChainCommitmentRootReadback"
        )
        self.transcriptPrefixFrames = try transcriptFrameData.prefix.enumerated().map { index, data in
            try Self.makeFrameUpload(
                device: context.device,
                data: data,
                label: "AppleZKProver.QM31FRIFoldChainTranscriptPrefix.\(index)"
            )
        }
        self.transcriptRoundFrames = try transcriptFrameData.rounds.enumerated().map { index, data in
            try Self.makeFrameUpload(
                device: context.device,
                data: data,
                label: "AppleZKProver.QM31FRIFoldChainTranscriptRound.\(index)"
            )
        }
        self.transcriptChallengeFrames = try transcriptFrameData.challenges.enumerated().map { index, data in
            try Self.makeFrameUpload(
                device: context.device,
                data: data,
                label: "AppleZKProver.QM31FRIFoldChainTranscriptChallenge.\(index)"
            )
        }
    }

    public func execute(
        evaluations: [QM31Element],
        rounds: [QM31FRIFoldRound]
    ) throws -> QM31FRIFoldChainResult {
        try validateInputs(evaluations: evaluations, rounds: rounds)
        let evaluationBytes = Self.packLittleEndian(evaluations)
        let inverseDomainBytes = Self.packLittleEndian(rounds.flatMap(\.inverseDomainPoints))
        let challenges = rounds.map(\.challenge)

        executionLock.lock()
        defer { executionLock.unlock() }

        let evaluationSlot = try uploadRingEvaluations.copy(evaluationBytes, byteCount: inputByteCount)
        let inverseDomainSlot = try uploadRingInverseDomain.copy(inverseDomainBytes, byteCount: totalInverseDomainByteCount)
        return try executeLocked(
            evaluationsBuffer: evaluationSlot.buffer,
            evaluationsOffset: evaluationSlot.offset,
            inverseDomainBuffer: inverseDomainSlot.buffer,
            inverseDomainOffset: inverseDomainSlot.offset,
            outputBuffer: outputVector.buffer,
            outputOffset: outputVector.offset,
            challenges: challenges,
            readOutput: true
        )
    }

    public func executeVerified(
        evaluations: [QM31Element],
        rounds: [QM31FRIFoldRound]
    ) throws -> QM31FRIFoldChainResult {
        let expected = try QM31FRIFoldChainOracle.fold(evaluations: evaluations, rounds: rounds)
        let measured = try execute(evaluations: evaluations, rounds: rounds)
        guard measured.values == expected else {
            throw AppleZKProverError.correctnessValidationFailed("QM31 FRI fold chain GPU result did not match the CPU oracle.")
        }
        return measured
    }

    public func executeTranscriptDerived(
        evaluations: [QM31Element],
        inverseDomainLayers: [[QM31Element]],
        roundCommitments: [Data]
    ) throws -> QM31FRIFoldTranscriptChainResult {
        try validateTranscriptInputs(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers,
            roundCommitments: roundCommitments
        )
        let evaluationBytes = Self.packLittleEndian(evaluations)
        let inverseDomainBytes = Self.packLittleEndian(inverseDomainLayers.flatMap { $0 })
        let commitmentBytes = Self.packRoundCommitments(roundCommitments)

        executionLock.lock()
        defer { executionLock.unlock() }

        let evaluationSlot = try uploadRingEvaluations.copy(evaluationBytes, byteCount: inputByteCount)
        let inverseDomainSlot = try uploadRingInverseDomain.copy(inverseDomainBytes, byteCount: totalInverseDomainByteCount)
        let commitmentSlot = try uploadRingRoundCommitments.copy(commitmentBytes, byteCount: roundCommitmentsByteCount)
        return try executeTranscriptDerivedLocked(
            evaluationsBuffer: evaluationSlot.buffer,
            evaluationsOffset: evaluationSlot.offset,
            inverseDomainBuffer: inverseDomainSlot.buffer,
            inverseDomainOffset: inverseDomainSlot.offset,
            roundCommitmentsBuffer: commitmentSlot.buffer,
            roundCommitmentsOffset: commitmentSlot.offset,
            roundCommitmentStride: roundCommitmentByteCount,
            outputBuffer: outputVector.buffer,
            outputOffset: outputVector.offset,
            readOutput: true
        )
    }

    public func executeTranscriptDerivedVerified(
        evaluations: [QM31Element],
        inverseDomainLayers: [[QM31Element]],
        roundCommitments: [Data]
    ) throws -> QM31FRIFoldTranscriptChainResult {
        let expected = try QM31FRIFoldTranscriptOracle.fold(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers,
            roundCommitments: roundCommitments
        )
        let measured = try executeTranscriptDerived(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers,
            roundCommitments: roundCommitments
        )
        guard measured.values == expected.values, measured.challenges == expected.challenges else {
            throw AppleZKProverError.correctnessValidationFailed("QM31 transcript-derived FRI fold chain GPU result did not match the CPU oracle.")
        }
        return measured
    }

    public func executeMerkleTranscriptDerived(
        evaluations: [QM31Element],
        inverseDomainLayers: [[QM31Element]]
    ) throws -> QM31FRIMerkleFoldChainResult {
        try validateMerkleTranscriptInputs(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers
        )
        let evaluationBytes = Self.packLittleEndian(evaluations)
        let inverseDomainBytes = Self.packLittleEndian(inverseDomainLayers.flatMap { $0 })

        executionLock.lock()
        defer { executionLock.unlock() }

        _ = try ensureMerkleCommitPlans()
        let evaluationSlot = try uploadRingEvaluations.copy(evaluationBytes, byteCount: inputByteCount)
        let inverseDomainSlot = try uploadRingInverseDomain.copy(inverseDomainBytes, byteCount: totalInverseDomainByteCount)
        return try executeMerkleTranscriptDerivedLocked(
            evaluationsBuffer: evaluationSlot.buffer,
            evaluationsOffset: evaluationSlot.offset,
            inverseDomainBuffer: inverseDomainSlot.buffer,
            inverseDomainOffset: inverseDomainSlot.offset,
            outputBuffer: outputVector.buffer,
            outputOffset: outputVector.offset,
            commitmentOutputBuffer: nil,
            commitmentOutputOffset: 0,
            commitmentOutputStride: roundCommitmentByteCount,
            materializedLayerBuffer: nil,
            materializedLayerOffset: 0,
            readOutput: true
        )
    }

    public func executeMerkleTranscriptDerivedVerified(
        evaluations: [QM31Element],
        inverseDomainLayers: [[QM31Element]]
    ) throws -> QM31FRIMerkleFoldChainResult {
        let expected = try QM31FRIMerkleFoldChainOracle.commitAndFold(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers
        )
        let measured = try executeMerkleTranscriptDerived(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers
        )
        guard measured.values == expected.values,
              measured.commitments == expected.commitments,
              measured.challenges == expected.challenges else {
            throw AppleZKProverError.correctnessValidationFailed("QM31 Merkle-bound FRI fold chain GPU result did not match the CPU oracle.")
        }
        return measured
    }

    public func executeResident(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int = 0,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int = 0,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0,
        challenges: [QM31Element]
    ) throws -> GPUExecutionStats {
        guard challenges.count == roundCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(challenges)

        executionLock.lock()
        defer { executionLock.unlock() }

        let result = try executeLocked(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: inverseDomainOffset,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset,
            challenges: challenges,
            readOutput: false
        )
        return result.stats
    }

    public func executeTranscriptDerivedResident(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int = 0,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int = 0,
        roundCommitmentsBuffer: MTLBuffer,
        roundCommitmentsOffset: Int = 0,
        roundCommitmentStride: Int = QM31FRIFoldTranscriptOracle.commitmentByteCount,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0
    ) throws -> GPUExecutionStats {
        executionLock.lock()
        defer { executionLock.unlock() }

        let result = try executeTranscriptDerivedLocked(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: inverseDomainOffset,
            roundCommitmentsBuffer: roundCommitmentsBuffer,
            roundCommitmentsOffset: roundCommitmentsOffset,
            roundCommitmentStride: roundCommitmentStride,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset,
            readOutput: false
        )
        return result.stats
    }

    public func executeMerkleTranscriptDerivedResident(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int = 0,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int = 0,
        commitmentOutputBuffer: MTLBuffer,
        commitmentOutputOffset: Int = 0,
        commitmentOutputStride: Int = QM31FRIFoldTranscriptOracle.commitmentByteCount,
        materializedLayerBuffer: MTLBuffer? = nil,
        materializedLayerOffset: Int = 0,
        outputBuffer: MTLBuffer,
        outputOffset: Int = 0
    ) throws -> GPUExecutionStats {
        executionLock.lock()
        defer { executionLock.unlock() }

        _ = try ensureMerkleCommitPlans()
        let result = try executeMerkleTranscriptDerivedLocked(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: inverseDomainOffset,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset,
            commitmentOutputBuffer: commitmentOutputBuffer,
            commitmentOutputOffset: commitmentOutputOffset,
            commitmentOutputStride: commitmentOutputStride,
            materializedLayerBuffer: materializedLayerBuffer,
            materializedLayerOffset: materializedLayerOffset,
            readOutput: false
        )
        return result.stats
    }

    public func clearReusableBuffers() throws {
        executionLock.lock()
        defer { executionLock.unlock() }

        uploadRingEvaluations.clear()
        uploadRingInverseDomain.clear()
        uploadRingRoundCommitments.clear()
        MetalBufferFactory.zeroSharedBuffer(outputReadback)
        MetalBufferFactory.zeroSharedBuffer(challengeReadback)
        MetalBufferFactory.zeroSharedBuffer(commitmentRootReadback)
        if let merkleCommitPlans {
            for plan in merkleCommitPlans {
                try plan.clearReusableBuffers()
            }
        }
        try MetalBufferFactory.zeroPrivateBuffers(
            [arena.buffer],
            context: context,
            label: "QM31FRIFoldChain.PlanClear"
        )
    }

    private func executeLocked(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int,
        challenges: [QM31Element],
        readOutput: Bool
    ) throws -> QM31FRIFoldChainResult {
        try validateBufferRange(buffer: evaluationsBuffer, offset: evaluationsOffset, byteCount: inputByteCount)
        try validateBufferRange(buffer: inverseDomainBuffer, offset: inverseDomainOffset, byteCount: totalInverseDomainByteCount)
        try validateBufferRange(buffer: outputBuffer, offset: outputOffset, byteCount: outputByteCount)
        try validateNoOutputAliasing(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: inverseDomainOffset,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset
        )

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "QM31.FRI.FoldChain"

        var firstInputBuffer = evaluationsBuffer
        var firstInputOffset = evaluationsOffset
        var inverseBuffer = inverseDomainBuffer
        var inverseOffset = inverseDomainOffset
        if readOutput {
            guard let uploadBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            uploadBlit.label = "QM31.FRI.FoldChain.Upload"
            uploadBlit.copy(
                from: evaluationsBuffer,
                sourceOffset: evaluationsOffset,
                to: evaluationVector.buffer,
                destinationOffset: evaluationVector.offset,
                size: inputByteCount
            )
            uploadBlit.copy(
                from: inverseDomainBuffer,
                sourceOffset: inverseDomainOffset,
                to: inverseDomainVector.buffer,
                destinationOffset: inverseDomainVector.offset,
                size: totalInverseDomainByteCount
            )
            uploadBlit.fill(buffer: scratchA.buffer, range: scratchA.offset..<(scratchA.offset + scratchA.length), value: 0)
            uploadBlit.fill(buffer: scratchB.buffer, range: scratchB.offset..<(scratchB.offset + scratchB.length), value: 0)
            uploadBlit.fill(buffer: outputVector.buffer, range: outputVector.offset..<(outputVector.offset + outputVector.length), value: 0)
            uploadBlit.endEncoding()
            firstInputBuffer = evaluationVector.buffer
            firstInputOffset = evaluationVector.offset
            inverseBuffer = inverseDomainVector.buffer
            inverseOffset = inverseDomainVector.offset
        }

        var currentInputBuffer = firstInputBuffer
        var currentInputOffset = firstInputOffset
        for roundIndex in 0..<roundCount {
            let isLast = roundIndex == roundCount - 1
            let nextOutput: ArenaSlice?
            let destinationBuffer: MTLBuffer
            let destinationOffset: Int
            if isLast {
                destinationBuffer = readOutput ? outputVector.buffer : outputBuffer
                destinationOffset = readOutput ? outputVector.offset : outputOffset
                nextOutput = nil
            } else if roundIndex.isMultiple(of: 2) {
                destinationBuffer = scratchA.buffer
                destinationOffset = scratchA.offset
                nextOutput = scratchA
            } else {
                destinationBuffer = scratchB.buffer
                destinationOffset = scratchB.offset
                nextOutput = scratchB
            }

            try encodeFoldRound(
                on: commandBuffer,
                inputBuffer: currentInputBuffer,
                inputOffset: currentInputOffset,
                inverseDomainBuffer: inverseBuffer,
                inverseDomainOffset: inverseOffset + roundInverseDomainElementOffsets[roundIndex] * Self.elementByteCount,
                outputBuffer: destinationBuffer,
                outputOffset: destinationOffset,
                pairCount: roundOutputCounts[roundIndex],
                challenge: challenges[roundIndex],
                roundIndex: roundIndex
            )

            if let nextOutput {
                currentInputBuffer = nextOutput.buffer
                currentInputOffset = nextOutput.offset
            }
        }

        if readOutput {
            guard let readbackBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            readbackBlit.label = "QM31.FRI.FoldChain.Readback"
            readbackBlit.copy(
                from: outputVector.buffer,
                sourceOffset: outputVector.offset,
                to: outputReadback,
                destinationOffset: 0,
                size: outputByteCount
            )
            readbackBlit.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let stats = GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpuDuration(commandBuffer))
        let values = readOutput ? Self.readQM31Buffer(outputReadback, count: outputCount) : []
        return QM31FRIFoldChainResult(values: values, stats: stats)
    }

    private func executeTranscriptDerivedLocked(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        roundCommitmentsBuffer: MTLBuffer,
        roundCommitmentsOffset: Int,
        roundCommitmentStride: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int,
        readOutput: Bool
    ) throws -> QM31FRIFoldTranscriptChainResult {
        try validateBufferRange(buffer: evaluationsBuffer, offset: evaluationsOffset, byteCount: inputByteCount)
        try validateBufferRange(buffer: inverseDomainBuffer, offset: inverseDomainOffset, byteCount: totalInverseDomainByteCount)
        try validateBufferRange(buffer: outputBuffer, offset: outputOffset, byteCount: outputByteCount)
        let commitmentSpanByteCount = try validateRoundCommitmentBuffer(
            buffer: roundCommitmentsBuffer,
            offset: roundCommitmentsOffset,
            stride: roundCommitmentStride
        )
        try validateNoOutputAliasing(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: inverseDomainOffset,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset
        )
        guard !rangesOverlap(
            lhsBuffer: outputBuffer,
            lhsOffset: outputOffset,
            lhsByteCount: outputByteCount,
            rhsBuffer: roundCommitmentsBuffer,
            rhsOffset: roundCommitmentsOffset,
            rhsByteCount: commitmentSpanByteCount
        ) else {
            throw AppleZKProverError.invalidInputLayout
        }

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "QM31.FRI.FoldChain.Transcript"

        var firstInputBuffer = evaluationsBuffer
        var firstInputOffset = evaluationsOffset
        var inverseBuffer = inverseDomainBuffer
        var inverseOffset = inverseDomainOffset
        if readOutput {
            guard let uploadBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            uploadBlit.label = "QM31.FRI.FoldChain.Transcript.Upload"
            uploadBlit.copy(
                from: evaluationsBuffer,
                sourceOffset: evaluationsOffset,
                to: evaluationVector.buffer,
                destinationOffset: evaluationVector.offset,
                size: inputByteCount
            )
            uploadBlit.copy(
                from: inverseDomainBuffer,
                sourceOffset: inverseDomainOffset,
                to: inverseDomainVector.buffer,
                destinationOffset: inverseDomainVector.offset,
                size: totalInverseDomainByteCount
            )
            uploadBlit.fill(buffer: scratchA.buffer, range: scratchA.offset..<(scratchA.offset + scratchA.length), value: 0)
            uploadBlit.fill(buffer: scratchB.buffer, range: scratchB.offset..<(scratchB.offset + scratchB.length), value: 0)
            uploadBlit.fill(buffer: outputVector.buffer, range: outputVector.offset..<(outputVector.offset + outputVector.length), value: 0)
            uploadBlit.fill(buffer: challengeScratch.buffer, range: challengeScratch.offset..<(challengeScratch.offset + challengeScratch.length), value: 0)
            uploadBlit.fill(buffer: challengeLog.buffer, range: challengeLog.offset..<(challengeLog.offset + challengeLog.length), value: 0)
            uploadBlit.endEncoding()
            firstInputBuffer = evaluationVector.buffer
            firstInputOffset = evaluationVector.offset
            inverseBuffer = inverseDomainVector.buffer
            inverseOffset = inverseDomainVector.offset
        }

        try transcript.encodeReset(on: commandBuffer)
        try encodeTranscriptPrefixFrames(on: commandBuffer)

        var currentInputBuffer = firstInputBuffer
        var currentInputOffset = firstInputOffset
        for roundIndex in 0..<roundCount {
            let isLast = roundIndex == roundCount - 1
            let nextOutput: ArenaSlice?
            let destinationBuffer: MTLBuffer
            let destinationOffset: Int
            if isLast {
                destinationBuffer = readOutput ? outputVector.buffer : outputBuffer
                destinationOffset = readOutput ? outputVector.offset : outputOffset
                nextOutput = nil
            } else if roundIndex.isMultiple(of: 2) {
                destinationBuffer = scratchA.buffer
                destinationOffset = scratchA.offset
                nextOutput = scratchA
            } else {
                destinationBuffer = scratchB.buffer
                destinationOffset = scratchB.offset
                nextOutput = scratchB
            }

            try encodeTranscriptFrame(transcriptRoundFrames[roundIndex], on: commandBuffer)
            try encodeTranscriptCommitment(
                buffer: roundCommitmentsBuffer,
                offset: try roundCommitmentOffset(
                    baseOffset: roundCommitmentsOffset,
                    stride: roundCommitmentStride,
                    roundIndex: roundIndex
                ),
                on: commandBuffer
            )
            try encodeTranscriptFrame(transcriptChallengeFrames[roundIndex], on: commandBuffer)
            try transcript.encodeSqueezeChallenges(
                output: challengeScratch,
                challengeCount: 4,
                fieldModulus: QM31Field.modulus,
                on: commandBuffer
            )

            if readOutput {
                guard let challengeBlit = commandBuffer.makeBlitCommandEncoder() else {
                    throw AppleZKProverError.failedToCreateEncoder
                }
                challengeBlit.label = "QM31.FRI.FoldChain.ChallengeLog.\(roundIndex)"
                challengeBlit.copy(
                    from: challengeScratch.buffer,
                    sourceOffset: challengeScratch.offset,
                    to: challengeLog.buffer,
                    destinationOffset: challengeLog.offset + roundIndex * Self.elementByteCount,
                    size: Self.elementByteCount
                )
                challengeBlit.endEncoding()
            }

            try encodeFoldRoundWithChallengeBuffer(
                on: commandBuffer,
                inputBuffer: currentInputBuffer,
                inputOffset: currentInputOffset,
                inverseDomainBuffer: inverseBuffer,
                inverseDomainOffset: inverseOffset + roundInverseDomainElementOffsets[roundIndex] * Self.elementByteCount,
                outputBuffer: destinationBuffer,
                outputOffset: destinationOffset,
                challengeBuffer: challengeScratch.buffer,
                challengeOffset: challengeScratch.offset,
                pairCount: roundOutputCounts[roundIndex],
                roundIndex: roundIndex
            )

            if let nextOutput {
                currentInputBuffer = nextOutput.buffer
                currentInputOffset = nextOutput.offset
            }
        }

        if readOutput {
            guard let readbackBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            readbackBlit.label = "QM31.FRI.FoldChain.Transcript.Readback"
            readbackBlit.copy(
                from: outputVector.buffer,
                sourceOffset: outputVector.offset,
                to: outputReadback,
                destinationOffset: 0,
                size: outputByteCount
            )
            readbackBlit.copy(
                from: challengeLog.buffer,
                sourceOffset: challengeLog.offset,
                to: challengeReadback,
                destinationOffset: 0,
                size: challengeLogByteCount
            )
            readbackBlit.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let stats = GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpuDuration(commandBuffer))
        let values = readOutput ? Self.readQM31Buffer(outputReadback, count: outputCount) : []
        let challenges = readOutput ? Self.readQM31Buffer(challengeReadback, count: roundCount) : []
        return QM31FRIFoldTranscriptChainResult(values: values, challenges: challenges, stats: stats)
    }

    private func executeMerkleTranscriptDerivedLocked(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int,
        commitmentOutputBuffer: MTLBuffer?,
        commitmentOutputOffset: Int,
        commitmentOutputStride: Int,
        materializedLayerBuffer: MTLBuffer?,
        materializedLayerOffset: Int,
        readOutput: Bool
    ) throws -> QM31FRIMerkleFoldChainResult {
        let merklePlans = try ensureMerkleCommitPlans()
        try validateBufferRange(buffer: evaluationsBuffer, offset: evaluationsOffset, byteCount: inputByteCount)
        try validateBufferRange(buffer: inverseDomainBuffer, offset: inverseDomainOffset, byteCount: totalInverseDomainByteCount)
        try validateBufferRange(buffer: outputBuffer, offset: outputOffset, byteCount: outputByteCount)
        try validateNoOutputAliasing(
            evaluationsBuffer: evaluationsBuffer,
            evaluationsOffset: evaluationsOffset,
            inverseDomainBuffer: inverseDomainBuffer,
            inverseDomainOffset: inverseDomainOffset,
            outputBuffer: outputBuffer,
            outputOffset: outputOffset
        )

        let commitmentOutputSpan: Int
        if let commitmentOutputBuffer {
            commitmentOutputSpan = try validateCommitmentOutputBuffer(
                buffer: commitmentOutputBuffer,
                offset: commitmentOutputOffset,
                stride: commitmentOutputStride
            )
            try validateNoCommitmentOutputAliasing(
                commitmentOutputBuffer: commitmentOutputBuffer,
                commitmentOutputOffset: commitmentOutputOffset,
                commitmentOutputSpan: commitmentOutputSpan,
                evaluationsBuffer: evaluationsBuffer,
                evaluationsOffset: evaluationsOffset,
                inverseDomainBuffer: inverseDomainBuffer,
                inverseDomainOffset: inverseDomainOffset,
                outputBuffer: outputBuffer,
                outputOffset: outputOffset
            )
        } else {
            commitmentOutputSpan = 0
        }

        let materializedLayerSpan: Int
        if let materializedLayerBuffer {
            materializedLayerSpan = try validateMaterializedLayerBuffer(
                buffer: materializedLayerBuffer,
                offset: materializedLayerOffset
            )
            try validateNoMaterializedLayerAliasing(
                materializedLayerBuffer: materializedLayerBuffer,
                materializedLayerOffset: materializedLayerOffset,
                materializedLayerSpan: materializedLayerSpan,
                evaluationsBuffer: evaluationsBuffer,
                evaluationsOffset: evaluationsOffset,
                inverseDomainBuffer: inverseDomainBuffer,
                inverseDomainOffset: inverseDomainOffset,
                outputBuffer: outputBuffer,
                outputOffset: outputOffset,
                commitmentOutputBuffer: commitmentOutputBuffer,
                commitmentOutputOffset: commitmentOutputOffset,
                commitmentOutputSpan: commitmentOutputSpan
            )
        } else {
            materializedLayerSpan = 0
        }

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "QM31.FRI.FoldChain.MerkleTranscript"

        var firstInputBuffer = evaluationsBuffer
        var firstInputOffset = evaluationsOffset
        var inverseBuffer = inverseDomainBuffer
        var inverseOffset = inverseDomainOffset
        if readOutput {
            guard let uploadBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            uploadBlit.label = "QM31.FRI.FoldChain.MerkleTranscript.Upload"
            uploadBlit.copy(
                from: evaluationsBuffer,
                sourceOffset: evaluationsOffset,
                to: evaluationVector.buffer,
                destinationOffset: evaluationVector.offset,
                size: inputByteCount
            )
            uploadBlit.copy(
                from: inverseDomainBuffer,
                sourceOffset: inverseDomainOffset,
                to: inverseDomainVector.buffer,
                destinationOffset: inverseDomainVector.offset,
                size: totalInverseDomainByteCount
            )
            uploadBlit.fill(buffer: scratchA.buffer, range: scratchA.offset..<(scratchA.offset + scratchA.length), value: 0)
            uploadBlit.fill(buffer: scratchB.buffer, range: scratchB.offset..<(scratchB.offset + scratchB.length), value: 0)
            uploadBlit.fill(buffer: outputVector.buffer, range: outputVector.offset..<(outputVector.offset + outputVector.length), value: 0)
            uploadBlit.fill(buffer: challengeScratch.buffer, range: challengeScratch.offset..<(challengeScratch.offset + challengeScratch.length), value: 0)
            uploadBlit.fill(buffer: challengeLog.buffer, range: challengeLog.offset..<(challengeLog.offset + challengeLog.length), value: 0)
            uploadBlit.fill(buffer: commitmentRootLog.buffer, range: commitmentRootLog.offset..<(commitmentRootLog.offset + commitmentRootLog.length), value: 0)
            uploadBlit.endEncoding()
            firstInputBuffer = evaluationVector.buffer
            firstInputOffset = evaluationVector.offset
            inverseBuffer = inverseDomainVector.buffer
            inverseOffset = inverseDomainVector.offset
        } else {
            guard let clearBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            clearBlit.label = "QM31.FRI.FoldChain.MerkleTranscript.Clear"
            clearBlit.fill(buffer: challengeScratch.buffer, range: challengeScratch.offset..<(challengeScratch.offset + challengeScratch.length), value: 0)
            clearBlit.fill(buffer: challengeLog.buffer, range: challengeLog.offset..<(challengeLog.offset + challengeLog.length), value: 0)
            clearBlit.fill(buffer: commitmentRootLog.buffer, range: commitmentRootLog.offset..<(commitmentRootLog.offset + commitmentRootLog.length), value: 0)
            clearBlit.endEncoding()
        }

        try transcript.encodeReset(on: commandBuffer)
        try encodeTranscriptPrefixFrames(on: commandBuffer)

        var currentInputBuffer = firstInputBuffer
        var currentInputOffset = firstInputOffset
        for roundIndex in 0..<roundCount {
            if let materializedLayerBuffer {
                guard let materializeBlit = commandBuffer.makeBlitCommandEncoder() else {
                    throw AppleZKProverError.failedToCreateEncoder
                }
                materializeBlit.label = "QM31.FRI.FoldChain.MerkleTranscript.Materialize.\(roundIndex)"
                materializeBlit.copy(
                    from: currentInputBuffer,
                    sourceOffset: currentInputOffset,
                    to: materializedLayerBuffer,
                    destinationOffset: materializedLayerOffset
                        + roundInputElementOffsets[roundIndex] * Self.elementByteCount,
                    size: roundInputCounts[roundIndex] * Self.elementByteCount
                )
                materializeBlit.endEncoding()
                _ = materializedLayerSpan
            }

            let rootOffset = commitmentRootLog.offset + roundIndex * roundCommitmentByteCount
            try merklePlans[roundIndex].encodeCommitmentRoot(
                uploadBuffer: currentInputBuffer,
                uploadOffset: currentInputOffset,
                rootBuffer: commitmentRootLog.buffer,
                rootOffset: rootOffset,
                on: commandBuffer
            )

            try encodeTranscriptFrame(transcriptRoundFrames[roundIndex], on: commandBuffer)
            try encodeTranscriptCommitment(
                buffer: commitmentRootLog.buffer,
                offset: rootOffset,
                on: commandBuffer
            )
            try encodeTranscriptFrame(transcriptChallengeFrames[roundIndex], on: commandBuffer)
            try transcript.encodeSqueezeChallenges(
                output: challengeScratch,
                challengeCount: 4,
                fieldModulus: QM31Field.modulus,
                on: commandBuffer
            )

            let isLast = roundIndex == roundCount - 1
            let nextOutput: ArenaSlice?
            let destinationBuffer: MTLBuffer
            let destinationOffset: Int
            if isLast {
                destinationBuffer = readOutput ? outputVector.buffer : outputBuffer
                destinationOffset = readOutput ? outputVector.offset : outputOffset
                nextOutput = nil
            } else if roundIndex.isMultiple(of: 2) {
                destinationBuffer = scratchA.buffer
                destinationOffset = scratchA.offset
                nextOutput = scratchA
            } else {
                destinationBuffer = scratchB.buffer
                destinationOffset = scratchB.offset
                nextOutput = scratchB
            }

            guard let challengeBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            challengeBlit.label = "QM31.FRI.FoldChain.MerkleTranscript.ChallengeLog.\(roundIndex)"
            challengeBlit.copy(
                from: challengeScratch.buffer,
                sourceOffset: challengeScratch.offset,
                to: challengeLog.buffer,
                destinationOffset: challengeLog.offset + roundIndex * Self.elementByteCount,
                size: Self.elementByteCount
            )
            challengeBlit.endEncoding()

            try encodeFoldRoundWithChallengeBuffer(
                on: commandBuffer,
                inputBuffer: currentInputBuffer,
                inputOffset: currentInputOffset,
                inverseDomainBuffer: inverseBuffer,
                inverseDomainOffset: inverseOffset + roundInverseDomainElementOffsets[roundIndex] * Self.elementByteCount,
                outputBuffer: destinationBuffer,
                outputOffset: destinationOffset,
                challengeBuffer: challengeScratch.buffer,
                challengeOffset: challengeScratch.offset,
                pairCount: roundOutputCounts[roundIndex],
                roundIndex: roundIndex
            )

            if let nextOutput {
                currentInputBuffer = nextOutput.buffer
                currentInputOffset = nextOutput.offset
            }
        }

        guard let readbackBlit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        readbackBlit.label = "QM31.FRI.FoldChain.MerkleTranscript.Readback"
        if readOutput {
            readbackBlit.copy(
                from: outputVector.buffer,
                sourceOffset: outputVector.offset,
                to: outputReadback,
                destinationOffset: 0,
                size: outputByteCount
            )
            readbackBlit.copy(
                from: challengeLog.buffer,
                sourceOffset: challengeLog.offset,
                to: challengeReadback,
                destinationOffset: 0,
                size: challengeLogByteCount
            )
            readbackBlit.copy(
                from: commitmentRootLog.buffer,
                sourceOffset: commitmentRootLog.offset,
                to: commitmentRootReadback,
                destinationOffset: 0,
                size: commitmentRootLogByteCount
            )
        }
        if let commitmentOutputBuffer {
            if commitmentOutputStride == roundCommitmentByteCount {
                readbackBlit.copy(
                    from: commitmentRootLog.buffer,
                    sourceOffset: commitmentRootLog.offset,
                    to: commitmentOutputBuffer,
                    destinationOffset: commitmentOutputOffset,
                    size: commitmentRootLogByteCount
                )
            } else {
                for roundIndex in 0..<roundCount {
                    readbackBlit.copy(
                        from: commitmentRootLog.buffer,
                        sourceOffset: commitmentRootLog.offset + roundIndex * roundCommitmentByteCount,
                        to: commitmentOutputBuffer,
                        destinationOffset: try roundCommitmentOffset(
                            baseOffset: commitmentOutputOffset,
                            stride: commitmentOutputStride,
                            roundIndex: roundIndex
                        ),
                        size: roundCommitmentByteCount
                    )
                }
            }
            _ = commitmentOutputSpan
        }
        readbackBlit.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        let wall = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let stats = GPUExecutionStats(cpuWallSeconds: wall, gpuSeconds: gpuDuration(commandBuffer))
        let values = readOutput ? Self.readQM31Buffer(outputReadback, count: outputCount) : []
        let challenges = readOutput ? Self.readQM31Buffer(challengeReadback, count: roundCount) : []
        let commitments = readOutput ? Self.readCommitments(commitmentRootReadback, count: roundCount) : []
        return QM31FRIMerkleFoldChainResult(
            values: values,
            commitments: commitments,
            challenges: challenges,
            stats: stats
        )
    }

    private func encodeFoldRound(
        on commandBuffer: MTLCommandBuffer,
        inputBuffer: MTLBuffer,
        inputOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int,
        pairCount: Int,
        challenge: QM31Element,
        roundIndex: Int
    ) throws {
        var params = QM31FRIFoldParams(
            pairCount: try checkedUInt32(pairCount),
            fieldModulus: QM31Field.modulus,
            challengeA: challenge.constant.real,
            challengeB: challenge.constant.imaginary,
            challengeC: challenge.uCoefficient.real,
            challengeD: challenge.uCoefficient.imaginary
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "QM31.FRI.FoldChain.Round\(roundIndex)"
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: inputOffset, index: 0)
        encoder.setBuffer(inverseDomainBuffer, offset: inverseDomainOffset, index: 1)
        encoder.setBuffer(outputBuffer, offset: outputOffset, index: 2)
        encoder.setBytes(&params, length: MemoryLayout<QM31FRIFoldParams>.stride, index: 3)
        context.dispatch1D(encoder, pipeline: pipeline, elementCount: pairCount)
        encoder.endEncoding()
    }

    private func encodeFoldRoundWithChallengeBuffer(
        on commandBuffer: MTLCommandBuffer,
        inputBuffer: MTLBuffer,
        inputOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int,
        challengeBuffer: MTLBuffer,
        challengeOffset: Int,
        pairCount: Int,
        roundIndex: Int
    ) throws {
        var params = QM31FRIFoldParams(
            pairCount: try checkedUInt32(pairCount),
            fieldModulus: QM31Field.modulus,
            challengeA: 0,
            challengeB: 0,
            challengeC: 0,
            challengeD: 0
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        encoder.label = "QM31.FRI.FoldChain.Transcript.Round\(roundIndex)"
        encoder.setComputePipelineState(challengeBufferPipeline)
        encoder.setBuffer(inputBuffer, offset: inputOffset, index: 0)
        encoder.setBuffer(inverseDomainBuffer, offset: inverseDomainOffset, index: 1)
        encoder.setBuffer(outputBuffer, offset: outputOffset, index: 2)
        encoder.setBuffer(challengeBuffer, offset: challengeOffset, index: 3)
        encoder.setBytes(&params, length: MemoryLayout<QM31FRIFoldParams>.stride, index: 4)
        context.dispatch1D(encoder, pipeline: challengeBufferPipeline, elementCount: pairCount)
        encoder.endEncoding()
    }

    private func encodeTranscriptFrame(
        _ frame: QM31FRIFoldTranscriptFrameUpload,
        on commandBuffer: MTLCommandBuffer
    ) throws {
        try transcript.encodeCanonicalPack(
            input: frame.buffer,
            output: transcriptFrameScratch,
            byteCount: frame.byteCount,
            on: commandBuffer
        )
        try transcript.encodeAbsorb(
            packed: transcriptFrameScratch,
            byteCount: frame.byteCount,
            on: commandBuffer
        )
    }

    private func encodeTranscriptCommitment(
        buffer: MTLBuffer,
        offset: Int,
        on commandBuffer: MTLCommandBuffer
    ) throws {
        try transcript.encodeCanonicalPack(
            input: buffer,
            inputOffset: offset,
            output: transcriptFrameScratch,
            byteCount: roundCommitmentByteCount,
            on: commandBuffer
        )
        try transcript.encodeAbsorb(
            packed: transcriptFrameScratch,
            byteCount: roundCommitmentByteCount,
            on: commandBuffer
        )
    }

    private func encodeTranscriptPrefixFrames(on commandBuffer: MTLCommandBuffer) throws {
        for frame in transcriptPrefixFrames {
            try encodeTranscriptFrame(frame, on: commandBuffer)
        }
    }

    private func validateInputs(evaluations: [QM31Element], rounds: [QM31FRIFoldRound]) throws {
        guard evaluations.count == inputCount,
              rounds.count == roundCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        for (index, round) in rounds.enumerated() {
            guard round.inverseDomainPoints.count == roundOutputCounts[index] else {
                throw AppleZKProverError.invalidInputLayout
            }
            try QM31Field.validateCanonical(round.inverseDomainPoints)
            try QM31Field.validateCanonical([round.challenge])
            guard round.inverseDomainPoints.allSatisfy({ !QM31Field.isZero($0) }) else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
    }

    private func validateTranscriptInputs(
        evaluations: [QM31Element],
        inverseDomainLayers: [[QM31Element]],
        roundCommitments: [Data]
    ) throws {
        guard evaluations.count == inputCount,
              inverseDomainLayers.count == roundCount,
              roundCommitments.count == roundCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        for (index, layer) in inverseDomainLayers.enumerated() {
            guard layer.count == roundOutputCounts[index] else {
                throw AppleZKProverError.invalidInputLayout
            }
            try QM31Field.validateCanonical(layer)
            guard layer.allSatisfy({ !QM31Field.isZero($0) }) else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        try validateRoundCommitments(roundCommitments)
    }

    private func validateMerkleTranscriptInputs(
        evaluations: [QM31Element],
        inverseDomainLayers: [[QM31Element]]
    ) throws {
        guard inputCount.nonzeroBitCount == 1,
              evaluations.count == inputCount,
              inverseDomainLayers.count == roundCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        for (index, layer) in inverseDomainLayers.enumerated() {
            guard layer.count == roundOutputCounts[index] else {
                throw AppleZKProverError.invalidInputLayout
            }
            try QM31Field.validateCanonical(layer)
            guard layer.allSatisfy({ !QM31Field.isZero($0) }) else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
    }

    private func validateRoundCommitments(_ roundCommitments: [Data]) throws {
        guard roundCommitments.count == roundCount,
              roundCommitments.allSatisfy({ $0.count == roundCommitmentByteCount }) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private func validateBufferRange(buffer: MTLBuffer, offset: Int, byteCount: Int) throws {
        let end = offset.addingReportingOverflow(max(1, byteCount))
        guard offset >= 0,
              byteCount >= 0,
              !end.overflow,
              buffer.length >= end.partialValue else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private func validateRoundCommitmentBuffer(
        buffer: MTLBuffer,
        offset: Int,
        stride: Int
    ) throws -> Int {
        guard offset >= 0,
              stride >= roundCommitmentByteCount,
              roundCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let lastOffset = try roundCommitmentOffset(
            baseOffset: offset,
            stride: stride,
            roundIndex: roundCount - 1
        )
        let end = lastOffset.addingReportingOverflow(roundCommitmentByteCount)
        guard !end.overflow,
              buffer.length >= end.partialValue else {
            throw AppleZKProverError.invalidInputLayout
        }
        return end.partialValue - offset
    }

    private func validateCommitmentOutputBuffer(
        buffer: MTLBuffer,
        offset: Int,
        stride: Int
    ) throws -> Int {
        try validateRoundCommitmentBuffer(buffer: buffer, offset: offset, stride: stride)
    }

    private func validateMaterializedLayerBuffer(
        buffer: MTLBuffer,
        offset: Int
    ) throws -> Int {
        try validateBufferRange(
            buffer: buffer,
            offset: offset,
            byteCount: materializedLayerLogByteCount
        )
        return materializedLayerLogByteCount
    }

    private func roundCommitmentOffset(
        baseOffset: Int,
        stride: Int,
        roundIndex: Int
    ) throws -> Int {
        let scaled = roundIndex.multipliedReportingOverflow(by: stride)
        let offset = baseOffset.addingReportingOverflow(scaled.partialValue)
        guard baseOffset >= 0,
              stride >= 0,
              roundIndex >= 0,
              !scaled.overflow,
              !offset.overflow else {
            throw AppleZKProverError.invalidInputLayout
        }
        return offset.partialValue
    }

    private func validateNoOutputAliasing(
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int
    ) throws {
        guard !rangesOverlap(
            lhsBuffer: outputBuffer,
            lhsOffset: outputOffset,
            lhsByteCount: outputByteCount,
            rhsBuffer: evaluationsBuffer,
            rhsOffset: evaluationsOffset,
            rhsByteCount: inputByteCount
        ),
        !rangesOverlap(
            lhsBuffer: outputBuffer,
            lhsOffset: outputOffset,
            lhsByteCount: outputByteCount,
            rhsBuffer: inverseDomainBuffer,
            rhsOffset: inverseDomainOffset,
            rhsByteCount: totalInverseDomainByteCount
        ) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private func validateNoCommitmentOutputAliasing(
        commitmentOutputBuffer: MTLBuffer,
        commitmentOutputOffset: Int,
        commitmentOutputSpan: Int,
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int
    ) throws {
        guard !rangesOverlap(
            lhsBuffer: commitmentOutputBuffer,
            lhsOffset: commitmentOutputOffset,
            lhsByteCount: commitmentOutputSpan,
            rhsBuffer: evaluationsBuffer,
            rhsOffset: evaluationsOffset,
            rhsByteCount: inputByteCount
        ),
        !rangesOverlap(
            lhsBuffer: commitmentOutputBuffer,
            lhsOffset: commitmentOutputOffset,
            lhsByteCount: commitmentOutputSpan,
            rhsBuffer: inverseDomainBuffer,
            rhsOffset: inverseDomainOffset,
            rhsByteCount: totalInverseDomainByteCount
        ),
        !rangesOverlap(
            lhsBuffer: commitmentOutputBuffer,
            lhsOffset: commitmentOutputOffset,
            lhsByteCount: commitmentOutputSpan,
            rhsBuffer: outputBuffer,
            rhsOffset: outputOffset,
            rhsByteCount: outputByteCount
        ) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    private func validateNoMaterializedLayerAliasing(
        materializedLayerBuffer: MTLBuffer,
        materializedLayerOffset: Int,
        materializedLayerSpan: Int,
        evaluationsBuffer: MTLBuffer,
        evaluationsOffset: Int,
        inverseDomainBuffer: MTLBuffer,
        inverseDomainOffset: Int,
        outputBuffer: MTLBuffer,
        outputOffset: Int,
        commitmentOutputBuffer: MTLBuffer?,
        commitmentOutputOffset: Int,
        commitmentOutputSpan: Int
    ) throws {
        guard !rangesOverlap(
            lhsBuffer: materializedLayerBuffer,
            lhsOffset: materializedLayerOffset,
            lhsByteCount: materializedLayerSpan,
            rhsBuffer: evaluationsBuffer,
            rhsOffset: evaluationsOffset,
            rhsByteCount: inputByteCount
        ),
        !rangesOverlap(
            lhsBuffer: materializedLayerBuffer,
            lhsOffset: materializedLayerOffset,
            lhsByteCount: materializedLayerSpan,
            rhsBuffer: inverseDomainBuffer,
            rhsOffset: inverseDomainOffset,
            rhsByteCount: totalInverseDomainByteCount
        ),
        !rangesOverlap(
            lhsBuffer: materializedLayerBuffer,
            lhsOffset: materializedLayerOffset,
            lhsByteCount: materializedLayerSpan,
            rhsBuffer: outputBuffer,
            rhsOffset: outputOffset,
            rhsByteCount: outputByteCount
        ) else {
            throw AppleZKProverError.invalidInputLayout
        }

        if let commitmentOutputBuffer {
            guard !rangesOverlap(
                lhsBuffer: materializedLayerBuffer,
                lhsOffset: materializedLayerOffset,
                lhsByteCount: materializedLayerSpan,
                rhsBuffer: commitmentOutputBuffer,
                rhsOffset: commitmentOutputOffset,
                rhsByteCount: commitmentOutputSpan
            ) else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
    }

    private func rangesOverlap(
        lhsBuffer: MTLBuffer,
        lhsOffset: Int,
        lhsByteCount: Int,
        rhsBuffer: MTLBuffer,
        rhsOffset: Int,
        rhsByteCount: Int
    ) -> Bool {
        guard lhsBuffer === rhsBuffer else {
            return false
        }
        let lhsEnd = lhsOffset + lhsByteCount
        let rhsEnd = rhsOffset + rhsByteCount
        return lhsOffset < rhsEnd && rhsOffset < lhsEnd
    }

    private static func packLittleEndian(_ values: [QM31Element]) -> Data {
        var data = Data()
        data.reserveCapacity(values.count * elementByteCount)
        for value in values {
            appendUInt32LittleEndian(value.constant.real, to: &data)
            appendUInt32LittleEndian(value.constant.imaginary, to: &data)
            appendUInt32LittleEndian(value.uCoefficient.real, to: &data)
            appendUInt32LittleEndian(value.uCoefficient.imaginary, to: &data)
        }
        return data
    }

    private static func appendUInt32LittleEndian(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }

    private static func readQM31Buffer(_ buffer: MTLBuffer, count: Int) -> [QM31Element] {
        let wordCount = count * 4
        let raw = buffer.contents().bindMemory(to: UInt32.self, capacity: wordCount)
        return (0..<count).map { index in
            QM31Element(
                a: raw[index * 4],
                b: raw[index * 4 + 1],
                c: raw[index * 4 + 2],
                d: raw[index * 4 + 3]
            )
        }
    }

    private static func readCommitments(_ buffer: MTLBuffer, count: Int) -> [Data] {
        let bytes = buffer.contents().bindMemory(to: UInt8.self, capacity: count * Self.commitmentByteCount)
        return (0..<count).map { index in
            Data(bytes: bytes.advanced(by: index * Self.commitmentByteCount), count: Self.commitmentByteCount)
        }
    }

    private static func packRoundCommitments(_ roundCommitments: [Data]) -> Data {
        var data = Data()
        data.reserveCapacity(roundCommitments.count * commitmentByteCount)
        for commitment in roundCommitments {
            data.append(commitment)
        }
        return data
    }

    private static func makeTranscriptFrames(
        inputCount: Int,
        roundOutputCounts: [Int]
    ) throws -> QM31FRIFoldTranscriptFrameData {
        let header = try QM31FRIFoldTranscriptFraming.header(
            inputCount: inputCount,
            roundCount: roundOutputCounts.count,
            commitmentByteCount: commitmentByteCount
        )
        var roundFrames: [Data] = []
        var challengeFrames: [Data] = []
        roundFrames.reserveCapacity(roundOutputCounts.count)
        challengeFrames.reserveCapacity(roundOutputCounts.count)

        var activeInputCount = inputCount
        for roundIndex in 0..<roundOutputCounts.count {
            let outputCount = roundOutputCounts[roundIndex]
            roundFrames.append(try QM31FRIFoldTranscriptFraming.roundCommitment(
                roundIndex: roundIndex,
                inputCount: activeInputCount,
                outputCount: outputCount,
                commitmentByteCount: commitmentByteCount
            ))
            challengeFrames.append(try QM31FRIFoldTranscriptFraming.challenge(roundIndex: roundIndex))
            activeInputCount = outputCount
        }

        return try QM31FRIFoldTranscriptFrameData(
            prefix: [header],
            rounds: roundFrames,
            challenges: challengeFrames
        )
    }

    private static func makeFrameUpload(
        device: MTLDevice,
        data: Data,
        label: String
    ) throws -> QM31FRIFoldTranscriptFrameUpload {
        let buffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            bytes: data,
            declaredLength: data.count,
            label: label
        )
        return QM31FRIFoldTranscriptFrameUpload(buffer: buffer, byteCount: data.count)
    }

    private func ensureMerkleCommitPlans() throws -> [SHA3RawLeavesMerkleCommitPlan] {
        if let merkleCommitPlans {
            return merkleCommitPlans
        }
        guard inputCount.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidLeafCount(inputCount)
        }

        var plans: [SHA3RawLeavesMerkleCommitPlan] = []
        plans.reserveCapacity(roundCount)
        var currentCount = inputCount
        for _ in 0..<roundCount {
            guard currentCount > 1, currentCount.nonzeroBitCount == 1 else {
                throw AppleZKProverError.invalidInputLayout
            }
            plans.append(try SHA3RawLeavesMerkleCommitPlan(
                context: context,
                leafCount: currentCount,
                leafStride: QM31FRILeafEncoding.elementByteCount,
                leafLength: QM31FRILeafEncoding.elementByteCount,
                configuration: .default
            ))
            currentCount /= 2
        }
        merkleCommitPlans = plans
        return plans
    }

    private static func checkedAdd(_ lhs: Int, _ rhs: Int) throws -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        guard lhs >= 0, rhs >= 0, !result.overflow else {
            throw AppleZKProverError.invalidInputLayout
        }
        return result.partialValue
    }

    private static func checkedSum(_ values: [Int]) throws -> Int {
        var total = 0
        for value in values {
            total = try checkedAdd(total, value)
        }
        return total
    }

    private func gpuDuration(_ commandBuffer: MTLCommandBuffer) -> Double? {
        guard commandBuffer.gpuEndTime > commandBuffer.gpuStartTime else {
            return nil
        }
        return commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    }
}
#endif
