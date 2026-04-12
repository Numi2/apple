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
    var merkleSubtreeMode: BenchMerkleSubtreeMode = .disabled
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
          --json                     Shortcut for --format json
          --suite                    Run the supported benchmark matrix
          --suite-leaf-bytes LIST    Comma-separated suite leaf lengths. Default: 0,32,64,128,135,136
          --suite-hashes LIST        Comma-separated suite hash functions. Default: sha3-256,keccak-256
          --verify / --no-verify     Enable or disable CPU root check. Default: verify
          --pipeline-archive PATH    Read/write Metal binary archive at PATH
          --no-pipeline-archive      Disable Metal binary archive use
          --merkle-subtree-auto      Enable benchmark-tuned 32-byte leaf subtree path
          --merkle-subtree-leaves N  Use N leaves per lower Merkle subtree; N must be a power of two
          --no-merkle-subtree        Disable lower subtree path. Default
        """
    }

    private mutating func validate() -> BenchError? {
        guard leafCount > 0, leafCount.nonzeroBitCount == 1 else {
            return BenchError.invalidArgument("--leaves must be a non-zero power of two.")
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
            guard suite ? suiteLeafLengths.allSatisfy({ $0 == 32 }) : leafLength == 32 else {
                return BenchError.invalidArgument("--merkle-subtree-auto currently requires --leaf-bytes 32.")
            }
        case let .fixed(value):
            guard suite ? suiteLeafLengths.allSatisfy({ $0 == 32 }) : leafLength == 32 else {
                return BenchError.invalidArgument("--merkle-subtree-leaves currently requires --leaf-bytes 32.")
            }
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
        if config.suite {
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
