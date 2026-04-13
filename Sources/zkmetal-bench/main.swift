import Foundation
import AppleZKProver

enum BenchFormat: String {
    case text
    case json
}

enum BenchHashFunction: String {
    case sha3_256 = "sha3-256"
    case keccak_256 = "keccak-256"
}

enum BenchMerkleSubtreeMode: Equatable {
    case disabled
    case automatic
    case fixed(Int)
}

let verificationFailureExitCode: Int32 = 2

enum BenchError: Error, LocalizedError {
    case invalidArgument(String)
    case missingValue(String)
    case helpRequested

    var errorDescription: String? {
        switch self {
        case let .invalidArgument(message):
            return message
        case let .missingValue(flag):
            return "Missing value for \(flag)."
        case .helpRequested:
            return nil
        }
    }
}

enum BenchParseResult {
    case success(BenchConfig)
    case failure(BenchError)
}

struct BenchConfig {
    var leafCount: Int = 1 << 14
    var leafLength: Int = 32
    var hashFunction: BenchHashFunction = .sha3_256
    var hashKernelFamily: FixedOneBlockHashKernelFamily = .scalar
    var hashSIMDGroupsPerThreadgroup = 2
    var keccakF1600Permutation = false
    var m31DotProduct = false
    var m31VectorInverse = false
    var permutationKernelFamily: KeccakF1600PermutationKernelFamily = .scalar
    var permutationSIMDGroupsPerThreadgroup = 2
    var merkleSubtreeMode: BenchMerkleSubtreeMode = .disabled
    var merkleOpening = false
    var openingLeafIndex = 0
    var verifyWithCPU = true
    var warmupIterations = 1
    var iterations = 5
    var format: BenchFormat = .text
    var usePipelineArchive = true
    var pipelineArchiveURL: URL?
    var suite = false
    var suiteLeafLengths = [0, 32, 64, 128, 135, SHA3Oracle.sha3_256Rate]
    var suiteHashFunctions: [BenchHashFunction] = [.sha3_256, .keccak_256]

    static func parse(arguments: [String]) -> BenchParseResult {
        var config = BenchConfig()
        if let error = config.apply(arguments: arguments) {
            return .failure(error)
        }
        return .success(config)
    }

    private mutating func apply(arguments: [String]) -> BenchError? {
        var iterator = arguments.dropFirst().makeIterator()
        while let arg = iterator.next() {
            switch arg {
            case "--leaves":
                switch Self.parsePositiveInt(flag: arg, value: iterator.next()) {
                case let .success(value): leafCount = value
                case let .failure(error): return error
                }
            case "--states":
                keccakF1600Permutation = true
                switch Self.parsePositiveInt(flag: arg, value: iterator.next()) {
                case let .success(value): leafCount = value
                case let .failure(error): return error
                }
            case "--elements":
                if !m31VectorInverse {
                    m31DotProduct = true
                }
                switch Self.parsePositiveInt(flag: arg, value: iterator.next()) {
                case let .success(value): leafCount = value
                case let .failure(error): return error
                }
            case "--leaf-bytes":
                switch Self.parseNonnegativeInt(flag: arg, value: iterator.next()) {
                case let .success(value): leafLength = value
                case let .failure(error): return error
                }
            case "--iterations":
                switch Self.parsePositiveInt(flag: arg, value: iterator.next()) {
                case let .success(value): iterations = value
                case let .failure(error): return error
                }
            case "--warmups":
                switch Self.parseNonnegativeInt(flag: arg, value: iterator.next()) {
                case let .success(value): warmupIterations = value
                case let .failure(error): return error
                }
            case "--format":
                let valueResult = Self.requireValue(flag: arg, value: iterator.next())
                let value: String
                switch valueResult {
                case let .success(parsed): value = parsed
                case let .failure(error): return error
                }
                guard let parsed = BenchFormat(rawValue: value) else {
                    return BenchError.invalidArgument("--format must be either 'text' or 'json'.")
                }
                format = parsed
            case "--hash-function", "--hash":
                let valueResult = Self.requireValue(flag: arg, value: iterator.next())
                let value: String
                switch valueResult {
                case let .success(parsed): value = parsed
                case let .failure(error): return error
                }
                guard let parsed = BenchHashFunction(rawValue: value) else {
                    return BenchError.invalidArgument("--hash-function must be either 'sha3-256' or 'keccak-256'.")
                }
                hashFunction = parsed
            case "--hash-kernel", "--hash-kernel-family":
                let valueResult = Self.requireValue(flag: arg, value: iterator.next())
                let value: String
                switch valueResult {
                case let .success(parsed): value = parsed
                case let .failure(error): return error
                }
                guard let parsed = FixedOneBlockHashKernelFamily(rawValue: value) else {
                    return BenchError.invalidArgument("--hash-kernel must be either 'scalar' or 'simdgroup'.")
                }
                hashKernelFamily = parsed
            case "--hash-simdgroups-per-threadgroup":
                switch Self.parsePositiveInt(flag: arg, value: iterator.next()) {
                case let .success(value): hashSIMDGroupsPerThreadgroup = value
                case let .failure(error): return error
                }
            case "--keccakf-permutation", "--permutation-only":
                keccakF1600Permutation = true
            case "--m31-dot-product":
                m31DotProduct = true
            case "--m31-inverse", "--m31-vector-inverse":
                m31VectorInverse = true
                m31DotProduct = false
            case "--merkle-opening":
                merkleOpening = true
            case "--opening-leaf-index":
                switch Self.parseNonnegativeInt(flag: arg, value: iterator.next()) {
                case let .success(value): openingLeafIndex = value
                case let .failure(error): return error
                }
            case "--permutation-kernel":
                let valueResult = Self.requireValue(flag: arg, value: iterator.next())
                let value: String
                switch valueResult {
                case let .success(parsed): value = parsed
                case let .failure(error): return error
                }
                guard let parsed = KeccakF1600PermutationKernelFamily(rawValue: value) else {
                    return BenchError.invalidArgument("--permutation-kernel must be either 'scalar' or 'simdgroup'.")
                }
                permutationKernelFamily = parsed
            case "--permutation-simdgroups-per-threadgroup":
                switch Self.parsePositiveInt(flag: arg, value: iterator.next()) {
                case let .success(value): permutationSIMDGroupsPerThreadgroup = value
                case let .failure(error): return error
                }
            case "--json":
                format = .json
            case "--suite":
                suite = true
            case "--suite-leaf-bytes":
                suite = true
                switch Self.parseNonnegativeIntList(flag: arg, value: iterator.next()) {
                case let .success(value): suiteLeafLengths = value
                case let .failure(error): return error
                }
            case "--suite-hashes", "--suite-hash-functions":
                suite = true
                switch Self.parseHashFunctionList(flag: arg, value: iterator.next()) {
                case let .success(value): suiteHashFunctions = value
                case let .failure(error): return error
                }
            case "--no-verify":
                verifyWithCPU = false
            case "--verify":
                verifyWithCPU = true
            case "--pipeline-archive":
                let valueResult = Self.requireValue(flag: arg, value: iterator.next())
                let value: String
                switch valueResult {
                case let .success(parsed): value = parsed
                case let .failure(error): return error
                }
                pipelineArchiveURL = URL(fileURLWithPath: value)
                usePipelineArchive = true
            case "--no-pipeline-archive":
                usePipelineArchive = false
                pipelineArchiveURL = nil
            case "--merkle-subtree-auto":
                merkleSubtreeMode = .automatic
            case "--merkle-subtree-leaves":
                let subtreeLeafCount: Int
                switch Self.parsePositiveInt(flag: arg, value: iterator.next()) {
                case let .success(value): subtreeLeafCount = value
                case let .failure(error): return error
                }
                merkleSubtreeMode = .fixed(subtreeLeafCount)
            case "--no-merkle-subtree":
                merkleSubtreeMode = .disabled
            case "--help", "-h":
                return BenchError.helpRequested
            default:
                return BenchError.invalidArgument("Unknown argument: \(arg)")
            }
        }

        return validate()
    }

    static var usage: String {
        """
        zkmetal-bench

        Options:
          --leaves N                 Power-of-two leaf count. Default: 16384
          --leaf-bytes N             Leaf byte length in 0...136. Default: 32
          --warmups N                Untimed warmup iterations. Default: 1
          --iterations N             Timed iterations. Default: 5
          --format text|json         Output format. Default: text
          --hash-function NAME       Standalone hash benchmark: sha3-256 or keccak-256. Default: sha3-256
          --hash-kernel NAME         Standalone hash kernel family: scalar or simdgroup. Default: scalar
          --hash-simdgroups-per-threadgroup N
                                      SIMD-group hash kernel packing. Default: 2
          --keccakf-permutation      Run Keccak-F1600 permutation-only benchmark instead of hash/Merkle
          --m31-dot-product          Run M31 vector dot-product benchmark instead of hash/Merkle
          --m31-inverse              Run M31 vector inverse benchmark instead of hash/Merkle
          --elements N               Element count for M31 benchmarks. Alias for --leaves in those modes
          --merkle-opening           Run Merkle opening extraction benchmark instead of hash/Merkle
          --opening-leaf-index N     Leaf index for --merkle-opening. Default: 0
          --states N                 State count for --keccakf-permutation. Alias for --leaves in that mode
          --permutation-kernel NAME  Keccak-F1600 permutation kernel family: scalar or simdgroup. Default: scalar
          --permutation-simdgroups-per-threadgroup N
                                      SIMD-group permutation packing. Default: 2
          --json                     Shortcut for --format json
          --suite                    Run the supported benchmark matrix
          --suite-leaf-bytes LIST    Comma-separated suite leaf lengths. Default: 0,32,64,128,135,136
          --suite-hashes LIST        Comma-separated suite hash functions. Default: sha3-256,keccak-256
          --verify / --no-verify     Enable or disable CPU root check. Default: verify
          --pipeline-archive PATH    Read/write Metal binary archive at PATH
          --no-pipeline-archive      Disable Metal binary archive use
          --merkle-subtree-auto      Enable benchmark-tuned fixed-rate leaf subtree path
          --merkle-subtree-leaves N  Use N leaves per lower Merkle subtree; N must be a power of two
          --no-merkle-subtree        Disable lower subtree path. Default
        """
    }

