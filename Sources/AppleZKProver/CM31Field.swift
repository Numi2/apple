import Foundation

public struct CM31Element: Equatable, Sendable {
    public let real: UInt32
    public let imaginary: UInt32

    public init(real: UInt32, imaginary: UInt32) {
        self.real = real
        self.imaginary = imaginary
    }
}

public enum CM31VectorOperation: UInt32, Sendable, CaseIterable {
    case add = 0
    case subtract = 1
    case negate = 2
    case multiply = 3
    case square = 4

    public var requiresRightHandSide: Bool {
        switch self {
        case .add, .subtract, .multiply:
            return true
        case .negate, .square:
            return false
        }
    }
}

public enum CM31Field {
    public static let modulus = M31Field.modulus

    public static func validateCanonical(_ values: [CM31Element]) throws {
        for value in values {
            guard value.real < modulus, value.imaginary < modulus else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
    }

    public static func add(_ lhs: CM31Element, _ rhs: CM31Element) -> CM31Element {
        CM31Element(
            real: M31Field.add(lhs.real, rhs.real),
            imaginary: M31Field.add(lhs.imaginary, rhs.imaginary)
        )
    }

    public static func subtract(_ lhs: CM31Element, _ rhs: CM31Element) -> CM31Element {
        CM31Element(
            real: M31Field.subtract(lhs.real, rhs.real),
            imaginary: M31Field.subtract(lhs.imaginary, rhs.imaginary)
        )
    }

    public static func negate(_ value: CM31Element) -> CM31Element {
        CM31Element(
            real: M31Field.negate(value.real),
            imaginary: M31Field.negate(value.imaginary)
        )
    }

    public static func multiply(_ lhs: CM31Element, _ rhs: CM31Element) -> CM31Element {
        let ac = M31Field.multiply(lhs.real, rhs.real)
        let bd = M31Field.multiply(lhs.imaginary, rhs.imaginary)
        let ad = M31Field.multiply(lhs.real, rhs.imaginary)
        let bc = M31Field.multiply(lhs.imaginary, rhs.real)
        return CM31Element(
            real: M31Field.subtract(ac, bd),
            imaginary: M31Field.add(ad, bc)
        )
    }

    public static func square(_ value: CM31Element) -> CM31Element {
        let real = M31Field.subtract(
            M31Field.square(value.real),
            M31Field.square(value.imaginary)
        )
        let cross = M31Field.multiply(value.real, value.imaginary)
        return CM31Element(real: real, imaginary: M31Field.add(cross, cross))
    }

    public static func apply(
        _ operation: CM31VectorOperation,
        lhs: [CM31Element],
        rhs: [CM31Element]? = nil
    ) throws -> [CM31Element] {
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
                case .negate, .square:
                    preconditionFailure("unary CM31 operation reached binary oracle path")
                }
            }
        }

        guard rhs == nil else {
            throw AppleZKProverError.invalidInputLayout
        }
        return lhs.map { value in
            switch operation {
            case .negate:
                return negate(value)
            case .square:
                return square(value)
            case .add, .subtract, .multiply:
                preconditionFailure("binary CM31 operation reached unary oracle path")
            }
        }
    }
}
