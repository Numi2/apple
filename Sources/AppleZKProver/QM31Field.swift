import Foundation

public struct QM31Element: Equatable, Codable, Sendable {
    public let constant: CM31Element
    public let uCoefficient: CM31Element

    public init(constant: CM31Element, uCoefficient: CM31Element) {
        self.constant = constant
        self.uCoefficient = uCoefficient
    }

    public init(a: UInt32, b: UInt32, c: UInt32, d: UInt32) {
        self.constant = CM31Element(real: a, imaginary: b)
        self.uCoefficient = CM31Element(real: c, imaginary: d)
    }
}

public enum QM31VectorOperation: UInt32, Sendable, CaseIterable {
    case add = 0
    case subtract = 1
    case negate = 2
    case multiply = 3
    case square = 4
    case inverse = 5

    public var requiresRightHandSide: Bool {
        switch self {
        case .add, .subtract, .multiply:
            return true
        case .negate, .square, .inverse:
            return false
        }
    }
}

public enum QM31Field {
    public static let modulus = M31Field.modulus
    public static let nonResidue = CM31Element(real: 2, imaginary: 1)

    public static func validateCanonical(_ values: [QM31Element]) throws {
        for value in values {
            guard value.constant.real < modulus,
                  value.constant.imaginary < modulus,
                  value.uCoefficient.real < modulus,
                  value.uCoefficient.imaginary < modulus else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
    }

    public static func isZero(_ value: QM31Element) -> Bool {
        value.constant.real == 0 &&
            value.constant.imaginary == 0 &&
            value.uCoefficient.real == 0 &&
            value.uCoefficient.imaginary == 0
    }

    public static func add(_ lhs: QM31Element, _ rhs: QM31Element) -> QM31Element {
        QM31Element(
            constant: CM31Field.add(lhs.constant, rhs.constant),
            uCoefficient: CM31Field.add(lhs.uCoefficient, rhs.uCoefficient)
        )
    }

    public static func subtract(_ lhs: QM31Element, _ rhs: QM31Element) -> QM31Element {
        QM31Element(
            constant: CM31Field.subtract(lhs.constant, rhs.constant),
            uCoefficient: CM31Field.subtract(lhs.uCoefficient, rhs.uCoefficient)
        )
    }

    public static func negate(_ value: QM31Element) -> QM31Element {
        QM31Element(
            constant: CM31Field.negate(value.constant),
            uCoefficient: CM31Field.negate(value.uCoefficient)
        )
    }

    public static func multiply(_ lhs: QM31Element, _ rhs: QM31Element) -> QM31Element {
        let ac = CM31Field.multiply(lhs.constant, rhs.constant)
        let bd = CM31Field.multiply(lhs.uCoefficient, rhs.uCoefficient)
        let ad = CM31Field.multiply(lhs.constant, rhs.uCoefficient)
        let bc = CM31Field.multiply(lhs.uCoefficient, rhs.constant)
        return QM31Element(
            constant: CM31Field.add(ac, CM31Field.multiply(nonResidue, bd)),
            uCoefficient: CM31Field.add(ad, bc)
        )
    }

    public static func square(_ value: QM31Element) -> QM31Element {
        let aa = CM31Field.square(value.constant)
        let bb = CM31Field.square(value.uCoefficient)
        let ab = CM31Field.multiply(value.constant, value.uCoefficient)
        return QM31Element(
            constant: CM31Field.add(aa, CM31Field.multiply(nonResidue, bb)),
            uCoefficient: CM31Field.add(ab, ab)
        )
    }

    public static func inverse(_ value: QM31Element) throws -> QM31Element {
        try validateCanonical([value])
        guard !isZero(value) else {
            throw AppleZKProverError.invalidInputLayout
        }

        let aa = CM31Field.square(value.constant)
        let bb = CM31Field.square(value.uCoefficient)
        let denominator = CM31Field.subtract(aa, CM31Field.multiply(nonResidue, bb))
        let denominatorInverse = try CM31Field.inverse(denominator)
        return QM31Element(
            constant: CM31Field.multiply(value.constant, denominatorInverse),
            uCoefficient: CM31Field.multiply(CM31Field.negate(value.uCoefficient), denominatorInverse)
        )
    }

    public static func batchInverse(_ values: [QM31Element]) throws -> [QM31Element] {
        guard !values.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        try validateCanonical(values)
        guard values.allSatisfy({ !isZero($0) }) else {
            throw AppleZKProverError.invalidInputLayout
        }

        var prefixes = Array(repeating: QM31Element(a: 1, b: 0, c: 0, d: 0), count: values.count)
        var accumulator = QM31Element(a: 1, b: 0, c: 0, d: 0)
        for index in values.indices {
            prefixes[index] = accumulator
            accumulator = multiply(accumulator, values[index])
        }

        var inverseAccumulator = try inverse(accumulator)
        var inverses = Array(repeating: QM31Element(a: 0, b: 0, c: 0, d: 0), count: values.count)
        for index in values.indices.reversed() {
            inverses[index] = multiply(inverseAccumulator, prefixes[index])
            inverseAccumulator = multiply(inverseAccumulator, values[index])
        }
        return inverses
    }

    public static func apply(
        _ operation: QM31VectorOperation,
        lhs: [QM31Element],
        rhs: [QM31Element]? = nil
    ) throws -> [QM31Element] {
        try validateCanonical(lhs)
        if operation.requiresRightHandSide {
            guard let rhs, rhs.count == lhs.count else {
                throw AppleZKProverError.invalidInputLayout
            }
            try validateCanonical(rhs)
            return zip(lhs, rhs).map { left, right in
                switch operation {
                case .add:
                    return add(left, right)
                case .subtract:
                    return subtract(left, right)
                case .multiply:
                    return multiply(left, right)
                case .negate, .square, .inverse:
                    preconditionFailure("unary QM31 operation reached binary oracle path")
                }
            }
        }

        guard rhs == nil else {
            throw AppleZKProverError.invalidInputLayout
        }
        if operation == .inverse {
            return try batchInverse(lhs)
        }
        return lhs.map { value in
            switch operation {
            case .negate:
                return negate(value)
            case .square:
                return square(value)
            case .add, .subtract, .multiply:
                preconditionFailure("binary QM31 operation reached unary oracle path")
            case .inverse:
                preconditionFailure("QM31 inverse reached non-batch oracle path")
            }
        }
    }
}
