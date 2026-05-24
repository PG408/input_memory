# InputMemory MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a SwiftPM-based macOS menu bar app that records foreground focused text-control turns into SQLite and exports the previous day as Markdown.

**Architecture:** The app uses a small SwiftUI/AppKit shell around a testable capture core. Platform-specific Accessibility and foreground-app APIs are wrapped behind protocols so turn lifecycle, `observed_text` overwrite rules, persistence, and Markdown export can be tested without live macOS UI state.

**Tech Stack:** Swift 5.10+, SwiftPM, SwiftUI, AppKit, ApplicationServices Accessibility APIs, SQLite3, XCTest, executable self-test target.

**Execution note:** The CommandLineTools-only Swift environment cannot import `XCTest` or Swift `Testing`. After Xcode was installed, standard XCTest verification works with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`. `InputMemorySelfTest` remains available as a fallback when XCTest is unavailable.

---

## File Structure

- `Package.swift`: SwiftPM package with one core library target, two executable targets, and one XCTest target.
- `Sources/InputMemory/App/InputMemoryApp.swift`: SwiftUI app entrypoint with `MenuBarExtra`, viewer window, and app delegate.
- `Sources/InputMemory/App/AppDelegate.swift`: macOS lifecycle hooks for shutdown flush and activation policy.
- `Sources/InputMemoryCore/Models/Turn.swift`: persisted turn model and enums.
- `Sources/InputMemoryCore/Models/ActiveTurn.swift`: in-memory active turn state and overwrite rules.
- `Sources/InputMemoryCore/Models/CaptureContext.swift`: app, window, and focused-control context snapshot models.
- `Sources/InputMemoryCore/Support/AppPaths.swift`: Application Support and export-directory paths.
- `Sources/InputMemoryCore/Support/Hashing.swift`: SHA-256 text hash helper.
- `Sources/InputMemoryCore/Stores/TurnStore.swift`: SQLite-backed turn persistence.
- `Sources/InputMemoryCore/Services/AccessibilityPermissionService.swift`: Accessibility permission checks and System Settings opener.
- `Sources/InputMemoryCore/Services/AccessibilityClient.swift`: focused element inspection and text reads.
- `Sources/InputMemoryCore/Services/ForegroundAppMonitor.swift`: foreground app change monitoring.
- `Sources/InputMemoryCore/Services/CaptureCoordinator.swift`: capture state machine, polling, pause/resume, shutdown recovery.
- `Sources/InputMemoryCore/Services/MarkdownExporter.swift`: T-day-trigger exports T-1-day Markdown.
- `Sources/InputMemory/Stores/AppState.swift`: observable UI state and service orchestration.
- `Sources/InputMemory/Views/MenuBarContentView.swift`: menu bar controls.
- `Sources/InputMemory/Views/ViewerWindowView.swift`: viewer shell.
- `Sources/InputMemory/Views/TurnListView.swift`: recent turn list.
- `Sources/InputMemory/Views/TurnDetailView.swift`: full-text detail panel.
- `Sources/InputMemory/Views/PermissionView.swift`: authorization prompt.
- `Sources/InputMemorySelfTest/main.swift`: executable fallback checks for turn rules, SQLite persistence, Markdown export, and capture lifecycle.
- `Tests/InputMemoryTests/*.swift`: standard XCTest coverage for turn rules, SQLite persistence, Markdown export, and capture lifecycle.
- `script/build_and_run.sh`: local build/run helper.

## Task 1: Scaffold SwiftPM macOS App

**Files:**
- Create: `Package.swift`
- Create: `Sources/InputMemory/App/InputMemoryApp.swift`
- Create: `Sources/InputMemory/App/AppDelegate.swift`
- Create: `Sources/InputMemory/Views/MenuBarContentView.swift`
- Create: `Tests/InputMemoryTests/SmokeTests.swift`
- Create: `script/build_and_run.sh`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "InputMemory",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "InputMemory", targets: ["InputMemory"])
    ],
    targets: [
        .executableTarget(
            name: "InputMemory",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "InputMemoryTests",
            dependencies: ["InputMemory"]
        )
    ]
)
```

- [ ] **Step 2: Create minimal app entrypoint**

`Sources/InputMemory/App/InputMemoryApp.swift`:

```swift
import SwiftUI

@main
struct InputMemoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("InputMemory", systemImage: "text.cursor") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.menu)

        WindowGroup("InputMemory", id: "viewer") {
            Text("InputMemory")
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
```

`Sources/InputMemory/App/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
}
```

`Sources/InputMemory/Views/MenuBarContentView.swift`:

```swift
import SwiftUI

struct MenuBarContentView: View {
    var body: some View {
        Button("Open Viewer") {
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
```

- [ ] **Step 3: Add smoke test**

`Tests/InputMemoryTests/SmokeTests.swift`:

```swift
import XCTest
@testable import InputMemory

final class SmokeTests: XCTestCase {
    func testPackageLoads() {
        XCTAssertEqual("InputMemory", "InputMemory")
    }
}
```

- [ ] **Step 4: Add build helper**

`script/build_and_run.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="InputMemory"
BUNDLE_ID="local.inputmemory"
BUILD_DIR=".build/debug"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

pkill -x "${APP_NAME}" 2>/dev/null || true
swift build --product "${APP_NAME}"

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
cp "${BUILD_DIR}/${APP_NAME}" "${EXECUTABLE}"
chmod +x "${EXECUTABLE}"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/open -n "${APP_BUNDLE}"
```

Run: `chmod +x script/build_and_run.sh`

- [ ] **Step 5: Verify scaffold**

Run: `swift test`

Expected: PASS with `SmokeTests.testPackageLoads`.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests script
git commit -m "chore: scaffold InputMemory app"
```

## Task 2: Implement Turn Models and ActiveTurn Rules

**Files:**
- Create: `Sources/InputMemory/Models/Turn.swift`
- Create: `Sources/InputMemory/Models/CaptureContext.swift`
- Create: `Sources/InputMemory/Models/ActiveTurn.swift`
- Create: `Sources/InputMemory/Support/Hashing.swift`
- Test: `Tests/InputMemoryTests/ActiveTurnTests.swift`
- Test: `Tests/InputMemoryTests/TestFixtures.swift`

- [ ] **Step 1: Write failing ActiveTurn tests**

`Tests/InputMemoryTests/TestFixtures.swift`:

```swift
import Foundation
@testable import InputMemory

extension Date {
    static let fixture = Date(timeIntervalSince1970: 1_800_000_000)
}

extension CaptureContext {
    static func fixture() -> CaptureContext {
        CaptureContext(
            appName: "TestApp",
            bundleID: "com.example.TestApp",
            windowTitle: "Test Window",
            controlRole: "AXTextField",
            controlSubrole: nil,
            controlTitle: nil,
            controlDescription: nil,
            controlPathHint: nil,
            controlFrame: nil,
            controlFingerprint: "fixture",
            isHeuristicTextControl: false
        )
    }
}
```

`Tests/InputMemoryTests/ActiveTurnTests.swift`:

```swift
import XCTest
@testable import InputMemory

final class ActiveTurnTests: XCTestCase {
    func testNonEmptyTextOverwritesObservedText() {
        var turn = ActiveTurn(context: .fixture())
        turn.applyReadResult(.readable("hello"), at: .fixture)
        turn.applyReadResult(.readable("hello world"), at: .fixture.addingTimeInterval(1))

        XCTAssertEqual(turn.observedText, "hello world")
        XCTAssertTrue(turn.everHadNonEmptyText)
        XCTAssertFalse(turn.endedEmpty)
    }

    func testEmptyTextDoesNotOverwriteExistingNonEmptyText() {
        var turn = ActiveTurn(context: .fixture())
        turn.applyReadResult(.readable("message"), at: .fixture)
        let transition = turn.applyReadResult(.empty, at: .fixture.addingTimeInterval(1))

        XCTAssertEqual(turn.observedText, "message")
        XCTAssertTrue(turn.endedEmpty)
        XCTAssertEqual(transition, .endTurn(.textCleared))
    }

    func testNeverNonEmptyTurnKeepsEmptyObservedText() {
        var turn = ActiveTurn(context: .fixture())
        let transition = turn.applyReadResult(.empty, at: .fixture)

        XCTAssertEqual(turn.observedText, "")
        XCTAssertFalse(turn.everHadNonEmptyText)
        XCTAssertEqual(transition, .continueTurn)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ActiveTurnTests`

Expected: FAIL because `ActiveTurn` and related types do not exist.

- [ ] **Step 3: Implement models**

`Sources/InputMemory/Models/Turn.swift`:

```swift
import Foundation

struct Turn: Identifiable, Equatable {
    var id: Int64?
    var observedText: String
    var observedTextHash: String
    var observedTextLength: Int
    var context: CaptureContext
    var captureStatus: CaptureStatus
    var endedEmpty: Bool
    var everHadNonEmptyText: Bool
    var startedAt: Date
    var lastObservedAt: Date
    var endedAt: Date?
    var endReason: EndReason?
    var createdAt: Date
    var updatedAt: Date
}

enum CaptureStatus: String, Equatable {
    case pending
    case readable
    case empty
    case unreadable
    case permissionDenied = "permission_denied"
}

enum EndReason: String, Equatable {
    case appChanged = "app_changed"
    case focusChanged = "focus_changed"
    case textCleared = "text_cleared"
    case controlUnavailable = "control_unavailable"
    case idleTimeout = "idle_timeout"
    case paused
    case appShutdown = "app_shutdown"
    case crashUnclosed = "crash_unclosed"
}
```

`Sources/InputMemory/Models/CaptureContext.swift`:

```swift
import Foundation

struct CaptureContext: Equatable {
    var appName: String
    var bundleID: String
    var windowTitle: String
    var controlRole: String?
    var controlSubrole: String?
    var controlTitle: String?
    var controlDescription: String?
    var controlPathHint: String?
    var controlFrame: String?
    var controlFingerprint: String
    var isHeuristicTextControl: Bool
}
```

`Sources/InputMemory/Support/Hashing.swift`:

```swift
import CryptoKit
import Foundation

enum Hashing {
    static func sha256(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
```

`Sources/InputMemory/Models/ActiveTurn.swift`:

```swift
import Foundation

enum TextReadResult: Equatable {
    case readable(String)
    case empty
    case unreadable
}

enum TurnTransition: Equatable {
    case continueTurn
    case endTurn(EndReason)
}

struct ActiveTurn {
    var databaseID: Int64?
    var context: CaptureContext
    var observedText: String = ""
    var lastRawText: String = ""
    var everHadNonEmptyText = false
    var endedEmpty = false
    var captureStatus: CaptureStatus = .pending
    var startedAt: Date
    var lastObservedAt: Date
    var dirty = true
    var lastFlushedAt: Date?

    init(context: CaptureContext, startedAt: Date = Date()) {
        self.context = context
        self.startedAt = startedAt
        self.lastObservedAt = startedAt
    }

    @discardableResult
    mutating func applyReadResult(_ result: TextReadResult, at date: Date) -> TurnTransition {
        lastObservedAt = date

        switch result {
        case .readable(let text) where !text.isEmpty:
            observedText = text
            lastRawText = text
            everHadNonEmptyText = true
            endedEmpty = false
            captureStatus = .readable
            dirty = true
            return .continueTurn

        case .readable:
            fallthrough
        case .empty:
            lastRawText = ""
            captureStatus = everHadNonEmptyText ? .readable : .empty
            dirty = true
            if everHadNonEmptyText {
                endedEmpty = true
                return .endTurn(.textCleared)
            }
            return .continueTurn

        case .unreadable:
            captureStatus = .unreadable
            dirty = true
            return .continueTurn
        }
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run: `swift test --filter ActiveTurnTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/InputMemory/Models Sources/InputMemory/Support Tests/InputMemoryTests/ActiveTurnTests.swift Tests/InputMemoryTests/TestFixtures.swift
git commit -m "feat: add turn state model"
```

## Task 3: Implement SQLite TurnStore

**Files:**
- Create: `Sources/InputMemory/Support/AppPaths.swift`
- Create: `Sources/InputMemory/Stores/TurnStore.swift`
- Test: `Tests/InputMemoryTests/TurnStoreTests.swift`

- [ ] **Step 1: Write failing TurnStore tests**

`Tests/InputMemoryTests/TurnStoreTests.swift`:

```swift
import XCTest
@testable import InputMemory

final class TurnStoreTests: XCTestCase {
    func testInsertAndUpdateTurn() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let context = CaptureContext.fixture()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var turn = Turn(
            id: nil,
            observedText: "hello",
            observedTextHash: Hashing.sha256("hello"),
            observedTextLength: 5,
            context: context,
            captureStatus: .readable,
            endedEmpty: false,
            everHadNonEmptyText: true,
            startedAt: now,
            lastObservedAt: now,
            endedAt: nil,
            endReason: nil,
            createdAt: now,
            updatedAt: now
        )

        turn.id = try store.insert(turn)
        turn.observedText = "hello world"
        turn.observedTextHash = Hashing.sha256("hello world")
        turn.observedTextLength = 11
        turn.endedAt = now.addingTimeInterval(5)
        turn.endReason = .focusChanged
        try store.update(turn)

        let recent = try store.fetchRecent(limit: 10)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent[0].observedText, "hello world")
        XCTAssertEqual(recent[0].endReason, .focusChanged)
    }

    func testCloseUnclosedTurnsMarksCrashUnclosed() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var turn = Turn.fixture(observedText: "draft", at: now)
        turn.id = try store.insert(turn)

        try store.closeUnclosedTurns()

        let recent = try store.fetchRecent(limit: 10)
        XCTAssertEqual(recent[0].endReason, .crashUnclosed)
        XCTAssertEqual(recent[0].endedAt, now)
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
            .path
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TurnStoreTests`

Expected: FAIL because `TurnStore` does not exist.

- [ ] **Step 3: Implement app paths**

`Sources/InputMemory/Support/AppPaths.swift`:

```swift
import Foundation

enum AppPaths {
    static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("InputMemory", isDirectory: true)
    }

    static var databaseURL: URL {
        applicationSupportDirectory.appendingPathComponent("input_memory.sqlite")
    }

    static var defaultExportDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("InputMemory", isDirectory: true)
    }

    static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
```

- [ ] **Step 4: Implement SQLite store**

`Sources/InputMemory/Stores/TurnStore.swift`:

```swift
import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class TurnStore {
    private var db: OpaquePointer?

    init(path: String = AppPaths.databaseURL.path) throws {
        try AppPaths.ensureDirectory(URL(fileURLWithPath: path).deletingLastPathComponent())
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            throw StoreError.openFailed(message: lastErrorMessage)
        }
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    func insert(_ turn: Turn) throws -> Int64 {
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
            bindTurn(turn, to: statement, includeID: false)
        }
        return sqlite3_last_insert_rowid(db)
    }

    func update(_ turn: Turn) throws {
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
            bindTurn(turn, to: statement, includeID: false)
            sqlite3_bind_int64(statement, 24, id)
        }
    }

    func fetchRecent(limit: Int) throws -> [Turn] {
        let sql = "SELECT * FROM turns ORDER BY started_at DESC LIMIT ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepareFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(limit))

        var turns: [Turn] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            turns.append(readTurn(statement))
        }
        return turns
    }

    func fetchTurns(on day: Date, calendar: Calendar = .current) throws -> [Turn] {
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

    func closeUnclosedTurns() throws {
        let sql = """
        UPDATE turns
        SET ended_at = last_observed_at, end_reason = 'crash_unclosed', updated_at = strftime('%s','now')
        WHERE ended_at IS NULL;
        """
        try execute(sql)
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

enum StoreError: Error, Equatable {
    case openFailed(message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)
    case missingID
}
```

Add the helper bindings and row reader in the same file:

```swift
private func bindTurn(_ turn: Turn, to statement: OpaquePointer?, includeID: Bool) {
    sqlite3_bind_text(statement, 1, turn.observedText, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 2, turn.observedTextHash, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(statement, 3, Int32(turn.observedTextLength))
    sqlite3_bind_text(statement, 4, turn.context.appName, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 5, turn.context.bundleID, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 6, turn.context.windowTitle, -1, SQLITE_TRANSIENT)
    bindOptionalText(statement, 7, turn.context.controlRole)
    bindOptionalText(statement, 8, turn.context.controlSubrole)
    bindOptionalText(statement, 9, turn.context.controlTitle)
    bindOptionalText(statement, 10, turn.context.controlDescription)
    bindOptionalText(statement, 11, turn.context.controlPathHint)
    bindOptionalText(statement, 12, turn.context.controlFrame)
    sqlite3_bind_text(statement, 13, turn.context.controlFingerprint, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(statement, 14, turn.context.isHeuristicTextControl ? 1 : 0)
    sqlite3_bind_text(statement, 15, turn.captureStatus.rawValue, -1, SQLITE_TRANSIENT)
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
        sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
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
```

Add the row-reader helpers in the same file:

```swift
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
```

Append the `Turn` fixture to `Tests/InputMemoryTests/TestFixtures.swift`:

```swift
extension Turn {
    static func fixture(observedText: String, at date: Date) -> Turn {
        Turn(
            id: nil,
            observedText: observedText,
            observedTextHash: Hashing.sha256(observedText),
            observedTextLength: observedText.count,
            context: .fixture(),
            captureStatus: observedText.isEmpty ? .empty : .readable,
            endedEmpty: observedText.isEmpty,
            everHadNonEmptyText: !observedText.isEmpty,
            startedAt: date,
            lastObservedAt: date,
            endedAt: nil,
            endReason: nil,
            createdAt: date,
            updatedAt: date
        )
    }
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --filter TurnStoreTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/InputMemory/Stores Sources/InputMemory/Support/AppPaths.swift Tests/InputMemoryTests/TurnStoreTests.swift Tests/InputMemoryTests/TestFixtures.swift
git commit -m "feat: persist turns in sqlite"
```

## Task 4: Implement Markdown Export

**Files:**
- Create: `Sources/InputMemory/Services/MarkdownExporter.swift`
- Test: `Tests/InputMemoryTests/MarkdownExporterTests.swift`

- [ ] **Step 1: Write failing exporter test**

`Tests/InputMemoryTests/MarkdownExporterTests.swift`:

```swift
import XCTest
@testable import InputMemory

final class MarkdownExporterTests: XCTestCase {
    func testExportsPreviousDayGroupedByContextWithTextFence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = try TurnStore(path: directory.appendingPathComponent("test.sqlite").path)
        let targetDay = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 22))!
        var turn = Turn.fixture(observedText: "# hello\nbody", at: targetDay.addingTimeInterval(3600))
        turn.id = try store.insert(turn)

        let exporter = MarkdownExporter(store: store, exportDirectory: directory)
        let outputURL = try exporter.exportPreviousDay(triggeredAt: targetDay.addingTimeInterval(86_400))

        let markdown = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertTrue(markdown.contains("# InputMemory Export: 2026-05-22"))
        XCTAssertTrue(markdown.contains("## TestApp | Test Window"))
        XCTAssertTrue(markdown.contains("```text\n# hello\nbody\n```"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MarkdownExporterTests`

Expected: FAIL because `MarkdownExporter` does not exist.

- [ ] **Step 3: Implement exporter**

`Sources/InputMemory/Services/MarkdownExporter.swift`:

```swift
import Foundation

final class MarkdownExporter {
    private let store: TurnStore
    private let exportDirectory: URL
    private let calendar: Calendar

    init(store: TurnStore, exportDirectory: URL = AppPaths.defaultExportDirectory, calendar: Calendar = .current) {
        self.store = store
        self.exportDirectory = exportDirectory
        self.calendar = calendar
    }

    func exportPreviousDay(triggeredAt: Date = Date()) throws -> URL {
        let targetDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: triggeredAt))!
        let turns = try store.fetchTurns(on: targetDay, calendar: calendar)
        try AppPaths.ensureDirectory(exportDirectory)

        let outputURL = exportDirectory.appendingPathComponent(Self.fileName(for: targetDay))
        try render(day: targetDay, generatedAt: triggeredAt, turns: turns)
            .write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    private func render(day: Date, generatedAt: Date, turns: [Turn]) -> String {
        let grouped = Dictionary(grouping: turns) { turn in
            "\(turn.context.appName)|\(turn.context.bundleID)|\(turn.context.windowTitle)"
        }
        var lines: [String] = [
            "# InputMemory Export: \(Self.dayFormatter.string(from: day))",
            "",
            "- Generated At: \(Self.timestampFormatter.string(from: generatedAt))",
            "- Turn Count: \(turns.count)",
            ""
        ]

        for key in grouped.keys.sorted() {
            guard let sessionTurns = grouped[key]?.sorted(by: { $0.startedAt < $1.startedAt }),
                  let first = sessionTurns.first else { continue }
            lines.append("## \(first.context.appName) | \(first.context.windowTitle)")
            lines.append("")
            lines.append("- Bundle ID: \(first.context.bundleID)")
            lines.append("- Turns: \(sessionTurns.count)")
            lines.append("")

            for turn in sessionTurns {
                lines.append("### Turn \(turn.id ?? 0) | \(Self.timestampFormatter.string(from: turn.startedAt))")
                lines.append("")
                lines.append("- Capture Status: \(turn.captureStatus.rawValue)")
                lines.append("- End Reason: \(turn.endReason?.rawValue ?? "active")")
                lines.append("- Ended Empty: \(turn.endedEmpty)")
                lines.append("- Text Length: \(turn.observedTextLength)")
                lines.append("")
                lines.append("```text")
                lines.append(turn.observedText)
                lines.append("```")
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func fileName(for day: Date) -> String {
        "\(dayFormatter.string(from: day)).md"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
```

- [ ] **Step 4: Run exporter tests**

Run: `swift test --filter MarkdownExporterTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/InputMemory/Services/MarkdownExporter.swift Tests/InputMemoryTests/MarkdownExporterTests.swift
git commit -m "feat: export turns to markdown"
```

## Task 5: Implement Platform Wrappers for Accessibility and Foreground App

**Files:**
- Create: `Sources/InputMemory/Services/AccessibilityPermissionService.swift`
- Create: `Sources/InputMemory/Services/AccessibilityClient.swift`
- Create: `Sources/InputMemory/Services/ForegroundAppMonitor.swift`

- [ ] **Step 1: Add permission service**

`Sources/InputMemory/Services/AccessibilityPermissionService.swift`:

```swift
import AppKit
import ApplicationServices

final class AccessibilityPermissionService {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Add foreground monitor**

`Sources/InputMemory/Services/ForegroundAppMonitor.swift`:

```swift
import AppKit

struct ForegroundAppSnapshot: Equatable {
    var appName: String
    var bundleID: String
    var processIdentifier: pid_t
}

final class ForegroundAppMonitor {
    var onAppChanged: ((ForegroundAppSnapshot?) -> Void)?

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        onAppChanged?(currentAppSnapshot())
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func currentAppSnapshot() -> ForegroundAppSnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return ForegroundAppSnapshot(
            appName: app.localizedName ?? "Unknown",
            bundleID: app.bundleIdentifier ?? "unknown",
            processIdentifier: app.processIdentifier
        )
    }

    @objc private func activeApplicationChanged(_ notification: Notification) {
        onAppChanged?(currentAppSnapshot())
    }
}
```

- [ ] **Step 3: Add Accessibility client**

`Sources/InputMemory/Services/AccessibilityClient.swift`:

```swift
import ApplicationServices
import AppKit

protocol AccessibilityReading {
    func focusedTextCandidate(for app: ForegroundAppSnapshot) -> FocusedTextCandidate?
    func readText(from candidate: FocusedTextCandidate) -> TextReadResult
}

struct FocusedTextCandidate {
    var element: AXUIElement
    var context: CaptureContext
}

final class AccessibilityClient: AccessibilityReading {
    func focusedTextCandidate(for app: ForegroundAppSnapshot) -> FocusedTextCandidate? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else {
            return nil
        }
        let axElement = unsafeBitCast(element, to: AXUIElement.self)
        let role = stringAttribute(kAXRoleAttribute, from: axElement)
        let value = stringAttribute(kAXValueAttribute, from: axElement)
        let isStandard = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role ?? "")
        let isHeuristic = !isStandard && value != nil
        guard isStandard || isHeuristic else { return nil }

        let context = CaptureContext(
            appName: app.appName,
            bundleID: app.bundleID,
            windowTitle: currentWindowTitle(for: app.processIdentifier),
            controlRole: role,
            controlSubrole: stringAttribute(kAXSubroleAttribute, from: axElement),
            controlTitle: stringAttribute(kAXTitleAttribute, from: axElement),
            controlDescription: stringAttribute(kAXDescriptionAttribute, from: axElement),
            controlPathHint: nil,
            controlFrame: frameDescription(from: axElement),
            controlFingerprint: fingerprint(app: app, role: role, frame: frameDescription(from: axElement)),
            isHeuristicTextControl: isHeuristic
        )
        return FocusedTextCandidate(element: axElement, context: context)
    }

    func readText(from candidate: FocusedTextCandidate) -> TextReadResult {
        guard let text = stringAttribute(kAXValueAttribute, from: candidate.element) else {
            return .unreadable
        }
        return text.isEmpty ? .empty : .readable(text)
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func currentWindowTitle(for pid: pid_t) -> String {
        let appElement = AXUIElementCreateApplication(pid)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window else { return "" }
        return stringAttribute(kAXTitleAttribute, from: unsafeBitCast(window, to: AXUIElement.self)) ?? ""
    }

    private func frameDescription(from element: AXUIElement) -> String? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
        return "\(String(describing: position))|\(String(describing: size))"
    }

    private func fingerprint(app: ForegroundAppSnapshot, role: String?, frame: String?) -> String {
        Hashing.sha256([app.bundleID, role ?? "", frame ?? ""].joined(separator: "|"))
    }
}
```

- [ ] **Step 4: Verify build**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/InputMemory/Services/AccessibilityPermissionService.swift Sources/InputMemory/Services/AccessibilityClient.swift Sources/InputMemory/Services/ForegroundAppMonitor.swift
git commit -m "feat: add macos accessibility wrappers"
```

## Task 6: Implement CaptureCoordinator With Fake-Driven Tests

**Files:**
- Create: `Sources/InputMemory/Services/CaptureCoordinator.swift`
- Test: `Tests/InputMemoryTests/CaptureCoordinatorTests.swift`

- [ ] **Step 1: Write coordinator tests**

`Tests/InputMemoryTests/CaptureCoordinatorTests.swift`:

```swift
import ApplicationServices
import XCTest
@testable import InputMemory

final class CaptureCoordinatorTests: XCTestCase {
    func testNonEmptyThenEmptyEndsTurnWithTextCleared() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(store: store, reader: FakeReader(results: [.readable("hello"), .empty]))
        coordinator.startCandidate(.fixture())
        coordinator.tick(now: .fixture)
        coordinator.tick(now: .fixture.addingTimeInterval(1))

        let turns = try store.fetchRecent(limit: 10)
        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].observedText, "hello")
        XCTAssertEqual(turns[0].endReason, .textCleared)
        XCTAssertTrue(turns[0].endedEmpty)
    }

    func testPauseEndsActiveTurn() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(store: store, reader: FakeReader(results: [.readable("draft")]))
        coordinator.startCandidate(.fixture())
        coordinator.tick(now: .fixture)
        coordinator.startRecording()
        coordinator.pause(now: .fixture.addingTimeInterval(2))

        let turns = try store.fetchRecent(limit: 10)
        XCTAssertEqual(turns[0].endReason, .paused)
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
            .path
    }
}

private final class FakeReader: AccessibilityReading {
    private var results: [TextReadResult]

    init(results: [TextReadResult]) {
        self.results = results
    }

    func focusedTextCandidate(for app: ForegroundAppSnapshot) -> FocusedTextCandidate? {
        .fixture()
    }

    func readText(from candidate: FocusedTextCandidate) -> TextReadResult {
        results.isEmpty ? .empty : results.removeFirst()
    }
}

private extension FocusedTextCandidate {
    static func fixture() -> FocusedTextCandidate {
        FocusedTextCandidate(
            element: AXUIElementCreateSystemWide(),
            context: .fixture()
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CaptureCoordinatorTests`

Expected: FAIL because `CaptureCoordinator` does not exist.

- [ ] **Step 3: Implement coordinator**

`Sources/InputMemory/Services/CaptureCoordinator.swift`:

```swift
import Foundation

final class CaptureCoordinator {
    private let store: TurnStore
    private let reader: AccessibilityReading
    private var activeTurn: ActiveTurn?
    private var activeCandidate: FocusedTextCandidate?
    private(set) var isRecording = false

    init(store: TurnStore, reader: AccessibilityReading) {
        self.store = store
        self.reader = reader
    }

    func startRecording() {
        isRecording = true
    }

    func pause(now: Date = Date()) {
        guard isRecording else { return }
        endActiveTurn(reason: .paused, at: now)
        isRecording = false
    }

    func startCandidate(_ candidate: FocusedTextCandidate, now: Date = Date()) {
        activeCandidate = candidate
        activeTurn = ActiveTurn(context: candidate.context, startedAt: now)
    }

    func tick(now: Date = Date()) {
        guard let candidate = activeCandidate, var turn = activeTurn else { return }
        let transition = turn.applyReadResult(reader.readText(from: candidate), at: now)

        if turn.databaseID == nil {
            var persisted = makeTurn(from: turn, endedAt: nil, endReason: nil, now: now)
            do {
                persisted.id = try store.insert(persisted)
                turn.databaseID = persisted.id
            } catch {
                activeTurn = turn
                return
            }
        } else if turn.dirty {
            do {
                try store.update(makeTurn(from: turn, endedAt: nil, endReason: nil, now: now))
            } catch {
                activeTurn = turn
                return
            }
        }

        activeTurn = turn

        if case .endTurn(let reason) = transition {
            endActiveTurn(reason: reason, at: now)
        }
    }

    func endActiveTurn(reason: EndReason, at date: Date = Date()) {
        guard var turn = activeTurn else { return }
        turn.lastObservedAt = date
        let persisted = makeTurn(from: turn, endedAt: date, endReason: reason, now: date)
        if persisted.id == nil {
            var insertable = persisted
            insertable.id = try? store.insert(insertable)
        } else {
            try? store.update(persisted)
        }
        activeTurn = nil
        activeCandidate = nil
    }

    func shutdown(now: Date = Date()) {
        endActiveTurn(reason: .appShutdown, at: now)
    }

    private func makeTurn(from active: ActiveTurn, endedAt: Date?, endReason: EndReason?, now: Date) -> Turn {
        Turn(
            id: active.databaseID,
            observedText: active.observedText,
            observedTextHash: Hashing.sha256(active.observedText),
            observedTextLength: active.observedText.count,
            context: active.context,
            captureStatus: active.captureStatus,
            endedEmpty: active.endedEmpty,
            everHadNonEmptyText: active.everHadNonEmptyText,
            startedAt: active.startedAt,
            lastObservedAt: active.lastObservedAt,
            endedAt: endedAt,
            endReason: endReason,
            createdAt: active.startedAt,
            updatedAt: now
        )
    }
}
```

- [ ] **Step 4: Run coordinator tests**

Run: `swift test --filter CaptureCoordinatorTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/InputMemory/Services/CaptureCoordinator.swift Tests/InputMemoryTests/CaptureCoordinatorTests.swift
git commit -m "feat: coordinate text capture turns"
```

## Task 7: Wire AppState, Menu Bar, Permission View, and Viewer

**Files:**
- Create: `Sources/InputMemory/Stores/AppState.swift`
- Modify: `Sources/InputMemory/App/InputMemoryApp.swift`
- Modify: `Sources/InputMemory/App/AppDelegate.swift`
- Modify: `Sources/InputMemory/Views/MenuBarContentView.swift`
- Create: `Sources/InputMemory/Views/ViewerWindowView.swift`
- Create: `Sources/InputMemory/Views/PermissionView.swift`
- Create: `Sources/InputMemory/Views/TurnListView.swift`
- Create: `Sources/InputMemory/Views/TurnDetailView.swift`

- [ ] **Step 1: Implement AppState**

`Sources/InputMemory/Stores/AppState.swift`:

```swift
import Foundation
import Observation

@Observable
final class AppState {
    var isRecording = false
    var hasAccessibilityPermission = false
    var recentTurns: [Turn] = []
    var selectedTurnID: Int64?
    var statusText = "Not started"

    let permissionService: AccessibilityPermissionService
    let store: TurnStore
    let exporter: MarkdownExporter

    init(
        permissionService: AccessibilityPermissionService = AccessibilityPermissionService(),
        store: TurnStore,
        exporter: MarkdownExporter
    ) {
        self.permissionService = permissionService
        self.store = store
        self.exporter = exporter
        refreshPermissionStatus()
        refreshRecentTurns()
    }

    convenience init() {
        let store = try! TurnStore()
        self.init(permissionService: AccessibilityPermissionService(), store: store, exporter: MarkdownExporter(store: store))
    }

    func refreshPermissionStatus() {
        hasAccessibilityPermission = permissionService.isTrusted
        statusText = hasAccessibilityPermission ? "Ready" : "Accessibility permission required"
    }

    func requestPermission() {
        permissionService.requestPermission()
        permissionService.openSystemSettings()
    }

    func pause() {
        isRecording = false
        statusText = "Paused"
    }

    func resume() {
        refreshPermissionStatus()
        guard hasAccessibilityPermission else { return }
        isRecording = true
        statusText = "Recording"
    }

    func exportNow() {
        do {
            _ = try exporter.exportPreviousDay()
            statusText = "Exported previous day"
        } catch {
            statusText = "Export failed: \(error.localizedDescription)"
        }
    }

    func refreshRecentTurns() {
        recentTurns = (try? store.fetchRecent(limit: 50)) ?? []
    }

    var selectedTurn: Turn? {
        recentTurns.first { $0.id == selectedTurnID }
    }
}
```

- [ ] **Step 2: Inject AppState**

Update `Sources/InputMemory/App/InputMemoryApp.swift`:

```swift
import SwiftUI

@main
struct InputMemoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("InputMemory", systemImage: "text.cursor") {
            MenuBarContentView()
                .environment(appState)
        }
        .menuBarExtraStyle(.menu)

        WindowGroup("InputMemory", id: "viewer") {
            ViewerWindowView()
                .environment(appState)
                .frame(minWidth: 800, minHeight: 520)
        }
    }
}
```

- [ ] **Step 3: Implement menu and viewer views**

`Sources/InputMemory/Views/MenuBarContentView.swift`:

```swift
import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(appState.statusText)
        Divider()
        Button(appState.isRecording ? "Pause" : "Resume") {
            appState.isRecording ? appState.pause() : appState.resume()
        }
        Button("Open Viewer") {
            openWindow(id: "viewer")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Export Now") {
            appState.exportNow()
        }
        Divider()
        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
```

`Sources/InputMemory/Views/ViewerWindowView.swift`:

```swift
import SwiftUI

struct ViewerWindowView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                PermissionView()
                TurnListView()
            }
            .padding()
        } detail: {
            TurnDetailView(turn: appState.selectedTurn)
        }
    }
}
```

`Sources/InputMemory/Views/PermissionView.swift`:

```swift
import SwiftUI

struct PermissionView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.hasAccessibilityPermission ? "Accessibility: Granted" : "Accessibility: Required")
                .font(.headline)
            if !appState.hasAccessibilityPermission {
                Button("Open System Settings") {
                    appState.requestPermission()
                }
            }
        }
    }
}
```

`Sources/InputMemory/Views/TurnListView.swift`:

```swift
import SwiftUI

struct TurnListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        List(selection: $appState.selectedTurnID) {
            ForEach(appState.recentTurns) { turn in
                VStack(alignment: .leading, spacing: 4) {
                    Text(turn.context.appName)
                        .lineLimit(1)
                    Text(turn.observedText)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .tag(turn.id)
            }
        }
        .listStyle(.sidebar)
    }
}
```

`Sources/InputMemory/Views/TurnDetailView.swift`:

```swift
import SwiftUI

struct TurnDetailView: View {
    let turn: Turn?

    var body: some View {
        if let turn {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(turn.context.windowTitle.isEmpty ? turn.context.appName : turn.context.windowTitle)
                        .font(.title2)
                    Text("Status: \(turn.captureStatus.rawValue)")
                        .foregroundStyle(.secondary)
                    Text(turn.observedText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
        } else {
            ContentUnavailableView("No Turn Selected", systemImage: "text.cursor")
        }
    }
}
```

- [ ] **Step 4: Verify build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/InputMemory/App Sources/InputMemory/Stores/AppState.swift Sources/InputMemory/Views
git commit -m "feat: add menu bar viewer"
```

## Task 8: Connect Live Capture Loop and App Lifecycle

**Files:**
- Modify: `Sources/InputMemory/Stores/AppState.swift`
- Modify: `Sources/InputMemory/App/AppDelegate.swift`
- Modify: `Sources/InputMemory/App/InputMemoryApp.swift`

- [ ] **Step 1: Add live services to AppState**

Modify `AppState` to own:

```swift
private let foregroundMonitor = ForegroundAppMonitor()
private let accessibilityClient = AccessibilityClient()
private var captureCoordinator: CaptureCoordinator?
private var timer: Timer?
private var currentApp: ForegroundAppSnapshot?
private var currentControlFingerprint: String?
```

In `init`, create:

```swift
captureCoordinator = CaptureCoordinator(store: store, reader: accessibilityClient)
try? store.closeUnclosedTurns()
```

- [ ] **Step 2: Implement recording control**

Add methods:

```swift
func startCaptureLoop() {
    guard hasAccessibilityPermission, timer == nil else { return }
    isRecording = true
    captureCoordinator?.startRecording()
    foregroundMonitor.onAppChanged = { [weak self] app in
        self?.handleAppChanged(app)
    }
    foregroundMonitor.start()
    timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
        self?.pollFocusedControl()
    }
}

func stopCaptureLoop(reason: EndReason = .paused) {
    timer?.invalidate()
    timer = nil
    foregroundMonitor.stop()
    captureCoordinator?.pause()
    isRecording = false
    refreshRecentTurns()
}

private func handleAppChanged(_ app: ForegroundAppSnapshot?) {
    captureCoordinator?.endActiveTurn(reason: .appChanged)
    currentApp = app
}

private func pollFocusedControl() {
    guard let currentApp else { return }
    guard let candidate = accessibilityClient.focusedTextCandidate(for: currentApp) else {
        captureCoordinator?.endActiveTurn(reason: .focusChanged)
        currentControlFingerprint = nil
        refreshRecentTurns()
        return
    }
    if candidate.context.controlFingerprint != currentControlFingerprint {
        captureCoordinator?.endActiveTurn(reason: .focusChanged)
        currentControlFingerprint = candidate.context.controlFingerprint
        captureCoordinator?.startCandidate(candidate)
    }
    captureCoordinator?.tick()
    refreshRecentTurns()
}

func shutdown() {
    captureCoordinator?.shutdown()
}
```

- [ ] **Step 3: Route app shutdown**

Update `AppDelegate` with a callback:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onShutdown: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationWillTerminate(_ notification: Notification) {
        onShutdown?()
    }
}
```

In `InputMemoryApp`, set the callback:

```swift
.onAppear {
    appDelegate.onShutdown = {
        appState.shutdown()
    }
}
```

- [ ] **Step 4: Verify live build**

Run: `swift build`

Expected: PASS.

Run: `./script/build_and_run.sh`

Expected: app launches, menu bar item appears, viewer opens, and permission status is visible.

- [ ] **Step 5: Manual capture smoke test**

Grant Accessibility permission when prompted. Then:

1. Open TextEdit.
2. Focus a text document.
3. Type `InputMemory smoke test`.
4. Wait one polling interval.
5. Open viewer.

Expected: recent turn list contains a turn with `InputMemory smoke test`.

- [ ] **Step 6: Commit**

```bash
git add Sources/InputMemory/Stores/AppState.swift Sources/InputMemory/App
git commit -m "feat: wire live capture loop"
```

## Task 9: Add Daily Export Time Setting

**Files:**
- Modify: `Sources/InputMemory/Stores/AppState.swift`
- Create: `Sources/InputMemory/Views/ExportSettingsView.swift`
- Modify: `Sources/InputMemory/Views/ViewerWindowView.swift`

- [ ] **Step 1: Add export time preference**

In `AppState`, add:

```swift
var exportHour: Int {
    get { UserDefaults.standard.integer(forKey: "exportHour") }
    set { UserDefaults.standard.set(newValue, forKey: "exportHour") }
}

private var exportTimer: Timer?

func startExportScheduler() {
    exportTimer?.invalidate()
    exportTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
        self?.checkScheduledExport()
    }
}

private func checkScheduledExport(now: Date = Date()) {
    let hour = Calendar.current.component(.hour, from: now)
    let minute = Calendar.current.component(.minute, from: now)
    guard hour == exportHour, minute == 0 else { return }
    exportNow()
}
```

Default `exportHour` is `2` if the key has not been set.

- [ ] **Step 2: Add settings view**

`Sources/InputMemory/Views/ExportSettingsView.swift`:

```swift
import SwiftUI

struct ExportSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        Stepper(value: $appState.exportHour, in: 0...23) {
            Text("Daily Export Hour: \(appState.exportHour):00")
        }
    }
}
```

Add `ExportSettingsView()` to `ViewerWindowView` below `PermissionView()`.

- [ ] **Step 3: Verify build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 4: Manual export smoke test**

Run: `./script/build_and_run.sh`, click `Export Now`.

Expected: `~/Documents/InputMemory/<yesterday>.md` is created or overwritten.

- [ ] **Step 5: Commit**

```bash
git add Sources/InputMemory/Stores/AppState.swift Sources/InputMemory/Views/ExportSettingsView.swift Sources/InputMemory/Views/ViewerWindowView.swift
git commit -m "feat: add scheduled markdown export setting"
```

## Task 10: Final Verification and README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Add README**

`README.md`:

```markdown
# InputMemory

InputMemory is a local macOS menu bar app that records text observable from the foreground focused text input control.

## MVP Scope

- Records focused text-control turns through macOS Accessibility.
- Stores turns in SQLite at `~/Library/Application Support/InputMemory/input_memory.sqlite`.
- Exports the previous day's turns to Markdown in `~/Documents/InputMemory/`.
- Does not record keyboard events, clipboard history, audio, OCR, or LLM summaries.

## Run

```bash
swift run InputMemory
```

## Test

```bash
swift test
```

## Permissions

The app requires macOS Accessibility permission. If permission is missing, the app still opens and shows the permission state, but it does not capture turns.
```

- [ ] **Step 2: Run full test suite**

Run: `swift test`

Expected: PASS.

- [ ] **Step 3: Build app**

Run: `swift build`

Expected: PASS.

- [ ] **Step 4: Run app smoke test**

Run: `./script/build_and_run.sh`

Expected:

- Menu bar item appears.
- Viewer opens from menu.
- Permission state is displayed.
- Pause/Resume toggles state.
- Export Now writes previous-day Markdown.

- [ ] **Step 5: Inspect git status**

Run: `git status --short`

Expected: only intentional files are modified or untracked.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: document InputMemory MVP"
```

## Self-Review

- Spec coverage:
  - `observed_text` one-field rule: Task 2 and Task 6.
  - Turn lifecycle and end reasons: Task 2 and Task 6.
  - SQLite primary storage: Task 3.
  - Markdown T-1 export with overwrite behavior: Task 4 and Task 9.
  - Menu bar app and viewer: Task 7.
  - Accessibility permission handling: Task 5 and Task 7.
  - Pause/resume: Task 6 and Task 7.
  - Shutdown recovery: Task 3 and Task 8.
  - Hybrid capture: Task 5 and Task 8.
- Known implementation risk:
  - `AccessibilityClient` may need small compile fixes around AX value casting on the target macOS SDK.
  - SwiftPM executable does not create a polished distributable `.app` bundle. Packaging is outside this MVP and must not be added during this plan.
- No intentional placeholders remain. Implementation changes must preserve the same contracts and tests.
