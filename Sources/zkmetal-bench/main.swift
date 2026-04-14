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
    var cm31VectorMultiply = false
    var qm31VectorMultiply = false
    var qm31VectorInverse = false
    var qm31FRIFold = false
    var circleFRIFold = false
    var circleFRIFoldChain = false
    var circleFRIFoldChainMerkleTranscript = false
    var circleCodewordProver = false
    var qm31FRIFoldChain = false
    var qm31FRIFoldChainTranscript = false
    var qm31FRIFoldChainMerkleTranscript = false
    var qm31FRIProof = false
    var friFoldRounds = 3
    var friQueryCount = 4
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
                if !m31VectorInverse && !cm31VectorMultiply && !qm31VectorMultiply && !qm31VectorInverse && !qm31FRIFold && !circleFRIFold && !circleFRIFoldChain && !circleFRIFoldChainMerkleTranscript && !circleCodewordProver && !qm31FRIFoldChain && !qm31FRIFoldChainTranscript && !qm31FRIFoldChainMerkleTranscript && !qm31FRIProof {
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
            case "--cm31-multiply", "--cm31-vector-multiply":
                cm31VectorMultiply = true
                m31DotProduct = false
            case "--qm31-multiply", "--qm31-vector-multiply":
                qm31VectorMultiply = true
                m31DotProduct = false
            case "--qm31-inverse", "--qm31-vector-inverse":
                qm31VectorInverse = true
                m31DotProduct = false
            case "--qm31-fri-fold":
                qm31FRIFold = true
                m31DotProduct = false
            case "--circle-fri-fold":
                circleFRIFold = true
                m31DotProduct = false
            case "--circle-fri-fold-chain":
                circleFRIFoldChain = true
                m31DotProduct = false
            case "--circle-fri-fold-chain-merkle", "--circle-fri-fold-chain-merkle-transcript":
                circleFRIFoldChainMerkleTranscript = true
                m31DotProduct = false
            case "--circle-codeword-prover", "--circle-codeword-pcs-fri":
                circleCodewordProver = true
                m31DotProduct = false
            case "--qm31-fri-fold-chain":
                qm31FRIFoldChain = true
                m31DotProduct = false
            case "--qm31-fri-fold-chain-transcript":
                qm31FRIFoldChainTranscript = true
                m31DotProduct = false
            case "--qm31-fri-fold-chain-merkle", "--qm31-fri-fold-chain-merkle-transcript":
                qm31FRIFoldChainMerkleTranscript = true
                m31DotProduct = false
            case "--qm31-fri-proof", "--qm31-fri-proof-verifier":
                qm31FRIProof = true
                m31DotProduct = false
            case "--fri-fold-rounds":
                switch Self.parsePositiveInt(flag: arg, value: iterator.next()) {
                case let .success(value): friFoldRounds = value
                case let .failure(error): return error
                }
            case "--fri-query-count":
                switch Self.parsePositiveInt(flag: arg, value: iterator.next()) {
                case let .success(value): friQueryCount = value
                case let .failure(error): return error
                }
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
          --cm31-multiply            Run CM31 vector multiplication benchmark instead of hash/Merkle
          --qm31-multiply            Run QM31 vector multiplication benchmark instead of hash/Merkle
          --qm31-inverse             Run QM31 vector inverse benchmark instead of hash/Merkle
          --qm31-fri-fold            Run QM31 radix-2 FRI fold benchmark instead of hash/Merkle
          --circle-fri-fold          Run canonical Circle first FRI fold benchmark instead of hash/Merkle
          --circle-fri-fold-chain    Run canonical Circle multi-round FRI fold chain instead of hash/Merkle
          --circle-fri-fold-chain-merkle
                                      Commit each current Circle FRI layer on GPU before deriving the next Circle V1 challenge
          --circle-codeword-prover    Generate a Circle codeword on GPU, keep it resident, and emit a Circle PCS/FRI proof
          --qm31-fri-fold-chain      Run chained QM31 radix-2 FRI folds instead of hash/Merkle
          --qm31-fri-fold-chain-transcript
                                      Run chained QM31 FRI folds with GPU transcript-derived challenges
          --qm31-fri-fold-chain-merkle
                                      Commit each current QM31 FRI layer on GPU before deriving the next challenge
          --qm31-fri-proof           Build, serialize, deserialize, and verify a linear QM31 FRI proof
          --fri-fold-rounds N        Fold rounds for FRI chain modes. Default: 3
          --fri-query-count N        Query count for --qm31-fri-proof. Default: 4
          --elements N               Element count for field-vector benchmarks. Alias for --leaves in those modes
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
        let exclusiveModes = [
            keccakF1600Permutation,
            merkleOpening,
            m31DotProduct,
            m31VectorInverse,
            cm31VectorMultiply,
            qm31VectorMultiply,
            qm31VectorInverse,
            qm31FRIFold,
            circleFRIFold,
            circleFRIFoldChain,
            circleFRIFoldChainMerkleTranscript,
            circleCodewordProver,
            qm31FRIFoldChain,
            qm31FRIFoldChainTranscript,
            qm31FRIFoldChainMerkleTranscript,
            qm31FRIProof,
        ].filter { $0 }.count
        guard exclusiveModes <= 1 else {
            return BenchError.invalidArgument("--keccakf-permutation, --merkle-opening, --m31-dot-product, --m31-inverse, --cm31-multiply, --qm31-multiply, --qm31-inverse, --qm31-fri-fold, --circle-fri-fold, --circle-fri-fold-chain, --circle-fri-fold-chain-merkle, --circle-codeword-prover, --qm31-fri-fold-chain, --qm31-fri-fold-chain-transcript, --qm31-fri-fold-chain-merkle, and --qm31-fri-proof are mutually exclusive.")
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
        if cm31VectorMultiply {
            guard !suite else {
                return BenchError.invalidArgument("--suite is not supported with CM31 vector benchmarks.")
            }
            guard !leafCount.multipliedReportingOverflow(by: 4 * MemoryLayout<UInt32>.stride).overflow else {
                return BenchError.invalidArgument("Requested CM31 vector buffers are too large for this process.")
            }
            return nil
        }
        if qm31VectorMultiply || qm31VectorInverse {
            guard !suite else {
                return BenchError.invalidArgument("--suite is not supported with QM31 vector benchmarks.")
            }
            guard !leafCount.multipliedReportingOverflow(by: 8 * MemoryLayout<UInt32>.stride).overflow else {
                return BenchError.invalidArgument("Requested QM31 vector buffers are too large for this process.")
            }
            return nil
        }
        if qm31FRIFold {
            guard !suite else {
                return BenchError.invalidArgument("--suite is not supported with QM31 FRI fold benchmarks.")
            }
            guard leafCount > 1, leafCount.isMultiple(of: 2) else {
                return BenchError.invalidArgument("--elements must be an even count greater than one for --qm31-fri-fold.")
            }
            guard !leafCount.multipliedReportingOverflow(by: 6 * MemoryLayout<UInt32>.stride).overflow else {
                return BenchError.invalidArgument("Requested QM31 FRI fold buffers are too large for this process.")
            }
            return nil
        }
        if circleFRIFold {
            guard !suite else {
                return BenchError.invalidArgument("--suite is not supported with Circle FRI fold benchmarks.")
            }
            guard leafCount > 1,
                  leafCount.nonzeroBitCount == 1 else {
                return BenchError.invalidArgument("--elements must be a power-of-two count greater than one for --circle-fri-fold.")
            }
            let logSize = leafCount.trailingZeroBitCount
            guard logSize >= Int(CircleDomainDescriptor.minimumLogSize),
                  logSize <= Int(CircleDomainDescriptor.maximumLogSize) else {
                return BenchError.invalidArgument("--elements is outside the supported canonical Circle-domain range.")
            }
            guard !leafCount.multipliedReportingOverflow(by: 8 * MemoryLayout<UInt32>.stride).overflow else {
                return BenchError.invalidArgument("Requested Circle FRI fold buffers are too large for this process.")
            }
            return nil
        }
        if circleFRIFoldChain || circleFRIFoldChainMerkleTranscript {
            guard !suite else {
                return BenchError.invalidArgument("--suite is not supported with Circle FRI fold chain benchmarks.")
            }
            guard leafCount > 1,
                  leafCount.nonzeroBitCount == 1 else {
                return BenchError.invalidArgument("--elements must be a power-of-two count greater than one for --circle-fri-fold-chain.")
            }
            let logSize = leafCount.trailingZeroBitCount
            guard logSize >= Int(CircleDomainDescriptor.minimumLogSize),
                  logSize <= Int(CircleDomainDescriptor.maximumLogSize),
                  friFoldRounds > 0,
                  friFoldRounds <= logSize else {
                return BenchError.invalidArgument("--fri-fold-rounds must be in 1...log2(--elements) for --circle-fri-fold-chain.")
            }
            guard let outputCount = Self.friFoldChainOutputCount(inputCount: leafCount, roundCount: friFoldRounds) else {
                return BenchError.invalidArgument("--elements must leave at least one output element after --fri-fold-rounds.")
            }
            guard !Self.qm31FRIFoldChainFieldBufferByteOverflow(inputCount: leafCount, outputCount: outputCount) else {
                return BenchError.invalidArgument("Requested Circle FRI fold chain buffers are too large for this process.")
            }
            return nil
        }
        if circleCodewordProver {
            guard !suite else {
                return BenchError.invalidArgument("--suite is not supported with Circle codeword prover benchmarks.")
            }
            guard leafCount > 1,
                  leafCount.nonzeroBitCount == 1 else {
                return BenchError.invalidArgument("--elements must be a power-of-two count greater than one for --circle-codeword-prover.")
            }
            let logSize = leafCount.trailingZeroBitCount
            guard logSize >= Int(CircleDomainDescriptor.minimumLogSize),
                  logSize <= Int(CircleDomainDescriptor.maximumLogSize),
                  friFoldRounds > 0,
                  friFoldRounds <= logSize else {
                return BenchError.invalidArgument("--fri-fold-rounds must be in 1...log2(--elements) for --circle-codeword-prover.")
            }
            guard let outputCount = Self.friFoldChainOutputCount(inputCount: leafCount, roundCount: friFoldRounds) else {
                return BenchError.invalidArgument("--elements must leave at least one output element after --fri-fold-rounds.")
            }
            guard !Self.qm31FRIFoldChainFieldBufferByteOverflow(inputCount: leafCount, outputCount: outputCount) else {
                return BenchError.invalidArgument("Requested Circle codeword prover buffers are too large for this process.")
            }
            return nil
        }
        if qm31FRIFoldChain || qm31FRIFoldChainTranscript || qm31FRIFoldChainMerkleTranscript {
            guard !suite else {
                return BenchError.invalidArgument("--suite is not supported with QM31 FRI fold chain benchmarks.")
            }
            if qm31FRIFoldChainMerkleTranscript, leafCount.nonzeroBitCount != 1 {
                return BenchError.invalidArgument("--elements must be a power of two for --qm31-fri-fold-chain-merkle.")
            }
            guard let outputCount = Self.friFoldChainOutputCount(inputCount: leafCount, roundCount: friFoldRounds) else {
                return BenchError.invalidArgument("--elements must be divisible by 2^--fri-fold-rounds and leave at least one output element.")
            }
            guard !Self.qm31FRIFoldChainFieldBufferByteOverflow(inputCount: leafCount, outputCount: outputCount) else {
                return BenchError.invalidArgument("Requested QM31 FRI fold chain buffers are too large for this process.")
            }
            return nil
        }
        if qm31FRIProof {
            guard !suite else {
                return BenchError.invalidArgument("--suite is not supported with QM31 FRI proof benchmarks.")
            }
            guard leafCount > 1,
                  leafCount.nonzeroBitCount == 1 else {
                return BenchError.invalidArgument("--elements must be a power-of-two count greater than one for --qm31-fri-proof.")
            }
            let logSize = leafCount.trailingZeroBitCount
            guard friFoldRounds > 0,
                  friFoldRounds <= logSize else {
                return BenchError.invalidArgument("--fri-fold-rounds must be in 1...log2(--elements) for --qm31-fri-proof.")
            }
            guard friQueryCount > 0 else {
                return BenchError.invalidArgument("--fri-query-count must be greater than zero.")
            }
            guard leafCount / 2 <= Int(UInt32.max) else {
                return BenchError.invalidArgument("--elements is too large for QM31 FRI proof query sampling.")
            }
            guard let outputCount = Self.friFoldChainOutputCount(inputCount: leafCount, roundCount: friFoldRounds) else {
                return BenchError.invalidArgument("--elements must leave at least one output element after --fri-fold-rounds.")
            }
            guard !Self.qm31FRIFoldChainFieldBufferByteOverflow(inputCount: leafCount, outputCount: outputCount) else {
                return BenchError.invalidArgument("Requested QM31 FRI proof buffers are too large for this process.")
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

    private static func friFoldChainOutputCount(inputCount: Int, roundCount: Int) -> Int? {
        guard inputCount > 1, roundCount > 0 else {
            return nil
        }
        var current = inputCount
        for _ in 0..<roundCount {
            guard current > 1, current.isMultiple(of: 2) else {
                return nil
            }
            current /= 2
        }
        return current
    }

    private static func fieldBufferByteOverflow(elementCount: Int) -> Bool {
        elementCount.multipliedReportingOverflow(by: 4 * MemoryLayout<UInt32>.stride).overflow
    }

    private static func qm31FRIFoldChainFieldBufferByteOverflow(inputCount: Int, outputCount: Int) -> Bool {
        let inverseDomainCount = inputCount.subtractingReportingOverflow(outputCount)
        guard outputCount >= 0,
              !inverseDomainCount.overflow,
              inverseDomainCount.partialValue >= 0 else {
            return true
        }
        let totalResidentInputCount = inputCount.addingReportingOverflow(inverseDomainCount.partialValue)
        guard !totalResidentInputCount.overflow else {
            return true
        }
        return fieldBufferByteOverflow(elementCount: totalResidentInputCount.partialValue)
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

struct CM31VectorBenchmarkConfigReport: Codable {
    let elementCount: Int
    let operation: String
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct CM31VectorVerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let outputDigestHex: String
    let cpuOutputDigestHex: String?
}

struct CM31VectorBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: CM31VectorBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let vector: FieldMeasurementReport?
    let verification: CM31VectorVerificationReport
}

struct QM31VectorBenchmarkConfigReport: Codable {
    let elementCount: Int
    let operation: String
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct QM31VectorVerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let outputDigestHex: String
    let cpuOutputDigestHex: String?
}

struct QM31VectorBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: QM31VectorBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let vector: FieldMeasurementReport?
    let verification: QM31VectorVerificationReport
}

struct QM31FRIFoldBenchmarkConfigReport: Codable {
    let inputElementCount: Int
    let outputElementCount: Int
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct QM31FRIFoldVerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let outputDigestHex: String
    let cpuOutputDigestHex: String?
}

struct QM31FRIFoldBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: QM31FRIFoldBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let fold: FieldMeasurementReport?
    let verification: QM31FRIFoldVerificationReport
}

struct CircleFRIFoldBenchmarkConfigReport: Codable {
    let domainLogSize: Int
    let inputElementCount: Int
    let outputElementCount: Int
    let storageOrder: String
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct CircleFRIFoldVerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let outputDigestHex: String
    let cpuOutputDigestHex: String?
}

struct CircleFRIFoldBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: CircleFRIFoldBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let fold: FieldMeasurementReport?
    let verification: CircleFRIFoldVerificationReport
}

struct CircleFRIFoldChainBenchmarkConfigReport: Codable {
    let domainLogSize: Int
    let inputElementCount: Int
    let outputElementCount: Int
    let roundCount: Int
    let challengeMode: String
    let totalInverseDomainElementCount: Int
    let storageOrder: String
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct CircleFRIFoldChainBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: CircleFRIFoldChainBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let foldChain: FieldMeasurementReport?
    let queryExtraction: FieldMeasurementReport?
    let proofEmission: FieldMeasurementReport?
    let proofSizeBytes: Int?
    let verification: CircleFRIFoldVerificationReport
}

struct CircleCodewordProverBenchmarkConfigReport: Codable {
    let codewordEngine: String
    let coefficientInput: String
    let domainLogSize: Int
    let codewordElementCount: Int
    let finalLayerElementCount: Int
    let xCoefficientCount: Int
    let yCoefficientCount: Int
    let fftTwiddleCount: Int
    let roundCount: Int
    let queryCount: Int
    let storageOrder: String
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct CircleCodewordProverVerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let verifierAccepted: Bool?
    let codewordDigestHex: String?
    let codewordDigestSource: String
    let cpuCodewordDigestHex: String?
    let proofDigestHex: String
    let cpuProofDigestHex: String?
}

struct CircleCodewordProverReadbackPolicyReport: Codable {
    let publicProofMaterialOnly: Bool
    let fullCodewordReadback: Bool
    let intermediateFRILayerReadback: Bool
    let publicReadbacks: [String]
}

struct CircleCodewordProverBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: CircleCodewordProverBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let codewordGeneration: FieldMeasurementReport?
    let proofEmission: FieldMeasurementReport?
    let fullProver: FieldMeasurementReport?
    let proofSizeBytes: Int?
    let readbackPolicy: CircleCodewordProverReadbackPolicyReport
    let verification: CircleCodewordProverVerificationReport
}

