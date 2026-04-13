import Foundation

public enum SHA3Oracle {
    public static let sha3_256Rate = 136

    public struct TranscriptState: Sendable {
        private var state: [UInt64]

        public init() {
            self.state = Array(repeating: 0, count: 25)
        }

        public mutating func reset() {
            state = Array(repeating: 0, count: 25)
        }

        public mutating func absorb(_ data: Data, domainSuffix: UInt8 = 0x06) throws {
            let bytes = [UInt8](data)
            let rate = SHA3Oracle.sha3_256Rate
            var offset = 0

            while offset + rate <= bytes.count {
                SHA3Oracle.absorbBlock(bytes, offset: offset, into: &state)
                SHA3Oracle.keccakF1600(&state)
                offset += rate
            }

            var tail = Array(repeating: UInt8(0), count: rate)
            let tailCount = bytes.count - offset
            if tailCount > 0 {
                tail[0..<tailCount] = bytes[offset..<bytes.count]
            }
            tail[tailCount] ^= domainSuffix
            tail[rate - 1] ^= 0x80
            SHA3Oracle.absorbBlock(tail, offset: 0, into: &state)
            SHA3Oracle.keccakF1600(&state)
        }

        public func squeezeUInt32(count: Int, modulus: UInt32) throws -> [UInt32] {
            guard count >= 0, modulus > 0 else {
                throw AppleZKProverError.invalidInputLayout
            }

            let wordsPerSqueezeBlock = SHA3Oracle.sha3_256Rate / MemoryLayout<UInt32>.stride
            let sampleSpace = UInt64(UInt32.max) + 1
            let rejectionLimit = sampleSpace - (sampleSpace % UInt64(modulus))
            var squeezeState = state
            var challenges: [UInt32] = []
            challenges.reserveCapacity(count)
            var candidateIndex = 0

            while challenges.count < count {
                if candidateIndex > 0, candidateIndex.isMultiple(of: wordsPerSqueezeBlock) {
                    SHA3Oracle.keccakF1600(&squeezeState)
                }

                let wordIndex = candidateIndex % wordsPerSqueezeBlock
                let word = squeezeState[wordIndex >> 1]
                let shift = UInt64((wordIndex & 1) * 32)
                let candidate = UInt64(UInt32(truncatingIfNeeded: word >> shift))
                candidateIndex += 1

                if candidate < rejectionLimit {
                    challenges.append(UInt32(candidate % UInt64(modulus)))
                }
            }
            return challenges
        }
    }

    private static let roundConstants: [UInt64] = [
        0x0000_0000_0000_0001,
        0x0000_0000_0000_8082,
        0x8000_0000_0000_808A,
        0x8000_0000_8000_8000,
        0x0000_0000_0000_808B,
        0x0000_0000_8000_0001,
        0x8000_0000_8000_8081,
        0x8000_0000_0000_8009,
        0x0000_0000_0000_008A,
        0x0000_0000_0000_0088,
        0x0000_0000_8000_8009,
        0x0000_0000_8000_000A,
        0x0000_0000_8000_808B,
        0x8000_0000_0000_008B,
        0x8000_0000_0000_8089,
        0x8000_0000_0000_8003,
        0x8000_0000_0000_8002,
        0x8000_0000_0000_0080,
        0x0000_0000_0000_800A,
        0x8000_0000_8000_000A,
        0x8000_0000_8000_8081,
        0x8000_0000_0000_8080,
        0x0000_0000_8000_0001,
        0x8000_0000_8000_8008,
    ]

    private static let rhoOffsets: [Int] = [
        1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14,
        27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44,
    ]

    private static let piLanes: [Int] = [
        10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4,
        15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1,
    ]

    public static func sha3_256(_ data: Data) -> Data {
        sponge256(data, domainSuffix: 0x06)
    }

    public static func sha3_256(oneBlock data: Data) throws -> Data {
        guard data.count <= sha3_256Rate else {
            throw AppleZKProverError.unsupportedOneBlockLength(data.count)
        }
        return sha3_256(data)
    }