    private mutating func validate() -> BenchError? {
        guard leafCount > 0 else {
            return BenchError.invalidArgument(keccakF1600Permutation ? "--states must be greater than zero." : "--leaves must be greater than zero.")
        }
        let exclusiveModes = [keccakF1600Permutation, merkleOpening, m31DotProduct, m31VectorInverse].filter { $0 }.count
        guard exclusiveModes <= 1 else {
            return BenchError.invalidArgument("--keccakf-permutation, --merkle-opening, --m31-dot-product, and --m31-inverse are mutually exclusive.")
        }
        if keccakF1600Permutation {
            guard !suite else {
                return BenchError.invalidArgument("--suite is not supported with --keccakf-permutation.")
            }
            guard !leafCount.multipliedReportingOverflow(by: KeccakF1600PermutationBatchDescriptor.stateByteCount).overflow else {
                return BenchError.invalidArgument("Requested Keccak-F1600 state buffer is too large for this process.")
            }
            return nil
        }
        if m31DotProduct || m31VectorInverse {
            guard !suite else {
                return BenchError.invalidArgument("--suite is not supported with M31 vector benchmarks.")
            }
            guard !leafCount.multipliedReportingOverflow(by: 2 * MemoryLayout<UInt32>.stride).overflow else {
                return BenchError.invalidArgument("Requested M31 vector buffers are too large for this process.")
            }
            return nil
        }
        guard !(suite && merkleOpening) else {
            return BenchError.invalidArgument("--suite is not supported with --merkle-opening.")
        }
        guard leafCount.nonzeroBitCount == 1 else {
            return BenchError.invalidArgument("--leaves must be a non-zero power of two.")
        }
        guard openingLeafIndex < leafCount else {
            return BenchError.invalidArgument("--opening-leaf-index must be in 0..<--leaves.")
        }
        if suite {
            guard !suiteLeafLengths.isEmpty else {
                return BenchError.invalidArgument("--suite-leaf-bytes must contain at least one length.")
            }
            for length in suiteLeafLengths {
                if let error = Self.validateLeafLength(length, flag: "--suite-leaf-bytes") {
                    return error
                }
            }
            guard !suiteHashFunctions.isEmpty else {
                return BenchError.invalidArgument("--suite-hashes must contain at least one hash function.")
            }
        } else {
            if let error = Self.validateLeafLength(leafLength, flag: "--leaf-bytes") {
                return error
            }
        }
        guard iterations > 0 else {
            return BenchError.invalidArgument("--iterations must be greater than zero.")
        }
        guard warmupIterations >= 0 else {
            return BenchError.invalidArgument("--warmups must be non-negative.")
        }
        let largestLeafLength = suite ? (suiteLeafLengths.max() ?? 0) : leafLength
        guard !leafCount.multipliedReportingOverflow(by: max(largestLeafLength, 1)).overflow else {
            return BenchError.invalidArgument("Requested leaf buffer is too large for this process.")
        }
        guard leafCount <= (Int.max - 1) / 2 else {
            return BenchError.invalidArgument("Requested leaf count is too large for Merkle hash accounting.")
        }
        switch merkleSubtreeMode {
        case .disabled:
            break
        case .automatic:
            break
        case let .fixed(value):
            guard value >= 2, value.nonzeroBitCount == 1 else {
                return BenchError.invalidArgument("--merkle-subtree-leaves must be a power of two greater than or equal to 2.")
            }
            guard value <= leafCount, leafCount.isMultiple(of: value) else {
                return BenchError.invalidArgument("--merkle-subtree-leaves must evenly divide --leaves.")
            }
        }
        return nil
    }

    private static func validateLeafLength(_ length: Int, flag: String) -> BenchError? {
        guard (0...SHA3Oracle.sha3_256Rate).contains(length) else {
            return BenchError.invalidArgument("\(flag) must be in 0...136 for the current fixed-rate SHA3 path.")
        }
        return nil
    }

    private static func parsePositiveInt(flag: String, value: String?) -> Result<Int, BenchError> {
        let parsed: Int
        switch parseNonnegativeInt(flag: flag, value: value) {
        case let .success(value): parsed = value
        case let .failure(error): return .failure(error)
        }
        guard parsed > 0 else {
            return .failure(BenchError.invalidArgument("\(flag) must be greater than zero."))
        }
        return .success(parsed)
    }

    private static func parseNonnegativeInt(flag: String, value: String?) -> Result<Int, BenchError> {
        let valueString: String
        switch requireValue(flag: flag, value: value) {
        case let .success(parsed): valueString = parsed
        case let .failure(error): return .failure(error)
        }
        guard let parsed = Int(valueString), parsed >= 0 else {
            return .failure(BenchError.invalidArgument("\(flag) must be a non-negative integer."))
        }
        return .success(parsed)
    }

    private static func requireValue(flag: String, value: String?) -> Result<String, BenchError> {
        guard let value else {
            return .failure(BenchError.missingValue(flag))
        }
        return .success(value)
    }

    private static func parseNonnegativeIntList(flag: String, value: String?) -> Result<[Int], BenchError> {
        let valueString: String
        switch requireValue(flag: flag, value: value) {
        case let .success(parsed): valueString = parsed
        case let .failure(error): return .failure(error)
        }
        let parts = valueString.split(separator: ",", omittingEmptySubsequences: false)
        guard !parts.isEmpty else {
            return .failure(BenchError.invalidArgument("\(flag) must be a comma-separated list of non-negative integers."))
        }

        var parsed: [Int] = []
        for part in parts {
            guard let number = Int(part.trimmingCharacters(in: .whitespacesAndNewlines)), number >= 0 else {
                return .failure(BenchError.invalidArgument("\(flag) must be a comma-separated list of non-negative integers."))
            }
            if !parsed.contains(number) {
                parsed.append(number)
            }
        }
        return .success(parsed)
    }

    private static func parseHashFunctionList(flag: String, value: String?) -> Result<[BenchHashFunction], BenchError> {
        let valueString: String
        switch requireValue(flag: flag, value: value) {
        case let .success(parsed): valueString = parsed
        case let .failure(error): return .failure(error)
        }
        let parts = valueString.split(separator: ",", omittingEmptySubsequences: false)
        guard !parts.isEmpty else {
            return .failure(BenchError.invalidArgument("\(flag) must be a comma-separated list containing sha3-256 or keccak-256."))
        }

        var parsed: [BenchHashFunction] = []
        for part in parts {
            let rawValue = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let hashFunction = BenchHashFunction(rawValue: rawValue) else {
                return .failure(BenchError.invalidArgument("\(flag) must contain only sha3-256 or keccak-256."))
            }
            if !parsed.contains(hashFunction) {
                parsed.append(hashFunction)
            }
        }
        return .success(parsed)
    }
}

func merkleSubtreeModeDescription(_ mode: BenchMerkleSubtreeMode) -> String {
    switch mode {
    case .disabled:
        return "disabled"
    case .automatic:
        return "automatic"
    case let .fixed(value):
        return "fixed:\(value)"
    }
}

struct DeviceReport: Codable {
    let name: String
    let registryID: UInt64
    let supportsApple3: Bool
    let supportsApple4: Bool
    let supportsApple7: Bool
    let supportsApple9: Bool
    let supports64BitAtomics: Bool
    let supportsSIMDReductions: Bool
    let supportsNonuniformThreadgroups: Bool
    let supportsBinaryArchives: Bool
    let maxThreadsPerThreadgroup: Int
    let maxThreadgroupMemoryLength: Int
    let hasUnifiedMemory: Bool
}

struct BenchmarkConfigReport: Codable {
    let leafCount: Int
    let leafLength: Int
    let leafStride: Int
    let hashFunction: String
    let hashKernelFamily: String
    let hashSIMDGroupsPerThreadgroup: Int?
    let merkleSubtreeMode: String
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct BenchmarkSuiteConfigReport: Codable {
    let leafCount: Int
    let leafLengths: [Int]
    let hashFunctions: [String]
    let hashKernelFamily: String
    let hashSIMDGroupsPerThreadgroup: Int?
    let merkleSubtreeMode: String
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct PipelineArchiveReport: Codable {
    let enabled: Bool
    let mode: String
    let path: String?
}

struct SeriesReport: Codable {
    let samples: [Double]
    let min: Double
    let median: Double
    let mean: Double
    let max: Double
}

struct MeasurementReport: Codable {
    let wallSeconds: SeriesReport
    let gpuSeconds: SeriesReport?
    let bestSecondsForThroughput: Double
    let hashInvocationsPerSecond: Double
    let inputBytesPerSecond: Double
}

struct FieldMeasurementReport: Codable {
    let wallSeconds: SeriesReport
    let gpuSeconds: SeriesReport?
    let bestSecondsForThroughput: Double
    let elementsPerSecond: Double
    let inputBytesPerSecond: Double
}

struct VerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let rootHex: String
    let cpuRootHex: String?
}

struct BenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: BenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let merkleFusedUpperNodeLimit: Int?
    let merkleSubtreeLeafCount: Int?
    let hash: MeasurementReport?
    let merkle: MeasurementReport?
    let verification: VerificationReport
}