struct QM31FRIFoldChainBenchmarkConfigReport: Codable {
    let inputElementCount: Int
    let outputElementCount: Int
    let roundCount: Int
    let challengeMode: String
    let totalInverseDomainElementCount: Int
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct QM31FRIFoldChainVerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let outputDigestHex: String
    let cpuOutputDigestHex: String?
}

struct QM31FRIFoldChainBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: QM31FRIFoldChainBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let foldChain: FieldMeasurementReport?
    let verification: QM31FRIFoldChainVerificationReport
}

struct QM31FRIProofBenchmarkConfigReport: Codable {
    let inputElementCount: Int
    let finalLayerElementCount: Int
    let roundCount: Int
    let queryCount: Int
    let totalInverseDomainElementCount: Int
    let warmupIterations: Int
    let iterations: Int
    let verifyWithCPU: Bool
}

struct QM31FRIProofVerificationReport: Codable {
    let enabled: Bool
    let matchedCPU: Bool?
    let verifierAccepted: Bool
    let proofDigestHex: String
    let cpuProofDigestHex: String?
    let finalLayerDigestHex: String
    let cpuFinalLayerDigestHex: String?
}

struct QM31FRIProofBenchmarkReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let target: String
    let configuration: QM31FRIProofBenchmarkConfigReport
    let device: DeviceReport?
    let pipelineArchive: PipelineArchiveReport
    let proofBuild: FieldMeasurementReport?
    let serialization: FieldMeasurementReport?
    let deserialization: FieldMeasurementReport?
    let proofVerification: FieldMeasurementReport?
    let proofSizeBytes: Int
    let queryOpeningCount: Int
    let verification: QM31FRIProofVerificationReport
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

func makeDeterministicCM31Vector(
    count: Int,
    realSalt: UInt32,
    imaginarySalt: UInt32
) -> [CM31Element] {
    let real = makeDeterministicM31Vector(count: count, salt: realSalt)
    let imaginary = makeDeterministicM31Vector(count: count, salt: imaginarySalt)
    return zip(real, imaginary).map { CM31Element(real: $0, imaginary: $1) }
}

func makeDeterministicQM31Vector(
    count: Int,
    aSalt: UInt32,
    bSalt: UInt32,
    cSalt: UInt32,
    dSalt: UInt32
) -> [QM31Element] {
    let a = makeDeterministicM31Vector(count: count, salt: aSalt)
    let b = makeDeterministicM31Vector(count: count, salt: bSalt)
    let c = makeDeterministicM31Vector(count: count, salt: cSalt)
    let d = makeDeterministicM31Vector(count: count, salt: dSalt)
    return (0..<count).map { index in
        QM31Element(a: a[index], b: b[index], c: c[index], d: d[index])
    }
}

func makeDeterministicNonzeroQM31Vector(
    count: Int,
    aSalt: UInt32,
    bSalt: UInt32,
    cSalt: UInt32,
    dSalt: UInt32
) -> [QM31Element] {
    makeDeterministicQM31Vector(
        count: count,
        aSalt: aSalt,
        bSalt: bSalt,
        cSalt: cSalt,
        dSalt: dSalt
    ).map { value in
        QM31Field.isZero(value) ? QM31Element(a: 1, b: 0, c: 0, d: 0) : value
    }
}

func makeDeterministicCircleCodewordPolynomial(domainSize: Int) throws -> CircleCodewordPolynomial {
    let xCoefficientCount = max(1, min(8, domainSize / 2))
    let yCoefficientCount = max(1, min(7, domainSize / 2))
    return try CircleCodewordPolynomial(
        xCoefficients: makeDeterministicQM31Vector(
            count: xCoefficientCount,
            aSalt: 0xe01,
            bSalt: 0xe03,
            cSalt: 0xe07,
            dSalt: 0xe0b
        ),
        yCoefficients: makeDeterministicQM31Vector(
            count: yCoefficientCount,
            aSalt: 0xe11,
            bSalt: 0xe17,
            cSalt: 0xe1d,
            dSalt: 0xe23
        )
    )
}

func makeDeterministicQM31FRIFoldRounds(
    inputCount: Int,
    roundCount: Int,
    saltBase: UInt32 = 0xf80
) -> [QM31FRIFoldRound] {
    var rounds: [QM31FRIFoldRound] = []
    var currentCount = inputCount
    for roundIndex in 0..<roundCount {
        let roundSalt = saltBase + UInt32(roundIndex) * 37
        let inverseDomainPoints = makeDeterministicNonzeroQM31Vector(
            count: currentCount / 2,
            aSalt: roundSalt,
            bSalt: roundSalt + 2,
            cSalt: roundSalt + 6,
            dSalt: roundSalt + 12
        )
        let challenge = QM31Element(
            a: 9 + UInt32(roundIndex) * 4,
            b: 7 + UInt32(roundIndex) * 6,
            c: 5 + UInt32(roundIndex) * 8,
            d: 3 + UInt32(roundIndex) * 10
        )
        rounds.append(QM31FRIFoldRound(inverseDomainPoints: inverseDomainPoints, challenge: challenge))
        currentCount /= 2
    }
    return rounds
}

func makeDeterministicCircleFRIChallenges(roundCount: Int) -> [QM31Element] {
    (0..<roundCount).map { roundIndex in
        QM31Element(
            a: 41 + UInt32(roundIndex) * 18,
            b: 43 + UInt32(roundIndex) * 22,
            c: 47 + UInt32(roundIndex) * 26,
            d: 53 + UInt32(roundIndex) * 30
        )
    }
}

func makeDeterministicQM31FRICommitments(count: Int, salt: UInt32 = 0xfd1) -> [Data] {
    (0..<count).map { roundIndex in
        Data((0..<QM31FRIFoldTranscriptOracle.commitmentByteCount).map { byteIndex in
            UInt8(truncatingIfNeeded: Int(salt) &+ roundIndex &* 31 &+ byteIndex &* 17)
        })
    }
}

func packUInt32LittleEndian(_ values: [UInt32]) -> Data {
    var data = Data()
    data.reserveCapacity(values.count * MemoryLayout<UInt32>.stride)
    for value in values {
        appendUInt32LittleEndian(value, to: &data)
    }
    return data
}

func packCM31LittleEndian(_ values: [CM31Element]) -> Data {
    var data = Data()
    data.reserveCapacity(values.count * 2 * MemoryLayout<UInt32>.stride)
    for value in values {
        appendUInt32LittleEndian(value.real, to: &data)
        appendUInt32LittleEndian(value.imaginary, to: &data)
    }
    return data
}

func packQM31LittleEndian(_ values: [QM31Element]) -> Data {
    var data = Data()
    data.reserveCapacity(values.count * 4 * MemoryLayout<UInt32>.stride)
    for value in values {
        appendUInt32LittleEndian(value.constant.real, to: &data)
        appendUInt32LittleEndian(value.constant.imaginary, to: &data)
        appendUInt32LittleEndian(value.uCoefficient.real, to: &data)
        appendUInt32LittleEndian(value.uCoefficient.imaginary, to: &data)
    }
    return data
}

func packQM31FRIFoldInverseDomains(_ rounds: [QM31FRIFoldRound]) -> Data {
    packQM31LittleEndian(rounds.flatMap { $0.inverseDomainPoints })
}

func packQM31FRICommitments(_ commitments: [Data]) -> Data {
    var data = Data()
    data.reserveCapacity(commitments.count * QM31FRIFoldTranscriptOracle.commitmentByteCount)
    for commitment in commitments {
        data.append(commitment)
    }
    return data
}

func appendUInt32LittleEndian(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 24) & 0xff))
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

func makeSharedMetalBuffer(
    device: MTLDevice,
    bytes: Data,
    label: String
) throws -> MTLBuffer {
    let length = bytes.count
    let buffer: MTLBuffer?
    if length == 0 {
        buffer = device.makeBuffer(length: 1, options: .storageModeShared)
    } else {
        buffer = bytes.withUnsafeBytes { rawBuffer in
            rawBuffer.baseAddress.flatMap {
                device.makeBuffer(bytes: $0, length: length, options: .storageModeShared)
            }
        }
    }
    guard let buffer else {
        throw AppleZKProverError.failedToCreateBuffer(label: label, length: length)
    }
    buffer.label = label
    return buffer
}

func makeSharedMetalBuffer(
    device: MTLDevice,
    length: Int,
    label: String
) throws -> MTLBuffer {
    guard let buffer = device.makeBuffer(length: max(1, length), options: .storageModeShared) else {
        throw AppleZKProverError.failedToCreateBuffer(label: label, length: length)
    }
    buffer.label = label
    return buffer
}

func makePrivateMetalBuffer(
    device: MTLDevice,
    length: Int,
    label: String
) throws -> MTLBuffer {
    guard let buffer = device.makeBuffer(length: max(1, length), options: .storageModePrivate) else {
        throw AppleZKProverError.failedToCreateBuffer(label: label, length: length)
    }
    buffer.label = label
    return buffer
}

