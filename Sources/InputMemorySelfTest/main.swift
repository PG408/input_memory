import ApplicationServices
import Foundation
import InputMemoryCore

@main
enum InputMemorySelfTest {
    static func main() throws {
        try testActiveTurnRules()
        try testTurnStoreInsertUpdate()
        try testCloseUnclosedTurns()
        try testMarkdownExporter()
        try testCaptureCoordinatorTextCleared()
        try testCaptureCoordinatorSkipsEmptyTurn()
        try testCaptureCoordinatorPlaceholder()
        try testCaptureCoordinatorPause()
        print("InputMemorySelfTest passed")
    }

    private static func testActiveTurnRules() throws {
        var turn = ActiveTurn(context: .fixture(), startedAt: .fixture)
        turn.applyReadResult(.readable("hello"), at: .fixture)
        turn.applyReadResult(.readable("hello world"), at: .fixture.addingTimeInterval(1))
        try expect(turn.observedText == "hello world", "non-empty text should overwrite observedText")
        try expect(turn.everHadNonEmptyText, "turn should remember non-empty reads")
        try expect(!turn.endedEmpty, "non-empty read should not mark endedEmpty")

        let transition = turn.applyReadResult(.empty, at: .fixture.addingTimeInterval(2))
        try expect(turn.observedText == "hello world", "empty text must not overwrite non-empty observedText")
        try expect(turn.endedEmpty, "empty after non-empty should mark endedEmpty")
        try expect(transition == .endTurn(.textCleared), "empty after non-empty should end turn")

        var emptyTurn = ActiveTurn(context: .fixture(), startedAt: .fixture)
        let emptyTransition = emptyTurn.applyReadResult(.empty, at: .fixture)
        try expect(emptyTurn.observedText == "", "never-non-empty turn should keep empty observedText")
        try expect(emptyTransition == .continueTurn, "initial empty turn should continue")

        var placeholderTurn = ActiveTurn(
            context: .fixture(appName: "Codex", bundleID: "com.openai.codex"),
            startedAt: .fixture
        )
        placeholderTurn.applyReadResult(.readable("actual question"), at: .fixture)
        let placeholderTransition = placeholderTurn.applyReadResult(
            .readable("Ask for follow-up changes"),
            at: .fixture.addingTimeInterval(1)
        )
        try expect(
            placeholderTurn.observedText == "actual question",
            "placeholder text must not overwrite non-empty observedText"
        )
        try expect(
            placeholderTransition == .endTurn(.textCleared),
            "placeholder after non-empty should end turn"
        )
    }

    private static func testTurnStoreInsertUpdate() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let now = Date.fixture
        var turn = Turn.fixture(observedText: "hello", at: now)
        turn.id = try store.insert(turn)
        turn.observedText = "hello world"
        turn.observedTextHash = Hashing.sha256("hello world")
        turn.observedTextLength = 11
        turn.endedAt = now.addingTimeInterval(5)
        turn.endReason = .focusChanged
        try store.update(turn)

