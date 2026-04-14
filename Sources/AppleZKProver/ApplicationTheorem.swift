import Foundation

public enum AIRProofOpenBoundaryV1: String, Codable, CaseIterable, Sendable {
    case quotientPolynomialLowDegreeProof = "quotient-polynomial-low-degree-proof"
    case pcsBackedConstraintOpenings = "pcs-backed-constraint-openings"
    case privateWitness = "private-witness"
    case zeroKnowledge = "zero-knowledge"
}

public enum AIRProofClaimScopeV1: String, Codable, CaseIterable, Sendable {
    case publicRevealedTraceConstraintEvaluation = "public-revealed-trace-constraint-evaluation"
    case succinctPrivateAIR = "succinct-private-air"
}

public struct AIRProofManifestV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1
    public static let artifactName = "AIRProofV1"
    public static let current = AIRProofManifestV1()

    public let version: UInt32
    public let artifact: String
    public let verifiesAIRSemantics: Bool
    public let includesPublicWitnessTrace: Bool
    public let usesTranscriptComposedConstraintEvaluations: Bool
    public let verifiesPublicTraceQuotientDivisibility: Bool
    public let provesQuotientLowDegree: Bool
    public let usesPCSBackedOpenings: Bool
    public let isSuccinct: Bool
    public let isZeroKnowledge: Bool
    public let acceptedClaimScope: AIRProofClaimScopeV1
    public let rejectedClaimScopes: [AIRProofClaimScopeV1]
    public let openBoundaries: [AIRProofOpenBoundaryV1]

    public init() {
        self.version = Self.currentVersion
        self.artifact = Self.artifactName
        self.verifiesAIRSemantics = true
        self.includesPublicWitnessTrace = true
        self.usesTranscriptComposedConstraintEvaluations = true
        self.verifiesPublicTraceQuotientDivisibility = true
        self.provesQuotientLowDegree = false
        self.usesPCSBackedOpenings = false
        self.isSuccinct = false
        self.isZeroKnowledge = false
        self.acceptedClaimScope = .publicRevealedTraceConstraintEvaluation
        self.rejectedClaimScopes = [.succinctPrivateAIR]
        self.openBoundaries = [
            .quotientPolynomialLowDegreeProof,
            .pcsBackedConstraintOpenings,
            .privateWitness,
            .zeroKnowledge,
        ]
    }
}

public enum ApplicationTheoremOpenBoundaryV1: String, Codable, CaseIterable, Sendable {
    case succinctAIRGKRProof = "succinct-air-gkr-proof"
    case zeroKnowledge = "zero-knowledge"
}

public struct ApplicationTheoremManifestV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1
    public static let artifactName = "ApplicationPublicSidecarTheoremV1"
    public static let current = ApplicationTheoremManifestV1()

    public let version: UInt32
    public let artifact: String
    public let verifiesApplicationProofComponents: Bool
    public let bindsPublicWitnessDigest: Bool
    public let verifiesWitnessToAIRTraceProduction: Bool
    public let verifiesAIRSemantics: Bool
    public let verifiesAIRToSumcheckReduction: Bool
    public let verifiesGKRClaimSemantics: Bool
    public let selfContainedProofArtifact: Bool
    public let isZeroKnowledge: Bool
    public let openBoundaries: [ApplicationTheoremOpenBoundaryV1]

    public init() {
        self.version = Self.currentVersion
        self.artifact = Self.artifactName
        self.verifiesApplicationProofComponents = true
        self.bindsPublicWitnessDigest = true
        self.verifiesWitnessToAIRTraceProduction = true
        self.verifiesAIRSemantics = true
        self.verifiesAIRToSumcheckReduction = true
        self.verifiesGKRClaimSemantics = true
        self.selfContainedProofArtifact = false
        self.isZeroKnowledge = false
        self.openBoundaries = [
            .succinctAIRGKRProof,
            .zeroKnowledge,
        ]
    }
}

public enum ApplicationPublicTheoremArtifactOpenBoundaryV1: String, Codable, CaseIterable, Sendable {
    case succinctAIRGKRProof = "succinct-air-gkr-proof"
    case zeroKnowledge = "zero-knowledge"
}

public struct ApplicationPublicTheoremArtifactManifestV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1
    public static let artifactName = "ApplicationPublicTheoremArtifactV1"
    public static let current = ApplicationPublicTheoremArtifactManifestV1()

    public let version: UInt32
    public let artifact: String
    public let includesStatement: Bool
    public let includesApplicationProof: Bool
    public let includesPublicWitnessTrace: Bool
    public let includesAIRDefinition: Bool
    public let includesGKRClaim: Bool
    public let verifiesEndToEndPublicTheorem: Bool
    public let isSuccinctAIRGKRProof: Bool
    public let isZeroKnowledge: Bool
    public let openBoundaries: [ApplicationPublicTheoremArtifactOpenBoundaryV1]

    public init() {
        self.version = Self.currentVersion
        self.artifact = Self.artifactName
        self.includesStatement = true
        self.includesApplicationProof = true
        self.includesPublicWitnessTrace = true
        self.includesAIRDefinition = true
        self.includesGKRClaim = true
        self.verifiesEndToEndPublicTheorem = true
        self.isSuccinctAIRGKRProof = false
        self.isZeroKnowledge = false
        self.openBoundaries = [
            .succinctAIRGKRProof,
            .zeroKnowledge,
        ]
    }
}

public struct ApplicationPublicTheoremTracePCSArtifactManifestV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1
    public static let artifactName = "ApplicationPublicTheoremTracePCSArtifactV1"
    public static let current = ApplicationPublicTheoremTracePCSArtifactManifestV1()

    public let version: UInt32
    public let artifact: String
    public let includesPublicTheoremArtifact: Bool
    public let includesAIRTracePCSProofBundle: Bool
    public let verifiesEndToEndPublicTheorem: Bool
    public let verifiesTracePCSBundleAgainstAIRTrace: Bool
    public let requiresApplicationPCSProofInTraceBundle: Bool
    public let isSuccinctAIRGKRProof: Bool
    public let isZeroKnowledge: Bool
    public let openBoundaries: [ApplicationPublicTheoremArtifactOpenBoundaryV1]

    public init() {
        self.version = Self.currentVersion
        self.artifact = Self.artifactName
        self.includesPublicTheoremArtifact = true
        self.includesAIRTracePCSProofBundle = true
        self.verifiesEndToEndPublicTheorem = true
        self.verifiesTracePCSBundleAgainstAIRTrace = true
        self.requiresApplicationPCSProofInTraceBundle = true
        self.isSuccinctAIRGKRProof = false
        self.isZeroKnowledge = false
        self.openBoundaries = [
            .succinctAIRGKRProof,
            .zeroKnowledge,
        ]
    }
}

public struct ApplicationPublicTheoremIntegratedArtifactManifestV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1
    public static let artifactName = "ApplicationPublicTheoremIntegratedArtifactV1"
    public static let current = ApplicationPublicTheoremIntegratedArtifactManifestV1()

    public let version: UInt32
    public let artifact: String
    public let includesPublicTheoremArtifact: Bool
    public let includesAIRConstraintMultilinearSumcheck: Bool
    public let includesSharedDomainQuotientIdentityPCS: Bool
    public let verifiesPublicAIRGKRTheorem: Bool
    public let verifiesAIRConstraintSumcheck: Bool
    public let verifiesSharedDomainQuotientIdentity: Bool
    public let verifiesGKRClaimSemantics: Bool
    public let isSuccinctAIRGKRProof: Bool
    public let isZeroKnowledge: Bool
    public let openBoundaries: [ApplicationPublicTheoremArtifactOpenBoundaryV1]

    public init() {
        self.version = Self.currentVersion
        self.artifact = Self.artifactName
        self.includesPublicTheoremArtifact = true
        self.includesAIRConstraintMultilinearSumcheck = true
        self.includesSharedDomainQuotientIdentityPCS = true
        self.verifiesPublicAIRGKRTheorem = true
        self.verifiesAIRConstraintSumcheck = true
        self.verifiesSharedDomainQuotientIdentity = true
        self.verifiesGKRClaimSemantics = true
        self.isSuccinctAIRGKRProof = false
        self.isZeroKnowledge = false
        self.openBoundaries = [
            .succinctAIRGKRProof,
            .zeroKnowledge,
        ]
    }
}

public enum AIRTraceReferenceKindV1: UInt32, Codable, Sendable {
    case current = 0
    case next = 1
}

public struct AIRTraceReferenceV1: Equatable, Codable, Sendable {
    public let kind: AIRTraceReferenceKindV1
    public let column: Int

    public init(kind: AIRTraceReferenceKindV1, column: Int) throws {
        guard column >= 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.kind = kind
        self.column = column
    }
}

public struct AIRConstraintTermV1: Equatable, Codable, Sendable {
    public let coefficient: UInt32
    public let factors: [AIRTraceReferenceV1]

    public init(coefficient: UInt32, factors: [AIRTraceReferenceV1] = []) throws {
        guard coefficient > 0,
              coefficient < M31Field.modulus else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.coefficient = coefficient
        self.factors = factors
    }
}

public struct AIRConstraintPolynomialV1: Equatable, Codable, Sendable {
    public let terms: [AIRConstraintTermV1]

    public init(terms: [AIRConstraintTermV1]) throws {
        guard !terms.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.terms = terms
    }
}

public struct AIRBoundaryConstraintV1: Equatable, Codable, Sendable {
    public let rowIndex: Int
    public let polynomial: AIRConstraintPolynomialV1

    public init(rowIndex: Int, polynomial: AIRConstraintPolynomialV1) throws {
        guard rowIndex >= 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.rowIndex = rowIndex
        self.polynomial = polynomial
    }
}

public struct AIRDefinitionV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let columnCount: Int
    public let transitionConstraints: [AIRConstraintPolynomialV1]
    public let boundaryConstraints: [AIRBoundaryConstraintV1]

    public init(
        version: UInt32 = Self.currentVersion,
        columnCount: Int,
        transitionConstraints: [AIRConstraintPolynomialV1],
        boundaryConstraints: [AIRBoundaryConstraintV1]
    ) throws {
        guard version == Self.currentVersion,
              columnCount > 0,
              !transitionConstraints.isEmpty || !boundaryConstraints.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        try Self.validateReferences(
            transitionConstraints.flatMap(\.terms),
            columnCount: columnCount,
            allowNextRow: true
        )
        try Self.validateReferences(
            boundaryConstraints.flatMap(\.polynomial.terms),
            columnCount: columnCount,
            allowNextRow: false
        )
        self.version = version
        self.columnCount = columnCount
        self.transitionConstraints = transitionConstraints
        self.boundaryConstraints = boundaryConstraints
    }

    private static func validateReferences(
        _ terms: [AIRConstraintTermV1],
        columnCount: Int,
        allowNextRow: Bool
    ) throws {
        for term in terms {
            for factor in term.factors {
                guard factor.column < columnCount,
                      allowNextRow || factor.kind == .current else {
                    throw AppleZKProverError.invalidInputLayout
                }
            }
        }
    }
}

public struct AIRExecutionTraceV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let rowCount: Int
    public let columnCount: Int
    public let rowMajorValues: [UInt32]

    public init(
        version: UInt32 = Self.currentVersion,
        rowCount: Int,
        columnCount: Int,
        rowMajorValues: [UInt32]
    ) throws {
        let expectedValueCount = try checkedBufferLength(rowCount, columnCount)
        guard version == Self.currentVersion,
              rowCount > 0,
              columnCount > 0,
              rowMajorValues.count == expectedValueCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(rowMajorValues)
        self.version = version
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.rowMajorValues = rowMajorValues
    }

    public func value(row: Int, column: Int) throws -> UInt32 {
        guard row >= 0,
              row < rowCount,
              column >= 0,
              column < columnCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        return rowMajorValues[row * columnCount + column]
    }
}

public struct ApplicationWitnessTraceV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let columns: [[UInt32]]

    public init(version: UInt32 = Self.currentVersion, columns: [[UInt32]]) throws {
        guard version == Self.currentVersion,
              let rowCount = columns.first?.count,
              !columns.isEmpty,
              rowCount > 0,
              columns.allSatisfy({ $0.count == rowCount }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        for column in columns {
            try M31Field.validateCanonical(column)
        }
        self.version = version
        self.columns = columns
    }

    public var columnCount: Int {
        columns.count
    }

    public var rowCount: Int {
        columns[0].count
    }
}

public struct ApplicationWitnessColumnV1: Equatable, Codable, Sendable {
    public let name: String
    public let values: [UInt32]

    public init(name: String, values: [UInt32]) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !values.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(values)
        self.name = name
        self.values = values
    }
}

public struct ApplicationWitnessLayoutV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let columns: [ApplicationWitnessColumnV1]

    public init(
        version: UInt32 = Self.currentVersion,
        columns: [ApplicationWitnessColumnV1]
    ) throws {
        guard version == Self.currentVersion,
              let rowCount = columns.first?.values.count,
              !columns.isEmpty,
              rowCount > 0,
              columns.allSatisfy({ $0.values.count == rowCount }) else {
            throw AppleZKProverError.invalidInputLayout
        }

        var names = Set<String>()
        for column in columns {
            guard names.insert(column.name).inserted else {
                throw AppleZKProverError.invalidInputLayout
            }
        }

        self.version = version
        self.columns = columns
    }

    public var columnCount: Int {
        columns.count
    }

    public var rowCount: Int {
        columns[0].values.count
    }

    public var columnNames: [String] {
        columns.map(\.name)
    }

    public func column(named name: String) throws -> ApplicationWitnessColumnV1 {
        guard let column = columns.first(where: { $0.name == name }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        return column
    }

    public func traceInDeclaredOrder() throws -> ApplicationWitnessTraceV1 {
        try ApplicationWitnessTraceV1(columns: columns.map(\.values))
    }

    public func trace(columnOrder: [String]) throws -> ApplicationWitnessTraceV1 {
        guard !columnOrder.isEmpty,
              Set(columnOrder).count == columnOrder.count else {
            throw AppleZKProverError.invalidInputLayout
        }

        let orderedColumns = try columnOrder.map { try column(named: $0).values }
        return try ApplicationWitnessTraceV1(columns: orderedColumns)
    }
}

public enum WitnessToAIRTraceProducerV1 {
    public static func produce(witness: ApplicationWitnessTraceV1) throws -> AIRExecutionTraceV1 {
        var values: [UInt32] = []
        values.reserveCapacity(try checkedBufferLength(witness.rowCount, witness.columnCount))
        for row in 0..<witness.rowCount {
            for column in 0..<witness.columnCount {
                values.append(witness.columns[column][row])
            }
        }
        return try AIRExecutionTraceV1(
            rowCount: witness.rowCount,
            columnCount: witness.columnCount,
            rowMajorValues: values
        )
    }

    public static func produce(
        witness: ApplicationWitnessTraceV1,
        for definition: AIRDefinitionV1
    ) throws -> AIRExecutionTraceV1 {
        let trace = try produce(witness: witness)
        guard trace.columnCount == definition.columnCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        return trace
    }
}

public struct AIRTraceCirclePCSChunkV1: Equatable, Sendable {
    public let chunkIndex: Int
    public let sourceColumnIndices: [Int]
    public let polynomial: CircleCodewordPolynomial
    public let polynomialClaim: CirclePCSFRIPolynomialClaimV1

    public init(
        chunkIndex: Int,
        sourceColumnIndices: [Int],
        polynomial: CircleCodewordPolynomial,
        polynomialClaim: CirclePCSFRIPolynomialClaimV1
    ) throws {
        guard chunkIndex >= 0,
              !sourceColumnIndices.isEmpty,
              sourceColumnIndices.count <= AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial,
              sourceColumnIndices.allSatisfy({ $0 >= 0 }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        for pair in zip(sourceColumnIndices, sourceColumnIndices.dropFirst()) {
            guard pair.0 < pair.1 else {
                throw AppleZKProverError.invalidInputLayout
            }
        }

        self.chunkIndex = chunkIndex
        self.sourceColumnIndices = sourceColumnIndices
        self.polynomial = polynomial
        self.polynomialClaim = polynomialClaim
    }
}

public struct AIRTraceCirclePCSWitnessV1: Equatable, Sendable {
    public let domain: CircleDomainDescriptor
    public let rowCount: Int
    public let columnCount: Int
    public let rowStorageIndices: [Int]
    public let claimedRowIndices: [Int]
    public let chunks: [AIRTraceCirclePCSChunkV1]

    public init(
        domain: CircleDomainDescriptor,
        rowCount: Int,
        columnCount: Int,
        rowStorageIndices: [Int],
        claimedRowIndices: [Int],
        chunks: [AIRTraceCirclePCSChunkV1]
    ) throws {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed,
              rowCount > 0,
              rowCount <= domain.halfSize,
              columnCount > 0,
              rowStorageIndices.count == rowCount,
              !claimedRowIndices.isEmpty,
              !chunks.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        for storageIndex in rowStorageIndices {
            guard storageIndex >= 0,
                  storageIndex < domain.size else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        let expectedRowStorageIndices = (0..<rowCount).map {
            CircleDomainOracle.bitReverseIndex($0, logSize: domain.logSize)
        }
        guard rowStorageIndices == expectedRowStorageIndices else {
            throw AppleZKProverError.invalidInputLayout
        }
        var previousClaimedRow: Int?
        for row in claimedRowIndices {
            guard row >= 0,
                  row < rowCount,
                  previousClaimedRow.map({ $0 < row }) ?? true else {
                throw AppleZKProverError.invalidInputLayout
            }
            previousClaimedRow = row
        }
        var expectedColumnIndex = 0
        for (index, chunk) in chunks.enumerated() {
            let nextExpectedColumnIndex = expectedColumnIndex.addingReportingOverflow(
                chunk.sourceColumnIndices.count
            )
            guard !nextExpectedColumnIndex.overflow,
                  nextExpectedColumnIndex.partialValue <= columnCount else {
                throw AppleZKProverError.invalidInputLayout
            }
            let expectedSourceIndices = Array(
                expectedColumnIndex..<nextExpectedColumnIndex.partialValue
            )
            guard chunk.chunkIndex == index,
                  chunk.sourceColumnIndices == expectedSourceIndices,
                  chunk.polynomialClaim.domain == domain else {
                throw AppleZKProverError.invalidInputLayout
            }
            expectedColumnIndex = nextExpectedColumnIndex.partialValue
        }
        guard expectedColumnIndex == columnCount else {
            throw AppleZKProverError.invalidInputLayout
        }

        self.domain = domain
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.rowStorageIndices = rowStorageIndices
        self.claimedRowIndices = claimedRowIndices
        self.chunks = chunks
    }

    public var polynomialClaims: [CirclePCSFRIPolynomialClaimV1] {
        chunks.map(\.polynomialClaim)
    }
}

public enum AIRTraceToCirclePCSWitnessV1 {
    public static let m31ColumnsPerQM31Polynomial = 4

    private static let zero = QM31Element(a: 0, b: 0, c: 0, d: 0)

    public static func make(
        trace: AIRExecutionTraceV1,
        domain: CircleDomainDescriptor,
        claimRowIndices: [Int]? = nil
    ) throws -> AIRTraceCirclePCSWitnessV1 {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed,
              trace.rowCount <= domain.halfSize else {
            throw AppleZKProverError.invalidInputLayout
        }

        let claimRows = try normalizedClaimRows(
            claimRowIndices ?? Array(0..<trace.rowCount),
            rowCount: trace.rowCount
        )
        let claimStorageIndices = claimRows.map {
            storageIndex(forFirstHalfTraceRow: $0, domain: domain)
        }
        let rowStorageIndices = (0..<trace.rowCount).map {
            storageIndex(forFirstHalfTraceRow: $0, domain: domain)
        }
        let xCoordinates = try firstHalfXCoordinates(rowCount: trace.rowCount, domain: domain)

        var chunks: [AIRTraceCirclePCSChunkV1] = []
        chunks.reserveCapacity((trace.columnCount + m31ColumnsPerQM31Polynomial - 1) / m31ColumnsPerQM31Polynomial)
        var firstColumn = 0
        while firstColumn < trace.columnCount {
            let sourceColumnIndices = Array(
                firstColumn..<min(firstColumn + m31ColumnsPerQM31Polynomial, trace.columnCount)
            )
            let packedValues = try (0..<trace.rowCount).map { row in
                try packedTraceRow(trace, row: row, firstColumn: firstColumn)
            }
            let xCoefficients = try interpolateUnivariate(
                xCoordinates: xCoordinates,
                values: packedValues
            )
            let polynomial = try CircleCodewordPolynomial(xCoefficients: xCoefficients)
            let polynomialClaim = try CirclePCSFRIPolynomialClaimV1.make(
                domain: domain,
                polynomial: polynomial,
                storageIndices: claimStorageIndices
            )
            chunks.append(try AIRTraceCirclePCSChunkV1(
                chunkIndex: chunks.count,
                sourceColumnIndices: sourceColumnIndices,
                polynomial: polynomial,
                polynomialClaim: polynomialClaim
            ))
            firstColumn += m31ColumnsPerQM31Polynomial
        }

        return try AIRTraceCirclePCSWitnessV1(
            domain: domain,
            rowCount: trace.rowCount,
            columnCount: trace.columnCount,
            rowStorageIndices: rowStorageIndices,
            claimedRowIndices: claimRows,
            chunks: chunks
        )
    }

    private static func normalizedClaimRows(_ rows: [Int], rowCount: Int) throws -> [Int] {
        guard !rows.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        var seen = Set<Int>()
        for row in rows {
            guard row >= 0,
                  row < rowCount,
                  seen.insert(row).inserted else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        return rows.sorted()
    }

    private static func storageIndex(
        forFirstHalfTraceRow row: Int,
        domain: CircleDomainDescriptor
    ) -> Int {
        CircleDomainOracle.bitReverseIndex(row, logSize: domain.logSize)
    }

    private static func firstHalfXCoordinates(
        rowCount: Int,
        domain: CircleDomainDescriptor
    ) throws -> [UInt32] {
        var xCoordinates: [UInt32] = []
        xCoordinates.reserveCapacity(rowCount)
        var seen = Set<UInt32>()
        for row in 0..<rowCount {
            let point = try CircleDomainOracle.point(in: domain, naturalDomainIndex: row)
            try CircleDomainOracle.validatePoint(point)
            guard seen.insert(point.x).inserted else {
                throw AppleZKProverError.invalidInputLayout
            }
            xCoordinates.append(point.x)
        }
        return xCoordinates
    }

    private static func packedTraceRow(
        _ trace: AIRExecutionTraceV1,
        row: Int,
        firstColumn: Int
    ) throws -> QM31Element {
        var limbs = Array(repeating: UInt32(0), count: m31ColumnsPerQM31Polynomial)
        for offset in 0..<m31ColumnsPerQM31Polynomial {
            let column = firstColumn + offset
            if column < trace.columnCount {
                limbs[offset] = try trace.value(row: row, column: column)
            }
        }
        return QM31Element(a: limbs[0], b: limbs[1], c: limbs[2], d: limbs[3])
    }

    private static func interpolateUnivariate(
        xCoordinates: [UInt32],
        values: [QM31Element]
    ) throws -> [QM31Element] {
        guard !xCoordinates.isEmpty,
              xCoordinates.count == values.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(xCoordinates)
        try QM31Field.validateCanonical(values)

        var coefficients = Array(repeating: zero, count: xCoordinates.count)
        for interpolationIndex in xCoordinates.indices {
            var basis = [UInt32(1)]
            var denominator = UInt32(1)
            for basisIndex in xCoordinates.indices where basisIndex != interpolationIndex {
                let root = xCoordinates[basisIndex]
                var nextBasis = Array(repeating: UInt32(0), count: basis.count + 1)
                for degree in basis.indices {
                    nextBasis[degree] = M31Field.add(
                        nextBasis[degree],
                        M31Field.multiply(basis[degree], M31Field.negate(root))
                    )
                    nextBasis[degree + 1] = M31Field.add(
                        nextBasis[degree + 1],
                        basis[degree]
                    )
                }
                basis = nextBasis
                denominator = M31Field.multiply(
                    denominator,
                    M31Field.subtract(xCoordinates[interpolationIndex], root)
                )
            }

            let scale = try M31Field.inverse(denominator)
            let scaledValue = QM31Field.multiplyByM31(values[interpolationIndex], scale)
            for degree in basis.indices {
                coefficients[degree] = QM31Field.add(
                    coefficients[degree],
                    QM31Field.multiplyByM31(scaledValue, basis[degree])
                )
            }
        }
        return coefficients
    }
}

public struct AIRTraceCircleFFTBasisChunkV1: Equatable, Sendable {
    public let chunkIndex: Int
    public let sourceColumnIndices: [Int]
    public let polynomial: CircleCodewordPolynomial
    public let polynomialClaim: CirclePCSFRIPolynomialClaimV1
    public let circleFFTBasisCoefficients: [QM31Element]

    public init(
        chunkIndex: Int,
        sourceColumnIndices: [Int],
        polynomial: CircleCodewordPolynomial,
        polynomialClaim: CirclePCSFRIPolynomialClaimV1,
        circleFFTBasisCoefficients: [QM31Element]
    ) throws {
        guard chunkIndex >= 0,
              !sourceColumnIndices.isEmpty,
              sourceColumnIndices.count <= AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial,
              sourceColumnIndices.allSatisfy({ $0 >= 0 }),
              polynomialClaim.polynomial == polynomial,
              circleFFTBasisCoefficients.count == polynomialClaim.domain.size else {
            throw AppleZKProverError.invalidInputLayout
        }
        for pair in zip(sourceColumnIndices, sourceColumnIndices.dropFirst()) {
            guard pair.0 < pair.1 else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        try QM31Field.validateCanonical(circleFFTBasisCoefficients)
        guard circleFFTBasisCoefficients == (try CircleCodewordOracle.circleFFTCoefficients(
            polynomial: polynomial,
            domain: polynomialClaim.domain
        )) else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.chunkIndex = chunkIndex
        self.sourceColumnIndices = sourceColumnIndices
        self.polynomial = polynomial
        self.polynomialClaim = polynomialClaim
        self.circleFFTBasisCoefficients = circleFFTBasisCoefficients
    }
}

public struct AIRTraceCircleFFTBasisWitnessV1: Equatable, Sendable {
    public let domain: CircleDomainDescriptor
    public let rowCount: Int
    public let columnCount: Int
    public let rowStorageIndices: [Int]
    public let claimedRowIndices: [Int]
    public let chunks: [AIRTraceCircleFFTBasisChunkV1]
    public let usesPublicTraceRows: Bool
    public let isResidentPrivateWitness: Bool
    public let verifiesAIRSemantics: Bool
    public let isZeroKnowledge: Bool

    public init(
        domain: CircleDomainDescriptor,
        rowCount: Int,
        columnCount: Int,
        rowStorageIndices: [Int],
        claimedRowIndices: [Int],
        chunks: [AIRTraceCircleFFTBasisChunkV1],
        usesPublicTraceRows: Bool = true,
        isResidentPrivateWitness: Bool = false,
        verifiesAIRSemantics: Bool = false,
        isZeroKnowledge: Bool = false
    ) throws {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed,
              rowCount > 0,
              rowCount <= domain.halfSize,
              columnCount > 0,
              rowStorageIndices.count == rowCount,
              !claimedRowIndices.isEmpty,
              !chunks.isEmpty,
              usesPublicTraceRows,
              !isResidentPrivateWitness,
              !verifiesAIRSemantics,
              !isZeroKnowledge else {
            throw AppleZKProverError.invalidInputLayout
        }
        let expectedRowStorageIndices = (0..<rowCount).map {
            CircleDomainOracle.bitReverseIndex($0, logSize: domain.logSize)
        }
        guard rowStorageIndices == expectedRowStorageIndices else {
            throw AppleZKProverError.invalidInputLayout
        }
        var previousClaimedRow: Int?
        for row in claimedRowIndices {
            guard row >= 0,
                  row < rowCount,
                  previousClaimedRow.map({ $0 < row }) ?? true else {
                throw AppleZKProverError.invalidInputLayout
            }
            previousClaimedRow = row
        }
        var expectedColumnIndex = 0
        for (index, chunk) in chunks.enumerated() {
            let nextExpectedColumnIndex = expectedColumnIndex.addingReportingOverflow(
                chunk.sourceColumnIndices.count
            )
            guard !nextExpectedColumnIndex.overflow,
                  nextExpectedColumnIndex.partialValue <= columnCount else {
                throw AppleZKProverError.invalidInputLayout
            }
            let expectedSourceIndices = Array(
                expectedColumnIndex..<nextExpectedColumnIndex.partialValue
            )
            guard chunk.chunkIndex == index,
                  chunk.sourceColumnIndices == expectedSourceIndices,
                  chunk.polynomialClaim.domain == domain,
                  chunk.circleFFTBasisCoefficients.count == domain.size else {
                throw AppleZKProverError.invalidInputLayout
            }
            expectedColumnIndex = nextExpectedColumnIndex.partialValue
        }
        guard expectedColumnIndex == columnCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.domain = domain
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.rowStorageIndices = rowStorageIndices
        self.claimedRowIndices = claimedRowIndices
        self.chunks = chunks
        self.usesPublicTraceRows = usesPublicTraceRows
        self.isResidentPrivateWitness = isResidentPrivateWitness
        self.verifiesAIRSemantics = verifiesAIRSemantics
        self.isZeroKnowledge = isZeroKnowledge
    }

    public var polynomialClaims: [CirclePCSFRIPolynomialClaimV1] {
        chunks.map(\.polynomialClaim)
    }

    public var circleFFTBasisCoefficientChunks: [[QM31Element]] {
        chunks.map(\.circleFFTBasisCoefficients)
    }
}

public enum AIRTraceToCircleFFTBasisWitnessV1 {
    public static func make(
        trace: AIRExecutionTraceV1,
        domain: CircleDomainDescriptor,
        claimRowIndices: [Int]? = nil
    ) throws -> AIRTraceCircleFFTBasisWitnessV1 {
        try make(
            pcsWitness: AIRTraceToCirclePCSWitnessV1.make(
                trace: trace,
                domain: domain,
                claimRowIndices: claimRowIndices
            )
        )
    }

    public static func make(
        pcsWitness: AIRTraceCirclePCSWitnessV1
    ) throws -> AIRTraceCircleFFTBasisWitnessV1 {
        let chunks = try pcsWitness.chunks.map { chunk in
            try AIRTraceCircleFFTBasisChunkV1(
                chunkIndex: chunk.chunkIndex,
                sourceColumnIndices: chunk.sourceColumnIndices,
                polynomial: chunk.polynomial,
                polynomialClaim: chunk.polynomialClaim,
                circleFFTBasisCoefficients: CircleCodewordOracle.circleFFTCoefficients(
                    polynomial: chunk.polynomial,
                    domain: pcsWitness.domain
                )
            )
        }
        return try AIRTraceCircleFFTBasisWitnessV1(
            domain: pcsWitness.domain,
            rowCount: pcsWitness.rowCount,
            columnCount: pcsWitness.columnCount,
            rowStorageIndices: pcsWitness.rowStorageIndices,
            claimedRowIndices: pcsWitness.claimedRowIndices,
            chunks: chunks
        )
    }
}

public struct AIRTraceCirclePCSProofChunkV1: Equatable, Sendable {
    public let chunkIndex: Int
    public let sourceColumnIndices: [Int]
    public let statement: CirclePCSFRIStatementV1
    public let proof: CirclePCSFRIProofV1

    public init(
        chunkIndex: Int,
        sourceColumnIndices: [Int],
        statement: CirclePCSFRIStatementV1,
        proof: CirclePCSFRIProofV1
    ) throws {
        guard chunkIndex >= 0,
              !sourceColumnIndices.isEmpty,
              statement.polynomialClaim.domain == proof.domain,
              statement.parameterSet.securityParameters == proof.securityParameters,
              try statement.publicInputs().publicInputDigest == proof.publicInputDigest else {
            throw AppleZKProverError.invalidInputLayout
        }
        for pair in zip(sourceColumnIndices, sourceColumnIndices.dropFirst()) {
            guard pair.0 < pair.1 else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        self.chunkIndex = chunkIndex
        self.sourceColumnIndices = sourceColumnIndices
        self.statement = statement
        self.proof = proof
    }
}

public struct AIRTraceCirclePCSProofBundleV1: Equatable, Sendable {
    public let witness: AIRTraceCirclePCSWitnessV1
    public let parameterSet: CirclePCSFRIParameterSetV1
    public let chunks: [AIRTraceCirclePCSProofChunkV1]