struct BenchmarkSuiteReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: BenchmarkSuiteConfigReport
    let reports: [BenchmarkReport]
}

struct KeccakPermutationBenchmarkConfigReport: Codable {
    let stateCount: Int
    let stateStride: Int
    let outputStride: Int
    let kernelFamily: String
    let simdgroupsPerThreadgroup: Int?
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct KeccakPermutationVerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let outputDigestHex: String
    let cpuOutputDigestHex: String?
}

struct KeccakPermutationBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: KeccakPermutationBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let permutation: MeasurementReport?
    let verification: KeccakPermutationVerificationReport
}

struct M31DotProductBenchmarkConfigReport: Codable {
    let elementCount: Int
    let threadsPerThreadgroup: Int?
    let elementsPerThreadgroup: Int?
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct M31DotProductVerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let value: UInt32
    let cpuValue: UInt32?
}

struct M31DotProductBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: M31DotProductBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let dotProduct: FieldMeasurementReport?
    let verification: M31DotProductVerificationReport
}

struct M31VectorBenchmarkConfigReport: Codable {
    let elementCount: Int
    let operation: String
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct M31VectorVerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let outputDigestHex: String
    let cpuOutputDigestHex: String?
}

struct M31VectorBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: M31VectorBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let vector: FieldMeasurementReport?
    let verification: M31VectorVerificationReport
}

struct MerkleOpeningBenchmarkConfigReport: Codable {
    let leafCount: Int
    let leafLength: Int
    let leafStride: Int
    let leafIndex: Int
    let merkleSubtreeMode: String
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct MerkleOpeningVerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let rootHex: String
    let cpuRootHex: String?
    let proofDigestHex: String
    let cpuProofDigestHex: String?
    let siblingCount: Int
}

struct MerkleOpeningBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: MerkleOpeningBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let merkleSubtreeLeafCount: Int?
    let treeDepth: Int?
    let opening: MeasurementReport?
    let verification: MerkleOpeningVerificationReport
}

func makeDeterministicLeaves(count: Int, leafLength: Int) -> Data {
    precondition(count > 0)
    precondition(leafLength >= 0)
    guard leafLength > 0 else {
        return Data()
    }

    var bytes = [UInt8](repeating: 0, count: count * leafLength)
    for leaf in 0..<count {
        for j in 0..<leafLength {
            bytes[leaf * leafLength + j] = UInt8(truncatingIfNeeded: (leaf &* 131) &+ (j &* 17) &+ 0x5a)
        }
    }
    return Data(bytes)
}

func makeDeterministicM31Vector(count: Int, salt: UInt32) -> [UInt32] {
    precondition(count > 0)
    return (0..<count).map { index in
        let value = UInt64(index + 1) * 1_048_573
            + UInt64(salt) * 65_537
            + UInt64(index) * 17 * UInt64(salt | 1)
        return UInt32(value % UInt64(M31Field.modulus))
    }
}

func makeDeterministicNonzeroM31Vector(count: Int, salt: UInt32) -> [UInt32] {
    makeDeterministicM31Vector(count: count, salt: salt).map { value in
        value == 0 ? UInt32(1) : value
    }
}

func packUInt32LittleEndian(_ values: [UInt32]) -> Data {
    var data = Data()
    data.reserveCapacity(values.count * MemoryLayout<UInt32>.stride)
    for value in values {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }
    return data
}

func makeDeterministicKeccakF1600States(count: Int) -> Data {
    precondition(count > 0)
    var data = Data()
    data.reserveCapacity(count * KeccakF1600PermutationBatchDescriptor.stateByteCount)

    for state in 0..<count {
        for lane in 0..<25 {
            let value = UInt64(truncatingIfNeeded: state &* 0x1f1f_0101)
                ^ UInt64(truncatingIfNeeded: lane &* 0x0102_0305)
                ^ (UInt64(lane) << 40)
                ^ (UInt64(state) << 56)
            appendUInt64LittleEndian(value, to: &data)
        }
    }
    return data
}

func cpuKeccakF1600PermutationBatch(
    states: Data,
    descriptor: KeccakF1600PermutationBatchDescriptor
) throws -> Data {
    guard states.count >= descriptor.count * descriptor.inputStride,
          descriptor.inputStride >= KeccakF1600PermutationBatchDescriptor.stateByteCount,
          descriptor.outputStride >= KeccakF1600PermutationBatchDescriptor.stateByteCount,
          descriptor.inputStride.isMultiple(of: MemoryLayout<UInt64>.stride),
          descriptor.outputStride.isMultiple(of: MemoryLayout<UInt64>.stride) else {
        throw AppleZKProverError.invalidInputLayout
    }

    var output = Data(count: descriptor.count * descriptor.outputStride)
    try states.withUnsafeBytes { inputRaw in
        try output.withUnsafeMutableBytes { outputRaw in
            guard let inputBase = inputRaw.bindMemory(to: UInt8.self).baseAddress,
                  let outputBase = outputRaw.bindMemory(to: UInt8.self).baseAddress else {
                throw AppleZKProverError.invalidInputLayout
            }

            for stateIndex in 0..<descriptor.count {
                let inputOffset = stateIndex * descriptor.inputStride
                let lanes = (0..<25).map { lane in
                    readUInt64LittleEndian(inputBase.advanced(by: inputOffset + lane * MemoryLayout<UInt64>.stride))
                }
                let permuted = try SHA3Oracle.keccakF1600Permutation(lanes)
                let outputOffset = stateIndex * descriptor.outputStride
                for lane in 0..<25 {
                    storeUInt64LittleEndian(
                        permuted[lane],
                        to: outputBase.advanced(by: outputOffset + lane * MemoryLayout<UInt64>.stride)
                    )
                }
            }
        }
    }
    return output
}

func appendUInt64LittleEndian(_ value: UInt64, to data: inout Data) {
    for shift in stride(from: 0, to: 64, by: 8) {
        data.append(UInt8((value >> UInt64(shift)) & 0xff))
    }
}

func readUInt64LittleEndian(_ source: UnsafePointer<UInt8>) -> UInt64 {
    var value: UInt64 = 0
    for byteIndex in 0..<MemoryLayout<UInt64>.stride {
        value |= UInt64(source[byteIndex]) << UInt64(byteIndex * 8)
    }
    return value
}

func storeUInt64LittleEndian(_ value: UInt64, to destination: UnsafeMutablePointer<UInt8>) {
    for byteIndex in 0..<MemoryLayout<UInt64>.stride {
        destination[byteIndex] = UInt8((value >> UInt64(byteIndex * 8)) & 0xff)
    }
}

func merkleOpeningProofDigestHex(_ proof: MerkleOpeningProof) -> String {
    var encoded = Data()
    appendUInt64LittleEndian(UInt64(proof.leafIndex), to: &encoded)
    appendUInt64LittleEndian(UInt64(proof.leaf.count), to: &encoded)
    encoded.append(proof.leaf)
    appendUInt64LittleEndian(UInt64(proof.siblingHashes.count), to: &encoded)
    for sibling in proof.siblingHashes {
        appendUInt64LittleEndian(UInt64(sibling.count), to: &encoded)
        encoded.append(sibling)
    }
    appendUInt64LittleEndian(UInt64(proof.root.count), to: &encoded)
    encoded.append(proof.root)
    return SHA3Oracle.sha3_256(encoded).hexString
}

func makeSeries(_ samples: [Double]) -> SeriesReport {
    precondition(!samples.isEmpty)
    let sorted = samples.sorted()
    let median: Double
    if sorted.count.isMultiple(of: 2) {
        median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
    } else {
        median = sorted[sorted.count / 2]
    }
    let sum = samples.reduce(0, +)
    return SeriesReport(
        samples: samples,
        min: sorted[0],
        median: median,
        mean: sum / Double(samples.count),
        max: sorted[sorted.count - 1]
    )
}

func makeMeasurement(
    wallSeconds: [Double],
    gpuSeconds: [Double?],
    hashInvocations: Int,
    inputBytes: Double
) -> MeasurementReport {
    let gpuSamples = gpuSeconds.compactMap { $0 }
    let wall = makeSeries(wallSeconds)
    let gpu = gpuSamples.isEmpty ? nil : makeSeries(gpuSamples)
    let bestSeconds = gpu?.min ?? wall.min
    return MeasurementReport(
        wallSeconds: wall,
        gpuSeconds: gpu,
        bestSecondsForThroughput: bestSeconds,
        hashInvocationsPerSecond: Double(hashInvocations) / bestSeconds,
        inputBytesPerSecond: inputBytes / bestSeconds
    )
}

func makeFieldMeasurement(
    wallSeconds: [Double],
    gpuSeconds: [Double?],
    elements: Int,
    inputBytes: Double
) -> FieldMeasurementReport {
    let gpuSamples = gpuSeconds.compactMap { $0 }
    let wall = makeSeries(wallSeconds)
    let gpu = gpuSamples.isEmpty ? nil : makeSeries(gpuSamples)
    let bestSeconds = gpu?.min ?? wall.min
    return FieldMeasurementReport(
        wallSeconds: wall,
        gpuSeconds: gpu,
        bestSecondsForThroughput: bestSeconds,
        elementsPerSecond: Double(elements) / bestSeconds,
        inputBytesPerSecond: inputBytes / bestSeconds
    )
}

