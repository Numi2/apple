import CommonCrypto
import CryptoKit
import Foundation
import Security

public enum SLHDSA {
    public enum DomainSeparator {
        public static let pure: UInt8 = 0
        public static let preHash: UInt8 = 1
    }

    public enum HashFamily: Sendable {
        case sha2
        case shake
    }

    public enum ParameterSet: String, CaseIterable, Sendable {
        case sha2_128s = "SLH-DSA-SHA2-128s"
        case shake_128s = "SLH-DSA-SHAKE-128s"
        case sha2_128f = "SLH-DSA-SHA2-128f"
        case shake_128f = "SLH-DSA-SHAKE-128f"
        case sha2_192s = "SLH-DSA-SHA2-192s"
        case shake_192s = "SLH-DSA-SHAKE-192s"
        case sha2_192f = "SLH-DSA-SHA2-192f"
        case shake_192f = "SLH-DSA-SHAKE-192f"
        case sha2_256s = "SLH-DSA-SHA2-256s"
        case shake_256s = "SLH-DSA-SHAKE-256s"
        case sha2_256f = "SLH-DSA-SHA2-256f"
        case shake_256f = "SLH-DSA-SHAKE-256f"

        public var parameters: Parameters {
            switch self {
            case .sha2_128s: return Parameters(name: rawValue, family: .sha2, n: 16, h: 63, d: 7, hp: 9, a: 12, k: 14, lgW: 4, m: 30)
            case .shake_128s: return Parameters(name: rawValue, family: .shake, n: 16, h: 63, d: 7, hp: 9, a: 12, k: 14, lgW: 4, m: 30)
            case .sha2_128f: return Parameters(name: rawValue, family: .sha2, n: 16, h: 66, d: 22, hp: 3, a: 6, k: 33, lgW: 4, m: 34)
            case .shake_128f: return Parameters(name: rawValue, family: .shake, n: 16, h: 66, d: 22, hp: 3, a: 6, k: 33, lgW: 4, m: 34)
            case .sha2_192s: return Parameters(name: rawValue, family: .sha2, n: 24, h: 63, d: 7, hp: 9, a: 14, k: 17, lgW: 4, m: 39)
            case .shake_192s: return Parameters(name: rawValue, family: .shake, n: 24, h: 63, d: 7, hp: 9, a: 14, k: 17, lgW: 4, m: 39)
            case .sha2_192f: return Parameters(name: rawValue, family: .sha2, n: 24, h: 66, d: 22, hp: 3, a: 8, k: 33, lgW: 4, m: 42)
            case .shake_192f: return Parameters(name: rawValue, family: .shake, n: 24, h: 66, d: 22, hp: 3, a: 8, k: 33, lgW: 4, m: 42)
            case .sha2_256s: return Parameters(name: rawValue, family: .sha2, n: 32, h: 64, d: 8, hp: 8, a: 14, k: 22, lgW: 4, m: 47)
            case .shake_256s: return Parameters(name: rawValue, family: .shake, n: 32, h: 64, d: 8, hp: 8, a: 14, k: 22, lgW: 4, m: 47)
            case .sha2_256f: return Parameters(name: rawValue, family: .sha2, n: 32, h: 68, d: 17, hp: 4, a: 9, k: 35, lgW: 4, m: 49)
            case .shake_256f: return Parameters(name: rawValue, family: .shake, n: 32, h: 68, d: 17, hp: 4, a: 9, k: 35, lgW: 4, m: 49)
            }
        }
    }

    public enum PreHashFunction: String, CaseIterable, Sendable {
        case sha2_256 = "SHA2-256"
        case sha2_384 = "SHA2-384"
        case sha2_512 = "SHA2-512"
        case sha2_224 = "SHA2-224"
        case sha2_512_224 = "SHA2-512/224"
        case sha2_512_256 = "SHA2-512/256"
        case sha3_224 = "SHA3-224"
        case sha3_256 = "SHA3-256"
        case sha3_384 = "SHA3-384"
        case sha3_512 = "SHA3-512"
        case shake128 = "SHAKE-128"
        case shake256 = "SHAKE-256"

        public var derEncodedOID: Data {
            Data(derOID)
        }

        public var phOID: Data {
            derEncodedOID
        }

