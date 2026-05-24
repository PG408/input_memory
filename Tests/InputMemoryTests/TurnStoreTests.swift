import XCTest
@testable import InputMemoryCore

final class TurnStoreTests: XCTestCase {
    func testInsertAndUpdateTurn() throws {
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
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent[0].observedText, "hello world")
        XCTAssertEqual(recent[0].endReason, .focusChanged)
    }

    func testCloseUnclosedTurnsMarksCrashUnclosed() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let now = Date.fixture
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