        let recent = try store.fetchRecent(limit: 10)
        try expect(recent.count == 1, "store should return inserted turn")
        try expect(recent[0].observedText == "hello world", "store should persist updated observedText")
        try expect(recent[0].endReason == .focusChanged, "store should persist endReason")
    }

    private static func testCloseUnclosedTurns() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let now = Date.fixture
        var turn = Turn.fixture(observedText: "draft", at: now)
        turn.id = try store.insert(turn)

        try store.closeUnclosedTurns()

        let recent = try store.fetchRecent(limit: 10)
        try expect(recent[0].endReason == .crashUnclosed, "unclosed turns should be marked crash_unclosed")
        try expect(recent[0].endedAt == now, "unclosed turn endedAt should use lastObservedAt")
    }

    private static func testMarkdownExporter() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = try TurnStore(path: directory.appendingPathComponent("test.sqlite").path)
        let targetDay = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 22))!
        var turn = Turn.fixture(observedText: "# hello\nbody", at: targetDay.addingTimeInterval(3600))
        turn.id = try store.insert(turn)
        var emptyTurn = Turn.fixture(observedText: "", at: targetDay.addingTimeInterval(7200))
        emptyTurn.id = try store.insert(emptyTurn)

        let exporter = MarkdownExporter(store: store, exportDirectory: directory)
        let outputURL = try exporter.exportPreviousDay(triggeredAt: targetDay.addingTimeInterval(86_400))

        let markdown = try String(contentsOf: outputURL, encoding: .utf8)
        try expect(markdown.contains("# InputMemory Export: 2026-05-22"), "export should use previous day")
        try expect(markdown.contains("- Turn Count: 1"), "export should count only exportable turns")
        try expect(markdown.contains("## TestApp | Test Window"), "export should group by app and window")
        try expect(markdown.contains("```text\n# hello\nbody\n```"), "export should fence observed text")
        try expect(!markdown.contains("- Text Length: 0"), "export should skip empty turns")
    }

    private static func testCaptureCoordinatorTextCleared() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(
            store: store,
            reader: FakeReader(results: [.readable("hello"), .empty])
        )
        coordinator.startCandidate(.fixture(), now: .fixture)
        coordinator.tick(now: .fixture)
        coordinator.tick(now: .fixture.addingTimeInterval(1))

        let turns = try store.fetchRecent(limit: 10)
        try expect(turns.count == 1, "coordinator should insert one turn")
        try expect(turns[0].observedText == "hello", "text_cleared should keep last non-empty text")
        try expect(turns[0].endReason == .textCleared, "empty after non-empty should end as text_cleared")
        try expect(turns[0].endedEmpty, "text_cleared turn should mark endedEmpty")
    }

    private static func testCaptureCoordinatorSkipsEmptyTurn() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(store: store, reader: FakeReader(results: [.empty]))
        coordinator.startCandidate(.fixture(), now: .fixture)
        coordinator.tick(now: .fixture)
        coordinator.endActiveTurn(reason: .focusChanged, at: .fixture.addingTimeInterval(1))

        let turns = try store.fetchRecent(limit: 10)
        try expect(turns.isEmpty, "coordinator should not persist never-non-empty turns")
    }

    private static func testCaptureCoordinatorPlaceholder() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(
            store: store,
            reader: FakeReader(results: [.readable("question"), .readable("Ask for follow-up changes")])
        )
        coordinator.startCandidate(
            .fixture(context: .fixture(appName: "Codex", bundleID: "com.openai.codex")),
            now: .fixture
        )
        coordinator.tick(now: .fixture)
        coordinator.tick(now: .fixture.addingTimeInterval(1))

        let turns = try store.fetchRecent(limit: 10)
        try expect(turns[0].observedText == "question", "placeholder should not overwrite persisted text")
        try expect(turns[0].endReason == .textCleared, "placeholder should end the current turn")
    }

    private static func testCaptureCoordinatorPause() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(store: store, reader: FakeReader(results: [.readable("draft")]))
        coordinator.startCandidate(.fixture(), now: .fixture)
        coordinator.tick(now: .fixture)
        coordinator.startRecording()
        coordinator.pause(now: .fixture.addingTimeInterval(2))

        let turns = try store.fetchRecent(limit: 10)
        try expect(turns[0].endReason == .paused, "pause should end active turn")
    }

    private static func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
            .path
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw SelfTestError.assertionFailed(message)
        }
    }
}

enum SelfTestError: Error, CustomStringConvertible {
    case assertionFailed(String)

    var description: String {
        switch self {
        case .assertionFailed(let message):
            return message
        }
    }
}

extension Date {
    static let fixture = Date(timeIntervalSince1970: 1_800_000_000)
}

extension CaptureContext {
    static func fixture(
        appName: String = "TestApp",
        bundleID: String = "com.example.TestApp"
    ) -> CaptureContext {
        CaptureContext(
            appName: appName,
            bundleID: bundleID,
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

extension FocusedTextCandidate {
    static func fixture(context: CaptureContext = .fixture()) -> FocusedTextCandidate {
        FocusedTextCandidate(
            element: AXUIElementCreateSystemWide(),
            context: context
        )
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