        var derOID: [UInt8] {
            switch self {
            case .sha2_256: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01]
            case .sha2_384: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x02]
            case .sha2_512: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03]
            case .sha2_224: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x04]
            case .sha2_512_224: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x05]
            case .sha2_512_256: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x06]
            case .sha3_224: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x07]
            case .sha3_256: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x08]
            case .sha3_384: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x09]
            case .sha3_512: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x0a]
            case .shake128: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x0b]
            case .shake256: return [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x0c]
            }
        }
    }

    public struct Parameters: Sendable, Equatable {
        public let name: String
        public let family: HashFamily
        public let n: Int
        public let h: Int
        public let d: Int
        public let hp: Int
        public let a: Int
        public let k: Int
        public let lgW: Int
        public let m: Int

        public var w: Int { 1 << lgW }
        public var len1: Int { (8 * n + (lgW - 1)) / lgW }
        public var len2: Int {
            var value = len1 * (w - 1)
            var bits = 0
            while value > 0 {
                bits += 1
                value >>= 1
            }
            return (bits - 1) / lgW + 1
        }
        public var len: Int { len1 + len2 }
        public var publicKeyByteCount: Int { 2 * n }
        public var privateKeyByteCount: Int { 4 * n }
        public var signatureByteCount: Int { (1 + k * (1 + a) + h + d * len) * n }
    }

    public struct KeyPair: Sendable, Equatable {
        public let publicKey: Data
        public let privateKey: Data
    }

    public struct PublicKey: Sendable, Equatable {
        public let parameterSet: ParameterSet
        public let pkSeed: Data
        public let pkRoot: Data

        public var encoded: Data { pkSeed + pkRoot }

        public init(encoded: Data, parameterSet: ParameterSet) throws {
            let p = parameterSet.parameters
            guard encoded.count == p.publicKeyByteCount else {
                throw AppleZKProverError.invalidInputLayout
            }
            self.parameterSet = parameterSet
            self.pkSeed = encoded.subdata(in: 0..<p.n)
            self.pkRoot = encoded.subdata(in: p.n..<(2 * p.n))
        }
    }

    public struct PrivateKey: Sendable, Equatable {
        public let parameterSet: ParameterSet
        public let skSeed: Data
        public let skPrf: Data
        public let pkSeed: Data
        public let pkRoot: Data

        public var encoded: Data { skSeed + skPrf + pkSeed + pkRoot }
        public var publicKey: PublicKey {
            try! PublicKey(encoded: pkSeed + pkRoot, parameterSet: parameterSet)
        }

        public init(encoded: Data, parameterSet: ParameterSet) throws {
            let p = parameterSet.parameters
            guard encoded.count == p.privateKeyByteCount else {
                throw AppleZKProverError.invalidInputLayout
            }
            self.parameterSet = parameterSet
            self.skSeed = encoded.subdata(in: 0..<p.n)
            self.skPrf = encoded.subdata(in: p.n..<(2 * p.n))
            self.pkSeed = encoded.subdata(in: (2 * p.n)..<(3 * p.n))
            self.pkRoot = encoded.subdata(in: (3 * p.n)..<(4 * p.n))
        }
    }

    public struct Signature: Sendable, Equatable {
        public let parameterSet: ParameterSet
        public let randomness: Data
        public let forsSignature: Data
        public let hypertreeSignature: Data

        public var encoded: Data { randomness + forsSignature + hypertreeSignature }

        public init(encoded: Data, parameterSet: ParameterSet) throws {
            let p = parameterSet.parameters
            guard encoded.count == p.signatureByteCount else {
                throw AppleZKProverError.invalidInputLayout
            }
            let forsLength = p.k * (1 + p.a) * p.n
            self.parameterSet = parameterSet
            self.randomness = encoded.subdata(in: 0..<p.n)
            self.forsSignature = encoded.subdata(in: p.n..<(p.n + forsLength))
            self.hypertreeSignature = encoded.subdata(in: (p.n + forsLength)..<encoded.count)
        }

        public func xmssSignature(layer: Int) throws -> Data {
            let p = parameterSet.parameters
            guard layer >= 0, layer < p.d else {
                throw AppleZKProverError.invalidInputLayout
            }
            let xmssLength = (p.hp + p.len) * p.n
            let start = layer * xmssLength
            return hypertreeSignature.subdata(in: start..<(start + xmssLength))
        }
    }

    public struct Address: Sendable, Equatable {
        public enum AddressType: Int, Sendable {
            case wotsHash = 0
            case wotsPK = 1
            case tree = 2
            case forsTree = 3
            case forsRoots = 4
            case wotsPRF = 5
            case forsPRF = 6
        }

        private var bytes: [UInt8]

        public init() {
            self.bytes = Array(repeating: 0, count: 32)
        }

        public init(encoded: Data) throws {
            guard encoded.count == 32 else {
                throw AppleZKProverError.invalidInputLayout
            }
            self.bytes = Array(encoded)
        }

        public var encoded: Data { Data(bytes) }
        public var compressedSHA2Encoded: Data {
            var out = Data()
            out.reserveCapacity(22)
            out.append(bytes[3])
            out.append(contentsOf: bytes[8..<16])
            out.append(bytes[19])
            out.append(contentsOf: bytes[20..<32])
            return out
        }

        public mutating func setLayerAddress(_ value: Int) { store(UInt64(value), offset: 0, count: 4) }
        public mutating func setTreeAddress(_ value: UInt64) {
            store(0, offset: 4, count: 4)
            store(value, offset: 8, count: 8)
        }
        public mutating func setTypeAndClear(_ type: AddressType) {
            store(UInt64(type.rawValue), offset: 16, count: 4)
            for index in 20..<32 {
                bytes[index] = 0
            }
        }
        public mutating func setKeyPairAddress(_ value: Int) { store(UInt64(value), offset: 20, count: 4) }
        public mutating func setChainAddress(_ value: Int) { store(UInt64(value), offset: 24, count: 4) }
        public mutating func setTreeHeight(_ value: Int) { store(UInt64(value), offset: 24, count: 4) }
        public mutating func setHashAddress(_ value: Int) { store(UInt64(value), offset: 28, count: 4) }
        public mutating func setTreeIndex(_ value: Int) { store(UInt64(value), offset: 28, count: 4) }

        public var keyPairAddress: Int { Int(load(offset: 20, count: 4)) }
        public var treeIndex: Int { Int(load(offset: 28, count: 4)) }

        private mutating func store(_ value: UInt64, offset: Int, count: Int) {
            for i in 0..<count {
                let shift = UInt64((count - 1 - i) * 8)
                bytes[offset + i] = UInt8((value >> shift) & 0xff)
            }
        }

        private func load(offset: Int, count: Int) -> UInt64 {
            var value: UInt64 = 0
            for i in 0..<count {
                value = (value << 8) | UInt64(bytes[offset + i])
            }
            return value
        }
    }

    public enum FIPSHelper {
        public static func toByte(_ value: UInt64, byteCount: Int) throws -> Data {
            guard byteCount >= 0 else {
                throw AppleZKProverError.invalidInputLayout
            }
            var out = [UInt8](repeating: 0, count: byteCount)
            var x = value
            for i in 0..<byteCount {
                out[byteCount - 1 - i] = UInt8(x & 0xff)
                x >>= 8
            }
            guard x == 0 else {
                throw AppleZKProverError.invalidInputLayout
            }
            return Data(out)
        }

        public static func to_byte(_ value: UInt64, byteCount: Int) throws -> Data {
            try toByte(value, byteCount: byteCount)
        }

        public static func toInt(_ bytes: Data) throws -> UInt64 {
            guard bytes.count <= 8 else {
                throw AppleZKProverError.invalidInputLayout
            }
            return toUInt64(bytes)
        }

        public static func to_int(_ bytes: Data) throws -> UInt64 {
            try toInt(bytes)
        }

        public static func base2b(_ bytes: Data, bits: Int, outputLength: Int) throws -> [Int] {
            guard bits > 0, bits <= 30, outputLength >= 0,
                  bytes.count * 8 >= bits * outputLength else {
                throw AppleZKProverError.invalidInputLayout
            }
            return slhBase2b(bytes, bits: bits, outputLength: outputLength)
        }

        public static func base_2b(_ bytes: Data, bits: Int, outputLength: Int) throws -> [Int] {
            try base2b(bytes, bits: bits, outputLength: outputLength)
        }
    }

    public enum HashPrimitives {
        public static func sha256(_ data: Data) -> Data { slhSHA256(data) }
        public static func sha512(_ data: Data) -> Data { slhSHA512(data) }
        public static func hmacSHA256(key: Data, message: Data) -> Data { slhHMACSHA256(key: key, message: message) }
        public static func hmacSHA512(key: Data, message: Data) -> Data { slhHMACSHA512(key: key, message: message) }
        public static func mgf1SHA256(seed: Data, outputByteCount: Int) throws -> Data {
            guard outputByteCount >= 0 else { throw AppleZKProverError.invalidInputLayout }
            return mgfSHA256(seed, outputByteCount: outputByteCount)
        }
        public static func mgf1SHA512(seed: Data, outputByteCount: Int) throws -> Data {
            guard outputByteCount >= 0 else { throw AppleZKProverError.invalidInputLayout }
            return mgfSHA512(seed, outputByteCount: outputByteCount)
        }
        public static func shake128(_ data: Data, outputByteCount: Int) throws -> Data {
            try SHA3Oracle.shake128(data, outputByteCount: outputByteCount)
        }
        public static func shake256(_ data: Data, outputByteCount: Int) throws -> Data {
            try SHA3Oracle.shake256(data, outputByteCount: outputByteCount)
        }
        public static func keccakF1600(_ lanes: [UInt64]) throws -> [UInt64] {
            try SHA3Oracle.keccakF1600Permutation(lanes)
        }
    }

    public enum ArithmetizationGadget: String, CaseIterable, Sendable {
        case sha256 = "SHA-256"
        case sha512 = "SHA-512"
        case hmac = "HMAC"
        case mgf1 = "MGF1"
        case shake128 = "SHAKE128"
        case shake256 = "SHAKE256"
        case keccakF1600 = "Keccak-f[1600]"
        case addressEncoding = "ADRS"
        case compressedSHA2AddressEncoding = "ADRS_c"
        case wotsChains = "WOTS+ chains"
        case forsTrees = "FORS trees"
        case xmssAuthPaths = "XMSS auth paths"
        case hypertreeVerification = "Hypertree verification"

        public func descriptor(parameters: Parameters) -> ArithmetizationDescriptor {
            switch self {
            case .sha256:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: nil, outputByteCount: 32, rounds: 64, notes: "FIPS 180-4 SHA-256 compression and padding.")
            case .sha512:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: nil, outputByteCount: 64, rounds: 80, notes: "FIPS 180-4 SHA-512 compression and padding.")
            case .hmac:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: nil, outputByteCount: parameters.n, rounds: nil, notes: "FIPS 198-1 HMAC-SHA-256 for n=16; HMAC-SHA-512 for n=24/32.")
            case .mgf1:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: nil, outputByteCount: parameters.m, rounds: nil, notes: "MGF1-SHA-256 for category 1 SHA2; MGF1-SHA-512 for category 3/5 SHA2.")
            case .shake128:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: nil, outputByteCount: 32, rounds: 24, notes: "SHAKE128 XOF over Keccak-f[1600].")
            case .shake256:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: nil, outputByteCount: parameters.n, rounds: 24, notes: "SHAKE256 XOF over Keccak-f[1600].")
            case .keccakF1600:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: 200, outputByteCount: 200, rounds: 24, notes: "Keccak-f[1600] permutation over 25 64-bit lanes.")
            case .addressEncoding:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: 32, outputByteCount: 32, rounds: nil, notes: "FIPS 205 32-byte ADRS encoding.")
            case .compressedSHA2AddressEncoding:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: 32, outputByteCount: 22, rounds: nil, notes: "FIPS 205 ADRS_c = ADRS[3] || ADRS[8:16] || ADRS[19] || ADRS[20:32].")
            case .wotsChains:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: parameters.n, outputByteCount: parameters.n, rounds: parameters.w - 1, notes: "WOTS+ chain F/H calls per chain; len=\(parameters.len).")
            case .forsTrees:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: parameters.n, outputByteCount: parameters.n, rounds: parameters.a, notes: "FORS authentication tree verification for k=\(parameters.k), a=\(parameters.a).")
            case .xmssAuthPaths:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: parameters.n, outputByteCount: parameters.n, rounds: parameters.hp, notes: "XMSS WOTS+ public key reconstruction plus h' authentication path.")
            case .hypertreeVerification:
                return ArithmetizationDescriptor(gadget: self, inputByteCount: parameters.n, outputByteCount: parameters.n, rounds: parameters.d, notes: "Hypertree verification across d=\(parameters.d) XMSS layers.")
            }
        }
    }

    public struct ArithmetizationDescriptor: Sendable, Equatable {
        public let gadget: ArithmetizationGadget
        public let inputByteCount: Int?
        public let outputByteCount: Int
        public let rounds: Int?
        public let notes: String
    }

    public struct ArithmetizationPlan: Sendable, Equatable {
        public let parameterSet: ParameterSet
        public let descriptors: [ArithmetizationDescriptor]

        public init(parameterSet: ParameterSet) {
            self.parameterSet = parameterSet
            let parameters = parameterSet.parameters
            self.descriptors = ArithmetizationGadget.allCases.map {
                $0.descriptor(parameters: parameters)
            }
        }
    }

    public struct ComponentLayout: Sendable, Equatable {
        public let parameterSet: ParameterSet
        public let publicKeyBytes: Int
        public let privateKeyBytes: Int
        public let signatureBytes: Int
        public let randomnessBytes: Int
        public let forsSignatureBytes: Int
        public let xmssSignatureBytes: Int
        public let hypertreeSignatureBytes: Int
        public let addressBytes: Int
        public let compressedSHA2AddressBytes: Int

        public init(parameterSet: ParameterSet) {
            let p = parameterSet.parameters
            self.parameterSet = parameterSet
            self.publicKeyBytes = p.publicKeyByteCount
            self.privateKeyBytes = p.privateKeyByteCount
            self.signatureBytes = p.signatureByteCount
            self.randomnessBytes = p.n
            self.forsSignatureBytes = p.k * (1 + p.a) * p.n
            self.xmssSignatureBytes = (p.hp + p.len) * p.n
            self.hypertreeSignatureBytes = p.d * (p.hp + p.len) * p.n
            self.addressBytes = 32
            self.compressedSHA2AddressBytes = 22
        }
    }

    public enum VerificationSurface: String, CaseIterable, Sendable {
        case wotsPKFromSignature = "wots_pkFromSig"
        case xmssPKFromSignature = "xmss_pkFromSig"
        case hypertreeVerify = "ht_verify"
        case forsPKFromSignature = "fors_pkFromSig"
        case slhVerifyInternal = "slh_verify_internal"

        public func descriptor(parameters: Parameters) -> ArithmetizationDescriptor {
            switch self {
            case .wotsPKFromSignature:
                return ArithmetizationDescriptor(
                    gadget: .wotsChains,
                    inputByteCount: parameters.len * parameters.n,
                    outputByteCount: parameters.n,
                    rounds: parameters.w - 1,
                    notes: "Reconstructs a WOTS+ public key from len=\(parameters.len) signature chains."
                )
            case .xmssPKFromSignature:
                return ArithmetizationDescriptor(
                    gadget: .xmssAuthPaths,
                    inputByteCount: (parameters.hp + parameters.len) * parameters.n,
                    outputByteCount: parameters.n,
                    rounds: parameters.hp,
                    notes: "Runs wots_pkFromSig and folds h'=\(parameters.hp) XMSS authentication nodes."
                )
            case .hypertreeVerify:
                return ArithmetizationDescriptor(
                    gadget: .hypertreeVerification,
                    inputByteCount: parameters.d * (parameters.hp + parameters.len) * parameters.n,
                    outputByteCount: parameters.n,
                    rounds: parameters.d,
                    notes: "Runs xmss_pkFromSig across d=\(parameters.d) hypertree layers."
                )
            case .forsPKFromSignature:
                return ArithmetizationDescriptor(
                    gadget: .forsTrees,
                    inputByteCount: parameters.k * (parameters.a + 1) * parameters.n,
                    outputByteCount: parameters.n,
                    rounds: parameters.a,
                    notes: "Reconstructs k=\(parameters.k) FORS roots from a-bit indices and authentication paths."
                )
            case .slhVerifyInternal:
                return ArithmetizationDescriptor(
                    gadget: .hypertreeVerification,
                    inputByteCount: parameters.signatureByteCount + parameters.publicKeyByteCount,
                    outputByteCount: 1,
                    rounds: nil,
                    notes: "FIPS 205 Algorithm 20: H_msg split, FORS public key reconstruction, and hypertree verification."
                )
            }
        }
    }

    public static func keygen(parameterSet: ParameterSet) throws -> KeyPair {
        let p = parameterSet.parameters
        return try keygenInternal(
            parameterSet: parameterSet,
            skSeed: secureRandomBytes(count: p.n),
            skPrf: secureRandomBytes(count: p.n),
            pkSeed: secureRandomBytes(count: p.n)
        )
    }

    public static func keygenStructured(parameterSet: ParameterSet) throws -> (publicKey: PublicKey, privateKey: PrivateKey) {
        let pair = try keygen(parameterSet: parameterSet)
        return (
            try PublicKey(encoded: pair.publicKey, parameterSet: parameterSet),
            try PrivateKey(encoded: pair.privateKey, parameterSet: parameterSet)
        )
    }

    public static func keygenInternal(
        parameterSet: ParameterSet,
        skSeed: Data,
        skPrf: Data,
        pkSeed: Data
    ) throws -> KeyPair {
        try Core(parameterSet.parameters).keygenInternal(skSeed: skSeed, skPrf: skPrf, pkSeed: pkSeed)
    }

    public static func keygenInternalStructured(
        parameterSet: ParameterSet,
        skSeed: Data,
        skPrf: Data,
        pkSeed: Data
    ) throws -> (publicKey: PublicKey, privateKey: PrivateKey) {
        let pair = try keygenInternal(parameterSet: parameterSet, skSeed: skSeed, skPrf: skPrf, pkSeed: pkSeed)
        return (
            try PublicKey(encoded: pair.publicKey, parameterSet: parameterSet),
            try PrivateKey(encoded: pair.privateKey, parameterSet: parameterSet)
        )
    }

    public static func sign(
        message: Data,
        context: Data = Data(),
        privateKey: Data,
        parameterSet: ParameterSet,
        additionalRandomness: Data? = nil
    ) throws -> Data {
        let p = parameterSet.parameters
        let randomness = try additionalRandomness ?? secureRandomBytes(count: p.n)
        return try Core(p).sign(message: message, context: context, privateKey: privateKey, additionalRandomness: randomness)
    }

    public static func sign(
        message: Data,
        context: Data = Data(),
        privateKey: PrivateKey,
        additionalRandomness: Data? = nil
    ) throws -> Signature {
        let encoded = try sign(
            message: message,
            context: context,
            privateKey: privateKey.encoded,
            parameterSet: privateKey.parameterSet,
            additionalRandomness: additionalRandomness
        )
        return try Signature(encoded: encoded, parameterSet: privateKey.parameterSet)
    }

    public static func signDeterministic(
        message: Data,
        context: Data = Data(),
        privateKey: Data,
        parameterSet: ParameterSet
    ) throws -> Data {
        try Core(parameterSet.parameters).sign(message: message, context: context, privateKey: privateKey, additionalRandomness: nil)
    }

    public static func signDeterministic(
        message: Data,
        context: Data = Data(),
        privateKey: PrivateKey
    ) throws -> Signature {
        let encoded = try signDeterministic(
            message: message,
            context: context,
            privateKey: privateKey.encoded,
            parameterSet: privateKey.parameterSet
        )
        return try Signature(encoded: encoded, parameterSet: privateKey.parameterSet)
    }

    public static func verify(
        message: Data,
        signature: Data,
        context: Data = Data(),
        publicKey: Data,
        parameterSet: ParameterSet
    ) throws -> Bool {
        try Core(parameterSet.parameters).verify(message: message, signature: signature, context: context, publicKey: publicKey)
    }

    public static func verify(
        message: Data,
        signature: Signature,
        context: Data = Data(),
        publicKey: PublicKey
    ) throws -> Bool {
        try slhVerify(message: message, signature: signature, context: context, publicKey: publicKey)
    }

    public static func slhVerifyInternal(
        message: Data,
        signature: Data,
        publicKey: Data,
        parameterSet: ParameterSet
    ) throws -> Bool {
        let p = parameterSet.parameters
        guard signature.count == p.signatureByteCount, publicKey.count == p.publicKeyByteCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try Core(p).verifyInternal(message: message, signature: signature, publicKey: publicKey)
    }

    public static func slh_verify_internal(
        message: Data,
        signature: Data,
        publicKey: Data,
        parameterSet: ParameterSet
    ) throws -> Bool {
        try slhVerifyInternal(message: message, signature: signature, publicKey: publicKey, parameterSet: parameterSet)
    }

    public static func slhVerifyInternal(
        message: Data,
        signature: Signature,
        publicKey: PublicKey
    ) throws -> Bool {
        guard signature.parameterSet == publicKey.parameterSet else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try Core(publicKey.parameterSet.parameters).verifyInternal(
            message: message,
            signature: signature.encoded,
            publicKey: publicKey.encoded
        )
    }

    public static func slh_verify_internal(
        message: Data,
        signature: Signature,
        publicKey: PublicKey
    ) throws -> Bool {
        try slhVerifyInternal(message: message, signature: signature, publicKey: publicKey)
    }

    public static func slhVerify(
        message: Data,
        signature: Data,
        context: Data = Data(),
        publicKey: Data,
        parameterSet: ParameterSet
    ) throws -> Bool {
        let p = parameterSet.parameters
        guard signature.count == p.signatureByteCount, publicKey.count == p.publicKeyByteCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try Core(p).verify(message: message, signature: signature, context: context, publicKey: publicKey)
    }

    public static func slh_verify(
        message: Data,
        signature: Data,
        context: Data = Data(),
        publicKey: Data,
        parameterSet: ParameterSet
    ) throws -> Bool {
        try slhVerify(
            message: message,
            signature: signature,
            context: context,
            publicKey: publicKey,
            parameterSet: parameterSet
        )
    }

    public static func slhVerify(
        message: Data,
        signature: Signature,
        context: Data = Data(),
        publicKey: PublicKey
    ) throws -> Bool {
        guard signature.parameterSet == publicKey.parameterSet else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try Core(publicKey.parameterSet.parameters).verify(
            message: message,
            signature: signature.encoded,
            context: context,
            publicKey: publicKey.encoded
        )
    }

    public static func slh_verify(
        message: Data,
        signature: Signature,
        context: Data = Data(),
        publicKey: PublicKey
    ) throws -> Bool {
        try slhVerify(message: message, signature: signature, context: context, publicKey: publicKey)
    }

    public static func hashSign(
        message: Data,
        context: Data = Data(),
        preHashFunction: PreHashFunction,
        privateKey: Data,
        parameterSet: ParameterSet,
        additionalRandomness: Data? = nil
    ) throws -> Data {
        let p = parameterSet.parameters
        let randomness = try additionalRandomness ?? secureRandomBytes(count: p.n)
        return try Core(p).hashSign(
            message: message,
            context: context,
            preHashFunction: preHashFunction,
            privateKey: privateKey,
            additionalRandomness: randomness
        )
    }

    public static func hashSign(
        message: Data,
        context: Data = Data(),
        preHashFunction: PreHashFunction,
        privateKey: PrivateKey,
        additionalRandomness: Data? = nil
    ) throws -> Signature {
        let encoded = try hashSign(
            message: message,
            context: context,
            preHashFunction: preHashFunction,
            privateKey: privateKey.encoded,
            parameterSet: privateKey.parameterSet,
            additionalRandomness: additionalRandomness
        )
        return try Signature(encoded: encoded, parameterSet: privateKey.parameterSet)
    }

    public static func hashSignDeterministic(
        message: Data,
        context: Data = Data(),
        preHashFunction: PreHashFunction,
        privateKey: Data,
        parameterSet: ParameterSet
    ) throws -> Data {
        try Core(parameterSet.parameters).hashSign(
            message: message,
            context: context,
            preHashFunction: preHashFunction,
            privateKey: privateKey,
            additionalRandomness: nil
        )
    }

    public static func hashSignDeterministic(
        message: Data,
        context: Data = Data(),
        preHashFunction: PreHashFunction,
        privateKey: PrivateKey
    ) throws -> Signature {
        let encoded = try hashSignDeterministic(
            message: message,
            context: context,
            preHashFunction: preHashFunction,
            privateKey: privateKey.encoded,
            parameterSet: privateKey.parameterSet
        )
        return try Signature(encoded: encoded, parameterSet: privateKey.parameterSet)
    }

    public static func hashVerify(
        message: Data,
        signature: Data,
        context: Data = Data(),
        preHashFunction: PreHashFunction,
        publicKey: Data,
        parameterSet: ParameterSet
    ) throws -> Bool {
        try Core(parameterSet.parameters).hashVerify(
            message: message,
            signature: signature,
            context: context,
            preHashFunction: preHashFunction,
            publicKey: publicKey
        )
    }

    public static func hashSLHVerify(
        message: Data,
        signature: Data,
        context: Data = Data(),
        preHashFunction: PreHashFunction,
        publicKey: Data,
        parameterSet: ParameterSet
    ) throws -> Bool {
        let p = parameterSet.parameters
        guard signature.count == p.signatureByteCount, publicKey.count == p.publicKeyByteCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try Core(p).hashVerify(
            message: message,
            signature: signature,
            context: context,
            preHashFunction: preHashFunction,
            publicKey: publicKey
        )
    }

    public static func hash_slh_verify(
        message: Data,
        signature: Data,
        context: Data = Data(),
        preHashFunction: PreHashFunction,
        publicKey: Data,
        parameterSet: ParameterSet
    ) throws -> Bool {
        try hashSLHVerify(
            message: message,
            signature: signature,
            context: context,
            preHashFunction: preHashFunction,
            publicKey: publicKey,
            parameterSet: parameterSet
        )
    }

    public static func hashSLHVerify(
        message: Data,
        signature: Signature,
        context: Data = Data(),
        preHashFunction: PreHashFunction,
        publicKey: PublicKey
    ) throws -> Bool {
        guard signature.parameterSet == publicKey.parameterSet else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try Core(publicKey.parameterSet.parameters).hashVerify(
            message: message,
            signature: signature.encoded,
            context: context,
            preHashFunction: preHashFunction,
            publicKey: publicKey.encoded
        )
    }

    public static func hash_slh_verify(
        message: Data,
        signature: Signature,
        context: Data = Data(),
        preHashFunction: PreHashFunction,
        publicKey: PublicKey
    ) throws -> Bool {
        try hashSLHVerify(
            message: message,
            signature: signature,
            context: context,
            preHashFunction: preHashFunction,
            publicKey: publicKey
        )
    }

    private static func secureRandomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw AppleZKProverError.correctnessValidationFailed("Secure randomness generation failed.")
        }
        return Data(bytes)
    }
}

