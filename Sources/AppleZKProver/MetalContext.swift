#if canImport(Metal)
import Foundation
import Metal
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(Darwin)
import Darwin
#endif

public struct GPUCapabilities: Sendable {
    public let name: String
    public let registryID: UInt64
    public let supportsApple3: Bool
    public let supportsApple4: Bool
    public let supportsApple7: Bool
    public let supportsApple9: Bool
    public let supports64BitAtomics: Bool
    public let supportsSIMDReductions: Bool
    public let supportsNonuniformThreadgroups: Bool
    public let supportsBinaryArchives: Bool
    public let supportsMetal4Queue: Bool
    public let maxThreadsPerThreadgroup: Int
    public let maxThreadgroupMemoryLength: Int
    public let hasUnifiedMemory: Bool

    public init(device: MTLDevice) {
        name = device.name
        registryID = device.registryID
        supportsApple3 = device.supportsFamily(.apple3)
        supportsApple4 = device.supportsFamily(.apple4)
        supportsApple7 = device.supportsFamily(.apple7)
        supportsApple9 = device.supportsFamily(.apple9)
        supports64BitAtomics = device.supportsFamily(.apple9) || (device.supportsFamily(.apple8) && device.supportsFamily(.mac2))
        supportsSIMDReductions = device.supportsFamily(.apple7) || device.supportsFamily(.mac2)
        supportsNonuniformThreadgroups = device.supportsFamily(.apple4) || device.supportsFamily(.mac2)
        supportsBinaryArchives = device.supportsFamily(.apple3) || device.supportsFamily(.mac2)
        supportsMetal4Queue = NSClassFromString("MTL4CommandQueue") != nil
            || NSClassFromString("Metal.MTL4CommandQueue") != nil
        maxThreadsPerThreadgroup = device.maxThreadsPerThreadgroup.width
        maxThreadgroupMemoryLength = device.maxThreadgroupMemoryLength
        hasUnifiedMemory = device.hasUnifiedMemory
    }
}

public struct MetalPipelineCacheConfiguration: Sendable {
    public enum BinaryArchiveMode: Sendable, Equatable {
        case disabled
        case readOnly(URL)
        case readWrite(URL)
    }

    public var binaryArchiveMode: BinaryArchiveMode

    public init(binaryArchiveMode: BinaryArchiveMode = .disabled) {
        self.binaryArchiveMode = binaryArchiveMode
    }

    public static let disabled = MetalPipelineCacheConfiguration(binaryArchiveMode: .disabled)
}

public final class MetalContext: @unchecked Sendable {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let capabilities: GPUCapabilities
    public let deviceFingerprint: DeviceFingerprint
    public let shaderSourceHash: String

    private let library: MTLLibrary
    private let binaryArchive: MTLBinaryArchive?
    private let binaryArchiveMode: MetalPipelineCacheConfiguration.BinaryArchiveMode
    private var pipelineCache: [PipelineCacheKey: MTLComputePipelineState] = [:]
    private var binaryArchiveDirty = false
    private let lock = NSLock()

    public init(
        device: MTLDevice? = MTLCreateSystemDefaultDevice(),
        pipelineCacheConfiguration: MetalPipelineCacheConfiguration = .disabled
    ) throws {
        guard let device else {
            throw AppleZKProverError.noMetalDevice
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw AppleZKProverError.failedToCreateCommandQueue
        }

        let capabilities = GPUCapabilities(device: device)
        let metalSource = try MetalContext.readMetalSource()
        self.device = device
        self.commandQueue = commandQueue
        self.commandQueue.label = "AppleZKProver.CommandQueue"
        self.capabilities = capabilities
        self.deviceFingerprint = DeviceFingerprint(
            registryID: capabilities.registryID,
            name: capabilities.name,
            osBuild: Self.currentOSBuild(),
            supportsApple4: capabilities.supportsApple4,
            supportsApple7: capabilities.supportsApple7,
            supportsApple9: capabilities.supportsApple9,
            supportsMetal4Queue: capabilities.supportsMetal4Queue,
            maxThreadsPerThreadgroup: capabilities.maxThreadsPerThreadgroup,
            hasUnifiedMemory: capabilities.hasUnifiedMemory
        )
        self.shaderSourceHash = Self.hashMetalSource(metalSource)
        self.binaryArchiveMode = pipelineCacheConfiguration.binaryArchiveMode
        self.binaryArchive = try MetalContext.makeBinaryArchive(
            device: device,
            capabilities: capabilities,
            configuration: pipelineCacheConfiguration
        )
        self.library = try MetalContext.makeLibrary(device: device, source: metalSource)
    }

