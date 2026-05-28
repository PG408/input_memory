# InputMemory Export Hygiene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce unsafe and noisy InputMemory exports while preserving SQLite as the raw source of truth.

**Architecture:** The capture layer blocks clearly sensitive controls before a turn can be created. The Markdown exporter renders a cleaned view of stored turns: non-empty, non-sensitive, normalized by context, and conservatively deduplicated. Existing SQLite rows are not migrated or deleted.

**Tech Stack:** SwiftPM, Swift, XCTest, SQLite-backed `TurnStore`, macOS Accessibility metadata.

---

## Assumptions

- SQLite remains the full raw log. This plan changes capture safety for future rows and Markdown export quality for generated files.
- Markdown is the LLM-facing artifact, so it should prefer signal over exhaustiveness.
- Deduplication must be conservative: collapse only adjacent identical non-empty snapshots in the same normalized context and control, not all repeated text across a day.
- No app blacklist is introduced beyond clearly sensitive/system contexts such as `AXSecureTextField` and `loginwindow`.

## File Structure

- Create `Sources/InputMemoryCore/Services/CapturePolicy.swift`
  - Pure, testable rules for whether a focused candidate must be ignored before capture.
- Modify `Sources/InputMemoryCore/Services/AccessibilityClient.swift`
  - Apply `CapturePolicy` after reading role/subrole/value and before returning a `FocusedTextCandidate`.
- Modify `Sources/InputMemoryCore/Services/MarkdownExporter.swift`
  - Add export-only filtering, adjacent deduplication, and window-title normalization.
- Modify `Tests/InputMemoryTests/TestFixtures.swift`
  - Add fixture helpers for contexts and ended turns used by exporter tests.
- Modify `Tests/InputMemoryTests/MarkdownExporterTests.swift`
  - Cover empty filtering, sensitive filtering, adjacent deduplication, and title normalization.
- Create `Tests/InputMemoryTests/CapturePolicyTests.swift`
  - Cover secure fields and loginwindow exclusion.
- Modify `Sources/InputMemorySelfTest/main.swift`
  - Keep fallback self-test aligned with the cleaned exporter behavior.

---

### Task 1: Add Capture Safety Policy

**Files:**
- Create: `Sources/InputMemoryCore/Services/CapturePolicy.swift`
- Test: `Tests/InputMemoryTests/CapturePolicyTests.swift`
- Modify: `Sources/InputMemoryCore/Services/AccessibilityClient.swift`

- [ ] **Step 1: Write failing policy tests**

Create `Tests/InputMemoryTests/CapturePolicyTests.swift`:

```swift
import XCTest
@testable import InputMemoryCore

final class CapturePolicyTests: XCTestCase {
    func testSkipsSecureTextField() {
        XCTAssertTrue(CapturePolicy.shouldSkipCandidate(
            appName: "loginwindow",
            bundleID: "com.apple.loginwindow",
            role: "AXTextField",
            subrole: "AXSecureTextField",
            value: "secret"
        ))
    }

    func testSkipsLoginwindowEvenWithoutSecureSubrole() {
        XCTAssertTrue(CapturePolicy.shouldSkipCandidate(
            appName: "loginwindow",
            bundleID: "com.apple.loginwindow",
            role: "AXTextField",
            subrole: nil,
            value: "anything"
        ))
    }

    func testAllowsNormalTextArea() {
        XCTAssertFalse(CapturePolicy.shouldSkipCandidate(
            appName: "TextEdit",
            bundleID: "com.apple.TextEdit",
            role: "AXTextArea",
            subrole: nil,
            value: "draft"
        ))
    }
}
```

- [ ] **Step 2: Run the new tests to verify failure**

Run:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CapturePolicyTests`

Expected: fail because `CapturePolicy` does not exist.

- [ ] **Step 3: Implement the policy**

Create `Sources/InputMemoryCore/Services/CapturePolicy.swift`:

```swift
import Foundation

