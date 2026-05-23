import ApplicationServices
import Foundation
import InputMemoryCore

@main
enum InputMemorySelfTest {
    static func main() throws {
        try testActiveTurnRules()
        try testTurnStoreInsertUpdate()
        try testCloseUnclosedTurns()
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