    public func pipeline(for spec: KernelSpec) throws -> MTLComputePipelineState {
        lock.lock()
        defer { lock.unlock() }

        let key = PipelineCacheKey(spec: spec, shaderSourceHash: shaderSourceHash)
        if let cached = pipelineCache[key] {
            return cached
        }
        let function = try makeFunction(for: spec)
        let descriptor = MTLComputePipelineDescriptor()
        descriptor.label = spec.cacheLabel(shaderSourceHash: shaderSourceHash)
        descriptor.computeFunction = function

        if let binaryArchive {
            descriptor.binaryArchives = [binaryArchive]
            if case .readWrite = binaryArchiveMode {
                do {
                    try binaryArchive.addComputePipelineFunctions(descriptor: descriptor)
                    binaryArchiveDirty = true
                } catch {
                    throw AppleZKProverError.failedToUpdateBinaryArchive(error.localizedDescription)
                }
            }
        }

        let pipeline = try device.makeComputePipelineState(descriptor: descriptor, options: [], reflection: nil)
        pipelineCache[key] = pipeline
        return pipeline
    }

    public func pipeline(named name: String) throws -> MTLComputePipelineState {
        try pipeline(for: KernelSpec(kernel: name, family: .scalar, queueMode: .metal3))
    }

    public func serializePipelineArchiveIfNeeded() throws {
        lock.lock()
        defer { lock.unlock() }

        guard binaryArchiveDirty, let binaryArchive else {
            return
        }
        guard case let .readWrite(url) = binaryArchiveMode else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try binaryArchive.serialize(to: url)
            binaryArchiveDirty = false
        } catch {
            throw AppleZKProverError.failedToSerializeBinaryArchive(error.localizedDescription)
        }
    }

    public func preferredThreadsPerThreadgroup(for pipeline: MTLComputePipelineState) -> MTLSize {
        let simdWidth = max(1, pipeline.threadExecutionWidth)
        let heavyRegisterCandidate = simdWidth * 4
        let width = max(simdWidth, min(pipeline.maxTotalThreadsPerThreadgroup, heavyRegisterCandidate))
        let rounded = max(simdWidth, (width / simdWidth) * simdWidth)
        return MTLSize(width: rounded, height: 1, depth: 1)
    }

    public func maxSIMDGroupsPerThreadgroup(for pipeline: MTLComputePipelineState) -> Int {
        let simdWidth = max(1, pipeline.threadExecutionWidth)
        return max(1, pipeline.maxTotalThreadsPerThreadgroup / simdWidth)
    }

    public func preferredSIMDGroupsPerThreadgroup(
        for pipeline: MTLComputePipelineState,
        limit: Int = 2
    ) -> Int {
        max(1, min(limit, maxSIMDGroupsPerThreadgroup(for: pipeline)))
    }

    public func dispatch1D(
        _ encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        elementCount: Int
    ) {
        let threadsPerThreadgroup = preferredThreadsPerThreadgroup(for: pipeline)
        if capabilities.supportsNonuniformThreadgroups {
            encoder.dispatchThreads(
                MTLSize(width: elementCount, height: 1, depth: 1),
                threadsPerThreadgroup: threadsPerThreadgroup
            )
        } else {
            let groups = (elementCount + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width
            encoder.dispatchThreadgroups(
                MTLSize(width: groups, height: 1, depth: 1),
                threadsPerThreadgroup: threadsPerThreadgroup
            )
        }
    }

    public func dispatchSIMDGroups1D(
        _ encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        simdgroupCount: Int,
        simdgroupsPerThreadgroup: Int
    ) {
        let simdWidth = max(1, pipeline.threadExecutionWidth)
        let groupsPerThreadgroup = max(1, min(
            simdgroupsPerThreadgroup,
            max(1, pipeline.maxTotalThreadsPerThreadgroup / simdWidth)
        ))
        let threadgroupCount = (simdgroupCount + groupsPerThreadgroup - 1) / groupsPerThreadgroup
        encoder.dispatchThreadgroups(
            MTLSize(width: threadgroupCount, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: simdWidth * groupsPerThreadgroup, height: 1, depth: 1)
        )
    }

    private func makeFunction(for spec: KernelSpec) throws -> MTLFunction {
        guard !spec.functionConstants.isEmpty else {
            return try library.makeFunction(name: spec.kernel).unwrap(or: AppleZKProverError.failedToReadMetalSource)
        }

        let values = MTLFunctionConstantValues()
        for (index, constant) in spec.functionConstants.sorted(by: { $0.key < $1.key }) {
            var value = constant
            values.setConstantValue(&value, type: .ulong, index: Int(index))
        }
        return try library.makeFunction(name: spec.kernel, constantValues: values)
    }

    private static func readMetalSource() throws -> String {
        guard let url = Bundle.module.url(forResource: "HashMerkleKernels", withExtension: "metal") else {
            throw AppleZKProverError.failedToLocateMetalSource
        }
        guard let source = try? String(contentsOf: url, encoding: .utf8) else {
            throw AppleZKProverError.failedToReadMetalSource
        }
        return source
    }

    private static func makeLibrary(device: MTLDevice, source: String) throws -> MTLLibrary {
        let options = MTLCompileOptions()
        options.fastMathEnabled = false
        return try device.makeLibrary(source: source, options: options)
    }

    private static func makeBinaryArchive(
        device: MTLDevice,
        capabilities: GPUCapabilities,
        configuration: MetalPipelineCacheConfiguration
    ) throws -> MTLBinaryArchive? {
        switch configuration.binaryArchiveMode {
        case .disabled:
            return nil
        case let .readOnly(url):
            guard capabilities.supportsBinaryArchives else {
                throw AppleZKProverError.failedToCreateBinaryArchive("Device does not support binary archives.")
            }
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw AppleZKProverError.failedToCreateBinaryArchive("Archive does not exist at \(url.path).")
            }
            return try openBinaryArchive(device: device, url: url)
        case let .readWrite(url):
            guard capabilities.supportsBinaryArchives else {
                throw AppleZKProverError.failedToCreateBinaryArchive("Device does not support binary archives.")
            }
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let existingURL = FileManager.default.fileExists(atPath: url.path) ? url : nil
            return try openBinaryArchive(device: device, url: existingURL)
        }
    }

    private static func openBinaryArchive(device: MTLDevice, url: URL?) throws -> MTLBinaryArchive {
        let descriptor = MTLBinaryArchiveDescriptor()
        descriptor.url = url
        do {
            return try device.makeBinaryArchive(descriptor: descriptor)
        } catch {
            throw AppleZKProverError.failedToCreateBinaryArchive(error.localizedDescription)
        }
    }

    private static func hashMetalSource(_ source: String) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
        #endif
    }

    private static func currentOSBuild() -> String {
        #if canImport(Darwin)
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: max(1, size))
        if sysctlbyname("kern.osversion", &buffer, &size, nil, 0) == 0 {
            return buffer.withUnsafeBufferPointer { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else {
                    return ProcessInfo.processInfo.operatingSystemVersionString
                }
                return String(cString: baseAddress)
            }
        }
        #endif
        return ProcessInfo.processInfo.operatingSystemVersionString
    }
}

private struct PipelineCacheKey: Hashable {
    let spec: KernelSpec
    let shaderSourceHash: String
}

private extension KernelSpec {
    func cacheLabel(shaderSourceHash: String) -> String {
        let constants = functionConstants
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        return "\(kernel).\(family.rawValue).\(queueMode.rawValue).\(constants).\(shaderSourceHash)"
    }
}

private extension Optional {
    func unwrap(or error: @autoclosure () -> Error) throws -> Wrapped {
        guard let self else { throw error() }
        return self
    }
}
#endif
