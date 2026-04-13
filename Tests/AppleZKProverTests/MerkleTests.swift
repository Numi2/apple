import XCTest
#if canImport(Metal)
import Metal
#endif
@testable import AppleZKProver

final class MerkleTests: XCTestCase {
    func testCPUDeterministicMerkleRoot() throws {
        let leaves = Self.makeLeaves(count: 8, leafLength: 32)
        let root = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: 8,
            leafStride: 32,
            leafLength: 32
        )
        XCTAssertEqual(root.hexString, "fef32b29cdcb4ba63b81675bcb9e81d03c75f57ef44e0e14b695c8fe20bfce38")
    }

    func testCPUEmptyLeavesMerkleRoot() throws {
        let leaves = Self.makeLeaves(count: 8, leafLength: 0)
        let root = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: 8,
            leafStride: 0,
            leafLength: 0
        )
        let repeatedEmptyLeaves = Array(repeating: Data(), count: 8)
        XCTAssertEqual(root, try MerkleOracle.rootSHA3_256(leaves: repeatedEmptyLeaves))
    }

    func testCPULargeRawMerkleRootMatchesDataLeaves() throws {
        let leafCount = 1024
        let leafLength = 32
        let leaves = Self.makeLeaves(count: leafCount, leafLength: leafLength, salt: 71)
        let rawRoot = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: leafCount,
            leafStride: leafLength,
            leafLength: leafLength
        )
        let dataLeaves = (0..<leafCount).map { leaf in
            let start = leaf * leafLength
            return leaves.subdata(in: start..<(start + leafLength))
        }

        XCTAssertEqual(rawRoot, try MerkleOracle.rootSHA3_256(leaves: dataLeaves))
        XCTAssertEqual(rawRoot.hexString, "328b14d25423df985c5d7649d24a474625ee648e90130e136164de604c93836d")
    }

    func testCPUMerkleRejectsMalformedInputs() {
        XCTAssertThrowsError(try MerkleOracle.rootSHA3_256(leaves: [])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidLeafCount(0))
        }
        XCTAssertThrowsError(try MerkleOracle.rootSHA3_256(leaves: [Data(), Data(), Data()])) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidLeafCount(3))
        }
        XCTAssertThrowsError(try MerkleOracle.rootSHA3_256(leaves: [Data(repeating: 0, count: 31)], hashLeaves: false)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidPrehashedLeafLength(31))
        }
        XCTAssertThrowsError(try MerkleOracle.rootSHA3_256(rawLeaves: Data(repeating: 0, count: 31), leafCount: 1, leafStride: 32, leafLength: 32)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try MerkleOracle.rootSHA3_256(rawLeaves: Data(), leafCount: 1, leafStride: 0, leafLength: 1)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    #if canImport(Metal)
    func testGPUMerkleMatchesCPU() throws {
        guard let _ = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext()
        let committer = SHA3MerkleCommitter(context: context)
        for leafLength in [0, 32, 136] {
            let leaves = Self.makeLeaves(count: 16, leafLength: leafLength)
            let cpu = try MerkleOracle.rootSHA3_256(
                rawLeaves: leaves,
                leafCount: 16,
                leafStride: leafLength,
                leafLength: leafLength
            )
            let gpu = try committer.commitRawLeaves(
                leaves: leaves,
                leafCount: 16,
                leafStride: leafLength,
                leafLength: leafLength
            )
            XCTAssertEqual(cpu, gpu.root)
        }
    }

    func testGPUMerkleVerifiedCommitMatchesCPU() throws {
        guard let _ = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 32
        let leafLength = 64
        let leaves = Self.makeLeaves(count: leafCount, leafLength: leafLength, salt: 37)
        let context = try MetalContext()
        let committer = SHA3MerkleCommitter(context: context)
        let commitment = try committer.commitRawLeavesVerified(
            leaves: leaves,
            leafCount: leafCount,
            leafStride: leafLength,
            leafLength: leafLength
        )
        let cpuRoot = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: leafCount,
            leafStride: leafLength,
            leafLength: leafLength
        )

        XCTAssertEqual(commitment.root, cpuRoot)
    }

    func testGPURawLeafMerklePlanCanBeReused() throws {
        guard let _ = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 16
        let leafLength = 32
        let context = try MetalContext()
        let committer = SHA3MerkleCommitter(context: context)
        let plan = try committer.makeRawLeavesCommitPlan(
            leafCount: leafCount,
            leafStride: leafLength,
            leafLength: leafLength
        )
        XCTAssertEqual(plan.subtreeLeafCount, 0)

        for salt in [0, 113] {
            let leaves = Self.makeLeaves(count: leafCount, leafLength: leafLength, salt: salt)
            let cpu = try MerkleOracle.rootSHA3_256(
                rawLeaves: leaves,
                leafCount: leafCount,
                leafStride: leafLength,
                leafLength: leafLength
            )
            let gpu = try plan.commit(leaves: leaves)
            XCTAssertEqual(cpu, gpu.root)
            try plan.clearReusableBuffers()
        }
    }

    func testGPURawLeafMerklePlanSupportsSingleUploadRingSlot() throws {
        guard let _ = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 16
        let leafLength = 64
        let context = try MetalContext()
        let committer = SHA3MerkleCommitter(context: context)
        let plan = try committer.makeRawLeavesCommitPlan(
            leafCount: leafCount,
            leafStride: leafLength,
            leafLength: leafLength,
            configuration: MerkleCommitPlanConfiguration(uploadRingSlotCount: 1)
        )

        for salt in [11, 97, 211] {
            let leaves = Self.makeLeaves(count: leafCount, leafLength: leafLength, salt: salt)
            let cpu = try MerkleOracle.rootSHA3_256(
                rawLeaves: leaves,
                leafCount: leafCount,
                leafStride: leafLength,
                leafLength: leafLength
            )
            let gpu = try plan.commit(leaves: leaves)
            XCTAssertEqual(cpu, gpu.root)
        }
    }

    func testGPURawLeafMerklePlanRejectsInvalidUploadRingSlotCount() throws {
        guard let _ = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext()
        let committer = SHA3MerkleCommitter(context: context)

        XCTAssertThrowsError(
            try committer.makeRawLeavesCommitPlan(
                leafCount: 2,
                leafStride: 32,
                leafLength: 32,
                configuration: MerkleCommitPlanConfiguration(uploadRingSlotCount: 0)
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testGPUMerkleFusedUpperBoundaryMatchesCPU() throws {
        guard let _ = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 1024
        let leafLength = 32
        let leaves = Self.makeLeaves(count: leafCount, leafLength: leafLength, salt: 71)
        let cpu = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: leafCount,
            leafStride: leafLength,
            leafLength: leafLength
        )

        let context = try MetalContext()
        let committer = SHA3MerkleCommitter(context: context)
        let plan = try committer.makeRawLeavesCommitPlan(
            leafCount: leafCount,
            leafStride: leafLength,
            leafLength: leafLength
        )
        XCTAssertGreaterThanOrEqual(plan.fusedUpperNodeLimit, 2)
        XCTAssertEqual(plan.subtreeLeafCount, 0)

        let gpu = try plan.commit(leaves: leaves)
        XCTAssertEqual(cpu, gpu.root)
    }

    func testGPUMerkleSubtreePathSupportsStridedLeaves() throws {
        guard let _ = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 512
        let leafLength = 32
        let leafStride = 40
        let leaves = Self.makeLeaves(count: leafCount, leafStride: leafStride, leafLength: leafLength, salt: 19)
        let cpu = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: leafCount,
            leafStride: leafStride,
            leafLength: leafLength
        )

        let context = try MetalContext()
        let committer = SHA3MerkleCommitter(context: context)
        let plan = try committer.makeRawLeavesCommitPlan(
            leafCount: leafCount,
            leafStride: leafStride,
            leafLength: leafLength,
            configuration: MerkleCommitPlanConfiguration(leafSubtreeMode: .fixed(64))
        )
        XCTAssertEqual(plan.subtreeLeafCount, 64)

        let gpu = try plan.commit(leaves: leaves)
        XCTAssertEqual(cpu, gpu.root)
    }

    func testGPUMerklePlanRejectsUInt32OverflowingLeafCount() throws {
        guard let _ = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext()
        let committer = SHA3MerkleCommitter(context: context)

        XCTAssertThrowsError(
            try committer.makeRawLeavesCommitPlan(
                leafCount: Int(UInt32.max) + 1,
                leafStride: 0,
                leafLength: 0
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testGPUMerklePlanRejectsPastFullRateLeaves() throws {
        guard let _ = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext()
        let committer = SHA3MerkleCommitter(context: context)

        XCTAssertThrowsError(
            try committer.makeRawLeavesCommitPlan(
                leafCount: 2,
                leafStride: 137,
                leafLength: 137
            )
        ) { error in
            XCTAssertEqual(error as? AppleZKProverError, .unsupportedOneBlockLength(137))
        }
    }

    func testGPURawLeafMerklePlanConcurrentReuseIsSerialized() throws {
        guard let _ = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let leafCount = 256
        let leafLength = 128
        let context = try MetalContext()
        let committer = SHA3MerkleCommitter(context: context)
        let plan = try committer.makeRawLeavesCommitPlan(
            leafCount: leafCount,
            leafStride: leafLength,
            leafLength: leafLength
        )
        let queue = DispatchQueue(label: "AppleZKProverTests.Merkle.ConcurrentPlan", attributes: .concurrent)
        let group = DispatchGroup()
        let failures = TestFailureRecorder()

        for task in 0..<8 {
            group.enter()
            queue.async {
                defer { group.leave() }

                do {
                    let leaves = Self.makeLeaves(
                        count: leafCount,
                        leafLength: leafLength,
                        salt: task * 53
                    )
                    let cpu = try MerkleOracle.rootSHA3_256(
                        rawLeaves: leaves,
                        leafCount: leafCount,
                        leafStride: leafLength,
                        leafLength: leafLength
                    )
                    let gpu = try plan.commit(leaves: leaves)
                    if gpu.root != cpu {
                        failures.append("Merkle mismatch in task \(task)")
                    }
                } catch {
                    failures.append("Merkle task \(task) failed: \(error)")
                }
            }
        }

        group.wait()
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }
    #endif

    private static func makeLeaves(count: Int, leafLength: Int, salt: Int = 0) -> Data {
        makeLeaves(count: count, leafStride: leafLength, leafLength: leafLength, salt: salt)
    }

    private static func makeLeaves(count: Int, leafStride: Int, leafLength: Int, salt: Int = 0) -> Data {
        var bytes = [UInt8](repeating: 0xa5, count: count * leafStride)
        for leaf in 0..<count {
            for j in 0..<leafLength {
                bytes[leaf * leafStride + j] = UInt8(truncatingIfNeeded: (leaf &* 29) &+ (j &* 7) &+ salt &+ 3)
            }
        }
        return Data(bytes)
    }
}