func makePrivateMetalBuffer(
    context: MetalContext,
    bytes: Data,
    label: String
) throws -> MTLBuffer {
    let destination = try makePrivateMetalBuffer(
        device: context.device,
        length: bytes.count,
        label: label
    )
    let staging = try makeSharedMetalBuffer(
        device: context.device,
        bytes: bytes,
        label: "\(label).Staging"
    )
    guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
        throw AppleZKProverError.failedToCreateCommandBuffer
    }
    commandBuffer.label = "\(label).Upload"
    guard let blit = commandBuffer.makeBlitCommandEncoder() else {
        throw AppleZKProverError.failedToCreateEncoder
    }
    blit.label = "\(label).Upload.Copy"
    if bytes.count > 0 {
        blit.copy(from: staging, sourceOffset: 0, to: destination, destinationOffset: 0, size: bytes.count)
    }
    blit.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    if let error = commandBuffer.error {
        throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
    }
    return destination
}

func readQM31Buffer(_ buffer: MTLBuffer, count: Int) -> [QM31Element] {
    let words = buffer.contents().bindMemory(to: UInt32.self, capacity: count * 4)
    return (0..<count).map { index in
        QM31Element(
            a: words[index * 4],
            b: words[index * 4 + 1],
            c: words[index * 4 + 2],
            d: words[index * 4 + 3]
        )
    }
}

