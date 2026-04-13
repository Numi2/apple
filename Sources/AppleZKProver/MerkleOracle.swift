import Foundation

public enum MerkleOracle {
    public static func rootSHA3_256(leaves: [Data], hashLeaves: Bool = true) throws -> Data {
        guard !leaves.isEmpty, leaves.count.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidLeafCount(leaves.count)
        }

        var level = hashLeaves ? leaves.map { SHA3Oracle.sha3_256($0) } : leaves
        for digest in level {
            guard digest.count == 32 else {
                throw AppleZKProverError.invalidPrehashedLeafLength(digest.count)
            }
        }

        while level.count > 1 {
            var next: [Data] = []
            next.reserveCapacity(level.count / 2)
            for i in stride(from: 0, to: level.count, by: 2) {
                var combined = Data(capacity: 64)
                combined.append(level[i])
                combined.append(level[i + 1])
                next.append(SHA3Oracle.sha3_256(combined))
            }
            level = next
        }

        return level[0]
    }

    public static func rootSHA3_256(rawLeaves: Data, leafCount: Int, leafStride: Int, leafLength: Int) throws -> Data {
        guard leafCount > 0, leafCount.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidLeafCount(leafCount)
        }
        guard leafLength >= 0, leafStride >= 0, leafStride >= leafLength else {
            throw AppleZKProverError.invalidInputLayout
        }

        let declaredLeafBytes = try checkedBufferLength(leafCount, leafStride)
        guard rawLeaves.count >= declaredLeafBytes else {
            throw AppleZKProverError.invalidInputLayout
        }

        var leaves: [Data] = []
        leaves.reserveCapacity(leafCount)
        for i in 0..<leafCount {
            let base = i * leafStride
            leaves.append(rawLeaves.subdata(in: base..<(base + leafLength)))
        }
        return try rootSHA3_256(leaves: leaves, hashLeaves: true)
    }

    public static func openingSHA3_256(
        rawLeaves: Data,
        leafCount: Int,
        leafStride: Int,
        leafLength: Int,
        leafIndex: Int
    ) throws -> MerkleOpeningProof {
        guard leafCount > 0, leafCount.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidLeafCount(leafCount)
        }
        guard leafLength >= 0,
              leafStride >= 0,
              leafStride >= leafLength,
              leafIndex >= 0,
              leafIndex < leafCount else {
            throw AppleZKProverError.invalidInputLayout
        }

        let declaredLeafBytes = try checkedBufferLength(leafCount, leafStride)
        guard rawLeaves.count >= declaredLeafBytes else {
            throw AppleZKProverError.invalidInputLayout
        }

        let leafStart = leafIndex * leafStride
        let leaf = rawLeaves.subdata(in: leafStart..<(leafStart + leafLength))
        var level: [Data] = []
        level.reserveCapacity(leafCount)
        for i in 0..<leafCount {
            let base = i * leafStride
            level.append(SHA3Oracle.sha3_256(rawLeaves.subdata(in: base..<(base + leafLength))))
        }

        var index = leafIndex
        var siblings: [Data] = []
        siblings.reserveCapacity(log2(leafCount))

        while level.count > 1 {
            siblings.append(level[index ^ 1])

            var next: [Data] = []
            next.reserveCapacity(level.count / 2)
            for i in stride(from: 0, to: level.count, by: 2) {
                var combined = Data(capacity: 64)
                combined.append(level[i])
                combined.append(level[i + 1])
                next.append(SHA3Oracle.sha3_256(combined))
            }
            level = next
            index >>= 1
        }

        return MerkleOpeningProof(
            leafIndex: leafIndex,
            leaf: leaf,
            siblingHashes: siblings,
            root: level[0]
        )
    }

    public static func verifySHA3_256(opening: MerkleOpeningProof) throws -> Bool {
        guard opening.leafIndex >= 0,
              opening.root.count == 32,
              opening.siblingHashes.allSatisfy({ $0.count == 32 }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        guard opening.siblingHashes.count < Int.bitWidth - 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let impliedLeafCount = 1 << opening.siblingHashes.count
        guard opening.leafIndex < impliedLeafCount else {
            throw AppleZKProverError.invalidInputLayout
        }

        var digest = SHA3Oracle.sha3_256(opening.leaf)
        for level in 0..<opening.siblingHashes.count {
            let sibling = opening.siblingHashes[level]
            var combined = Data(capacity: 64)
            if ((opening.leafIndex >> level) & 1) == 0 {
                combined.append(digest)
                combined.append(sibling)
            } else {
                combined.append(sibling)
                combined.append(digest)
            }
            digest = SHA3Oracle.sha3_256(combined)
        }

        return digest == opening.root
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