private struct SLHDSAAddress {
    private var bytes: [UInt8] = Array(repeating: 0, count: 32)

    mutating func setLayerAddress(_ value: Int) {
        store(UInt64(value), offset: 0, count: 4)
    }

    mutating func setTreeAddress(_ value: UInt64) {
        store(0, offset: 4, count: 4)
        store(value, offset: 8, count: 8)
    }

    mutating func setTypeAndClear(_ value: Int) {
        store(UInt64(value), offset: 16, count: 4)
        for index in 20..<32 {
            bytes[index] = 0
        }
    }

    mutating func setKeyPairAddress(_ value: Int) {
        store(UInt64(value), offset: 20, count: 4)
    }

    func keyPairAddress() -> Int {
        Int(load(offset: 20, count: 4))
    }

    mutating func setChainAddress(_ value: Int) {
        store(UInt64(value), offset: 24, count: 4)
    }

    mutating func setTreeHeight(_ value: Int) {
        store(UInt64(value), offset: 24, count: 4)
    }

    mutating func setHashAddress(_ value: Int) {
        store(UInt64(value), offset: 28, count: 4)
    }

    mutating func setTreeIndex(_ value: Int) {
        store(UInt64(value), offset: 28, count: 4)
    }

    func treeIndex() -> Int {
        Int(load(offset: 28, count: 4))
    }

