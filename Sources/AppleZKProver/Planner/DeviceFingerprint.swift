import Foundation

public struct DeviceFingerprint: Hashable, Codable, Sendable {
    public let registryID: UInt64
    public let name: String
    public let osBuild: String
    public let supportsApple4: Bool
    public let supportsApple7: Bool
    public let supportsApple9: Bool
    public let supportsMetal4Queue: Bool
    public let maxThreadsPerThreadgroup: Int
    public let hasUnifiedMemory: Bool

    public init(
        registryID: UInt64,
        name: String,
        osBuild: String,
        supportsApple4: Bool,
        supportsApple7: Bool,
        supportsApple9: Bool,
        supportsMetal4Queue: Bool,
        maxThreadsPerThreadgroup: Int,
        hasUnifiedMemory: Bool
    ) {
        self.registryID = registryID
        self.name = name
        self.osBuild = osBuild
        self.supportsApple4 = supportsApple4
        self.supportsApple7 = supportsApple7
        self.supportsApple9 = supportsApple9
        self.supportsMetal4Queue = supportsMetal4Queue
        self.maxThreadsPerThreadgroup = maxThreadsPerThreadgroup
        self.hasUnifiedMemory = hasUnifiedMemory
    }
}
