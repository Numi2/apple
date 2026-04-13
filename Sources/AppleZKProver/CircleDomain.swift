import Foundation

public struct CirclePointM31: Equatable, Sendable {
    public static let identity = CirclePointM31(x: 1, y: 0)
    public static let generator = CirclePointM31(x: 2, y: 1_268_011_823)

    public let x: UInt32
    public let y: UInt32

    public init(x: UInt32, y: UInt32) {
        self.x = x
        self.y = y
    }

    public func doubled() -> CirclePointM31 {
        adding(self)
    }

    public func repeatedDouble(_ count: UInt32) -> CirclePointM31 {
        var result = self
        for _ in 0..<count {
            result = result.doubled()
        }
        return result
    }

    public func conjugate() -> CirclePointM31 {
        CirclePointM31(x: x, y: M31Field.negate(y))
    }

    public func adding(_ rhs: CirclePointM31) -> CirclePointM31 {
        let xProduct = M31Field.multiply(x, rhs.x)
        let yProduct = M31Field.multiply(y, rhs.y)
        let crossLeft = M31Field.multiply(x, rhs.y)
        let crossRight = M31Field.multiply(y, rhs.x)
        return CirclePointM31(
            x: M31Field.subtract(xProduct, yProduct),
            y: M31Field.add(crossLeft, crossRight)
        )
    }

    public func multiplied(by scalar: UInt64) -> CirclePointM31 {
        var result = CirclePointM31.identity
        var power = self
        var remaining = scalar
        while remaining > 0 {
            if remaining & 1 == 1 {
                result = result.adding(power)
            }
            remaining >>= 1
            if remaining > 0 {
                power = power.doubled()
            }
        }
        return result
    }
}

public struct CirclePointIndex: Equatable, Comparable, Sendable {
    public static let circleLogOrder: UInt32 = 31
    public static let circleOrder: UInt64 = UInt64(1) << Int(circleLogOrder)
    public static let circleOrderMask: UInt64 = circleOrder - 1
    public static let zero = CirclePointIndex(rawValue: 0)
    public static let generator = CirclePointIndex(rawValue: 1)

    public let rawValue: UInt32

    public init(rawValue: UInt64) {
        self.rawValue = UInt32(rawValue & Self.circleOrderMask)
    }

    public static func < (lhs: CirclePointIndex, rhs: CirclePointIndex) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func subgroupGenerator(logSize: UInt32) throws -> CirclePointIndex {
        guard logSize <= circleLogOrder else {
            throw AppleZKProverError.invalidInputLayout
        }
        return CirclePointIndex(rawValue: UInt64(1) << Int(circleLogOrder - logSize))
    }

    public func adding(_ rhs: CirclePointIndex) -> CirclePointIndex {
        CirclePointIndex(rawValue: UInt64(rawValue) + UInt64(rhs.rawValue))
    }

    public func negated() -> CirclePointIndex {
        CirclePointIndex(rawValue: Self.circleOrder - UInt64(rawValue))
    }

    public func multiplied(by scalar: Int) throws -> CirclePointIndex {
        guard scalar >= 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let reducedScalar = UInt64(scalar) & Self.circleOrderMask
        return CirclePointIndex(rawValue: UInt64(rawValue) * reducedScalar)
    }

    public func toPoint() -> CirclePointM31 {
        CirclePointM31.generator.multiplied(by: UInt64(rawValue))
    }
}

public struct CircleCoset: Equatable, Sendable {
    public let initialIndex: CirclePointIndex
    public let stepSize: CirclePointIndex
    public let logSize: UInt32

    public init(initialIndex: CirclePointIndex, logSize: UInt32) throws {
        guard logSize <= CirclePointIndex.circleLogOrder else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.initialIndex = initialIndex
        self.stepSize = try CirclePointIndex.subgroupGenerator(logSize: logSize)
        self.logSize = logSize
    }

    public static func subgroup(logSize: UInt32) throws -> CircleCoset {
        try CircleCoset(initialIndex: .zero, logSize: logSize)
    }

    public static func odds(logSize: UInt32) throws -> CircleCoset {
        guard logSize < CirclePointIndex.circleLogOrder else {
            throw AppleZKProverError.invalidInputLayout
        }
        let initial = try CirclePointIndex.subgroupGenerator(logSize: logSize + 1)
        return try CircleCoset(initialIndex: initial, logSize: logSize)
    }

    public static func halfOdds(logSize: UInt32) throws -> CircleCoset {
        guard logSize <= CirclePointIndex.circleLogOrder - 2 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let initial = try CirclePointIndex.subgroupGenerator(logSize: logSize + 2)
        return try CircleCoset(initialIndex: initial, logSize: logSize)
    }

    public var size: Int {
        1 << Int(logSize)
    }