    func data() -> Data {
        Data(bytes)
    }

    func compressedData() -> Data {
        var out = Data()
        out.reserveCapacity(22)
        out.append(bytes[3])
        out.append(contentsOf: bytes[8..<16])
        out.append(bytes[19])
        out.append(contentsOf: bytes[20..<32])
        return out
    }

    private mutating func store(_ value: UInt64, offset: Int, count: Int) {
        for i in 0..<count {
            let shift = UInt64((count - 1 - i) * 8)
            bytes[offset + i] = UInt8((value >> shift) & 0xff)
        }
    }

    private func load(offset: Int, count: Int) -> UInt64 {
        var value: UInt64 = 0
        for i in 0..<count {
            value = (value << 8) | UInt64(bytes[offset + i])
        }
        return value
    }
}

private struct Core {
    private enum AddressType: Int {
        case wotsHash = 0
        case wotsPK = 1
        case tree = 2
        case forsTree = 3
        case forsRoots = 4
        case wotsPRF = 5
        case forsPRF = 6
    }

    let p: SLHDSA.Parameters

    init(_ parameters: SLHDSA.Parameters) {
        self.p = parameters
    }

    func keygenInternal(skSeed: Data, skPrf: Data, pkSeed: Data) throws -> SLHDSA.KeyPair {
        guard skSeed.count == p.n, skPrf.count == p.n, pkSeed.count == p.n else {
            throw AppleZKProverError.invalidInputLayout
        }
        var adrs = SLHDSAAddress()
        adrs.setLayerAddress(p.d - 1)
        let pkRoot = try xmssNode(skSeed: skSeed, i: 0, z: p.hp, pkSeed: pkSeed, adrs: &adrs)
        var sk = Data()
        sk.reserveCapacity(p.privateKeyByteCount)
        sk.append(skSeed)
        sk.append(skPrf)
        sk.append(pkSeed)
        sk.append(pkRoot)
        var pk = Data()
        pk.reserveCapacity(p.publicKeyByteCount)
        pk.append(pkSeed)
        pk.append(pkRoot)
        return SLHDSA.KeyPair(publicKey: pk, privateKey: sk)
    }