func iso8601Now() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
}

func printSeconds(_ label: String, _ series: SeriesReport) {
    print("  \(label) min/med/mean/max s: \(String(format: "%.6f", series.min)) / \(String(format: "%.6f", series.median)) / \(String(format: "%.6f", series.mean)) / \(String(format: "%.6f", series.max))")
}

#if canImport(Metal)
import Metal

func defaultPipelineArchiveURL(for device: MTLDevice) -> URL {
    let safeName = device.name.map { character -> Character in
        if character.isLetter || character.isNumber {
            return character
        }
        return "-"
    }
    let name = String(safeName).split(separator: "-").joined(separator: "-")
    let registryID = String(device.registryID, radix: 16)
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".build/applezkprover-pipeline-archives", isDirectory: true)
        .appendingPathComponent("\(name)-\(registryID).metalar")
}

func makeDeviceReport(_ capabilities: GPUCapabilities) -> DeviceReport {
    DeviceReport(
        name: capabilities.name,
        registryID: capabilities.registryID,
        supportsApple3: capabilities.supportsApple3,
        supportsApple4: capabilities.supportsApple4,
        supportsApple7: capabilities.supportsApple7,
        supportsApple9: capabilities.supportsApple9,
        supports64BitAtomics: capabilities.supports64BitAtomics,
        supportsSIMDReductions: capabilities.supportsSIMDReductions,
        supportsNonuniformThreadgroups: capabilities.supportsNonuniformThreadgroups,
        supportsBinaryArchives: capabilities.supportsBinaryArchives,
        maxThreadsPerThreadgroup: capabilities.maxThreadsPerThreadgroup,
        maxThreadgroupMemoryLength: capabilities.maxThreadgroupMemoryLength,
        hasUnifiedMemory: capabilities.hasUnifiedMemory
    )
}

func makeMerkleCommitPlanConfiguration(_ mode: BenchMerkleSubtreeMode) -> MerkleCommitPlanConfiguration {
    switch mode {
    case .disabled:
        return MerkleCommitPlanConfiguration(leafSubtreeMode: .disabled)
    case .automatic:
        return MerkleCommitPlanConfiguration(leafSubtreeMode: .automatic)
    case let .fixed(value):
        return MerkleCommitPlanConfiguration(leafSubtreeMode: .fixed(value))
    }
}
#endif