func readQM31FRICommitments(_ buffer: MTLBuffer, count: Int) -> [Data] {
    let byteCount = QM31FRIFoldTranscriptOracle.commitmentByteCount
    let bytes = buffer.contents().bindMemory(to: UInt8.self, capacity: count * byteCount)
    return (0..<count).map { index in
        Data(bytes: bytes.advanced(by: index * byteCount), count: byteCount)
    }
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

func emitJSON(_ report: CM31VectorBenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: QM31VectorBenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: QM31FRIFoldBenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: CircleFRIFoldBenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: CircleFRIFoldChainBenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: CircleCodewordProverBenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: QM31FRIFoldChainBenchmarkReport) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func emitJSON(_ report: QM31FRIProofBenchmarkReport) throws {
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

func emitText(_ report: CM31VectorBenchmarkReport) {
    print("zkmetal-bench cm31-vector")
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

func emitText(_ report: QM31VectorBenchmarkReport) {
    print("zkmetal-bench qm31-vector")
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

func emitText(_ report: QM31FRIFoldBenchmarkReport) {
    print("zkmetal-bench qm31-fri-fold")
    print("  input elems  : \(report.configuration.inputElementCount)")
    print("  output elems : \(report.configuration.outputElementCount)")
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

    if let fold = report.fold {
        printSeconds("fold wall", fold.wallSeconds)
        if let gpu = fold.gpuSeconds {
            printSeconds("fold gpu ", gpu)
        }
        print("  folds/sec    : \(String(format: "%.2f", fold.elementsPerSecond))")
        print("  input B/s    : \(String(format: "%.2f", fold.inputBytesPerSecond))")
    }

    print("  output digest: \(report.verification.outputDigestHex)")
    if let cpuDigest = report.verification.cpuOutputDigestHex {
        print("  cpu digest   : \(cpuDigest)")
    }
    if let matchedCPU = report.verification.matchedCPU {
        print("  match        : \(matchedCPU)")
    }
}

func emitText(_ report: CircleFRIFoldBenchmarkReport) {
    print("zkmetal-bench circle-fri-fold")
    print("  domain log   : \(report.configuration.domainLogSize)")
    print("  input elems  : \(report.configuration.inputElementCount)")
    print("  output elems : \(report.configuration.outputElementCount)")
    print("  storage      : \(report.configuration.storageOrder)")
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

    if let fold = report.fold {
        printSeconds("fold wall", fold.wallSeconds)
        if let gpu = fold.gpuSeconds {
            printSeconds("fold gpu ", gpu)
        }
        print("  folds/sec    : \(String(format: "%.2f", fold.elementsPerSecond))")
        print("  input B/s    : \(String(format: "%.2f", fold.inputBytesPerSecond))")
    }

    print("  output digest: \(report.verification.outputDigestHex)")
    if let cpuDigest = report.verification.cpuOutputDigestHex {
        print("  cpu digest   : \(cpuDigest)")
    }
    if let matchedCPU = report.verification.matchedCPU {
        print("  match        : \(matchedCPU)")
    }
}

func emitText(_ report: CircleFRIFoldChainBenchmarkReport) {
    print("zkmetal-bench circle-fri-fold-chain")
    print("  domain log   : \(report.configuration.domainLogSize)")
    print("  input elems  : \(report.configuration.inputElementCount)")
    print("  output elems : \(report.configuration.outputElementCount)")
    print("  rounds       : \(report.configuration.roundCount)")
    print("  challenges   : \(report.configuration.challengeMode)")
    print("  inv elems    : \(report.configuration.totalInverseDomainElementCount)")
    print("  storage      : \(report.configuration.storageOrder)")
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

    if let foldChain = report.foldChain {
        printSeconds("chain wall", foldChain.wallSeconds)
        if let gpu = foldChain.gpuSeconds {
            printSeconds("chain gpu ", gpu)
        }
        print("  output/sec   : \(String(format: "%.2f", foldChain.elementsPerSecond))")
        print("  input B/s    : \(String(format: "%.2f", foldChain.inputBytesPerSecond))")
    }

    if let extraction = report.queryExtraction {
        printSeconds("query wall", extraction.wallSeconds)
        if let gpu = extraction.gpuSeconds {
            printSeconds("query gpu ", gpu)
        }
        print("  openings/sec : \(String(format: "%.2f", extraction.elementsPerSecond))")
        print("  proof B/s    : \(String(format: "%.2f", extraction.inputBytesPerSecond))")
    }

    if let proofEmission = report.proofEmission {
        printSeconds("proof wall", proofEmission.wallSeconds)
        if let gpu = proofEmission.gpuSeconds {
            printSeconds("proof gpu ", gpu)
        }
        print("  proofs/sec   : \(String(format: "%.2f", proofEmission.elementsPerSecond))")
        print("  proof B/s    : \(String(format: "%.2f", proofEmission.inputBytesPerSecond))")
    }
    if let proofSizeBytes = report.proofSizeBytes {
        print("  proof bytes  : \(proofSizeBytes)")
    }

    print("  output digest: \(report.verification.outputDigestHex)")
    if let cpuDigest = report.verification.cpuOutputDigestHex {
        print("  cpu digest   : \(cpuDigest)")
    }
    if let matchedCPU = report.verification.matchedCPU {
        print("  match        : \(matchedCPU)")
    }
}

func emitText(_ report: CircleCodewordProverBenchmarkReport) {
    print("zkmetal-bench circle-codeword-prover")
    print("  engine       : \(report.configuration.codewordEngine)")
    print("  coeff input  : \(report.configuration.coefficientInput)")
    print("  domain log   : \(report.configuration.domainLogSize)")
    print("  codeword elems: \(report.configuration.codewordElementCount)")
    print("  final elems  : \(report.configuration.finalLayerElementCount)")
    print("  x coeffs     : \(report.configuration.xCoefficientCount)")
    print("  y coeffs     : \(report.configuration.yCoefficientCount)")
    print("  fft twiddles : \(report.configuration.fftTwiddleCount)")
    print("  rounds       : \(report.configuration.roundCount)")
    print("  queries      : \(report.configuration.queryCount)")
    print("  storage      : \(report.configuration.storageOrder)")
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

    if let codeword = report.codewordGeneration {
        printSeconds("codeword wall", codeword.wallSeconds)
        if let gpu = codeword.gpuSeconds {
            printSeconds("codeword gpu ", gpu)
        }
        print("  evals/sec    : \(String(format: "%.2f", codeword.elementsPerSecond))")
        print("  input B/s    : \(String(format: "%.2f", codeword.inputBytesPerSecond))")
    }

    if let proof = report.proofEmission {
        printSeconds("proof wall", proof.wallSeconds)
        if let gpu = proof.gpuSeconds {
            printSeconds("proof gpu ", gpu)
        }
        print("  proofs/sec   : \(String(format: "%.2f", proof.elementsPerSecond))")
        print("  proof B/s    : \(String(format: "%.2f", proof.inputBytesPerSecond))")
    }
    if let fullProver = report.fullProver {
        printSeconds("full wall ", fullProver.wallSeconds)
        if let gpu = fullProver.gpuSeconds {
            printSeconds("full gpu  ", gpu)
        }
        print("  full/sec     : \(String(format: "%.2f", fullProver.elementsPerSecond))")
        print("  full B/s     : \(String(format: "%.2f", fullProver.inputBytesPerSecond))")
    }
    if let proofSizeBytes = report.proofSizeBytes {
        print("  proof bytes  : \(proofSizeBytes)")
    }

    print("  readback     : \(report.readbackPolicy.publicProofMaterialOnly ? "public proof material only" : "debug/private material")")
    print("  codeword rb  : \(report.readbackPolicy.fullCodewordReadback)")
    print("  fri-layer rb : \(report.readbackPolicy.intermediateFRILayerReadback)")
    if let codewordDigest = report.verification.codewordDigestHex {
        print("  codeword digest: \(codewordDigest)")
    } else {
        print("  codeword digest: not read back")
    }
    print("  codeword source: \(report.verification.codewordDigestSource)")
    if let cpuDigest = report.verification.cpuCodewordDigestHex {
        print("  cpu codeword : \(cpuDigest)")
    }
    print("  proof digest : \(report.verification.proofDigestHex)")
    if let cpuProofDigest = report.verification.cpuProofDigestHex {
        print("  cpu proof    : \(cpuProofDigest)")
    }
    if let accepted = report.verification.verifierAccepted {
        print("  verifier     : \(accepted)")
    }
    if let matchedCPU = report.verification.matchedCPU {
        print("  match        : \(matchedCPU)")
    }
}

func emitText(_ report: QM31FRIFoldChainBenchmarkReport) {
    print("zkmetal-bench qm31-fri-fold-chain")
    print("  input elems  : \(report.configuration.inputElementCount)")
    print("  output elems : \(report.configuration.outputElementCount)")
    print("  rounds       : \(report.configuration.roundCount)")
    print("  challenge    : \(report.configuration.challengeMode)")
    print("  inv elems    : \(report.configuration.totalInverseDomainElementCount)")
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

    if let foldChain = report.foldChain {
        printSeconds("chain wall", foldChain.wallSeconds)
        if let gpu = foldChain.gpuSeconds {
            printSeconds("chain gpu ", gpu)
        }
        print("  output/sec   : \(String(format: "%.2f", foldChain.elementsPerSecond))")
        print("  input B/s    : \(String(format: "%.2f", foldChain.inputBytesPerSecond))")
    }

    print("  output digest: \(report.verification.outputDigestHex)")
    if let cpuDigest = report.verification.cpuOutputDigestHex {
        print("  cpu digest   : \(cpuDigest)")
    }
    if let matchedCPU = report.verification.matchedCPU {
        print("  match        : \(matchedCPU)")
    }
}

func emitText(_ report: QM31FRIProofBenchmarkReport) {
    print("zkmetal-bench qm31-fri-proof")
    print("  input elems  : \(report.configuration.inputElementCount)")
    print("  final elems  : \(report.configuration.finalLayerElementCount)")
    print("  rounds       : \(report.configuration.roundCount)")
    print("  queries      : \(report.configuration.queryCount)")
    print("  inv elems    : \(report.configuration.totalInverseDomainElementCount)")
    print("  warmups      : \(report.configuration.warmupIterations)")
    print("  iterations   : \(report.configuration.iterations)")
    print("  verify (CPU) : \(report.configuration.verifyWithCPU)")
    print("  archive      : \(report.pipelineArchive.mode)")

    if let proofBuild = report.proofBuild {
        printSeconds("build wall", proofBuild.wallSeconds)
        print("  builds/sec   : \(String(format: "%.2f", proofBuild.elementsPerSecond))")
        print("  input B/s    : \(String(format: "%.2f", proofBuild.inputBytesPerSecond))")
    }
    if let serialization = report.serialization {
        printSeconds("ser wall  ", serialization.wallSeconds)
        print("  serial/sec   : \(String(format: "%.2f", serialization.elementsPerSecond))")
        print("  proof B/s    : \(String(format: "%.2f", serialization.inputBytesPerSecond))")
    }
    if let deserialization = report.deserialization {
        printSeconds("de wall   ", deserialization.wallSeconds)
        print("  deser/sec    : \(String(format: "%.2f", deserialization.elementsPerSecond))")
        print("  proof B/s    : \(String(format: "%.2f", deserialization.inputBytesPerSecond))")
    }
    if let proofVerification = report.proofVerification {
        printSeconds("verify wall", proofVerification.wallSeconds)
        print("  verify/sec   : \(String(format: "%.2f", proofVerification.elementsPerSecond))")
        print("  proof B/s    : \(String(format: "%.2f", proofVerification.inputBytesPerSecond))")
    }

    print("  proof bytes  : \(report.proofSizeBytes)")
    print("  openings     : \(report.queryOpeningCount)")
    print("  proof digest : \(report.verification.proofDigestHex)")
    if let cpuProofDigest = report.verification.cpuProofDigestHex {
        print("  cpu proof    : \(cpuProofDigest)")
    }
    print("  final digest : \(report.verification.finalLayerDigestHex)")
    if let cpuFinalLayerDigest = report.verification.cpuFinalLayerDigestHex {
        print("  cpu final    : \(cpuFinalLayerDigest)")
    }
    print("  verifier     : \(report.verification.verifierAccepted)")
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

func verificationFailureMessages(in report: CM31VectorBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true else {
        let cpuDigest = report.verification.cpuOutputDigestHex ?? "missing"
        return [
            "cm31-vector operation=\(report.configuration.operation) elements=\(report.configuration.elementCount) target=\(report.target) digest=\(report.verification.outputDigestHex) cpu-digest=\(cpuDigest)",
        ]
    }
    return []
}

func verificationFailureMessages(in report: QM31VectorBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true else {
        let cpuDigest = report.verification.cpuOutputDigestHex ?? "missing"
        return [
            "qm31-vector operation=\(report.configuration.operation) elements=\(report.configuration.elementCount) target=\(report.target) digest=\(report.verification.outputDigestHex) cpu-digest=\(cpuDigest)",
        ]
    }
    return []
}

func verificationFailureMessages(in report: QM31FRIFoldBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true else {
        let cpuDigest = report.verification.cpuOutputDigestHex ?? "missing"
        return [
            "qm31-fri-fold input-elements=\(report.configuration.inputElementCount) target=\(report.target) digest=\(report.verification.outputDigestHex) cpu-digest=\(cpuDigest)",
        ]
    }
    return []
}

func verificationFailureMessages(in report: CircleFRIFoldBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true else {
        let cpuDigest = report.verification.cpuOutputDigestHex ?? "missing"
        return [
            "circle-fri-fold log-size=\(report.configuration.domainLogSize) input-elements=\(report.configuration.inputElementCount) target=\(report.target) digest=\(report.verification.outputDigestHex) cpu-digest=\(cpuDigest)",
        ]
    }
    return []
}

func verificationFailureMessages(in report: CircleFRIFoldChainBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true else {
        let cpuDigest = report.verification.cpuOutputDigestHex ?? "missing"
        return [
            "circle-fri-fold-chain mode=\(report.configuration.challengeMode) log-size=\(report.configuration.domainLogSize) input-elements=\(report.configuration.inputElementCount) rounds=\(report.configuration.roundCount) target=\(report.target) digest=\(report.verification.outputDigestHex) cpu-digest=\(cpuDigest)",
        ]
    }
    return []
}

func verificationFailureMessages(in report: CircleCodewordProverBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true,
          report.verification.verifierAccepted == true else {
        let codewordDigest = report.verification.codewordDigestHex ?? "not-read-back"
        let cpuCodewordDigest = report.verification.cpuCodewordDigestHex ?? "missing"
        let cpuProofDigest = report.verification.cpuProofDigestHex ?? "missing"
        return [
            "circle-codeword-prover log-size=\(report.configuration.domainLogSize) codeword-elements=\(report.configuration.codewordElementCount) rounds=\(report.configuration.roundCount) target=\(report.target) codeword-digest=\(codewordDigest) codeword-source=\(report.verification.codewordDigestSource) cpu-codeword-digest=\(cpuCodewordDigest) proof-digest=\(report.verification.proofDigestHex) cpu-proof-digest=\(cpuProofDigest)",
        ]
    }
    return []
}

func verificationFailureMessages(in report: QM31FRIFoldChainBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true else {
        let cpuDigest = report.verification.cpuOutputDigestHex ?? "missing"
        return [
            "qm31-fri-fold-chain mode=\(report.configuration.challengeMode) input-elements=\(report.configuration.inputElementCount) rounds=\(report.configuration.roundCount) target=\(report.target) digest=\(report.verification.outputDigestHex) cpu-digest=\(cpuDigest)",
        ]
    }
    return []
}

func verificationFailureMessages(in report: QM31FRIProofBenchmarkReport) -> [String] {
    guard report.verification.enabled else {
        return []
    }
    guard report.verification.matchedCPU == true,
          report.verification.verifierAccepted else {
        let cpuProofDigest = report.verification.cpuProofDigestHex ?? "missing"
        let cpuFinalDigest = report.verification.cpuFinalLayerDigestHex ?? "missing"
        return [
            "qm31-fri-proof input-elements=\(report.configuration.inputElementCount) rounds=\(report.configuration.roundCount) queries=\(report.configuration.queryCount) target=\(report.target) proof-digest=\(report.verification.proofDigestHex) cpu-proof-digest=\(cpuProofDigest) final-digest=\(report.verification.finalLayerDigestHex) cpu-final-digest=\(cpuFinalDigest) verifier=\(report.verification.verifierAccepted)",
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

func makeCM31VectorConfigReport(
    config: BenchConfig,
    operation: CM31VectorOperation
) -> CM31VectorBenchmarkConfigReport {
    CM31VectorBenchmarkConfigReport(
        elementCount: config.leafCount,
        operation: cm31VectorOperationName(operation),
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

func cm31VectorOperationName(_ operation: CM31VectorOperation) -> String {
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
    }
}

func makeQM31VectorConfigReport(
    config: BenchConfig,
    operation: QM31VectorOperation
) -> QM31VectorBenchmarkConfigReport {
    QM31VectorBenchmarkConfigReport(
        elementCount: config.leafCount,
        operation: qm31VectorOperationName(operation),
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

func qm31VectorOperationName(_ operation: QM31VectorOperation) -> String {
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

func makeQM31FRIFoldConfigReport(config: BenchConfig) -> QM31FRIFoldBenchmarkConfigReport {
    QM31FRIFoldBenchmarkConfigReport(
        inputElementCount: config.leafCount,
        outputElementCount: config.leafCount / 2,
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

func makeCircleFRIFoldConfigReport(config: BenchConfig) -> CircleFRIFoldBenchmarkConfigReport {
    CircleFRIFoldBenchmarkConfigReport(
        domainLogSize: config.leafCount.trailingZeroBitCount,
        inputElementCount: config.leafCount,
        outputElementCount: config.leafCount / 2,
        storageOrder: "circle-domain-bit-reversed",
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

func makeCircleFRIFoldChainConfigReport(
    config: BenchConfig,
    outputElementCount: Int,
    totalInverseDomainElementCount: Int
) -> CircleFRIFoldChainBenchmarkConfigReport {
    CircleFRIFoldChainBenchmarkConfigReport(
        domainLogSize: config.leafCount.trailingZeroBitCount,
        inputElementCount: config.leafCount,
        outputElementCount: outputElementCount,
        roundCount: config.friFoldRounds,
        challengeMode: config.circleFRIFoldChainMerkleTranscript
            ? "circle-v1-merkle-transcript"
            : "explicit",
        totalInverseDomainElementCount: totalInverseDomainElementCount,
        storageOrder: "circle-domain-bit-reversed",
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

func makeCircleCodewordProverConfigReport(
    config: BenchConfig,
    polynomial: CircleCodewordPolynomial,
    finalLayerElementCount: Int,
    queryCount: Int
) -> CircleCodewordProverBenchmarkConfigReport {
    CircleCodewordProverBenchmarkConfigReport(
        codewordEngine: "circle-fft-butterfly-v1",
        coefficientInput: "resident-circle-fft-basis-buffer",
        domainLogSize: config.leafCount.trailingZeroBitCount,
        codewordElementCount: config.leafCount,
        finalLayerElementCount: finalLayerElementCount,
        xCoefficientCount: polynomial.xCoefficients.count,
        yCoefficientCount: polynomial.yCoefficients.count,
        fftTwiddleCount: config.leafCount - 1,
        roundCount: config.friFoldRounds,
        queryCount: queryCount,
        storageOrder: "circle-domain-bit-reversed",
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

func makeCircleCodewordProverReadbackPolicyReport() -> CircleCodewordProverReadbackPolicyReport {
    CircleCodewordProverReadbackPolicyReport(
        publicProofMaterialOnly: true,
        fullCodewordReadback: false,
        intermediateFRILayerReadback: false,
        publicReadbacks: CircleCodewordPCSFRIResidentCommandPlanV1.canonicalPublicReadbacks.map(\.rawValue)
    )
}

func makeQM31FRIFoldChainConfigReport(
    config: BenchConfig,
    outputElementCount: Int,
    totalInverseDomainElementCount: Int
) -> QM31FRIFoldChainBenchmarkConfigReport {
    let challengeMode: String
    if config.qm31FRIFoldChainMerkleTranscript {
        challengeMode = "merkle-transcript"
    } else if config.qm31FRIFoldChainTranscript {
        challengeMode = "transcript"
    } else {
        challengeMode = "explicit"
    }
    return QM31FRIFoldChainBenchmarkConfigReport(
        inputElementCount: config.leafCount,
        outputElementCount: outputElementCount,
        roundCount: config.friFoldRounds,
        challengeMode: challengeMode,
        totalInverseDomainElementCount: totalInverseDomainElementCount,
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
}

func makeQM31FRIProofConfigReport(
    config: BenchConfig,
    finalLayerElementCount: Int,
    totalInverseDomainElementCount: Int
) -> QM31FRIProofBenchmarkConfigReport {
    QM31FRIProofBenchmarkConfigReport(
        inputElementCount: config.leafCount,
        finalLayerElementCount: finalLayerElementCount,
        roundCount: config.friFoldRounds,
        queryCount: config.friQueryCount,
        totalInverseDomainElementCount: totalInverseDomainElementCount,
        warmupIterations: config.warmupIterations,
        iterations: config.iterations,
        verifyWithCPU: config.verifyWithCPU
    )
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
func runCM31VectorMultiplyBenchmark(_ config: BenchConfig) throws -> CM31VectorBenchmarkReport {
    let operation = CM31VectorOperation.multiply
    let lhs = makeDeterministicCM31Vector(count: config.leafCount, realSalt: 0xc31, imaginarySalt: 0xc37)
    let rhs = makeDeterministicCM31Vector(count: config.leafCount, realSalt: 0xc41, imaginarySalt: 0xc43)
    let configReport = makeCM31VectorConfigReport(config: config, operation: operation)

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let cpuOutput = try CM31Field.apply(operation, lhs: lhs, rhs: rhs)
        let digest = SHA3Oracle.sha3_256(packCM31LittleEndian(cpuOutput)).hexString
        return CM31VectorBenchmarkReport(
            schemaVersion: 1,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: configReport,
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            vector: nil,
            verification: CM31VectorVerificationReport(
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
    let plan = try CM31VectorArithmeticPlan(context: context, operation: operation, count: config.leafCount)
    try context.serializePipelineArchiveIfNeeded()

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try plan.execute(lhs: lhs, rhs: rhs)
        }
    }

    var wallSeconds: [Double] = []
    var gpuSeconds: [Double?] = []
    var output: [CM31Element] = []
    for _ in 0..<config.iterations {
        let result = try plan.execute(lhs: lhs, rhs: rhs)
        wallSeconds.append(result.stats.cpuWallSeconds)
        gpuSeconds.append(result.stats.gpuSeconds)
        output = result.values
    }

    let cpuOutput = config.verifyWithCPU ? try CM31Field.apply(operation, lhs: lhs, rhs: rhs) : nil
    let matchedCPU = cpuOutput.map { $0 == output }
    let outputDigest = SHA3Oracle.sha3_256(packCM31LittleEndian(output)).hexString
    let cpuOutputDigest = cpuOutput.map { SHA3Oracle.sha3_256(packCM31LittleEndian($0)).hexString }
    return CM31VectorBenchmarkReport(
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
            inputBytes: Double(config.leafCount) * Double(4 * MemoryLayout<UInt32>.stride)
        ),
        verification: CM31VectorVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            outputDigestHex: outputDigest,
            cpuOutputDigestHex: cpuOutputDigest
        )
    )
    #else
    let cpuOutput = try CM31Field.apply(operation, lhs: lhs, rhs: rhs)
    let digest = SHA3Oracle.sha3_256(packCM31LittleEndian(cpuOutput)).hexString
    return CM31VectorBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: configReport,
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        vector: nil,
        verification: CM31VectorVerificationReport(
            enabled: true,
            matchedCPU: true,
            outputDigestHex: digest,
            cpuOutputDigestHex: digest
        )
    )
    #endif
}

@inline(never)
func runQM31VectorBenchmark(
    _ config: BenchConfig,
    operation: QM31VectorOperation
) throws -> QM31VectorBenchmarkReport {
    let lhs = operation == .inverse
        ? makeDeterministicNonzeroQM31Vector(count: config.leafCount, aSalt: 0x9a1, bSalt: 0x9a7, cSalt: 0x9ad, dSalt: 0x9b3)
        : makeDeterministicQM31Vector(count: config.leafCount, aSalt: 0x9a1, bSalt: 0x9a7, cSalt: 0x9ad, dSalt: 0x9b3)
    let rhs = operation.requiresRightHandSide
        ? makeDeterministicQM31Vector(count: config.leafCount, aSalt: 0x9c1, bSalt: 0x9c7, cSalt: 0x9d3, dSalt: 0x9df)
        : nil
    let configReport = makeQM31VectorConfigReport(config: config, operation: operation)

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let cpuOutput = try QM31Field.apply(operation, lhs: lhs, rhs: rhs)
        let digest = SHA3Oracle.sha3_256(packQM31LittleEndian(cpuOutput)).hexString
        return QM31VectorBenchmarkReport(
            schemaVersion: 1,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: configReport,
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            vector: nil,
            verification: QM31VectorVerificationReport(
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
    let plan = try QM31VectorArithmeticPlan(context: context, operation: operation, count: config.leafCount)
    try context.serializePipelineArchiveIfNeeded()

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try plan.execute(lhs: lhs, rhs: rhs)
        }
    }

    var wallSeconds: [Double] = []
    var gpuSeconds: [Double?] = []
    var output: [QM31Element] = []
    for _ in 0..<config.iterations {
        let result = try plan.execute(lhs: lhs, rhs: rhs)
        wallSeconds.append(result.stats.cpuWallSeconds)
        gpuSeconds.append(result.stats.gpuSeconds)
        output = result.values
    }

    let cpuOutput = config.verifyWithCPU ? try QM31Field.apply(operation, lhs: lhs, rhs: rhs) : nil
    let matchedCPU = cpuOutput.map { $0 == output }
    let outputDigest = SHA3Oracle.sha3_256(packQM31LittleEndian(output)).hexString
    let cpuOutputDigest = cpuOutput.map { SHA3Oracle.sha3_256(packQM31LittleEndian($0)).hexString }
    let inputVectors = operation.requiresRightHandSide ? 2 : 1
    return QM31VectorBenchmarkReport(
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
            inputBytes: Double(config.leafCount * inputVectors * 4 * MemoryLayout<UInt32>.stride)
        ),
        verification: QM31VectorVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            outputDigestHex: outputDigest,
            cpuOutputDigestHex: cpuOutputDigest
        )
    )
    #else
    let cpuOutput = try QM31Field.apply(operation, lhs: lhs, rhs: rhs)
    let digest = SHA3Oracle.sha3_256(packQM31LittleEndian(cpuOutput)).hexString
    return QM31VectorBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: configReport,
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        vector: nil,
        verification: QM31VectorVerificationReport(
            enabled: true,
            matchedCPU: true,
            outputDigestHex: digest,
            cpuOutputDigestHex: digest
        )
    )
    #endif
}

@inline(never)
func runQM31FRIFoldBenchmark(_ config: BenchConfig) throws -> QM31FRIFoldBenchmarkReport {
    let outputCount = config.leafCount / 2
    let evaluations = makeDeterministicQM31Vector(
        count: config.leafCount,
        aSalt: 0xf31,
        bSalt: 0xf37,
        cSalt: 0xf3d,
        dSalt: 0xf43
    )
    let inverseDomainPoints = makeDeterministicNonzeroQM31Vector(
        count: outputCount,
        aSalt: 0xf47,
        bSalt: 0xf4d,
        cSalt: 0xf53,
        dSalt: 0xf59
    )
    let challenge = QM31Element(a: 9, b: 7, c: 5, d: 3)
    let configReport = makeQM31FRIFoldConfigReport(config: config)

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let cpuOutput = try QM31FRIFoldOracle.fold(
            evaluations: evaluations,
            inverseDomainPoints: inverseDomainPoints,
            challenge: challenge
        )
        let digest = SHA3Oracle.sha3_256(packQM31LittleEndian(cpuOutput)).hexString
        return QM31FRIFoldBenchmarkReport(
            schemaVersion: 1,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: configReport,
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            fold: nil,
            verification: QM31FRIFoldVerificationReport(
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
    let plan = try QM31FRIFoldPlan(context: context, inputCount: config.leafCount)
    try context.serializePipelineArchiveIfNeeded()

    let evaluationBuffer = try makeSharedMetalBuffer(
        device: device,
        bytes: packQM31LittleEndian(evaluations),
        label: "zkmetal-bench.QM31FRIFold.Evaluations"
    )
    let inverseDomainBuffer = try makeSharedMetalBuffer(
        device: device,
        bytes: packQM31LittleEndian(inverseDomainPoints),
        label: "zkmetal-bench.QM31FRIFold.InverseDomain"
    )
    let outputBuffer = try makeSharedMetalBuffer(
        device: device,
        length: outputCount * 4 * MemoryLayout<UInt32>.stride,
        label: "zkmetal-bench.QM31FRIFold.Output"
    )

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try plan.executeResident(
                evaluationsBuffer: evaluationBuffer,
                inverseDomainBuffer: inverseDomainBuffer,
                outputBuffer: outputBuffer,
                challenge: challenge
            )
        }
    }

    var wallSeconds: [Double] = []
    var gpuSeconds: [Double?] = []
    for _ in 0..<config.iterations {
        let stats = try plan.executeResident(
            evaluationsBuffer: evaluationBuffer,
            inverseDomainBuffer: inverseDomainBuffer,
            outputBuffer: outputBuffer,
            challenge: challenge
        )
        wallSeconds.append(stats.cpuWallSeconds)
        gpuSeconds.append(stats.gpuSeconds)
    }

    let output = readQM31Buffer(outputBuffer, count: outputCount)
    let cpuOutput = config.verifyWithCPU
        ? try QM31FRIFoldOracle.fold(
            evaluations: evaluations,
            inverseDomainPoints: inverseDomainPoints,
            challenge: challenge
        )
        : nil
    let matchedCPU = cpuOutput.map { $0 == output }
    let outputDigest = SHA3Oracle.sha3_256(packQM31LittleEndian(output)).hexString
    let cpuOutputDigest = cpuOutput.map { SHA3Oracle.sha3_256(packQM31LittleEndian($0)).hexString }
    let inputBytes = Double(config.leafCount) * Double(4 * MemoryLayout<UInt32>.stride)
        + Double(outputCount) * Double(4 * MemoryLayout<UInt32>.stride)
    return QM31FRIFoldBenchmarkReport(
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
        fold: makeFieldMeasurement(
            wallSeconds: wallSeconds,
            gpuSeconds: gpuSeconds,
            elements: outputCount,
            inputBytes: inputBytes
        ),
        verification: QM31FRIFoldVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            outputDigestHex: outputDigest,
            cpuOutputDigestHex: cpuOutputDigest
        )
    )
    #else
    let cpuOutput = try QM31FRIFoldOracle.fold(
        evaluations: evaluations,
        inverseDomainPoints: inverseDomainPoints,
        challenge: challenge
    )
    let digest = SHA3Oracle.sha3_256(packQM31LittleEndian(cpuOutput)).hexString
    return QM31FRIFoldBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: configReport,
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        fold: nil,
        verification: QM31FRIFoldVerificationReport(
            enabled: true,
            matchedCPU: true,
            outputDigestHex: digest,
            cpuOutputDigestHex: digest
        )
    )
    #endif
}

@inline(never)
func runCircleFRIFoldBenchmark(_ config: BenchConfig) throws -> CircleFRIFoldBenchmarkReport {
    let domain = try CircleDomainDescriptor.canonical(logSize: UInt32(config.leafCount.trailingZeroBitCount))
    let outputCount = domain.halfSize
    let evaluations = makeDeterministicQM31Vector(
        count: domain.size,
        aSalt: 0xc31,
        bSalt: 0xc37,
        cSalt: 0xc3d,
        dSalt: 0xc43
    )
    let challenge = QM31Element(a: 41, b: 43, c: 47, d: 53)
    let configReport = makeCircleFRIFoldConfigReport(config: config)

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let cpuOutput = try CircleFRIFoldOracle.foldCircleIntoLine(
            evaluations: evaluations,
            domain: domain,
            challenge: challenge
        )
        let digest = SHA3Oracle.sha3_256(packQM31LittleEndian(cpuOutput)).hexString
        return CircleFRIFoldBenchmarkReport(
            schemaVersion: 1,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: configReport,
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            fold: nil,
            verification: CircleFRIFoldVerificationReport(
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
    let plan = try CircleFRIFoldPlan(context: context, domain: domain)
    try context.serializePipelineArchiveIfNeeded()

    let evaluationBuffer = try makeSharedMetalBuffer(
        device: device,
        bytes: packQM31LittleEndian(evaluations),
        label: "zkmetal-bench.CircleFRIFold.Evaluations"
    )
    let outputBuffer = try makeSharedMetalBuffer(
        device: device,
        length: outputCount * CircleFRIFoldPlan.elementByteCount,
        label: "zkmetal-bench.CircleFRIFold.Output"
    )

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try plan.executeResident(
                evaluationsBuffer: evaluationBuffer,
                outputBuffer: outputBuffer,
                challenge: challenge
            )
        }
    }

    var wallSeconds: [Double] = []
    var gpuSeconds: [Double?] = []
    for _ in 0..<config.iterations {
        let stats = try plan.executeResident(
            evaluationsBuffer: evaluationBuffer,
            outputBuffer: outputBuffer,
            challenge: challenge
        )
        wallSeconds.append(stats.cpuWallSeconds)
        gpuSeconds.append(stats.gpuSeconds)
    }

    let output = readQM31Buffer(outputBuffer, count: outputCount)
    let cpuOutput = config.verifyWithCPU
        ? try CircleFRIFoldOracle.foldCircleIntoLine(
            evaluations: evaluations,
            domain: domain,
            challenge: challenge
        )
        : nil
    let matchedCPU = cpuOutput.map { $0 == output }
    let outputDigest = SHA3Oracle.sha3_256(packQM31LittleEndian(output)).hexString
    let cpuOutputDigest = cpuOutput.map { SHA3Oracle.sha3_256(packQM31LittleEndian($0)).hexString }
    let inputBytes = Double(domain.size + domain.halfSize) * Double(CircleFRIFoldPlan.elementByteCount)
    return CircleFRIFoldBenchmarkReport(
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
        fold: makeFieldMeasurement(
            wallSeconds: wallSeconds,
            gpuSeconds: gpuSeconds,
            elements: outputCount,
            inputBytes: inputBytes
        ),
        verification: CircleFRIFoldVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            outputDigestHex: outputDigest,
            cpuOutputDigestHex: cpuOutputDigest
        )
    )
    #else
    let cpuOutput = try CircleFRIFoldOracle.foldCircleIntoLine(
        evaluations: evaluations,
        domain: domain,
        challenge: challenge
    )
    let digest = SHA3Oracle.sha3_256(packQM31LittleEndian(cpuOutput)).hexString
    return CircleFRIFoldBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: configReport,
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        fold: nil,
        verification: CircleFRIFoldVerificationReport(
            enabled: true,
            matchedCPU: true,
            outputDigestHex: digest,
            cpuOutputDigestHex: digest
        )
    )
    #endif
}

@inline(never)
func runCircleFRIFoldChainBenchmark(_ config: BenchConfig) throws -> CircleFRIFoldChainBenchmarkReport {
    let domain = try CircleDomainDescriptor.canonical(logSize: UInt32(config.leafCount.trailingZeroBitCount))
    let outputCount = domain.size >> config.friFoldRounds
    let totalInverseDomainCount = domain.size - outputCount
    let merkleTranscriptDerived = config.circleFRIFoldChainMerkleTranscript
    let evaluations = makeDeterministicQM31Vector(
        count: domain.size,
        aSalt: 0xcc1,
        bSalt: 0xcc7,
        cSalt: 0xccd,
        dSalt: 0xcd3
    )
    let challenges = makeDeterministicCircleFRIChallenges(roundCount: config.friFoldRounds)
    let security = try CircleFRISecurityParametersV1(
        logBlowupFactor: 2,
        queryCount: 4,
        foldingStep: 1,
        grindingBits: 0
    )
    let publicInputs = try CirclePCSFRIPublicInputsV1(
        publicInputDigest: Data((0..<32).map { UInt8(0x90 + $0) })
    )
    let configReport = makeCircleFRIFoldChainConfigReport(
        config: config,
        outputElementCount: outputCount,
        totalInverseDomainElementCount: totalInverseDomainCount
    )

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let cpuOutput = merkleTranscriptDerived
            ? try CircleFRIProofBuilderV1.prove(
                evaluations: evaluations,
                domain: domain,
                securityParameters: security,
                publicInputs: publicInputs,
                roundCount: config.friFoldRounds
            ).finalLayer
            : try CircleFRILayerOracleV1.fold(
                evaluations: evaluations,
                domain: domain,
                challenges: challenges
            )
        let digest = SHA3Oracle.sha3_256(packQM31LittleEndian(cpuOutput)).hexString
        return CircleFRIFoldChainBenchmarkReport(
            schemaVersion: 1,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: configReport,
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            foldChain: nil,
            queryExtraction: nil,
            proofEmission: nil,
            proofSizeBytes: nil,
            verification: CircleFRIFoldVerificationReport(
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
    let explicitPlan = merkleTranscriptDerived ? nil : try CircleFRIFoldChainPlan(
        context: context,
        domain: domain,
        roundCount: config.friFoldRounds
    )
    let merklePlan = merkleTranscriptDerived ? try CircleFRIMerkleTranscriptFoldChainPlan(
        context: context,
        domain: domain,
        securityParameters: security,
        publicInputs: publicInputs,
        roundCount: config.friFoldRounds
    ) : nil
    let residentProver = merkleTranscriptDerived ? try CirclePCSFRIResidentProverV1(
        context: context,
        domain: domain,
        securityParameters: security,
        publicInputs: publicInputs,
        roundCount: config.friFoldRounds
    ) : nil
    try context.serializePipelineArchiveIfNeeded()

    let evaluationBuffer = try makeSharedMetalBuffer(
        device: device,
        bytes: packQM31LittleEndian(evaluations),
        label: "zkmetal-bench.CircleFRIFoldChain.Evaluations"
    )
    let commitmentOutputBuffer = merkleTranscriptDerived
        ? try makeSharedMetalBuffer(
            device: device,
            length: config.friFoldRounds * CircleFRIMerkleTranscriptFoldChainPlan.commitmentByteCount,
            label: "zkmetal-bench.CircleFRIFoldChain.MerkleCommitments"
        )
        : nil
    let committedLayerBuffer = try merklePlan.map { plan in
        try makeSharedMetalBuffer(
            device: device,
            length: plan.totalCommittedLayerCount * CircleFRIMerkleTranscriptFoldChainPlan.elementByteCount,
            label: "zkmetal-bench.CircleFRIFoldChain.CommittedLayers"
        )
    }
    let outputBuffer = try makeSharedMetalBuffer(
        device: device,
        length: outputCount * CircleFRIFoldChainPlan.elementByteCount,
        label: "zkmetal-bench.CircleFRIFoldChain.Output"
    )

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            if let merklePlan, let commitmentOutputBuffer, let committedLayerBuffer {
                _ = try merklePlan.executeMaterializedResident(
                    evaluationsBuffer: evaluationBuffer,
                    committedLayerBuffer: committedLayerBuffer,
                    commitmentOutputBuffer: commitmentOutputBuffer,
                    outputBuffer: outputBuffer
                )
            } else if let explicitPlan {
                _ = try explicitPlan.executeResident(
                    evaluationsBuffer: evaluationBuffer,
                    outputBuffer: outputBuffer,
                    challenges: challenges
                )
            }
        }
    }

    var wallSeconds: [Double] = []
    var gpuSeconds: [Double?] = []
    for _ in 0..<config.iterations {
        let stats: GPUExecutionStats
        if let merklePlan, let commitmentOutputBuffer, let committedLayerBuffer {
            stats = try merklePlan.executeMaterializedResident(
                evaluationsBuffer: evaluationBuffer,
                committedLayerBuffer: committedLayerBuffer,
                commitmentOutputBuffer: commitmentOutputBuffer,
                outputBuffer: outputBuffer
            )
        } else if let explicitPlan {
            stats = try explicitPlan.executeResident(
                evaluationsBuffer: evaluationBuffer,
                outputBuffer: outputBuffer,
                challenges: challenges
            )
        } else {
            throw BenchError.invalidArgument("Circle FRI fold chain mode was not initialized.")
        }
        wallSeconds.append(stats.cpuWallSeconds)
        gpuSeconds.append(stats.gpuSeconds)
    }

    let output = readQM31Buffer(outputBuffer, count: outputCount)
    let expectedProof = config.verifyWithCPU && merkleTranscriptDerived
        ? try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: config.friFoldRounds
        )
        : nil
    let cpuOutput: [QM31Element]?
    if let expectedProof {
        cpuOutput = expectedProof.finalLayer
    } else {
        cpuOutput = config.verifyWithCPU
            ? try CircleFRILayerOracleV1.fold(
                evaluations: evaluations,
                domain: domain,
                challenges: challenges
            )
            : nil
    }
    let gpuCommitments = commitmentOutputBuffer.map {
        readQM31FRICommitments($0, count: config.friFoldRounds)
    }
    let queryExtraction: CircleFRIResidentQueryExtractionResult?
    let queryExtractionMeasurement: FieldMeasurementReport?
    if merkleTranscriptDerived,
       let gpuCommitments,
       let committedLayerBuffer,
       let merklePlan {
        let transcript = try CircleFRITranscriptV1.derive(
            domain: domain,
            securityParameters: security,
            publicInputDigest: publicInputs.publicInputDigest,
            commitments: gpuCommitments,
            finalLayer: output
        )
        let extractor = try CircleFRIResidentQueryExtractorV1(
            context: context,
            domain: domain,
            roundCount: config.friFoldRounds
        )
        if config.warmupIterations > 0 {
            for _ in 0..<config.warmupIterations {
                _ = try extractor.extractQueries(
                    committedLayerBuffer: committedLayerBuffer,
                    commitments: gpuCommitments,
                    queryPairIndices: transcript.queryPairIndices
                )
            }
        }

        var queryWallSeconds: [Double] = []
        var queryGPUSeconds: [Double?] = []
        var latestExtraction: CircleFRIResidentQueryExtractionResult?
        for _ in 0..<config.iterations {
            let result = try extractor.extractQueries(
                committedLayerBuffer: committedLayerBuffer,
                commitments: gpuCommitments,
                queryPairIndices: transcript.queryPairIndices
            )
            latestExtraction = result
            queryWallSeconds.append(result.stats.cpuWallSeconds)
            queryGPUSeconds.append(result.stats.gpuSeconds)
        }
        guard let measuredExtraction = latestExtraction else {
            throw BenchError.invalidArgument("--iterations must be greater than zero.")
        }
        queryExtraction = measuredExtraction
        let proofMaterialBytes = transcript.queryPairIndices.count
            * merklePlan.committedLayerCounts.reduce(0) { total, layerCount in
                total + 2 * (
                    CircleFRIResidentQueryExtractorV1.elementByteCount
                        + layerCount.trailingZeroBitCount * QM31FRIFoldTranscriptOracle.commitmentByteCount
                )
            }
        queryExtractionMeasurement = makeFieldMeasurement(
            wallSeconds: queryWallSeconds,
            gpuSeconds: queryGPUSeconds,
            elements: measuredExtraction.openingCount,
            inputBytes: Double(proofMaterialBytes)
        )
    } else {
        queryExtraction = nil
        queryExtractionMeasurement = nil
    }

    let proofEmissionResult: CirclePCSFRIResidentProverV1Result?
    let proofEmissionMeasurement: FieldMeasurementReport?
    if merkleTranscriptDerived,
       let residentProver {
        if config.warmupIterations > 0 {
            for _ in 0..<config.warmupIterations {
                _ = try residentProver.prove(evaluationsBuffer: evaluationBuffer)
            }
        }

        var proofWallSeconds: [Double] = []
        var proofGPUSeconds: [Double?] = []
        var latestProof: CirclePCSFRIResidentProverV1Result?
        for _ in 0..<config.iterations {
            let result = try residentProver.prove(evaluationsBuffer: evaluationBuffer)
            latestProof = result
            proofWallSeconds.append(result.stats.cpuWallSeconds)
            proofGPUSeconds.append(result.stats.gpuSeconds)
        }
        guard let measuredProof = latestProof else {
            throw BenchError.invalidArgument("--iterations must be greater than zero.")
        }
        proofEmissionResult = measuredProof
        proofEmissionMeasurement = makeFieldMeasurement(
            wallSeconds: proofWallSeconds,
            gpuSeconds: proofGPUSeconds,
            elements: 1,
            inputBytes: Double(measuredProof.proofByteCount)
        )
    } else {
        proofEmissionResult = nil
        proofEmissionMeasurement = nil
    }

    let residentProofVerifierOK: Bool?
    if config.verifyWithCPU,
       let proofEmissionResult {
        residentProofVerifierOK = try CirclePCSFRIProofVerifierV1.verify(
            proof: proofEmissionResult.proof,
            publicInputs: publicInputs
        )
    } else {
        residentProofVerifierOK = nil
    }

    let matchedCPU: Bool?
    if let expectedProof {
        matchedCPU = expectedProof.finalLayer == output
            && gpuCommitments == Optional(expectedProof.commitments)
            && queryExtraction.map(\.queries) == Optional(expectedProof.queries)
            && proofEmissionResult.map(\.proof) == Optional(expectedProof)
            && residentProofVerifierOK == Optional(true)
    } else {
        matchedCPU = cpuOutput.map { $0 == output }
    }
    let outputDigest = SHA3Oracle.sha3_256(packQM31LittleEndian(output)).hexString
    let cpuOutputDigest = cpuOutput.map { SHA3Oracle.sha3_256(packQM31LittleEndian($0)).hexString }
    let inverseElementCount = explicitPlan?.totalInverseDomainCount
        ?? merklePlan?.totalInverseDomainCount
        ?? totalInverseDomainCount
    let inputBytes = Double(domain.size + inverseElementCount) * Double(CircleFRIFoldChainPlan.elementByteCount)
        + Double(merkleTranscriptDerived ? config.friFoldRounds * CircleFRIMerkleTranscriptFoldChainPlan.commitmentByteCount : 0)
    return CircleFRIFoldChainBenchmarkReport(
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
        foldChain: makeFieldMeasurement(
            wallSeconds: wallSeconds,
            gpuSeconds: gpuSeconds,
            elements: outputCount,
            inputBytes: inputBytes
        ),
        queryExtraction: queryExtractionMeasurement,
        proofEmission: proofEmissionMeasurement,
        proofSizeBytes: proofEmissionResult?.proofByteCount,
        verification: CircleFRIFoldVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            outputDigestHex: outputDigest,
            cpuOutputDigestHex: cpuOutputDigest
        )
    )
    #else
    let cpuOutput = merkleTranscriptDerived
        ? try CircleFRIProofBuilderV1.prove(
            evaluations: evaluations,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: config.friFoldRounds
        ).finalLayer
        : try CircleFRILayerOracleV1.fold(
            evaluations: evaluations,
            domain: domain,
            challenges: challenges
        )
    let digest = SHA3Oracle.sha3_256(packQM31LittleEndian(cpuOutput)).hexString
    return CircleFRIFoldChainBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: configReport,
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        foldChain: nil,
        queryExtraction: nil,
        proofEmission: nil,
        proofSizeBytes: nil,
        verification: CircleFRIFoldVerificationReport(
            enabled: true,
            matchedCPU: true,
            outputDigestHex: digest,
            cpuOutputDigestHex: digest
        )
    )
    #endif
}

@inline(never)
func runCircleCodewordProverBenchmark(_ config: BenchConfig) throws -> CircleCodewordProverBenchmarkReport {
    let domain = try CircleDomainDescriptor.canonical(logSize: UInt32(config.leafCount.trailingZeroBitCount))
    let finalLayerCount = domain.size >> config.friFoldRounds
    let polynomial = try makeDeterministicCircleCodewordPolynomial(domainSize: domain.size)
    let queryCount: UInt32 = 4
    let security = try CircleFRISecurityParametersV1(
        logBlowupFactor: 2,
        queryCount: queryCount,
        foldingStep: 1,
        grindingBits: 0
    )
    let publicInputs = try CirclePCSFRIPublicInputsV1(
        publicInputDigest: Data((0..<32).map { UInt8(0xa0 + $0) })
    )
    let configReport = makeCircleCodewordProverConfigReport(
        config: config,
        polynomial: polynomial,
        finalLayerElementCount: finalLayerCount,
        queryCount: Int(queryCount)
    )

    let cpuCodeword = config.verifyWithCPU
        ? try CircleCodewordOracle.evaluate(polynomial: polynomial, domain: domain)
        : nil
    let expectedProof = try cpuCodeword.map {
        try CircleFRIProofBuilderV1.prove(
            evaluations: $0,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: config.friFoldRounds
        )
    }
    let expectedProofBytes = try expectedProof.map { try CirclePCSFRIProofCodecV1.encode($0) }

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let codeword: [QM31Element]
        if let cpuCodeword {
            codeword = cpuCodeword
        } else {
            codeword = try CircleCodewordOracle.evaluate(polynomial: polynomial, domain: domain)
        }
        let proof: CirclePCSFRIProofV1
        if let expectedProof {
            proof = expectedProof
        } else {
            proof = try CircleFRIProofBuilderV1.prove(
                evaluations: codeword,
                domain: domain,
                securityParameters: security,
                publicInputs: publicInputs,
                roundCount: config.friFoldRounds
            )
        }
        let proofBytes: Data
        if let expectedProofBytes {
            proofBytes = expectedProofBytes
        } else {
            proofBytes = try CirclePCSFRIProofCodecV1.encode(proof)
        }
        let codewordDigest = SHA3Oracle.sha3_256(packQM31LittleEndian(codeword)).hexString
        let proofDigest = SHA3Oracle.sha3_256(proofBytes).hexString
        let verifierAccepted = config.verifyWithCPU
            ? try CirclePCSFRIProofVerifierV1.verify(proof: proof, publicInputs: publicInputs)
            : nil
        return CircleCodewordProverBenchmarkReport(
            schemaVersion: 3,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: configReport,
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            codewordGeneration: nil,
            proofEmission: nil,
            fullProver: nil,
            proofSizeBytes: proofBytes.count,
            readbackPolicy: makeCircleCodewordProverReadbackPolicyReport(),
            verification: CircleCodewordProverVerificationReport(
                enabled: config.verifyWithCPU,
                matchedCPU: config.verifyWithCPU ? true : nil,
                verifierAccepted: verifierAccepted,
                codewordDigestHex: codewordDigest,
                codewordDigestSource: "cpu",
                cpuCodewordDigestHex: config.verifyWithCPU ? codewordDigest : nil,
                proofDigestHex: proofDigest,
                cpuProofDigestHex: config.verifyWithCPU ? proofDigest : nil
            )
        )
    }

    let archiveURL = config.pipelineArchiveURL ?? defaultPipelineArchiveURL(for: device)
    let pipelineCacheConfiguration = config.usePipelineArchive
        ? MetalPipelineCacheConfiguration(binaryArchiveMode: .readWrite(archiveURL))
        : .disabled
    let context = try MetalContext(device: device, pipelineCacheConfiguration: pipelineCacheConfiguration)
    let codewordPlan = try CircleCodewordPlan(context: context, domain: domain)
    let proofProver = try CirclePCSFRIResidentProverV1(
        context: context,
        domain: domain,
        securityParameters: security,
        publicInputs: publicInputs,
        roundCount: config.friFoldRounds
    )
    let fullProver = try CircleCodewordPCSFRIProverV1(
        context: context,
        domain: domain,
        securityParameters: security,
        publicInputs: publicInputs,
        roundCount: config.friFoldRounds
    )
    try context.serializePipelineArchiveIfNeeded()

    let codewordBuffer = try makePrivateMetalBuffer(
        device: device,
        length: domain.size * CircleCodewordPlan.elementByteCount,
        label: "zkmetal-bench.CircleCodewordProver.Codeword"
    )
    let circleCoefficientBytes = try QM31CanonicalEncoding.pack(
        CircleCodewordOracle.circleFFTCoefficients(
            polynomial: polynomial,
            domain: domain
        )
    )
    let circleCoefficientBuffer = try makePrivateMetalBuffer(
        context: context,
        bytes: circleCoefficientBytes,
        label: "zkmetal-bench.CircleCodewordProver.CircleFFTCoefficients"
    )

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try codewordPlan.executeResident(
                circleCoefficientBuffer: circleCoefficientBuffer,
                outputBuffer: codewordBuffer
            )
        }
    }

    var codewordWallSeconds: [Double] = []
    var codewordGPUSeconds: [Double?] = []
    for _ in 0..<config.iterations {
        let stats = try codewordPlan.executeResident(
            circleCoefficientBuffer: circleCoefficientBuffer,
            outputBuffer: codewordBuffer
        )
        codewordWallSeconds.append(stats.cpuWallSeconds)
        codewordGPUSeconds.append(stats.gpuSeconds)
    }

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try proofProver.prove(evaluationsBuffer: codewordBuffer)
        }
    }

    var proofWallSeconds: [Double] = []
    var proofGPUSeconds: [Double?] = []
    var latestProof: CirclePCSFRIResidentProverV1Result?
    for _ in 0..<config.iterations {
        let result = try proofProver.prove(evaluationsBuffer: codewordBuffer)
        latestProof = result
        proofWallSeconds.append(result.stats.cpuWallSeconds)
        proofGPUSeconds.append(result.stats.gpuSeconds)
    }
    guard let measuredProof = latestProof else {
        throw BenchError.invalidArgument("--iterations must be greater than zero.")
    }

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try fullProver.proveCircleFFTCoefficientsResident(
                circleCoefficientBuffer: circleCoefficientBuffer
            )
        }
    }

    var fullWallSeconds: [Double] = []
    var fullGPUSeconds: [Double?] = []
    var latestFullProof: CircleCodewordPCSFRIProverV1Result?
    for _ in 0..<config.iterations {
        let result = try fullProver.proveCircleFFTCoefficientsResident(
            circleCoefficientBuffer: circleCoefficientBuffer
        )
        latestFullProof = result
        fullWallSeconds.append(result.stats.cpuWallSeconds)
        fullGPUSeconds.append(result.stats.gpuSeconds)
    }
    guard let measuredFullProof = latestFullProof else {
        throw BenchError.invalidArgument("--iterations must be greater than zero.")
    }

    let verifierAccepted = config.verifyWithCPU
        ? try CirclePCSFRIProofVerifierV1.verify(
            proof: measuredFullProof.proof,
            publicInputs: publicInputs
        )
        : nil
    let matchedCPU: Bool?
    if let expectedProof {
        matchedCPU = measuredProof.proof == expectedProof
            && measuredFullProof.proof == expectedProof
            && verifierAccepted == Optional(true)
    } else {
        matchedCPU = nil
    }

    let cpuCodewordDigest = cpuCodeword.map { SHA3Oracle.sha3_256(packQM31LittleEndian($0)).hexString }
    let proofDigest = SHA3Oracle.sha3_256(measuredFullProof.encodedProof).hexString
    let cpuProofDigest = expectedProofBytes.map { SHA3Oracle.sha3_256($0).hexString }
    let fftCoefficientBytes = domain.size * CircleCodewordPlan.elementByteCount
    let fftTwiddleBytes = (domain.size - 1) * CircleCodewordPlan.twiddleElementByteCount
    let codewordInputBytes = Double(
        fftCoefficientBytes + fftTwiddleBytes
    )
    let proofInputBytes = Double(measuredProof.proofByteCount)

    return CircleCodewordProverBenchmarkReport(
        schemaVersion: 3,
        generatedAt: iso8601Now(),
        target: "metal",
        configuration: configReport,
        device: makeDeviceReport(context.capabilities),
        pipelineArchive: PipelineArchiveReport(
            enabled: config.usePipelineArchive,
            mode: config.usePipelineArchive ? "readWrite" : "disabled",
            path: config.usePipelineArchive ? archiveURL.path : nil
        ),
        codewordGeneration: makeFieldMeasurement(
            wallSeconds: codewordWallSeconds,
            gpuSeconds: codewordGPUSeconds,
            elements: domain.size,
            inputBytes: codewordInputBytes
        ),
        proofEmission: makeFieldMeasurement(
            wallSeconds: proofWallSeconds,
            gpuSeconds: proofGPUSeconds,
            elements: 1,
            inputBytes: proofInputBytes
        ),
        fullProver: makeFieldMeasurement(
            wallSeconds: fullWallSeconds,
            gpuSeconds: fullGPUSeconds,
            elements: 1,
            inputBytes: codewordInputBytes + Double(measuredFullProof.proofByteCount)
        ),
        proofSizeBytes: measuredFullProof.proofByteCount,
        readbackPolicy: makeCircleCodewordProverReadbackPolicyReport(),
        verification: CircleCodewordProverVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            verifierAccepted: verifierAccepted,
            codewordDigestHex: cpuCodewordDigest,
            codewordDigestSource: cpuCodewordDigest == nil ? "not-read-back" : "cpu-oracle-no-gpu-codeword-readback",
            cpuCodewordDigestHex: cpuCodewordDigest,
            proofDigestHex: proofDigest,
            cpuProofDigestHex: cpuProofDigest
        )
    )
    #else
    let codeword: [QM31Element]
    if let cpuCodeword {
        codeword = cpuCodeword
    } else {
        codeword = try CircleCodewordOracle.evaluate(polynomial: polynomial, domain: domain)
    }
    let proof: CirclePCSFRIProofV1
    if let expectedProof {
        proof = expectedProof
    } else {
        proof = try CircleFRIProofBuilderV1.prove(
            evaluations: codeword,
            domain: domain,
            securityParameters: security,
            publicInputs: publicInputs,
            roundCount: config.friFoldRounds
        )
    }
    let proofBytes: Data
    if let expectedProofBytes {
        proofBytes = expectedProofBytes
    } else {
        proofBytes = try CirclePCSFRIProofCodecV1.encode(proof)
    }
    let codewordDigest = SHA3Oracle.sha3_256(packQM31LittleEndian(codeword)).hexString
    let proofDigest = SHA3Oracle.sha3_256(proofBytes).hexString
    let verifierAccepted = config.verifyWithCPU
        ? try CirclePCSFRIProofVerifierV1.verify(proof: proof, publicInputs: publicInputs)
        : nil
    return CircleCodewordProverBenchmarkReport(
        schemaVersion: 3,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: configReport,
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        codewordGeneration: nil,
        proofEmission: nil,
        fullProver: nil,
        proofSizeBytes: proofBytes.count,
        readbackPolicy: makeCircleCodewordProverReadbackPolicyReport(),
        verification: CircleCodewordProverVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: config.verifyWithCPU ? verifierAccepted : nil,
            verifierAccepted: verifierAccepted,
            codewordDigestHex: codewordDigest,
            codewordDigestSource: "cpu",
            cpuCodewordDigestHex: config.verifyWithCPU ? codewordDigest : nil,
            proofDigestHex: proofDigest,
            cpuProofDigestHex: config.verifyWithCPU ? proofDigest : nil
        )
    )
    #endif
}

