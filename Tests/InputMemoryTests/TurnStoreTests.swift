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

    func testFetchRecentSkipsEmptyTurns() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let now = Date.fixture
        var empty = Turn.fixture(observedText: "", at: now)
        empty.id = try store.insert(empty)
        var nonEmpty = Turn.fixture(observedText: "draft", at: now.addingTimeInterval(1))
        nonEmpty.id = try store.insert(nonEmpty)

        let recent = try store.fetchRecent(limit: 10)
        XCTAssertEqual(recent.map(\.observedText), ["draft"])
    }

    func testFetchRecentSkipsInvisibleTextTurns() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let now = Date.fixture
        var invisible = Turn.fixture(observedText: "\u{200B}", at: now)
        invisible.id = try store.insert(invisible)
        var nonEmpty = Turn.fixture(observedText: "draft", at: now.addingTimeInterval(1))
        nonEmpty.id = try store.insert(nonEmpty)

        let recent = try store.fetchRecent(limit: 10)
        XCTAssertEqual(recent.map(\.observedText), ["draft"])
    }

    func testCompactionRemovesCrashRecoveredAppendOnlyDuplicate() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let now = Date.fixture
        var first = Turn.fixture(observedText: "why: high cost\nhow:", at: now)
        first.endedAt = now.addingTimeInterval(60)
        first.endReason = .appChanged
        first.id = try store.insert(first)
        var duplicate = Turn.fixture(observedText: "why: high cost\nhow:", at: now.addingTimeInterval(120))
        duplicate.id = try store.insert(duplicate)

        try store.closeUnclosedTurns()
        try store.compactAppendOnlyTurns()

        let recent = try store.fetchRecent(limit: 10)
        XCTAssertEqual(recent.map(\.observedText), ["why: high cost\nhow:"])
        XCTAssertEqual(recent[0].id, duplicate.id)
        XCTAssertEqual(recent[0].endReason, .crashUnclosed)
    }

    func testCompactionKeepsEditedTurnsInSameWindow() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let now = Date.fixture
        var first = Turn.fixture(observedText: "ABC", at: now)
        first.id = try store.insert(first)
        var edited = Turn.fixture(observedText: "ABD", at: now.addingTimeInterval(120))
        edited.id = try store.insert(edited)

        try store.compactAppendOnlyTurns()

        let recent = try store.fetchRecent(limit: 10)
        XCTAssertEqual(recent.map(\.observedText), ["ABD", "ABC"])
    }

    func testCompactionDeletesInvisibleTextTurns() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let now = Date.fixture
        var invisible = Turn.fixture(observedText: "\u{200B}", at: now)
        invisible.id = try store.insert(invisible)
        var nonEmpty = Turn.fixture(observedText: "draft", at: now.addingTimeInterval(1))
        nonEmpty.id = try store.insert(nonEmpty)

        try store.compactAppendOnlyTurns()

        let recent = try store.fetchRecent(limit: 10)
        XCTAssertEqual(recent.map(\.observedText), ["draft"])
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
            .path
    }
}