    public init(
        witness: AIRTraceCirclePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1,
        chunks: [AIRTraceCirclePCSProofChunkV1]
    ) throws {
        try parameterSet.validateDomain(witness.domain)
        guard !chunks.isEmpty,
              chunks.count == witness.chunks.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        for index in chunks.indices {
            let proofChunk = chunks[index]
            let witnessChunk = witness.chunks[index]
            guard proofChunk.chunkIndex == index,
                  proofChunk.sourceColumnIndices == witnessChunk.sourceColumnIndices,
                  proofChunk.statement.parameterSet == parameterSet,
                  proofChunk.statement.polynomialClaim == witnessChunk.polynomialClaim,
                  proofChunk.proof.domain == witness.domain else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        self.witness = witness
        self.parameterSet = parameterSet
        self.chunks = chunks
    }

    public var statements: [CirclePCSFRIStatementV1] {
        chunks.map(\.statement)
    }

    public var proofs: [CirclePCSFRIProofV1] {
        chunks.map(\.proof)
    }
}

public enum AIRTraceCirclePCSProofBundleBuilderV1 {
    public static func prove(
        trace: AIRExecutionTraceV1,
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128,
        claimRowIndices: [Int]? = nil
    ) throws -> AIRTraceCirclePCSProofBundleV1 {
        let witness = try AIRTraceToCirclePCSWitnessV1.make(
            trace: trace,
            domain: domain,
            claimRowIndices: claimRowIndices
        )
        return try prove(witness: witness, parameterSet: parameterSet)
    }

    public static func prove(
        witness: AIRTraceCirclePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128
    ) throws -> AIRTraceCirclePCSProofBundleV1 {
        try parameterSet.validateDomain(witness.domain)
        var proofChunks: [AIRTraceCirclePCSProofChunkV1] = []
        proofChunks.reserveCapacity(witness.chunks.count)
        for witnessChunk in witness.chunks {
            let statement = try CirclePCSFRIStatementV1(
                parameterSet: parameterSet,
                polynomialClaim: witnessChunk.polynomialClaim
            )
            let proof = try CirclePCSFRIContractProverV1.prove(statement: statement)
            proofChunks.append(try AIRTraceCirclePCSProofChunkV1(
                chunkIndex: witnessChunk.chunkIndex,
                sourceColumnIndices: witnessChunk.sourceColumnIndices,
                statement: statement,
                proof: proof
            ))
        }
        let bundle = try AIRTraceCirclePCSProofBundleV1(
            witness: witness,
            parameterSet: parameterSet,
            chunks: proofChunks
        )
        guard try AIRTraceCirclePCSProofBundleVerifierV1.verify(bundle) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "AIR trace Circle PCS proof bundle does not verify."
            )
        }
        return bundle
    }
}

public enum AIRTraceCirclePCSProofBundleVerifierV1 {
    public static func verify(_ bundle: AIRTraceCirclePCSProofBundleV1) throws -> Bool {
        for chunk in bundle.chunks {
            guard chunk.statement.parameterSet == bundle.parameterSet,
                  try CirclePCSFRIContractVerifierV1.verify(
                    proof: chunk.proof,
                    statement: chunk.statement
                  ) else {
                return false
            }
        }
        return true
    }

    public static func verify(
        _ bundle: AIRTraceCirclePCSProofBundleV1,
        against trace: AIRExecutionTraceV1
    ) throws -> Bool {
        let expectedWitness = try AIRTraceToCirclePCSWitnessV1.make(
            trace: trace,
            domain: bundle.witness.domain,
            claimRowIndices: bundle.witness.claimedRowIndices
        )
        guard expectedWitness == bundle.witness else {
            return false
        }
        return try verify(bundle)
    }

    public static func verify(encodedBundle: Data) throws -> Bool {
        try verify(AIRTraceCirclePCSProofBundleCodecV1.decode(encodedBundle))
    }

    public static func verify(
        encodedBundle: Data,
        against trace: AIRExecutionTraceV1
    ) throws -> Bool {
        try verify(
            AIRTraceCirclePCSProofBundleCodecV1.decode(encodedBundle),
            against: trace
        )
    }
}

public enum AIRTraceCirclePCSProofBundleCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x43, 0x50, 0x42, 0x56, 0x31])

    public static func encode(_ bundle: AIRTraceCirclePCSProofBundleV1) throws -> Data {
        var data = Data()
        data.append(magic)
        try CanonicalBinary.appendLengthPrefixed(
            try CircleDomainDescriptorCodecV1.encode(bundle.witness.domain),
            to: &data
        )
        CanonicalBinary.appendUInt64(UInt64(bundle.witness.rowCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(bundle.witness.columnCount), to: &data)
        try appendIntList(bundle.witness.rowStorageIndices, to: &data)
        try appendIntList(bundle.witness.claimedRowIndices, to: &data)
        try CanonicalBinary.appendLengthPrefixed(
            try parameterSetBytes(bundle.parameterSet),
            to: &data
        )
        CanonicalBinary.appendUInt64(UInt64(bundle.chunks.count), to: &data)
        for chunk in bundle.chunks {
            CanonicalBinary.appendUInt64(UInt64(chunk.chunkIndex), to: &data)
            try appendIntList(chunk.sourceColumnIndices, to: &data)
            try CanonicalBinary.appendLengthPrefixed(
                try ApplicationProofStatementCodecV1.encodePCSStatement(chunk.statement),
                to: &data
            )
            try CanonicalBinary.appendLengthPrefixed(
                try CirclePCSFRIProofCodecV1.encode(chunk.proof),
                to: &data
            )
        }
        return data
    }

    public static func decode(_ data: Data) throws -> AIRTraceCirclePCSProofBundleV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let domain = try CircleDomainDescriptorCodecV1.decode(try reader.readLengthPrefixed())
        let rowCount = try readCount64(from: &reader)
        let columnCount = try readCount64(from: &reader)
        let rowStorageIndices = try readIntList(from: &reader)
        let claimedRowIndices = try readIntList(from: &reader)
        let parameterSet = try readParameterSet(
            from: CanonicalByteReader(try reader.readLengthPrefixed())
        )
        let chunkCount = try readCount64(from: &reader)
        var witnessChunks: [AIRTraceCirclePCSChunkV1] = []
        witnessChunks.reserveCapacity(chunkCount)
        var proofChunks: [AIRTraceCirclePCSProofChunkV1] = []
        proofChunks.reserveCapacity(chunkCount)

        for _ in 0..<chunkCount {
            let chunkIndex = try readCount64(from: &reader)
            let sourceColumnIndices = try readIntList(from: &reader)
            let statement = try ApplicationProofStatementCodecV1.decodePCSStatement(
                try reader.readLengthPrefixed()
            )
            let proof = try CirclePCSFRIProofCodecV1.decode(
                try reader.readLengthPrefixed()
            )
            let witnessChunk = try AIRTraceCirclePCSChunkV1(
                chunkIndex: chunkIndex,
                sourceColumnIndices: sourceColumnIndices,
                polynomial: statement.polynomialClaim.polynomial,
                polynomialClaim: statement.polynomialClaim
            )
            witnessChunks.append(witnessChunk)
            proofChunks.append(try AIRTraceCirclePCSProofChunkV1(
                chunkIndex: chunkIndex,
                sourceColumnIndices: sourceColumnIndices,
                statement: statement,
                proof: proof
            ))
        }
        try reader.finish()

        let witness = try AIRTraceCirclePCSWitnessV1(
            domain: domain,
            rowCount: rowCount,
            columnCount: columnCount,
            rowStorageIndices: rowStorageIndices,
            claimedRowIndices: claimedRowIndices,
            chunks: witnessChunks
        )
        return try AIRTraceCirclePCSProofBundleV1(
            witness: witness,
            parameterSet: parameterSet,
            chunks: proofChunks
        )
    }

    private static func appendIntList(_ values: [Int], to data: inout Data) throws {
        CanonicalBinary.appendUInt64(UInt64(values.count), to: &data)
        for value in values {
            guard value >= 0 else {
                throw AppleZKProverError.invalidInputLayout
            }
            CanonicalBinary.appendUInt64(UInt64(value), to: &data)
        }
    }

    private static func readIntList(from reader: inout CanonicalByteReader) throws -> [Int] {
        let count = try readCount64(from: &reader)
        var values: [Int] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            values.append(try readCount64(from: &reader))
        }
        return values
    }

    private static func parameterSetBytes(_ parameterSet: CirclePCSFRIParameterSetV1) throws -> Data {
        var data = Data()
        try CanonicalBinary.appendLengthPrefixed(
            Data(parameterSet.profileID.rawValue.utf8),
            to: &data
        )
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.logBlowupFactor, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.queryCount, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.foldingStep, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.grindingBits, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.targetSoundnessBits, to: &data)
        return data
    }

    private static func readParameterSet(
        from byteReader: CanonicalByteReader
    ) throws -> CirclePCSFRIParameterSetV1 {
        var reader = byteReader
        guard let profileString = String(
            data: try reader.readLengthPrefixed(),
            encoding: .utf8
        ),
              let profileID = CirclePCSFRIParameterSetV1.ProfileID(rawValue: profileString) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let logBlowupFactor = try reader.readUInt32()
        let queryCount = try reader.readUInt32()
        let foldingStep = try reader.readUInt32()
        let grindingBits = try reader.readUInt32()
        let targetSoundnessBits = try reader.readUInt32()
        try reader.finish()
        let parameterSet = try CirclePCSFRIParameterSetV1(
            profileID: profileID,
            logBlowupFactor: logBlowupFactor,
            queryCount: queryCount,
            grindingBits: grindingBits,
            targetSoundnessBits: targetSoundnessBits
        )
        guard parameterSet.securityParameters.foldingStep == foldingStep else {
            throw AppleZKProverError.invalidInputLayout
        }
        return parameterSet
    }
}

public enum AIRTraceCirclePCSProofBundleDigestV1 {
    private static let domain = Data("AppleZKProver.AIRTraceCirclePCSProofBundle.V1".utf8)

    public static func digest(_ bundle: AIRTraceCirclePCSProofBundleV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        try CanonicalBinary.appendLengthPrefixed(
            try AIRTraceCirclePCSProofBundleCodecV1.encode(bundle),
            to: &data
        )
        return SHA3Oracle.sha3_256(data)
    }
}

public struct AIRTracePCSOpeningQueryPlanV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let traceRowCount: Int
    public let traceColumnCount: Int
    public let transitionQueryCount: Int
    public let airDefinitionDigest: Data
    public let initialTraceCommitmentDigest: Data
    public let sampledTransitionRows: [Int]
    public let boundaryRows: [Int]
    public let requiredTraceRows: [Int]

    public init(
        version: UInt32 = currentVersion,
        traceRowCount: Int,
        traceColumnCount: Int,
        transitionQueryCount: Int,
        airDefinitionDigest: Data,
        initialTraceCommitmentDigest: Data,
        sampledTransitionRows: [Int],
        boundaryRows: [Int],
        requiredTraceRows: [Int]
    ) throws {
        guard version == Self.currentVersion,
              traceRowCount > 0,
              traceColumnCount > 0,
              transitionQueryCount >= 0,
              airDefinitionDigest.count == 32,
              initialTraceCommitmentDigest.count == 32,
              !requiredTraceRows.isEmpty,
              Self.isStrictlyAscending(sampledTransitionRows),
              Self.isStrictlyAscending(boundaryRows),
              Self.isStrictlyAscending(requiredTraceRows),
              sampledTransitionRows.allSatisfy({ $0 >= 0 && $0 + 1 < traceRowCount }),
              boundaryRows.allSatisfy({ $0 >= 0 && $0 < traceRowCount }),
              requiredTraceRows.allSatisfy({ $0 >= 0 && $0 < traceRowCount }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let expectedRequiredRows = Self.requiredRows(
            sampledTransitionRows: sampledTransitionRows,
            boundaryRows: boundaryRows
        )
        guard requiredTraceRows == expectedRequiredRows,
              transitionQueryCount == sampledTransitionRows.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.traceRowCount = traceRowCount
        self.traceColumnCount = traceColumnCount
        self.transitionQueryCount = transitionQueryCount
        self.airDefinitionDigest = airDefinitionDigest
        self.initialTraceCommitmentDigest = initialTraceCommitmentDigest
        self.sampledTransitionRows = sampledTransitionRows
        self.boundaryRows = boundaryRows
        self.requiredTraceRows = requiredTraceRows
    }

    fileprivate static func requiredRows(
        sampledTransitionRows: [Int],
        boundaryRows: [Int]
    ) -> [Int] {
        Array(Set(
            sampledTransitionRows.flatMap { [$0, $0 + 1] } + boundaryRows
        )).sorted()
    }

    private static func isStrictlyAscending(_ values: [Int]) -> Bool {
        for pair in zip(values, values.dropFirst()) {
            guard pair.0 < pair.1 else {
                return false
            }
        }
        return true
    }
}

public enum AIRTracePCSOpeningQueryPlannerV1 {
    private static let transcriptDomain = Data("AppleZKProver.AIRTracePCSOpeningQueryPlan.V1".utf8)
    private static let commitmentDigestDomain = Data("AppleZKProver.AIRTracePCSInitialCommitments.V1".utf8)

    public static func make(
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1,
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1,
        transitionQueryCount: Int
    ) throws -> AIRTracePCSOpeningQueryPlanV1 {
        let witness = try AIRTraceToCirclePCSWitnessV1.make(
            trace: trace,
            domain: domain,
            claimRowIndices: [0]
        )
        return try make(
            definition: definition,
            witness: witness,
            parameterSet: parameterSet,
            transitionQueryCount: transitionQueryCount
        )
    }

    public static func make(
        definition: AIRDefinitionV1,
        witness: AIRTraceCirclePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1,
        transitionQueryCount: Int
    ) throws -> AIRTracePCSOpeningQueryPlanV1 {
        try parameterSet.validateDomain(witness.domain)
        let roots = try initialCommitmentRoots(
            witness: witness
        )
        return try make(
            definition: definition,
            witness: witness,
            parameterSet: parameterSet,
            initialCommitmentRoots: roots,
            transitionQueryCount: transitionQueryCount
        )
    }

    public static func make(
        definition: AIRDefinitionV1,
        bundle: AIRTraceCirclePCSProofBundleV1,
        transitionQueryCount: Int
    ) throws -> AIRTracePCSOpeningQueryPlanV1 {
        let roots = try initialCommitmentRoots(bundle: bundle)
        return try make(
            definition: definition,
            witness: bundle.witness,
            parameterSet: bundle.parameterSet,
            initialCommitmentRoots: roots,
            transitionQueryCount: transitionQueryCount
        )
    }

    public static func initialTraceCommitmentDigest(
        bundle: AIRTraceCirclePCSProofBundleV1
    ) throws -> Data {
        try initialTraceCommitmentDigest(
            witness: bundle.witness,
            parameterSet: bundle.parameterSet,
            initialCommitmentRoots: initialCommitmentRoots(bundle: bundle)
        )
    }

    private static func make(
        definition: AIRDefinitionV1,
        witness: AIRTraceCirclePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1,
        initialCommitmentRoots: [Data],
        transitionQueryCount: Int
    ) throws -> AIRTracePCSOpeningQueryPlanV1 {
        guard definition.columnCount == witness.columnCount,
              witness.rowCount > 1 || definition.transitionConstraints.isEmpty,
              definition.boundaryConstraints.allSatisfy({ $0.rowIndex < witness.rowCount }),
              initialCommitmentRoots.count == witness.chunks.count,
              transitionQueryCount >= 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let transitionRowCount = definition.transitionConstraints.isEmpty ? 0 : witness.rowCount - 1
        let sampledTransitionRows: [Int]
        if transitionRowCount == 0 {
            guard transitionQueryCount == 0 else {
                throw AppleZKProverError.invalidInputLayout
            }
            sampledTransitionRows = []
        } else {
            guard transitionQueryCount > 0,
                  transitionQueryCount <= transitionRowCount else {
                throw AppleZKProverError.invalidInputLayout
            }
            let transcript = try queryTranscript(
                definition: definition,
                witness: witness,
                parameterSet: parameterSet,
                initialCommitmentRoots: initialCommitmentRoots,
                transitionQueryCount: transitionQueryCount
            )
            sampledTransitionRows = try drawUniqueRows(
                transcript: transcript,
                count: transitionQueryCount,
                rowCount: transitionRowCount
            )
        }
        let boundaryRows = Array(Set(definition.boundaryConstraints.map(\.rowIndex))).sorted()
        return try AIRTracePCSOpeningQueryPlanV1(
            traceRowCount: witness.rowCount,
            traceColumnCount: witness.columnCount,
            transitionQueryCount: sampledTransitionRows.count,
            airDefinitionDigest: AIRDefinitionDigestV1.digest(definition),
            initialTraceCommitmentDigest: initialTraceCommitmentDigest(
                witness: witness,
                parameterSet: parameterSet,
                initialCommitmentRoots: initialCommitmentRoots
            ),
            sampledTransitionRows: sampledTransitionRows,
            boundaryRows: boundaryRows,
            requiredTraceRows: AIRTracePCSOpeningQueryPlanV1.requiredRows(
                sampledTransitionRows: sampledTransitionRows,
                boundaryRows: boundaryRows
            )
        )
    }

    private static func queryTranscript(
        definition: AIRDefinitionV1,
        witness: AIRTraceCirclePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1,
        initialCommitmentRoots: [Data],
        transitionQueryCount: Int
    ) throws -> SHA3Oracle.TranscriptState {
        var transcript = SHA3Oracle.TranscriptState()
        var header = Data()
        CanonicalBinary.appendUInt32(UInt32(transcriptDomain.count), to: &header)
        header.append(transcriptDomain)
        CanonicalBinary.appendUInt32(AIRTracePCSOpeningQueryPlanV1.currentVersion, to: &header)
        CanonicalBinary.appendUInt64(UInt64(witness.rowCount), to: &header)
        CanonicalBinary.appendUInt64(UInt64(witness.columnCount), to: &header)
        CanonicalBinary.appendUInt64(UInt64(definition.transitionConstraints.count), to: &header)
        CanonicalBinary.appendUInt64(UInt64(definition.boundaryConstraints.count), to: &header)
        CanonicalBinary.appendUInt64(UInt64(transitionQueryCount), to: &header)
        try transcript.absorb(header)
        try transcript.absorb(AIRDefinitionDigestV1.digest(definition))
        try transcript.absorb(initialTraceCommitmentDigest(
            witness: witness,
            parameterSet: parameterSet,
            initialCommitmentRoots: initialCommitmentRoots
        ))
        return transcript
    }

    private static func drawUniqueRows(
        transcript: SHA3Oracle.TranscriptState,
        count: Int,
        rowCount: Int
    ) throws -> [Int] {
        guard count > 0,
              rowCount > 0,
              count <= rowCount,
              rowCount <= Int(UInt32.max) else {
            throw AppleZKProverError.invalidInputLayout
        }
        if count == rowCount {
            return Array(0..<rowCount)
        }
        var selected = Set<Int>()
        var attempt: UInt32 = 0
        while selected.count < count {
            var attemptTranscript = transcript
            var frame = Data()
            CanonicalBinary.appendUInt32(attempt, to: &frame)
            CanonicalBinary.appendUInt64(UInt64(count - selected.count), to: &frame)
            try attemptTranscript.absorb(frame)
            let words = try attemptTranscript.squeezeUInt32(
                count: max(4, (count - selected.count) * 2),
                modulus: UInt32(rowCount)
            )
            for word in words {
                selected.insert(Int(word))
                if selected.count == count {
                    break
                }
            }
            attempt = attempt.addingReportingOverflow(1).partialValue
        }
        return selected.sorted()
    }

    private static func initialCommitmentRoots(
        witness: AIRTraceCirclePCSWitnessV1
    ) throws -> [Data] {
        try witness.chunks.map { chunk in
            let evaluations = try CircleCodewordOracle.evaluate(
                polynomial: chunk.polynomial,
                domain: witness.domain
            )
            return try MerkleOracle.rootSHA3_256(
                rawLeaves: QM31CanonicalEncoding.pack(evaluations),
                leafCount: evaluations.count,
                leafStride: QM31CanonicalEncoding.elementByteCount,
                leafLength: QM31CanonicalEncoding.elementByteCount
            )
        }
    }

    private static func initialCommitmentRoots(
        bundle: AIRTraceCirclePCSProofBundleV1
    ) throws -> [Data] {
        try bundle.chunks.map { chunk in
            guard let root = chunk.proof.commitments.first,
                  root.count == 32 else {
                throw AppleZKProverError.invalidInputLayout
            }
            return root
        }
    }

    private static func initialTraceCommitmentDigest(
        witness: AIRTraceCirclePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1,
        initialCommitmentRoots: [Data]
    ) throws -> Data {
        guard initialCommitmentRoots.count == witness.chunks.count,
              initialCommitmentRoots.allSatisfy({ $0.count == 32 }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(commitmentDigestDomain.count), to: &data)
        data.append(commitmentDigestDomain)
        CanonicalBinary.appendUInt32(AIRTracePCSOpeningQueryPlanV1.currentVersion, to: &data)
        try CanonicalBinary.appendLengthPrefixed(
            try CircleDomainDescriptorCodecV1.encode(witness.domain),
            to: &data
        )
        appendParameterSet(parameterSet, to: &data)
        CanonicalBinary.appendUInt64(UInt64(witness.rowCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(witness.columnCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(witness.chunks.count), to: &data)
        for (index, chunk) in witness.chunks.enumerated() {
            CanonicalBinary.appendUInt64(UInt64(chunk.chunkIndex), to: &data)
            CanonicalBinary.appendUInt64(UInt64(chunk.sourceColumnIndices.count), to: &data)
            for column in chunk.sourceColumnIndices {
                guard column >= 0 else {
                    throw AppleZKProverError.invalidInputLayout
                }
                CanonicalBinary.appendUInt64(UInt64(column), to: &data)
            }
            data.append(initialCommitmentRoots[index])
        }
        return SHA3Oracle.sha3_256(data)
    }

    private static func appendParameterSet(
        _ parameterSet: CirclePCSFRIParameterSetV1,
        to data: inout Data
    ) {
        CanonicalBinary.appendUInt32(UInt32(parameterSet.profileID.rawValue.utf8.count), to: &data)
        data.append(Data(parameterSet.profileID.rawValue.utf8))
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.logBlowupFactor, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.queryCount, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.foldingStep, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.grindingBits, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.targetSoundnessBits, to: &data)
    }
}

public struct AIRTracePCSQueriedOpeningBundleV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let queryPlan: AIRTracePCSOpeningQueryPlanV1
    public let tracePCSProofBundle: AIRTraceCirclePCSProofBundleV1

    public init(
        version: UInt32 = currentVersion,
        queryPlan: AIRTracePCSOpeningQueryPlanV1,
        tracePCSProofBundle: AIRTraceCirclePCSProofBundleV1
    ) throws {
        guard version == Self.currentVersion else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.queryPlan = queryPlan
        self.tracePCSProofBundle = tracePCSProofBundle
    }
}

public enum AIRTracePCSQueriedOpeningBundleBuilderV1 {
    public static func prove(
        trace: AIRExecutionTraceV1,
        definition: AIRDefinitionV1,
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128,
        transitionQueryCount: Int
    ) throws -> AIRTracePCSQueriedOpeningBundleV1 {
        let queryPlan = try AIRTracePCSOpeningQueryPlannerV1.make(
            definition: definition,
            trace: trace,
            domain: domain,
            parameterSet: parameterSet,
            transitionQueryCount: transitionQueryCount
        )
        let tracePCSProofBundle = try AIRTraceCirclePCSProofBundleBuilderV1.prove(
            trace: trace,
            domain: domain,
            parameterSet: parameterSet,
            claimRowIndices: queryPlan.requiredTraceRows
        )
        return try assemble(
            queryPlan: queryPlan,
            tracePCSProofBundle: tracePCSProofBundle,
            definition: definition
        )
    }

    public static func assemble(
        queryPlan: AIRTracePCSOpeningQueryPlanV1,
        tracePCSProofBundle: AIRTraceCirclePCSProofBundleV1,
        definition: AIRDefinitionV1
    ) throws -> AIRTracePCSQueriedOpeningBundleV1 {
        let queriedBundle = try AIRTracePCSQueriedOpeningBundleV1(
            queryPlan: queryPlan,
            tracePCSProofBundle: tracePCSProofBundle
        )
        guard try AIRTracePCSQueriedOpeningBundleVerifierV1.verify(
            queriedBundle,
            definition: definition
        ) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "AIR trace PCS queried opening bundle does not verify."
            )
        }
        return queriedBundle
    }
}

public struct AIRTracePCSQueriedOpeningVerificationReportV1: Equatable, Sendable {
    public let openingConstraintReport: AIRTracePCSOpeningConstraintReportV1
    public let queryPlanMatchesCommitments: Bool
    public let bundleClaimsExactlyQueryRows: Bool
    public let isZeroKnowledge: Bool

    public var verified: Bool {
        openingConstraintReport.openedConstraintsVerified &&
            queryPlanMatchesCommitments &&
            bundleClaimsExactlyQueryRows
    }
}

public enum AIRTracePCSQueriedOpeningBundleVerifierV1 {
    public static func verificationReport(
        _ queriedBundle: AIRTracePCSQueriedOpeningBundleV1,
        definition: AIRDefinitionV1
    ) throws -> AIRTracePCSQueriedOpeningVerificationReportV1 {
        let expectedPlan = try AIRTracePCSOpeningQueryPlannerV1.make(
            definition: definition,
            bundle: queriedBundle.tracePCSProofBundle,
            transitionQueryCount: queriedBundle.queryPlan.transitionQueryCount
        )
        let openingReport = try AIRTracePCSOpeningConstraintVerifierV1.verificationReport(
            bundle: queriedBundle.tracePCSProofBundle,
            definition: definition
        )
        return AIRTracePCSQueriedOpeningVerificationReportV1(
            openingConstraintReport: openingReport,
            queryPlanMatchesCommitments: expectedPlan == queriedBundle.queryPlan,
            bundleClaimsExactlyQueryRows: queriedBundle.tracePCSProofBundle.witness.claimedRowIndices == queriedBundle.queryPlan.requiredTraceRows,
            isZeroKnowledge: false
        )
    }

    public static func verify(
        _ queriedBundle: AIRTracePCSQueriedOpeningBundleV1,
        definition: AIRDefinitionV1
    ) throws -> Bool {
        try verificationReport(
            queriedBundle,
            definition: definition
        ).verified
    }
}

public struct AIRTraceQuotientPCSQueryAlignmentReportV1: Equatable, Sendable {
    public let traceQueriedOpeningReport: AIRTracePCSQueriedOpeningVerificationReportV1
    public let quotientPCSBundleProofsVerify: Bool
    public let quotientPCSBundleMatchesQuotientProof: Bool
    public let domainsMatch: Bool
    public let parameterSetsMatch: Bool
    public let requiredQuotientStorageIndices: [Int]
    public let openedQuotientStorageIndices: [Int]
    public let quotientOpeningsMatchTraceQueryRows: Bool
    public let coordinateDomainsAlignedForAIRQuotientIdentity: Bool
    public let quotientIdentityChecked: Bool
    public let isZeroKnowledge: Bool

    public var verifiedPublicOpeningAlignment: Bool {
        traceQueriedOpeningReport.verified &&
            quotientPCSBundleProofsVerify &&
            quotientPCSBundleMatchesQuotientProof &&
            domainsMatch &&
            parameterSetsMatch &&
            quotientOpeningsMatchTraceQueryRows
    }

    public var provesAIRQuotientIdentity: Bool {
        false
    }
}

public enum AIRTraceQuotientPCSQueryAlignmentVerifierV1 {
    public static func requiredQuotientStorageIndices(
        traceQueryPlan: AIRTracePCSOpeningQueryPlanV1,
        traceWitness: AIRTraceCirclePCSWitnessV1
    ) throws -> [Int] {
        guard traceQueryPlan.traceRowCount == traceWitness.rowCount,
              traceQueryPlan.traceColumnCount == traceWitness.columnCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try traceQueryPlan.requiredTraceRows.map { row -> Int in
            guard row >= 0,
                  row < traceWitness.rowStorageIndices.count else {
                throw AppleZKProverError.invalidInputLayout
            }
            return traceWitness.rowStorageIndices[row]
        }.sorted()
    }

    public static func requiredQuotientStorageIndices(
        traceQueriedOpeningBundle: AIRTracePCSQueriedOpeningBundleV1
    ) throws -> [Int] {
        try requiredQuotientStorageIndices(
            traceQueryPlan: traceQueriedOpeningBundle.queryPlan,
            traceWitness: traceQueriedOpeningBundle.tracePCSProofBundle.witness
        )
    }

    public static func verificationReport(
        traceQueriedOpeningBundle: AIRTracePCSQueriedOpeningBundleV1,
        quotientPCSProofBundle: AIRQuotientCirclePCSProofBundleV1,
        quotientProof: AIRPublicQuotientProofV1,
        definition: AIRDefinitionV1
    ) throws -> AIRTraceQuotientPCSQueryAlignmentReportV1 {
        let traceReport = try AIRTracePCSQueriedOpeningBundleVerifierV1.verificationReport(
            traceQueriedOpeningBundle,
            definition: definition
        )
        let quotientPCSBundleProofsVerify = try AIRQuotientCirclePCSProofBundleVerifierV1.verify(
            quotientPCSProofBundle
        )
        let quotientPCSBundleMatchesQuotientProof = try AIRQuotientCirclePCSProofBundleVerifierV1.verify(
            quotientPCSProofBundle,
            against: quotientProof
        )
        let requiredStorageIndices = try requiredQuotientStorageIndices(
            traceQueriedOpeningBundle: traceQueriedOpeningBundle
        )
        let domainsMatch = traceQueriedOpeningBundle.tracePCSProofBundle.witness.domain ==
            quotientPCSProofBundle.witness.domain
        let parameterSetsMatch = traceQueriedOpeningBundle.tracePCSProofBundle.parameterSet ==
            quotientPCSProofBundle.parameterSet
        return AIRTraceQuotientPCSQueryAlignmentReportV1(
            traceQueriedOpeningReport: traceReport,
            quotientPCSBundleProofsVerify: quotientPCSBundleProofsVerify,
            quotientPCSBundleMatchesQuotientProof: quotientPCSBundleMatchesQuotientProof,
            domainsMatch: domainsMatch,
            parameterSetsMatch: parameterSetsMatch,
            requiredQuotientStorageIndices: requiredStorageIndices,
            openedQuotientStorageIndices: quotientPCSProofBundle.witness.claimedStorageIndices,
            quotientOpeningsMatchTraceQueryRows: quotientPCSProofBundle.witness.claimedStorageIndices == requiredStorageIndices,
            coordinateDomainsAlignedForAIRQuotientIdentity: false,
            quotientIdentityChecked: false,
            isZeroKnowledge: false
        )
    }

    public static func verifyPublicOpeningAlignment(
        traceQueriedOpeningBundle: AIRTracePCSQueriedOpeningBundleV1,
        quotientPCSProofBundle: AIRQuotientCirclePCSProofBundleV1,
        quotientProof: AIRPublicQuotientProofV1,
        definition: AIRDefinitionV1
    ) throws -> Bool {
        try verificationReport(
            traceQueriedOpeningBundle: traceQueriedOpeningBundle,
            quotientPCSProofBundle: quotientPCSProofBundle,
            quotientProof: quotientProof,
            definition: definition
        ).verifiedPublicOpeningAlignment
    }
}

public struct AIRTracePCSOpeningConstraintReportV1: Equatable, Sendable {
    public let tracePCSBundleProofsVerify: Bool
    public let traceShapeMatchesAIR: Bool
    public let openedTransitionRows: [Int]
    public let openedBoundaryRows: [Int]
    public let transitionOpeningCoverageComplete: Bool
    public let boundaryOpeningCoverageComplete: Bool
    public let transitionOpeningsSatisfyAIR: Bool
    public let boundaryOpeningsSatisfyAIR: Bool
    public let isZeroKnowledge: Bool

    public var openedConstraintsVerified: Bool {
        tracePCSBundleProofsVerify &&
            traceShapeMatchesAIR &&
            transitionOpeningsSatisfyAIR &&
            boundaryOpeningsSatisfyAIR
    }

    public var allAIRConstraintsCoveredAndVerified: Bool {
        openedConstraintsVerified &&
            transitionOpeningCoverageComplete &&
            boundaryOpeningCoverageComplete
    }
}