    func sign(message: Data, context: Data, privateKey: Data, additionalRandomness: Data?) throws -> Data {
        guard context.count <= 255, privateKey.count == p.privateKeyByteCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        let mp = pureMessage(message: message, context: context)
        return try signInternal(message: mp, privateKey: privateKey, additionalRandomness: additionalRandomness)
    }

    func verify(message: Data, signature: Data, context: Data, publicKey: Data) throws -> Bool {
        guard context.count <= 255 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let mp = pureMessage(message: message, context: context)
        return try verifyInternal(message: mp, signature: signature, publicKey: publicKey)
    }

    func hashSign(
        message: Data,
        context: Data,
        preHashFunction: SLHDSA.PreHashFunction,
        privateKey: Data,
        additionalRandomness: Data?
    ) throws -> Data {
        guard context.count <= 255, privateKey.count == p.privateKeyByteCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        let mp = try preHashMessage(message: message, context: context, preHashFunction: preHashFunction)
        return try signInternal(message: mp, privateKey: privateKey, additionalRandomness: additionalRandomness)
    }

    func hashVerify(
        message: Data,
        signature: Data,
        context: Data,
        preHashFunction: SLHDSA.PreHashFunction,
        publicKey: Data
    ) throws -> Bool {
        guard context.count <= 255 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let mp = try preHashMessage(message: message, context: context, preHashFunction: preHashFunction)
        return try verifyInternal(message: mp, signature: signature, publicKey: publicKey)
    }

    private func pureMessage(message: Data, context: Data) -> Data {
        var out = Data()
        out.reserveCapacity(2 + context.count + message.count)
        out.append(SLHDSA.DomainSeparator.pure)
        out.append(UInt8(context.count))
        out.append(context)
        out.append(message)
        return out
    }

    private func preHashMessage(
        message: Data,
        context: Data,
        preHashFunction: SLHDSA.PreHashFunction
    ) throws -> Data {
        let digest = try digest(message, preHashFunction: preHashFunction)
        var out = Data()
        out.reserveCapacity(2 + context.count + preHashFunction.derOID.count + digest.count)
        out.append(SLHDSA.DomainSeparator.preHash)
        out.append(UInt8(context.count))
        out.append(context)
        out.append(contentsOf: preHashFunction.derOID)
        out.append(digest)
        return out
    }

    private func digest(_ message: Data, preHashFunction: SLHDSA.PreHashFunction) throws -> Data {
        switch preHashFunction {
        case .sha2_256:
            return sha256(message)
        case .sha2_384:
            return Data(SHA384.hash(data: message))
        case .sha2_512:
            return sha512(message)
        case .sha2_224:
            return commonCryptoSHA224(message)
        case .sha2_512_224:
            return sha512t(message, variant: .sha512_224)
        case .sha2_512_256:
            return sha512t(message, variant: .sha512_256)
        case .sha3_224:
            return SHA3Oracle.sha3_224(message)
        case .sha3_256:
            return SHA3Oracle.sha3_256(message)
        case .sha3_384:
            return SHA3Oracle.sha3_384(message)
        case .sha3_512:
            return SHA3Oracle.sha3_512(message)
        case .shake128:
            return try SHA3Oracle.shake128(message, outputByteCount: 32)
        case .shake256:
            return try SHA3Oracle.shake256(message, outputByteCount: 64)
        }
    }

    private func signInternal(message: Data, privateKey: Data, additionalRandomness: Data?) throws -> Data {
        let skSeed = slice(privateKey, 0, p.n)
        let skPrf = slice(privateKey, p.n, p.n)
        let pkSeed = slice(privateKey, 2 * p.n, p.n)
        let pkRoot = slice(privateKey, 3 * p.n, p.n)
        let optRand = additionalRandomness ?? pkSeed
        guard optRand.count == p.n else {
            throw AppleZKProverError.invalidInputLayout
        }

        let r = try prfMsg(skPrf: skPrf, optRand: optRand, message: message)
        let digest = try hMsg(r: r, pkSeed: pkSeed, pkRoot: pkRoot, message: message)
        let split = splitDigest(digest)
        var adrs = SLHDSAAddress()
        adrs.setTreeAddress(split.tree)
        adrs.setTypeAndClear(AddressType.forsTree.rawValue)
        adrs.setKeyPairAddress(split.leaf)

        let sigFors = try forsSign(md: split.md, skSeed: skSeed, pkSeed: pkSeed, adrs: &adrs)
        let pkFors = try forsPKFromSig(sigFors: sigFors, md: split.md, pkSeed: pkSeed, adrs: &adrs)
        let sigHT = try htSign(message: pkFors, skSeed: skSeed, pkSeed: pkSeed, tree: split.tree, leaf: split.leaf)

        var sig = Data()
        sig.reserveCapacity(p.signatureByteCount)
        sig.append(r)
        sig.append(sigFors)
        sig.append(sigHT)
        return sig
    }

    func verifyInternal(message: Data, signature: Data, publicKey: Data) throws -> Bool {
        guard signature.count == p.signatureByteCount, publicKey.count == p.publicKeyByteCount else {
            return false
        }
        let pkSeed = slice(publicKey, 0, p.n)
        let pkRoot = slice(publicKey, p.n, p.n)
        let r = slice(signature, 0, p.n)
        let forsLength = p.k * (1 + p.a) * p.n
        let sigFors = slice(signature, p.n, forsLength)
        let sigHT = slice(signature, p.n + forsLength, signature.count - p.n - forsLength)

        let digest = try hMsg(r: r, pkSeed: pkSeed, pkRoot: pkRoot, message: message)
        let split = splitDigest(digest)
        var adrs = SLHDSAAddress()
        adrs.setTreeAddress(split.tree)
        adrs.setTypeAndClear(AddressType.forsTree.rawValue)
        adrs.setKeyPairAddress(split.leaf)
        let pkFors = try forsPKFromSig(sigFors: sigFors, md: split.md, pkSeed: pkSeed, adrs: &adrs)
        return try htVerify(message: pkFors, sigHT: sigHT, pkSeed: pkSeed, tree: split.tree, leaf: split.leaf, pkRoot: pkRoot)
    }

