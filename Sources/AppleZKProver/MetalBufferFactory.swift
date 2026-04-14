#if canImport(Metal)
import Foundation
import Metal
#if canImport(Darwin)
import Darwin
#endif

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
        guard declaredLength >= 0,
              bytes.count >= declaredLength else {
            throw AppleZKProverError.invalidInputLayout
        }
        let buffer: MTLBuffer?
        if declaredLength == 0 {
            buffer = device.makeBuffer(length: 1, options: .storageModeShared)
        } else {
            buffer = bytes.withUnsafeBytes { rawBuffer in
                rawBuffer.baseAddress.flatMap {
                    device.makeBuffer(bytes: $0, length: declaredLength, options: .storageModeShared)
                }
            }
        }
        guard let buffer else {
            throw AppleZKProverError.failedToCreateBuffer(label: label, length: declaredLength)
        }
        buffer.label = label
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
        try copy(bytes, into: buffer, destinationOffset: 0, byteCount: byteCount)
    }

    static func copy(
        _ bytes: Data,
        into buffer: MTLBuffer,
        destinationOffset: Int,
        byteCount: Int
    ) throws {
        let requiredLength = destinationOffset.addingReportingOverflow(max(1, byteCount))
        guard byteCount >= 0,
              destinationOffset >= 0,
              bytes.count >= byteCount,
              !requiredLength.overflow,
              buffer.length >= requiredLength.partialValue else {
            throw AppleZKProverError.invalidInputLayout
        }
        guard byteCount > 0 else {
            return
        }

        bytes.withUnsafeBytes { rawBuffer in
            guard let source = rawBuffer.baseAddress else {
                return
            }
            buffer.contents()
                .advanced(by: destinationOffset)
                .copyMemory(from: source, byteCount: byteCount)
        }
    }

    static func zeroSharedBuffer(_ buffer: MTLBuffer) {
        zeroSharedBufferUnchecked(buffer, offset: 0, byteCount: buffer.length)
    }

    static func zeroSharedBuffer(
        _ buffer: MTLBuffer,
        offset: Int,
        byteCount: Int
    ) throws {
        let end = offset.addingReportingOverflow(byteCount)
        guard offset >= 0,
              byteCount >= 0,
              !end.overflow,
              end.partialValue <= buffer.length else {
            throw AppleZKProverError.invalidInputLayout
        }
        zeroSharedBufferUnchecked(buffer, offset: offset, byteCount: byteCount)
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

    private static func zeroSharedBufferUnchecked(
        _ buffer: MTLBuffer,
        offset: Int,
        byteCount: Int
    ) {
        guard byteCount > 0 else {
            return
        }
        let destination = buffer.contents().advanced(by: offset)
        #if canImport(Darwin)
        _ = memset_s(destination, byteCount, 0, byteCount)
        #else
        memset(destination, 0, byteCount)
        #endif
    }
}
#endif