@inline(never)
func runQM31FRIFoldChainBenchmark(_ config: BenchConfig) throws -> QM31FRIFoldChainBenchmarkReport {
    let outputCount = config.leafCount >> config.friFoldRounds
    let totalInverseDomainCount = config.leafCount - outputCount
    let transcriptDerived = config.qm31FRIFoldChainTranscript
    let merkleTranscriptDerived = config.qm31FRIFoldChainMerkleTranscript
    let evaluations = makeDeterministicQM31Vector(
        count: config.leafCount,
        aSalt: 0xfa1,
        bSalt: 0xfa7,
        cSalt: 0xfad,
        dSalt: 0xfb3
    )
    let rounds = makeDeterministicQM31FRIFoldRounds(
        inputCount: config.leafCount,
        roundCount: config.friFoldRounds,
        saltBase: 0xfc1
    )
    let challenges = rounds.map(\.challenge)
    let inverseDomainLayers = rounds.map(\.inverseDomainPoints)
    let roundCommitments = transcriptDerived
        ? makeDeterministicQM31FRICommitments(count: config.friFoldRounds, salt: 0xfd1)
        : []
    let configReport = makeQM31FRIFoldChainConfigReport(
        config: config,
        outputElementCount: outputCount,
        totalInverseDomainElementCount: totalInverseDomainCount
    )

    #if canImport(Metal)
    guard let device = MTLCreateSystemDefaultDevice() else {
        let cpuOutput = merkleTranscriptDerived
            ? try QM31FRIMerkleFoldChainOracle.commitAndFold(
                evaluations: evaluations,
                inverseDomainLayers: inverseDomainLayers
            ).values
            : transcriptDerived
            ? try QM31FRIFoldTranscriptOracle.fold(
                evaluations: evaluations,
                inverseDomainLayers: inverseDomainLayers,
                roundCommitments: roundCommitments
            ).values
            : try QM31FRIFoldChainOracle.fold(evaluations: evaluations, rounds: rounds)
        let digest = SHA3Oracle.sha3_256(packQM31LittleEndian(cpuOutput)).hexString
        return QM31FRIFoldChainBenchmarkReport(
            schemaVersion: 1,
            generatedAt: iso8601Now(),
            target: "cpu",
            configuration: configReport,
            device: nil,
            pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
            foldChain: nil,
            verification: QM31FRIFoldChainVerificationReport(
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
    let plan = try QM31FRIFoldChainPlan(
        context: context,
        inputCount: config.leafCount,
        roundCount: config.friFoldRounds
    )
    try context.serializePipelineArchiveIfNeeded()

    let evaluationBuffer = try makeSharedMetalBuffer(
        device: device,
        bytes: packQM31LittleEndian(evaluations),
        label: "zkmetal-bench.QM31FRIFoldChain.Evaluations"
    )
    let inverseDomainBuffer = try makeSharedMetalBuffer(
        device: device,
        bytes: packQM31FRIFoldInverseDomains(rounds),
        label: "zkmetal-bench.QM31FRIFoldChain.InverseDomain"
    )
    let commitmentBuffer = transcriptDerived
        ? try makeSharedMetalBuffer(
            device: device,
            bytes: packQM31FRICommitments(roundCommitments),
            label: "zkmetal-bench.QM31FRIFoldChain.Commitments"
        )
        : nil
    let commitmentOutputBuffer = merkleTranscriptDerived
        ? try makeSharedMetalBuffer(
            device: device,
            length: config.friFoldRounds * QM31FRIFoldTranscriptOracle.commitmentByteCount,
            label: "zkmetal-bench.QM31FRIFoldChain.MerkleCommitments"
        )
        : nil
    let outputBuffer = try makeSharedMetalBuffer(
        device: device,
        length: outputCount * 4 * MemoryLayout<UInt32>.stride,
        label: "zkmetal-bench.QM31FRIFoldChain.Output"
    )

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            if merkleTranscriptDerived, let commitmentOutputBuffer {
                _ = try plan.executeMerkleTranscriptDerivedResident(
                    evaluationsBuffer: evaluationBuffer,
                    inverseDomainBuffer: inverseDomainBuffer,
                    commitmentOutputBuffer: commitmentOutputBuffer,
                    outputBuffer: outputBuffer
                )
            } else if transcriptDerived, let commitmentBuffer {
                _ = try plan.executeTranscriptDerivedResident(
                    evaluationsBuffer: evaluationBuffer,
                    inverseDomainBuffer: inverseDomainBuffer,
                    roundCommitmentsBuffer: commitmentBuffer,
                    outputBuffer: outputBuffer
                )
            } else {
                _ = try plan.executeResident(
                    evaluationsBuffer: evaluationBuffer,
                    inverseDomainBuffer: inverseDomainBuffer,
                    outputBuffer: outputBuffer,
                    challenges: challenges
                )
            }
        }
    }

    var wallSeconds: [Double] = []
    var gpuSeconds: [Double?] = []
    for _ in 0..<config.iterations {
        let stats: GPUExecutionStats
        if merkleTranscriptDerived, let commitmentOutputBuffer {
            stats = try plan.executeMerkleTranscriptDerivedResident(
                evaluationsBuffer: evaluationBuffer,
                inverseDomainBuffer: inverseDomainBuffer,
                commitmentOutputBuffer: commitmentOutputBuffer,
                outputBuffer: outputBuffer
            )
        } else if transcriptDerived, let commitmentBuffer {
            stats = try plan.executeTranscriptDerivedResident(
                evaluationsBuffer: evaluationBuffer,
                inverseDomainBuffer: inverseDomainBuffer,
                roundCommitmentsBuffer: commitmentBuffer,
                outputBuffer: outputBuffer
            )
        } else {
            stats = try plan.executeResident(
                evaluationsBuffer: evaluationBuffer,
                inverseDomainBuffer: inverseDomainBuffer,
                outputBuffer: outputBuffer,
                challenges: challenges
            )
        }
        wallSeconds.append(stats.cpuWallSeconds)
        gpuSeconds.append(stats.gpuSeconds)
    }

    let output = readQM31Buffer(outputBuffer, count: outputCount)
    let cpuResult: QM31FRIMerkleFoldChainOracleResult?
    let cpuOutput: [QM31Element]?
    if config.verifyWithCPU {
        if merkleTranscriptDerived {
            let expected = try QM31FRIMerkleFoldChainOracle.commitAndFold(
                evaluations: evaluations,
                inverseDomainLayers: inverseDomainLayers
            )
            cpuResult = expected
            cpuOutput = expected.values
        } else {
            cpuResult = nil
            cpuOutput = transcriptDerived
            ? try QM31FRIFoldTranscriptOracle.fold(
                evaluations: evaluations,
                inverseDomainLayers: inverseDomainLayers,
                roundCommitments: roundCommitments
            ).values
            : try QM31FRIFoldChainOracle.fold(evaluations: evaluations, rounds: rounds)
        }
    } else {
        cpuResult = nil
        cpuOutput = nil
    }
    let gpuCommitments = commitmentOutputBuffer.map { readQM31FRICommitments($0, count: config.friFoldRounds) }
    let matchedCPU: Bool?
    if let cpuResult {
        matchedCPU = cpuResult.values == output && cpuResult.commitments == gpuCommitments
    } else {
        matchedCPU = cpuOutput.map { $0 == output }
    }
    let outputDigest = SHA3Oracle.sha3_256(packQM31LittleEndian(output)).hexString
    let cpuOutputDigest = cpuOutput.map { SHA3Oracle.sha3_256(packQM31LittleEndian($0)).hexString }
    let inputBytes = Double(config.leafCount + totalInverseDomainCount)
        * Double(4 * MemoryLayout<UInt32>.stride)
        + Double(transcriptDerived ? roundCommitments.count * QM31FRIFoldTranscriptOracle.commitmentByteCount : 0)
        + Double(merkleTranscriptDerived ? config.friFoldRounds * QM31FRIFoldTranscriptOracle.commitmentByteCount : 0)
    return QM31FRIFoldChainBenchmarkReport(
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
        foldChain: makeFieldMeasurement(
            wallSeconds: wallSeconds,
            gpuSeconds: gpuSeconds,
            elements: outputCount,
            inputBytes: inputBytes
        ),
        verification: QM31FRIFoldChainVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            outputDigestHex: outputDigest,
            cpuOutputDigestHex: cpuOutputDigest
        )
    )
    #else
    let cpuOutput = merkleTranscriptDerived
        ? try QM31FRIMerkleFoldChainOracle.commitAndFold(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers
        ).values
        : transcriptDerived
        ? try QM31FRIFoldTranscriptOracle.fold(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers,
            roundCommitments: roundCommitments
        ).values
        : try QM31FRIFoldChainOracle.fold(evaluations: evaluations, rounds: rounds)
    let digest = SHA3Oracle.sha3_256(packQM31LittleEndian(cpuOutput)).hexString
    return QM31FRIFoldChainBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: configReport,
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        foldChain: nil,
        verification: QM31FRIFoldChainVerificationReport(
            enabled: true,
            matchedCPU: true,
            outputDigestHex: digest,
            cpuOutputDigestHex: digest
        )
    )
    #endif
}

