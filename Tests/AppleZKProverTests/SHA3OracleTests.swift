import XCTest
#if canImport(Metal)
import Metal
#endif
@testable import AppleZKProver

final class TestFailureRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [String] = []

    func append(_ message: String) {
        lock.lock()
        messages.append(message)
        lock.unlock()
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return messages.isEmpty
    }

    func joined(separator: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        return messages.joined(separator: separator)
    }
}

final class SHA3OracleTests: XCTestCase {
    struct KeccakPermutationParams {
        var count: UInt32
        var inputStride: UInt32
        var outputStride: UInt32
    }

    func testEmptyStringVector() {
        let digest = SHA3Oracle.sha3_256(Data())
        XCTAssertEqual(
            digest.hexString,
            "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"
        )
    }

    func testABCStringVector() {
        let digest = SHA3Oracle.sha3_256(Data("abc".utf8))
        XCTAssertEqual(
            digest.hexString,
            "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"
        )
    }

    func testSHA3RateBoundaryVectors() {
        let vectors: [(Int, String)] = [
            (135, "87415687ea3625a5b5e687c95e1d64ba9d2788b93ce76d5602d465bdc1cc9e6d"),
            (136, "5a252ab523703cda4b29667be9454cd077a6807ffc463b41f2f18c7ce0119422"),
            (137, "e66aae37ecd2f057b7b45d3f8ce137d12e63f29b520af4e79664a0a46dc3040c"),
            (512, "56473ae5887735c22921d5cbe7e89a70816dc5879c7e7b961c2afdbfda2e754e"),
        ]

        for (length, expectedHex) in vectors {
            let bytes = Data((0..<length).map { UInt8(truncatingIfNeeded: $0 * 11 + 7) })
            XCTAssertEqual(SHA3Oracle.sha3_256(bytes).hexString, expectedHex, "length \(length)")
        }
    }

    func testKeccakEmptyStringVector() {
        let digest = KeccakOracle.keccak_256(Data())
        XCTAssertEqual(
            digest.hexString,
            "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
        )
    }

    func testKeccakABCStringVector() {
        let digest = KeccakOracle.keccak_256(Data("abc".utf8))
        XCTAssertEqual(
            digest.hexString,
            "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"
        )
    }

    func testKeccakRateBoundaryVectors() {
        let vectors: [(Int, String)] = [
            (135, "5cc83a61d8e1849c1e959a1fdcb36a7254e836ef5eb22abb6099c442de6279ba"),
            (136, "d5cc9ca93225fd3e61b15e126f08bdca3821154ee88cb901b0cbc3d66ae75eb6"),
            (137, "bd9be1cd315d1958d432f447f4b730b6702469ee32d677a77a53201d4a2c3075"),
            (512, "270ad36c4b58b3e5a624c53f9c49e20c4e311c02ee6f990f386115c735f9e58d"),
        ]

        for (length, expectedHex) in vectors {
            let bytes = Data((0..<length).map { UInt8(truncatingIfNeeded: $0 * 11 + 7) })
            XCTAssertEqual(KeccakOracle.keccak_256(bytes).hexString, expectedHex, "length \(length)")
        }
    }

    func testSHA3AndKeccakDomainsDiffer() {
        XCTAssertNotEqual(SHA3Oracle.sha3_256(Data()), KeccakOracle.keccak_256(Data()))
        XCTAssertNotEqual(SHA3Oracle.sha3_256(Data("abc".utf8)), KeccakOracle.keccak_256(Data("abc".utf8)))
    }

    func testOneBlockShortcutMatchesGenericPath() throws {
        let bytes = Data((0..<136).map { UInt8(truncatingIfNeeded: $0 * 11 + 7) })
        XCTAssertEqual(SHA3Oracle.sha3_256(bytes), try SHA3Oracle.sha3_256(oneBlock: bytes))
        XCTAssertEqual(KeccakOracle.keccak_256(bytes), try KeccakOracle.keccak_256(oneBlock: bytes))
    }

