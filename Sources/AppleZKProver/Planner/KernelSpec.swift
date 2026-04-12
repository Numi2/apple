import Foundation

public struct KernelSpec: Hashable, Codable, Sendable {
    public enum Family: String, Codable, Sendable {
        case scalar
        case simdgroup
        case treelet
    }

    public enum QueueMode: String, Codable, Sendable {
        case metal3
        case metal4
    }

    public let kernel: String
    public let family: Family
    public let queueMode: QueueMode
    public let functionConstants: [UInt16: UInt64]
    public let threadsPerThreadgroup: UInt16
    public let simdgroupsPerThreadgroup: UInt8

    public init(
        kernel: String,
        family: Family,
        queueMode: QueueMode,
        functionConstants: [UInt16: UInt64] = [:],
        threadsPerThreadgroup: UInt16 = 0,
        simdgroupsPerThreadgroup: UInt8 = 0
    ) {
        self.kernel = kernel
        self.family = family
        self.queueMode = queueMode
        self.functionConstants = functionConstants
        self.threadsPerThreadgroup = threadsPerThreadgroup
        self.simdgroupsPerThreadgroup = simdgroupsPerThreadgroup
    }
}