public enum AIRTracePCSOpeningConstraintVerifierV1 {
    public static func verificationReport(
        bundle: AIRTraceCirclePCSProofBundleV1,
        definition: AIRDefinitionV1
    ) throws -> AIRTracePCSOpeningConstraintReportV1 {
        let bundleProofsVerify = try AIRTraceCirclePCSProofBundleVerifierV1.verify(bundle)
        let traceShapeMatchesAIR = shapeMatchesAIR(
            witness: bundle.witness,
            definition: definition
        )
        let openedRows = try openedTraceRows(from: bundle)
        let openedRowSet = Set(openedRows.keys)
        let openedTransitionRows = transitionRowsCoveredByOpenings(
            openedRowSet: openedRowSet,
            rowCount: bundle.witness.rowCount
        )
        let openedBoundaryRows = boundaryRowsCoveredByOpenings(
            definition: definition,
            openedRowSet: openedRowSet
        )
        let transitionCoverageComplete = definition.transitionConstraints.isEmpty ||
            openedTransitionRows == Array(0..<max(0, bundle.witness.rowCount - 1))
        let boundaryCoverageComplete = definition.boundaryConstraints.allSatisfy {
            $0.rowIndex < bundle.witness.rowCount && openedRowSet.contains($0.rowIndex)
        }
        let transitionOpeningsSatisfyAIR = traceShapeMatchesAIR
            ? try transitionOpeningsSatisfyAIR(
                definition: definition,
                openedRows: openedRows,
                openedTransitionRows: openedTransitionRows
            )
            : false
        let boundaryOpeningsSatisfyAIR = traceShapeMatchesAIR
            ? try boundaryOpeningsSatisfyAIR(
                definition: definition,
                openedRows: openedRows
            )
            : false
        return AIRTracePCSOpeningConstraintReportV1(
            tracePCSBundleProofsVerify: bundleProofsVerify,
            traceShapeMatchesAIR: traceShapeMatchesAIR,
            openedTransitionRows: openedTransitionRows,
            openedBoundaryRows: openedBoundaryRows,
            transitionOpeningCoverageComplete: transitionCoverageComplete,
            boundaryOpeningCoverageComplete: boundaryCoverageComplete,
            transitionOpeningsSatisfyAIR: transitionOpeningsSatisfyAIR,
            boundaryOpeningsSatisfyAIR: boundaryOpeningsSatisfyAIR,
            isZeroKnowledge: false
        )
    }

    public static func verifyOpenedConstraints(
        bundle: AIRTraceCirclePCSProofBundleV1,
        definition: AIRDefinitionV1
    ) throws -> Bool {
        try verificationReport(
            bundle: bundle,
            definition: definition
        ).openedConstraintsVerified
    }

    public static func verifyAllAIRConstraintsFromOpenings(
        bundle: AIRTraceCirclePCSProofBundleV1,
        definition: AIRDefinitionV1
    ) throws -> Bool {
        try verificationReport(
            bundle: bundle,
            definition: definition
        ).allAIRConstraintsCoveredAndVerified
    }

    public static func verificationReport(
        encodedBundle: Data,
        definition: AIRDefinitionV1
    ) throws -> AIRTracePCSOpeningConstraintReportV1 {
        try verificationReport(
            bundle: AIRTraceCirclePCSProofBundleCodecV1.decode(encodedBundle),
            definition: definition
        )
    }

    private static func shapeMatchesAIR(
        witness: AIRTraceCirclePCSWitnessV1,
        definition: AIRDefinitionV1
    ) -> Bool {
        definition.columnCount == witness.columnCount &&
            (witness.rowCount > 1 || definition.transitionConstraints.isEmpty) &&
            definition.boundaryConstraints.allSatisfy { $0.rowIndex < witness.rowCount }
    }

    private static func openedTraceRows(
        from bundle: AIRTraceCirclePCSProofBundleV1
    ) throws -> [Int: [UInt32]] {
        let witness = bundle.witness
        let expectedClaimStorageIndices = try witness.claimedRowIndices.map { row -> Int in
            guard row >= 0,
                  row < witness.rowStorageIndices.count else {
                throw AppleZKProverError.invalidInputLayout
            }
            return witness.rowStorageIndices[row]
        }.sorted()
        let storageIndexToClaimedRow = Dictionary(
            uniqueKeysWithValues: witness.claimedRowIndices.map {
                (witness.rowStorageIndices[$0], $0)
            }
        )
        var rowValues = Dictionary(
            uniqueKeysWithValues: witness.claimedRowIndices.map {
                ($0, Array<UInt32?>(repeating: nil, count: witness.columnCount))
            }
        )

        for chunk in bundle.chunks {
            let claimStorageIndices = try chunk.statement.polynomialClaim.evaluationClaims.map { claim -> Int in
                guard claim.storageIndex <= UInt64(Int.max) else {
                    throw AppleZKProverError.invalidInputLayout
                }
                return Int(claim.storageIndex)
            }
            guard claimStorageIndices == expectedClaimStorageIndices else {
                throw AppleZKProverError.invalidInputLayout
            }
            for claim in chunk.statement.polynomialClaim.evaluationClaims {
                guard claim.storageIndex <= UInt64(Int.max),
                      let row = storageIndexToClaimedRow[Int(claim.storageIndex)] else {
                    throw AppleZKProverError.invalidInputLayout
                }
                let limbs = limbs(from: claim.value)
                for offset in chunk.sourceColumnIndices.count..<AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial {
                    guard limbs[offset] == 0 else {
                        throw AppleZKProverError.invalidInputLayout
                    }
                }
                var values = rowValues[row] ?? Array<UInt32?>(
                    repeating: nil,
                    count: witness.columnCount
                )
                for (offset, column) in chunk.sourceColumnIndices.enumerated() {
                    guard column >= 0,
                          column < values.count,
                          values[column] == nil else {
                        throw AppleZKProverError.invalidInputLayout
                    }
                    values[column] = limbs[offset]
                }
                rowValues[row] = values
            }
        }

        var openedRows: [Int: [UInt32]] = [:]
        for row in witness.claimedRowIndices {
            guard let optionalValues = rowValues[row],
                  optionalValues.allSatisfy({ $0 != nil }) else {
                throw AppleZKProverError.invalidInputLayout
            }
            openedRows[row] = optionalValues.map { $0! }
        }
        return openedRows
    }

    private static func limbs(from value: QM31Element) -> [UInt32] {
        [
            value.constant.real,
            value.constant.imaginary,
            value.uCoefficient.real,
            value.uCoefficient.imaginary,
        ]
    }

    private static func transitionRowsCoveredByOpenings(
        openedRowSet: Set<Int>,
        rowCount: Int
    ) -> [Int] {
        guard rowCount > 1 else {
            return []
        }
        return (0..<(rowCount - 1)).filter {
            openedRowSet.contains($0) && openedRowSet.contains($0 + 1)
        }
    }

    private static func boundaryRowsCoveredByOpenings(
        definition: AIRDefinitionV1,
        openedRowSet: Set<Int>
    ) -> [Int] {
        Array(Set(definition.boundaryConstraints.compactMap {
            openedRowSet.contains($0.rowIndex) ? $0.rowIndex : nil
        })).sorted()
    }

    private static func transitionOpeningsSatisfyAIR(
        definition: AIRDefinitionV1,
        openedRows: [Int: [UInt32]],
        openedTransitionRows: [Int]
    ) throws -> Bool {
        for row in openedTransitionRows {
            guard let currentRow = openedRows[row],
                  let nextRow = openedRows[row + 1] else {
                return false
            }
            for constraint in definition.transitionConstraints {
                guard try evaluate(
                    constraint,
                    currentRow: currentRow,
                    nextRow: nextRow
                ) == 0 else {
                    return false
                }
            }
        }
        return true
    }

    private static func boundaryOpeningsSatisfyAIR(
        definition: AIRDefinitionV1,
        openedRows: [Int: [UInt32]]
    ) throws -> Bool {
        for constraint in definition.boundaryConstraints {
            guard let row = openedRows[constraint.rowIndex] else {
                continue
            }
            guard try evaluate(
                constraint.polynomial,
                currentRow: row,
                nextRow: nil
            ) == 0 else {
                return false
            }
        }
        return true
    }

    private static func evaluate(
        _ polynomial: AIRConstraintPolynomialV1,
        currentRow: [UInt32],
        nextRow: [UInt32]?
    ) throws -> UInt32 {
        var accumulator: UInt32 = 0
        for term in polynomial.terms {
            var product = term.coefficient
            for factor in term.factors {
                let rowValues: [UInt32]
                switch factor.kind {
                case .current:
                    rowValues = currentRow
                case .next:
                    guard let nextRow else {
                        throw AppleZKProverError.invalidInputLayout
                    }
                    rowValues = nextRow
                }
                guard factor.column >= 0,
                      factor.column < rowValues.count else {
                    throw AppleZKProverError.invalidInputLayout
                }
                product = M31Field.multiply(product, rowValues[factor.column])
            }
            accumulator = M31Field.add(accumulator, product)
        }
        return accumulator
    }
}

public enum AIRSemanticVerifierV1 {
    public static func verify(definition: AIRDefinitionV1, trace: AIRExecutionTraceV1) throws -> Bool {
        guard definition.columnCount == trace.columnCount else {
            return false
        }
        return try constraintEvaluations(definition: definition, trace: trace).allSatisfy { $0 == 0 }
    }

    public static func constraintEvaluations(
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> [UInt32] {
        guard definition.columnCount == trace.columnCount,
              trace.rowCount > 1 || definition.transitionConstraints.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }

        var evaluations: [UInt32] = []
        evaluations.reserveCapacity(
            max(0, trace.rowCount - 1) * definition.transitionConstraints.count +
                definition.boundaryConstraints.count
        )

        for row in 0..<max(0, trace.rowCount - 1) {
            for constraint in definition.transitionConstraints {
                evaluations.append(try evaluate(constraint, trace: trace, row: row))
            }
        }

        for constraint in definition.boundaryConstraints {
            guard constraint.rowIndex < trace.rowCount else {
                throw AppleZKProverError.invalidInputLayout
            }
            evaluations.append(try evaluate(constraint.polynomial, trace: trace, row: constraint.rowIndex))
        }

        return evaluations
    }

    private static func evaluate(
        _ polynomial: AIRConstraintPolynomialV1,
        trace: AIRExecutionTraceV1,
        row: Int
    ) throws -> UInt32 {
        var accumulator: UInt32 = 0
        for term in polynomial.terms {
            var product = term.coefficient
            for factor in term.factors {
                let factorRow: Int
                switch factor.kind {
                case .current:
                    factorRow = row
                case .next:
                    factorRow = row + 1
                }
                product = M31Field.multiply(
                    product,
                    try trace.value(row: factorRow, column: factor.column)
                )
            }
            accumulator = M31Field.add(accumulator, product)
        }
        return accumulator
    }
}

public enum AIRDefinitionDigestV1 {
    private static let domain = Data("AppleZKProver.AIRDefinition.V1".utf8)

    public static func digest(_ definition: AIRDefinitionV1) throws -> Data {
        var data = headerFrame()
        CanonicalBinary.appendUInt32(definition.version, to: &data)
        CanonicalBinary.appendUInt32(try checkedUInt32(definition.columnCount), to: &data)
        CanonicalBinary.appendUInt32(try checkedUInt32(definition.transitionConstraints.count), to: &data)
        for constraint in definition.transitionConstraints {
            try appendPolynomial(constraint, to: &data)
        }
        CanonicalBinary.appendUInt32(try checkedUInt32(definition.boundaryConstraints.count), to: &data)
        for constraint in definition.boundaryConstraints {
            CanonicalBinary.appendUInt64(UInt64(constraint.rowIndex), to: &data)
            try appendPolynomial(constraint.polynomial, to: &data)
        }
        return SHA3Oracle.sha3_256(data)
    }

    private static func appendPolynomial(
        _ polynomial: AIRConstraintPolynomialV1,
        to data: inout Data
    ) throws {
        CanonicalBinary.appendUInt32(try checkedUInt32(polynomial.terms.count), to: &data)
        for term in polynomial.terms {
            CanonicalBinary.appendUInt32(term.coefficient, to: &data)
            CanonicalBinary.appendUInt32(try checkedUInt32(term.factors.count), to: &data)
            for factor in term.factors {
                CanonicalBinary.appendUInt32(factor.kind.rawValue, to: &data)
                CanonicalBinary.appendUInt32(try checkedUInt32(factor.column), to: &data)
            }
        }
    }

    private static func headerFrame() -> Data {
        var frame = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &frame)
        frame.append(domain)
        CanonicalBinary.appendUInt32(M31Field.modulus, to: &frame)
        return frame
    }
}

public enum ApplicationWitnessDigestV1 {
    private static let domain = Data("AppleZKProver.ApplicationWitnessTrace.V1".utf8)

    public static func digest(_ witness: ApplicationWitnessTraceV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        CanonicalBinary.appendUInt32(witness.version, to: &data)
        CanonicalBinary.appendUInt32(try checkedUInt32(witness.columnCount), to: &data)
        CanonicalBinary.appendUInt32(try checkedUInt32(witness.rowCount), to: &data)
        for column in witness.columns {
            for value in column {
                CanonicalBinary.appendUInt32(value, to: &data)
            }
        }
        return SHA3Oracle.sha3_256(data)
    }
}

public enum AIRToSumcheckReductionV1 {
    public static func paddedEvaluationVector(
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> [UInt32] {
        var evaluations = try AIRSemanticVerifierV1.constraintEvaluations(
            definition: definition,
            trace: trace
        )
        guard !evaluations.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        var targetCount = 2
        while targetCount < evaluations.count {
            targetCount <<= 1
        }
        evaluations.append(contentsOf: repeatElement(0, count: targetCount - evaluations.count))
        return evaluations
    }

    public static func verify(
        statement: M31SumcheckStatementV1,
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> Bool {
        let evaluations = try paddedEvaluationVector(definition: definition, trace: trace)
        guard statement.laneCount == evaluations.count else {
            return false
        }
        return statement.initialEvaluationDigest == (try M31SumcheckEncodingV1.digestWords(evaluations))
    }
}

public struct AIRConstraintMultilinearSumcheckProofV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let airDefinitionDigest: Data
    public let traceRowCount: Int
    public let traceColumnCount: Int
    public let airEvaluationDigest: Data
    public let sumcheckProof: M31MultilinearSumcheckProofV1

    public init(
        version: UInt32 = Self.currentVersion,
        airDefinitionDigest: Data,
        traceRowCount: Int,
        traceColumnCount: Int,
        airEvaluationDigest: Data,
        sumcheckProof: M31MultilinearSumcheckProofV1
    ) throws {
        guard version == Self.currentVersion,
              airDefinitionDigest.count == 32,
              traceRowCount > 0,
              traceColumnCount > 0,
              airEvaluationDigest.count == 32,
              sumcheckProof.statement.claimedHypercubeSum == 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.airDefinitionDigest = airDefinitionDigest
        self.traceRowCount = traceRowCount
        self.traceColumnCount = traceColumnCount
        self.airEvaluationDigest = airEvaluationDigest
        self.sumcheckProof = sumcheckProof
    }
}

public enum AIRConstraintMultilinearSumcheckProofBuilderV1 {
    public static func prove(
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> AIRConstraintMultilinearSumcheckProofV1 {
        let evaluations = try AIRToSumcheckReductionV1.paddedEvaluationVector(
            definition: definition,
            trace: trace
        )
        let sumcheckProof = try M31MultilinearSumcheckProofBuilderV1.prove(
            evaluations: evaluations,
            claimedHypercubeSum: 0
        )
        return try assemble(
            definition: definition,
            trace: trace,
            airEvaluationDigest: M31SumcheckEncodingV1.digestWords(evaluations),
            sumcheckProof: sumcheckProof
        )
    }

    public static func assemble(
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1,
        airEvaluationDigest: Data,
        sumcheckProof: M31MultilinearSumcheckProofV1
    ) throws -> AIRConstraintMultilinearSumcheckProofV1 {
        let proof = try AIRConstraintMultilinearSumcheckProofV1(
            airDefinitionDigest: AIRDefinitionDigestV1.digest(definition),
            traceRowCount: trace.rowCount,
            traceColumnCount: trace.columnCount,
            airEvaluationDigest: airEvaluationDigest,
            sumcheckProof: sumcheckProof
        )
        guard try AIRConstraintMultilinearSumcheckVerifierV1.verify(
            proof,
            definition: definition,
            trace: trace
        ) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "AIR constraint multilinear sumcheck proof does not verify."
            )
        }
        return proof
    }
}

public struct AIRConstraintMultilinearSumcheckVerificationReportV1: Equatable, Sendable {
    public let sumcheckReport: M31MultilinearSumcheckVerificationReportV1
    public let airDefinitionDigestMatches: Bool
    public let traceShapeMatches: Bool
    public let airEvaluationDigestMatches: Bool
    public let sumcheckInitialDigestMatchesAIRReduction: Bool
    public let zeroSumClaimVerified: Bool
    public let airSemanticsVerified: Bool
    public let isZeroKnowledge: Bool

    public var provesAIRConstraintSumcheck: Bool {
        sumcheckReport.fullMultilinearSumcheckVerified &&
            airDefinitionDigestMatches &&
            traceShapeMatches &&
            airEvaluationDigestMatches &&
            sumcheckInitialDigestMatchesAIRReduction &&
            zeroSumClaimVerified
    }

    public var provesPublicAIRSemantics: Bool {
        provesAIRConstraintSumcheck && airSemanticsVerified
    }
}

