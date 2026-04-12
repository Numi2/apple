#if canImport(Metal)
import Foundation
import Metal

enum MetalBufferFactory {
    static func makeSharedBuffer(
        device: MTLDevice,
        length: Int,
        label: String
    ) throws -> MTLBuffer {
        let allocationLength = max(1, length)
        guard let buffer = device.makeBuffer(length: allocationLength, options: .storageModeShared) else {
            throw AppleZKProverError.failedToCreateBuffer(label: label, length: length)
        }
        buffer.label = label
        return buffer
    }

    static func makeSharedBuffer(
        device: MTLDevice,
        bytes: Data,
        declaredLength: Int,
        label: String
    ) throws -> MTLBuffer {
        guard bytes.count >= declaredLength else {
            throw AppleZKProverError.invalidInputLayout
        }
        let buffer = try makeSharedBuffer(device: device, length: declaredLength, label: label)
        try copy(bytes, into: buffer, byteCount: declaredLength)
        return buffer
    }

    static func makePrivateBuffer(
        device: MTLDevice,
        length: Int,
        label: String
    ) throws -> MTLBuffer {
        let allocationLength = max(1, length)
        guard let buffer = device.makeBuffer(length: allocationLength, options: .storageModePrivate) else {
            throw AppleZKProverError.failedToCreateBuffer(label: label, length: length)
        }
        buffer.label = label
        return buffer
    }

    static func copy(_ bytes: Data, into buffer: MTLBuffer, byteCount: Int) throws {
        guard byteCount >= 0,
              bytes.count >= byteCount,
              buffer.length >= max(1, byteCount) else {
            throw AppleZKProverError.invalidInputLayout
        }
        guard byteCount > 0 else {
            return
        }

        bytes.withUnsafeBytes { rawBuffer in
            guard let source = rawBuffer.baseAddress else {
                return
            }
            buffer.contents().copyMemory(from: source, byteCount: byteCount)
        }
    }

    static func zeroSharedBuffer(_ buffer: MTLBuffer) {
        UnsafeMutableRawBufferPointer(start: buffer.contents(), count: buffer.length)
            .initializeMemory(as: UInt8.self, repeating: 0)
    }

    static func zeroPrivateBuffers(
        _ buffers: [MTLBuffer],
        context: MetalContext,
        label: String
    ) throws {
        guard !buffers.isEmpty else {
            return
        }
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = label

        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        blit.label = "\(label).Clear"
        for buffer in buffers {
            blit.fill(buffer: buffer, range: 0..<buffer.length, value: 0)
        }
        blit.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }
    }
}
#endif