func emitJSON(_ report: BenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: BenchmarkSuiteReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: KeccakPermutationBenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: M31DotProductBenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: M31VectorBenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: MerkleOpeningBenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitText(_ report: BenchmarkReport) {
    print("zkmetal-bench")
    print("  leaves       : \(report.configuration.leafCount)")
    print("  leaf bytes   : \(report.configuration.leafLength)")
    print("  hash fn      : \(report.configuration.hashFunction)")
    print("  hash kernel  : \(report.configuration.hashKernelFamily)")
    if let simdgroups = report.configuration.hashSIMDGroupsPerThreadgroup {
        print("  hash simd/tg : \(simdgroups)")
    }
    print("  subtree mode : \(report.configuration.merkleSubtreeMode)")
    print("  warmups      : \(report.configuration.warmupIterations)")
    print("  iterations   : \(report.configuration.iterations)")
    print("  verify (CPU) : \(report.configuration.verifyWithCPU)")

    if let device = report.device {
        print("  device       : \(device.name)")
        print("  apple9       : \(device.supportsApple9)")
        print("  apple7       : \(device.supportsApple7)")
        print("  apple4       : \(device.supportsApple4)")
        print("  64b atomics  : \(device.supports64BitAtomics)")
        print("  SIMD reduce  : \(device.supportsSIMDReductions)")
        print("  binary arch  : \(device.supportsBinaryArchives)")
        print("  tg mem bytes : \(device.maxThreadgroupMemoryLength)")
    }

    print("  archive      : \(report.pipelineArchive.mode)")
    if let path = report.pipelineArchive.path {
        print("  archive path : \(path)")
    }
    if let limit = report.merkleFusedUpperNodeLimit {
        print("  upper fuse n : \(limit)")
    }
    if let subtree = report.merkleSubtreeLeafCount {
        print("  subtree leafs: \(subtree)")
    }

    if let hash = report.hash {
        printSeconds("hash wall", hash.wallSeconds)
        if let gpu = hash.gpuSeconds {
            printSeconds("hash gpu ", gpu)
        }
        print("  hash/sec     : \(String(format: "%.2f", hash.hashInvocationsPerSecond))")
        print("  hash input B/s: \(String(format: "%.2f", hash.inputBytesPerSecond))")
    }

    if let merkle = report.merkle {
        printSeconds("merkle wall", merkle.wallSeconds)
        if let gpu = merkle.gpuSeconds {
            printSeconds("merkle gpu ", gpu)
        }
        print("  merkle hash/sec: \(String(format: "%.2f", merkle.hashInvocationsPerSecond))")
        print("  merkle input B/s: \(String(format: "%.2f", merkle.inputBytesPerSecond))")
    }

    print("  root         : \(report.verification.rootHex)")
    if let cpuRoot = report.verification.cpuRootHex {
        print("  cpu root     : \(cpuRoot)")
    }
    if let matchedCPU = report.verification.matchedCPU {
        print("  match        : \(matchedCPU)")
    }
}

func emitText(_ report: KeccakPermutationBenchmarkReport) {
    print("zkmetal-bench keccak-f1600")
    print("  states       : \(report.configuration.stateCount)")
    print("  state bytes  : \(KeccakF1600PermutationBatchDescriptor.stateByteCount)")
    print("  state stride : \(report.configuration.stateStride)")
    print("  output stride: \(report.configuration.outputStride)")
    print("  kernel       : \(report.configuration.kernelFamily)")
    if let simdgroups = report.configuration.simdgroupsPerThreadgroup {
        print("  simd/tg      : \(simdgroups)")
    }
    print("  warmups      : \(report.configuration.warmupIterations)")
    print("  iterations   : \(report.configuration.iterations)")
    print("  verify (CPU) : \(report.configuration.verifyWithCPU)")

    if let device = report.device {
        print("  device       : \(device.name)")
        print("  apple9       : \(device.supportsApple9)")
        print("  apple7       : \(device.supportsApple7)")
        print("  apple4       : \(device.supportsApple4)")
        print("  SIMD reduce  : \(device.supportsSIMDReductions)")
        print("  binary arch  : \(device.supportsBinaryArchives)")
        print("  tg mem bytes : \(device.maxThreadgroupMemoryLength)")
    }

    print("  archive      : \(report.pipelineArchive.mode)")
    if let path = report.pipelineArchive.path {
        print("  archive path : \(path)")
    }

    if let permutation = report.permutation {
        printSeconds("perm wall", permutation.wallSeconds)
        if let gpu = permutation.gpuSeconds {
            printSeconds("perm gpu ", gpu)
        }
        print("  states/sec   : \(String(format: "%.2f", permutation.hashInvocationsPerSecond))")
        print("  state B/s    : \(String(format: "%.2f", permutation.inputBytesPerSecond))")
    }

    print("  output digest: \(report.verification.outputDigestHex)")
    if let cpuDigest = report.verification.cpuOutputDigestHex {
        print("  cpu digest   : \(cpuDigest)")
    }
    if let matchedCPU = report.verification.matchedCPU {
        print("  match        : \(matchedCPU)")
    }
}

func emitText(_ report: M31DotProductBenchmarkReport) {
    print("zkmetal-bench m31-dot-product")
    print("  elements     : \(report.configuration.elementCount)")
    if let threads = report.configuration.threadsPerThreadgroup {
        print("  threads/tg   : \(threads)")
    }
    if let elements = report.configuration.elementsPerThreadgroup {
        print("  elements/tg  : \(elements)")
    }
    print("  warmups      : \(report.configuration.warmupIterations)")
    print("  iterations   : \(report.configuration.iterations)")
    print("  verify (CPU) : \(report.configuration.verifyWithCPU)")

    if let device = report.device {
        print("  device       : \(device.name)")
        print("  apple9       : \(device.supportsApple9)")
        print("  SIMD reduce  : \(device.supportsSIMDReductions)")
        print("  binary arch  : \(device.supportsBinaryArchives)")
        print("  tg mem bytes : \(device.maxThreadgroupMemoryLength)")
    }

    print("  archive      : \(report.pipelineArchive.mode)")
    if let path = report.pipelineArchive.path {
        print("  archive path : \(path)")
    }

    if let dotProduct = report.dotProduct {
        printSeconds("dot wall", dotProduct.wallSeconds)
        if let gpu = dotProduct.gpuSeconds {
            printSeconds("dot gpu ", gpu)
        }
        print("  elements/sec : \(String(format: "%.2f", dotProduct.elementsPerSecond))")
        print("  input B/s    : \(String(format: "%.2f", dotProduct.inputBytesPerSecond))")
    }

    print("  value        : \(report.verification.value)")
    if let cpuValue = report.verification.cpuValue {
        print("  cpu value    : \(cpuValue)")
    }
    if let matchedCPU = report.verification.matchedCPU {
        print("  match        : \(matchedCPU)")
    }
}

func emitText(_ report: M31VectorBenchmarkReport) {
    print("zkmetal-bench m31-vector")
    print("  elements     : \(report.configuration.elementCount)")
    print("  operation    : \(report.configuration.operation)")
    print("  warmups      : \(report.configuration.warmupIterations)")
    print("  iterations   : \(report.configuration.iterations)")
    print("  verify (CPU) : \(report.configuration.verifyWithCPU)")

    if let device = report.device {
        print("  device       : \(device.name)")
        print("  apple9       : \(device.supportsApple9)")
        print("  binary arch  : \(device.supportsBinaryArchives)")
        print("  tg mem bytes : \(device.maxThreadgroupMemoryLength)")
    }

    print("  archive      : \(report.pipelineArchive.mode)")
    if let path = report.pipelineArchive.path {
        print("  archive path : \(path)")
    }

    if let vector = report.vector {
        printSeconds("vec wall", vector.wallSeconds)
        if let gpu = vector.gpuSeconds {
            printSeconds("vec gpu ", gpu)
        }
        print("  elements/sec : \(String(format: "%.2f", vector.elementsPerSecond))")
        print("  input B/s    : \(String(format: "%.2f", vector.inputBytesPerSecond))")
    }

    print("  output digest: \(report.verification.outputDigestHex)")
    if let cpuDigest = report.verification.cpuOutputDigestHex {
        print("  cpu digest   : \(cpuDigest)")
    }
    if let matchedCPU = report.verification.matchedCPU {
        print("  match        : \(matchedCPU)")
    }
}

func emitText(_ report: MerkleOpeningBenchmarkReport) {
    print("zkmetal-bench merkle-opening")
    print("  leaves       : \(report.configuration.leafCount)")
    print("  leaf bytes   : \(report.configuration.leafLength)")
    print("  leaf index   : \(report.configuration.leafIndex)")
    print("  subtree mode : \(report.configuration.merkleSubtreeMode)")
    if let subtree = report.merkleSubtreeLeafCount {
        print("  subtree leafs: \(subtree)")
    }
    if let treeDepth = report.treeDepth {
        print("  tree depth   : \(treeDepth)")
    }
    print("  warmups      : \(report.configuration.warmupIterations)")
    print("  iterations   : \(report.configuration.iterations)")
    print("  verify (CPU) : \(report.configuration.verifyWithCPU)")

    if let device = report.device {
        print("  device       : \(device.name)")
        print("  apple9       : \(device.supportsApple9)")
        print("  binary arch  : \(device.supportsBinaryArchives)")
        print("  tg mem bytes : \(device.maxThreadgroupMemoryLength)")
    }

    print("  archive      : \(report.pipelineArchive.mode)")
    if let path = report.pipelineArchive.path {
        print("  archive path : \(path)")
    }

    if let opening = report.opening {
        printSeconds("open wall", opening.wallSeconds)
        if let gpu = opening.gpuSeconds {
            printSeconds("open gpu ", gpu)
        }
        print("  openings/sec : \(String(format: "%.2f", opening.hashInvocationsPerSecond))")
        print("  input B/s    : \(String(format: "%.2f", opening.inputBytesPerSecond))")
    }

    print("  siblings     : \(report.verification.siblingCount)")
    print("  root         : \(report.verification.rootHex)")
    if let cpuRoot = report.verification.cpuRootHex {
        print("  cpu root     : \(cpuRoot)")
    }
    print("  proof digest : \(report.verification.proofDigestHex)")
    if let cpuProof = report.verification.cpuProofDigestHex {
        print("  cpu proof    : \(cpuProof)")
    }
    if let matchedCPU = report.verification.matchedCPU {
        print("  match        : \(matchedCPU)")
    }
}

func emitText(_ suite: BenchmarkSuiteReport) {
    print("zkmetal-bench suite")
    print("  leaves       : \(suite.configuration.leafCount)")
    print("  leaf bytes   : \(suite.configuration.leafLengths.map(String.init).joined(separator: ","))")
    print("  hash fns     : \(suite.configuration.hashFunctions.joined(separator: ","))")
    print("  hash kernel  : \(suite.configuration.hashKernelFamily)")
    if let simdgroups = suite.configuration.hashSIMDGroupsPerThreadgroup {
        print("  hash simd/tg : \(simdgroups)")
    }
    print("  subtree mode : \(suite.configuration.merkleSubtreeMode)")
    print("  warmups      : \(suite.configuration.warmupIterations)")
    print("  iterations   : \(suite.configuration.iterations)")
    print("  verify (CPU) : \(suite.configuration.verifyWithCPU)")
    print("  target       : \(suite.target)")
    print("  reports      : \(suite.reports.count)")

    for report in suite.reports {
        let matchedCPU = report.verification.matchedCPU.map(String.init) ?? "n/a"
        let hashWall = report.hash.map { String(format: "%.6f", $0.wallSeconds.min) } ?? "n/a"
        let merkleWall = report.merkle.map { String(format: "%.6f", $0.wallSeconds.min) } ?? "n/a"
        print("  - \(report.configuration.hashFunction) leaf=\(report.configuration.leafLength) target=\(report.target) hash_min_s=\(hashWall) merkle_min_s=\(merkleWall) match=\(matchedCPU)")
    }
}

func suiteTarget(for reports: [BenchmarkReport]) -> String {
    let targets = Set(reports.map(\.target))
    if targets.count == 1, let target = targets.first {
        return target
    }
    return targets.sorted().joined(separator: "+")
}

func makeSuiteReport(config: BenchConfig, reports: [BenchmarkReport]) -> BenchmarkSuiteReport {
    BenchmarkSuiteReport(
        schemaVersion: 4,
        generatedAt: iso8601Now(),
        target: suiteTarget(for: reports),
        configuration: BenchmarkSuiteConfigReport(
            leafCount: config.leafCount,
            leafLengths: config.suiteLeafLengths,
            hashFunctions: config.suiteHashFunctions.map(\.rawValue),
            hashKernelFamily: config.hashKernelFamily.rawValue,
            hashSIMDGroupsPerThreadgroup: config.hashKernelFamily == .simdgroup
                ? config.hashSIMDGroupsPerThreadgroup
                : nil,
            merkleSubtreeMode: merkleSubtreeModeDescription(config.merkleSubtreeMode),
            warmupIterations: config.warmupIterations,
            iterations: config.iterations,
            verifyWithCPU: config.verifyWithCPU
        ),
        reports: reports
    )
}

func makeSuiteConfigs(_ config: BenchConfig) -> [BenchConfig] {
    var configs: [BenchConfig] = []
    for leafLength in config.suiteLeafLengths {
        for hashFunction in config.suiteHashFunctions {
            var child = config
            child.suite = false
            child.leafLength = leafLength
            child.hashFunction = hashFunction
            configs.append(child)
        }
    }
    return configs
}

func verificationFailureMessages(in report: BenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true else {
        let cpuRoot = report.verification.cpuRootHex ?? "missing"
        let simdgroups = report.configuration.hashSIMDGroupsPerThreadgroup.map { " simdgroups/tg=\($0)" } ?? ""
        return [
            "\(report.configuration.hashFunction) kernel=\(report.configuration.hashKernelFamily)\(simdgroups) leaf-bytes=\(report.configuration.leafLength) target=\(report.target) root=\(report.verification.rootHex) cpu-root=\(cpuRoot)",
        ]
    }
    return []
}

func verificationFailureMessages(in suite: BenchmarkSuiteReport) -> [String] {
    suite.reports.flatMap { verificationFailureMessages(in: $0) }
}

func verificationFailureMessages(in report: MerkleOpeningBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true else {
        let cpuRoot = report.verification.cpuRootHex ?? "missing"
        let cpuProof = report.verification.cpuProofDigestHex ?? "missing"
        return [
            "merkle-opening leaf-bytes=\(report.configuration.leafLength) leaf-index=\(report.configuration.leafIndex) target=\(report.target) root=\(report.verification.rootHex) cpu-root=\(cpuRoot) proof=\(report.verification.proofDigestHex) cpu-proof=\(cpuProof)",
        ]
    }
    return []
}

func verificationFailureMessages(in report: M31DotProductBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true else {
        let cpuValue = report.verification.cpuValue.map(String.init) ?? "missing"
        return [
            "m31-dot-product elements=\(report.configuration.elementCount) target=\(report.target) value=\(report.verification.value) cpu-value=\(cpuValue)",
        ]
    }
    return []
}

func verificationFailureMessages(in report: M31VectorBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true else {
        let cpuDigest = report.verification.cpuOutputDigestHex ?? "missing"
        return [
            "m31-vector operation=\(report.configuration.operation) elements=\(report.configuration.elementCount) target=\(report.target) digest=\(report.verification.outputDigestHex) cpu-digest=\(cpuDigest)",
        ]
    }
    return []
}

func makeBenchmarkConfigReport(
    config: BenchConfig,
    effectiveSIMDGroupsPerThreadgroup: Int?
) -> BenchmarkConfigReport {
    BenchmarkConfigReport(
        leafCount: config.leafCount,
        leafLength: config.leafLength,
        leafStride: config.leafLength,
        hashFunction: config.hashFunction.rawValue,
        hashKernelFamily: config.hashKernelFamily.rawValue,
        hashSIMDGroupsPerThreadgroup: effectiveSIMDGroupsPerThreadgroup,
        merkleSubtreeMode: merkleSubtreeModeDescription(config.merkleSubtreeMode),
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

func makeM31VectorConfigReport(
    config: BenchConfig,
    operation: M31VectorOperation
) -> M31VectorBenchmarkConfigReport {
    M31VectorBenchmarkConfigReport(
        elementCount: config.leafCount,
        operation: m31VectorOperationName(operation),
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

func m31VectorOperationName(_ operation: M31VectorOperation) -> String {
    switch operation {
    case .add:
        return "add"
    case .subtract:
        return "subtract"
    case .negate:
        return "negate"
    case .multiply:
        return "multiply"
    case .square:
        return "square"
    case .inverse:
        return "inverse"
    }
}

func makeM31DotProductConfigReport(
    config: BenchConfig,
    threadsPerThreadgroup: Int?,
    elementsPerThreadgroup: Int?
) -> M31DotProductBenchmarkConfigReport {
    M31DotProductBenchmarkConfigReport(
        elementCount: config.leafCount,
        threadsPerThreadgroup: threadsPerThreadgroup,
        elementsPerThreadgroup: elementsPerThreadgroup,
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

func makeMerkleOpeningConfigReport(config: BenchConfig) -> MerkleOpeningBenchmarkConfigReport {
    MerkleOpeningBenchmarkConfigReport(
        leafCount: config.leafCount,
        leafLength: config.leafLength,
        leafStride: config.leafLength,
        leafIndex: config.openingLeafIndex,
        merkleSubtreeMode: merkleSubtreeModeDescription(config.merkleSubtreeMode),
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

@inline(never)
func runM31VectorInverseBenchmark(_ config: BenchConfig) throws -> M31VectorBenchmarkReport {
    let operation = M31VectorOperation.inverse
    let input = makeDeterministicNonzeroM31Vector(count: config.leafCount, salt: 0x91)
    let configReport = makeM31VectorConfigReport(config: config, operation: operation)

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let cpuOutput = try M31Field.batchInverse(input)
        let digest = SHA3Oracle.sha3_256(packUInt32LittleEndian(cpuOutput)).hexString
        return M31VectorBenchmarkReport(
            schemaVersion: 1,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: configReport,
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            vector: nil,
            verification: M31VectorVerificationReport(
                enabled: true,
                matchedCPU: true,
                outputDigestHex: digest,
                cpuOutputDigestHex: digest
            )
        )
    }

    let archiveURL = config.pipelineArchiveURL ?? defaultPipelineArchiveURL(for: device)
    let pipelineCacheConfiguration = config.usePipelineArchive
        ? MetalPipelineCacheConfiguration(binaryArchiveMode: .readWrite(archiveURL))
        : .disabled
    let context = try MetalContext(device: device, pipelineCacheConfiguration: pipelineCacheConfiguration)
    let plan = try M31VectorArithmeticPlan(context: context, operation: operation, count: config.leafCount)
    try context.serializePipelineArchiveIfNeeded()

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try plan.execute(lhs: input)
        }
    }

    var wallSeconds: [Double] = []
    var gpuSeconds: [Double?] = []
    var output: [UInt32] = []
    for _ in 0..<config.iterations {
        let result = try plan.execute(lhs: input)
        wallSeconds.append(result.stats.cpuWallSeconds)
        gpuSeconds.append(result.stats.gpuSeconds)
        output = result.values
    }

    let cpuOutput = config.verifyWithCPU ? try M31Field.batchInverse(input) : nil
    let matchedCPU = cpuOutput.map { $0 == output }
    let outputDigest = SHA3Oracle.sha3_256(packUInt32LittleEndian(output)).hexString
    let cpuOutputDigest = cpuOutput.map { SHA3Oracle.sha3_256(packUInt32LittleEndian($0)).hexString }
    return M31VectorBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "metal",
        configuration: configReport,
        device: makeDeviceReport(context.capabilities),
        pipelineArchive: PipelineArchiveReport(
            enabled: config.usePipelineArchive,
            mode: config.usePipelineArchive ? "readWrite" : "disabled",
            path: config.usePipelineArchive ? archiveURL.path : nil
        ),
        vector: makeFieldMeasurement(
            wallSeconds: wallSeconds,
            gpuSeconds: gpuSeconds,
            elements: config.leafCount,
            inputBytes: Double(config.leafCount) * Double(MemoryLayout<UInt32>.stride)
        ),
        verification: M31VectorVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            outputDigestHex: outputDigest,
            cpuOutputDigestHex: cpuOutputDigest
        )
    )
    #else
    let cpuOutput = try M31Field.batchInverse(input)
    let digest = SHA3Oracle.sha3_256(packUInt32LittleEndian(cpuOutput)).hexString
    return M31VectorBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: configReport,
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        vector: nil,
        verification: M31VectorVerificationReport(
            enabled: true,
            matchedCPU: true,
            outputDigestHex: digest,
            cpuOutputDigestHex: digest
        )
    )
    #endif
}

@inline(never)
func runM31DotProductBenchmark(_ config: BenchConfig) throws -> M31DotProductBenchmarkReport {
    let lhs = makeDeterministicM31Vector(count: config.leafCount, salt: 0x31)
    let rhs = makeDeterministicM31Vector(count: config.leafCount, salt: 0x71)

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let cpuValue = try M31Field.dotProduct(lhs: lhs, rhs: rhs)
        return M31DotProductBenchmarkReport(
            schemaVersion: 1,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: makeM31DotProductConfigReport(
                config: config,
                threadsPerThreadgroup: nil,
                elementsPerThreadgroup: nil
            ),
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            dotProduct: nil,
            verification: M31DotProductVerificationReport(
                enabled: true,
                matchedCPU: true,
                value: cpuValue,
                cpuValue: cpuValue
            )
        )
    }

    let archiveURL = config.pipelineArchiveURL ?? defaultPipelineArchiveURL(for: device)
    let pipelineCacheConfiguration = config.usePipelineArchive
        ? MetalPipelineCacheConfiguration(binaryArchiveMode: .readWrite(archiveURL))
        : .disabled
    let context = try MetalContext(device: device, pipelineCacheConfiguration: pipelineCacheConfiguration)
    let plan = try M31DotProductPlan(context: context, count: config.leafCount)
    let configReport = makeM31DotProductConfigReport(
        config: config,
        threadsPerThreadgroup: plan.threadsPerThreadgroup,
        elementsPerThreadgroup: plan.elementsPerThreadgroup
    )
    try context.serializePipelineArchiveIfNeeded()

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try plan.execute(lhs: lhs, rhs: rhs)
        }
    }

    var wallSeconds: [Double] = []
    var gpuSeconds: [Double?] = []
    var value: UInt32 = 0
    for _ in 0..<config.iterations {
        let result = try plan.execute(lhs: lhs, rhs: rhs)
        wallSeconds.append(result.stats.cpuWallSeconds)
        gpuSeconds.append(result.stats.gpuSeconds)
        value = result.value
    }

    let cpuValue = config.verifyWithCPU ? try M31Field.dotProduct(lhs: lhs, rhs: rhs) : nil
    let matchedCPU = cpuValue.map { $0 == value }
    let inputBytes = Double(config.leafCount) * Double(2 * MemoryLayout<UInt32>.stride)
    return M31DotProductBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "metal",
        configuration: configReport,
        device: makeDeviceReport(context.capabilities),
        pipelineArchive: PipelineArchiveReport(
            enabled: config.usePipelineArchive,
            mode: config.usePipelineArchive ? "readWrite" : "disabled",
            path: config.usePipelineArchive ? archiveURL.path : nil
        ),
        dotProduct: makeFieldMeasurement(
            wallSeconds: wallSeconds,
            gpuSeconds: gpuSeconds,
            elements: config.leafCount,
            inputBytes: inputBytes
        ),
        verification: M31DotProductVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            value: value,
            cpuValue: cpuValue
        )
    )
    #else
    let cpuValue = try M31Field.dotProduct(lhs: lhs, rhs: rhs)
    return M31DotProductBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: makeM31DotProductConfigReport(
            config: config,
            threadsPerThreadgroup: nil,
            elementsPerThreadgroup: nil
        ),
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        dotProduct: nil,
        verification: M31DotProductVerificationReport(
            enabled: true,
            matchedCPU: true,
            value: cpuValue,
            cpuValue: cpuValue
        )
    )
    #endif
}