    private func splitDigest(_ digest: Data) -> (md: Data, tree: UInt64, leaf: Int) {
        let mdBytes = (p.k * p.a + 7) / 8
        let treeBits = p.h - p.hp
        let treeBytes = (treeBits + 7) / 8
        let leafBytes = (p.hp + 7) / 8
        let md = slice(digest, 0, mdBytes)
        var tree = toUInt64(slice(digest, mdBytes, treeBytes))
        if treeBits < 64 {
            tree %= UInt64(1) << UInt64(treeBits)
        }
        let leaf = Int(toUInt64(slice(digest, mdBytes + treeBytes, leafBytes)) % (UInt64(1) << UInt64(p.hp)))
        return (md, tree, leaf)
    }

    private func wotsMessage(_ message: Data) -> [Int] {
        var csum = 0
        var msg = base2b(message, bits: p.lgW, outputLength: p.len1)
        for value in msg {
            csum += p.w - 1 - value
        }
        let shift = (8 - ((p.len2 * p.lgW) % 8)) % 8
        csum <<= shift
        let csumBytes = toByte(csum, count: (p.len2 * p.lgW + 7) / 8)
        msg += base2b(csumBytes, bits: p.lgW, outputLength: p.len2)
        return msg
    }

    private func chain(_ x: Data, start: Int, steps: Int, pkSeed: Data, adrs: inout SLHDSAAddress) throws -> Data {
        guard start + steps < p.w else {
            throw AppleZKProverError.invalidInputLayout
        }
        var tmp = x
        if steps == 0 {
            return tmp
        }
        for j in start..<(start + steps) {
            adrs.setHashAddress(j)
            tmp = try f(pkSeed: pkSeed, adrs: adrs, message: tmp)
        }
        return tmp
    }

    private func wotsPKGen(skSeed: Data, pkSeed: Data, adrs: inout SLHDSAAddress) throws -> Data {
        var skAdrs = adrs
        skAdrs.setTypeAndClear(AddressType.wotsPRF.rawValue)
        skAdrs.setKeyPairAddress(adrs.keyPairAddress())
        var tmp = Data()
        tmp.reserveCapacity(p.len * p.n)
        for i in 0..<p.len {
            skAdrs.setChainAddress(i)
            let sk = try prf(pkSeed: pkSeed, skSeed: skSeed, adrs: skAdrs)
            adrs.setChainAddress(i)
            tmp.append(try chain(sk, start: 0, steps: p.w - 1, pkSeed: pkSeed, adrs: &adrs))
        }
        var pkAdrs = adrs
        pkAdrs.setTypeAndClear(AddressType.wotsPK.rawValue)
        pkAdrs.setKeyPairAddress(adrs.keyPairAddress())
        return try t(pkSeed: pkSeed, adrs: pkAdrs, message: tmp)
    }

    private func wotsSign(message: Data, skSeed: Data, pkSeed: Data, adrs: inout SLHDSAAddress) throws -> Data {
        let msg = wotsMessage(message)
        var skAdrs = adrs
        skAdrs.setTypeAndClear(AddressType.wotsPRF.rawValue)
        skAdrs.setKeyPairAddress(adrs.keyPairAddress())
        var sig = Data()
        sig.reserveCapacity(p.len * p.n)
        for i in 0..<p.len {
            skAdrs.setChainAddress(i)
            let sk = try prf(pkSeed: pkSeed, skSeed: skSeed, adrs: skAdrs)
            adrs.setChainAddress(i)
            sig.append(try chain(sk, start: 0, steps: msg[i], pkSeed: pkSeed, adrs: &adrs))
        }
        return sig
    }

    private func wotsPKFromSig(sig: Data, message: Data, pkSeed: Data, adrs: inout SLHDSAAddress) throws -> Data {
        let msg = wotsMessage(message)
        var tmp = Data()
        tmp.reserveCapacity(p.len * p.n)
        for i in 0..<p.len {
            adrs.setChainAddress(i)
            tmp.append(try chain(slice(sig, i * p.n, p.n), start: msg[i], steps: p.w - 1 - msg[i], pkSeed: pkSeed, adrs: &adrs))
        }
        var pkAdrs = adrs
        pkAdrs.setTypeAndClear(AddressType.wotsPK.rawValue)
        pkAdrs.setKeyPairAddress(adrs.keyPairAddress())
        return try t(pkSeed: pkSeed, adrs: pkAdrs, message: tmp)
    }

    private func xmssNode(skSeed: Data, i: Int, z: Int, pkSeed: Data, adrs: inout SLHDSAAddress) throws -> Data {
        guard z <= p.hp, i < (1 << (p.hp - z)) else {
            throw AppleZKProverError.invalidInputLayout
        }
        if z == 0 {
            adrs.setTypeAndClear(AddressType.wotsHash.rawValue)
            adrs.setKeyPairAddress(i)
            return try wotsPKGen(skSeed: skSeed, pkSeed: pkSeed, adrs: &adrs)
        }
        let left = try xmssNode(skSeed: skSeed, i: 2 * i, z: z - 1, pkSeed: pkSeed, adrs: &adrs)
        let right = try xmssNode(skSeed: skSeed, i: 2 * i + 1, z: z - 1, pkSeed: pkSeed, adrs: &adrs)
        adrs.setTypeAndClear(AddressType.tree.rawValue)
        adrs.setTreeHeight(z)
        adrs.setTreeIndex(i)
        return try h(pkSeed: pkSeed, adrs: adrs, message: left + right)
    }

    private func xmssSign(message: Data, skSeed: Data, idx: Int, pkSeed: Data, adrs: inout SLHDSAAddress) throws -> Data {
        var auth = Data()
        auth.reserveCapacity(p.hp * p.n)
        for j in 0..<p.hp {
            let k = (idx >> j) ^ 1
            auth.append(try xmssNode(skSeed: skSeed, i: k, z: j, pkSeed: pkSeed, adrs: &adrs))
        }
        adrs.setTypeAndClear(AddressType.wotsHash.rawValue)
        adrs.setKeyPairAddress(idx)
        return try wotsSign(message: message, skSeed: skSeed, pkSeed: pkSeed, adrs: &adrs) + auth
    }

    private func xmssPKFromSig(idx: Int, sigXMSS: Data, message: Data, pkSeed: Data, adrs: inout SLHDSAAddress) throws -> Data {
        adrs.setTypeAndClear(AddressType.wotsHash.rawValue)
        adrs.setKeyPairAddress(idx)
        let sig = slice(sigXMSS, 0, p.len * p.n)
        let auth = slice(sigXMSS, p.len * p.n, p.hp * p.n)
        var node = try wotsPKFromSig(sig: sig, message: message, pkSeed: pkSeed, adrs: &adrs)
        adrs.setTypeAndClear(AddressType.tree.rawValue)
        adrs.setTreeIndex(idx)
        for k in 0..<p.hp {
            adrs.setTreeHeight(k + 1)
            let authK = slice(auth, k * p.n, p.n)
            if ((idx >> k) & 1) == 0 {
                adrs.setTreeIndex(adrs.treeIndex() / 2)
                node = try h(pkSeed: pkSeed, adrs: adrs, message: node + authK)
            } else {
                adrs.setTreeIndex((adrs.treeIndex() - 1) / 2)
                node = try h(pkSeed: pkSeed, adrs: adrs, message: authK + node)
            }
        }
        return node
    }