public enum CapturePolicy {
    public static func shouldSkipCandidate(
        appName: String,
        bundleID: String,
        role: String?,
        subrole: String?,
        value: String?
    ) -> Bool {
        if bundleID == "com.apple.loginwindow" || appName == "loginwindow" {
            return true
        }
        if subrole == "AXSecureTextField" {
            return true
        }
        if role == "AXTextField", subrole?.localizedCaseInsensitiveContains("secure") == true {
            return true
        }
        return false
    }
}
```

- [ ] **Step 4: Apply the policy in `AccessibilityClient`**

In `focusedTextCandidate(for:)`, after `role` and `value` are read, add:

```swift
let subrole = stringAttribute(kAXSubroleAttribute, from: axElement)
guard !CapturePolicy.shouldSkipCandidate(
    appName: app.appName,
    bundleID: app.bundleID,
    role: role,
    subrole: subrole,
    value: value
) else {
    return nil
}
```

Then reuse `subrole` in `CaptureContext` instead of reading it again.

- [ ] **Step 5: Verify and commit**

Run:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CapturePolicyTests`

Expected: pass.

Commit:

`git add Sources/InputMemoryCore/Services/CapturePolicy.swift Sources/InputMemoryCore/Services/AccessibilityClient.swift Tests/InputMemoryTests/CapturePolicyTests.swift && git commit -m "fix: skip sensitive accessibility controls"`

---

### Task 2: Filter Empty and Sensitive Turns from Markdown

**Files:**
- Modify: `Sources/InputMemoryCore/Services/MarkdownExporter.swift`
- Modify: `Tests/InputMemoryTests/MarkdownExporterTests.swift`
- Modify: `Tests/InputMemoryTests/TestFixtures.swift`

- [ ] **Step 1: Add exporter fixtures**

Add these helpers to `Tests/InputMemoryTests/TestFixtures.swift`:

```swift
extension CaptureContext {
    static func fixture(
        appName: String = "TestApp",
        bundleID: String = "com.example.TestApp",
        windowTitle: String = "Test Window",
        controlRole: String? = "AXTextField",
        controlSubrole: String? = nil,
        controlFingerprint: String = "fixture",
        isHeuristicTextControl: Bool = false
    ) -> CaptureContext {
        CaptureContext(
            appName: appName,
            bundleID: bundleID,
            windowTitle: windowTitle,
            controlRole: controlRole,
            controlSubrole: controlSubrole,
            controlTitle: nil,
            controlDescription: nil,
            controlPathHint: nil,
            controlFrame: nil,
            controlFingerprint: controlFingerprint,
            isHeuristicTextControl: isHeuristicTextControl
        )
    }
}

extension Turn {
    static func fixture(
        observedText: String,
        context: CaptureContext,
        at date: Date
    ) -> Turn {
        Turn(
            id: nil,
            observedText: observedText,
            observedTextHash: Hashing.sha256(observedText),
            observedTextLength: observedText.count,
            context: context,
            captureStatus: observedText.isEmpty ? .empty : .readable,
            endedEmpty: observedText.isEmpty,
            everHadNonEmptyText: !observedText.isEmpty,
            startedAt: date,
            lastObservedAt: date,
            endedAt: date.addingTimeInterval(1),
            endReason: .focusChanged,
            createdAt: date,
            updatedAt: date
        )
    }
}
```

- [ ] **Step 2: Write failing exporter filtering test**

Add to `MarkdownExporterTests`:

```swift
func testExportSkipsEmptyAndSensitiveTurns() throws {
    let day = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 27))!
    let safe = Turn.fixture(
        observedText: "real input",
        context: .fixture(),
        at: day.addingTimeInterval(60)
    )
    let empty = Turn.fixture(
        observedText: "",
        context: .fixture(controlFingerprint: "empty"),
        at: day.addingTimeInterval(120)
    )
    let secure = Turn.fixture(
        observedText: "do-not-export",
        context: .fixture(
            appName: "loginwindow",
            bundleID: "com.apple.loginwindow",
            controlRole: "AXTextField",
            controlSubrole: "AXSecureTextField",
            controlFingerprint: "secure"
        ),
        at: day.addingTimeInterval(180)
    )

    let exporter = MarkdownExporter(store: try TurnStore(path: temporaryDatabasePath()))
    let markdown = exporter.render(day: day, generatedAt: day, turns: [safe, empty, secure])

    XCTAssertTrue(markdown.contains("- Turn Count: 1"))
    XCTAssertTrue(markdown.contains("real input"))
    XCTAssertFalse(markdown.contains("do-not-export"))
    XCTAssertFalse(markdown.contains("- Text Length: 0"))
}
```

- [ ] **Step 3: Implement export filtering**