    public var initial: CirclePointM31 {
        initialIndex.toPoint()
    }

    public var step: CirclePointM31 {
        stepSize.toPoint()
    }

    public func index(at offset: Int) throws -> CirclePointIndex {
        guard offset >= 0, offset < size else {
            throw AppleZKProverError.invalidInputLayout
        }
        return initialIndex.adding(try stepSize.multiplied(by: offset))
    }

    public func point(at offset: Int) throws -> CirclePointM31 {
        try index(at: offset).toPoint()
    }

    public func doubled() throws -> CircleCoset {
        guard logSize > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try CircleCoset(
            initialIndex: try initialIndex.multiplied(by: 2),
            logSize: logSize - 1
        )
    }

    public func conjugate() throws -> CircleCoset {
        let conjugate = try CircleCoset(initialIndex: initialIndex.negated(), logSize: logSize)
        return CircleCoset(
            initialIndex: conjugate.initialIndex,
            stepSize: stepSize.negated(),
            logSize: logSize
        )
    }

    private init(initialIndex: CirclePointIndex, stepSize: CirclePointIndex, logSize: UInt32) {
        self.initialIndex = initialIndex
        self.stepSize = stepSize
        self.logSize = logSize
    }
}

public enum CircleDomainStorageOrder: UInt32, CaseIterable, Sendable {
    case circleDomainNatural = 0
    case circleDomainBitReversed = 1
    case cosetNatural = 2
}

public struct CircleDomainDescriptor: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1
    public static let maximumLogSize: UInt32 = CirclePointIndex.circleLogOrder - 1
    public static let minimumLogSize: UInt32 = 1

    public let version: UInt32
    public let logSize: UInt32
    public let halfCosetInitialIndex: CirclePointIndex
    public let halfCosetLogSize: UInt32
    public let storageOrder: CircleDomainStorageOrder

    public init(
        version: UInt32 = currentVersion,
        logSize: UInt32,
        halfCosetInitialIndex: CirclePointIndex,
        halfCosetLogSize: UInt32,
        storageOrder: CircleDomainStorageOrder = .circleDomainBitReversed
    ) throws {
        guard version == Self.currentVersion,
              logSize >= Self.minimumLogSize,
              logSize <= Self.maximumLogSize,
              halfCosetLogSize <= Self.maximumLogSize - 1,
              halfCosetLogSize == logSize - 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.logSize = logSize
        self.halfCosetInitialIndex = halfCosetInitialIndex
        self.halfCosetLogSize = halfCosetLogSize
        self.storageOrder = storageOrder
    }

    public static func canonical(
        logSize: UInt32,
        storageOrder: CircleDomainStorageOrder = .circleDomainBitReversed
    ) throws -> CircleDomainDescriptor {
        guard logSize >= minimumLogSize, logSize <= maximumLogSize else {
            throw AppleZKProverError.invalidInputLayout
        }
        let halfCoset = try CircleCoset.halfOdds(logSize: logSize - 1)
        return try CircleDomainDescriptor(
            logSize: logSize,
            halfCosetInitialIndex: halfCoset.initialIndex,
            halfCosetLogSize: halfCoset.logSize,
            storageOrder: storageOrder
        )
    }

    public var size: Int {
        1 << Int(logSize)
    }

    public var halfSize: Int {
        size / 2
    }

    public var halfCoset: CircleCoset {
        get throws {
            try CircleCoset(initialIndex: halfCosetInitialIndex, logSize: halfCosetLogSize)
        }
    }

    public var isCanonical: Bool {
        guard let step = try? CirclePointIndex.subgroupGenerator(logSize: halfCosetLogSize) else {
            return false
        }
        let fourInitial = (try? halfCosetInitialIndex.multiplied(by: 4)) ?? .zero
        return fourInitial == step
    }
}

public enum CircleDomainOracle {
    public static func validatePoint(_ point: CirclePointM31) throws {
        try M31Field.validateCanonical([point.x, point.y])
        let norm = M31Field.add(M31Field.square(point.x), M31Field.square(point.y))
        guard norm == 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
    }

    public static func pointIndex(
        in descriptor: CircleDomainDescriptor,
        naturalDomainIndex: Int
    ) throws -> CirclePointIndex {
        guard naturalDomainIndex >= 0, naturalDomainIndex < descriptor.size else {
            throw AppleZKProverError.invalidInputLayout
        }
        let halfCoset = try descriptor.halfCoset
        if naturalDomainIndex < descriptor.halfSize {
            return try halfCoset.index(at: naturalDomainIndex)
        }
        return try halfCoset.index(at: naturalDomainIndex - descriptor.halfSize).negated()
    }

    public static func point(
        in descriptor: CircleDomainDescriptor,
        naturalDomainIndex: Int
    ) throws -> CirclePointM31 {
        try pointIndex(in: descriptor, naturalDomainIndex: naturalDomainIndex).toPoint()
    }