    public static func keccakF1600Permutation(_ lanes: [UInt64]) throws -> [UInt64] {
        guard lanes.count == 25 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var state = lanes
        keccakF1600(&state)
        return state
    }

    static func sponge256(_ data: Data, domainSuffix: UInt8) -> Data {
        var state = Array(repeating: UInt64(0), count: 25)
        let bytes = [UInt8](data)
        let rate = sha3_256Rate
        var offset = 0

        while offset + rate <= bytes.count {
            absorbBlock(bytes, offset: offset, into: &state)
            keccakF1600(&state)
            offset += rate
        }

        var tail = Array(repeating: UInt8(0), count: rate)
        let tailCount = bytes.count - offset
        if tailCount > 0 {
            tail[0..<tailCount] = bytes[offset..<bytes.count]
        }
        tail[tailCount] ^= domainSuffix
        tail[rate - 1] ^= 0x80
        absorbBlock(tail, offset: 0, into: &state)
        keccakF1600(&state)

        var digest = Data(count: 32)
        digest.withUnsafeMutableBytes { rawBuffer in
            guard let out = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }
            for lane in 0..<4 {
                storeLittleEndian(state[lane], to: out.advanced(by: lane * 8))
            }
        }
        return digest
    }

    private static func absorbBlock(_ bytes: [UInt8], offset: Int, into state: inout [UInt64]) {
        precondition(offset >= 0)
        precondition(offset + sha3_256Rate <= bytes.count)
        for lane in 0..<(sha3_256Rate / 8) {
            var value: UInt64 = 0
            for shift in 0..<8 {
                value |= UInt64(bytes[offset + lane * 8 + shift]) << UInt64(shift * 8)
            }
            state[lane] ^= value
        }
    }

    private static func rotateLeft(_ value: UInt64, by amount: Int) -> UInt64 {
        let n = UInt64(amount & 63)
        return (value << n) | (value >> UInt64((64 - Int(n)) & 63))
    }

    private static func keccakF1600(_ state: inout [UInt64]) {
        precondition(state.count == 25)
        var c = Array(repeating: UInt64(0), count: 5)
        var b = Array(repeating: UInt64(0), count: 25)

        for round in 0..<24 {
            for x in 0..<5 {
                c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
            }
            for x in 0..<5 {
                let d = c[(x + 4) % 5] ^ rotateLeft(c[(x + 1) % 5], by: 1)
                state[x] ^= d
                state[x + 5] ^= d
                state[x + 10] ^= d
                state[x + 15] ^= d
                state[x + 20] ^= d
            }

            let first = state[1]
            var current = first
            for i in 0..<24 {
                let destination = piLanes[i]
                let next = state[destination]
                state[destination] = rotateLeft(current, by: rhoOffsets[i])
                current = next
            }

            for row in stride(from: 0, to: 25, by: 5) {
                for x in 0..<5 {
                    b[row + x] = state[row + x]
                }
                for x in 0..<5 {
                    state[row + x] = b[row + x] ^ ((~b[row + ((x + 1) % 5)]) & b[row + ((x + 2) % 5)])
                }
            }

            state[0] ^= roundConstants[round]
        }
    }

    private static func storeLittleEndian(_ value: UInt64, to output: UnsafeMutablePointer<UInt8>) {
        for i in 0..<8 {
            output[i] = UInt8((value >> UInt64(i * 8)) & 0xff)
        }
    }
}

public enum KeccakOracle {
    public static func keccak_256(_ data: Data) -> Data {
        SHA3Oracle.sponge256(data, domainSuffix: 0x01)
    }

    public static func keccak_256(oneBlock data: Data) throws -> Data {
        guard data.count <= SHA3Oracle.sha3_256Rate else {
            throw AppleZKProverError.unsupportedOneBlockLength(data.count)
        }
        return keccak_256(data)
    }
}
