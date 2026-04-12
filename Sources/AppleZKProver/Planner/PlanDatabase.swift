import Foundation

public struct PlanRaceResult: Sendable {
    public let record: PlanRecord
    public let measuredSpec: KernelSpec
    public let isWinner: Bool

    public init(record: PlanRecord, measuredSpec: KernelSpec, isWinner: Bool) {
        self.record = record
        self.measuredSpec = measuredSpec
        self.isWinner = isWinner
    }
}

public struct PlanDriftPolicy: Sendable {
    public var emaAlpha: Double
    public var relativeThreshold: Double
    public var minimumSamples: Int

    public init(
        emaAlpha: Double = 0.2,
        relativeThreshold: Double = 0.25,
        minimumSamples: Int = 8
    ) {
        self.emaAlpha = min(1, max(0.01, emaAlpha))
        self.relativeThreshold = max(0.01, relativeThreshold)
        self.minimumSamples = max(1, minimumSamples)
    }

    public static let `default` = PlanDriftPolicy()
}

public enum PlanDriftStatus: Equatable, Sendable {
    case stable(sampleCount: Int, emaGPUTimeNS: Double, emaCPUSubmitNS: Double)
    case stale(sampleCount: Int, relativeDrift: Double)
}

#if canImport(SQLite3)
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class PlanDatabase: @unchecked Sendable {
    private let database: OpaquePointer?
    private let lock = NSLock()

    public init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(db)
            throw AppleZKProverError.failedToOpenPlanDatabase(message)
        }
        database = db
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA synchronous=NORMAL")
        try migrate()
    }

    deinit {
        sqlite3_close(database)
    }

    public func recordRaceResult(_ result: PlanRaceResult) throws {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        INSERT INTO plan_race_results (
            created_at, registry_id, device_name, os_build,
            supports_apple4, supports_apple7, supports_apple9, supports_metal4_queue,
            max_threads_per_threadgroup, has_unified_memory,
            stage, field, input_log2, leaf_bytes, arity, rounds_per_superstep, fixed_width_case,
            kernel, family, queue_mode, function_constants, threads_per_threadgroup, simdgroups_per_threadgroup,
            median_gpu_time_ns, median_cpu_submit_ns, p95_gpu_time_ns, readbacks, confidence,
            shader_hash, protocol_hash, is_winner
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        try withStatement(sql) { statement in
            let record = result.record
            let device = record.device
            let workload = record.workload
            let spec = result.measuredSpec
            bindText(iso8601Now(), to: statement, at: 1)
            sqlite3_bind_int64(statement, 2, sqlite3_int64(bitPattern: device.registryID))
            bindText(device.name, to: statement, at: 3)
            bindText(device.osBuild, to: statement, at: 4)
            bindBool(device.supportsApple4, to: statement, at: 5)
            bindBool(device.supportsApple7, to: statement, at: 6)
            bindBool(device.supportsApple9, to: statement, at: 7)
            bindBool(device.supportsMetal4Queue, to: statement, at: 8)
            sqlite3_bind_int(statement, 9, Int32(device.maxThreadsPerThreadgroup))
            bindBool(device.hasUnifiedMemory, to: statement, at: 10)
            bindText(workload.stage.rawValue, to: statement, at: 11)
            bindText(workload.field.rawValue, to: statement, at: 12)
            sqlite3_bind_int(statement, 13, Int32(workload.inputLog2))
            sqlite3_bind_int(statement, 14, Int32(workload.leafBytes))
            sqlite3_bind_int(statement, 15, Int32(workload.arity))
            sqlite3_bind_int(statement, 16, Int32(workload.roundsPerSuperstep))
            sqlite3_bind_int(statement, 17, Int32(workload.fixedWidthCase))
            bindText(spec.kernel, to: statement, at: 18)
            bindText(spec.family.rawValue, to: statement, at: 19)
            bindText(spec.queueMode.rawValue, to: statement, at: 20)
            bindText(Self.encodeFunctionConstants(spec.functionConstants), to: statement, at: 21)
            sqlite3_bind_int(statement, 22, Int32(spec.threadsPerThreadgroup))
            sqlite3_bind_int(statement, 23, Int32(spec.simdgroupsPerThreadgroup))
            sqlite3_bind_double(statement, 24, record.medianGPUTimeNS)
            sqlite3_bind_double(statement, 25, record.medianCPUSubmitNS)
            sqlite3_bind_double(statement, 26, record.p95GPUTimeNS)
            sqlite3_bind_int(statement, 27, Int32(record.readbacks))
            sqlite3_bind_double(statement, 28, record.confidence)
            bindText(record.shaderHash, to: statement, at: 29)
            bindText(record.protocolHash, to: statement, at: 30)
            bindBool(result.isWinner, to: statement, at: 31)
            try step(statement)
        }
    }

    public func latestWinner(
        device: DeviceFingerprint,
        workload: WorkloadSignature,
        shaderHash: String,
        protocolHash: String
    ) throws -> PlanRecord? {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        SELECT kernel, family, queue_mode, function_constants, threads_per_threadgroup, simdgroups_per_threadgroup,
               median_gpu_time_ns, median_cpu_submit_ns, p95_gpu_time_ns, readbacks, confidence
        FROM plan_race_results
        WHERE registry_id = ? AND os_build = ? AND stage = ? AND field = ? AND input_log2 = ?
          AND leaf_bytes = ? AND arity = ? AND rounds_per_superstep = ? AND fixed_width_case = ?
          AND shader_hash = ? AND protocol_hash = ? AND is_winner = 1
        ORDER BY id DESC
        LIMIT 1
        """
        return try withStatement(sql) { statement in
            sqlite3_bind_int64(statement, 1, sqlite3_int64(bitPattern: device.registryID))
            bindText(device.osBuild, to: statement, at: 2)
            bindText(workload.stage.rawValue, to: statement, at: 3)
            bindText(workload.field.rawValue, to: statement, at: 4)
            sqlite3_bind_int(statement, 5, Int32(workload.inputLog2))
            sqlite3_bind_int(statement, 6, Int32(workload.leafBytes))
            sqlite3_bind_int(statement, 7, Int32(workload.arity))
            sqlite3_bind_int(statement, 8, Int32(workload.roundsPerSuperstep))
            sqlite3_bind_int(statement, 9, Int32(workload.fixedWidthCase))
            bindText(shaderHash, to: statement, at: 10)
            bindText(protocolHash, to: statement, at: 11)

            let result = sqlite3_step(statement)
            guard result == SQLITE_ROW else {
                if result == SQLITE_DONE {
                    return nil
                }
                throw AppleZKProverError.failedToUpdatePlanDatabase(errorMessage())
            }

            let kernel = columnText(statement, 0)
            let family = KernelSpec.Family(rawValue: columnText(statement, 1)) ?? .scalar
            let queueMode = KernelSpec.QueueMode(rawValue: columnText(statement, 2)) ?? .metal3
            let constants = Self.decodeFunctionConstants(columnText(statement, 3))
            let winner = KernelSpec(
                kernel: kernel,
                family: family,
                queueMode: queueMode,
                functionConstants: constants,
                threadsPerThreadgroup: UInt16(clamping: sqlite3_column_int(statement, 4)),
                simdgroupsPerThreadgroup: UInt8(clamping: sqlite3_column_int(statement, 5))
            )
            return PlanRecord(
                device: device,
                workload: workload,
                winner: winner,
                medianGPUTimeNS: sqlite3_column_double(statement, 6),
                medianCPUSubmitNS: sqlite3_column_double(statement, 7),
                p95GPUTimeNS: sqlite3_column_double(statement, 8),
                readbacks: Int(sqlite3_column_int(statement, 9)),
                confidence: sqlite3_column_double(statement, 10),
                shaderHash: shaderHash,
                protocolHash: protocolHash
            )
        }
    }

    public func recordLiveObservation(
        for record: PlanRecord,
        gpuTimeNS: Double,
        cpuSubmitNS: Double,
        policy: PlanDriftPolicy = .default
    ) throws -> PlanDriftStatus {
        lock.lock()
        defer { lock.unlock() }

        let key = ObservationKey(record: record)
        let existing = try latestObservation(for: key)
        let sampleCount = (existing?.sampleCount ?? 0) + 1
        let emaGPUTimeNS = Self.updatedEMA(
            previous: existing?.emaGPUTimeNS,
            observed: gpuTimeNS,
            alpha: policy.emaAlpha
        )
        let emaCPUSubmitNS = Self.updatedEMA(
            previous: existing?.emaCPUSubmitNS,
            observed: cpuSubmitNS,
            alpha: policy.emaAlpha
        )
        let baseline = max(1, record.medianGPUTimeNS + record.medianCPUSubmitNS)
        let observed = emaGPUTimeNS + emaCPUSubmitNS
        let relativeDrift = abs(observed - baseline) / baseline
        let isStale = sampleCount >= policy.minimumSamples && relativeDrift > policy.relativeThreshold

        try upsertObservation(
            key: key,
            sampleCount: sampleCount,
            emaGPUTimeNS: emaGPUTimeNS,
            emaCPUSubmitNS: emaCPUSubmitNS,
            relativeDrift: relativeDrift,
            isStale: isStale
        )

        if isStale {
            return .stale(sampleCount: sampleCount, relativeDrift: relativeDrift)
        }
        return .stable(
            sampleCount: sampleCount,
            emaGPUTimeNS: emaGPUTimeNS,
            emaCPUSubmitNS: emaCPUSubmitNS
        )
    }

    private func migrate() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS plan_race_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL,
                registry_id INTEGER NOT NULL,
                device_name TEXT NOT NULL,
                os_build TEXT NOT NULL,
                supports_apple4 INTEGER NOT NULL,
                supports_apple7 INTEGER NOT NULL,
                supports_apple9 INTEGER NOT NULL,
                supports_metal4_queue INTEGER NOT NULL,
                max_threads_per_threadgroup INTEGER NOT NULL,
                has_unified_memory INTEGER NOT NULL,
                stage TEXT NOT NULL,
                field TEXT NOT NULL,
                input_log2 INTEGER NOT NULL,
                leaf_bytes INTEGER NOT NULL,
                arity INTEGER NOT NULL,
                rounds_per_superstep INTEGER NOT NULL,
                fixed_width_case INTEGER NOT NULL,
                kernel TEXT NOT NULL,
                family TEXT NOT NULL,
                queue_mode TEXT NOT NULL,
                function_constants TEXT NOT NULL,
                threads_per_threadgroup INTEGER NOT NULL,
                simdgroups_per_threadgroup INTEGER NOT NULL,
                median_gpu_time_ns REAL NOT NULL,
                median_cpu_submit_ns REAL NOT NULL,
                p95_gpu_time_ns REAL NOT NULL,
                readbacks INTEGER NOT NULL,
                confidence REAL NOT NULL,
                shader_hash TEXT NOT NULL,
                protocol_hash TEXT NOT NULL,
                is_winner INTEGER NOT NULL
            )
            """
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS plan_race_results_lookup
            ON plan_race_results (
                registry_id, os_build, stage, field, input_log2, leaf_bytes, arity,
                rounds_per_superstep, fixed_width_case, shader_hash, protocol_hash, is_winner, id
            )
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS plan_runtime_observations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                registry_id INTEGER NOT NULL,
                os_build TEXT NOT NULL,
                stage TEXT NOT NULL,
                field TEXT NOT NULL,
                input_log2 INTEGER NOT NULL,
                leaf_bytes INTEGER NOT NULL,
                arity INTEGER NOT NULL,
                rounds_per_superstep INTEGER NOT NULL,
                fixed_width_case INTEGER NOT NULL,
                shader_hash TEXT NOT NULL,
                protocol_hash TEXT NOT NULL,
                kernel TEXT NOT NULL,
                family TEXT NOT NULL,
                queue_mode TEXT NOT NULL,
                function_constants TEXT NOT NULL,
                sample_count INTEGER NOT NULL,
                ema_gpu_time_ns REAL NOT NULL,
                ema_cpu_submit_ns REAL NOT NULL,
                relative_drift REAL NOT NULL,
                is_stale INTEGER NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE (
                    registry_id, os_build, stage, field, input_log2, leaf_bytes, arity,
                    rounds_per_superstep, fixed_width_case, shader_hash, protocol_hash,
                    kernel, family, queue_mode, function_constants
                )
            )
            """
        )
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw AppleZKProverError.failedToUpdatePlanDatabase(errorMessage())
        }
    }

    private func withStatement<T>(_ sql: String, body: (OpaquePointer?) throws -> T) throws -> T {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw AppleZKProverError.failedToUpdatePlanDatabase(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    private func errorMessage() -> String {
        guard let database else {
            return "database is closed"
        }
        return String(cString: sqlite3_errmsg(database))
    }

    private static func encodeFunctionConstants(_ constants: [UInt16: UInt64]) -> String {
        constants
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ";")
    }

    private static func decodeFunctionConstants(_ encoded: String) -> [UInt16: UInt64] {
        guard !encoded.isEmpty else {
            return [:]
        }

        var constants: [UInt16: UInt64] = [:]
        for pair in encoded.split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2,
                  let key = UInt16(parts[0]),
                  let value = UInt64(parts[1]) else {
                continue
            }
            constants[key] = value
        }
        return constants
    }

    private func latestObservation(for key: ObservationKey) throws -> RuntimeObservation? {
        let sql = """
        SELECT sample_count, ema_gpu_time_ns, ema_cpu_submit_ns
        FROM plan_runtime_observations
        WHERE registry_id = ? AND os_build = ? AND stage = ? AND field = ? AND input_log2 = ?
          AND leaf_bytes = ? AND arity = ? AND rounds_per_superstep = ? AND fixed_width_case = ?
          AND shader_hash = ? AND protocol_hash = ? AND kernel = ? AND family = ?
          AND queue_mode = ? AND function_constants = ?
        LIMIT 1
        """
        return try withStatement(sql) { statement in
            bindObservationKey(key, to: statement)
            let result = sqlite3_step(statement)
            guard result == SQLITE_ROW else {
                if result == SQLITE_DONE {
                    return nil
                }
                throw AppleZKProverError.failedToUpdatePlanDatabase(errorMessage())
            }
            return RuntimeObservation(
                sampleCount: Int(sqlite3_column_int(statement, 0)),
                emaGPUTimeNS: sqlite3_column_double(statement, 1),
                emaCPUSubmitNS: sqlite3_column_double(statement, 2)
            )
        }
    }

    private func upsertObservation(
        key: ObservationKey,
        sampleCount: Int,
        emaGPUTimeNS: Double,
        emaCPUSubmitNS: Double,
        relativeDrift: Double,
        isStale: Bool
    ) throws {
        let sql = """
        INSERT INTO plan_runtime_observations (
            registry_id, os_build, stage, field, input_log2, leaf_bytes, arity,
            rounds_per_superstep, fixed_width_case, shader_hash, protocol_hash,
            kernel, family, queue_mode, function_constants,
            sample_count, ema_gpu_time_ns, ema_cpu_submit_ns, relative_drift, is_stale, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (
            registry_id, os_build, stage, field, input_log2, leaf_bytes, arity,
            rounds_per_superstep, fixed_width_case, shader_hash, protocol_hash,
            kernel, family, queue_mode, function_constants
        ) DO UPDATE SET
            sample_count = excluded.sample_count,
            ema_gpu_time_ns = excluded.ema_gpu_time_ns,
            ema_cpu_submit_ns = excluded.ema_cpu_submit_ns,
            relative_drift = excluded.relative_drift,
            is_stale = excluded.is_stale,
            updated_at = excluded.updated_at
        """
        try withStatement(sql) { statement in
            bindObservationKey(key, to: statement)
            sqlite3_bind_int(statement, 16, Int32(sampleCount))
            sqlite3_bind_double(statement, 17, emaGPUTimeNS)
            sqlite3_bind_double(statement, 18, emaCPUSubmitNS)
            sqlite3_bind_double(statement, 19, relativeDrift)
            bindBool(isStale, to: statement, at: 20)
            bindText(iso8601Now(), to: statement, at: 21)
            try step(statement)
        }
    }

    private func bindObservationKey(_ key: ObservationKey, to statement: OpaquePointer?) {
        sqlite3_bind_int64(statement, 1, sqlite3_int64(bitPattern: key.registryID))
        bindText(key.osBuild, to: statement, at: 2)
        bindText(key.stage, to: statement, at: 3)
        bindText(key.field, to: statement, at: 4)
        sqlite3_bind_int(statement, 5, Int32(key.inputLog2))
        sqlite3_bind_int(statement, 6, Int32(key.leafBytes))
        sqlite3_bind_int(statement, 7, Int32(key.arity))
        sqlite3_bind_int(statement, 8, Int32(key.roundsPerSuperstep))
        sqlite3_bind_int(statement, 9, Int32(key.fixedWidthCase))
        bindText(key.shaderHash, to: statement, at: 10)
        bindText(key.protocolHash, to: statement, at: 11)
        bindText(key.kernel, to: statement, at: 12)
        bindText(key.family, to: statement, at: 13)
        bindText(key.queueMode, to: statement, at: 14)
        bindText(key.functionConstants, to: statement, at: 15)
    }

    private static func updatedEMA(previous: Double?, observed: Double, alpha: Double) -> Double {
        guard let previous else {
            return observed
        }
        return alpha * observed + (1 - alpha) * previous
    }
}

private struct ObservationKey {
    let registryID: UInt64
    let osBuild: String
    let stage: String
    let field: String
    let inputLog2: UInt8
    let leafBytes: UInt16
    let arity: UInt8
    let roundsPerSuperstep: UInt8
    let fixedWidthCase: UInt16
    let shaderHash: String
    let protocolHash: String
    let kernel: String
    let family: String
    let queueMode: String
    let functionConstants: String

    init(record: PlanRecord) {
        registryID = record.device.registryID
        osBuild = record.device.osBuild
        stage = record.workload.stage.rawValue
        field = record.workload.field.rawValue
        inputLog2 = record.workload.inputLog2
        leafBytes = record.workload.leafBytes
        arity = record.workload.arity
        roundsPerSuperstep = record.workload.roundsPerSuperstep
        fixedWidthCase = record.workload.fixedWidthCase
        shaderHash = record.shaderHash
        protocolHash = record.protocolHash
        kernel = record.winner.kernel
        family = record.winner.family.rawValue
        queueMode = record.winner.queueMode.rawValue
        functionConstants = Self.encodeFunctionConstants(record.winner.functionConstants)
    }

    private static func encodeFunctionConstants(_ constants: [UInt16: UInt64]) -> String {
        constants
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ";")
    }
}

private struct RuntimeObservation {
    let sampleCount: Int
    let emaGPUTimeNS: Double
    let emaCPUSubmitNS: Double
}

private func bindText(_ value: String, to statement: OpaquePointer?, at index: Int32) {
    sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
}

private func bindBool(_ value: Bool, to statement: OpaquePointer?, at index: Int32) {
    sqlite3_bind_int(statement, index, value ? 1 : 0)
}

private func step(_ statement: OpaquePointer?) throws {
    guard sqlite3_step(statement) == SQLITE_DONE else {
        throw AppleZKProverError.failedToUpdatePlanDatabase("sqlite step failed")
    }
}

private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
    guard let text = sqlite3_column_text(statement, index) else {
        return ""
    }
    return String(cString: text)
}

private func iso8601Now() -> String {
    ISO8601DateFormatter().string(from: Date())
}

#else
public final class PlanDatabase: @unchecked Sendable {
    public init(url: URL) throws {
        throw AppleZKProverError.failedToOpenPlanDatabase("SQLite3 is unavailable on this platform.")
    }

    public func recordRaceResult(_ result: PlanRaceResult) throws {
        throw AppleZKProverError.failedToOpenPlanDatabase("SQLite3 is unavailable on this platform.")
    }

    public func latestWinner(
        device: DeviceFingerprint,
        workload: WorkloadSignature,
        shaderHash: String,
        protocolHash: String
    ) throws -> PlanRecord? {
        throw AppleZKProverError.failedToOpenPlanDatabase("SQLite3 is unavailable on this platform.")
    }

    public func recordLiveObservation(
        for record: PlanRecord,
        gpuTimeNS: Double,
        cpuSubmitNS: Double,
        policy: PlanDriftPolicy = .default
    ) throws -> PlanDriftStatus {
        throw AppleZKProverError.failedToOpenPlanDatabase("SQLite3 is unavailable on this platform.")
    }
}
#endif