In `MarkdownExporter.render`, create `exportTurns` first:

```swift
let exportTurns = turns.filter { turn in
    guard turn.observedTextLength > 0 else { return false }
    guard turn.captureStatus == .readable else { return false }
    return !CapturePolicy.shouldSkipCandidate(
        appName: turn.context.appName,
        bundleID: turn.context.bundleID,
        role: turn.context.controlRole,
        subrole: turn.context.controlSubrole,
        value: turn.observedText
    )
}
```

Use `exportTurns` for `Turn Count` and grouping. Keep the header name as `Turn Count` for compatibility.

- [ ] **Step 4: Verify and commit**

Run:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MarkdownExporterTests`

Expected: pass.

Commit:

`git add Sources/InputMemoryCore/Services/MarkdownExporter.swift Tests/InputMemoryTests/MarkdownExporterTests.swift Tests/InputMemoryTests/TestFixtures.swift && git commit -m "fix: filter noisy markdown turns"`

---

### Task 3: Deduplicate Adjacent Identical Export Snapshots

**Files:**
- Modify: `Sources/InputMemoryCore/Services/MarkdownExporter.swift`
- Modify: `Tests/InputMemoryTests/MarkdownExporterTests.swift`

- [ ] **Step 1: Write failing adjacent dedupe test**

Add to `MarkdownExporterTests`:

```swift
func testExportCollapsesAdjacentIdenticalTurnsInSameControl() throws {
    let day = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 27))!
    let context = CaptureContext.fixture(controlFingerprint: "same-control")
    let first = Turn.fixture(observedText: "same text", context: context, at: day.addingTimeInterval(60))
    let second = Turn.fixture(observedText: "same text", context: context, at: day.addingTimeInterval(120))
    let changed = Turn.fixture(observedText: "changed text", context: context, at: day.addingTimeInterval(180))

    let exporter = MarkdownExporter(store: try TurnStore(path: temporaryDatabasePath()))
    let markdown = exporter.render(day: day, generatedAt: day, turns: [first, second, changed])

    XCTAssertTrue(markdown.contains("- Turn Count: 2"))
    XCTAssertEqual(markdown.components(separatedBy: "same text").count - 1, 1)
    XCTAssertTrue(markdown.contains("changed text"))
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MarkdownExporterTests/testExportCollapsesAdjacentIdenticalTurnsInSameControl`

Expected: fail because both identical turns are exported.

- [ ] **Step 3: Implement conservative dedupe**

Add a private method in `MarkdownExporter`:

```swift
private func deduplicateAdjacent(_ turns: [Turn]) -> [Turn] {
    var result: [Turn] = []
    var previousKey: String?

    for turn in turns.sorted(by: { $0.startedAt < $1.startedAt }) {
        let key = [
            turn.context.bundleID,
            normalizedWindowTitle(turn.context.windowTitle),
            turn.context.controlFingerprint,
            turn.observedTextHash
        ].joined(separator: "|")

        if key == previousKey {
            continue
        }
        result.append(turn)
        previousKey = key
    }

    return result
}
```

Call it after filtering and before grouping:

```swift
let exportTurns = deduplicateAdjacent(filteredTurns)
```

- [ ] **Step 4: Verify and commit**

Run:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MarkdownExporterTests`

Expected: pass.

Commit:

`git add Sources/InputMemoryCore/Services/MarkdownExporter.swift Tests/InputMemoryTests/MarkdownExporterTests.swift && git commit -m "fix: dedupe repeated markdown snapshots"`

---

### Task 4: Normalize Window Titles in Export Grouping

**Files:**
- Modify: `Sources/InputMemoryCore/Services/MarkdownExporter.swift`
- Modify: `Tests/InputMemoryTests/MarkdownExporterTests.swift`

- [ ] **Step 1: Write failing normalization test**

Add to `MarkdownExporterTests`:

