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
}
