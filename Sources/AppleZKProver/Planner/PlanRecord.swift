import Foundation

public struct PlanRecord: Codable, Sendable {
    public let device: DeviceFingerprint
    public let workload: WorkloadSignature
    public let winner: KernelSpec
    public let medianGPUTimeNS: Double
    public let medianCPUSubmitNS: Double
    public let p95GPUTimeNS: Double
    public let readbacks: Int
    public let confidence: Double
    public let shaderHash: String
    public let protocolHash: String

    public init(
        device: DeviceFingerprint,
        workload: WorkloadSignature,
        winner: KernelSpec,
        medianGPUTimeNS: Double,
        medianCPUSubmitNS: Double,
        p95GPUTimeNS: Double,
        readbacks: Int,
        confidence: Double,
        shaderHash: String,
        protocolHash: String
    ) {
        self.device = device
        self.workload = workload
        self.winner = winner
        self.medianGPUTimeNS = medianGPUTimeNS
        self.medianCPUSubmitNS = medianCPUSubmitNS
        self.p95GPUTimeNS = p95GPUTimeNS
        self.readbacks = readbacks
        self.confidence = confidence
        self.shaderHash = shaderHash
        self.protocolHash = protocolHash
    }
}
