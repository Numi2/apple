import Foundation

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
