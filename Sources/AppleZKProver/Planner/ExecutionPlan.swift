import Foundation

public struct ExecutionPlan: Hashable, Codable, Sendable {
    public enum ReadbackPoint: String, Hashable, Codable, Sendable {
        case finalRoot
        case finalProofBytes
        case debugTap
    }

    public struct BufferLayout: Hashable, Codable, Sendable {
        public let uploadBytes: Int
        public let privateArenaBytes: Int
        public let readbackBytes: Int

        public init(uploadBytes: Int, privateArenaBytes: Int, readbackBytes: Int) {
            self.uploadBytes = uploadBytes
            self.privateArenaBytes = privateArenaBytes
            self.readbackBytes = readbackBytes
        }
    }

    public let workload: WorkloadSignature
    public let queueMode: KernelSpec.QueueMode
    public let kernels: [KernelSpec]
    public let bufferLayout: BufferLayout
    public let commandBufferChunks: UInt8
    public let readbackPoints: [ReadbackPoint]

    public init(
        workload: WorkloadSignature,
        queueMode: KernelSpec.QueueMode,
        kernels: [KernelSpec],
        bufferLayout: BufferLayout,
        commandBufferChunks: UInt8,
        readbackPoints: [ReadbackPoint]
    ) {
        self.workload = workload
        self.queueMode = queueMode
        self.kernels = kernels
        self.bufferLayout = bufferLayout
        self.commandBufferChunks = commandBufferChunks
        self.readbackPoints = readbackPoints
    }
}