@inline(never)
func runMerkleOpeningBenchmark(_ config: BenchConfig) throws -> MerkleOpeningBenchmarkReport {
    let leaves = makeDeterministicLeaves(count: config.leafCount, leafLength: config.leafLength)
    let configReport = makeMerkleOpeningConfigReport(config: config)

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let cpuOpening = try MerkleOracle.openingSHA3_256(
            rawLeaves: leaves,
            leafCount: config.leafCount,
            leafStride: config.leafLength,
            leafLength: config.leafLength,
            leafIndex: config.openingLeafIndex
        )
        return MerkleOpeningBenchmarkReport(
            schemaVersion: 1,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: configReport,
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            merkleSubtreeLeafCount: nil,
            treeDepth: cpuOpening.siblingHashes.count,
            opening: nil,
            verification: MerkleOpeningVerificationReport(
                enabled: true,
                matchedCPU: true,
                rootHex: cpuOpening.root.hexString,
                cpuRootHex: cpuOpening.root.hexString,
                proofDigestHex: merkleOpeningProofDigestHex(cpuOpening),
                cpuProofDigestHex: merkleOpeningProofDigestHex(cpuOpening),
                siblingCount: cpuOpening.siblingHashes.count
            )
        )
    }

    let archiveURL = config.pipelineArchiveURL ?? defaultPipelineArchiveURL(for: device)
    let pipelineCacheConfiguration = config.usePipelineArchive
        ? MetalPipelineCacheConfiguration(binaryArchiveMode: .readWrite(archiveURL))
        : .disabled
    let context = try MetalContext(device: device, pipelineCacheConfiguration: pipelineCacheConfiguration)
    let committer = SHA3MerkleCommitter(context: context)
    let plan = try committer.makeRawLeavesCommitPlan(
        leafCount: config.leafCount,
        leafStride: config.leafLength,
        leafLength: config.leafLength,
        configuration: makeMerkleCommitPlanConfiguration(config.merkleSubtreeMode)
    )
    try context.serializePipelineArchiveIfNeeded()

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try plan.openRawLeaf(leaves: leaves, leafIndex: config.openingLeafIndex)
        }
    }

    var openingWallSeconds: [Double] = []
    var openingGPUSeconds: [Double?] = []
    var opening: MerkleOpening?
    for _ in 0..<config.iterations {
        let result = try plan.openRawLeaf(leaves: leaves, leafIndex: config.openingLeafIndex)
        openingWallSeconds.append(result.stats.cpuWallSeconds)
        openingGPUSeconds.append(result.stats.gpuSeconds)
        opening = result
    }

    guard let opening else {
        throw BenchError.invalidArgument("--iterations must be greater than zero.")
    }
    let cpuOpening = config.verifyWithCPU
        ? try MerkleOracle.openingSHA3_256(
            rawLeaves: leaves,
            leafCount: config.leafCount,
            leafStride: config.leafLength,
            leafLength: config.leafLength,
            leafIndex: config.openingLeafIndex
        )
        : nil
    let matchedCPU = try cpuOpening.map { cpuProof in
        guard opening.proof == cpuProof else {
            return false
        }
        return try MerkleOracle.verifySHA3_256(opening: opening.proof)
    }
    let merkleHashInvocations = config.leafCount + config.leafCount - 1
    let merkleInputBytes = Double(config.leafCount) * Double(config.leafLength)
        + Double(config.leafCount - 1) * 64
        + Double(opening.proof.siblingHashes.count) * 32
    return MerkleOpeningBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "metal",
        configuration: configReport,
        device: makeDeviceReport(context.capabilities),
        pipelineArchive: PipelineArchiveReport(
            enabled: config.usePipelineArchive,
            mode: config.usePipelineArchive ? "readWrite" : "disabled",
            path: config.usePipelineArchive ? archiveURL.path : nil
        ),
        merkleSubtreeLeafCount: plan.subtreeLeafCount,
        treeDepth: plan.treeDepth,
        opening: makeMeasurement(
            wallSeconds: openingWallSeconds,
            gpuSeconds: openingGPUSeconds,
            hashInvocations: merkleHashInvocations,
            inputBytes: merkleInputBytes
        ),
        verification: MerkleOpeningVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            rootHex: opening.proof.root.hexString,
            cpuRootHex: cpuOpening?.root.hexString,
            proofDigestHex: merkleOpeningProofDigestHex(opening.proof),
            cpuProofDigestHex: cpuOpening.map { merkleOpeningProofDigestHex($0) },
            siblingCount: opening.proof.siblingHashes.count
        )
    )
    #else
    let cpuOpening = try MerkleOracle.openingSHA3_256(
        rawLeaves: leaves,
        leafCount: config.leafCount,
        leafStride: config.leafLength,
        leafLength: config.leafLength,
        leafIndex: config.openingLeafIndex
    )
    return MerkleOpeningBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: configReport,
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        merkleSubtreeLeafCount: nil,
        treeDepth: cpuOpening.siblingHashes.count,
        opening: nil,
        verification: MerkleOpeningVerificationReport(
            enabled: true,
            matchedCPU: true,
            rootHex: cpuOpening.root.hexString,
            cpuRootHex: cpuOpening.root.hexString,
            proofDigestHex: merkleOpeningProofDigestHex(cpuOpening),
            cpuProofDigestHex: merkleOpeningProofDigestHex(cpuOpening),
            siblingCount: cpuOpening.siblingHashes.count
        )
    )
    #endif
}

