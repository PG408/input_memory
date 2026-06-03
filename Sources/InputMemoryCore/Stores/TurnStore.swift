import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class TurnStore {
    private var db: OpaquePointer?

    public init(path: String = AppPaths.databaseURL.path) throws {
        try AppPaths.ensureDirectory(URL(fileURLWithPath: path).deletingLastPathComponent())
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            throw StoreError.openFailed(message: lastErrorMessage)
        }
        sqlite3_busy_timeout(db, 5_000)
        try migrate()
        AppLog.store.info("SQLite store opened path=\(path, privacy: .private)")
    }

    deinit {
        sqlite3_close(db)
    }

    public func insert(_ turn: Turn) throws -> Int64 {
        let sql = """
        INSERT INTO turns (
            observed_text, observed_text_hash, observed_text_length,
            app_name, bundle_id, window_title,
            control_role, control_subrole, control_title, control_description,
            control_path_hint, control_frame, control_fingerprint, is_heuristic_text_control,
            capture_status, ended_empty, ever_had_non_empty_text,
            started_at, last_observed_at, ended_at, end_reason, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        try execute(sql) { statement in
            bindTurn(turn, to: statement)
        }
        let id = sqlite3_last_insert_rowid(db)
        AppLog.store.debug(
            "Inserted turn id=\(id, privacy: .public) app=\(turn.context.appName, privacy: .public) bundleID=\(turn.context.bundleID, privacy: .public) window=\(turn.context.windowTitle, privacy: .private) \(AppLogMetadata.textSummary(turn.observedText), privacy: .public)"
        )
        return id
    }

    public func update(_ turn: Turn) throws {
        guard let id = turn.id else { throw StoreError.missingID }
        let sql = """
        UPDATE turns SET
            observed_text = ?, observed_text_hash = ?, observed_text_length = ?,
            app_name = ?, bundle_id = ?, window_title = ?,
            control_role = ?, control_subrole = ?, control_title = ?, control_description = ?,
            control_path_hint = ?, control_frame = ?, control_fingerprint = ?, is_heuristic_text_control = ?,
            capture_status = ?, ended_empty = ?, ever_had_non_empty_text = ?,
            started_at = ?, last_observed_at = ?, ended_at = ?, end_reason = ?, created_at = ?, updated_at = ?
        WHERE id = ?;
        """
        try execute(sql) { statement in
            bindTurn(turn, to: statement)
            sqlite3_bind_int64(statement, 24, id)
        }
        AppLog.store.debug(
            "Updated turn id=\(id, privacy: .public) status=\(turn.captureStatus.rawValue, privacy: .public) endReason=\(turn.endReason?.rawValue ?? "active", privacy: .public) \(AppLogMetadata.textSummary(turn.observedText), privacy: .public)"
        )
    }

    public func deleteTurn(id: Int64) throws {
        try execute("DELETE FROM turns WHERE id = ?;") { statement in
            sqlite3_bind_int64(statement, 1, id)
        }
        AppLog.store.debug("Deleted turn id=\(id, privacy: .public)")
    }

    public func fetchPreviousTurnInSameWindow(as turn: Turn) throws -> Turn? {
        guard let id = turn.id else { throw StoreError.missingID }
        let sql = """
        SELECT * FROM turns
        WHERE id != ?
            AND app_name = ?
            AND bundle_id = ?
            AND window_title = ?
            AND started_at <= ?
        ORDER BY started_at DESC, id DESC
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepareFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, id)
        sqlite3_bind_text(statement, 2, turn.context.appName, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, turn.context.bundleID, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, turn.context.windowTitle, -1, sqliteTransient)
        sqlite3_bind_double(statement, 5, turn.startedAt.timeIntervalSince1970)

        if sqlite3_step(statement) == SQLITE_ROW {
            return readTurn(statement)
        }
        return nil
    }

    public func fetchRecent(limit: Int) throws -> [Turn] {
        let sql = "SELECT * FROM turns WHERE observed_text_length > 0 ORDER BY started_at DESC LIMIT ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepareFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(max(limit * 20, limit)))

        var turns: [Turn] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let turn = readTurn(statement)
            guard TextSanitizer.isMeaningful(turn.observedText) else {
                continue
            }
            turns.append(turn)
            if turns.count == limit {
                break
            }
        }
        return turns
    }

    public func fetchTurns(on day: Date, calendar: Calendar = .current) throws -> [Turn] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let sql = "SELECT * FROM turns WHERE started_at >= ? AND started_at < ? ORDER BY started_at ASC;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepareFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, start.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, end.timeIntervalSince1970)

        var turns: [Turn] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            turns.append(readTurn(statement))
        }
        return turns
    }

    @discardableResult
    public func compactAppendOnlyTurns() throws -> TurnCompactionResult {
        let turns = try fetchAllTurnsForCompaction()
        var lastTurnByContext: [TurnContextKey: Turn] = [:]
        var deletedInvisibleCount = 0
        var deletedAppendOnlyCount = 0

        for turn in turns {
            guard TextSanitizer.isMeaningful(turn.observedText) else {
                if let id = turn.id {
                    try deleteTurn(id: id)
                    deletedInvisibleCount += 1
                }
                continue
            }

            let key = TurnContextKey(turn: turn)
            if let previous = lastTurnByContext[key],
               let previousID = previous.id,
               shouldReplacePreviousTurn(previous, with: turn) {
                try deleteTurn(id: previousID)
                deletedAppendOnlyCount += 1
            }
            lastTurnByContext[key] = turn
        }

        let result = TurnCompactionResult(
            scannedCount: turns.count,
            deletedInvisibleCount: deletedInvisibleCount,
            deletedAppendOnlyCount: deletedAppendOnlyCount
        )
        AppLog.store.info(
            "Compaction finished scanned=\(result.scannedCount, privacy: .public) deletedInvisible=\(result.deletedInvisibleCount, privacy: .public) deletedAppendOnly=\(result.deletedAppendOnlyCount, privacy: .public)"
        )
        return result
    }

    @discardableResult
    public func closeUnclosedTurns() throws -> Int {
        let sql = """
        UPDATE turns
        SET ended_at = last_observed_at, end_reason = 'crash_unclosed', updated_at = strftime('%s','now')
        WHERE ended_at IS NULL;
        """
        try execute(sql)
        let changedCount = Int(sqlite3_changes(db))
        AppLog.store.info("Close unclosed turns changed=\(changedCount, privacy: .public)")
        return changedCount
    }

    private func fetchAllTurnsForCompaction() throws -> [Turn] {
        let sql = "SELECT * FROM turns ORDER BY started_at ASC, id ASC;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepareFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        var turns: [Turn] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            turns.append(readTurn(statement))
        }
        return turns
    }

    private func shouldReplacePreviousTurn(_ previous: Turn, with current: Turn) -> Bool {
        let previousText = TextSanitizer.visibleText(previous.observedText)
        let currentText = TextSanitizer.visibleText(current.observedText)
        return currentText == previousText || currentText.hasPrefix(previousText)
    }

    private func migrate() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS turns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            observed_text TEXT NOT NULL,
            observed_text_hash TEXT NOT NULL,
            observed_text_length INTEGER NOT NULL,
            app_name TEXT NOT NULL,
            bundle_id TEXT NOT NULL,
            window_title TEXT NOT NULL,
            control_role TEXT,
            control_subrole TEXT,
            control_title TEXT,
            control_description TEXT,
            control_path_hint TEXT,
            control_frame TEXT,
            control_fingerprint TEXT NOT NULL,
            is_heuristic_text_control INTEGER NOT NULL,
            capture_status TEXT NOT NULL,
            ended_empty INTEGER NOT NULL,
            ever_had_non_empty_text INTEGER NOT NULL,
            started_at REAL NOT NULL,
            last_observed_at REAL NOT NULL,
            ended_at REAL,
            end_reason TEXT,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_turns_started_at ON turns(started_at);
        CREATE INDEX IF NOT EXISTS idx_turns_context ON turns(app_name, bundle_id, window_title);
        """
        try execute(sql)
        AppLog.store.info("SQLite migration finished")
    }

    private func execute(_ sql: String, binder: ((OpaquePointer?) -> Void)? = nil) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepareFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }
        binder?(statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.stepFailed(message: lastErrorMessage)
        }
    }

    private var lastErrorMessage: String {
        if let db, let message = sqlite3_errmsg(db) {
            return String(cString: message)
        }
        return "Unknown SQLite error"
    }
}

public struct TurnCompactionResult: Equatable, Sendable {
    public let scannedCount: Int
    public let deletedInvisibleCount: Int
    public let deletedAppendOnlyCount: Int
}

private struct TurnContextKey: Hashable {
    let appName: String
    let bundleID: String
    let windowTitle: String

    init(turn: Turn) {
        self.appName = turn.context.appName
        self.bundleID = turn.context.bundleID
        self.windowTitle = turn.context.windowTitle
    }
}

public enum StoreError: Error, Equatable {
    case openFailed(message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)
    case missingID
}

private func bindTurn(_ turn: Turn, to statement: OpaquePointer?) {
    sqlite3_bind_text(statement, 1, turn.observedText, -1, sqliteTransient)
    sqlite3_bind_text(statement, 2, turn.observedTextHash, -1, sqliteTransient)
    sqlite3_bind_int(statement, 3, Int32(turn.observedTextLength))
    sqlite3_bind_text(statement, 4, turn.context.appName, -1, sqliteTransient)
    sqlite3_bind_text(statement, 5, turn.context.bundleID, -1, sqliteTransient)
    sqlite3_bind_text(statement, 6, turn.context.windowTitle, -1, sqliteTransient)
    bindOptionalText(statement, 7, turn.context.controlRole)
    bindOptionalText(statement, 8, turn.context.controlSubrole)
    bindOptionalText(statement, 9, turn.context.controlTitle)
    bindOptionalText(statement, 10, turn.context.controlDescription)
    bindOptionalText(statement, 11, turn.context.controlPathHint)
    bindOptionalText(statement, 12, turn.context.controlFrame)
    sqlite3_bind_text(statement, 13, turn.context.controlFingerprint, -1, sqliteTransient)
    sqlite3_bind_int(statement, 14, turn.context.isHeuristicTextControl ? 1 : 0)
    sqlite3_bind_text(statement, 15, turn.captureStatus.rawValue, -1, sqliteTransient)
    sqlite3_bind_int(statement, 16, turn.endedEmpty ? 1 : 0)
    sqlite3_bind_int(statement, 17, turn.everHadNonEmptyText ? 1 : 0)
    sqlite3_bind_double(statement, 18, turn.startedAt.timeIntervalSince1970)
    sqlite3_bind_double(statement, 19, turn.lastObservedAt.timeIntervalSince1970)
    bindOptionalDate(statement, 20, turn.endedAt)
    bindOptionalText(statement, 21, turn.endReason?.rawValue)
    sqlite3_bind_double(statement, 22, turn.createdAt.timeIntervalSince1970)
    sqlite3_bind_double(statement, 23, turn.updatedAt.timeIntervalSince1970)
}

private func bindOptionalText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
    if let value {
        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    } else {
        sqlite3_bind_null(statement, index)
    }
}

private func bindOptionalDate(_ statement: OpaquePointer?, _ index: Int32, _ value: Date?) {
    if let value {
        sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
    } else {
        sqlite3_bind_null(statement, index)
    }
}

private func readTurn(_ statement: OpaquePointer?) -> Turn {
    let context = CaptureContext(
        appName: columnString(statement, 4),
        bundleID: columnString(statement, 5),
        windowTitle: columnString(statement, 6),
        controlRole: optionalColumnString(statement, 7),
        controlSubrole: optionalColumnString(statement, 8),
        controlTitle: optionalColumnString(statement, 9),
        controlDescription: optionalColumnString(statement, 10),
        controlPathHint: optionalColumnString(statement, 11),
        controlFrame: optionalColumnString(statement, 12),
        controlFingerprint: columnString(statement, 13),
        isHeuristicTextControl: sqlite3_column_int(statement, 14) == 1
    )
    return Turn(
        id: sqlite3_column_int64(statement, 0),
        observedText: columnString(statement, 1),
        observedTextHash: columnString(statement, 2),
        observedTextLength: Int(sqlite3_column_int(statement, 3)),
        context: context,
        captureStatus: CaptureStatus(rawValue: columnString(statement, 15)) ?? .unreadable,
        endedEmpty: sqlite3_column_int(statement, 16) == 1,
        everHadNonEmptyText: sqlite3_column_int(statement, 17) == 1,
        startedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 18)),
        lastObservedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 19)),
        endedAt: optionalColumnDate(statement, 20),
        endReason: optionalColumnString(statement, 21).flatMap(EndReason.init(rawValue:)),
        createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 22)),
        updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 23))
    )
}

private func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String {
    guard let pointer = sqlite3_column_text(statement, index) else { return "" }
    return String(cString: pointer)
}

private func optionalColumnString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return columnString(statement, index)
}

private func optionalColumnDate(_ statement: OpaquePointer?, _ index: Int32) -> Date? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
}
