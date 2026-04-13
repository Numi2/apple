import Foundation

public enum AppleZKProverError: Error, Equatable, LocalizedError {
    case noMetalDevice
    case failedToCreateCommandQueue
    case failedToCreateCommandBuffer
    case failedToCreateEncoder
    case failedToCreateBuffer(label: String, length: Int)
    case failedToCreateBinaryArchive(String)
    case failedToUpdateBinaryArchive(String)
    case failedToSerializeBinaryArchive(String)
    case failedToOpenPlanDatabase(String)
    case failedToUpdatePlanDatabase(String)
    case failedToLocateMetalSource
    case failedToReadMetalSource
    case unsupportedOneBlockLength(Int)
    case invalidLeafCount(Int)
    case invalidPrehashedLeafLength(Int)
    case invalidInputLayout
    case correctnessValidationFailed(String)
    case commandExecutionFailed(String)
    case unavailableOnThisPlatform
    case invalidKernelConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .noMetalDevice:
            return "No Metal device is available."
        case .failedToCreateCommandQueue:
            return "Failed to create Metal command queue."
        case .failedToCreateCommandBuffer:
            return "Failed to create Metal command buffer."
        case .failedToCreateEncoder:
            return "Failed to create Metal compute command encoder."
        case let .failedToCreateBuffer(label, length):
            return "Failed to create Metal buffer '\(label)' of length \(length)."
        case let .failedToCreateBinaryArchive(message):
            return "Failed to create Metal binary archive: \(message)"
        case let .failedToUpdateBinaryArchive(message):
            return "Failed to update Metal binary archive: \(message)"
        case let .failedToSerializeBinaryArchive(message):
            return "Failed to serialize Metal binary archive: \(message)"
        case let .failedToOpenPlanDatabase(message):
            return "Failed to open planner database: \(message)"
        case let .failedToUpdatePlanDatabase(message):
            return "Failed to update planner database: \(message)"
        case .failedToLocateMetalSource:
            return "Failed to locate bundled Metal source file."
        case .failedToReadMetalSource:
            return "Failed to read bundled Metal source file."
        case let .unsupportedOneBlockLength(length):
            return "Fixed-rate SHA3/Keccak path supports at most 136 bytes, got \(length)."
        case let .invalidLeafCount(count):
            return "Leaf count must be a non-zero power of two, got \(count)."
        case let .invalidPrehashedLeafLength(length):
            return "Prehashed Merkle leaves must be 32-byte digests, got \(length) bytes."
        case .invalidInputLayout:
            return "The provided input bytes do not match the declared count/stride/length layout."
        case let .correctnessValidationFailed(message):
            return "Correctness validation failed: \(message)"
        case let .commandExecutionFailed(message):
            return "Metal command execution failed: \(message)"
        case .unavailableOnThisPlatform:
            return "Metal acceleration is unavailable on this platform."
        case let .invalidKernelConfiguration(message):
            return "Invalid kernel configuration: \(message)"
        }
    }
}

public struct GPUExecutionStats: Sendable {
    public let cpuWallSeconds: Double
    public let gpuSeconds: Double?

    public init(cpuWallSeconds: Double, gpuSeconds: Double?) {
        self.cpuWallSeconds = cpuWallSeconds
        self.gpuSeconds = gpuSeconds
    }
}

public struct MerkleCommitment: Sendable {
    public let root: Data
    public let stats: GPUExecutionStats

    public init(root: Data, stats: GPUExecutionStats) {
        self.root = root
        self.stats = stats
    }
}

public struct MerkleOpeningProof: Equatable, Sendable {
    public let leafIndex: Int
    public let leaf: Data
    public let siblingHashes: [Data]
    public let root: Data

    public init(
        leafIndex: Int,
        leaf: Data,
        siblingHashes: [Data],
        root: Data
    ) {
        self.leafIndex = leafIndex
        self.leaf = leaf
        self.siblingHashes = siblingHashes
        self.root = root
    }
}

public struct MerkleOpening: Sendable {
    public let proof: MerkleOpeningProof
    public let stats: GPUExecutionStats

    public init(proof: MerkleOpeningProof, stats: GPUExecutionStats) {
        self.proof = proof
        self.stats = stats
    }
}

public struct FixedMessageBatchDescriptor: Sendable {
    public let count: Int
    public let messageStride: Int
    public let messageLength: Int
    public let outputStride: Int

    public init(count: Int, messageStride: Int, messageLength: Int, outputStride: Int = 32) {
        self.count = count
        self.messageStride = messageStride
        self.messageLength = messageLength
        self.outputStride = outputStride
    }
}

public enum FixedOneBlockHashKernelFamily: String, Sendable {
    case scalar
    case simdgroup
}

public enum KeccakF1600PermutationKernelFamily: String, Sendable {
    case scalar
    case simdgroup
}

public struct GPUHashBatchResult: Sendable {
    public let digests: Data
    public let stats: GPUExecutionStats

    public init(digests: Data, stats: GPUExecutionStats) {
        self.digests = digests
        self.stats = stats
    }
}

public struct KeccakF1600PermutationBatchDescriptor: Sendable {
    public static let stateByteCount = 25 * MemoryLayout<UInt64>.stride

    public let count: Int
    public let inputStride: Int
    public let outputStride: Int

    public init(
        count: Int,
        inputStride: Int = Self.stateByteCount,
        outputStride: Int = Self.stateByteCount
    ) {
        self.count = count
        self.inputStride = inputStride
        self.outputStride = outputStride
    }
}

public struct KeccakF1600PermutationBatchResult: Sendable {
    public let states: Data
    public let stats: GPUExecutionStats

    public init(states: Data, stats: GPUExecutionStats) {
        self.states = states
        self.stats = stats
    }
}

func checkedBufferLength(_ lhs: Int, _ rhs: Int) throws -> Int {
    let result = lhs.multipliedReportingOverflow(by: rhs)
    guard !result.overflow else {
        throw AppleZKProverError.invalidInputLayout
    }
    return result.partialValue
}

func checkedUInt32(_ value: Int) throws -> UInt32 {
    guard value >= 0, value <= Int(UInt32.max) else {
        throw AppleZKProverError.invalidInputLayout
    }
    return UInt32(value)
}