public enum AIRConstraintMultilinearSumcheckVerifierV1 {
    public static func verificationReport(
        _ proof: AIRConstraintMultilinearSumcheckProofV1,
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> AIRConstraintMultilinearSumcheckVerificationReportV1 {
        let evaluations = try AIRToSumcheckReductionV1.paddedEvaluationVector(
            definition: definition,
            trace: trace
        )
        let evaluationDigest = try M31SumcheckEncodingV1.digestWords(evaluations)
        let sumcheckReport = try M31MultilinearSumcheckVerifierV1.verificationReport(
            proof: proof.sumcheckProof,
            statement: proof.sumcheckProof.statement
        )
        return try AIRConstraintMultilinearSumcheckVerificationReportV1(
            sumcheckReport: sumcheckReport,
            airDefinitionDigestMatches: proof.airDefinitionDigest == AIRDefinitionDigestV1.digest(definition),
            traceShapeMatches: proof.traceRowCount == trace.rowCount &&
                proof.traceColumnCount == trace.columnCount &&
                definition.columnCount == trace.columnCount,
            airEvaluationDigestMatches: proof.airEvaluationDigest == evaluationDigest,
            sumcheckInitialDigestMatchesAIRReduction: proof.sumcheckProof.statement.initialEvaluationDigest == evaluationDigest,
            zeroSumClaimVerified: proof.sumcheckProof.statement.claimedHypercubeSum == 0,
            airSemanticsVerified: AIRSemanticVerifierV1.verify(definition: definition, trace: trace),
            isZeroKnowledge: false
        )
    }

    public static func verify(
        _ proof: AIRConstraintMultilinearSumcheckProofV1,
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> Bool {
        try verificationReport(
            proof,
            definition: definition,
            trace: trace
        ).provesAIRConstraintSumcheck
    }
}

public struct AIRCompositionEvaluationV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let traceRowCount: Int
    public let traceColumnCount: Int
    public let transitionConstraintCount: Int
    public let boundaryConstraintCount: Int
    public let compositionWeights: [UInt32]
    public let rawEvaluationDigest: Data
    public let combinedEvaluations: [UInt32]

    public init(
        version: UInt32 = Self.currentVersion,
        traceRowCount: Int,
        traceColumnCount: Int,
        transitionConstraintCount: Int,
        boundaryConstraintCount: Int,
        compositionWeights: [UInt32],
        rawEvaluationDigest: Data,
        combinedEvaluations: [UInt32]
    ) throws {
        let transitionRowCount = transitionConstraintCount > 0 ? max(0, traceRowCount - 1) : 0
        let transitionCombinedCount = try checkedBufferLength(
            transitionRowCount,
            1
        )
        let expectedCombinedCount = transitionCombinedCount.addingReportingOverflow(boundaryConstraintCount)
        let totalConstraintCount = transitionConstraintCount.addingReportingOverflow(boundaryConstraintCount)
        guard version == Self.currentVersion,
              traceRowCount > 0,
              traceColumnCount > 0,
              transitionConstraintCount >= 0,
              boundaryConstraintCount >= 0,
              !totalConstraintCount.overflow,
              transitionConstraintCount == 0 || traceRowCount > 1,
              totalConstraintCount.partialValue > 0,
              compositionWeights.count == totalConstraintCount.partialValue,
              rawEvaluationDigest.count == 32,
              !expectedCombinedCount.overflow,
              combinedEvaluations.count == expectedCombinedCount.partialValue else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(compositionWeights)
        try M31Field.validateCanonical(combinedEvaluations)
        guard compositionWeights.allSatisfy({ $0 != 0 }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.traceRowCount = traceRowCount
        self.traceColumnCount = traceColumnCount
        self.transitionConstraintCount = transitionConstraintCount
        self.boundaryConstraintCount = boundaryConstraintCount
        self.compositionWeights = compositionWeights
        self.rawEvaluationDigest = rawEvaluationDigest
        self.combinedEvaluations = combinedEvaluations
    }

    public var allConstraintsVanish: Bool {
        combinedEvaluations.allSatisfy { $0 == 0 }
    }
}

public enum AIRCompositionOracleV1 {
    public static func evaluate(
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> AIRCompositionEvaluationV1 {
        guard definition.columnCount == trace.columnCount,
              trace.rowCount > 1 || definition.transitionConstraints.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        let rawEvaluations = try AIRSemanticVerifierV1.constraintEvaluations(
            definition: definition,
            trace: trace
        )
        let rawEvaluationDigest = try M31SumcheckEncodingV1.digestWords(rawEvaluations)
        let weights = try compositionWeights(
            definition: definition,
            trace: trace
        )
        return try AIRCompositionEvaluationV1(
            traceRowCount: trace.rowCount,
            traceColumnCount: trace.columnCount,
            transitionConstraintCount: definition.transitionConstraints.count,
            boundaryConstraintCount: definition.boundaryConstraints.count,
            compositionWeights: weights,
            rawEvaluationDigest: rawEvaluationDigest,
            combinedEvaluations: combinedEvaluations(
                rawEvaluations: rawEvaluations,
                traceRowCount: trace.rowCount,
                transitionConstraintCount: definition.transitionConstraints.count,
                boundaryConstraintCount: definition.boundaryConstraints.count,
                weights: weights
            )
        )
    }

    public static func verify(
        _ composition: AIRCompositionEvaluationV1,
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> Bool {
        try evaluate(definition: definition, trace: trace) == composition
    }

    private static func compositionWeights(
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> [UInt32] {
        let weightCount = definition.transitionConstraints.count + definition.boundaryConstraints.count
        guard weightCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var transcript = SHA3Oracle.TranscriptState()
        try transcript.absorb(transcriptHeader())
        try transcript.absorb(AIRDefinitionDigestV1.digest(definition))
        var shapeFrame = Data()
        CanonicalBinary.appendUInt64(UInt64(trace.rowCount), to: &shapeFrame)
        CanonicalBinary.appendUInt64(UInt64(trace.columnCount), to: &shapeFrame)
        CanonicalBinary.appendUInt64(UInt64(definition.transitionConstraints.count), to: &shapeFrame)
        CanonicalBinary.appendUInt64(UInt64(definition.boundaryConstraints.count), to: &shapeFrame)
        try transcript.absorb(shapeFrame)
        return try transcript.squeezeUInt32(
            count: weightCount,
            modulus: M31Field.modulus - 1
        ).map { $0 + 1 }
    }

    private static func combinedEvaluations(
        rawEvaluations: [UInt32],
        traceRowCount: Int,
        transitionConstraintCount: Int,
        boundaryConstraintCount: Int,
        weights: [UInt32]
    ) throws -> [UInt32] {
        let transitionRowCount = transitionConstraintCount > 0 ? traceRowCount - 1 : 0
        let transitionRawCount = try checkedBufferLength(
            transitionRowCount,
            transitionConstraintCount
        )
        let expectedRawCount = transitionRawCount.addingReportingOverflow(boundaryConstraintCount)
        guard !expectedRawCount.overflow,
              rawEvaluations.count == expectedRawCount.partialValue,
              weights.count == transitionConstraintCount + boundaryConstraintCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(rawEvaluations)
        try M31Field.validateCanonical(weights)

        var combined: [UInt32] = []
        combined.reserveCapacity(transitionRowCount + boundaryConstraintCount)
        for row in 0..<transitionRowCount {
            var accumulator: UInt32 = 0
            let rowOffset = row * transitionConstraintCount
            for constraintIndex in 0..<transitionConstraintCount {
                accumulator = M31Field.add(
                    accumulator,
                    M31Field.multiply(
                        weights[constraintIndex],
                        rawEvaluations[rowOffset + constraintIndex]
                    )
                )
            }
            combined.append(accumulator)
        }

        let boundaryOffset = transitionRowCount * transitionConstraintCount
        for boundaryIndex in 0..<boundaryConstraintCount {
            combined.append(M31Field.multiply(
                weights[transitionConstraintCount + boundaryIndex],
                rawEvaluations[boundaryOffset + boundaryIndex]
            ))
        }
        return combined
    }

    private static func transcriptHeader() -> Data {
        var data = Data()
        let domain = Data("AppleZKProver.AIRComposition.V1".utf8)
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        CanonicalBinary.appendUInt32(AIRCompositionEvaluationV1.currentVersion, to: &data)
        CanonicalBinary.appendUInt32(M31Field.modulus, to: &data)
        return data
    }
}

public enum AIRCompositionEvaluationDigestV1 {
    private static let domain = Data("AppleZKProver.AIRCompositionEvaluation.V1".utf8)

    public static func digest(_ composition: AIRCompositionEvaluationV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        CanonicalBinary.appendUInt32(composition.version, to: &data)
        CanonicalBinary.appendUInt64(UInt64(composition.traceRowCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(composition.traceColumnCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(composition.transitionConstraintCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(composition.boundaryConstraintCount), to: &data)
        appendM31Words(composition.compositionWeights, to: &data)
        data.append(composition.rawEvaluationDigest)
        appendM31Words(composition.combinedEvaluations, to: &data)
        return SHA3Oracle.sha3_256(data)
    }
}

public enum AIRPublicQuotientConstraintKindV1: UInt32, Codable, Sendable {
    case transition = 0
    case boundary = 1
}

public struct AIRConstraintQuotientPolynomialV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let kind: AIRPublicQuotientConstraintKindV1
    public let constraintIndex: Int
    public let numeratorDegreeBound: Int
    public let vanishingDegree: Int
    public let quotientDegreeBound: Int
    public let quotientCoefficients: [UInt32]

    public init(
        version: UInt32 = Self.currentVersion,
        kind: AIRPublicQuotientConstraintKindV1,
        constraintIndex: Int,
        numeratorDegreeBound: Int,
        vanishingDegree: Int,
        quotientDegreeBound: Int,
        quotientCoefficients: [UInt32]
    ) throws {
        let maxCoefficientCount = quotientDegreeBound.addingReportingOverflow(1)
        guard version == Self.currentVersion,
              constraintIndex >= 0,
              numeratorDegreeBound >= 0,
              vanishingDegree > 0,
              quotientDegreeBound >= 0,
              !maxCoefficientCount.overflow,
              !quotientCoefficients.isEmpty,
              quotientCoefficients.count <= maxCoefficientCount.partialValue,
              M31PolynomialV1.normalize(quotientCoefficients) == quotientCoefficients else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(quotientCoefficients)
        self.version = version
        self.kind = kind
        self.constraintIndex = constraintIndex
        self.numeratorDegreeBound = numeratorDegreeBound
        self.vanishingDegree = vanishingDegree
        self.quotientDegreeBound = quotientDegreeBound
        self.quotientCoefficients = quotientCoefficients
    }
}

public struct AIRPublicQuotientProofV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let traceRowCount: Int
    public let traceColumnCount: Int
    public let tracePolynomialDigest: Data
    public let quotientPolynomials: [AIRConstraintQuotientPolynomialV1]

    public init(
        version: UInt32 = Self.currentVersion,
        traceRowCount: Int,
        traceColumnCount: Int,
        tracePolynomialDigest: Data,
        quotientPolynomials: [AIRConstraintQuotientPolynomialV1]
    ) throws {
        guard version == Self.currentVersion,
              traceRowCount > 0,
              traceColumnCount > 0,
              tracePolynomialDigest.count == 32,
              !quotientPolynomials.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.traceRowCount = traceRowCount
        self.traceColumnCount = traceColumnCount
        self.tracePolynomialDigest = tracePolynomialDigest
        self.quotientPolynomials = quotientPolynomials
    }
}

public enum AIRTracePolynomialDigestV1 {
    private static let domain = Data("AppleZKProver.AIRTracePolynomials.V1".utf8)

    public static func digest(_ tracePolynomials: [[UInt32]]) throws -> Data {
        guard !tracePolynomials.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        CanonicalBinary.appendUInt32(AIRPublicQuotientProofV1.currentVersion, to: &data)
        CanonicalBinary.appendUInt64(UInt64(tracePolynomials.count), to: &data)
        for polynomial in tracePolynomials {
            let normalized = M31PolynomialV1.normalize(polynomial)
            try M31Field.validateCanonical(normalized)
            appendM31Words(normalized, to: &data)
        }
        return SHA3Oracle.sha3_256(data)
    }
}

public enum AIRPublicQuotientProofDigestV1 {
    private static let domain = Data("AppleZKProver.AIRPublicQuotientProof.V1".utf8)

    public static func digest(_ proof: AIRPublicQuotientProofV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        try CanonicalBinary.appendLengthPrefixed(
            try AIRPublicQuotientProofCodecV1.encode(proof),
            to: &data
        )
        return SHA3Oracle.sha3_256(data)
    }
}

public enum AIRPublicQuotientOracleV1 {
    public static func prove(
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> AIRPublicQuotientProofV1 {
        guard definition.columnCount == trace.columnCount,
              trace.rowCount > 1 || definition.transitionConstraints.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        let tracePolynomials = try traceColumnPolynomials(trace)
        let quotientPolynomials = try quotientPolynomials(
            definition: definition,
            tracePolynomials: tracePolynomials,
            traceRowCount: trace.rowCount
        )
        return try AIRPublicQuotientProofV1(
            traceRowCount: trace.rowCount,
            traceColumnCount: trace.columnCount,
            tracePolynomialDigest: AIRTracePolynomialDigestV1.digest(tracePolynomials),
            quotientPolynomials: quotientPolynomials
        )
    }

    public static func verify(
        _ proof: AIRPublicQuotientProofV1,
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> Bool {
        try prove(definition: definition, trace: trace) == proof
    }

    public static func traceColumnPolynomials(_ trace: AIRExecutionTraceV1) throws -> [[UInt32]] {
        guard UInt64(trace.rowCount) <= UInt64(M31Field.modulus) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let xCoordinates = try rowDomain(count: trace.rowCount)
        var polynomials: [[UInt32]] = []
        polynomials.reserveCapacity(trace.columnCount)
        for column in 0..<trace.columnCount {
            var values: [UInt32] = []
            values.reserveCapacity(trace.rowCount)
            for row in 0..<trace.rowCount {
                values.append(try trace.value(row: row, column: column))
            }
            polynomials.append(try M31PolynomialV1.interpolate(
                xCoordinates: xCoordinates,
                values: values
            ))
        }
        return polynomials
    }

    private static func quotientPolynomials(
        definition: AIRDefinitionV1,
        tracePolynomials: [[UInt32]],
        traceRowCount: Int
    ) throws -> [AIRConstraintQuotientPolynomialV1] {
        guard definition.columnCount == tracePolynomials.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        var quotients: [AIRConstraintQuotientPolynomialV1] = []
        quotients.reserveCapacity(definition.transitionConstraints.count + definition.boundaryConstraints.count)

        if !definition.transitionConstraints.isEmpty {
            let transitionVanishing = try M31PolynomialV1.vanishingPolynomial(
                points: rowDomain(count: traceRowCount - 1)
            )
            for (index, constraint) in definition.transitionConstraints.enumerated() {
                let numerator = try constraintNumerator(
                    constraint,
                    tracePolynomials: tracePolynomials
                )
                quotients.append(try quotientCertificate(
                    kind: .transition,
                    constraintIndex: index,
                    numerator: numerator,
                    vanishingPolynomial: transitionVanishing
                ))
            }
        }

        for (index, constraint) in definition.boundaryConstraints.enumerated() {
            guard constraint.rowIndex < traceRowCount else {
                throw AppleZKProverError.invalidInputLayout
            }
            let numerator = try constraintNumerator(
                constraint.polynomial,
                tracePolynomials: tracePolynomials
            )
            let rowPoint = try rowCoordinate(constraint.rowIndex)
            let boundaryVanishing = [M31Field.negate(rowPoint), UInt32(1)]
            quotients.append(try quotientCertificate(
                kind: .boundary,
                constraintIndex: index,
                numerator: numerator,
                vanishingPolynomial: boundaryVanishing
            ))
        }

        return quotients
    }

    private static func quotientCertificate(
        kind: AIRPublicQuotientConstraintKindV1,
        constraintIndex: Int,
        numerator: [UInt32],
        vanishingPolynomial: [UInt32]
    ) throws -> AIRConstraintQuotientPolynomialV1 {
        let normalizedNumerator = M31PolynomialV1.normalize(numerator)
        let normalizedVanishing = M31PolynomialV1.normalize(vanishingPolynomial)
        let division = try M31PolynomialV1.divide(
            normalizedNumerator,
            by: normalizedVanishing
        )
        guard M31PolynomialV1.isZero(division.remainder),
              M31PolynomialV1.normalize(
                try M31PolynomialV1.multiply(division.quotient, normalizedVanishing)
              ) == normalizedNumerator else {
            throw AppleZKProverError.correctnessValidationFailed(
                "AIR constraint numerator is not divisible by its public vanishing polynomial."
            )
        }
        let numeratorDegree = M31PolynomialV1.degree(normalizedNumerator)
        let vanishingDegree = M31PolynomialV1.degree(normalizedVanishing)
        return try AIRConstraintQuotientPolynomialV1(
            kind: kind,
            constraintIndex: constraintIndex,
            numeratorDegreeBound: numeratorDegree,
            vanishingDegree: vanishingDegree,
            quotientDegreeBound: max(0, numeratorDegree - vanishingDegree),
            quotientCoefficients: M31PolynomialV1.normalize(division.quotient)
        )
    }

    private static func constraintNumerator(
        _ polynomial: AIRConstraintPolynomialV1,
        tracePolynomials: [[UInt32]]
    ) throws -> [UInt32] {
        var accumulator = [UInt32(0)]
        for term in polynomial.terms {
            var product = [term.coefficient]
            for factor in term.factors {
                guard factor.column < tracePolynomials.count else {
                    throw AppleZKProverError.invalidInputLayout
                }
                let factorPolynomial: [UInt32]
                switch factor.kind {
                case .current:
                    factorPolynomial = tracePolynomials[factor.column]
                case .next:
                    factorPolynomial = try M31PolynomialV1.shiftByOne(
                        tracePolynomials[factor.column]
                    )
                }
                product = try M31PolynomialV1.multiply(product, factorPolynomial)
            }
            accumulator = try M31PolynomialV1.add(accumulator, product)
        }
        return M31PolynomialV1.normalize(accumulator)
    }

    private static func rowDomain(count: Int) throws -> [UInt32] {
        guard count > 0,
              UInt64(count) <= UInt64(M31Field.modulus) else {
            throw AppleZKProverError.invalidInputLayout
        }
        return try (0..<count).map { try rowCoordinate($0) }
    }

    private static func rowCoordinate(_ row: Int) throws -> UInt32 {
        guard row >= 0,
              UInt64(row) < UInt64(M31Field.modulus) else {
            throw AppleZKProverError.invalidInputLayout
        }
        return UInt32(row)
    }
}

private enum M31PolynomialV1 {
    static func normalize(_ coefficients: [UInt32]) -> [UInt32] {
        guard !coefficients.isEmpty else {
            return [0]
        }
        var trimmed = coefficients
        while trimmed.count > 1 && trimmed.last == 0 {
            trimmed.removeLast()
        }
        return trimmed
    }

    static func degree(_ coefficients: [UInt32]) -> Int {
        let normalized = normalize(coefficients)
        return normalized.count == 1 && normalized[0] == 0 ? 0 : normalized.count - 1
    }

    static func isZero(_ coefficients: [UInt32]) -> Bool {
        normalize(coefficients) == [0]
    }

    static func add(_ lhs: [UInt32], _ rhs: [UInt32]) throws -> [UInt32] {
        try M31Field.validateCanonical(lhs)
        try M31Field.validateCanonical(rhs)
        let count = max(lhs.count, rhs.count)
        var result = Array(repeating: UInt32(0), count: count)
        for index in 0..<count {
            result[index] = M31Field.add(
                index < lhs.count ? lhs[index] : 0,
                index < rhs.count ? rhs[index] : 0
            )
        }
        return normalize(result)
    }

    static func subtract(_ lhs: [UInt32], _ rhs: [UInt32]) throws -> [UInt32] {
        try M31Field.validateCanonical(lhs)
        try M31Field.validateCanonical(rhs)
        let count = max(lhs.count, rhs.count)
        var result = Array(repeating: UInt32(0), count: count)
        for index in 0..<count {
            result[index] = M31Field.subtract(
                index < lhs.count ? lhs[index] : 0,
                index < rhs.count ? rhs[index] : 0
            )
        }
        return normalize(result)
    }

    static func multiply(_ lhs: [UInt32], _ rhs: [UInt32]) throws -> [UInt32] {
        let left = normalize(lhs)
        let right = normalize(rhs)
        try M31Field.validateCanonical(left)
        try M31Field.validateCanonical(right)
        if isZero(left) || isZero(right) {
            return [0]
        }
        let count = left.count.addingReportingOverflow(right.count - 1)
        guard !count.overflow else {
            throw AppleZKProverError.invalidInputLayout
        }
        var result = Array(repeating: UInt32(0), count: count.partialValue)
        for leftIndex in left.indices {
            for rightIndex in right.indices {
                let index = leftIndex + rightIndex
                result[index] = M31Field.add(
                    result[index],
                    M31Field.multiply(left[leftIndex], right[rightIndex])
                )
            }
        }
        return normalize(result)
    }

    static func scale(_ coefficients: [UInt32], by scalar: UInt32) throws -> [UInt32] {
        try M31Field.validateCanonical(coefficients)
        guard scalar < M31Field.modulus else {
            throw AppleZKProverError.invalidInputLayout
        }
        if scalar == 0 {
            return [0]
        }
        return normalize(coefficients.map { M31Field.multiply($0, scalar) })
    }

    static func shiftByOne(_ coefficients: [UInt32]) throws -> [UInt32] {
        let normalized = normalize(coefficients)
        try M31Field.validateCanonical(normalized)
        var result = [UInt32(0)]
        for coefficient in normalized.reversed() {
            result = try multiply(result, [1, 1])
            result[0] = M31Field.add(result[0], coefficient)
        }
        return normalize(result)
    }

    static func vanishingPolynomial(points: [UInt32]) throws -> [UInt32] {
        guard !points.isEmpty,
              Set(points).count == points.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(points)
        var polynomial = [UInt32(1)]
        for point in points {
            polynomial = try multiply(polynomial, [M31Field.negate(point), 1])
        }
        return normalize(polynomial)
    }

    static func interpolate(
        xCoordinates: [UInt32],
        values: [UInt32]
    ) throws -> [UInt32] {
        guard !xCoordinates.isEmpty,
              xCoordinates.count == values.count,
              Set(xCoordinates).count == xCoordinates.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(xCoordinates)
        try M31Field.validateCanonical(values)

        let vanishing = try vanishingPolynomial(points: xCoordinates)
        var coefficients = [UInt32(0)]
        for index in xCoordinates.indices {
            let value = values[index]
            if value == 0 {
                continue
            }
            let divisor = [M31Field.negate(xCoordinates[index]), UInt32(1)]
            let basisDivision = try divide(vanishing, by: divisor)
            guard isZero(basisDivision.remainder) else {
                throw AppleZKProverError.correctnessValidationFailed(
                    "M31 interpolation basis division was not exact."
                )
            }
            var denominator = UInt32(1)
            for otherIndex in xCoordinates.indices where otherIndex != index {
                denominator = M31Field.multiply(
                    denominator,
                    M31Field.subtract(xCoordinates[index], xCoordinates[otherIndex])
                )
            }
            let scaleFactor = M31Field.multiply(value, try M31Field.inverse(denominator))
            coefficients = try add(
                coefficients,
                scale(basisDivision.quotient, by: scaleFactor)
            )
        }
        return normalize(coefficients)
    }

    static func divide(
        _ numerator: [UInt32],
        by denominator: [UInt32]
    ) throws -> (quotient: [UInt32], remainder: [UInt32]) {
        var remainder = normalize(numerator)
        let divisor = normalize(denominator)
        try M31Field.validateCanonical(remainder)
        try M31Field.validateCanonical(divisor)
        guard !isZero(divisor) else {
            throw AppleZKProverError.invalidInputLayout
        }
        if remainder.count < divisor.count {
            return ([0], remainder)
        }
        let quotientCount = remainder.count - divisor.count + 1
        var quotient = Array(repeating: UInt32(0), count: quotientCount)
        let divisorLeadInverse = try M31Field.inverse(divisor[divisor.count - 1])
        while remainder.count >= divisor.count && !isZero(remainder) {
            let degreeOffset = remainder.count - divisor.count
            let coefficient = M31Field.multiply(
                remainder[remainder.count - 1],
                divisorLeadInverse
            )
            quotient[degreeOffset] = coefficient
            if coefficient != 0 {
                for divisorIndex in divisor.indices {
                    let remainderIndex = degreeOffset + divisorIndex
                    remainder[remainderIndex] = M31Field.subtract(
                        remainder[remainderIndex],
                        M31Field.multiply(coefficient, divisor[divisorIndex])
                    )
                }
            }
            remainder = normalize(remainder)
        }
        return (normalize(quotient), normalize(remainder))
    }
}

public struct AIRProofStatementV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let airDefinitionDigest: Data
    public let witnessTraceDigest: Data
    public let traceRowCount: Int
    public let traceColumnCount: Int
    public let compositionEvaluationDigest: Data
    public let publicQuotientProofDigest: Data

    public init(
        version: UInt32 = Self.currentVersion,
        airDefinitionDigest: Data,
        witnessTraceDigest: Data,
        traceRowCount: Int,
        traceColumnCount: Int,
        compositionEvaluationDigest: Data,
        publicQuotientProofDigest: Data
    ) throws {
        guard version == Self.currentVersion,
              airDefinitionDigest.count == 32,
              witnessTraceDigest.count == 32,
              traceRowCount > 0,
              traceColumnCount > 0,
              compositionEvaluationDigest.count == 32,
              publicQuotientProofDigest.count == 32 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.airDefinitionDigest = airDefinitionDigest
        self.witnessTraceDigest = witnessTraceDigest
        self.traceRowCount = traceRowCount
        self.traceColumnCount = traceColumnCount
        self.compositionEvaluationDigest = compositionEvaluationDigest
        self.publicQuotientProofDigest = publicQuotientProofDigest
    }

    public func digest() throws -> Data {
        var data = Data()
        let domain = Data("AppleZKProver.AIRProofStatement.V1".utf8)
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        CanonicalBinary.appendUInt32(version, to: &data)
        data.append(airDefinitionDigest)
        data.append(witnessTraceDigest)
        CanonicalBinary.appendUInt64(UInt64(traceRowCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(traceColumnCount), to: &data)
        data.append(compositionEvaluationDigest)
        data.append(publicQuotientProofDigest)
        return SHA3Oracle.sha3_256(data)
    }
}

public struct AIRProofV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let statementDigest: Data
    public let airDefinition: AIRDefinitionV1
    public let witness: ApplicationWitnessTraceV1
    public let composition: AIRCompositionEvaluationV1
    public let publicQuotientProof: AIRPublicQuotientProofV1

    public init(
        version: UInt32 = Self.currentVersion,
        statementDigest: Data,
        airDefinition: AIRDefinitionV1,
        witness: ApplicationWitnessTraceV1,
        composition: AIRCompositionEvaluationV1,
        publicQuotientProof: AIRPublicQuotientProofV1
    ) throws {
        guard version == Self.currentVersion,
              statementDigest.count == 32 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.statementDigest = statementDigest
        self.airDefinition = airDefinition
        self.witness = witness
        self.composition = composition
        self.publicQuotientProof = publicQuotientProof
    }
}

public struct AIRProofVerificationReportV1: Equatable, Sendable {
    public let statementDigestMatches: Bool
    public let airDefinitionDigestMatches: Bool
    public let witnessTraceDigestMatches: Bool
    public let witnessToAIRTraceProduced: Bool
    public let compositionEvaluationDigestMatches: Bool
    public let compositionMatchesTrace: Bool
    public let compositionVanishes: Bool
    public let publicQuotientProofDigestMatches: Bool
    public let publicQuotientProofVerified: Bool
    public let airSemanticsVerified: Bool
    public let isSuccinct: Bool
    public let isZeroKnowledge: Bool

    public var verifiesPublicRevealedTraceAIR: Bool {
        statementDigestMatches &&
            airDefinitionDigestMatches &&
            witnessTraceDigestMatches &&
            witnessToAIRTraceProduced &&
            compositionEvaluationDigestMatches &&
            compositionMatchesTrace &&
            compositionVanishes &&
            publicQuotientProofDigestMatches &&
            publicQuotientProofVerified &&
            airSemanticsVerified
    }

    public func verifies(_ scope: AIRProofClaimScopeV1) -> Bool {
        switch scope {
        case .publicRevealedTraceConstraintEvaluation:
            return verifiesPublicRevealedTraceAIR
        case .succinctPrivateAIR:
            return false
        }
    }
}

public enum AIRProofBuilderV1 {
    public static func prove(
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1
    ) throws -> (statement: AIRProofStatementV1, proof: AIRProofV1) {
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: witness,
            for: airDefinition
        )
        let composition = try AIRCompositionOracleV1.evaluate(
            definition: airDefinition,
            trace: trace
        )
        guard composition.allConstraintsVanish,
              try AIRSemanticVerifierV1.verify(definition: airDefinition, trace: trace) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Public witness trace does not satisfy the AIR definition."
            )
        }
        let publicQuotientProof = try AIRPublicQuotientOracleV1.prove(
            definition: airDefinition,
            trace: trace
        )
        let statement = try AIRProofStatementV1(
            airDefinitionDigest: AIRDefinitionDigestV1.digest(airDefinition),
            witnessTraceDigest: ApplicationWitnessDigestV1.digest(witness),
            traceRowCount: trace.rowCount,
            traceColumnCount: trace.columnCount,
            compositionEvaluationDigest: AIRCompositionEvaluationDigestV1.digest(composition),
            publicQuotientProofDigest: AIRPublicQuotientProofDigestV1.digest(publicQuotientProof)
        )
        let proof = try AIRProofV1(
            statementDigest: statement.digest(),
            airDefinition: airDefinition,
            witness: witness,
            composition: composition,
            publicQuotientProof: publicQuotientProof
        )
        guard try AIRProofVerifierV1.verify(proof: proof, statement: statement) else {
            throw AppleZKProverError.correctnessValidationFailed("AIR proof does not verify.")
        }
        return (statement, proof)
    }
}

public enum AIRProofVerifierV1 {
    public static func verificationReport(
        proof: AIRProofV1,
        statement: AIRProofStatementV1
    ) throws -> AIRProofVerificationReportV1 {
        let statementDigestMatches = proof.statementDigest == (try statement.digest())
        let airDefinitionDigestMatches = statement.airDefinitionDigest == (try AIRDefinitionDigestV1.digest(proof.airDefinition))
        let witnessTraceDigestMatches = statement.witnessTraceDigest == (try ApplicationWitnessDigestV1.digest(proof.witness))
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: proof.witness,
            for: proof.airDefinition
        )
        let expectedComposition = try AIRCompositionOracleV1.evaluate(
            definition: proof.airDefinition,
            trace: trace
        )
        let compositionDigestMatches = statement.compositionEvaluationDigest == (try AIRCompositionEvaluationDigestV1.digest(proof.composition))
        let quotientDigestMatches = statement.publicQuotientProofDigest == (try AIRPublicQuotientProofDigestV1.digest(proof.publicQuotientProof))
        let quotientVerified: Bool
        do {
            quotientVerified = try AIRPublicQuotientOracleV1.verify(
                proof.publicQuotientProof,
                definition: proof.airDefinition,
                trace: trace
            )
        } catch {
            quotientVerified = false
        }
        let shapeMatches = statement.traceRowCount == trace.rowCount &&
            statement.traceColumnCount == trace.columnCount
        return AIRProofVerificationReportV1(
            statementDigestMatches: statementDigestMatches,
            airDefinitionDigestMatches: airDefinitionDigestMatches,
            witnessTraceDigestMatches: witnessTraceDigestMatches,
            witnessToAIRTraceProduced: shapeMatches,
            compositionEvaluationDigestMatches: compositionDigestMatches,
            compositionMatchesTrace: expectedComposition == proof.composition,
            compositionVanishes: proof.composition.allConstraintsVanish,
            publicQuotientProofDigestMatches: quotientDigestMatches,
            publicQuotientProofVerified: quotientVerified,
            airSemanticsVerified: try AIRSemanticVerifierV1.verify(
                definition: proof.airDefinition,
                trace: trace
            ),
            isSuccinct: false,
            isZeroKnowledge: false
        )
    }

    public static func verificationReport(
        encodedProof: Data,
        statement: AIRProofStatementV1
    ) throws -> AIRProofVerificationReportV1 {
        try verificationReport(
            proof: AIRProofCodecV1.decode(encodedProof),
            statement: statement
        )
    }

    public static func verify(
        proof: AIRProofV1,
        statement: AIRProofStatementV1
    ) throws -> Bool {
        try verificationReport(proof: proof, statement: statement)
            .verifies(.publicRevealedTraceConstraintEvaluation)
    }

    public static func verify(
        encodedProof: Data,
        statement: AIRProofStatementV1
    ) throws -> Bool {
        try verificationReport(encodedProof: encodedProof, statement: statement)
            .verifies(.publicRevealedTraceConstraintEvaluation)
    }
}

public enum AIRProofQuotientPCSArtifactOpenBoundaryV1: String, Codable, CaseIterable, Sendable {
    case privateWitness = "private-witness"
    case zeroKnowledge = "zero-knowledge"
    case succinctAIRGKRProof = "succinct-air-gkr-proof"
}

public struct AIRProofQuotientPCSArtifactManifestV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1
    public static let artifactName = "AIRProofQuotientPCSArtifactV1"
    public static let current = AIRProofQuotientPCSArtifactManifestV1()

    public let version: UInt32
    public let artifact: String
    public let includesAIRProof: Bool
    public let includesPublicQuotientPCSProofBundle: Bool
    public let verifiesPublicRevealedTraceAIR: Bool
    public let verifiesQuotientPCSBundleAgainstAIRProof: Bool
    public let usesPCSBackedQuotientLowDegreeProof: Bool
    public let isSuccinctAIRGKRProof: Bool
    public let isZeroKnowledge: Bool
    public let openBoundaries: [AIRProofQuotientPCSArtifactOpenBoundaryV1]

    public init() {
        self.version = Self.currentVersion
        self.artifact = Self.artifactName
        self.includesAIRProof = true
        self.includesPublicQuotientPCSProofBundle = true
        self.verifiesPublicRevealedTraceAIR = true
        self.verifiesQuotientPCSBundleAgainstAIRProof = true
        self.usesPCSBackedQuotientLowDegreeProof = true
        self.isSuccinctAIRGKRProof = false
        self.isZeroKnowledge = false
        self.openBoundaries = [
            .privateWitness,
            .zeroKnowledge,
            .succinctAIRGKRProof,
        ]
    }
}

public struct AIRQuotientCirclePCSChunkV1: Equatable, Sendable {
    public let chunkIndex: Int
    public let sourceQuotientIndices: [Int]
    public let polynomial: CircleCodewordPolynomial
    public let polynomialClaim: CirclePCSFRIPolynomialClaimV1

    public init(
        chunkIndex: Int,
        sourceQuotientIndices: [Int],
        polynomial: CircleCodewordPolynomial,
        polynomialClaim: CirclePCSFRIPolynomialClaimV1
    ) throws {
        guard chunkIndex >= 0,
              !sourceQuotientIndices.isEmpty,
              sourceQuotientIndices.count <= AIRPublicQuotientToCirclePCSWitnessV1.m31QuotientsPerQM31Polynomial,
              sourceQuotientIndices.allSatisfy({ $0 >= 0 }),
              polynomialClaim.polynomial == polynomial else {
            throw AppleZKProverError.invalidInputLayout
        }
        for pair in zip(sourceQuotientIndices, sourceQuotientIndices.dropFirst()) {
            guard pair.0 < pair.1 else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        self.chunkIndex = chunkIndex
        self.sourceQuotientIndices = sourceQuotientIndices
        self.polynomial = polynomial
        self.polynomialClaim = polynomialClaim
    }
}

public struct AIRQuotientCirclePCSWitnessV1: Equatable, Sendable {
    public let domain: CircleDomainDescriptor
    public let quotientProofDigest: Data
    public let quotientPolynomialCount: Int
    public let claimedStorageIndices: [Int]
    public let chunks: [AIRQuotientCirclePCSChunkV1]

    public init(
        domain: CircleDomainDescriptor,
        quotientProofDigest: Data,
        quotientPolynomialCount: Int,
        claimedStorageIndices: [Int],
        chunks: [AIRQuotientCirclePCSChunkV1]
    ) throws {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed,
              quotientProofDigest.count == 32,
              quotientPolynomialCount > 0,
              !claimedStorageIndices.isEmpty,
              !chunks.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        var previousClaimedStorageIndex: Int?
        for storageIndex in claimedStorageIndices {
            guard storageIndex >= 0,
                  storageIndex < domain.size,
                  previousClaimedStorageIndex.map({ $0 < storageIndex }) ?? true else {
                throw AppleZKProverError.invalidInputLayout
            }
            previousClaimedStorageIndex = storageIndex
        }
        var expectedQuotientIndex = 0
        for (index, chunk) in chunks.enumerated() {
            let nextExpectedQuotientIndex = expectedQuotientIndex.addingReportingOverflow(
                chunk.sourceQuotientIndices.count
            )
            guard !nextExpectedQuotientIndex.overflow else {
                throw AppleZKProverError.invalidInputLayout
            }
            let expectedSourceIndices = Array(
                expectedQuotientIndex..<nextExpectedQuotientIndex.partialValue
            )
            guard chunk.chunkIndex == index,
                  !chunk.sourceQuotientIndices.isEmpty,
                  chunk.sourceQuotientIndices == expectedSourceIndices,
                  chunk.polynomialClaim.domain == domain else {
                throw AppleZKProverError.invalidInputLayout
            }
            expectedQuotientIndex = nextExpectedQuotientIndex.partialValue
        }
        guard expectedQuotientIndex == quotientPolynomialCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.domain = domain
        self.quotientProofDigest = quotientProofDigest
        self.quotientPolynomialCount = quotientPolynomialCount
        self.claimedStorageIndices = claimedStorageIndices
        self.chunks = chunks
    }

    public var polynomialClaims: [CirclePCSFRIPolynomialClaimV1] {
        chunks.map(\.polynomialClaim)
    }
}

public enum AIRPublicQuotientToCirclePCSWitnessV1 {
    public static let m31QuotientsPerQM31Polynomial = 4

    public static func make(
        quotientProof: AIRPublicQuotientProofV1,
        domain: CircleDomainDescriptor,
        claimStorageIndices: [Int]? = nil
    ) throws -> AIRQuotientCirclePCSWitnessV1 {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed else {
            throw AppleZKProverError.invalidInputLayout
        }
        let claimedStorageIndices = try normalizedStorageIndices(
            claimStorageIndices ?? [0],
            domain: domain
        )
        let quotientRecords = quotientProof.quotientPolynomials
        var chunks: [AIRQuotientCirclePCSChunkV1] = []
        chunks.reserveCapacity((quotientRecords.count + m31QuotientsPerQM31Polynomial - 1) / m31QuotientsPerQM31Polynomial)
        var firstQuotientIndex = 0
        while firstQuotientIndex < quotientRecords.count {
            let sourceIndices = Array(
                firstQuotientIndex..<min(
                    firstQuotientIndex + m31QuotientsPerQM31Polynomial,
                    quotientRecords.count
                )
            )
            let packedCoefficients = try packQuotientCoefficients(
                sourceIndices.map { quotientRecords[$0] }
            )
            let polynomial = try CircleCodewordPolynomial(xCoefficients: packedCoefficients)
            let polynomialClaim = try CirclePCSFRIPolynomialClaimV1.make(
                domain: domain,
                polynomial: polynomial,
                storageIndices: claimedStorageIndices
            )
            chunks.append(try AIRQuotientCirclePCSChunkV1(
                chunkIndex: chunks.count,
                sourceQuotientIndices: sourceIndices,
                polynomial: polynomial,
                polynomialClaim: polynomialClaim
            ))
            firstQuotientIndex += m31QuotientsPerQM31Polynomial
        }
        return try AIRQuotientCirclePCSWitnessV1(
            domain: domain,
            quotientProofDigest: AIRPublicQuotientProofDigestV1.digest(quotientProof),
            quotientPolynomialCount: quotientProof.quotientPolynomials.count,
            claimedStorageIndices: claimedStorageIndices,
            chunks: chunks
        )
    }

    private static func normalizedStorageIndices(
        _ storageIndices: [Int],
        domain: CircleDomainDescriptor
    ) throws -> [Int] {
        guard !storageIndices.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        let sorted = storageIndices.sorted()
        var previous: Int?
        for storageIndex in sorted {
            guard storageIndex >= 0,
                  storageIndex < domain.size,
                  previous.map({ $0 < storageIndex }) ?? true else {
                throw AppleZKProverError.invalidInputLayout
            }
            previous = storageIndex
        }
        return sorted
    }

    private static func packQuotientCoefficients(
        _ quotientRecords: [AIRConstraintQuotientPolynomialV1]
    ) throws -> [QM31Element] {
        guard !quotientRecords.isEmpty,
              quotientRecords.count <= m31QuotientsPerQM31Polynomial else {
            throw AppleZKProverError.invalidInputLayout
        }
        let maxCoefficientCount = quotientRecords
            .map(\.quotientCoefficients.count)
            .max() ?? 0
        guard maxCoefficientCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var coefficients: [QM31Element] = []
        coefficients.reserveCapacity(maxCoefficientCount)
        for coefficientIndex in 0..<maxCoefficientCount {
            var limbs = Array(repeating: UInt32(0), count: m31QuotientsPerQM31Polynomial)
            for quotientIndex in quotientRecords.indices {
                let quotientCoefficients = quotientRecords[quotientIndex].quotientCoefficients
                if coefficientIndex < quotientCoefficients.count {
                    limbs[quotientIndex] = quotientCoefficients[coefficientIndex]
                }
            }
            coefficients.append(QM31Element(a: limbs[0], b: limbs[1], c: limbs[2], d: limbs[3]))
        }
        return coefficients
    }
}

public struct AIRQuotientCirclePCSProofChunkV1: Equatable, Sendable {
    public let chunkIndex: Int
    public let sourceQuotientIndices: [Int]
    public let statement: CirclePCSFRIStatementV1
    public let proof: CirclePCSFRIProofV1

    public init(
        chunkIndex: Int,
        sourceQuotientIndices: [Int],
        statement: CirclePCSFRIStatementV1,
        proof: CirclePCSFRIProofV1
    ) throws {
        guard chunkIndex >= 0,
              !sourceQuotientIndices.isEmpty,
              statement.polynomialClaim.domain == proof.domain,
              statement.parameterSet.securityParameters == proof.securityParameters,
              try statement.publicInputs().publicInputDigest == proof.publicInputDigest else {
            throw AppleZKProverError.invalidInputLayout
        }
        for pair in zip(sourceQuotientIndices, sourceQuotientIndices.dropFirst()) {
            guard pair.0 < pair.1 else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        self.chunkIndex = chunkIndex
        self.sourceQuotientIndices = sourceQuotientIndices
        self.statement = statement
        self.proof = proof
    }
}

public struct AIRQuotientCirclePCSProofBundleV1: Equatable, Sendable {
    public let witness: AIRQuotientCirclePCSWitnessV1
    public let parameterSet: CirclePCSFRIParameterSetV1
    public let chunks: [AIRQuotientCirclePCSProofChunkV1]

    public init(
        witness: AIRQuotientCirclePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1,
        chunks: [AIRQuotientCirclePCSProofChunkV1]
    ) throws {
        try parameterSet.validateDomain(witness.domain)
        guard !chunks.isEmpty,
              chunks.count == witness.chunks.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        for index in chunks.indices {
            let proofChunk = chunks[index]
            let witnessChunk = witness.chunks[index]
            guard proofChunk.chunkIndex == index,
                  proofChunk.sourceQuotientIndices == witnessChunk.sourceQuotientIndices,
                  proofChunk.statement.parameterSet == parameterSet,
                  proofChunk.statement.polynomialClaim == witnessChunk.polynomialClaim,
                  proofChunk.proof.domain == witness.domain else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        self.witness = witness
        self.parameterSet = parameterSet
        self.chunks = chunks
    }
}

public enum AIRQuotientCirclePCSProofBundleBuilderV1 {
    public static func prove(
        quotientProof: AIRPublicQuotientProofV1,
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128,
        claimStorageIndices: [Int]? = nil
    ) throws -> AIRQuotientCirclePCSProofBundleV1 {
        let witness = try AIRPublicQuotientToCirclePCSWitnessV1.make(
            quotientProof: quotientProof,
            domain: domain,
            claimStorageIndices: claimStorageIndices
        )
        return try prove(witness: witness, parameterSet: parameterSet)
    }

    public static func prove(
        witness: AIRQuotientCirclePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128
    ) throws -> AIRQuotientCirclePCSProofBundleV1 {
        try parameterSet.validateDomain(witness.domain)
        var proofChunks: [AIRQuotientCirclePCSProofChunkV1] = []
        proofChunks.reserveCapacity(witness.chunks.count)
        for witnessChunk in witness.chunks {
            let statement = try CirclePCSFRIStatementV1(
                parameterSet: parameterSet,
                polynomialClaim: witnessChunk.polynomialClaim
            )
            let proof = try CirclePCSFRIContractProverV1.prove(statement: statement)
            proofChunks.append(try AIRQuotientCirclePCSProofChunkV1(
                chunkIndex: witnessChunk.chunkIndex,
                sourceQuotientIndices: witnessChunk.sourceQuotientIndices,
                statement: statement,
                proof: proof
            ))
        }
        let bundle = try AIRQuotientCirclePCSProofBundleV1(
            witness: witness,
            parameterSet: parameterSet,
            chunks: proofChunks
        )
        guard try AIRQuotientCirclePCSProofBundleVerifierV1.verify(bundle) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "AIR quotient Circle PCS proof bundle does not verify."
            )
        }
        return bundle
    }
}

public enum AIRQuotientCirclePCSProofBundleVerifierV1 {
    public static func verify(_ bundle: AIRQuotientCirclePCSProofBundleV1) throws -> Bool {
        for chunk in bundle.chunks {
            guard chunk.statement.parameterSet == bundle.parameterSet,
                  try CirclePCSFRIContractVerifierV1.verify(
                    proof: chunk.proof,
                    statement: chunk.statement
                  ) else {
                return false
            }
        }
        return true
    }

    public static func verify(
        _ bundle: AIRQuotientCirclePCSProofBundleV1,
        against quotientProof: AIRPublicQuotientProofV1
    ) throws -> Bool {
        let expectedWitness = try AIRPublicQuotientToCirclePCSWitnessV1.make(
            quotientProof: quotientProof,
            domain: bundle.witness.domain,
            claimStorageIndices: bundle.witness.claimedStorageIndices
        )
        guard expectedWitness == bundle.witness else {
            return false
        }
        return try verify(bundle)
    }

    public static func verify(
        encodedBundle: Data,
        against quotientProof: AIRPublicQuotientProofV1
    ) throws -> Bool {
        try verify(
            AIRQuotientCirclePCSProofBundleCodecV1.decode(encodedBundle),
            against: quotientProof
        )
    }
}

public enum AIRQuotientCirclePCSProofBundleDigestV1 {
    private static let domain = Data("AppleZKProver.AIRQuotientCirclePCSProofBundle.V1".utf8)

    public static func digest(_ bundle: AIRQuotientCirclePCSProofBundleV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        try CanonicalBinary.appendLengthPrefixed(
            try AIRQuotientCirclePCSProofBundleCodecV1.encode(bundle),
            to: &data
        )
        return SHA3Oracle.sha3_256(data)
    }
}

public enum AIRRowDomainTracePCSVariantV1: UInt32, Sendable {
    case current = 0
    case nextShifted = 1
}

public struct AIRRowDomainTracePCSChunkV1: Equatable, Sendable {
    public let chunkIndex: Int
    public let sourceColumnIndices: [Int]
    public let polynomial: CircleCodewordPolynomial
    public let polynomialClaim: CirclePCSFRIPolynomialClaimV1

    public init(
        chunkIndex: Int,
        sourceColumnIndices: [Int],
        polynomial: CircleCodewordPolynomial,
        polynomialClaim: CirclePCSFRIPolynomialClaimV1
    ) throws {
        guard chunkIndex >= 0,
              !sourceColumnIndices.isEmpty,
              sourceColumnIndices.count <= AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial,
              sourceColumnIndices.allSatisfy({ $0 >= 0 }),
              polynomial.yCoefficients.isEmpty,
              polynomialClaim.polynomial == polynomial else {
            throw AppleZKProverError.invalidInputLayout
        }
        for pair in zip(sourceColumnIndices, sourceColumnIndices.dropFirst()) {
            guard pair.0 < pair.1 else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        for coefficient in polynomial.xCoefficients {
            let limbs = [
                coefficient.constant.real,
                coefficient.constant.imaginary,
                coefficient.uCoefficient.real,
                coefficient.uCoefficient.imaginary,
            ]
            for offset in sourceColumnIndices.count..<AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial {
                guard limbs[offset] == 0 else {
                    throw AppleZKProverError.invalidInputLayout
                }
            }
        }
        self.chunkIndex = chunkIndex
        self.sourceColumnIndices = sourceColumnIndices
        self.polynomial = polynomial
        self.polynomialClaim = polynomialClaim
    }
}

public struct AIRRowDomainTracePCSWitnessV1: Equatable, Sendable {
    public let domain: CircleDomainDescriptor
    public let variant: AIRRowDomainTracePCSVariantV1
    public let traceRowCount: Int
    public let traceColumnCount: Int
    public let sourceTracePolynomialDigest: Data
    public let claimedStorageIndices: [Int]
    public let chunks: [AIRRowDomainTracePCSChunkV1]

    public init(
        domain: CircleDomainDescriptor,
        variant: AIRRowDomainTracePCSVariantV1,
        traceRowCount: Int,
        traceColumnCount: Int,
        sourceTracePolynomialDigest: Data,
        claimedStorageIndices: [Int],
        chunks: [AIRRowDomainTracePCSChunkV1]
    ) throws {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed,
              traceRowCount > 0,
              traceColumnCount > 0,
              sourceTracePolynomialDigest.count == 32,
              !claimedStorageIndices.isEmpty,
              !chunks.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        var previousClaimedStorageIndex: Int?
        for storageIndex in claimedStorageIndices {
            guard storageIndex >= 0,
                  storageIndex < domain.size,
                  previousClaimedStorageIndex.map({ $0 < storageIndex }) ?? true else {
                throw AppleZKProverError.invalidInputLayout
            }
            previousClaimedStorageIndex = storageIndex
        }
        var expectedColumnIndex = 0
        for (index, chunk) in chunks.enumerated() {
            let nextExpectedColumnIndex = expectedColumnIndex.addingReportingOverflow(
                chunk.sourceColumnIndices.count
            )
            guard !nextExpectedColumnIndex.overflow,
                  nextExpectedColumnIndex.partialValue <= traceColumnCount else {
                throw AppleZKProverError.invalidInputLayout
            }
            let expectedSourceIndices = Array(
                expectedColumnIndex..<nextExpectedColumnIndex.partialValue
            )
            guard chunk.chunkIndex == index,
                  chunk.sourceColumnIndices == expectedSourceIndices,
                  chunk.polynomialClaim.domain == domain else {
                throw AppleZKProverError.invalidInputLayout
            }
            let chunkClaimIndices = try chunk.polynomialClaim.evaluationClaims.map { claim -> Int in
                guard claim.storageIndex <= UInt64(Int.max) else {
                    throw AppleZKProverError.invalidInputLayout
                }
                return Int(claim.storageIndex)
            }
            guard chunkClaimIndices == claimedStorageIndices else {
                throw AppleZKProverError.invalidInputLayout
            }
            expectedColumnIndex = nextExpectedColumnIndex.partialValue
        }
        guard expectedColumnIndex == traceColumnCount else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.domain = domain
        self.variant = variant
        self.traceRowCount = traceRowCount
        self.traceColumnCount = traceColumnCount
        self.sourceTracePolynomialDigest = sourceTracePolynomialDigest
        self.claimedStorageIndices = claimedStorageIndices
        self.chunks = chunks
    }
}

public enum AIRRowDomainTraceToCirclePCSWitnessV1 {
    public static func make(
        trace: AIRExecutionTraceV1,
        variant: AIRRowDomainTracePCSVariantV1,
        domain: CircleDomainDescriptor,
        claimStorageIndices: [Int]? = nil
    ) throws -> AIRRowDomainTracePCSWitnessV1 {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed else {
            throw AppleZKProverError.invalidInputLayout
        }
        let claimedStorageIndices = try normalizedStorageIndices(
            claimStorageIndices ?? [0],
            domain: domain
        )
        let tracePolynomials = try AIRPublicQuotientOracleV1.traceColumnPolynomials(trace)
        let committedPolynomials: [[UInt32]]
        switch variant {
        case .current:
            committedPolynomials = tracePolynomials
        case .nextShifted:
            committedPolynomials = try tracePolynomials.map {
                try M31PolynomialV1.shiftByOne($0)
            }
        }
        let tracePolynomialDigest = try AIRTracePolynomialDigestV1.digest(tracePolynomials)
        var chunks: [AIRRowDomainTracePCSChunkV1] = []
        chunks.reserveCapacity(
            (trace.columnCount + AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial - 1) /
                AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial
        )
        var firstColumn = 0
        while firstColumn < trace.columnCount {
            let sourceColumnIndices = Array(
                firstColumn..<min(
                    firstColumn + AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial,
                    trace.columnCount
                )
            )
            let xCoefficients = try packM31Polynomials(
                sourceColumnIndices.map { committedPolynomials[$0] }
            )
            let polynomial = try CircleCodewordPolynomial(xCoefficients: xCoefficients)
            let polynomialClaim = try CirclePCSFRIPolynomialClaimV1.make(
                domain: domain,
                polynomial: polynomial,
                storageIndices: claimedStorageIndices
            )
            chunks.append(try AIRRowDomainTracePCSChunkV1(
                chunkIndex: chunks.count,
                sourceColumnIndices: sourceColumnIndices,
                polynomial: polynomial,
                polynomialClaim: polynomialClaim
            ))
            firstColumn += AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial
        }
        return try AIRRowDomainTracePCSWitnessV1(
            domain: domain,
            variant: variant,
            traceRowCount: trace.rowCount,
            traceColumnCount: trace.columnCount,
            sourceTracePolynomialDigest: tracePolynomialDigest,
            claimedStorageIndices: claimedStorageIndices,
            chunks: chunks
        )
    }

    fileprivate static func m31Polynomials(from witness: AIRRowDomainTracePCSWitnessV1) throws -> [[UInt32]] {
        var polynomials = Array(
            repeating: [UInt32](),
            count: witness.traceColumnCount
        )
        for chunk in witness.chunks {
            for (offset, column) in chunk.sourceColumnIndices.enumerated() {
                guard column >= 0,
                      column < polynomials.count else {
                    throw AppleZKProverError.invalidInputLayout
                }
                polynomials[column] = M31PolynomialV1.normalize(
                    chunk.polynomial.xCoefficients.map {
                        limbs(from: $0)[offset]
                    }
                )
            }
            guard chunk.polynomial.yCoefficients.isEmpty else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        guard polynomials.allSatisfy({ !$0.isEmpty }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        return polynomials
    }

    private static func normalizedStorageIndices(
        _ storageIndices: [Int],
        domain: CircleDomainDescriptor
    ) throws -> [Int] {
        guard !storageIndices.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        let sorted = storageIndices.sorted()
        var previous: Int?
        for storageIndex in sorted {
            guard storageIndex >= 0,
                  storageIndex < domain.size,
                  previous.map({ $0 < storageIndex }) ?? true else {
                throw AppleZKProverError.invalidInputLayout
            }
            previous = storageIndex
        }
        return sorted
    }

    private static func packM31Polynomials(_ polynomials: [[UInt32]]) throws -> [QM31Element] {
        guard !polynomials.isEmpty,
              polynomials.count <= AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial else {
            throw AppleZKProverError.invalidInputLayout
        }
        let normalized = polynomials.map { M31PolynomialV1.normalize($0) }
        for polynomial in normalized {
            try M31Field.validateCanonical(polynomial)
        }
        let maxCoefficientCount = normalized.map(\.count).max() ?? 0
        guard maxCoefficientCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var coefficients: [QM31Element] = []
        coefficients.reserveCapacity(maxCoefficientCount)
        for coefficientIndex in 0..<maxCoefficientCount {
            var limbs = Array(
                repeating: UInt32(0),
                count: AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial
            )
            for polynomialIndex in normalized.indices {
                if coefficientIndex < normalized[polynomialIndex].count {
                    limbs[polynomialIndex] = normalized[polynomialIndex][coefficientIndex]
                }
            }
            coefficients.append(QM31Element(
                a: limbs[0],
                b: limbs[1],
                c: limbs[2],
                d: limbs[3]
            ))
        }
        return coefficients
    }

    private static func limbs(from value: QM31Element) -> [UInt32] {
        [
            value.constant.real,
            value.constant.imaginary,
            value.uCoefficient.real,
            value.uCoefficient.imaginary,
        ]
    }
}

public struct AIRRowDomainTracePCSProofChunkV1: Equatable, Sendable {
    public let chunkIndex: Int
    public let sourceColumnIndices: [Int]
    public let statement: CirclePCSFRIStatementV1
    public let proof: CirclePCSFRIProofV1

    public init(
        chunkIndex: Int,
        sourceColumnIndices: [Int],
        statement: CirclePCSFRIStatementV1,
        proof: CirclePCSFRIProofV1
    ) throws {
        guard chunkIndex >= 0,
              !sourceColumnIndices.isEmpty,
              statement.polynomialClaim.domain == proof.domain,
              statement.parameterSet.securityParameters == proof.securityParameters,
              try statement.publicInputs().publicInputDigest == proof.publicInputDigest else {
            throw AppleZKProverError.invalidInputLayout
        }
        for pair in zip(sourceColumnIndices, sourceColumnIndices.dropFirst()) {
            guard pair.0 < pair.1 else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        self.chunkIndex = chunkIndex
        self.sourceColumnIndices = sourceColumnIndices
        self.statement = statement
        self.proof = proof
    }
}

public struct AIRRowDomainTracePCSProofBundleV1: Equatable, Sendable {
    public let witness: AIRRowDomainTracePCSWitnessV1
    public let parameterSet: CirclePCSFRIParameterSetV1
    public let chunks: [AIRRowDomainTracePCSProofChunkV1]

    public init(
        witness: AIRRowDomainTracePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1,
        chunks: [AIRRowDomainTracePCSProofChunkV1]
    ) throws {
        try parameterSet.validateDomain(witness.domain)
        guard !chunks.isEmpty,
              chunks.count == witness.chunks.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        for index in chunks.indices {
            let proofChunk = chunks[index]
            let witnessChunk = witness.chunks[index]
            guard proofChunk.chunkIndex == index,
                  proofChunk.sourceColumnIndices == witnessChunk.sourceColumnIndices,
                  proofChunk.statement.parameterSet == parameterSet,
                  proofChunk.statement.polynomialClaim == witnessChunk.polynomialClaim,
                  proofChunk.proof.domain == witness.domain else {
                throw AppleZKProverError.invalidInputLayout
            }
        }
        self.witness = witness
        self.parameterSet = parameterSet
        self.chunks = chunks
    }
}

public enum AIRRowDomainTracePCSProofBundleBuilderV1 {
    public static func prove(
        trace: AIRExecutionTraceV1,
        variant: AIRRowDomainTracePCSVariantV1,
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128,
        claimStorageIndices: [Int]? = nil
    ) throws -> AIRRowDomainTracePCSProofBundleV1 {
        let witness = try AIRRowDomainTraceToCirclePCSWitnessV1.make(
            trace: trace,
            variant: variant,
            domain: domain,
            claimStorageIndices: claimStorageIndices
        )
        return try prove(witness: witness, parameterSet: parameterSet)
    }

    public static func prove(
        witness: AIRRowDomainTracePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128
    ) throws -> AIRRowDomainTracePCSProofBundleV1 {
        try parameterSet.validateDomain(witness.domain)
        var proofChunks: [AIRRowDomainTracePCSProofChunkV1] = []
        proofChunks.reserveCapacity(witness.chunks.count)
        for witnessChunk in witness.chunks {
            let statement = try CirclePCSFRIStatementV1(
                parameterSet: parameterSet,
                polynomialClaim: witnessChunk.polynomialClaim
            )
            let proof = try CirclePCSFRIContractProverV1.prove(statement: statement)
            proofChunks.append(try AIRRowDomainTracePCSProofChunkV1(
                chunkIndex: witnessChunk.chunkIndex,
                sourceColumnIndices: witnessChunk.sourceColumnIndices,
                statement: statement,
                proof: proof
            ))
        }
        let bundle = try AIRRowDomainTracePCSProofBundleV1(
            witness: witness,
            parameterSet: parameterSet,
            chunks: proofChunks
        )
        guard try AIRRowDomainTracePCSProofBundleVerifierV1.verify(bundle) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "AIR row-domain trace Circle PCS proof bundle does not verify."
            )
        }
        return bundle
    }
}

public enum AIRRowDomainTracePCSProofBundleVerifierV1 {
    public static func verify(_ bundle: AIRRowDomainTracePCSProofBundleV1) throws -> Bool {
        for chunk in bundle.chunks {
            guard chunk.statement.parameterSet == bundle.parameterSet,
                  try CirclePCSFRIContractVerifierV1.verify(
                    proof: chunk.proof,
                    statement: chunk.statement
                  ) else {
                return false
            }
        }
        return true
    }

    public static func verifyCurrentTraceDigest(
        _ bundle: AIRRowDomainTracePCSProofBundleV1,
        against quotientProof: AIRPublicQuotientProofV1
    ) throws -> Bool {
        guard bundle.witness.variant == .current,
              bundle.witness.traceRowCount == quotientProof.traceRowCount,
              bundle.witness.traceColumnCount == quotientProof.traceColumnCount,
              bundle.witness.sourceTracePolynomialDigest == quotientProof.tracePolynomialDigest else {
            return false
        }
        let polynomials = try AIRRowDomainTraceToCirclePCSWitnessV1.m31Polynomials(
            from: bundle.witness
        )
        return try AIRTracePolynomialDigestV1.digest(polynomials) == quotientProof.tracePolynomialDigest
    }

    public static func verifyNextShiftedTrace(
        _ nextBundle: AIRRowDomainTracePCSProofBundleV1,
        againstCurrent currentBundle: AIRRowDomainTracePCSProofBundleV1
    ) throws -> Bool {
        guard currentBundle.witness.variant == .current,
              nextBundle.witness.variant == .nextShifted,
              currentBundle.witness.domain == nextBundle.witness.domain,
              currentBundle.witness.traceRowCount == nextBundle.witness.traceRowCount,
              currentBundle.witness.traceColumnCount == nextBundle.witness.traceColumnCount,
              currentBundle.witness.sourceTracePolynomialDigest == nextBundle.witness.sourceTracePolynomialDigest,
              currentBundle.parameterSet == nextBundle.parameterSet else {
            return false
        }
        let currentPolynomials = try AIRRowDomainTraceToCirclePCSWitnessV1.m31Polynomials(
            from: currentBundle.witness
        )
        let nextPolynomials = try AIRRowDomainTraceToCirclePCSWitnessV1.m31Polynomials(
            from: nextBundle.witness
        )
        let expectedNext = try currentPolynomials.map {
            try M31PolynomialV1.shiftByOne($0)
        }
        return nextPolynomials == expectedNext
    }
}

public struct AIRQuotientIdentityOpeningQueryPlanV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let traceRowCount: Int
    public let traceColumnCount: Int
    public let quotientPolynomialCount: Int
    public let queryCount: Int
    public let airDefinitionDigest: Data
    public let quotientProofDigest: Data
    public let commitmentDigest: Data
    public let claimedStorageIndices: [Int]

    public init(
        version: UInt32 = Self.currentVersion,
        traceRowCount: Int,
        traceColumnCount: Int,
        quotientPolynomialCount: Int,
        queryCount: Int,
        airDefinitionDigest: Data,
        quotientProofDigest: Data,
        commitmentDigest: Data,
        claimedStorageIndices: [Int]
    ) throws {
        guard version == Self.currentVersion,
              traceRowCount > 0,
              traceColumnCount > 0,
              quotientPolynomialCount > 0,
              queryCount > 0,
              queryCount == claimedStorageIndices.count,
              airDefinitionDigest.count == 32,
              quotientProofDigest.count == 32,
              commitmentDigest.count == 32,
              !claimedStorageIndices.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        var previous: Int?
        for storageIndex in claimedStorageIndices {
            guard storageIndex >= 0,
                  previous.map({ $0 < storageIndex }) ?? true else {
                throw AppleZKProverError.invalidInputLayout
            }
            previous = storageIndex
        }
        self.version = version
        self.traceRowCount = traceRowCount
        self.traceColumnCount = traceColumnCount
        self.quotientPolynomialCount = quotientPolynomialCount
        self.queryCount = queryCount
        self.airDefinitionDigest = airDefinitionDigest
        self.quotientProofDigest = quotientProofDigest
        self.commitmentDigest = commitmentDigest
        self.claimedStorageIndices = claimedStorageIndices
    }
}

public enum AIRQuotientIdentityOpeningQueryPlannerV1 {
    private static let transcriptDomain = Data("AppleZKProver.AIRQuotientIdentityOpeningQueryPlan.V1".utf8)
    private static let commitmentDigestDomain = Data("AppleZKProver.AIRQuotientIdentityCommitments.V1".utf8)

    public static func make(
        definition: AIRDefinitionV1,
        quotientProof: AIRPublicQuotientProofV1,
        currentTraceWitness: AIRRowDomainTracePCSWitnessV1,
        nextTraceWitness: AIRRowDomainTracePCSWitnessV1,
        quotientWitness: AIRQuotientCirclePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1,
        queryCount: Int
    ) throws -> AIRQuotientIdentityOpeningQueryPlanV1 {
        let currentRoots = try initialCommitmentRoots(witness: currentTraceWitness)
        let nextRoots = try initialCommitmentRoots(witness: nextTraceWitness)
        let quotientRoots = try initialCommitmentRoots(witness: quotientWitness)
        return try make(
            definition: definition,
            quotientProof: quotientProof,
            currentTraceWitness: currentTraceWitness,
            nextTraceWitness: nextTraceWitness,
            quotientWitness: quotientWitness,
            parameterSet: parameterSet,
            currentTraceRoots: currentRoots,
            nextTraceRoots: nextRoots,
            quotientRoots: quotientRoots,
            queryCount: queryCount
        )
    }

    public static func make(
        definition: AIRDefinitionV1,
        quotientProof: AIRPublicQuotientProofV1,
        currentTraceBundle: AIRRowDomainTracePCSProofBundleV1,
        nextTraceBundle: AIRRowDomainTracePCSProofBundleV1,
        quotientBundle: AIRQuotientCirclePCSProofBundleV1,
        queryCount: Int
    ) throws -> AIRQuotientIdentityOpeningQueryPlanV1 {
        try make(
            definition: definition,
            quotientProof: quotientProof,
            currentTraceWitness: currentTraceBundle.witness,
            nextTraceWitness: nextTraceBundle.witness,
            quotientWitness: quotientBundle.witness,
            parameterSet: currentTraceBundle.parameterSet,
            currentTraceRoots: initialCommitmentRoots(bundle: currentTraceBundle),
            nextTraceRoots: initialCommitmentRoots(bundle: nextTraceBundle),
            quotientRoots: initialCommitmentRoots(bundle: quotientBundle),
            queryCount: queryCount
        )
    }

    private static func make(
        definition: AIRDefinitionV1,
        quotientProof: AIRPublicQuotientProofV1,
        currentTraceWitness: AIRRowDomainTracePCSWitnessV1,
        nextTraceWitness: AIRRowDomainTracePCSWitnessV1,
        quotientWitness: AIRQuotientCirclePCSWitnessV1,
        parameterSet: CirclePCSFRIParameterSetV1,
        currentTraceRoots: [Data],
        nextTraceRoots: [Data],
        quotientRoots: [Data],
        queryCount: Int
    ) throws -> AIRQuotientIdentityOpeningQueryPlanV1 {
        guard queryCount > 0,
              currentTraceWitness.variant == .current,
              nextTraceWitness.variant == .nextShifted,
              currentTraceWitness.domain == nextTraceWitness.domain,
              currentTraceWitness.domain == quotientWitness.domain,
              currentTraceWitness.traceRowCount == quotientProof.traceRowCount,
              currentTraceWitness.traceColumnCount == quotientProof.traceColumnCount,
              nextTraceWitness.traceRowCount == quotientProof.traceRowCount,
              nextTraceWitness.traceColumnCount == quotientProof.traceColumnCount,
              quotientWitness.quotientPolynomialCount == quotientProof.quotientPolynomials.count,
              currentTraceWitness.sourceTracePolynomialDigest == quotientProof.tracePolynomialDigest,
              nextTraceWitness.sourceTracePolynomialDigest == quotientProof.tracePolynomialDigest,
              quotientWitness.quotientProofDigest == (try AIRPublicQuotientProofDigestV1.digest(quotientProof)),
              definition.columnCount == quotientProof.traceColumnCount,
              currentTraceRoots.count == currentTraceWitness.chunks.count,
              nextTraceRoots.count == nextTraceWitness.chunks.count,
              quotientRoots.count == quotientWitness.chunks.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        try parameterSet.validateDomain(currentTraceWitness.domain)
        let commitmentDigest = try commitmentDigest(
            domain: currentTraceWitness.domain,
            parameterSet: parameterSet,
            currentTraceWitness: currentTraceWitness,
            nextTraceWitness: nextTraceWitness,
            quotientWitness: quotientWitness,
            currentTraceRoots: currentTraceRoots,
            nextTraceRoots: nextTraceRoots,
            quotientRoots: quotientRoots
        )
        let storageIndices = try drawUniqueStorageIndices(
            definition: definition,
            quotientProof: quotientProof,
            domain: currentTraceWitness.domain,
            parameterSet: parameterSet,
            commitmentDigest: commitmentDigest,
            queryCount: queryCount
        )
        return try AIRQuotientIdentityOpeningQueryPlanV1(
            traceRowCount: quotientProof.traceRowCount,
            traceColumnCount: quotientProof.traceColumnCount,
            quotientPolynomialCount: quotientProof.quotientPolynomials.count,
            queryCount: queryCount,
            airDefinitionDigest: AIRDefinitionDigestV1.digest(definition),
            quotientProofDigest: AIRPublicQuotientProofDigestV1.digest(quotientProof),
            commitmentDigest: commitmentDigest,
            claimedStorageIndices: storageIndices
        )
    }

    private static func drawUniqueStorageIndices(
        definition: AIRDefinitionV1,
        quotientProof: AIRPublicQuotientProofV1,
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1,
        commitmentDigest: Data,
        queryCount: Int
    ) throws -> [Int] {
        guard domain.size <= Int(UInt32.max),
              queryCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let eligible = try eligibleStorageIndices(
            domain: domain,
            traceRowCount: quotientProof.traceRowCount
        )
        guard queryCount <= eligible.count else {
            throw AppleZKProverError.invalidInputLayout
        }
        let eligibleSet = Set(eligible)
        var transcript = SHA3Oracle.TranscriptState()
        var header = Data()
        CanonicalBinary.appendUInt32(UInt32(transcriptDomain.count), to: &header)
        header.append(transcriptDomain)
        CanonicalBinary.appendUInt32(AIRQuotientIdentityOpeningQueryPlanV1.currentVersion, to: &header)
        CanonicalBinary.appendUInt64(UInt64(quotientProof.traceRowCount), to: &header)
        CanonicalBinary.appendUInt64(UInt64(quotientProof.traceColumnCount), to: &header)
        CanonicalBinary.appendUInt64(UInt64(quotientProof.quotientPolynomials.count), to: &header)
        CanonicalBinary.appendUInt64(UInt64(queryCount), to: &header)
        try CanonicalBinary.appendLengthPrefixed(
            try CircleDomainDescriptorCodecV1.encode(domain),
            to: &header
        )
        appendParameterSet(parameterSet, to: &header)
        try transcript.absorb(header)
        try transcript.absorb(AIRDefinitionDigestV1.digest(definition))
        try transcript.absorb(AIRPublicQuotientProofDigestV1.digest(quotientProof))
        try transcript.absorb(commitmentDigest)

        var selected = Set<Int>()
        var attempt: UInt32 = 0
        while selected.count < queryCount {
            var attemptTranscript = transcript
            var frame = Data()
            CanonicalBinary.appendUInt32(attempt, to: &frame)
            CanonicalBinary.appendUInt64(UInt64(queryCount - selected.count), to: &frame)
            try attemptTranscript.absorb(frame)
            let words = try attemptTranscript.squeezeUInt32(
                count: max(4, (queryCount - selected.count) * 2),
                modulus: UInt32(domain.size)
            )
            for word in words {
                let storageIndex = Int(word)
                if eligibleSet.contains(storageIndex) {
                    selected.insert(storageIndex)
                }
                if selected.count == queryCount {
                    break
                }
            }
            attempt = attempt.addingReportingOverflow(1).partialValue
        }
        return selected.sorted()
    }

    private static func eligibleStorageIndices(
        domain: CircleDomainDescriptor,
        traceRowCount: Int
    ) throws -> [Int] {
        guard UInt64(traceRowCount) < UInt64(M31Field.modulus) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let firstForbidden = UInt32(traceRowCount)
        var indices: [Int] = []
        indices.reserveCapacity(domain.size)
        for storageIndex in 0..<domain.size {
            let naturalIndex = try CircleDomainOracle.naturalDomainIndex(
                forStorageIndex: storageIndex,
                descriptor: domain
            )
            let point = try CircleDomainOracle.point(
                in: domain,
                naturalDomainIndex: naturalIndex
            )
            if point.x >= firstForbidden {
                indices.append(storageIndex)
            }
        }
        return indices
    }

    private static func commitmentDigest(
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1,
        currentTraceWitness: AIRRowDomainTracePCSWitnessV1,
        nextTraceWitness: AIRRowDomainTracePCSWitnessV1,
        quotientWitness: AIRQuotientCirclePCSWitnessV1,
        currentTraceRoots: [Data],
        nextTraceRoots: [Data],
        quotientRoots: [Data]
    ) throws -> Data {
        guard (currentTraceRoots + nextTraceRoots + quotientRoots).allSatisfy({ $0.count == 32 }) else {
            throw AppleZKProverError.invalidInputLayout
        }
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(commitmentDigestDomain.count), to: &data)
        data.append(commitmentDigestDomain)
        CanonicalBinary.appendUInt32(AIRQuotientIdentityOpeningQueryPlanV1.currentVersion, to: &data)
        try CanonicalBinary.appendLengthPrefixed(
            try CircleDomainDescriptorCodecV1.encode(domain),
            to: &data
        )
        appendParameterSet(parameterSet, to: &data)
        CanonicalBinary.appendUInt64(UInt64(currentTraceWitness.traceRowCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(currentTraceWitness.traceColumnCount), to: &data)
        data.append(currentTraceWitness.sourceTracePolynomialDigest)
        appendTraceRoots(
            currentTraceRoots,
            witness: currentTraceWitness,
            to: &data
        )
        appendTraceRoots(
            nextTraceRoots,
            witness: nextTraceWitness,
            to: &data
        )
        CanonicalBinary.appendUInt64(UInt64(quotientWitness.quotientPolynomialCount), to: &data)
        data.append(quotientWitness.quotientProofDigest)
        appendQuotientRoots(
            quotientRoots,
            witness: quotientWitness,
            to: &data
        )
        return SHA3Oracle.sha3_256(data)
    }

    private static func appendTraceRoots(
        _ roots: [Data],
        witness: AIRRowDomainTracePCSWitnessV1,
        to data: inout Data
    ) {
        CanonicalBinary.appendUInt32(witness.variant.rawValue, to: &data)
        CanonicalBinary.appendUInt64(UInt64(witness.chunks.count), to: &data)
        for (index, chunk) in witness.chunks.enumerated() {
            CanonicalBinary.appendUInt64(UInt64(chunk.chunkIndex), to: &data)
            CanonicalBinary.appendUInt64(UInt64(chunk.sourceColumnIndices.count), to: &data)
            for column in chunk.sourceColumnIndices {
                CanonicalBinary.appendUInt64(UInt64(column), to: &data)
            }
            data.append(roots[index])
        }
    }

    private static func appendQuotientRoots(
        _ roots: [Data],
        witness: AIRQuotientCirclePCSWitnessV1,
        to data: inout Data
    ) {
        CanonicalBinary.appendUInt64(UInt64(witness.chunks.count), to: &data)
        for (index, chunk) in witness.chunks.enumerated() {
            CanonicalBinary.appendUInt64(UInt64(chunk.chunkIndex), to: &data)
            CanonicalBinary.appendUInt64(UInt64(chunk.sourceQuotientIndices.count), to: &data)
            for quotientIndex in chunk.sourceQuotientIndices {
                CanonicalBinary.appendUInt64(UInt64(quotientIndex), to: &data)
            }
            data.append(roots[index])
        }
    }

    private static func initialCommitmentRoots(
        witness: AIRRowDomainTracePCSWitnessV1
    ) throws -> [Data] {
        try witness.chunks.map { chunk in
            try initialCommitmentRoot(
                polynomial: chunk.polynomial,
                domain: witness.domain
            )
        }
    }

    private static func initialCommitmentRoots(
        witness: AIRQuotientCirclePCSWitnessV1
    ) throws -> [Data] {
        try witness.chunks.map { chunk in
            try initialCommitmentRoot(
                polynomial: chunk.polynomial,
                domain: witness.domain
            )
        }
    }

    private static func initialCommitmentRoots(
        bundle: AIRRowDomainTracePCSProofBundleV1
    ) throws -> [Data] {
        try bundle.chunks.map { chunk in
            guard let root = chunk.proof.commitments.first,
                  root.count == 32 else {
                throw AppleZKProverError.invalidInputLayout
            }
            return root
        }
    }

    private static func initialCommitmentRoots(
        bundle: AIRQuotientCirclePCSProofBundleV1
    ) throws -> [Data] {
        try bundle.chunks.map { chunk in
            guard let root = chunk.proof.commitments.first,
                  root.count == 32 else {
                throw AppleZKProverError.invalidInputLayout
            }
            return root
        }
    }

    private static func initialCommitmentRoot(
        polynomial: CircleCodewordPolynomial,
        domain: CircleDomainDescriptor
    ) throws -> Data {
        let evaluations = try CircleCodewordOracle.evaluate(
            polynomial: polynomial,
            domain: domain
        )
        return try MerkleOracle.rootSHA3_256(
            rawLeaves: QM31CanonicalEncoding.pack(evaluations),
            leafCount: evaluations.count,
            leafStride: QM31CanonicalEncoding.elementByteCount,
            leafLength: QM31CanonicalEncoding.elementByteCount
        )
    }

    private static func appendParameterSet(
        _ parameterSet: CirclePCSFRIParameterSetV1,
        to data: inout Data
    ) {
        CanonicalBinary.appendUInt32(UInt32(parameterSet.profileID.rawValue.utf8.count), to: &data)
        data.append(Data(parameterSet.profileID.rawValue.utf8))
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.logBlowupFactor, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.queryCount, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.foldingStep, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.grindingBits, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.targetSoundnessBits, to: &data)
    }
}

public struct AIRSharedDomainQuotientIdentityPCSProofBundleV1: Equatable, Sendable {
    public let queryPlan: AIRQuotientIdentityOpeningQueryPlanV1
    public let currentTracePCSProofBundle: AIRRowDomainTracePCSProofBundleV1
    public let nextTracePCSProofBundle: AIRRowDomainTracePCSProofBundleV1
    public let quotientPCSProofBundle: AIRQuotientCirclePCSProofBundleV1

    public init(
        queryPlan: AIRQuotientIdentityOpeningQueryPlanV1,
        currentTracePCSProofBundle: AIRRowDomainTracePCSProofBundleV1,
        nextTracePCSProofBundle: AIRRowDomainTracePCSProofBundleV1,
        quotientPCSProofBundle: AIRQuotientCirclePCSProofBundleV1
    ) throws {
        guard currentTracePCSProofBundle.witness.domain == nextTracePCSProofBundle.witness.domain,
              currentTracePCSProofBundle.witness.domain == quotientPCSProofBundle.witness.domain,
              currentTracePCSProofBundle.parameterSet == nextTracePCSProofBundle.parameterSet,
              currentTracePCSProofBundle.parameterSet == quotientPCSProofBundle.parameterSet,
              currentTracePCSProofBundle.witness.claimedStorageIndices == queryPlan.claimedStorageIndices,
              nextTracePCSProofBundle.witness.claimedStorageIndices == queryPlan.claimedStorageIndices,
              quotientPCSProofBundle.witness.claimedStorageIndices == queryPlan.claimedStorageIndices else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.queryPlan = queryPlan
        self.currentTracePCSProofBundle = currentTracePCSProofBundle
        self.nextTracePCSProofBundle = nextTracePCSProofBundle
        self.quotientPCSProofBundle = quotientPCSProofBundle
    }
}

public enum AIRSharedDomainQuotientIdentityPCSProofBundleBuilderV1 {
    public static func prove(
        trace: AIRExecutionTraceV1,
        definition: AIRDefinitionV1,
        quotientProof: AIRPublicQuotientProofV1,
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128,
        queryCount: Int
    ) throws -> AIRSharedDomainQuotientIdentityPCSProofBundleV1 {
        let currentSeedWitness = try AIRRowDomainTraceToCirclePCSWitnessV1.make(
            trace: trace,
            variant: .current,
            domain: domain
        )
        let nextSeedWitness = try AIRRowDomainTraceToCirclePCSWitnessV1.make(
            trace: trace,
            variant: .nextShifted,
            domain: domain
        )
        let quotientSeedWitness = try AIRPublicQuotientToCirclePCSWitnessV1.make(
            quotientProof: quotientProof,
            domain: domain
        )
        let queryPlan = try AIRQuotientIdentityOpeningQueryPlannerV1.make(
            definition: definition,
            quotientProof: quotientProof,
            currentTraceWitness: currentSeedWitness,
            nextTraceWitness: nextSeedWitness,
            quotientWitness: quotientSeedWitness,
            parameterSet: parameterSet,
            queryCount: queryCount
        )
        let currentTraceBundle = try AIRRowDomainTracePCSProofBundleBuilderV1.prove(
            trace: trace,
            variant: .current,
            domain: domain,
            parameterSet: parameterSet,
            claimStorageIndices: queryPlan.claimedStorageIndices
        )
        let nextTraceBundle = try AIRRowDomainTracePCSProofBundleBuilderV1.prove(
            trace: trace,
            variant: .nextShifted,
            domain: domain,
            parameterSet: parameterSet,
            claimStorageIndices: queryPlan.claimedStorageIndices
        )
        let quotientBundle = try AIRQuotientCirclePCSProofBundleBuilderV1.prove(
            quotientProof: quotientProof,
            domain: domain,
            parameterSet: parameterSet,
            claimStorageIndices: queryPlan.claimedStorageIndices
        )
        return try assemble(
            queryPlan: queryPlan,
            currentTracePCSProofBundle: currentTraceBundle,
            nextTracePCSProofBundle: nextTraceBundle,
            quotientPCSProofBundle: quotientBundle,
            definition: definition,
            quotientProof: quotientProof
        )
    }

    public static func prove(
        proof: AIRProofV1,
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128,
        queryCount: Int
    ) throws -> AIRSharedDomainQuotientIdentityPCSProofBundleV1 {
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: proof.witness,
            for: proof.airDefinition
        )
        return try prove(
            trace: trace,
            definition: proof.airDefinition,
            quotientProof: proof.publicQuotientProof,
            domain: domain,
            parameterSet: parameterSet,
            queryCount: queryCount
        )
    }

    public static func assemble(
        queryPlan: AIRQuotientIdentityOpeningQueryPlanV1,
        currentTracePCSProofBundle: AIRRowDomainTracePCSProofBundleV1,
        nextTracePCSProofBundle: AIRRowDomainTracePCSProofBundleV1,
        quotientPCSProofBundle: AIRQuotientCirclePCSProofBundleV1,
        definition: AIRDefinitionV1,
        quotientProof: AIRPublicQuotientProofV1
    ) throws -> AIRSharedDomainQuotientIdentityPCSProofBundleV1 {
        let bundle = try AIRSharedDomainQuotientIdentityPCSProofBundleV1(
            queryPlan: queryPlan,
            currentTracePCSProofBundle: currentTracePCSProofBundle,
            nextTracePCSProofBundle: nextTracePCSProofBundle,
            quotientPCSProofBundle: quotientPCSProofBundle
        )
        guard try AIRSharedDomainQuotientIdentityPCSProofBundleVerifierV1
            .verificationReport(
                bundle,
                definition: definition,
                quotientProof: quotientProof
            )
            .provesAIRQuotientIdentity else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Shared-domain AIR quotient identity PCS proof bundle does not verify."
            )
        }
        return bundle
    }
}

