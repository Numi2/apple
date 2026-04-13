#if canImport(Metal)
import Foundation
import Metal

public struct ArenaSlice: @unchecked Sendable {
    public enum Role: String, Sendable {
        case leafHashes
        case frontierNodes
        case sumcheckVector
        case coefficients
        case challenges
        case transcriptState
        case scratch
    }

    public let buffer: MTLBuffer
    public let offset: Int
    public let length: Int
    public let role: Role

    public init(buffer: MTLBuffer, offset: Int, length: Int, role: Role) {
        self.buffer = buffer
        self.offset = offset
        self.length = length
        self.role = role
    }
}

public struct BufferHandle: @unchecked Sendable {
    public let slice: ArenaSlice

    public init(slice: ArenaSlice) {
        self.slice = slice
    }
}

public final class ResidencyArena: @unchecked Sendable {
    public let buffer: MTLBuffer
    public let capacity: Int

    private var cursor = 0
    private let lock = NSLock()

    public init(device: MTLDevice, capacity: Int, label: String = "AppleZKProver.ResidencyArena") throws {
        let allocationLength = max(1, capacity)
        guard let buffer = device.makeBuffer(length: allocationLength, options: .storageModePrivate) else {
            throw AppleZKProverError.failedToCreateBuffer(label: label, length: capacity)
        }
        buffer.label = label
        self.buffer = buffer
        self.capacity = allocationLength
    }

    public func reset() {
        lock.lock()
        cursor = 0
        lock.unlock()
    }

    public func allocate(
        length: Int,
        alignment: Int = 256,
        role: ArenaSlice.Role
    ) throws -> ArenaSlice {
        guard length >= 0, alignment > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }

        lock.lock()
        defer { lock.unlock() }

        let alignedOffset = try Self.align(cursor, to: alignment)
        let end = alignedOffset.addingReportingOverflow(max(1, length))
        guard !end.overflow, end.partialValue <= capacity else {
            throw AppleZKProverError.failedToCreateBuffer(label: "ResidencyArena.\(role.rawValue)", length: length)
        }
        cursor = end.partialValue
        return ArenaSlice(buffer: buffer, offset: alignedOffset, length: length, role: role)
    }

    private static func align(_ value: Int, to alignment: Int) throws -> Int {
        let remainder = value % alignment
        guard remainder != 0 else {
            return value
        }
        let aligned = value.addingReportingOverflow(alignment - remainder)
        guard !aligned.overflow else {
            throw AppleZKProverError.invalidInputLayout
        }
        return aligned.partialValue
    }
}
#endif