@inline(never)
func runBenchmark(_ config: BenchConfig) throws -> BenchmarkReport {
    let leaves = makeDeterministicLeaves(count: config.leafCount, leafLength: config.leafLength)

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let configReport = makeBenchmarkConfigReport(
            config: config,
            effectiveSIMDGroupsPerThreadgroup: nil
        )
        let cpuRoot = try MerkleOracle.rootSHA3_256(
            rawLeaves: leaves,
            leafCount: config.leafCount,
            leafStride: config.leafLength,
            leafLength: config.leafLength
        )
        let report = BenchmarkReport(
            schemaVersion: 4,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: configReport,
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            merkleFusedUpperNodeLimit: nil,
            merkleSubtreeLeafCount: nil,
            hash: nil,
            merkle: nil,
            verification: VerificationReport(enabled: true, matchedCPU: true, rootHex: cpuRoot.hexString, cpuRootHex: cpuRoot.hexString)
        )
        return report
    }

    let archiveURL = config.pipelineArchiveURL ?? defaultPipelineArchiveURL(for: device)
    let pipelineCacheConfiguration = config.usePipelineArchive
        ? MetalPipelineCacheConfiguration(binaryArchiveMode: .readWrite(archiveURL))
        : .disabled
    let context = try MetalContext(device: device, pipelineCacheConfiguration: pipelineCacheConfiguration)
    let committer = SHA3MerkleCommitter(context: context)
    let descriptor = FixedMessageBatchDescriptor(
        count: config.leafCount,
        messageStride: config.leafLength,
        messageLength: config.leafLength,
        outputStride: 32
    )
    let runHash: () throws -> GPUHashBatchResult
    let effectiveSIMDGroupsPerThreadgroup: Int?
    switch config.hashFunction {
    case .sha3_256:
        let hasher = SHA3BatchHasher(context: context)
        let hashPlan = try hasher.makeFixedOneBlockPlan(
            descriptor: descriptor,
            kernelFamily: config.hashKernelFamily,
            simdgroupsPerThreadgroup: config.hashKernelFamily == .simdgroup
                ? config.hashSIMDGroupsPerThreadgroup
                : nil
        )
        effectiveSIMDGroupsPerThreadgroup = config.hashKernelFamily == .simdgroup
            ? hashPlan.simdgroupsPerThreadgroup
            : nil
        runHash = {
            try hashPlan.hash(messages: leaves)
        }
    case .keccak_256:
        let hasher = Keccak256BatchHasher(context: context)
        let hashPlan = try hasher.makeFixedOneBlockPlan(
            descriptor: descriptor,
            kernelFamily: config.hashKernelFamily,
            simdgroupsPerThreadgroup: config.hashKernelFamily == .simdgroup
                ? config.hashSIMDGroupsPerThreadgroup
                : nil
        )
        effectiveSIMDGroupsPerThreadgroup = config.hashKernelFamily == .simdgroup
            ? hashPlan.simdgroupsPerThreadgroup
            : nil
        runHash = {
            try hashPlan.hash(messages: leaves)
        }
    }
    let configReport = makeBenchmarkConfigReport(
        config: config,
        effectiveSIMDGroupsPerThreadgroup: effectiveSIMDGroupsPerThreadgroup
    )
    let merklePlan = try committer.makeRawLeavesCommitPlan(
        leafCount: config.leafCount,
        leafStride: config.leafLength,
        leafLength: config.leafLength,
        configuration: makeMerkleCommitPlanConfiguration(config.merkleSubtreeMode)
    )
    try context.serializePipelineArchiveIfNeeded()

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try runHash()
            _ = try merklePlan.commit(leaves: leaves)
        }
    }

    var hashWallSeconds: [Double] = []
    var hashGPUSeconds: [Double?] = []
    var merkleWallSeconds: [Double] = []
    var merkleGPUSeconds: [Double?] = []
    var root = Data()

    for _ in 0..<config.iterations {
        let hashResult = try runHash()
        hashWallSeconds.append(hashResult.stats.cpuWallSeconds)
        hashGPUSeconds.append(hashResult.stats.gpuSeconds)

        let commitment = try merklePlan.commit(leaves: leaves)
        merkleWallSeconds.append(commitment.stats.cpuWallSeconds)
        merkleGPUSeconds.append(commitment.stats.gpuSeconds)
        root = commitment.root
    }

    let cpuRoot = config.verifyWithCPU
        ? try MerkleOracle.rootSHA3_256(rawLeaves: leaves, leafCount: config.leafCount, leafStride: config.leafLength, leafLength: config.leafLength)
        : nil
    let matchedCPU = cpuRoot.map { $0 == root }
    let hashInputBytes = Double(config.leafCount) * Double(config.leafLength)
    let merkleHashInvocations = config.leafCount + config.leafCount - 1
    let merkleInputBytes = hashInputBytes + Double(config.leafCount - 1) * 64
    let report = BenchmarkReport(
        schemaVersion: 4,
        generatedAt: iso8601Now(),
        target: "metal",
        configuration: configReport,
        device: makeDeviceReport(context.capabilities),
        pipelineArchive: PipelineArchiveReport(
            enabled: config.usePipelineArchive,
            mode: config.usePipelineArchive ? "readWrite" : "disabled",
            path: config.usePipelineArchive ? archiveURL.path : nil
        ),
        merkleFusedUpperNodeLimit: merklePlan.fusedUpperNodeLimit,
        merkleSubtreeLeafCount: merklePlan.subtreeLeafCount,
        hash: makeMeasurement(
            wallSeconds: hashWallSeconds,
            gpuSeconds: hashGPUSeconds,
            hashInvocations: config.leafCount,
            inputBytes: hashInputBytes
        ),
        merkle: makeMeasurement(
            wallSeconds: merkleWallSeconds,
            gpuSeconds: merkleGPUSeconds,
            hashInvocations: merkleHashInvocations,
            inputBytes: merkleInputBytes
        ),
        verification: VerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            rootHex: root.hexString,
            cpuRootHex: cpuRoot?.hexString
        )
    )

    return report
    #else
    let configReport = makeBenchmarkConfigReport(
        config: config,
        effectiveSIMDGroupsPerThreadgroup: nil
    )
    let cpuRoot = try MerkleOracle.rootSHA3_256(
        rawLeaves: leaves,
        leafCount: config.leafCount,
        leafStride: config.leafLength,
        leafLength: config.leafLength
    )
    let report = BenchmarkReport(
        schemaVersion: 4,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: configReport,
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        merkleFusedUpperNodeLimit: nil,
        merkleSubtreeLeafCount: nil,
        hash: nil,
        merkle: nil,
        verification: VerificationReport(enabled: true, matchedCPU: true, rootHex: cpuRoot.hexString, cpuRootHex: cpuRoot.hexString)
    )
    return report
    #endif
}