public struct AIRSharedDomainQuotientIdentityVerificationReportV1: Equatable, Sendable {
    public let currentTracePCSBundleProofsVerify: Bool
    public let nextTracePCSBundleProofsVerify: Bool
    public let quotientPCSBundleProofsVerify: Bool
    public let currentTraceBundleMatchesQuotientTraceDigest: Bool
    public let nextTraceBundleMatchesShiftedTrace: Bool
    public let quotientPCSBundleMatchesQuotientProof: Bool
    public let queryPlanMatchesCommitments: Bool
    public let bundlesOpenExactlyQueryPoints: Bool
    public let domainsMatch: Bool
    public let parameterSetsMatch: Bool
    public let coordinateDomainsAlignedForAIRQuotientIdentity: Bool
    public let quotientIdentityChecked: Bool
    public let isZeroKnowledge: Bool

    public var verifiesPCSOpeningInputs: Bool {
        currentTracePCSBundleProofsVerify &&
            nextTracePCSBundleProofsVerify &&
            quotientPCSBundleProofsVerify &&
            currentTraceBundleMatchesQuotientTraceDigest &&
            nextTraceBundleMatchesShiftedTrace &&
            quotientPCSBundleMatchesQuotientProof &&
            queryPlanMatchesCommitments &&
            bundlesOpenExactlyQueryPoints &&
            domainsMatch &&
            parameterSetsMatch
    }