    public static func storagePointIndices(
        for descriptor: CircleDomainDescriptor
    ) throws -> [CirclePointIndex] {
        try (0..<descriptor.size).map { storageIndex in
            let naturalIndex = try naturalDomainIndex(forStorageIndex: storageIndex, descriptor: descriptor)
            return try pointIndex(in: descriptor, naturalDomainIndex: naturalIndex)
        }
    }

    public static func naturalDomainIndex(
        forStorageIndex storageIndex: Int,
        descriptor: CircleDomainDescriptor
    ) throws -> Int {
        guard storageIndex >= 0, storageIndex < descriptor.size else {
            throw AppleZKProverError.invalidInputLayout
        }
        switch descriptor.storageOrder {
        case .circleDomainNatural:
            return storageIndex
        case .circleDomainBitReversed:
            return bitReverseIndex(storageIndex, logSize: descriptor.logSize)
        case .cosetNatural:
            return cosetIndexToCircleDomainIndex(storageIndex, logSize: descriptor.logSize)
        }
    }

    public static func bitReverseIndex(_ index: Int, logSize: UInt32) -> Int {
        guard logSize > 0 else {
            return index
        }
        var value = index
        var reversed = 0
        for _ in 0..<logSize {
            reversed = (reversed << 1) | (value & 1)
            value >>= 1
        }
        return reversed
    }

    public static func doubleX(_ x: UInt32) -> UInt32 {
        M31Field.subtract(M31Field.add(M31Field.square(x), M31Field.square(x)), 1)
    }

    public static func circleDomainIndexToCosetIndex(_ circleIndex: Int, logSize: UInt32) -> Int {
        let n = 1 << Int(logSize)
        if circleIndex < n / 2 {
            return circleIndex * 2
        }
        return (n - 1 - circleIndex) * 2 + 1
    }

    public static func cosetIndexToCircleDomainIndex(_ cosetIndex: Int, logSize: UInt32) -> Int {
        if cosetIndex.isMultiple(of: 2) {
            return cosetIndex / 2
        }
        return ((2 << Int(logSize)) - cosetIndex) / 2
    }

    public static func cosetOrderToCircleDomainOrder<T>(_ values: [T]) throws -> [T] {
        guard !values.isEmpty, values.count.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let half = values.count / 2
        var result: [T] = []
        result.reserveCapacity(values.count)
        for index in 0..<half {
            result.append(values[index << 1])
        }
        for index in 0..<half {
            result.append(values[values.count - 1 - (index << 1)])
        }
        return result
    }

    public static func bitReverseCircleDomainOrder<T>(_ values: [T]) throws -> [T] {
        guard !values.isEmpty, values.count.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let logSize = UInt32(log2(values.count))
        var result = values
        for index in 0..<result.count {
            let reversed = bitReverseIndex(index, logSize: logSize)
            if reversed > index {
                result.swapAt(index, reversed)
            }
        }
        return result
    }

    public static func bitReverseCosetToCircleDomainOrder<T>(_ values: [T]) throws -> [T] {
        guard !values.isEmpty, values.count.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let logSize = UInt32(log2(values.count))
        var result = values
        for index in 0..<result.count {
            let circleIndex = cosetIndexToCircleDomainIndex(index, logSize: logSize)
            let target = bitReverseIndex(circleIndex, logSize: logSize)
            if target > index {
                result.swapAt(index, target)
            }
        }
        return result
    }

    public static func firstFoldInverseYTwiddles(
        for descriptor: CircleDomainDescriptor
    ) throws -> [QM31Element] {
        guard descriptor.storageOrder == .circleDomainBitReversed else {
            throw AppleZKProverError.invalidInputLayout
        }
        var twiddles: [QM31Element] = []
        twiddles.reserveCapacity(descriptor.halfSize)
        for pairIndex in 0..<descriptor.halfSize {
            let naturalDomainIndex = bitReverseIndex(pairIndex << 1, logSize: descriptor.logSize)
            let point = try point(in: descriptor, naturalDomainIndex: naturalDomainIndex)
            try validatePoint(point)
            guard point.y != 0 else {
                throw AppleZKProverError.invalidInputLayout
            }
            let inverseY = try M31Field.inverse(point.y)
            twiddles.append(QM31Element(a: inverseY, b: 0, c: 0, d: 0))
        }
        return twiddles
    }

    public static func foldQueryIndex(
        bitReversedStorageIndex: Int,
        foldStep: UInt32,
        sourceLogSize: UInt32
    ) throws -> Int {
        guard foldStep > 0,
              sourceLogSize >= foldStep,
              bitReversedStorageIndex >= 0,
              bitReversedStorageIndex < (1 << Int(sourceLogSize)) else {
            throw AppleZKProverError.invalidInputLayout
        }
        return bitReversedStorageIndex >> Int(foldStep)
    }

