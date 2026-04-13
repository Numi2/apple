#if canImport(Metal)
import Foundation
import Metal

struct SharedUploadSlot: @unchecked Sendable {
    let buffer: MTLBuffer
    let offset: Int
    let capacity: Int
    let byteCount: Int
    let index: Int
}

final class SharedUploadRing: @unchecked Sendable {
    let buffer: MTLBuffer
    let slotCapacity: Int
    let slotStride: Int
    let slotCount: Int

    private var cursor = 0
    private let lock = NSLock()

    init(
        device: MTLDevice,
        slotCapacity: Int,
        slotCount: Int,
        alignment: Int = 256,
        label: String
    ) throws {
        guard slotCapacity >= 0, slotCount > 0, alignment > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let stride = try Self.align(max(1, slotCapacity), to: alignment)
        let totalLength = try checkedBufferLength(stride, slotCount)
        let buffer = try MetalBufferFactory.makeSharedBuffer(
            device: device,
            length: totalLength,
            label: label
        )
        self.buffer = buffer
        self.slotCapacity = slotCapacity
        self.slotStride = stride
        self.slotCount = slotCount
    }

    func reserve(byteCount: Int) throws -> SharedUploadSlot {
        guard byteCount >= 0, byteCount <= slotCapacity else {
            throw AppleZKProverError.invalidInputLayout
        }

        lock.lock()
        let index = cursor
        cursor = (cursor + 1) % slotCount
        lock.unlock()

        return SharedUploadSlot(
            buffer: buffer,
            offset: index * slotStride,
            capacity: slotCapacity,
            byteCount: byteCount,
            index: index
        )
    }

    func copy(_ bytes: Data, byteCount: Int) throws -> SharedUploadSlot {
        guard byteCount >= 0, bytes.count >= byteCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        let slot = try reserve(byteCount: byteCount)
        try MetalBufferFactory.copy(
            bytes,
            into: slot.buffer,
            destinationOffset: slot.offset,
            byteCount: byteCount
        )
        let tailByteCount = slotStride - byteCount
        if tailByteCount > 0 {
            try MetalBufferFactory.zeroSharedBuffer(
                slot.buffer,
                offset: slot.offset + byteCount,
                byteCount: tailByteCount
            )
        }
        return slot
    }

    func clear() {
        MetalBufferFactory.zeroSharedBuffer(buffer)
    }

    private static func align(_ value: Int, to alignment: Int) throws -> Int {
        let remainder = value % alignment
        guard remainder != 0 else {
            return value
        }
        let padding = alignment - remainder
        let aligned = value.addingReportingOverflow(padding)
        guard !aligned.overflow else {
            throw AppleZKProverError.invalidInputLayout
        }
        return aligned.partialValue
    }
}
#endif