    public var provesAIRQuotientIdentity: Bool {
        verifiesPCSOpeningInputs &&
            coordinateDomainsAlignedForAIRQuotientIdentity &&
            quotientIdentityChecked
    }
}

public enum AIRSharedDomainQuotientIdentityPCSProofBundleVerifierV1 {
    public static func verificationReport(
        _ bundle: AIRSharedDomainQuotientIdentityPCSProofBundleV1,
        definition: AIRDefinitionV1,
        quotientProof: AIRPublicQuotientProofV1
    ) throws -> AIRSharedDomainQuotientIdentityVerificationReportV1 {
        let currentTraceProofsVerify = try AIRRowDomainTracePCSProofBundleVerifierV1.verify(
            bundle.currentTracePCSProofBundle
        )
        let nextTraceProofsVerify = try AIRRowDomainTracePCSProofBundleVerifierV1.verify(
            bundle.nextTracePCSProofBundle
        )
        let quotientProofsVerify = try AIRQuotientCirclePCSProofBundleVerifierV1.verify(
            bundle.quotientPCSProofBundle
        )
        let currentTraceMatches = try AIRRowDomainTracePCSProofBundleVerifierV1
            .verifyCurrentTraceDigest(
                bundle.currentTracePCSProofBundle,
                against: quotientProof
            )
        let nextTraceMatches = try AIRRowDomainTracePCSProofBundleVerifierV1
            .verifyNextShiftedTrace(
                bundle.nextTracePCSProofBundle,
                againstCurrent: bundle.currentTracePCSProofBundle
            )
        let quotientBundleMatches = try AIRQuotientCirclePCSProofBundleVerifierV1.verify(
            bundle.quotientPCSProofBundle,
            against: quotientProof
        )
        let expectedPlan = try AIRQuotientIdentityOpeningQueryPlannerV1.make(
            definition: definition,
            quotientProof: quotientProof,
            currentTraceBundle: bundle.currentTracePCSProofBundle,
            nextTraceBundle: bundle.nextTracePCSProofBundle,
            quotientBundle: bundle.quotientPCSProofBundle,
            queryCount: bundle.queryPlan.queryCount
        )
        let queryPlanMatches = expectedPlan == bundle.queryPlan
        let domainsMatch = bundle.currentTracePCSProofBundle.witness.domain ==
            bundle.nextTracePCSProofBundle.witness.domain &&
            bundle.currentTracePCSProofBundle.witness.domain ==
            bundle.quotientPCSProofBundle.witness.domain
        let parameterSetsMatch = bundle.currentTracePCSProofBundle.parameterSet ==
            bundle.nextTracePCSProofBundle.parameterSet &&
            bundle.currentTracePCSProofBundle.parameterSet ==
            bundle.quotientPCSProofBundle.parameterSet
        let bundlesOpenExactlyQueryPoints =
            bundle.currentTracePCSProofBundle.witness.claimedStorageIndices == bundle.queryPlan.claimedStorageIndices &&
            bundle.nextTracePCSProofBundle.witness.claimedStorageIndices == bundle.queryPlan.claimedStorageIndices &&
            bundle.quotientPCSProofBundle.witness.claimedStorageIndices == bundle.queryPlan.claimedStorageIndices
        let coordinateDomainsAligned = domainsMatch &&
            bundle.currentTracePCSProofBundle.witness.variant == .current &&
            bundle.nextTracePCSProofBundle.witness.variant == .nextShifted
        let identityChecked = coordinateDomainsAligned && bundlesOpenExactlyQueryPoints
            ? try quotientIdentityHolds(
                bundle: bundle,
                definition: definition,
                quotientProof: quotientProof
            )
            : false
        return AIRSharedDomainQuotientIdentityVerificationReportV1(
            currentTracePCSBundleProofsVerify: currentTraceProofsVerify,
            nextTracePCSBundleProofsVerify: nextTraceProofsVerify,
            quotientPCSBundleProofsVerify: quotientProofsVerify,
            currentTraceBundleMatchesQuotientTraceDigest: currentTraceMatches,
            nextTraceBundleMatchesShiftedTrace: nextTraceMatches,
            quotientPCSBundleMatchesQuotientProof: quotientBundleMatches,
            queryPlanMatchesCommitments: queryPlanMatches,
            bundlesOpenExactlyQueryPoints: bundlesOpenExactlyQueryPoints,
            domainsMatch: domainsMatch,
            parameterSetsMatch: parameterSetsMatch,
            coordinateDomainsAlignedForAIRQuotientIdentity: coordinateDomainsAligned,
            quotientIdentityChecked: identityChecked,
            isZeroKnowledge: false
        )
    }

    public static func verify(
        _ bundle: AIRSharedDomainQuotientIdentityPCSProofBundleV1,
        definition: AIRDefinitionV1,
        quotientProof: AIRPublicQuotientProofV1
    ) throws -> Bool {
        try verificationReport(
            bundle,
            definition: definition,
            quotientProof: quotientProof
        ).provesAIRQuotientIdentity
    }

    private static func quotientIdentityHolds(
        bundle: AIRSharedDomainQuotientIdentityPCSProofBundleV1,
        definition: AIRDefinitionV1,
        quotientProof: AIRPublicQuotientProofV1
    ) throws -> Bool {
        guard quotientProof.traceRowCount == bundle.currentTracePCSProofBundle.witness.traceRowCount,
              quotientProof.traceColumnCount == bundle.currentTracePCSProofBundle.witness.traceColumnCount,
              definition.columnCount == quotientProof.traceColumnCount,
              quotientProof.quotientPolynomials.count ==
                definition.transitionConstraints.count + definition.boundaryConstraints.count else {
            return false
        }
        let currentOpenings = try openedTraceValues(
            from: bundle.currentTracePCSProofBundle
        )
        let nextOpenings = try openedTraceValues(
            from: bundle.nextTracePCSProofBundle
        )
        let quotientOpenings = try openedQuotientValues(
            from: bundle.quotientPCSProofBundle
        )
        let expectedRecords = try expectedQuotientRecordLayout(
            definition: definition,
            quotientProof: quotientProof
        )
        guard expectedRecords else {
            return false
        }

        for storageIndex in bundle.queryPlan.claimedStorageIndices {
            guard let currentValues = currentOpenings[storageIndex],
                  let nextValues = nextOpenings[storageIndex],
                  let quotientValues = quotientOpenings[storageIndex] else {
                return false
            }
            let z = try rowDomainChallenge(
                storageIndex: storageIndex,
                domain: bundle.currentTracePCSProofBundle.witness.domain
            )
            let transitionVanishing = try transitionVanishingValue(
                z,
                traceRowCount: quotientProof.traceRowCount
            )
            var quotientIndex = 0
            for constraint in definition.transitionConstraints {
                let numerator = try evaluate(
                    constraint,
                    currentRow: currentValues,
                    nextRow: nextValues
                )
                let expected = M31Field.multiply(
                    transitionVanishing,
                    quotientValues[quotientIndex]
                )
                guard numerator == expected else {
                    return false
                }
                quotientIndex += 1
            }
            for boundaryIndex in definition.boundaryConstraints.indices {
                let constraint = definition.boundaryConstraints[boundaryIndex]
                let rowCoordinate = try rowCoordinate(constraint.rowIndex)
                let boundaryVanishing = M31Field.subtract(z, rowCoordinate)
                let numerator = try evaluate(
                    constraint.polynomial,
                    currentRow: currentValues,
                    nextRow: nil
                )
                let expected = M31Field.multiply(
                    boundaryVanishing,
                    quotientValues[quotientIndex]
                )
                guard numerator == expected else {
                    return false
                }
                quotientIndex += 1
            }
        }
        return true
    }

    private static func expectedQuotientRecordLayout(
        definition: AIRDefinitionV1,
        quotientProof: AIRPublicQuotientProofV1
    ) throws -> Bool {
        var quotientIndex = 0
        for constraintIndex in definition.transitionConstraints.indices {
            guard quotientIndex < quotientProof.quotientPolynomials.count else {
                return false
            }
            let record = quotientProof.quotientPolynomials[quotientIndex]
            guard record.kind == .transition,
                  record.constraintIndex == constraintIndex,
                  record.vanishingDegree == max(1, quotientProof.traceRowCount - 1) else {
                return false
            }
            quotientIndex += 1
        }
        for boundaryIndex in definition.boundaryConstraints.indices {
            guard quotientIndex < quotientProof.quotientPolynomials.count else {
                return false
            }
            let record = quotientProof.quotientPolynomials[quotientIndex]
            guard record.kind == .boundary,
                  record.constraintIndex == boundaryIndex,
                  record.vanishingDegree == 1 else {
                return false
            }
            quotientIndex += 1
        }
        return quotientIndex == quotientProof.quotientPolynomials.count
    }

    private static func openedTraceValues(
        from bundle: AIRRowDomainTracePCSProofBundleV1
    ) throws -> [Int: [UInt32]] {
        let witness = bundle.witness
        var rows = Dictionary(
            uniqueKeysWithValues: witness.claimedStorageIndices.map {
                ($0, Array<UInt32?>(repeating: nil, count: witness.traceColumnCount))
            }
        )
        for chunk in bundle.chunks {
            let claimStorageIndices = try chunk.statement.polynomialClaim.evaluationClaims.map { claim -> Int in
                guard claim.storageIndex <= UInt64(Int.max) else {
                    throw AppleZKProverError.invalidInputLayout
                }
                return Int(claim.storageIndex)
            }
            guard claimStorageIndices == witness.claimedStorageIndices else {
                throw AppleZKProverError.invalidInputLayout
            }
            for claim in chunk.statement.polynomialClaim.evaluationClaims {
                guard claim.storageIndex <= UInt64(Int.max) else {
                    throw AppleZKProverError.invalidInputLayout
                }
                let storageIndex = Int(claim.storageIndex)
                var values = rows[storageIndex] ?? Array<UInt32?>(
                    repeating: nil,
                    count: witness.traceColumnCount
                )
                let limbs = limbs(from: claim.value)
                for offset in chunk.sourceColumnIndices.count..<AIRTraceToCirclePCSWitnessV1.m31ColumnsPerQM31Polynomial {
                    guard limbs[offset] == 0 else {
                        throw AppleZKProverError.invalidInputLayout
                    }
                }
                for (offset, column) in chunk.sourceColumnIndices.enumerated() {
                    guard column >= 0,
                          column < values.count,
                          values[column] == nil else {
                        throw AppleZKProverError.invalidInputLayout
                    }
                    values[column] = limbs[offset]
                }
                rows[storageIndex] = values
            }
        }
        var opened: [Int: [UInt32]] = [:]
        for storageIndex in witness.claimedStorageIndices {
            guard let values = rows[storageIndex],
                  values.allSatisfy({ $0 != nil }) else {
                throw AppleZKProverError.invalidInputLayout
            }
            opened[storageIndex] = values.map { $0! }
        }
        return opened
    }

    private static func openedQuotientValues(
        from bundle: AIRQuotientCirclePCSProofBundleV1
    ) throws -> [Int: [UInt32]] {
        let witness = bundle.witness
        var rows = Dictionary(
            uniqueKeysWithValues: witness.claimedStorageIndices.map {
                ($0, Array<UInt32?>(repeating: nil, count: witness.quotientPolynomialCount))
            }
        )
        for chunk in bundle.chunks {
            let claimStorageIndices = try chunk.statement.polynomialClaim.evaluationClaims.map { claim -> Int in
                guard claim.storageIndex <= UInt64(Int.max) else {
                    throw AppleZKProverError.invalidInputLayout
                }
                return Int(claim.storageIndex)
            }
            guard claimStorageIndices == witness.claimedStorageIndices else {
                throw AppleZKProverError.invalidInputLayout
            }
            for claim in chunk.statement.polynomialClaim.evaluationClaims {
                guard claim.storageIndex <= UInt64(Int.max) else {
                    throw AppleZKProverError.invalidInputLayout
                }
                let storageIndex = Int(claim.storageIndex)
                var values = rows[storageIndex] ?? Array<UInt32?>(
                    repeating: nil,
                    count: witness.quotientPolynomialCount
                )
                let limbs = limbs(from: claim.value)
                for offset in chunk.sourceQuotientIndices.count..<AIRPublicQuotientToCirclePCSWitnessV1.m31QuotientsPerQM31Polynomial {
                    guard limbs[offset] == 0 else {
                        throw AppleZKProverError.invalidInputLayout
                    }
                }
                for (offset, quotientIndex) in chunk.sourceQuotientIndices.enumerated() {
                    guard quotientIndex >= 0,
                          quotientIndex < values.count,
                          values[quotientIndex] == nil else {
                        throw AppleZKProverError.invalidInputLayout
                    }
                    values[quotientIndex] = limbs[offset]
                }
                rows[storageIndex] = values
            }
        }
        var opened: [Int: [UInt32]] = [:]
        for storageIndex in witness.claimedStorageIndices {
            guard let values = rows[storageIndex],
                  values.allSatisfy({ $0 != nil }) else {
                throw AppleZKProverError.invalidInputLayout
            }
            opened[storageIndex] = values.map { $0! }
        }
        return opened
    }

    private static func rowDomainChallenge(
        storageIndex: Int,
        domain: CircleDomainDescriptor
    ) throws -> UInt32 {
        let naturalIndex = try CircleDomainOracle.naturalDomainIndex(
            forStorageIndex: storageIndex,
            descriptor: domain
        )
        let point = try CircleDomainOracle.point(
            in: domain,
            naturalDomainIndex: naturalIndex
        )
        try CircleDomainOracle.validatePoint(point)
        return point.x
    }

    private static func transitionVanishingValue(
        _ z: UInt32,
        traceRowCount: Int
    ) throws -> UInt32 {
        guard traceRowCount > 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var accumulator: UInt32 = 1
        for row in 0..<(traceRowCount - 1) {
            accumulator = M31Field.multiply(
                accumulator,
                M31Field.subtract(z, try rowCoordinate(row))
            )
        }
        return accumulator
    }

    private static func evaluate(
        _ polynomial: AIRConstraintPolynomialV1,
        currentRow: [UInt32],
        nextRow: [UInt32]?
    ) throws -> UInt32 {
        var accumulator: UInt32 = 0
        for term in polynomial.terms {
            var product = term.coefficient
            for factor in term.factors {
                let rowValues: [UInt32]
                switch factor.kind {
                case .current:
                    rowValues = currentRow
                case .next:
                    guard let nextRow else {
                        throw AppleZKProverError.invalidInputLayout
                    }
                    rowValues = nextRow
                }
                guard factor.column >= 0,
                      factor.column < rowValues.count else {
                    throw AppleZKProverError.invalidInputLayout
                }
                product = M31Field.multiply(product, rowValues[factor.column])
            }
            accumulator = M31Field.add(accumulator, product)
        }
        return accumulator
    }

    private static func rowCoordinate(_ row: Int) throws -> UInt32 {
        guard row >= 0,
              UInt64(row) < UInt64(M31Field.modulus) else {
            throw AppleZKProverError.invalidInputLayout
        }
        return UInt32(row)
    }

    private static func limbs(from value: QM31Element) -> [UInt32] {
        [
            value.constant.real,
            value.constant.imaginary,
            value.uCoefficient.real,
            value.uCoefficient.imaginary,
        ]
    }
}

public struct AIRProofQuotientPCSArtifactV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let statement: AIRProofStatementV1
    public let proof: AIRProofV1
    public let quotientPCSProofBundle: AIRQuotientCirclePCSProofBundleV1

    public init(
        version: UInt32 = currentVersion,
        statement: AIRProofStatementV1,
        proof: AIRProofV1,
        quotientPCSProofBundle: AIRQuotientCirclePCSProofBundleV1
    ) throws {
        guard version == Self.currentVersion else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.statement = statement
        self.proof = proof
        self.quotientPCSProofBundle = quotientPCSProofBundle
    }
}

public enum AIRProofQuotientPCSArtifactBuilderV1 {
    public static func prove(
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1,
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128,
        quotientClaimStorageIndices: [Int]? = nil
    ) throws -> AIRProofQuotientPCSArtifactV1 {
        let airProof = try AIRProofBuilderV1.prove(
            witness: witness,
            airDefinition: airDefinition
        )
        let quotientPCSProofBundle = try AIRQuotientCirclePCSProofBundleBuilderV1.prove(
            quotientProof: airProof.proof.publicQuotientProof,
            domain: domain,
            parameterSet: parameterSet,
            claimStorageIndices: quotientClaimStorageIndices
        )
        return try assemble(
            statement: airProof.statement,
            proof: airProof.proof,
            quotientPCSProofBundle: quotientPCSProofBundle
        )
    }

    public static func assemble(
        statement: AIRProofStatementV1,
        proof: AIRProofV1,
        quotientPCSProofBundle: AIRQuotientCirclePCSProofBundleV1
    ) throws -> AIRProofQuotientPCSArtifactV1 {
        let artifact = try AIRProofQuotientPCSArtifactV1(
            statement: statement,
            proof: proof,
            quotientPCSProofBundle: quotientPCSProofBundle
        )
        guard try AIRProofQuotientPCSArtifactVerifierV1.verify(artifact) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "AIR proof quotient PCS artifact does not verify."
            )
        }
        return artifact
    }
}

public struct AIRProofQuotientPCSVerificationReportV1: Equatable, Sendable {
    public let airProofReport: AIRProofVerificationReportV1
    public let quotientPCSBundleProofsVerify: Bool
    public let quotientPCSBundleMatchesAIRProof: Bool
    public let usesPCSBackedQuotientLowDegreeProof: Bool
    public let isSuccinctAIRGKRProof: Bool
    public let isZeroKnowledge: Bool

    public var verified: Bool {
        airProofReport.verifies(.publicRevealedTraceConstraintEvaluation) &&
            quotientPCSBundleProofsVerify &&
            quotientPCSBundleMatchesAIRProof
    }
}

public enum AIRProofQuotientPCSArtifactVerifierV1 {
    public static func verificationReport(
        _ artifact: AIRProofQuotientPCSArtifactV1
    ) throws -> AIRProofQuotientPCSVerificationReportV1 {
        let airProofReport = try AIRProofVerifierV1.verificationReport(
            proof: artifact.proof,
            statement: artifact.statement
        )
        let quotientPCSBundleProofsVerify = try AIRQuotientCirclePCSProofBundleVerifierV1.verify(
            artifact.quotientPCSProofBundle
        )
        let quotientPCSBundleMatchesAIRProof = try AIRQuotientCirclePCSProofBundleVerifierV1.verify(
            artifact.quotientPCSProofBundle,
            against: artifact.proof.publicQuotientProof
        )
        return AIRProofQuotientPCSVerificationReportV1(
            airProofReport: airProofReport,
            quotientPCSBundleProofsVerify: quotientPCSBundleProofsVerify,
            quotientPCSBundleMatchesAIRProof: quotientPCSBundleMatchesAIRProof,
            usesPCSBackedQuotientLowDegreeProof: true,
            isSuccinctAIRGKRProof: false,
            isZeroKnowledge: false
        )
    }

    public static func verificationReport(
        encodedArtifact: Data
    ) throws -> AIRProofQuotientPCSVerificationReportV1 {
        try verificationReport(
            AIRProofQuotientPCSArtifactCodecV1.decode(encodedArtifact)
        )
    }

    public static func verify(_ artifact: AIRProofQuotientPCSArtifactV1) throws -> Bool {
        try verificationReport(artifact).verified
    }

    public static func verify(encodedArtifact: Data) throws -> Bool {
        try verificationReport(encodedArtifact: encodedArtifact).verified
    }
}

public enum AIRProofQuotientPCSArtifactDigestV1 {
    private static let domain = Data("AppleZKProver.AIRProofQuotientPCSArtifact.V1".utf8)

    public static func digest(_ artifact: AIRProofQuotientPCSArtifactV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        try CanonicalBinary.appendLengthPrefixed(
            try AIRProofQuotientPCSArtifactCodecV1.encode(artifact),
            to: &data
        )
        return SHA3Oracle.sha3_256(data)
    }
}

public enum GKRGateOperationV1: UInt32, Codable, Sendable {
    case add = 0
    case subtract = 1
    case multiply = 2
}

public struct GKRGateV1: Equatable, Codable, Sendable {
    public let operation: GKRGateOperationV1
    public let leftInputIndex: Int
    public let rightInputIndex: Int

    public init(
        operation: GKRGateOperationV1,
        leftInputIndex: Int,
        rightInputIndex: Int
    ) throws {
        guard leftInputIndex >= 0,
              rightInputIndex >= 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.operation = operation
        self.leftInputIndex = leftInputIndex
        self.rightInputIndex = rightInputIndex
    }
}

public struct GKRLayerV1: Equatable, Codable, Sendable {
    public let gates: [GKRGateV1]

    public init(gates: [GKRGateV1]) throws {
        guard !gates.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.gates = gates
    }
}

public struct GKRClaimV1: Equatable, Codable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let inputValues: [UInt32]
    public let layers: [GKRLayerV1]
    public let claimedOutputs: [UInt32]

    public init(
        version: UInt32 = Self.currentVersion,
        inputValues: [UInt32],
        layers: [GKRLayerV1],
        claimedOutputs: [UInt32]
    ) throws {
        guard version == Self.currentVersion,
              !inputValues.isEmpty,
              !claimedOutputs.isEmpty else {
            throw AppleZKProverError.invalidInputLayout
        }
        try M31Field.validateCanonical(inputValues)
        try M31Field.validateCanonical(claimedOutputs)
        try Self.validateLayerShape(inputCount: inputValues.count, layers: layers)
        self.version = version
        self.inputValues = inputValues
        self.layers = layers
        self.claimedOutputs = claimedOutputs
    }

    private static func validateLayerShape(inputCount: Int, layers: [GKRLayerV1]) throws {
        var activeCount = inputCount
        for layer in layers {
            for gate in layer.gates {
                guard gate.leftInputIndex < activeCount,
                      gate.rightInputIndex < activeCount else {
                    throw AppleZKProverError.invalidInputLayout
                }
            }
            activeCount = layer.gates.count
        }
    }
}

public enum GKRSemanticVerifierV1 {
    public static func evaluate(_ claim: GKRClaimV1) throws -> [UInt32] {
        var activeValues = claim.inputValues
        for layer in claim.layers {
            var nextValues: [UInt32] = []
            nextValues.reserveCapacity(layer.gates.count)
            for gate in layer.gates {
                let left = activeValues[gate.leftInputIndex]
                let right = activeValues[gate.rightInputIndex]
                switch gate.operation {
                case .add:
                    nextValues.append(M31Field.add(left, right))
                case .subtract:
                    nextValues.append(M31Field.subtract(left, right))
                case .multiply:
                    nextValues.append(M31Field.multiply(left, right))
                }
            }
            activeValues = nextValues
        }
        return activeValues
    }

    public static func verify(_ claim: GKRClaimV1) throws -> Bool {
        try evaluate(claim) == claim.claimedOutputs
    }
}

public enum GKRClaimDigestV1 {
    private static let domain = Data("AppleZKProver.GKRClaim.V1".utf8)

    public static func digest(_ claim: GKRClaimV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        CanonicalBinary.appendUInt32(claim.version, to: &data)
        CanonicalBinary.appendUInt32(M31Field.modulus, to: &data)
        try appendWords(claim.inputValues, to: &data)
        CanonicalBinary.appendUInt32(try checkedUInt32(claim.layers.count), to: &data)
        for layer in claim.layers {
            CanonicalBinary.appendUInt32(try checkedUInt32(layer.gates.count), to: &data)
            for gate in layer.gates {
                CanonicalBinary.appendUInt32(gate.operation.rawValue, to: &data)
                CanonicalBinary.appendUInt32(try checkedUInt32(gate.leftInputIndex), to: &data)
                CanonicalBinary.appendUInt32(try checkedUInt32(gate.rightInputIndex), to: &data)
            }
        }
        try appendWords(claim.claimedOutputs, to: &data)
        return SHA3Oracle.sha3_256(data)
    }

    private static func appendWords(_ words: [UInt32], to data: inout Data) throws {
        CanonicalBinary.appendUInt32(try checkedUInt32(words.count), to: &data)
        for word in words {
            CanonicalBinary.appendUInt32(word, to: &data)
        }
    }
}

public struct ApplicationPublicTheoremArtifactV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let statement: ApplicationProofStatementV1
    public let proof: ApplicationProofV1
    public let witness: ApplicationWitnessTraceV1
    public let airDefinition: AIRDefinitionV1
    public let gkrClaim: GKRClaimV1

    public init(
        version: UInt32 = currentVersion,
        statement: ApplicationProofStatementV1,
        proof: ApplicationProofV1,
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1,
        gkrClaim: GKRClaimV1
    ) throws {
        guard version == Self.currentVersion else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.statement = statement
        self.proof = proof
        self.witness = witness
        self.airDefinition = airDefinition
        self.gkrClaim = gkrClaim
    }
}

public enum ApplicationPublicTheoremBuilderV1 {
    public static func prove(
        applicationIdentifier: String,
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1,
        gkrClaim: GKRClaimV1,
        pcsStatement: CirclePCSFRIStatementV1,
        sumcheckRounds: Int? = nil
    ) throws -> ApplicationPublicTheoremArtifactV1 {
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: witness,
            for: airDefinition
        )
        guard try AIRSemanticVerifierV1.verify(definition: airDefinition, trace: trace) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Public witness trace does not satisfy the AIR definition."
            )
        }
        guard try GKRSemanticVerifierV1.verify(gkrClaim) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "GKR claim outputs do not match the supplied layered circuit."
            )
        }

        let evaluations = try AIRToSumcheckReductionV1.paddedEvaluationVector(
            definition: airDefinition,
            trace: trace
        )
        let rounds = try sumcheckRounds ?? log2Exact(evaluations.count)
        let sumcheckProof = try M31SumcheckProofBuilderV1.prove(
            evaluations: evaluations,
            rounds: rounds
        )
        let statement = try ApplicationProofStatementV1(
            applicationIdentifier: applicationIdentifier,
            witnessCommitmentDigest: ApplicationWitnessDigestV1.digest(witness),
            airDefinitionDigest: AIRDefinitionDigestV1.digest(airDefinition),
            gkrClaimDigest: GKRClaimDigestV1.digest(gkrClaim),
            sumcheckStatement: sumcheckProof.statement,
            pcsStatement: pcsStatement
        )
        let proof = try ApplicationProofBuilderV1.prove(
            statement: statement,
            sumcheckProof: sumcheckProof
        )
        return try assemble(
            statement: statement,
            proof: proof,
            witness: witness,
            airDefinition: airDefinition,
            gkrClaim: gkrClaim
        )
    }

    public static func assemble(
        statement: ApplicationProofStatementV1,
        proof: ApplicationProofV1,
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1,
        gkrClaim: GKRClaimV1
    ) throws -> ApplicationPublicTheoremArtifactV1 {
        let artifact = try ApplicationPublicTheoremArtifactV1(
            statement: statement,
            proof: proof,
            witness: witness,
            airDefinition: airDefinition,
            gkrClaim: gkrClaim
        )
        guard try ApplicationTheoremVerifierV1.verifyPublicTheoremArtifact(artifact) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Application public theorem artifact does not verify."
            )
        }
        return artifact
    }

    private static func log2Exact(_ value: Int) throws -> Int {
        guard value > 1,
              value.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var remaining = value
        var result = 0
        while remaining > 1 {
            remaining >>= 1
            result += 1
        }
        return result
    }
}

public struct ApplicationPublicTheoremTracePCSArtifactV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let publicTheoremArtifact: ApplicationPublicTheoremArtifactV1
    public let tracePCSProofBundle: AIRTraceCirclePCSProofBundleV1

    public init(
        version: UInt32 = currentVersion,
        publicTheoremArtifact: ApplicationPublicTheoremArtifactV1,
        tracePCSProofBundle: AIRTraceCirclePCSProofBundleV1
    ) throws {
        guard version == Self.currentVersion else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.publicTheoremArtifact = publicTheoremArtifact
        self.tracePCSProofBundle = tracePCSProofBundle
    }
}