@inline(never)
func runQM31FRIProofBenchmark(_ config: BenchConfig) throws -> QM31FRIProofBenchmarkReport {
    let outputCount = config.leafCount >> config.friFoldRounds
    let totalInverseDomainCount = config.leafCount - outputCount
    let evaluations = makeDeterministicQM31Vector(
        count: config.leafCount,
        aSalt: 0xfa1,
        bSalt: 0xfa7,
        cSalt: 0xfad,
        dSalt: 0xfb3
    )
    let rounds = makeDeterministicQM31FRIFoldRounds(
        inputCount: config.leafCount,
        roundCount: config.friFoldRounds,
        saltBase: 0xfc1
    )
    let inverseDomainLayers = rounds.map(\.inverseDomainPoints)
    let configReport = makeQM31FRIProofConfigReport(
        config: config,
        finalLayerElementCount: outputCount,
        totalInverseDomainElementCount: totalInverseDomainCount
    )

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try QM31FRIProofBuilder.prove(
                evaluations: evaluations,
                inverseDomainLayers: inverseDomainLayers,
                queryCount: config.friQueryCount
            )
        }
    }

    var buildWallSeconds: [Double] = []
    var measuredProof: QM31FRIProof?
    for _ in 0..<config.iterations {
        let start = DispatchTime.now()
        let proof = try QM31FRIProofBuilder.prove(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers,
            queryCount: config.friQueryCount
        )
        let end = DispatchTime.now()
        measuredProof = proof
        buildWallSeconds.append(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000)
    }
    guard let measuredProof else {
        throw BenchError.invalidArgument("--iterations must be greater than zero.")
    }

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try measuredProof.serialized()
        }
    }

    var serializationWallSeconds: [Double] = []
    var measuredProofBytes: Data?
    for _ in 0..<config.iterations {
        let start = DispatchTime.now()
        let bytes = try measuredProof.serialized()
        let end = DispatchTime.now()
        measuredProofBytes = bytes
        serializationWallSeconds.append(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000)
    }
    guard let measuredProofBytes else {
        throw BenchError.invalidArgument("--iterations must be greater than zero.")
    }

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try QM31FRIProof.deserialize(measuredProofBytes)
        }
    }

    var deserializationWallSeconds: [Double] = []
    var decodedProof: QM31FRIProof?
    for _ in 0..<config.iterations {
        let start = DispatchTime.now()
        let proof = try QM31FRIProof.deserialize(measuredProofBytes)
        let end = DispatchTime.now()
        decodedProof = proof
        deserializationWallSeconds.append(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000)
    }
    guard let decodedProof else {
        throw BenchError.invalidArgument("--iterations must be greater than zero.")
    }

    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try QM31FRIProofVerifier.verify(
                proof: decodedProof,
                inverseDomainLayers: inverseDomainLayers
            )
        }
    }

    var verificationWallSeconds: [Double] = []
    var verifierAccepted = false
    for _ in 0..<config.iterations {
        let start = DispatchTime.now()
        let accepted = try QM31FRIProofVerifier.verify(
            proof: decodedProof,
            inverseDomainLayers: inverseDomainLayers
        )
        let end = DispatchTime.now()
        verifierAccepted = accepted
        verificationWallSeconds.append(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000)
    }

    let cpuProof = config.verifyWithCPU
        ? try QM31FRIProofBuilder.prove(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers,
            queryCount: config.friQueryCount
        )
        : nil
    let cpuCommitted = config.verifyWithCPU
        ? try QM31FRIMerkleFoldChainOracle.commitAndFold(
            evaluations: evaluations,
            inverseDomainLayers: inverseDomainLayers
        )
        : nil
    let cpuProofBytes = try cpuProof.map { try $0.serialized() }
    let proofDigest = SHA3Oracle.sha3_256(measuredProofBytes).hexString
    let cpuProofDigest = cpuProofBytes.map { SHA3Oracle.sha3_256($0).hexString }
    let finalLayerDigest = SHA3Oracle.sha3_256(packQM31LittleEndian(measuredProof.finalValues)).hexString
    let cpuFinalLayerDigest = cpuCommitted.map { SHA3Oracle.sha3_256(packQM31LittleEndian($0.values)).hexString }
    let matchedCPU: Bool?
    if let cpuProof, let cpuCommitted {
        matchedCPU = decodedProof == measuredProof
            && measuredProof == cpuProof
            && measuredProof.finalValues == cpuCommitted.values
            && measuredProof.commitments == cpuCommitted.commitments
            && verifierAccepted
    } else {
        matchedCPU = nil
    }

    let emptyGPUSamples = Array<Double?>(repeating: nil, count: config.iterations)
    let fieldElementByteCount = Double(QM31CanonicalEncoding.elementByteCount)
    let proofBuildInputBytes = Double(config.leafCount + totalInverseDomainCount) * fieldElementByteCount
    let proofByteCount = measuredProofBytes.count
    let verifierInputBytes = Double(proofByteCount) + Double(totalInverseDomainCount) * fieldElementByteCount

    return QM31FRIProofBenchmarkReport(
        schemaVersion: 1,
        generatedAt: iso8601Now(),
        target: "cpu",
        configuration: configReport,
        device: nil,
        pipelineArchive: PipelineArchiveReport(enabled: false, mode: "unavailable", path: nil),
        proofBuild: makeFieldMeasurement(
            wallSeconds: buildWallSeconds,
            gpuSeconds: emptyGPUSamples,
            elements: 1,
            inputBytes: proofBuildInputBytes
        ),
        serialization: makeFieldMeasurement(
            wallSeconds: serializationWallSeconds,
            gpuSeconds: emptyGPUSamples,
            elements: 1,
            inputBytes: Double(proofByteCount)
        ),
        deserialization: makeFieldMeasurement(
            wallSeconds: deserializationWallSeconds,
            gpuSeconds: emptyGPUSamples,
            elements: 1,
            inputBytes: Double(proofByteCount)
        ),
        proofVerification: makeFieldMeasurement(
            wallSeconds: verificationWallSeconds,
            gpuSeconds: emptyGPUSamples,
            elements: 1,
            inputBytes: verifierInputBytes
        ),
        proofSizeBytes: proofByteCount,
        queryOpeningCount: config.friQueryCount * config.friFoldRounds * 2,
        verification: QM31FRIProofVerificationReport(
            enabled: config.verifyWithCPU,
            matchedCPU: matchedCPU,
            verifierAccepted: verifierAccepted,
            proofDigestHex: proofDigest,
            cpuProofDigestHex: cpuProofDigest,
            finalLayerDigestHex: finalLayerDigest,
            cpuFinalLayerDigestHex: cpuFinalLayerDigest
        )
    )
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
        } else if config.cm31VectorMultiply {
            let report = try runCM31VectorMultiplyBenchmark(config)
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
        } else if config.qm31VectorMultiply || config.qm31VectorInverse {
            let operation: QM31VectorOperation = config.qm31VectorInverse ? .inverse : .multiply
            let report = try runQM31VectorBenchmark(config, operation: operation)
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
        } else if config.qm31FRIFold {
            let report = try runQM31FRIFoldBenchmark(config)
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
        } else if config.circleFRIFold {
            let report = try runCircleFRIFoldBenchmark(config)
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
        } else if config.circleFRIFoldChain || config.circleFRIFoldChainMerkleTranscript {
            let report = try runCircleFRIFoldChainBenchmark(config)
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
        } else if config.circleCodewordProver {
            let report = try runCircleCodewordProverBenchmark(config)
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
        } else if config.qm31FRIFoldChain || config.qm31FRIFoldChainTranscript || config.qm31FRIFoldChainMerkleTranscript {
            let report = try runQM31FRIFoldChainBenchmark(config)
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
        } else if config.qm31FRIProof {
            let report = try runQM31FRIProofBenchmark(config)
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