    private func htSign(message: Data, skSeed: Data, pkSeed: Data, tree: UInt64, leaf: Int) throws -> Data {
        var adrs = SLHDSAAddress()
        var idxTree = tree
        var idxLeaf = leaf
        adrs.setTreeAddress(idxTree)
        var sig = try xmssSign(message: message, skSeed: skSeed, idx: idxLeaf, pkSeed: pkSeed, adrs: &adrs)
        var root = try xmssPKFromSig(idx: idxLeaf, sigXMSS: sig, message: message, pkSeed: pkSeed, adrs: &adrs)
        let hpMask = UInt64((1 << p.hp) - 1)
        for layer in 1..<p.d {
            idxLeaf = Int(idxTree & hpMask)
            idxTree >>= UInt64(p.hp)
            adrs.setLayerAddress(layer)
            adrs.setTreeAddress(idxTree)
            let sigTmp = try xmssSign(message: root, skSeed: skSeed, idx: idxLeaf, pkSeed: pkSeed, adrs: &adrs)
            sig.append(sigTmp)
            if layer < p.d - 1 {
                root = try xmssPKFromSig(idx: idxLeaf, sigXMSS: sigTmp, message: root, pkSeed: pkSeed, adrs: &adrs)
            }
        }
        return sig
    }

    private func htVerify(message: Data, sigHT: Data, pkSeed: Data, tree: UInt64, leaf: Int, pkRoot: Data) throws -> Bool {
        var adrs = SLHDSAAddress()
        var idxTree = tree
        var idxLeaf = leaf
        adrs.setTreeAddress(idxTree)
        let xmssLength = (p.hp + p.len) * p.n
        var node = try xmssPKFromSig(idx: idxLeaf, sigXMSS: slice(sigHT, 0, xmssLength), message: message, pkSeed: pkSeed, adrs: &adrs)
        let hpMask = UInt64((1 << p.hp) - 1)
        for layer in 1..<p.d {
            idxLeaf = Int(idxTree & hpMask)
            idxTree >>= UInt64(p.hp)
            adrs.setLayerAddress(layer)
            adrs.setTreeAddress(idxTree)
            node = try xmssPKFromSig(
                idx: idxLeaf,
                sigXMSS: slice(sigHT, layer * xmssLength, xmssLength),
                message: node,
                pkSeed: pkSeed,
                adrs: &adrs
            )
        }
        return constantTimeEqual(node, pkRoot)
    }

    private func forsSKGen(skSeed: Data, pkSeed: Data, adrs: SLHDSAAddress, idx: Int) throws -> Data {
        var skAdrs = adrs
        skAdrs.setTypeAndClear(AddressType.forsPRF.rawValue)
        skAdrs.setKeyPairAddress(adrs.keyPairAddress())
        skAdrs.setTreeIndex(idx)
        return try prf(pkSeed: pkSeed, skSeed: skSeed, adrs: skAdrs)
    }

    private func forsNode(skSeed: Data, i: Int, z: Int, pkSeed: Data, adrs: inout SLHDSAAddress) throws -> Data {
        guard z <= p.a, i < (p.k << (p.a - z)) else {
            throw AppleZKProverError.invalidInputLayout
        }
        if z == 0 {
            let sk = try forsSKGen(skSeed: skSeed, pkSeed: pkSeed, adrs: adrs, idx: i)
            adrs.setTreeHeight(0)
            adrs.setTreeIndex(i)
            return try f(pkSeed: pkSeed, adrs: adrs, message: sk)
        }
        let left = try forsNode(skSeed: skSeed, i: 2 * i, z: z - 1, pkSeed: pkSeed, adrs: &adrs)
        let right = try forsNode(skSeed: skSeed, i: 2 * i + 1, z: z - 1, pkSeed: pkSeed, adrs: &adrs)
        adrs.setTreeHeight(z)
        adrs.setTreeIndex(i)
        return try h(pkSeed: pkSeed, adrs: adrs, message: left + right)
    }

    private func forsSign(md: Data, skSeed: Data, pkSeed: Data, adrs: inout SLHDSAAddress) throws -> Data {
        let indices = base2b(md, bits: p.a, outputLength: p.k)
        var sig = Data()
        sig.reserveCapacity(p.k * (p.a + 1) * p.n)
        for i in 0..<p.k {
            sig.append(try forsSKGen(skSeed: skSeed, pkSeed: pkSeed, adrs: adrs, idx: (i << p.a) + indices[i]))
            for j in 0..<p.a {
                let s = (indices[i] >> j) ^ 1
                sig.append(try forsNode(skSeed: skSeed, i: (i << (p.a - j)) + s, z: j, pkSeed: pkSeed, adrs: &adrs))
            }
        }
        return sig
    }

    private func forsPKFromSig(sigFors: Data, md: Data, pkSeed: Data, adrs: inout SLHDSAAddress) throws -> Data {
        let indices = base2b(md, bits: p.a, outputLength: p.k)
        var roots = Data()
        roots.reserveCapacity(p.k * p.n)
        for i in 0..<p.k {
            let skOffset = i * (p.a + 1) * p.n
            let sk = slice(sigFors, skOffset, p.n)
            adrs.setTreeHeight(0)
            adrs.setTreeIndex((i << p.a) + indices[i])
            var node = try f(pkSeed: pkSeed, adrs: adrs, message: sk)
            let authOffset = skOffset + p.n
            for j in 0..<p.a {
                let auth = slice(sigFors, authOffset + j * p.n, p.n)
                adrs.setTreeHeight(j + 1)
                if ((indices[i] >> j) & 1) == 0 {
                    adrs.setTreeIndex(adrs.treeIndex() / 2)
                    node = try h(pkSeed: pkSeed, adrs: adrs, message: node + auth)
                } else {
                    adrs.setTreeIndex((adrs.treeIndex() - 1) / 2)
                    node = try h(pkSeed: pkSeed, adrs: adrs, message: auth + node)
                }
            }
            roots.append(node)
        }
        var pkAdrs = adrs
        pkAdrs.setTypeAndClear(AddressType.forsRoots.rawValue)
        pkAdrs.setKeyPairAddress(adrs.keyPairAddress())
        return try t(pkSeed: pkSeed, adrs: pkAdrs, message: roots)
    }

    private func hMsg(r: Data, pkSeed: Data, pkRoot: Data, message: Data) throws -> Data {
        switch p.family {
        case .shake:
            return try SHA3Oracle.shake256(r + pkSeed + pkRoot + message, outputByteCount: p.m)
        case .sha2:
            if p.n == 16 {
                return mgfSHA256(r + pkSeed + sha256(r + pkSeed + pkRoot + message), outputByteCount: p.m)
            }
            return mgfSHA512(r + pkSeed + sha512(r + pkSeed + pkRoot + message), outputByteCount: p.m)
        }
    }

    private func prf(pkSeed: Data, skSeed: Data, adrs: SLHDSAAddress) throws -> Data {
        switch p.family {
        case .shake:
            return try SHA3Oracle.shake256(pkSeed + adrs.data() + skSeed, outputByteCount: p.n)
        case .sha2:
            return truncate(sha256(pkSeed + Data(repeating: 0, count: 64 - p.n) + adrs.compressedData() + skSeed), count: p.n)
        }
    }

    private func prfMsg(skPrf: Data, optRand: Data, message: Data) throws -> Data {
        switch p.family {
        case .shake:
            return try SHA3Oracle.shake256(skPrf + optRand + message, outputByteCount: p.n)
        case .sha2:
            if p.n == 16 {
                return truncate(hmacSHA256(key: skPrf, message: optRand + message), count: p.n)
            }
            return truncate(hmacSHA512(key: skPrf, message: optRand + message), count: p.n)
        }
    }

    private func f(pkSeed: Data, adrs: SLHDSAAddress, message: Data) throws -> Data {
        try thash(pkSeed: pkSeed, adrs: adrs, message: message)
    }

    private func h(pkSeed: Data, adrs: SLHDSAAddress, message: Data) throws -> Data {
        try thash(pkSeed: pkSeed, adrs: adrs, message: message)
    }

    private func t(pkSeed: Data, adrs: SLHDSAAddress, message: Data) throws -> Data {
        try thash(pkSeed: pkSeed, adrs: adrs, message: message)
    }

    private func thash(pkSeed: Data, adrs: SLHDSAAddress, message: Data) throws -> Data {
        switch p.family {
        case .shake:
            return try SHA3Oracle.shake256(pkSeed + adrs.data() + message, outputByteCount: p.n)
        case .sha2:
            if p.n == 16 {
                return truncate(sha256(pkSeed + Data(repeating: 0, count: 64 - p.n) + adrs.compressedData() + message), count: p.n)
            }
            return truncate(sha512(pkSeed + Data(repeating: 0, count: 128 - p.n) + adrs.compressedData() + message), count: p.n)
        }
    }
}