public enum ApplicationPublicTheoremTracePCSArtifactBuilderV1 {
    public static func prove(
        applicationIdentifier: String,
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1,
        gkrClaim: GKRClaimV1,
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128,
        claimRowIndices: [Int]? = nil,
        sumcheckRounds: Int? = nil
    ) throws -> ApplicationPublicTheoremTracePCSArtifactV1 {
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: witness,
            for: airDefinition
        )
        let tracePCSProofBundle = try AIRTraceCirclePCSProofBundleBuilderV1.prove(
            trace: trace,
            domain: domain,
            parameterSet: parameterSet,
            claimRowIndices: claimRowIndices
        )
        guard let primaryTracePCSChunk = tracePCSProofBundle.chunks.first else {
            throw AppleZKProverError.invalidInputLayout
        }
        guard try AIRSemanticVerifierV1.verify(definition: airDefinition, trace: trace) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Public witness trace does not satisfy the AIR definition."
            )
        }
        guard try GKRSemanticVerifierV1.verify(gkrClaim) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "GKR claim outputs do not match the supplied layered circuit."
            )
        }

        let evaluations = try AIRToSumcheckReductionV1.paddedEvaluationVector(
            definition: airDefinition,
            trace: trace
        )
        let rounds = try sumcheckRounds ?? log2Exact(evaluations.count)
        let sumcheckProof = try M31SumcheckProofBuilderV1.prove(
            evaluations: evaluations,
            rounds: rounds
        )
        let statement = try ApplicationProofStatementV1(
            applicationIdentifier: applicationIdentifier,
            witnessCommitmentDigest: ApplicationWitnessDigestV1.digest(witness),
            airDefinitionDigest: AIRDefinitionDigestV1.digest(airDefinition),
            gkrClaimDigest: GKRClaimDigestV1.digest(gkrClaim),
            sumcheckStatement: sumcheckProof.statement,
            pcsStatement: primaryTracePCSChunk.statement
        )
        let proof = try ApplicationProofBuilderV1.assemble(
            statement: statement,
            sumcheckProof: sumcheckProof,
            pcsProof: primaryTracePCSChunk.proof
        )
        let publicTheoremArtifact = try ApplicationPublicTheoremBuilderV1.assemble(
            statement: statement,
            proof: proof,
            witness: witness,
            airDefinition: airDefinition,
            gkrClaim: gkrClaim
        )
        return try assemble(
            publicTheoremArtifact: publicTheoremArtifact,
            tracePCSProofBundle: tracePCSProofBundle
        )
    }

    public static func assemble(
        publicTheoremArtifact: ApplicationPublicTheoremArtifactV1,
        tracePCSProofBundle: AIRTraceCirclePCSProofBundleV1
    ) throws -> ApplicationPublicTheoremTracePCSArtifactV1 {
        let artifact = try ApplicationPublicTheoremTracePCSArtifactV1(
            publicTheoremArtifact: publicTheoremArtifact,
            tracePCSProofBundle: tracePCSProofBundle
        )
        guard try ApplicationPublicTheoremTracePCSArtifactVerifierV1.verify(artifact) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Application public theorem trace PCS artifact does not verify."
            )
        }
        return artifact
    }

    private static func log2Exact(_ value: Int) throws -> Int {
        guard value > 1,
              value.nonzeroBitCount == 1 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var remaining = value
        var result = 0
        while remaining > 1 {
            remaining >>= 1
            result += 1
        }
        return result
    }
}

public struct ApplicationPublicTheoremTracePCSVerificationReportV1: Equatable, Sendable {
    public let publicTheoremReport: ApplicationTheoremVerificationReportV1
    public let tracePCSBundleProofsVerify: Bool
    public let tracePCSBundleMatchesAIRTrace: Bool
    public let applicationPCSProofIsInTraceBundle: Bool
    public let isZeroKnowledge: Bool

    public var verified: Bool {
        publicTheoremReport.publicSidecarTheoremVerified &&
            tracePCSBundleProofsVerify &&
            tracePCSBundleMatchesAIRTrace &&
            applicationPCSProofIsInTraceBundle
    }
}

public enum ApplicationPublicTheoremTracePCSArtifactVerifierV1 {
    public static func verificationReport(
        _ artifact: ApplicationPublicTheoremTracePCSArtifactV1
    ) throws -> ApplicationPublicTheoremTracePCSVerificationReportV1 {
        let publicTheorem = artifact.publicTheoremArtifact
        let publicTheoremReport = try ApplicationTheoremVerifierV1.verificationReport(
            artifact: publicTheorem
        )
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: publicTheorem.witness,
            for: publicTheorem.airDefinition
        )
        let expectedTracePCSWitness = try AIRTraceToCirclePCSWitnessV1.make(
            trace: trace,
            domain: artifact.tracePCSProofBundle.witness.domain,
            claimRowIndices: artifact.tracePCSProofBundle.witness.claimedRowIndices
        )
        let bundleProofsVerify = try AIRTraceCirclePCSProofBundleVerifierV1.verify(
            artifact.tracePCSProofBundle
        )
        let bundleMatchesTrace = expectedTracePCSWitness == artifact.tracePCSProofBundle.witness
        let applicationPCSProofIsInTraceBundle = artifact.tracePCSProofBundle.chunks.contains { chunk in
            chunk.statement == publicTheorem.statement.pcsStatement &&
                chunk.proof == publicTheorem.proof.pcsProof
        }
        return ApplicationPublicTheoremTracePCSVerificationReportV1(
            publicTheoremReport: publicTheoremReport,
            tracePCSBundleProofsVerify: bundleProofsVerify,
            tracePCSBundleMatchesAIRTrace: bundleMatchesTrace,
            applicationPCSProofIsInTraceBundle: applicationPCSProofIsInTraceBundle,
            isZeroKnowledge: false
        )
    }

    public static func verificationReport(
        encodedArtifact: Data
    ) throws -> ApplicationPublicTheoremTracePCSVerificationReportV1 {
        try verificationReport(
            ApplicationPublicTheoremTracePCSArtifactCodecV1.decode(encodedArtifact)
        )
    }

    public static func verify(_ artifact: ApplicationPublicTheoremTracePCSArtifactV1) throws -> Bool {
        try verificationReport(artifact).verified
    }

    public static func verify(encodedArtifact: Data) throws -> Bool {
        try verificationReport(encodedArtifact: encodedArtifact).verified
    }
}

public struct ApplicationPublicTheoremIntegratedArtifactV1: Equatable, Sendable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let publicTheoremArtifact: ApplicationPublicTheoremArtifactV1
    public let airConstraintSumcheckProof: AIRConstraintMultilinearSumcheckProofV1
    public let quotientIdentityPCSProofBundle: AIRSharedDomainQuotientIdentityPCSProofBundleV1

    public init(
        version: UInt32 = currentVersion,
        publicTheoremArtifact: ApplicationPublicTheoremArtifactV1,
        airConstraintSumcheckProof: AIRConstraintMultilinearSumcheckProofV1,
        quotientIdentityPCSProofBundle: AIRSharedDomainQuotientIdentityPCSProofBundleV1
    ) throws {
        guard version == Self.currentVersion else {
            throw AppleZKProverError.invalidInputLayout
        }
        self.version = version
        self.publicTheoremArtifact = publicTheoremArtifact
        self.airConstraintSumcheckProof = airConstraintSumcheckProof
        self.quotientIdentityPCSProofBundle = quotientIdentityPCSProofBundle
    }
}

public enum ApplicationPublicTheoremIntegratedArtifactBuilderV1 {
    public static func prove(
        applicationIdentifier: String,
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1,
        gkrClaim: GKRClaimV1,
        pcsStatement: CirclePCSFRIStatementV1,
        domain: CircleDomainDescriptor,
        parameterSet: CirclePCSFRIParameterSetV1 = .conservative128,
        quotientIdentityQueryCount: Int,
        sumcheckRounds: Int? = nil
    ) throws -> ApplicationPublicTheoremIntegratedArtifactV1 {
        let publicTheoremArtifact = try ApplicationPublicTheoremBuilderV1.prove(
            applicationIdentifier: applicationIdentifier,
            witness: witness,
            airDefinition: airDefinition,
            gkrClaim: gkrClaim,
            pcsStatement: pcsStatement,
            sumcheckRounds: sumcheckRounds
        )
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: witness,
            for: airDefinition
        )
        let airConstraintSumcheckProof = try AIRConstraintMultilinearSumcheckProofBuilderV1.prove(
            definition: airDefinition,
            trace: trace
        )
        let quotientProof = try AIRPublicQuotientOracleV1.prove(
            definition: airDefinition,
            trace: trace
        )
        let quotientIdentityBundle = try AIRSharedDomainQuotientIdentityPCSProofBundleBuilderV1.prove(
            trace: trace,
            definition: airDefinition,
            quotientProof: quotientProof,
            domain: domain,
            parameterSet: parameterSet,
            queryCount: quotientIdentityQueryCount
        )
        return try assemble(
            publicTheoremArtifact: publicTheoremArtifact,
            airConstraintSumcheckProof: airConstraintSumcheckProof,
            quotientIdentityPCSProofBundle: quotientIdentityBundle
        )
    }

    public static func assemble(
        publicTheoremArtifact: ApplicationPublicTheoremArtifactV1,
        airConstraintSumcheckProof: AIRConstraintMultilinearSumcheckProofV1,
        quotientIdentityPCSProofBundle: AIRSharedDomainQuotientIdentityPCSProofBundleV1
    ) throws -> ApplicationPublicTheoremIntegratedArtifactV1 {
        let artifact = try ApplicationPublicTheoremIntegratedArtifactV1(
            publicTheoremArtifact: publicTheoremArtifact,
            airConstraintSumcheckProof: airConstraintSumcheckProof,
            quotientIdentityPCSProofBundle: quotientIdentityPCSProofBundle
        )
        guard try ApplicationPublicTheoremIntegratedArtifactVerifierV1.verify(artifact) else {
            throw AppleZKProverError.correctnessValidationFailed(
                "Application integrated public theorem artifact does not verify."
            )
        }
        return artifact
    }
}

public struct ApplicationPublicTheoremIntegratedVerificationReportV1: Equatable, Sendable {
    public let publicTheoremReport: ApplicationTheoremVerificationReportV1
    public let airConstraintSumcheckReport: AIRConstraintMultilinearSumcheckVerificationReportV1
    public let quotientIdentityReport: AIRSharedDomainQuotientIdentityVerificationReportV1
    public let quotientProofDerivedFromPublicTrace: Bool
    public let airConstraintSumcheckMatchesPublicTheoremTrace: Bool
    public let quotientIdentityMatchesPublicTheoremTrace: Bool
    public let isSuccinctAIRGKRProof: Bool
    public let isZeroKnowledge: Bool

    public var verifiesIntegratedPublicTheorem: Bool {
        publicTheoremReport.publicSidecarTheoremVerified &&
            airConstraintSumcheckReport.provesPublicAIRSemantics &&
            quotientIdentityReport.provesAIRQuotientIdentity &&
            quotientProofDerivedFromPublicTrace &&
            airConstraintSumcheckMatchesPublicTheoremTrace &&
            quotientIdentityMatchesPublicTheoremTrace
    }
}

public enum ApplicationPublicTheoremIntegratedArtifactVerifierV1 {
    public static func verificationReport(
        _ artifact: ApplicationPublicTheoremIntegratedArtifactV1
    ) throws -> ApplicationPublicTheoremIntegratedVerificationReportV1 {
        let publicTheorem = artifact.publicTheoremArtifact
        let publicTheoremReport = try ApplicationTheoremVerifierV1.verificationReport(
            artifact: publicTheorem
        )
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: publicTheorem.witness,
            for: publicTheorem.airDefinition
        )
        let airSumcheckReport = try AIRConstraintMultilinearSumcheckVerifierV1
            .verificationReport(
                artifact.airConstraintSumcheckProof,
                definition: publicTheorem.airDefinition,
                trace: trace
            )
        let quotientProofResult = try derivedQuotientProof(
            definition: publicTheorem.airDefinition,
            trace: trace
        )
        let quotientIdentityReport: AIRSharedDomainQuotientIdentityVerificationReportV1
        if let quotientProof = quotientProofResult.proof {
            quotientIdentityReport = try AIRSharedDomainQuotientIdentityPCSProofBundleVerifierV1
                .verificationReport(
                    artifact.quotientIdentityPCSProofBundle,
                    definition: publicTheorem.airDefinition,
                    quotientProof: quotientProof
                )
        } else {
            quotientIdentityReport = AIRSharedDomainQuotientIdentityVerificationReportV1(
                currentTracePCSBundleProofsVerify: false,
                nextTracePCSBundleProofsVerify: false,
                quotientPCSBundleProofsVerify: false,
                currentTraceBundleMatchesQuotientTraceDigest: false,
                nextTraceBundleMatchesShiftedTrace: false,
                quotientPCSBundleMatchesQuotientProof: false,
                queryPlanMatchesCommitments: false,
                bundlesOpenExactlyQueryPoints: false,
                domainsMatch: false,
                parameterSetsMatch: false,
                coordinateDomainsAlignedForAIRQuotientIdentity: false,
                quotientIdentityChecked: false,
                isZeroKnowledge: false
            )
        }
        let airDefinitionDigest = try AIRDefinitionDigestV1.digest(publicTheorem.airDefinition)
        let airMatchesPublicTrace =
            artifact.airConstraintSumcheckProof.traceRowCount == trace.rowCount &&
            artifact.airConstraintSumcheckProof.traceColumnCount == trace.columnCount &&
            artifact.airConstraintSumcheckProof.airDefinitionDigest == airDefinitionDigest
        let quotientMatchesPublicTrace =
            artifact.quotientIdentityPCSProofBundle.queryPlan.traceRowCount == trace.rowCount &&
            artifact.quotientIdentityPCSProofBundle.queryPlan.traceColumnCount == trace.columnCount &&
            artifact.quotientIdentityPCSProofBundle.queryPlan.airDefinitionDigest == airDefinitionDigest
        return ApplicationPublicTheoremIntegratedVerificationReportV1(
            publicTheoremReport: publicTheoremReport,
            airConstraintSumcheckReport: airSumcheckReport,
            quotientIdentityReport: quotientIdentityReport,
            quotientProofDerivedFromPublicTrace: quotientProofResult.derived,
            airConstraintSumcheckMatchesPublicTheoremTrace: airMatchesPublicTrace,
            quotientIdentityMatchesPublicTheoremTrace: quotientMatchesPublicTrace,
            isSuccinctAIRGKRProof: false,
            isZeroKnowledge: false
        )
    }

    public static func verify(
        _ artifact: ApplicationPublicTheoremIntegratedArtifactV1
    ) throws -> Bool {
        try verificationReport(artifact).verifiesIntegratedPublicTheorem
    }

    public static func verificationReport(
        encodedArtifact: Data
    ) throws -> ApplicationPublicTheoremIntegratedVerificationReportV1 {
        try verificationReport(
            ApplicationPublicTheoremIntegratedArtifactCodecV1.decode(encodedArtifact)
        )
    }

    public static func verify(encodedArtifact: Data) throws -> Bool {
        try verificationReport(encodedArtifact: encodedArtifact).verifiesIntegratedPublicTheorem
    }

    private static func derivedQuotientProof(
        definition: AIRDefinitionV1,
        trace: AIRExecutionTraceV1
    ) throws -> (derived: Bool, proof: AIRPublicQuotientProofV1?) {
        do {
            return (
                true,
                try AIRPublicQuotientOracleV1.prove(
                    definition: definition,
                    trace: trace
                )
            )
        } catch AppleZKProverError.correctnessValidationFailed {
            return (false, nil)
        } catch AppleZKProverError.invalidInputLayout {
            return (false, nil)
        }
    }
}

public struct ApplicationTheoremVerificationReportV1: Equatable, Sendable {
    public let componentReport: ApplicationProofVerificationReportV1
    public let witnessCommitmentDigestMatches: Bool
    public let airDefinitionDigestMatches: Bool
    public let gkrClaimDigestMatches: Bool
    public let witnessToAIRTraceProduced: Bool
    public let airSemanticsVerified: Bool
    public let airToSumcheckReductionVerified: Bool
    public let gkrVerified: Bool
    public let isZeroKnowledge: Bool

    public var publicSidecarTheoremVerified: Bool {
        componentReport.implementedComponentsVerified &&
            witnessCommitmentDigestMatches &&
            airDefinitionDigestMatches &&
            gkrClaimDigestMatches &&
            witnessToAIRTraceProduced &&
            airSemanticsVerified &&
            airToSumcheckReductionVerified &&
            gkrVerified
    }
}

public enum ApplicationTheoremVerifierV1 {
    public static func verificationReport(
        artifact: ApplicationPublicTheoremArtifactV1
    ) throws -> ApplicationTheoremVerificationReportV1 {
        try verificationReport(
            proof: artifact.proof,
            statement: artifact.statement,
            witness: artifact.witness,
            airDefinition: artifact.airDefinition,
            gkrClaim: artifact.gkrClaim
        )
    }

    public static func verificationReport(
        encodedArtifact: Data
    ) throws -> ApplicationTheoremVerificationReportV1 {
        try verificationReport(
            artifact: ApplicationPublicTheoremArtifactCodecV1.decode(encodedArtifact)
        )
    }

    public static func verificationReport(
        proof: ApplicationProofV1,
        statement: ApplicationProofStatementV1,
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1,
        gkrClaim: GKRClaimV1
    ) throws -> ApplicationTheoremVerificationReportV1 {
        let componentReport = try ApplicationProofVerifierV1.verificationReport(
            proof: proof,
            statement: statement
        )
        let trace = try WitnessToAIRTraceProducerV1.produce(
            witness: witness,
            for: airDefinition
        )

        return try ApplicationTheoremVerificationReportV1(
            componentReport: componentReport,
            witnessCommitmentDigestMatches: statement.witnessCommitmentDigest == ApplicationWitnessDigestV1.digest(witness),
            airDefinitionDigestMatches: statement.airDefinitionDigest == AIRDefinitionDigestV1.digest(airDefinition),
            gkrClaimDigestMatches: statement.gkrClaimDigest == GKRClaimDigestV1.digest(gkrClaim),
            witnessToAIRTraceProduced: true,
            airSemanticsVerified: AIRSemanticVerifierV1.verify(definition: airDefinition, trace: trace),
            airToSumcheckReductionVerified: AIRToSumcheckReductionV1.verify(
                statement: statement.sumcheckStatement,
                definition: airDefinition,
                trace: trace
            ),
            gkrVerified: GKRSemanticVerifierV1.verify(gkrClaim),
            isZeroKnowledge: false
        )
    }

    public static func verificationReport(
        encodedProof: Data,
        statement: ApplicationProofStatementV1,
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1,
        gkrClaim: GKRClaimV1
    ) throws -> ApplicationTheoremVerificationReportV1 {
        try verificationReport(
            proof: ApplicationProofCodecV1.decode(encodedProof),
            statement: statement,
            witness: witness,
            airDefinition: airDefinition,
            gkrClaim: gkrClaim
        )
    }

    public static func verifyPublicSidecarTheorem(
        proof: ApplicationProofV1,
        statement: ApplicationProofStatementV1,
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1,
        gkrClaim: GKRClaimV1
    ) throws -> Bool {
        try verificationReport(
            proof: proof,
            statement: statement,
            witness: witness,
            airDefinition: airDefinition,
            gkrClaim: gkrClaim
        ).publicSidecarTheoremVerified
    }

    public static func verifyPublicSidecarTheorem(
        encodedProof: Data,
        statement: ApplicationProofStatementV1,
        witness: ApplicationWitnessTraceV1,
        airDefinition: AIRDefinitionV1,
        gkrClaim: GKRClaimV1
    ) throws -> Bool {
        try verificationReport(
            encodedProof: encodedProof,
            statement: statement,
            witness: witness,
            airDefinition: airDefinition,
            gkrClaim: gkrClaim
        ).publicSidecarTheoremVerified
    }

    public static func verifyPublicTheoremArtifact(
        _ artifact: ApplicationPublicTheoremArtifactV1
    ) throws -> Bool {
        try verificationReport(artifact: artifact).publicSidecarTheoremVerified
    }

    public static func verifyPublicTheoremArtifact(
        encodedArtifact: Data
    ) throws -> Bool {
        try verificationReport(encodedArtifact: encodedArtifact).publicSidecarTheoremVerified
    }
}

public enum ApplicationWitnessTraceCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x57, 0x54, 0x56, 0x31, 0x00])

    public static func encode(_ witness: ApplicationWitnessTraceV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(witness.version, to: &data)
        CanonicalBinary.appendUInt64(UInt64(witness.columnCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(witness.rowCount), to: &data)
        for column in witness.columns {
            appendM31Words(column, to: &data)
        }
        return data
    }

    public static func decode(_ data: Data) throws -> ApplicationWitnessTraceV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let columnCount = try readCount64(from: &reader)
        let rowCount = try readCount64(from: &reader)
        var columns: [[UInt32]] = []
        columns.reserveCapacity(columnCount)
        for _ in 0..<columnCount {
            let column = try readM31Words(from: &reader)
            guard column.count == rowCount else {
                throw AppleZKProverError.invalidInputLayout
            }
            columns.append(column)
        }
        try reader.finish()
        return try ApplicationWitnessTraceV1(version: version, columns: columns)
    }
}

public enum AIRDefinitionCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x41, 0x49, 0x56, 0x31, 0x00])

    public static func encode(_ definition: AIRDefinitionV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(definition.version, to: &data)
        CanonicalBinary.appendUInt64(UInt64(definition.columnCount), to: &data)
        try appendPolynomials(definition.transitionConstraints, to: &data)
        CanonicalBinary.appendUInt64(UInt64(definition.boundaryConstraints.count), to: &data)
        for boundary in definition.boundaryConstraints {
            CanonicalBinary.appendUInt64(UInt64(boundary.rowIndex), to: &data)
            try appendPolynomial(boundary.polynomial, to: &data)
        }
        return data
    }

    public static func decode(_ data: Data) throws -> AIRDefinitionV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let columnCount = try readCount64(from: &reader)
        let transitionConstraints = try readPolynomials(from: &reader)
        let boundaryCount = try readCount64(from: &reader)
        var boundaryConstraints: [AIRBoundaryConstraintV1] = []
        boundaryConstraints.reserveCapacity(boundaryCount)
        for _ in 0..<boundaryCount {
            boundaryConstraints.append(try AIRBoundaryConstraintV1(
                rowIndex: readCount64(from: &reader),
                polynomial: readPolynomial(from: &reader)
            ))
        }
        try reader.finish()
        return try AIRDefinitionV1(
            version: version,
            columnCount: columnCount,
            transitionConstraints: transitionConstraints,
            boundaryConstraints: boundaryConstraints
        )
    }

    private static func appendPolynomials(
        _ polynomials: [AIRConstraintPolynomialV1],
        to data: inout Data
    ) throws {
        CanonicalBinary.appendUInt64(UInt64(polynomials.count), to: &data)
        for polynomial in polynomials {
            try appendPolynomial(polynomial, to: &data)
        }
    }

    private static func appendPolynomial(
        _ polynomial: AIRConstraintPolynomialV1,
        to data: inout Data
    ) throws {
        CanonicalBinary.appendUInt64(UInt64(polynomial.terms.count), to: &data)
        for term in polynomial.terms {
            CanonicalBinary.appendUInt32(term.coefficient, to: &data)
            CanonicalBinary.appendUInt64(UInt64(term.factors.count), to: &data)
            for factor in term.factors {
                CanonicalBinary.appendUInt32(factor.kind.rawValue, to: &data)
                CanonicalBinary.appendUInt64(UInt64(factor.column), to: &data)
            }
        }
    }

    private static func readPolynomials(
        from reader: inout CanonicalByteReader
    ) throws -> [AIRConstraintPolynomialV1] {
        let count = try readCount64(from: &reader)
        var polynomials: [AIRConstraintPolynomialV1] = []
        polynomials.reserveCapacity(count)
        for _ in 0..<count {
            polynomials.append(try readPolynomial(from: &reader))
        }
        return polynomials
    }

    private static func readPolynomial(
        from reader: inout CanonicalByteReader
    ) throws -> AIRConstraintPolynomialV1 {
        let termCount = try readCount64(from: &reader)
        var terms: [AIRConstraintTermV1] = []
        terms.reserveCapacity(termCount)
        for _ in 0..<termCount {
            let coefficient = try reader.readUInt32()
            let factorCount = try readCount64(from: &reader)
            var factors: [AIRTraceReferenceV1] = []
            factors.reserveCapacity(factorCount)
            for _ in 0..<factorCount {
                guard let kind = AIRTraceReferenceKindV1(rawValue: try reader.readUInt32()) else {
                    throw AppleZKProverError.invalidInputLayout
                }
                factors.append(try AIRTraceReferenceV1(
                    kind: kind,
                    column: readCount64(from: &reader)
                ))
            }
            terms.append(try AIRConstraintTermV1(
                coefficient: coefficient,
                factors: factors
            ))
        }
        return try AIRConstraintPolynomialV1(terms: terms)
    }
}

public enum AIRCompositionEvaluationCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x41, 0x43, 0x56, 0x31, 0x00])

    public static func encode(_ composition: AIRCompositionEvaluationV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(composition.version, to: &data)
        CanonicalBinary.appendUInt64(UInt64(composition.traceRowCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(composition.traceColumnCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(composition.transitionConstraintCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(composition.boundaryConstraintCount), to: &data)
        appendM31Words(composition.compositionWeights, to: &data)
        data.append(composition.rawEvaluationDigest)
        appendM31Words(composition.combinedEvaluations, to: &data)
        return data
    }

    public static func decode(_ data: Data) throws -> AIRCompositionEvaluationV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let traceRowCount = try readCount64(from: &reader)
        let traceColumnCount = try readCount64(from: &reader)
        let transitionConstraintCount = try readCount64(from: &reader)
        let boundaryConstraintCount = try readCount64(from: &reader)
        let compositionWeights = try readM31Words(from: &reader)
        let rawEvaluationDigest = try reader.readBytes(count: 32)
        let combinedEvaluations = try readM31Words(from: &reader)
        try reader.finish()
        return try AIRCompositionEvaluationV1(
            version: version,
            traceRowCount: traceRowCount,
            traceColumnCount: traceColumnCount,
            transitionConstraintCount: transitionConstraintCount,
            boundaryConstraintCount: boundaryConstraintCount,
            compositionWeights: compositionWeights,
            rawEvaluationDigest: rawEvaluationDigest,
            combinedEvaluations: combinedEvaluations
        )
    }
}

public enum AIRPublicQuotientProofCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x41, 0x51, 0x56, 0x31, 0x00])

    public static func encode(_ proof: AIRPublicQuotientProofV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(proof.version, to: &data)
        CanonicalBinary.appendUInt64(UInt64(proof.traceRowCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(proof.traceColumnCount), to: &data)
        data.append(proof.tracePolynomialDigest)
        CanonicalBinary.appendUInt64(UInt64(proof.quotientPolynomials.count), to: &data)
        for quotient in proof.quotientPolynomials {
            CanonicalBinary.appendUInt32(quotient.version, to: &data)
            CanonicalBinary.appendUInt32(quotient.kind.rawValue, to: &data)
            CanonicalBinary.appendUInt64(UInt64(quotient.constraintIndex), to: &data)
            CanonicalBinary.appendUInt64(UInt64(quotient.numeratorDegreeBound), to: &data)
            CanonicalBinary.appendUInt64(UInt64(quotient.vanishingDegree), to: &data)
            CanonicalBinary.appendUInt64(UInt64(quotient.quotientDegreeBound), to: &data)
            appendM31Words(quotient.quotientCoefficients, to: &data)
        }
        return data
    }

    public static func decode(_ data: Data) throws -> AIRPublicQuotientProofV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let traceRowCount = try readCount64(from: &reader)
        let traceColumnCount = try readCount64(from: &reader)
        let tracePolynomialDigest = try reader.readBytes(count: 32)
        let quotientCount = try readCount64(from: &reader)
        var quotientPolynomials: [AIRConstraintQuotientPolynomialV1] = []
        quotientPolynomials.reserveCapacity(quotientCount)
        for _ in 0..<quotientCount {
            let quotientVersion = try reader.readUInt32()
            guard let kind = AIRPublicQuotientConstraintKindV1(rawValue: try reader.readUInt32()) else {
                throw AppleZKProverError.invalidInputLayout
            }
            quotientPolynomials.append(try AIRConstraintQuotientPolynomialV1(
                version: quotientVersion,
                kind: kind,
                constraintIndex: readCount64(from: &reader),
                numeratorDegreeBound: readCount64(from: &reader),
                vanishingDegree: readCount64(from: &reader),
                quotientDegreeBound: readCount64(from: &reader),
                quotientCoefficients: readM31Words(from: &reader)
            ))
        }
        try reader.finish()
        return try AIRPublicQuotientProofV1(
            version: version,
            traceRowCount: traceRowCount,
            traceColumnCount: traceColumnCount,
            tracePolynomialDigest: tracePolynomialDigest,
            quotientPolynomials: quotientPolynomials
        )
    }
}

public enum AIRProofStatementCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x41, 0x50, 0x53, 0x31, 0x00])

    public static func encode(_ statement: AIRProofStatementV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(statement.version, to: &data)
        data.append(statement.airDefinitionDigest)
        data.append(statement.witnessTraceDigest)
        CanonicalBinary.appendUInt64(UInt64(statement.traceRowCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(statement.traceColumnCount), to: &data)
        data.append(statement.compositionEvaluationDigest)
        data.append(statement.publicQuotientProofDigest)
        return data
    }

    public static func decode(_ data: Data) throws -> AIRProofStatementV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let airDefinitionDigest = try reader.readBytes(count: 32)
        let witnessTraceDigest = try reader.readBytes(count: 32)
        let traceRowCount = try readCount64(from: &reader)
        let traceColumnCount = try readCount64(from: &reader)
        let compositionEvaluationDigest = try reader.readBytes(count: 32)
        let publicQuotientProofDigest = try reader.readBytes(count: 32)
        try reader.finish()
        return try AIRProofStatementV1(
            version: version,
            airDefinitionDigest: airDefinitionDigest,
            witnessTraceDigest: witnessTraceDigest,
            traceRowCount: traceRowCount,
            traceColumnCount: traceColumnCount,
            compositionEvaluationDigest: compositionEvaluationDigest,
            publicQuotientProofDigest: publicQuotientProofDigest
        )
    }
}

public enum AIRProofCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x41, 0x50, 0x56, 0x31, 0x00])

    public static func encode(_ proof: AIRProofV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(proof.version, to: &data)
        data.append(proof.statementDigest)
        try CanonicalBinary.appendLengthPrefixed(
            try AIRDefinitionCodecV1.encode(proof.airDefinition),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try ApplicationWitnessTraceCodecV1.encode(proof.witness),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try AIRCompositionEvaluationCodecV1.encode(proof.composition),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try AIRPublicQuotientProofCodecV1.encode(proof.publicQuotientProof),
            to: &data
        )
        return data
    }

    public static func decode(_ data: Data) throws -> AIRProofV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let statementDigest = try reader.readBytes(count: 32)
        let airDefinition = try AIRDefinitionCodecV1.decode(try reader.readLengthPrefixed())
        let witness = try ApplicationWitnessTraceCodecV1.decode(try reader.readLengthPrefixed())
        let composition = try AIRCompositionEvaluationCodecV1.decode(try reader.readLengthPrefixed())
        let publicQuotientProof = try AIRPublicQuotientProofCodecV1.decode(try reader.readLengthPrefixed())
        try reader.finish()
        return try AIRProofV1(
            version: version,
            statementDigest: statementDigest,
            airDefinition: airDefinition,
            witness: witness,
            composition: composition,
            publicQuotientProof: publicQuotientProof
        )
    }
}