func makeKeccakPermutationConfigReport(
    config: BenchConfig,
    descriptor: KeccakF1600PermutationBatchDescriptor,
    effectiveSIMDGroupsPerThreadgroup: Int?
) -> KeccakPermutationBenchmarkConfigReport {
    KeccakPermutationBenchmarkConfigReport(
        stateCount: descriptor.count,
        stateStride: descriptor.inputStride,
        outputStride: descriptor.outputStride,
        kernelFamily: config.permutationKernelFamily.rawValue,
        simdgroupsPerThreadgroup: effectiveSIMDGroupsPerThreadgroup,
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

@inline(never)
func runKeccakPermutationBenchmark(_ config: BenchConfig) throws -> KeccakPermutationBenchmarkReport {
    let descriptor = KeccakF1600PermutationBatchDescriptor(count: config.leafCount)
    let states = makeDeterministicKeccakF1600States(count: descriptor.count)

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let cpuOutput = try cpuKeccakF1600PermutationBatch(states: states, descriptor: descriptor)
        let digest = SHA3Oracle.sha3_256(cpuOutput).hexString
        return KeccakPermutationBenchmarkReport(
            schemaVersion: 1,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: makeKeccakPermutationConfigReport(
                config: config,
                descriptor: descriptor,
                effectiveSIMDGroupsPerThreadgroup: nil
            ),
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            permutation: nil,
            verification: KeccakPermutationVerificationReport(
                enabled: true,
                matchedCPU: true,
                outputDigestHex: digest,
                cpuOutputDigestHex: digest
            )
        )
    }

    let archiveURL = config.pipelineArchiveURL ?? defaultPipelineArchiveURL(for: device)
    let pipelineCacheConfiguration = config.usePipelineArchive
        ? MetalPipelineCacheConfiguration(binaryArchiveMode: .readWrite(archiveURL))
        : .disabled
    let context = try MetalContext(device: device, pipelineCacheConfiguration: pipelineCacheConfiguration)
    let batcher = KeccakF1600PermutationBatcher(context: context)
    let plan = try batcher.makePermutationPlan(
        descriptor: descriptor,
        kernelFamily: config.permutationKernelFamily,
        simdgroupsPerThreadgroup: config.permutationKernelFamily == .simdgroup
            ? config.permutationSIMDGroupsPerThreadgroup
            : nil
    )
    let effectiveSIMDGroupsPerThreadgroup = config.permutationKernelFamily == .simdgroup
        ? plan.simdgroupsPerThreadgroup
        : nil
    try context.serializePipelineArchiveIfNeeded()

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try plan.permute(states: states)
        }
    }

    var wallSeconds: [Double] = []
    var gpuSeconds: [Double?] = []
    var output = Data()

    for _ in 0..<config.iterations {
        let result = try plan.permute(states: states)
        wallSeconds.append(result.stats.cpuWallSeconds)
        gpuSeconds.append(result.stats.gpuSeconds)
        output = result.states
    }

    let cpuOutput = config.verifyWithCPU
        ? try cpuKeccakF1600PermutationBatch(states: states, descriptor: descriptor)
        : nil
    let matchedCPU = cpuOutput.map { $0 == output }
    let outputDigest = SHA3Oracle.sha3_256(output).hexString
    let cpuOutputDigest = cpuOutput.map { SHA3Oracle.sha3_256($0).hexString }

    return KeccakPermutationBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "metal",
        configuration: makeKeccakPermutationConfigReport(
            config: config,
            descriptor: descriptor,
            effectiveSIMDGroupsPerThreadgroup: effectiveSIMDGroupsPerThreadgroup
        ),
        device: makeDeviceReport(context.capabilities),
        pipelineArchive: PipelineArchiveReport(
            enabled: config.usePipelineArchive,
            mode: config.usePipelineArchive ? "readWrite" : "disabled",
            path: config.usePipelineArchive ? archiveURL.path : nil
        ),
        permutation: makeMeasurement(
            wallSeconds: wallSeconds,
            gpuSeconds: gpuSeconds,
            hashInvocations: descriptor.count,
            inputBytes: Double(descriptor.count) * Double(KeccakF1600PermutationBatchDescriptor.stateByteCount)
        ),
        verification: KeccakPermutationVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            outputDigestHex: outputDigest,
            cpuOutputDigestHex: cpuOutputDigest
        )
    )
    #else
    let cpuOutput = try cpuKeccakF1600PermutationBatch(states: states, descriptor: descriptor)
    let digest = SHA3Oracle.sha3_256(cpuOutput).hexString
    return KeccakPermutationBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: makeKeccakPermutationConfigReport(
            config: config,
            descriptor: descriptor,
            effectiveSIMDGroupsPerThreadgroup: nil
        ),
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        permutation: nil,
        verification: KeccakPermutationVerificationReport(
            enabled: true,
            matchedCPU: true,
            outputDigestHex: digest,
            cpuOutputDigestHex: digest
        )
    )
    #endif
}

func verificationFailureMessages(in report: KeccakPermutationBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true else {
        let cpuDigest = report.verification.cpuOutputDigestHex ?? "missing"
        let simdgroups = report.configuration.simdgroupsPerThreadgroup.map { " simdgroups/tg=\($0)" } ?? ""
        return [
            "keccak-f1600 kernel=\(report.configuration.kernelFamily)\(simdgroups) states=\(report.configuration.stateCount) target=\(report.target) digest=\(report.verification.outputDigestHex) cpu-digest=\(cpuDigest)",
        ]
    }
    return []
}

@inline(never)
func runCLI() -> Int32 {
    do {
        let config: BenchConfig
        switch BenchConfig.parse(arguments: CommandLine.arguments) {
        case let .success(parsed):
            config = parsed
        case .failure(.helpRequested):
            print(BenchConfig.usage)
            return 0
        case let .failure(error):
            fputs("error: \(error.localizedDescription)\n\n\(BenchConfig.usage)\n", stderr)
            return 1
        }
        if config.keccakF1600Permutation {
            let report = try runKeccakPermutationBenchmark(config)
            if config.format == .json {
                try emitJSON(report)
            } else {
                emitText(report)
            }
            let failures = verificationFailureMessages(in: report)
            if !failures.isEmpty {
                for message in failures {
                    fputs("verification failure: \(message)\n", stderr)
                }
                return verificationFailureExitCode
            }
        } else if config.m31DotProduct {
            let report = try runM31DotProductBenchmark(config)
            if config.format == .json {
                try emitJSON(report)
            } else {
                emitText(report)
            }
            let failures = verificationFailureMessages(in: report)
            if !failures.isEmpty {
                for message in failures {
                    fputs("verification failure: \(message)\n", stderr)
                }
                return verificationFailureExitCode
            }
        } else if config.m31VectorInverse {
            let report = try runM31VectorInverseBenchmark(config)
            if config.format == .json {
                try emitJSON(report)
            } else {
                emitText(report)
            }
            let failures = verificationFailureMessages(in: report)
            if !failures.isEmpty {
                for message in failures {
                    fputs("verification failure: \(message)\n", stderr)
                }
                return verificationFailureExitCode
            }
        } else if config.merkleOpening {
            let report = try runMerkleOpeningBenchmark(config)
            if config.format == .json {
                try emitJSON(report)
            } else {
                emitText(report)
            }
            let failures = verificationFailureMessages(in: report)
            if !failures.isEmpty {
                for message in failures {
                    fputs("verification failure: \(message)\n", stderr)
                }
                return verificationFailureExitCode
            }
        } else if config.suite {
            let reports = try makeSuiteConfigs(config).map { try runBenchmark($0) }
            let suite = makeSuiteReport(config: config, reports: reports)
            if config.format == .json {
                try emitJSON(suite)
            } else {
                emitText(suite)
            }
            let failures = verificationFailureMessages(in: suite)
            if !failures.isEmpty {
                for message in failures {
                    fputs("verification failure: \(message)\n", stderr)
                }
                return verificationFailureExitCode
            }
        } else {
            let report = try runBenchmark(config)
            if config.format == .json {
                try emitJSON(report)
            } else {
                emitText(report)
            }
            let failures = verificationFailureMessages(in: report)
            if !failures.isEmpty {
                for message in failures {
                    fputs("verification failure: \(message)\n", stderr)
                }
                return verificationFailureExitCode
            }
        }
        return 0
    } catch {
        fputs("error: \(error.localizedDescription)\n\n\(BenchConfig.usage)\n", stderr)
        return 1
    }
}

exit(runCLI())
