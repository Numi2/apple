import Foundation

public enum PlannerFunctionConstant: UInt16, Sendable {
    case leafBytes = 1
    case parentBytes = 2
    case treeArity = 3
    case treeletDepth = 4
    case fixedWidthCase = 5
    case sumcheckMode = 6
    case barrierCadence = 7
    case domainSuffix = 8
}

extension Dictionary where Key == UInt16, Value == UInt64 {
    static func plannerConstants(_ pairs: [(PlannerFunctionConstant, UInt64)]) -> [UInt16: UInt64] {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.rawValue, $0.1) })
    }
}