private func slice(_ data: Data, _ offset: Int, _ count: Int) -> Data {
    data.subdata(in: offset..<(offset + count))
}

private func toByte(_ value: Int, count: Int) -> Data {
    var out = [UInt8](repeating: 0, count: count)
    var x = value
    for i in 0..<count {
        out[count - 1 - i] = UInt8(x & 0xff)
        x >>= 8
    }
    return Data(out)
}

private func toUInt64(_ data: Data) -> UInt64 {
    var value: UInt64 = 0
    for byte in data {
        value = (value << 8) | UInt64(byte)
    }
    return value
}

private func base2b(_ data: Data, bits: Int, outputLength: Int) -> [Int] {
    let bytes = [UInt8](data)
    var input = 0
    var availableBits = 0
    var total = 0
    let mask = (1 << bits) - 1
    var out: [Int] = []
    out.reserveCapacity(outputLength)
    for _ in 0..<outputLength {
        while availableBits < bits {
            total = (total << 8) + Int(bytes[input])
            input += 1
            availableBits += 8
        }
        availableBits -= bits
        out.append((total >> availableBits) & mask)
    }
    return out
}

private func slhBase2b(_ data: Data, bits: Int, outputLength: Int) -> [Int] {
    base2b(data, bits: bits, outputLength: outputLength)
}

private func sha256(_ data: Data) -> Data {
    Data(SHA256.hash(data: data))
}

private func sha512(_ data: Data) -> Data {
    Data(SHA512.hash(data: data))
}

private func slhSHA256(_ data: Data) -> Data {
    sha256(data)
}

private func slhSHA512(_ data: Data) -> Data {
    sha512(data)
}

private func commonCryptoSHA224(_ data: Data) -> Data {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA224_DIGEST_LENGTH))
    data.withUnsafeBytes { rawBuffer in
        _ = CC_SHA224(rawBuffer.baseAddress, CC_LONG(data.count), &digest)
    }
    return Data(digest)
}

private enum SHA512TVariant {
    case sha512_224
    case sha512_256

    var initialState: [UInt64] {
        switch self {
        case .sha512_224:
            return [
                0x8c3d37c819544da2, 0x73e1996689dcd4d6,
                0x1dfab7ae32ff9c82, 0x679dd514582f9fcf,
                0x0f6d2b697bd44da8, 0x77e36f7304c48942,
                0x3f9d85a86a1d36c8, 0x1112e6ad91d692a1,
            ]
        case .sha512_256:
            return [
                0x22312194fc2bf72c, 0x9f555fa3c84c64c2,
                0x2393b86b6f53b151, 0x963877195940eabd,
                0x96283ee2a88effe3, 0xbe5e1e2553863992,
                0x2b0199fc2c85b8aa, 0x0eb72ddc81c52ca2,
            ]
        }
    }

    var outputByteCount: Int {
        switch self {
        case .sha512_224: return 28
        case .sha512_256: return 32
        }
    }
}

private func sha512t(_ data: Data, variant: SHA512TVariant) -> Data {
    var state = variant.initialState
    var message = [UInt8](data)
    let bitLengthLow = UInt64(message.count) &* 8
    let bitLengthHigh = UInt64(message.count >> 61)
    message.append(0x80)
    while (message.count % 128) != 112 {
        message.append(0)
    }
    appendBigEndian(bitLengthHigh, to: &message)
    appendBigEndian(bitLengthLow, to: &message)

    for blockStart in stride(from: 0, to: message.count, by: 128) {
        sha512Compress(block: message[blockStart..<(blockStart + 128)], state: &state)
    }

    var digest = Data()
    digest.reserveCapacity(64)
    for word in state {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(8)
        appendBigEndian(word, to: &bytes)
        digest.append(contentsOf: bytes)
    }
    return truncate(digest, count: variant.outputByteCount)
}

private func sha512Compress(block: ArraySlice<UInt8>, state: inout [UInt64]) {
    let k: [UInt64] = [
        0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
        0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
        0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
        0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
        0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
        0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
        0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
        0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
        0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
        0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
        0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
        0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
        0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
        0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
        0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
        0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
        0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
        0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
        0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
        0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817,
    ]
    var w = [UInt64](repeating: 0, count: 80)
    let bytes = Array(block)
    for i in 0..<16 {
        var value: UInt64 = 0
        for j in 0..<8 {
            value = (value << 8) | UInt64(bytes[i * 8 + j])
        }
        w[i] = value
    }
    for i in 16..<80 {
        let s0 = rotateRight(w[i - 15], by: 1) ^ rotateRight(w[i - 15], by: 8) ^ (w[i - 15] >> 7)
        let s1 = rotateRight(w[i - 2], by: 19) ^ rotateRight(w[i - 2], by: 61) ^ (w[i - 2] >> 6)
        w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
    }
    var a = state[0]
    var b = state[1]
    var c = state[2]
    var d = state[3]
    var e = state[4]
    var f = state[5]
    var g = state[6]
    var h = state[7]
    for i in 0..<80 {
        let s1 = rotateRight(e, by: 14) ^ rotateRight(e, by: 18) ^ rotateRight(e, by: 41)
        let ch = (e & f) ^ ((~e) & g)
        let temp1 = h &+ s1 &+ ch &+ k[i] &+ w[i]
        let s0 = rotateRight(a, by: 28) ^ rotateRight(a, by: 34) ^ rotateRight(a, by: 39)
        let maj = (a & b) ^ (a & c) ^ (b & c)
        let temp2 = s0 &+ maj
        h = g
        g = f
        f = e
        e = d &+ temp1
        d = c
        c = b
        b = a
        a = temp1 &+ temp2
    }
    state[0] = state[0] &+ a
    state[1] = state[1] &+ b
    state[2] = state[2] &+ c
    state[3] = state[3] &+ d
    state[4] = state[4] &+ e
    state[5] = state[5] &+ f
    state[6] = state[6] &+ g
    state[7] = state[7] &+ h
}

private func rotateRight(_ value: UInt64, by amount: Int) -> UInt64 {
    (value >> UInt64(amount)) | (value << UInt64(64 - amount))
}

private func appendBigEndian(_ value: UInt64, to bytes: inout [UInt8]) {
    for shift in stride(from: 56, through: 0, by: -8) {
        bytes.append(UInt8((value >> UInt64(shift)) & 0xff))
    }
}

private func hmacSHA256(key: Data, message: Data) -> Data {
    let key = SymmetricKey(data: key)
    return Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
}

private func hmacSHA512(key: Data, message: Data) -> Data {
    let key = SymmetricKey(data: key)
    return Data(HMAC<SHA512>.authenticationCode(for: message, using: key))
}

private func slhHMACSHA256(key: Data, message: Data) -> Data {
    hmacSHA256(key: key, message: message)
}

private func slhHMACSHA512(key: Data, message: Data) -> Data {
    hmacSHA512(key: key, message: message)
}

private func mgfSHA256(_ seed: Data, outputByteCount: Int) -> Data {
    mgf(seed, outputByteCount: outputByteCount, digestByteCount: 32, hash: sha256)
}

private func mgfSHA512(_ seed: Data, outputByteCount: Int) -> Data {
    mgf(seed, outputByteCount: outputByteCount, digestByteCount: 64, hash: sha512)
}

private func mgf(_ seed: Data, outputByteCount: Int, digestByteCount: Int, hash: (Data) -> Data) -> Data {
    var out = Data()
    out.reserveCapacity(outputByteCount)
    let blocks = (outputByteCount + digestByteCount - 1) / digestByteCount
    for counter in 0..<blocks {
        var blockInput = seed
        blockInput.append(toByte(counter, count: 4))
        out.append(hash(blockInput))
    }
    return truncate(out, count: outputByteCount)
}

private func truncate(_ data: Data, count: Int) -> Data {
    data.prefix(count)
}

private func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
    guard lhs.count == rhs.count else {
        return false
    }
    var diff: UInt8 = 0
    for (a, b) in zip(lhs, rhs) {
        diff |= a ^ b
    }
    return diff == 0
}