    func testOneBlockShortcutRejectsMultiBlockInputs() {
        let bytes = Data(repeating: 0x42, count: 137)

        XCTAssertThrowsError(try SHA3Oracle.sha3_256(oneBlock: bytes)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .unsupportedOneBlockLength(137))
        }
        XCTAssertThrowsError(try KeccakOracle.keccak_256(oneBlock: bytes)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .unsupportedOneBlockLength(137))
        }
    }

    #if canImport(Metal)
    func testGPUOneBlockBatchHasherMatchesCPU() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext()
        let hasher = SHA3BatchHasher(context: context)

        for messageLength in [0, 32, 64, 128, 136] {
            let count = 7
            let messageStride = messageLength == 0 ? 0 : messageLength + 5
            let outputStride = 40
            let messages = Self.makeBatchMessages(
                count: count,
                messageStride: messageStride,
                messageLength: messageLength
            )
            let descriptor = FixedMessageBatchDescriptor(
                count: count,
                messageStride: messageStride,
                messageLength: messageLength,
                outputStride: outputStride
            )

            let result = try hasher.hashFixedOneBlock(messages: messages, descriptor: descriptor)
            for i in 0..<count {
                let messageStart = i * messageStride
                let message = messages.subdata(in: messageStart..<(messageStart + messageLength))
                let digestStart = i * outputStride
                let digest = result.digests.subdata(in: digestStart..<(digestStart + 32))
                XCTAssertEqual(digest, SHA3Oracle.sha3_256(message))
            }
        }
    }

    func testGPUKeccakOneBlockBatchHasherMatchesCPU() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext()
        let hasher = Keccak256BatchHasher(context: context)

        for messageLength in [0, 32, 64, 128, 135, 136] {
            let count = 7
            let messageStride = messageLength == 0 ? 0 : messageLength + 5
            let outputStride = 40
            let messages = Self.makeBatchMessages(
                count: count,
                messageStride: messageStride,
                messageLength: messageLength
            )
            let descriptor = FixedMessageBatchDescriptor(
                count: count,
                messageStride: messageStride,
                messageLength: messageLength,
                outputStride: outputStride
            )

            let result = try hasher.hashFixedOneBlock(messages: messages, descriptor: descriptor)
            for i in 0..<count {
                let messageStart = i * messageStride
                let message = messages.subdata(in: messageStart..<(messageStart + messageLength))
                let digestStart = i * outputStride
                let digest = result.digests.subdata(in: digestStart..<(digestStart + 32))
                XCTAssertEqual(digest, KeccakOracle.keccak_256(message))
            }
        }
    }

    func testGPUSIMDGroupKeccakF1600PermutationMatchesCPU() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext()
        guard context.capabilities.supportsApple7 || context.capabilities.supportsSIMDReductions else {
            throw XCTSkip("SIMD-group permutation path requires Apple7 or equivalent SIMD-group support")
        }

        let stateCount = 6
        let wordsPerState = 25
        let inputStride = wordsPerState * MemoryLayout<UInt64>.stride
        let outputStride = inputStride
        var inputWords: [UInt64] = []
        inputWords.reserveCapacity(stateCount * wordsPerState)
        for state in 0..<stateCount {
            for lane in 0..<wordsPerState {
                let value = UInt64(truncatingIfNeeded: state * 0x1f1f_0101 + lane * 0x0102_0305)
                    ^ (UInt64(lane) << 40)
                    ^ (UInt64(state) << 56)
                inputWords.append(value)
            }
        }

        let pipeline = try context.pipeline(for: KernelSpec(
            kernel: "keccak_f1600_permutation_simdgroup",
            family: .simdgroup,
            queueMode: .metal3,
            threadsPerThreadgroup: UInt16(max(25, context.capabilities.maxThreadsPerThreadgroup))
        ))
        XCTAssertGreaterThanOrEqual(pipeline.threadExecutionWidth, 25)

        guard let input = context.device.makeBuffer(
            bytes: inputWords,
            length: inputWords.count * MemoryLayout<UInt64>.stride,
            options: .storageModeShared
        ) else {
            throw AppleZKProverError.failedToCreateBuffer(label: "KeccakPermutation.Input", length: inputWords.count * MemoryLayout<UInt64>.stride)
        }
        guard let output = context.device.makeBuffer(
            length: inputWords.count * MemoryLayout<UInt64>.stride,
            options: .storageModeShared
        ) else {
            throw AppleZKProverError.failedToCreateBuffer(label: "KeccakPermutation.Output", length: inputWords.count * MemoryLayout<UInt64>.stride)
        }
        var params = KeccakPermutationParams(
            count: UInt32(stateCount),
            inputStride: UInt32(inputStride),
            outputStride: UInt32(outputStride)
        )

        guard let commandBuffer = context.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(input, offset: 0, index: 0)
        encoder.setBuffer(output, offset: 0, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<KeccakPermutationParams>.stride, index: 2)
        encoder.dispatchThreadgroups(
            MTLSize(width: stateCount, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let outputWords = output.contents().bindMemory(to: UInt64.self, capacity: inputWords.count)
        for state in 0..<stateCount {
            let start = state * wordsPerState
            let expected = try SHA3Oracle.keccakF1600Permutation(Array(inputWords[start..<(start + wordsPerState)]))
            let actual = (0..<wordsPerState).map { outputWords[start + $0] }
            XCTAssertEqual(actual, expected, "state \(state)")
        }
    }

    func testGPUSIMDGroupOneBlockHashersMatchCPU() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext()
        guard context.capabilities.supportsApple7 || context.capabilities.supportsSIMDReductions else {
            throw XCTSkip("SIMD-group hash path requires Apple7 or equivalent SIMD-group support")
        }

        let sha3Hasher = SHA3BatchHasher(context: context)
        let keccakHasher = Keccak256BatchHasher(context: context)
        for messageLength in [0, 1, 31, 32, 64, 128, 135, 136] {
            let count = 9
            let messageStride = messageLength == 0 ? 0 : messageLength + 3
            let outputStride = 40
            let messages = Self.makeBatchMessages(
                count: count,
                messageStride: messageStride,
                messageLength: messageLength,
                salt: messageLength * 13
            )
            let descriptor = FixedMessageBatchDescriptor(
                count: count,
                messageStride: messageStride,
                messageLength: messageLength,
                outputStride: outputStride
            )

            let sha3Result = try sha3Hasher.hashFixedOneBlock(
                messages: messages,
                descriptor: descriptor,
                kernelFamily: .simdgroup
            )
            let keccakResult = try keccakHasher.hashFixedOneBlock(
                messages: messages,
                descriptor: descriptor,
                kernelFamily: .simdgroup
            )

            for i in 0..<count {
                let messageStart = i * messageStride
                let message = messages.subdata(in: messageStart..<(messageStart + messageLength))
                let digestStart = i * outputStride
                let sha3Digest = sha3Result.digests.subdata(in: digestStart..<(digestStart + 32))
                let keccakDigest = keccakResult.digests.subdata(in: digestStart..<(digestStart + 32))
                XCTAssertEqual(sha3Digest, SHA3Oracle.sha3_256(message), "SHA3 length \(messageLength), message \(i)")
                XCTAssertEqual(keccakDigest, KeccakOracle.keccak_256(message), "Keccak length \(messageLength), message \(i)")
            }
        }
    }

    func testGPUHashPlansRejectUInt32OverflowingCounts() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext()
        let descriptor = FixedMessageBatchDescriptor(
            count: Int(UInt32.max) + 1,
            messageStride: 0,
            messageLength: 0,
            outputStride: 32
        )

        XCTAssertThrowsError(try SHA3BatchHasher(context: context).makeFixedOneBlockPlan(descriptor: descriptor)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
        XCTAssertThrowsError(try Keccak256BatchHasher(context: context).makeFixedOneBlockPlan(descriptor: descriptor)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .invalidInputLayout)
        }
    }

    func testGPUHashPlansRejectPastFullRateInputs() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let context = try MetalContext()
        let descriptor = FixedMessageBatchDescriptor(
            count: 1,
            messageStride: 137,
            messageLength: 137,
            outputStride: 32
        )

        XCTAssertThrowsError(try SHA3BatchHasher(context: context).makeFixedOneBlockPlan(descriptor: descriptor)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .unsupportedOneBlockLength(137))
        }
        XCTAssertThrowsError(try Keccak256BatchHasher(context: context).makeFixedOneBlockPlan(descriptor: descriptor)) { error in
            XCTAssertEqual(error as? AppleZKProverError, .unsupportedOneBlockLength(137))
        }
    }

    func testGPUKeccakOneBlockPlanCanBeReused() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let count = 5
        let messageLength = 32
        let messageStride = 37
        let outputStride = 40
        let context = try MetalContext()
        let hasher = Keccak256BatchHasher(context: context)
        let descriptor = FixedMessageBatchDescriptor(
            count: count,
            messageStride: messageStride,
            messageLength: messageLength,
            outputStride: outputStride
        )
        let plan = try hasher.makeFixedOneBlockPlan(descriptor: descriptor)

        for salt in [0, 97] {
            let messages = Self.makeBatchMessages(
                count: count,
                messageStride: messageStride,
                messageLength: messageLength,
                salt: salt
            )
            let result = try plan.hash(messages: messages)
            for i in 0..<count {
                let messageStart = i * messageStride
                let message = messages.subdata(in: messageStart..<(messageStart + messageLength))
                let digestStart = i * outputStride
                let digest = result.digests.subdata(in: digestStart..<(digestStart + 32))
                XCTAssertEqual(digest, KeccakOracle.keccak_256(message))
            }
            plan.clearReusableBuffers()
        }
    }

    func testGPUOneBlockPlanConcurrentReuseIsSerialized() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let count = 16
        let messageLength = 128
        let messageStride = 136
        let outputStride = 40
        let context = try MetalContext()
        let hasher = SHA3BatchHasher(context: context)
        let descriptor = FixedMessageBatchDescriptor(
            count: count,
            messageStride: messageStride,
            messageLength: messageLength,
            outputStride: outputStride
        )
        let plan = try hasher.makeFixedOneBlockPlan(descriptor: descriptor)
        let queue = DispatchQueue(label: "AppleZKProverTests.SHA3.ConcurrentPlan", attributes: .concurrent)
        let group = DispatchGroup()
        let failures = TestFailureRecorder()

        for task in 0..<8 {
            group.enter()
            queue.async {
                defer { group.leave() }

                do {
                    let salt = task * 37
                    let messages = Self.makeBatchMessages(
                        count: count,
                        messageStride: messageStride,
                        messageLength: messageLength,
                        salt: salt
                    )
                    let result = try plan.hash(messages: messages)
                    for i in 0..<count {
                        let messageStart = i * messageStride
                        let message = messages.subdata(in: messageStart..<(messageStart + messageLength))
                        let digestStart = i * outputStride
                        let digest = result.digests.subdata(in: digestStart..<(digestStart + 32))
                        if digest != SHA3Oracle.sha3_256(message) {
                            failures.append("SHA3 mismatch in task \(task), message \(i)")
                            return
                        }
                    }
                } catch {
                    failures.append("SHA3 task \(task) failed: \(error)")
                }
            }
        }

        group.wait()
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testGPUKeccakOneBlockPlanConcurrentReuseIsSerialized() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let count = 16
        let messageLength = 128
        let messageStride = 136
        let outputStride = 40
        let context = try MetalContext()
        let hasher = Keccak256BatchHasher(context: context)
        let descriptor = FixedMessageBatchDescriptor(
            count: count,
            messageStride: messageStride,
            messageLength: messageLength,
            outputStride: outputStride
        )
        let plan = try hasher.makeFixedOneBlockPlan(descriptor: descriptor)
        let queue = DispatchQueue(label: "AppleZKProverTests.Keccak.ConcurrentPlan", attributes: .concurrent)
        let group = DispatchGroup()
        let failures = TestFailureRecorder()

        for task in 0..<8 {
            group.enter()
            queue.async {
                defer { group.leave() }

                do {
                    let salt = task * 41
                    let messages = Self.makeBatchMessages(
                        count: count,
                        messageStride: messageStride,
                        messageLength: messageLength,
                        salt: salt
                    )
                    let result = try plan.hash(messages: messages)
                    for i in 0..<count {
                        let messageStart = i * messageStride
                        let message = messages.subdata(in: messageStart..<(messageStart + messageLength))
                        let digestStart = i * outputStride
                        let digest = result.digests.subdata(in: digestStart..<(digestStart + 32))
                        if digest != KeccakOracle.keccak_256(message) {
                            failures.append("Keccak mismatch in task \(task), message \(i)")
                            return
                        }
                    }
                } catch {
                    failures.append("Keccak task \(task) failed: \(error)")
                }
            }
        }

        group.wait()
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testGPUOneBlockPlanCanBeReused() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device on this test machine")
        }

        let count = 5
        let messageLength = 32
        let messageStride = 37
        let outputStride = 40
        let context = try MetalContext()
        let hasher = SHA3BatchHasher(context: context)
        let descriptor = FixedMessageBatchDescriptor(
            count: count,
            messageStride: messageStride,
            messageLength: messageLength,
            outputStride: outputStride
        )
        let plan = try hasher.makeFixedOneBlockPlan(descriptor: descriptor)

        for salt in [0, 97] {
            let messages = Self.makeBatchMessages(
                count: count,
                messageStride: messageStride,
                messageLength: messageLength,
                salt: salt
            )
            let result = try plan.hash(messages: messages)
            for i in 0..<count {
                let messageStart = i * messageStride
                let message = messages.subdata(in: messageStart..<(messageStart + messageLength))
                let digestStart = i * outputStride
                let digest = result.digests.subdata(in: digestStart..<(digestStart + 32))
                XCTAssertEqual(digest, SHA3Oracle.sha3_256(message))
            }
            plan.clearReusableBuffers()
        }
    }
    #endif

    private static func makeBatchMessages(count: Int, messageStride: Int, messageLength: Int, salt: Int = 0) -> Data {
        var bytes = [UInt8](repeating: 0xa5, count: count * messageStride)
        for message in 0..<count {
            for offset in 0..<messageLength {
                bytes[message * messageStride + offset] = UInt8(truncatingIfNeeded: message * 31 + offset * 9 + salt + 11)
            }
        }
        return Data(bytes)
    }
}