public enum AIRQuotientCirclePCSProofBundleCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x51, 0x50, 0x42, 0x56, 0x31])

    public static func encode(_ bundle: AIRQuotientCirclePCSProofBundleV1) throws -> Data {
        var data = Data()
        data.append(magic)
        try CanonicalBinary.appendLengthPrefixed(
            try CircleDomainDescriptorCodecV1.encode(bundle.witness.domain),
            to: &data
        )
        data.append(bundle.witness.quotientProofDigest)
        CanonicalBinary.appendUInt64(UInt64(bundle.witness.quotientPolynomialCount), to: &data)
        try appendIntList(bundle.witness.claimedStorageIndices, to: &data)
        try CanonicalBinary.appendLengthPrefixed(
            try parameterSetBytes(bundle.parameterSet),
            to: &data
        )
        CanonicalBinary.appendUInt64(UInt64(bundle.chunks.count), to: &data)
        for chunk in bundle.chunks {
            CanonicalBinary.appendUInt64(UInt64(chunk.chunkIndex), to: &data)
            try appendIntList(chunk.sourceQuotientIndices, to: &data)
            try CanonicalBinary.appendLengthPrefixed(
                try ApplicationProofStatementCodecV1.encodePCSStatement(chunk.statement),
                to: &data
            )
            try CanonicalBinary.appendLengthPrefixed(
                try CirclePCSFRIProofCodecV1.encode(chunk.proof),
                to: &data
            )
        }
        return data
    }

    public static func decode(_ data: Data) throws -> AIRQuotientCirclePCSProofBundleV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let domain = try CircleDomainDescriptorCodecV1.decode(try reader.readLengthPrefixed())
        let quotientProofDigest = try reader.readBytes(count: 32)
        let quotientPolynomialCount = try readCount64(from: &reader)
        let claimedStorageIndices = try readIntList(from: &reader)
        let parameterSet = try readParameterSet(
            from: CanonicalByteReader(try reader.readLengthPrefixed())
        )
        let chunkCount = try readCount64(from: &reader)
        var witnessChunks: [AIRQuotientCirclePCSChunkV1] = []
        witnessChunks.reserveCapacity(chunkCount)
        var proofChunks: [AIRQuotientCirclePCSProofChunkV1] = []
        proofChunks.reserveCapacity(chunkCount)

        for _ in 0..<chunkCount {
            let chunkIndex = try readCount64(from: &reader)
            let sourceQuotientIndices = try readIntList(from: &reader)
            let statement = try ApplicationProofStatementCodecV1.decodePCSStatement(
                try reader.readLengthPrefixed()
            )
            let proof = try CirclePCSFRIProofCodecV1.decode(
                try reader.readLengthPrefixed()
            )
            let witnessChunk = try AIRQuotientCirclePCSChunkV1(
                chunkIndex: chunkIndex,
                sourceQuotientIndices: sourceQuotientIndices,
                polynomial: statement.polynomialClaim.polynomial,
                polynomialClaim: statement.polynomialClaim
            )
            witnessChunks.append(witnessChunk)
            proofChunks.append(try AIRQuotientCirclePCSProofChunkV1(
                chunkIndex: chunkIndex,
                sourceQuotientIndices: sourceQuotientIndices,
                statement: statement,
                proof: proof
            ))
        }
        try reader.finish()

        let witness = try AIRQuotientCirclePCSWitnessV1(
            domain: domain,
            quotientProofDigest: quotientProofDigest,
            quotientPolynomialCount: quotientPolynomialCount,
            claimedStorageIndices: claimedStorageIndices,
            chunks: witnessChunks
        )
        return try AIRQuotientCirclePCSProofBundleV1(
            witness: witness,
            parameterSet: parameterSet,
            chunks: proofChunks
        )
    }

    private static func appendIntList(_ values: [Int], to data: inout Data) throws {
        CanonicalBinary.appendUInt64(UInt64(values.count), to: &data)
        for value in values {
            guard value >= 0 else {
                throw AppleZKProverError.invalidInputLayout
            }
            CanonicalBinary.appendUInt64(UInt64(value), to: &data)
        }
    }

    private static func readIntList(from reader: inout CanonicalByteReader) throws -> [Int] {
        let count = try readCount64(from: &reader)
        var values: [Int] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            values.append(try readCount64(from: &reader))
        }
        return values
    }

    private static func parameterSetBytes(_ parameterSet: CirclePCSFRIParameterSetV1) throws -> Data {
        var data = Data()
        try CanonicalBinary.appendLengthPrefixed(
            Data(parameterSet.profileID.rawValue.utf8),
            to: &data
        )
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.logBlowupFactor, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.queryCount, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.foldingStep, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.grindingBits, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.targetSoundnessBits, to: &data)
        return data
    }

    private static func readParameterSet(
        from byteReader: CanonicalByteReader
    ) throws -> CirclePCSFRIParameterSetV1 {
        var reader = byteReader
        guard let profileString = String(
            data: try reader.readLengthPrefixed(),
            encoding: .utf8
        ),
              let profileID = CirclePCSFRIParameterSetV1.ProfileID(rawValue: profileString) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let logBlowupFactor = try reader.readUInt32()
        let queryCount = try reader.readUInt32()
        let foldingStep = try reader.readUInt32()
        let grindingBits = try reader.readUInt32()
        let targetSoundnessBits = try reader.readUInt32()
        try reader.finish()
        let parameterSet = try CirclePCSFRIParameterSetV1(
            profileID: profileID,
            logBlowupFactor: logBlowupFactor,
            queryCount: queryCount,
            grindingBits: grindingBits,
            targetSoundnessBits: targetSoundnessBits
        )
        guard parameterSet.securityParameters.foldingStep == foldingStep else {
            throw AppleZKProverError.invalidInputLayout
        }
        return parameterSet
    }
}

public enum AIRProofQuotientPCSArtifactCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x41, 0x51, 0x50, 0x56, 0x31])

    public static func encode(_ artifact: AIRProofQuotientPCSArtifactV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(artifact.version, to: &data)
        try CanonicalBinary.appendLengthPrefixed(
            try AIRProofStatementCodecV1.encode(artifact.statement),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try AIRProofCodecV1.encode(artifact.proof),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try AIRQuotientCirclePCSProofBundleCodecV1.encode(artifact.quotientPCSProofBundle),
            to: &data
        )
        return data
    }

    public static func decode(_ data: Data) throws -> AIRProofQuotientPCSArtifactV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let statement = try AIRProofStatementCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        let proof = try AIRProofCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        let quotientPCSProofBundle = try AIRQuotientCirclePCSProofBundleCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        try reader.finish()
        return try AIRProofQuotientPCSArtifactV1(
            version: version,
            statement: statement,
            proof: proof,
            quotientPCSProofBundle: quotientPCSProofBundle
        )
    }
}

public enum GKRClaimCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x47, 0x4b, 0x56, 0x31, 0x00])

    public static func encode(_ claim: GKRClaimV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(claim.version, to: &data)
        appendM31Words(claim.inputValues, to: &data)
        CanonicalBinary.appendUInt64(UInt64(claim.layers.count), to: &data)
        for layer in claim.layers {
            CanonicalBinary.appendUInt64(UInt64(layer.gates.count), to: &data)
            for gate in layer.gates {
                CanonicalBinary.appendUInt32(gate.operation.rawValue, to: &data)
                CanonicalBinary.appendUInt64(UInt64(gate.leftInputIndex), to: &data)
                CanonicalBinary.appendUInt64(UInt64(gate.rightInputIndex), to: &data)
            }
        }
        appendM31Words(claim.claimedOutputs, to: &data)
        return data
    }

    public static func decode(_ data: Data) throws -> GKRClaimV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let inputValues = try readM31Words(from: &reader)
        let layerCount = try readCount64(from: &reader)
        var layers: [GKRLayerV1] = []
        layers.reserveCapacity(layerCount)
        for _ in 0..<layerCount {
            let gateCount = try readCount64(from: &reader)
            var gates: [GKRGateV1] = []
            gates.reserveCapacity(gateCount)
            for _ in 0..<gateCount {
                guard let operation = GKRGateOperationV1(rawValue: try reader.readUInt32()) else {
                    throw AppleZKProverError.invalidInputLayout
                }
                gates.append(try GKRGateV1(
                    operation: operation,
                    leftInputIndex: readCount64(from: &reader),
                    rightInputIndex: readCount64(from: &reader)
                ))
            }
            layers.append(try GKRLayerV1(gates: gates))
        }
        let claimedOutputs = try readM31Words(from: &reader)
        try reader.finish()
        return try GKRClaimV1(
            version: version,
            inputValues: inputValues,
            layers: layers,
            claimedOutputs: claimedOutputs
        )
    }
}

public enum ApplicationProofStatementCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x41, 0x53, 0x56, 0x31, 0x00])

    public static func encode(_ statement: ApplicationProofStatementV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(statement.version, to: &data)
        try CanonicalBinary.appendLengthPrefixed(Data(statement.applicationIdentifier.utf8), to: &data)
        data.append(statement.witnessCommitmentDigest)
        data.append(statement.airDefinitionDigest)
        data.append(statement.gkrClaimDigest)
        try CanonicalBinary.appendLengthPrefixed(
            try encodeSumcheckStatement(statement.sumcheckStatement),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try encodePCSStatement(statement.pcsStatement),
            to: &data
        )
        return data
    }

    public static func decode(_ data: Data) throws -> ApplicationProofStatementV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        guard let applicationIdentifier = String(
            data: try reader.readLengthPrefixed(),
            encoding: .utf8
        ) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let witnessCommitmentDigest = try reader.readBytes(count: 32)
        let airDefinitionDigest = try reader.readBytes(count: 32)
        let gkrClaimDigest = try reader.readBytes(count: 32)
        let sumcheckStatement = try decodeSumcheckStatement(try reader.readLengthPrefixed())
        let pcsStatement = try decodePCSStatement(try reader.readLengthPrefixed())
        try reader.finish()
        return try ApplicationProofStatementV1(
            version: version,
            applicationIdentifier: applicationIdentifier,
            witnessCommitmentDigest: witnessCommitmentDigest,
            airDefinitionDigest: airDefinitionDigest,
            gkrClaimDigest: gkrClaimDigest,
            sumcheckStatement: sumcheckStatement,
            pcsStatement: pcsStatement
        )
    }

    private static func encodeSumcheckStatement(_ statement: M31SumcheckStatementV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(statement.version, to: &data)
        CanonicalBinary.appendUInt64(UInt64(statement.laneCount), to: &data)
        CanonicalBinary.appendUInt32(try checkedUInt32(statement.rounds), to: &data)
        data.append(statement.initialEvaluationDigest)
        data.append(statement.finalVectorDigest)
        return data
    }

    private static func decodeSumcheckStatement(_ data: Data) throws -> M31SumcheckStatementV1 {
        var reader = CanonicalByteReader(data)
        let version = try reader.readUInt32()
        let laneCount = try readCount64(from: &reader)
        let rounds = Int(try reader.readUInt32())
        let initialEvaluationDigest = try reader.readBytes(count: 32)
        let finalVectorDigest = try reader.readBytes(count: 32)
        try reader.finish()
        return try M31SumcheckStatementV1(
            version: version,
            laneCount: laneCount,
            rounds: rounds,
            initialEvaluationDigest: initialEvaluationDigest,
            finalVectorDigest: finalVectorDigest
        )
    }

    static func encodePCSStatement(_ statement: CirclePCSFRIStatementV1) throws -> Data {
        var data = Data()
        try CanonicalBinary.appendLengthPrefixed(
            Data(statement.parameterSet.profileID.rawValue.utf8),
            to: &data
        )
        CanonicalBinary.appendUInt32(statement.parameterSet.securityParameters.logBlowupFactor, to: &data)
        CanonicalBinary.appendUInt32(statement.parameterSet.securityParameters.queryCount, to: &data)
        CanonicalBinary.appendUInt32(statement.parameterSet.securityParameters.foldingStep, to: &data)
        CanonicalBinary.appendUInt32(statement.parameterSet.securityParameters.grindingBits, to: &data)
        CanonicalBinary.appendUInt32(statement.parameterSet.targetSoundnessBits, to: &data)
        try CanonicalBinary.appendLengthPrefixed(
            try CircleDomainDescriptorCodecV1.encode(statement.polynomialClaim.domain),
            to: &data
        )
        appendQM31Elements(statement.polynomialClaim.polynomial.xCoefficients, to: &data)
        appendQM31Elements(statement.polynomialClaim.polynomial.yCoefficients, to: &data)
        CanonicalBinary.appendUInt64(UInt64(statement.polynomialClaim.evaluationClaims.count), to: &data)
        for claim in statement.polynomialClaim.evaluationClaims {
            CanonicalBinary.appendUInt64(claim.storageIndex, to: &data)
            appendPoint(claim.point, to: &data)
            data.append(QM31CanonicalEncoding.pack(claim.value))
        }
        return data
    }

    static func decodePCSStatement(_ data: Data) throws -> CirclePCSFRIStatementV1 {
        var reader = CanonicalByteReader(data)
        guard let profileString = String(
            data: try reader.readLengthPrefixed(),
            encoding: .utf8
        ),
              let profileID = CirclePCSFRIParameterSetV1.ProfileID(rawValue: profileString) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let logBlowupFactor = try reader.readUInt32()
        let queryCount = try reader.readUInt32()
        let foldingStep = try reader.readUInt32()
        let grindingBits = try reader.readUInt32()
        let targetSoundnessBits = try reader.readUInt32()
        let parameterSet = try CirclePCSFRIParameterSetV1(
            profileID: profileID,
            logBlowupFactor: logBlowupFactor,
            queryCount: queryCount,
            grindingBits: grindingBits,
            targetSoundnessBits: targetSoundnessBits
        )
        guard parameterSet.securityParameters.foldingStep == foldingStep else {
            throw AppleZKProverError.invalidInputLayout
        }
        let domain = try CircleDomainDescriptorCodecV1.decode(try reader.readLengthPrefixed())
        let polynomial = try CircleCodewordPolynomial(
            xCoefficients: readQM31Elements(from: &reader),
            yCoefficients: readQM31Elements(from: &reader)
        )
        let claimCount = try readCount64(from: &reader)
        var evaluationClaims: [CirclePCSFRIEvaluationClaimV1] = []
        evaluationClaims.reserveCapacity(claimCount)
        for _ in 0..<claimCount {
            evaluationClaims.append(try CirclePCSFRIEvaluationClaimV1(
                storageIndex: try reader.readUInt64(),
                point: readPoint(from: &reader),
                value: readQM31Element(from: &reader)
            ))
        }
        try reader.finish()
        let polynomialClaim = try CirclePCSFRIPolynomialClaimV1(
            domain: domain,
            polynomial: polynomial,
            evaluationClaims: evaluationClaims
        )
        return try CirclePCSFRIStatementV1(
            parameterSet: parameterSet,
            polynomialClaim: polynomialClaim
        )
    }

    private static func appendPoint(_ point: CirclePointM31, to data: inout Data) {
        CanonicalBinary.appendUInt32(point.x, to: &data)
        CanonicalBinary.appendUInt32(point.y, to: &data)
    }

    private static func readPoint(from reader: inout CanonicalByteReader) throws -> CirclePointM31 {
        let point = CirclePointM31(
            x: try reader.readUInt32(),
            y: try reader.readUInt32()
        )
        try CircleDomainOracle.validatePoint(point)
        return point
    }
}

public enum AIRConstraintMultilinearSumcheckProofCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x41, 0x43, 0x4d, 0x31, 0x00])

    public static func encode(_ proof: AIRConstraintMultilinearSumcheckProofV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(proof.version, to: &data)
        data.append(proof.airDefinitionDigest)
        CanonicalBinary.appendUInt64(UInt64(proof.traceRowCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(proof.traceColumnCount), to: &data)
        data.append(proof.airEvaluationDigest)
        try CanonicalBinary.appendLengthPrefixed(
            try M31MultilinearSumcheckProofCodecV1.encode(proof.sumcheckProof),
            to: &data
        )
        return data
    }

    public static func decode(_ data: Data) throws -> AIRConstraintMultilinearSumcheckProofV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let airDefinitionDigest = try reader.readBytes(count: 32)
        let traceRowCount = try readCount64(from: &reader)
        let traceColumnCount = try readCount64(from: &reader)
        let airEvaluationDigest = try reader.readBytes(count: 32)
        let sumcheckProof = try M31MultilinearSumcheckProofCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        try reader.finish()
        return try AIRConstraintMultilinearSumcheckProofV1(
            version: version,
            airDefinitionDigest: airDefinitionDigest,
            traceRowCount: traceRowCount,
            traceColumnCount: traceColumnCount,
            airEvaluationDigest: airEvaluationDigest,
            sumcheckProof: sumcheckProof
        )
    }
}

public enum AIRConstraintMultilinearSumcheckProofDigestV1 {
    private static let domain = Data("AppleZKProver.AIRConstraintMultilinearSumcheckProof.V1".utf8)

    public static func digest(_ proof: AIRConstraintMultilinearSumcheckProofV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        try CanonicalBinary.appendLengthPrefixed(
            try AIRConstraintMultilinearSumcheckProofCodecV1.encode(proof),
            to: &data
        )
        return SHA3Oracle.sha3_256(data)
    }
}

public enum AIRRowDomainTracePCSProofBundleCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x52, 0x54, 0x50, 0x31, 0x00])

    public static func encode(_ bundle: AIRRowDomainTracePCSProofBundleV1) throws -> Data {
        var data = Data()
        data.append(magic)
        try CanonicalBinary.appendLengthPrefixed(
            try CircleDomainDescriptorCodecV1.encode(bundle.witness.domain),
            to: &data
        )
        CanonicalBinary.appendUInt32(bundle.witness.variant.rawValue, to: &data)
        CanonicalBinary.appendUInt64(UInt64(bundle.witness.traceRowCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(bundle.witness.traceColumnCount), to: &data)
        data.append(bundle.witness.sourceTracePolynomialDigest)
        try appendIntList(bundle.witness.claimedStorageIndices, to: &data)
        try CanonicalBinary.appendLengthPrefixed(
            try parameterSetBytes(bundle.parameterSet),
            to: &data
        )
        CanonicalBinary.appendUInt64(UInt64(bundle.chunks.count), to: &data)
        for chunk in bundle.chunks {
            CanonicalBinary.appendUInt64(UInt64(chunk.chunkIndex), to: &data)
            try appendIntList(chunk.sourceColumnIndices, to: &data)
            try CanonicalBinary.appendLengthPrefixed(
                try ApplicationProofStatementCodecV1.encodePCSStatement(chunk.statement),
                to: &data
            )
            try CanonicalBinary.appendLengthPrefixed(
                try CirclePCSFRIProofCodecV1.encode(chunk.proof),
                to: &data
            )
        }
        return data
    }

    public static func decode(_ data: Data) throws -> AIRRowDomainTracePCSProofBundleV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let domain = try CircleDomainDescriptorCodecV1.decode(try reader.readLengthPrefixed())
        guard let variant = AIRRowDomainTracePCSVariantV1(rawValue: try reader.readUInt32()) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let traceRowCount = try readCount64(from: &reader)
        let traceColumnCount = try readCount64(from: &reader)
        let sourceTracePolynomialDigest = try reader.readBytes(count: 32)
        let claimedStorageIndices = try readIntList(from: &reader)
        let parameterSet = try readParameterSet(
            from: CanonicalByteReader(try reader.readLengthPrefixed())
        )
        let chunkCount = try readCount64(from: &reader)
        var witnessChunks: [AIRRowDomainTracePCSChunkV1] = []
        witnessChunks.reserveCapacity(chunkCount)
        var proofChunks: [AIRRowDomainTracePCSProofChunkV1] = []
        proofChunks.reserveCapacity(chunkCount)

        for _ in 0..<chunkCount {
            let chunkIndex = try readCount64(from: &reader)
            let sourceColumnIndices = try readIntList(from: &reader)
            let statement = try ApplicationProofStatementCodecV1.decodePCSStatement(
                try reader.readLengthPrefixed()
            )
            let proof = try CirclePCSFRIProofCodecV1.decode(
                try reader.readLengthPrefixed()
            )
            witnessChunks.append(try AIRRowDomainTracePCSChunkV1(
                chunkIndex: chunkIndex,
                sourceColumnIndices: sourceColumnIndices,
                polynomial: statement.polynomialClaim.polynomial,
                polynomialClaim: statement.polynomialClaim
            ))
            proofChunks.append(try AIRRowDomainTracePCSProofChunkV1(
                chunkIndex: chunkIndex,
                sourceColumnIndices: sourceColumnIndices,
                statement: statement,
                proof: proof
            ))
        }
        try reader.finish()

        let witness = try AIRRowDomainTracePCSWitnessV1(
            domain: domain,
            variant: variant,
            traceRowCount: traceRowCount,
            traceColumnCount: traceColumnCount,
            sourceTracePolynomialDigest: sourceTracePolynomialDigest,
            claimedStorageIndices: claimedStorageIndices,
            chunks: witnessChunks
        )
        return try AIRRowDomainTracePCSProofBundleV1(
            witness: witness,
            parameterSet: parameterSet,
            chunks: proofChunks
        )
    }

    private static func appendIntList(_ values: [Int], to data: inout Data) throws {
        CanonicalBinary.appendUInt64(UInt64(values.count), to: &data)
        for value in values {
            guard value >= 0 else {
                throw AppleZKProverError.invalidInputLayout
            }
            CanonicalBinary.appendUInt64(UInt64(value), to: &data)
        }
    }

    private static func readIntList(from reader: inout CanonicalByteReader) throws -> [Int] {
        let count = try readCount64(from: &reader)
        var values: [Int] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            values.append(try readCount64(from: &reader))
        }
        return values
    }

    private static func parameterSetBytes(_ parameterSet: CirclePCSFRIParameterSetV1) throws -> Data {
        var data = Data()
        try CanonicalBinary.appendLengthPrefixed(
            Data(parameterSet.profileID.rawValue.utf8),
            to: &data
        )
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.logBlowupFactor, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.queryCount, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.foldingStep, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.securityParameters.grindingBits, to: &data)
        CanonicalBinary.appendUInt32(parameterSet.targetSoundnessBits, to: &data)
        return data
    }

    private static func readParameterSet(
        from byteReader: CanonicalByteReader
    ) throws -> CirclePCSFRIParameterSetV1 {
        var reader = byteReader
        guard let profileString = String(
            data: try reader.readLengthPrefixed(),
            encoding: .utf8
        ),
              let profileID = CirclePCSFRIParameterSetV1.ProfileID(rawValue: profileString) else {
            throw AppleZKProverError.invalidInputLayout
        }
        let logBlowupFactor = try reader.readUInt32()
        let queryCount = try reader.readUInt32()
        let foldingStep = try reader.readUInt32()
        let grindingBits = try reader.readUInt32()
        let targetSoundnessBits = try reader.readUInt32()
        try reader.finish()
        let parameterSet = try CirclePCSFRIParameterSetV1(
            profileID: profileID,
            logBlowupFactor: logBlowupFactor,
            queryCount: queryCount,
            grindingBits: grindingBits,
            targetSoundnessBits: targetSoundnessBits
        )
        guard parameterSet.securityParameters.foldingStep == foldingStep else {
            throw AppleZKProverError.invalidInputLayout
        }
        return parameterSet
    }
}

public enum AIRRowDomainTracePCSProofBundleDigestV1 {
    private static let domain = Data("AppleZKProver.AIRRowDomainTracePCSProofBundle.V1".utf8)

    public static func digest(_ bundle: AIRRowDomainTracePCSProofBundleV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        try CanonicalBinary.appendLengthPrefixed(
            try AIRRowDomainTracePCSProofBundleCodecV1.encode(bundle),
            to: &data
        )
        return SHA3Oracle.sha3_256(data)
    }
}

public enum AIRQuotientIdentityOpeningQueryPlanCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x51, 0x49, 0x50, 0x31, 0x00])

    public static func encode(_ plan: AIRQuotientIdentityOpeningQueryPlanV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(plan.version, to: &data)
        CanonicalBinary.appendUInt64(UInt64(plan.traceRowCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(plan.traceColumnCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(plan.quotientPolynomialCount), to: &data)
        CanonicalBinary.appendUInt64(UInt64(plan.queryCount), to: &data)
        data.append(plan.airDefinitionDigest)
        data.append(plan.quotientProofDigest)
        data.append(plan.commitmentDigest)
        try appendIntList(plan.claimedStorageIndices, to: &data)
        return data
    }

    public static func decode(_ data: Data) throws -> AIRQuotientIdentityOpeningQueryPlanV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let traceRowCount = try readCount64(from: &reader)
        let traceColumnCount = try readCount64(from: &reader)
        let quotientPolynomialCount = try readCount64(from: &reader)
        let queryCount = try readCount64(from: &reader)
        let airDefinitionDigest = try reader.readBytes(count: 32)
        let quotientProofDigest = try reader.readBytes(count: 32)
        let commitmentDigest = try reader.readBytes(count: 32)
        let claimedStorageIndices = try readIntList(from: &reader)
        try reader.finish()
        return try AIRQuotientIdentityOpeningQueryPlanV1(
            version: version,
            traceRowCount: traceRowCount,
            traceColumnCount: traceColumnCount,
            quotientPolynomialCount: quotientPolynomialCount,
            queryCount: queryCount,
            airDefinitionDigest: airDefinitionDigest,
            quotientProofDigest: quotientProofDigest,
            commitmentDigest: commitmentDigest,
            claimedStorageIndices: claimedStorageIndices
        )
    }

    private static func appendIntList(_ values: [Int], to data: inout Data) throws {
        CanonicalBinary.appendUInt64(UInt64(values.count), to: &data)
        for value in values {
            guard value >= 0 else {
                throw AppleZKProverError.invalidInputLayout
            }
            CanonicalBinary.appendUInt64(UInt64(value), to: &data)
        }
    }

    private static func readIntList(from reader: inout CanonicalByteReader) throws -> [Int] {
        let count = try readCount64(from: &reader)
        var values: [Int] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            values.append(try readCount64(from: &reader))
        }
        return values
    }
}

public enum AIRSharedDomainQuotientIdentityPCSProofBundleCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x53, 0x51, 0x49, 0x31, 0x00])

    public static func encode(_ bundle: AIRSharedDomainQuotientIdentityPCSProofBundleV1) throws -> Data {
        var data = Data()
        data.append(magic)
        try CanonicalBinary.appendLengthPrefixed(
            try AIRQuotientIdentityOpeningQueryPlanCodecV1.encode(bundle.queryPlan),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try AIRRowDomainTracePCSProofBundleCodecV1.encode(bundle.currentTracePCSProofBundle),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try AIRRowDomainTracePCSProofBundleCodecV1.encode(bundle.nextTracePCSProofBundle),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try AIRQuotientCirclePCSProofBundleCodecV1.encode(bundle.quotientPCSProofBundle),
            to: &data
        )
        return data
    }

    public static func decode(_ data: Data) throws -> AIRSharedDomainQuotientIdentityPCSProofBundleV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let queryPlan = try AIRQuotientIdentityOpeningQueryPlanCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        let currentTracePCSProofBundle = try AIRRowDomainTracePCSProofBundleCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        let nextTracePCSProofBundle = try AIRRowDomainTracePCSProofBundleCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        let quotientPCSProofBundle = try AIRQuotientCirclePCSProofBundleCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        try reader.finish()
        return try AIRSharedDomainQuotientIdentityPCSProofBundleV1(
            queryPlan: queryPlan,
            currentTracePCSProofBundle: currentTracePCSProofBundle,
            nextTracePCSProofBundle: nextTracePCSProofBundle,
            quotientPCSProofBundle: quotientPCSProofBundle
        )
    }
}

public enum AIRSharedDomainQuotientIdentityPCSProofBundleDigestV1 {
    private static let domain = Data("AppleZKProver.AIRSharedDomainQuotientIdentityPCSProofBundle.V1".utf8)

    public static func digest(_ bundle: AIRSharedDomainQuotientIdentityPCSProofBundleV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        try CanonicalBinary.appendLengthPrefixed(
            try AIRSharedDomainQuotientIdentityPCSProofBundleCodecV1.encode(bundle),
            to: &data
        )
        return SHA3Oracle.sha3_256(data)
    }
}

public enum ApplicationPublicTheoremArtifactCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x50, 0x54, 0x56, 0x31, 0x00])

    public static func encode(_ artifact: ApplicationPublicTheoremArtifactV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(artifact.version, to: &data)
        try CanonicalBinary.appendLengthPrefixed(
            try ApplicationProofStatementCodecV1.encode(artifact.statement),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try ApplicationProofCodecV1.encode(artifact.proof),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try ApplicationWitnessTraceCodecV1.encode(artifact.witness),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try AIRDefinitionCodecV1.encode(artifact.airDefinition),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try GKRClaimCodecV1.encode(artifact.gkrClaim),
            to: &data
        )
        return data
    }

    public static func decode(_ data: Data) throws -> ApplicationPublicTheoremArtifactV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let statement = try ApplicationProofStatementCodecV1.decode(try reader.readLengthPrefixed())
        let proof = try ApplicationProofCodecV1.decode(try reader.readLengthPrefixed())
        let witness = try ApplicationWitnessTraceCodecV1.decode(try reader.readLengthPrefixed())
        let airDefinition = try AIRDefinitionCodecV1.decode(try reader.readLengthPrefixed())
        let gkrClaim = try GKRClaimCodecV1.decode(try reader.readLengthPrefixed())
        try reader.finish()
        return try ApplicationPublicTheoremArtifactV1(
            version: version,
            statement: statement,
            proof: proof,
            witness: witness,
            airDefinition: airDefinition,
            gkrClaim: gkrClaim
        )
    }
}

public enum ApplicationPublicTheoremIntegratedArtifactCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x50, 0x54, 0x49, 0x31, 0x00])

    public static func encode(_ artifact: ApplicationPublicTheoremIntegratedArtifactV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(artifact.version, to: &data)
        try CanonicalBinary.appendLengthPrefixed(
            try ApplicationPublicTheoremArtifactCodecV1.encode(artifact.publicTheoremArtifact),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try AIRConstraintMultilinearSumcheckProofCodecV1.encode(artifact.airConstraintSumcheckProof),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try AIRSharedDomainQuotientIdentityPCSProofBundleCodecV1.encode(
                artifact.quotientIdentityPCSProofBundle
            ),
            to: &data
        )
        return data
    }

    public static func decode(_ data: Data) throws -> ApplicationPublicTheoremIntegratedArtifactV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let publicTheoremArtifact = try ApplicationPublicTheoremArtifactCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        let airConstraintSumcheckProof = try AIRConstraintMultilinearSumcheckProofCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        let quotientIdentityPCSProofBundle = try AIRSharedDomainQuotientIdentityPCSProofBundleCodecV1
            .decode(try reader.readLengthPrefixed())
        try reader.finish()
        return try ApplicationPublicTheoremIntegratedArtifactV1(
            version: version,
            publicTheoremArtifact: publicTheoremArtifact,
            airConstraintSumcheckProof: airConstraintSumcheckProof,
            quotientIdentityPCSProofBundle: quotientIdentityPCSProofBundle
        )
    }
}

public enum ApplicationPublicTheoremIntegratedArtifactDigestV1 {
    private static let domain = Data("AppleZKProver.ApplicationPublicTheoremIntegratedArtifact.V1".utf8)

    public static func digest(_ artifact: ApplicationPublicTheoremIntegratedArtifactV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        try CanonicalBinary.appendLengthPrefixed(
            try ApplicationPublicTheoremIntegratedArtifactCodecV1.encode(artifact),
            to: &data
        )
        return SHA3Oracle.sha3_256(data)
    }
}

public enum ApplicationPublicTheoremTracePCSArtifactCodecV1 {
    private static let magic = Data([0x41, 0x5a, 0x4b, 0x50, 0x54, 0x50, 0x43, 0x31])

    public static func encode(_ artifact: ApplicationPublicTheoremTracePCSArtifactV1) throws -> Data {
        var data = Data()
        data.append(magic)
        CanonicalBinary.appendUInt32(artifact.version, to: &data)
        try CanonicalBinary.appendLengthPrefixed(
            try ApplicationPublicTheoremArtifactCodecV1.encode(artifact.publicTheoremArtifact),
            to: &data
        )
        try CanonicalBinary.appendLengthPrefixed(
            try AIRTraceCirclePCSProofBundleCodecV1.encode(artifact.tracePCSProofBundle),
            to: &data
        )
        return data
    }

    public static func decode(_ data: Data) throws -> ApplicationPublicTheoremTracePCSArtifactV1 {
        var reader = CanonicalByteReader(data)
        guard try reader.readBytes(count: magic.count) == magic else {
            throw AppleZKProverError.invalidInputLayout
        }
        let version = try reader.readUInt32()
        let publicTheoremArtifact = try ApplicationPublicTheoremArtifactCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        let tracePCSProofBundle = try AIRTraceCirclePCSProofBundleCodecV1.decode(
            try reader.readLengthPrefixed()
        )
        try reader.finish()
        return try ApplicationPublicTheoremTracePCSArtifactV1(
            version: version,
            publicTheoremArtifact: publicTheoremArtifact,
            tracePCSProofBundle: tracePCSProofBundle
        )
    }
}

public enum ApplicationPublicTheoremTracePCSArtifactDigestV1 {
    private static let domain = Data("AppleZKProver.ApplicationPublicTheoremTracePCSArtifact.V1".utf8)

    public static func digest(_ artifact: ApplicationPublicTheoremTracePCSArtifactV1) throws -> Data {
        var data = Data()
        CanonicalBinary.appendUInt32(UInt32(domain.count), to: &data)
        data.append(domain)
        try CanonicalBinary.appendLengthPrefixed(
            try ApplicationPublicTheoremTracePCSArtifactCodecV1.encode(artifact),
            to: &data
        )
        return SHA3Oracle.sha3_256(data)
    }
}

private func appendM31Words(_ words: [UInt32], to data: inout Data) {
    CanonicalBinary.appendUInt64(UInt64(words.count), to: &data)
    for word in words {
        CanonicalBinary.appendUInt32(word, to: &data)
    }
}

private func readM31Words(from reader: inout CanonicalByteReader) throws -> [UInt32] {
    let count = try readCount64(from: &reader)
    var words: [UInt32] = []
    words.reserveCapacity(count)
    for _ in 0..<count {
        words.append(try reader.readUInt32())
    }
    try M31Field.validateCanonical(words)
    return words
}

private func appendQM31Elements(_ elements: [QM31Element], to data: inout Data) {
    CanonicalBinary.appendUInt64(UInt64(elements.count), to: &data)
    data.append(QM31CanonicalEncoding.pack(elements))
}

private func readQM31Elements(from reader: inout CanonicalByteReader) throws -> [QM31Element] {
    let count = try readCount64(from: &reader)
    let byteCount = try checkedBufferLength(count, QM31CanonicalEncoding.elementByteCount)
    return try QM31CanonicalEncoding.unpackMany(
        try reader.readBytes(count: byteCount),
        count: count
    )
}

private func readQM31Element(from reader: inout CanonicalByteReader) throws -> QM31Element {
    try QM31CanonicalEncoding.unpack(
        try reader.readBytes(count: QM31CanonicalEncoding.elementByteCount)
    )
}

private func readCount64(from reader: inout CanonicalByteReader) throws -> Int {
    let count = try reader.readUInt64()
    guard count <= UInt64(Int.max) else {
        throw AppleZKProverError.invalidInputLayout
    }
    return Int(count)
}
