import Foundation

public enum M31Field {
    public static let modulus: UInt32 = 2_147_483_647

    public static func validateCanonical(_ values: [UInt32]) throws {
        guard values.allSatisfy({ $0 < modulus }) else {
            throw AppleZKProverError.invalidInputLayout
        }
    }
}

public struct SumcheckChunkOracleResult: Sendable {
    public let finalVector: [UInt32]
    public let coefficients: [UInt32]
    public let challenges: [UInt32]

    public init(finalVector: [UInt32], coefficients: [UInt32], challenges: [UInt32]) {
        self.finalVector = finalVector
        self.coefficients = coefficients
        self.challenges = challenges
    }
}

public enum SumcheckOracle {
    public static func m31Chunk(
        evaluations: [UInt32],
        rounds: Int
    ) throws -> SumcheckChunkOracleResult {
        guard evaluations.count > 1,
              evaluations.count.nonzeroBitCount == 1,
              rounds > 0,
              rounds <= log2(evaluations.count) else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(evaluations)

        var transcript = SHA3Oracle.TranscriptState()
        var current = evaluations
        var allCoefficients: [UInt32] = []
        var challenges: [UInt32] = []

        for _ in 0..<rounds {
            let pairCount = current.count / 2
            var roundCoefficients: [UInt32] = []
            roundCoefficients.reserveCapacity(pairCount * 2)

            for index in 0..<pairCount {
                roundCoefficients.append(current[index * 2])
                roundCoefficients.append(current[index * 2 + 1])
            }

            try transcript.absorb(packLittleEndian(roundCoefficients))
            let challenge = try transcript.squeezeUInt32(count: 1, modulus: M31Field.modulus)[0]
            challenges.append(challenge)
            allCoefficients.append(contentsOf: roundCoefficients)

            var next = Array(repeating: UInt32(0), count: pairCount)
            for index in 0..<pairCount {
                next[index] = fold(
                    current[index * 2],
                    current[index * 2 + 1],
                    challenge: challenge
                )
            }
            current = next
        }

        return SumcheckChunkOracleResult(
            finalVector: current,
            coefficients: allCoefficients,
            challenges: challenges
        )
    }

    private static func fold(_ a: UInt32, _ b: UInt32, challenge: UInt32) -> UInt32 {
        let value = UInt64(a) + UInt64(b) * UInt64(challenge)
        return UInt32(value % UInt64(M31Field.modulus))
    }

    private static func packLittleEndian(_ words: [UInt32]) -> Data {
        var data = Data()
        data.reserveCapacity(words.count * MemoryLayout<UInt32>.stride)
        for word in words {
            data.append(UInt8(word & 0xff))
            data.append(UInt8((word >> 8) & 0xff))
            data.append(UInt8((word >> 16) & 0xff))
            data.append(UInt8((word >> 24) & 0xff))
        }
        return data
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