    private static func log2(_ value: Int) -> Int {
        var remaining = max(1, value)
        var result = 0
        while remaining > 1 {
            remaining >>= 1
            result += 1
        }
        return result
    }
}

public enum CircleFRIFoldOracle {
    public static func foldCircleIntoLine(
        evaluations: [QM31Element],
        domain: CircleDomainDescriptor,
        challenge: QM31Element
    ) throws -> [QM31Element] {
        guard domain.storageOrder == .circleDomainBitReversed,
              evaluations.count == domain.size,
              evaluations.count > 1,
              evaluations.count.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        try QM31Field.validateCanonical([challenge])
        let inverseYTwiddles = try CircleDomainOracle.firstFoldInverseYTwiddles(for: domain)
        return try QM31FRIFoldOracle.fold(
            evaluations: evaluations,
            inverseDomainPoints: inverseYTwiddles,
            challenge: challenge
        )
    }
}

public enum CircleFRILayerOracleV1 {
    public static func inverseDomainLayers(
        for domain: CircleDomainDescriptor,
        roundCount: Int
    ) throws -> [[QM31Element]] {
        guard domain.storageOrder == .circleDomainBitReversed,
              domain.isCanonical,
              roundCount > 0,
              roundCount <= Int(domain.logSize) else {
            throw AppleZKProverError.invalidInputLayout
        }

        var layers: [[QM31Element]] = [
            try CircleDomainOracle.firstFoldInverseYTwiddles(for: domain),
        ]
        guard roundCount > 1 else {
            return layers
        }

        var currentXCoordinates = try firstLineXCoordinates(for: domain)
        for _ in 1..<roundCount {
            guard currentXCoordinates.count > 1,
                  currentXCoordinates.count.isMultiple(of: 2) else {
                throw AppleZKProverError.invalidInputLayout
            }
            var inverseXTwiddles: [QM31Element] = []
            var nextXCoordinates: [UInt32] = []
            inverseXTwiddles.reserveCapacity(currentXCoordinates.count / 2)
            nextXCoordinates.reserveCapacity(currentXCoordinates.count / 2)
            for pairIndex in 0..<(currentXCoordinates.count / 2) {
                let leftX = currentXCoordinates[pairIndex * 2]
                let rightX = currentXCoordinates[pairIndex * 2 + 1]
                guard M31Field.add(leftX, rightX) == 0,
                      leftX != 0 else {
                    throw AppleZKProverError.invalidInputLayout
                }
                inverseXTwiddles.append(QM31Element(a: try M31Field.inverse(leftX), b: 0, c: 0, d: 0))
                nextXCoordinates.append(CircleDomainOracle.doubleX(leftX))
            }
            layers.append(inverseXTwiddles)
            currentXCoordinates = nextXCoordinates
        }
        return layers
    }

    public static func fold(
        evaluations: [QM31Element],
        domain: CircleDomainDescriptor,
        challenges: [QM31Element]
    ) throws -> [QM31Element] {
        guard !challenges.isEmpty,
              challenges.count <= Int(domain.logSize),
              evaluations.count == domain.size else {
            throw AppleZKProverError.invalidInputLayout
        }
        try QM31Field.validateCanonical(evaluations)
        try QM31Field.validateCanonical(challenges)

        let inverseLayers = try inverseDomainLayers(for: domain, roundCount: challenges.count)
        var current = evaluations
        for roundIndex in 0..<challenges.count {
            if roundIndex == 0 {
                current = try CircleFRIFoldOracle.foldCircleIntoLine(
                    evaluations: current,
                    domain: domain,
                    challenge: challenges[roundIndex]
                )
            } else {
                current = try QM31FRIFoldOracle.fold(
                    evaluations: current,
                    inverseDomainPoints: inverseLayers[roundIndex],
                    challenge: challenges[roundIndex]
                )
            }
        }
        return current
    }

    public static func firstLineXCoordinates(
        for domain: CircleDomainDescriptor
    ) throws -> [UInt32] {
        guard domain.storageOrder == .circleDomainBitReversed,
              domain.isCanonical else {
            throw AppleZKProverError.invalidInputLayout
        }
        var coordinates: [UInt32] = []
        coordinates.reserveCapacity(domain.halfSize)
        for pairIndex in 0..<domain.halfSize {
            let naturalDomainIndex = CircleDomainOracle.bitReverseIndex(pairIndex << 1, logSize: domain.logSize)
            let point = try CircleDomainOracle.point(in: domain, naturalDomainIndex: naturalDomainIndex)
            try CircleDomainOracle.validatePoint(point)
            coordinates.append(point.x)
        }
        return coordinates
    }
}
