import Foundation

public struct WorkloadSignature: Hashable, Codable, Sendable {
    public enum Stage: String, Codable, Sendable {
        case merkleCommit
        case merkleOpen
        case sumcheckChunk
        case transcript
    }

    public enum Field: String, Codable, Sendable {
        case bytes
        case m31
        case binaryTower
    }

    public let stage: Stage
    public let field: Field
    public let inputLog2: UInt8
    public let leafBytes: UInt16
    public let arity: UInt8
    public let roundsPerSuperstep: UInt8
    public let fixedWidthCase: UInt16

    public init(
        stage: Stage,
        field: Field,
        inputLog2: UInt8,
        leafBytes: UInt16,
        arity: UInt8,
        roundsPerSuperstep: UInt8,
        fixedWidthCase: UInt16
    ) {
        self.stage = stage
        self.field = field
        self.inputLog2 = inputLog2
        self.leafBytes = leafBytes
        self.arity = arity
        self.roundsPerSuperstep = roundsPerSuperstep
        self.fixedWidthCase = fixedWidthCase
    }
}