```swift
func testExportNormalizesDynamicBrowserWindowTitles() throws {
    let day = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 27))!
    let first = Turn.fixture(
        observedText: "draft one",
        context: .fixture(
            appName: "Microsoft Edge",
            bundleID: "com.microsoft.edgemac",
            windowTitle: "广告策略 - 飞书云文档 - 内存使用量高 - 1.2 GB - Microsoft Edge",
            controlFingerprint: "a"
        ),
        at: day.addingTimeInterval(60)
    )
    let second = Turn.fixture(
        observedText: "draft two",
        context: .fixture(
            appName: "Microsoft Edge",
            bundleID: "com.microsoft.edgemac",
            windowTitle: "广告策略 - 飞书云文档 - 睡眠 - Microsoft Edge",
            controlFingerprint: "b"
        ),
        at: day.addingTimeInterval(120)
    )

    let exporter = MarkdownExporter(store: try TurnStore(path: temporaryDatabasePath()))
    let markdown = exporter.render(day: day, generatedAt: day, turns: [first, second])

    XCTAssertEqual(markdown.components(separatedBy: "## Microsoft Edge | 广告策略 - 飞书云文档 - Microsoft Edge").count - 1, 1)
    XCTAssertFalse(markdown.contains("内存使用量高"))
    XCTAssertFalse(markdown.contains("睡眠 -"))
}
```

- [ ] **Step 2: Implement title normalization**

Add a private method in `MarkdownExporter`:

```swift
private func normalizedWindowTitle(_ title: String) -> String {
    var normalized = title
        .replacingOccurrences(of: #"[\u{200B}-\u{200F}\u{202A}-\u{202E}\u{2060}\u{FEFF}]"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"内存使用量高 - [^-]+ - "#, with: "", options: .regularExpression)
        .replacingOccurrences(of: "睡眠 - ", with: "")
        .replacingOccurrences(of: "音频正在播放 - ", with: "")
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized
}
```

Use this method in the grouping key and section heading:

```swift
let grouped = Dictionary(grouping: exportTurns) { turn in
    [
        turn.context.appName,
        turn.context.bundleID,
        normalizedWindowTitle(turn.context.windowTitle)
    ].joined(separator: "|")
}
```

When rendering the section heading:

```swift
lines.append("## \(first.context.appName) | \(normalizedWindowTitle(first.context.windowTitle))")
```

- [ ] **Step 3: Verify and commit**

Run:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MarkdownExporterTests`

Expected: pass.

Commit:

`git add Sources/InputMemoryCore/Services/MarkdownExporter.swift Tests/InputMemoryTests/MarkdownExporterTests.swift && git commit -m "fix: normalize markdown export contexts"`

---

### Task 5: Align Self-Test and Run End-to-End Checks

**Files:**
- Modify: `Sources/InputMemorySelfTest/main.swift`
- No app UI changes.

- [ ] **Step 1: Update self-test expectations**

In `testMarkdownExporter()`, add one empty turn and assert that it is not rendered:

```swift
var emptyTurn = Turn.fixture(observedText: "", at: targetDay.addingTimeInterval(7200))
emptyTurn.id = try store.insert(emptyTurn)
```

Then assert:

```swift
try expect(markdown.contains("- Turn Count: 1"), "export should count only exportable turns")
try expect(!markdown.contains("- Text Length: 0"), "export should skip empty turns")
```

- [ ] **Step 2: Run full verification**

Run:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`

Expected: all XCTest cases pass.

Run:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`

Expected: build succeeds.

Run:

`swift run InputMemorySelfTest`

Expected: `InputMemorySelfTest passed`.

- [ ] **Step 3: Optional local export smoke check**

Run:

`./script/build_and_run.sh`

Then use the menu bar `Export Now` action and inspect yesterday's generated file under `~/Documents/InputMemory/`.

Expected:

- No `AXSecureTextField` content.
- No `Text Length: 0`.
- Fewer repeated identical sections.
- Browser/Feishu document titles are less fragmented.

- [ ] **Step 4: Commit final self-test alignment**

Commit:

`git add Sources/InputMemorySelfTest/main.swift && git commit -m "test: align self test with cleaned exports"`

---

## Non-Goals

- Do not delete or mutate existing SQLite rows.
- Do not add clipboard capture, OCR, keyboard logging, or app-wide blacklist UI.
- Do not summarize memory content in this change.
- Do not attempt semantic duplicate detection; exact adjacent duplicate collapse is enough for MVP.

## Acceptance Criteria

- Future capture does not create turns for `AXSecureTextField` or `loginwindow`.
- Markdown export excludes empty, unreadable, and sensitive turns.
- Adjacent identical text snapshots in the same normalized context/control appear once in Markdown.
- Export grouping uses normalized window titles.
- Full verification passes: `swift test`, `swift build`, and `InputMemorySelfTest`.
