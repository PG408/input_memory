import XCTest
@testable import InputMemoryCore

final class CaptureCoordinatorTests: XCTestCase {
    func testNonEmptyThenEmptyEndsTurnWithTextCleared() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(
            store: store,
            reader: FakeReader(results: [.readable("hello"), .empty])
        )
        coordinator.startCandidate(.fixture(), now: .fixture)
        coordinator.tick(now: .fixture)
        coordinator.tick(now: .fixture.addingTimeInterval(1))

        let turns = try store.fetchRecent(limit: 10)
        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].observedText, "hello")
        XCTAssertEqual(turns[0].endReason, .textCleared)
        XCTAssertTrue(turns[0].endedEmpty)
    }

    func testPlaceholderEndsTurnWithoutOverwritingPersistedText() throws {
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
        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].observedText, "question")
        XCTAssertEqual(turns[0].endReason, .textCleared)
        XCTAssertTrue(turns[0].endedEmpty)
    }

    func testEmptyTurnIsNotPersisted() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(store: store, reader: FakeReader(results: [.empty]))
        coordinator.startCandidate(.fixture(), now: .fixture)
        coordinator.tick(now: .fixture)
        coordinator.endActiveTurn(reason: .focusChanged, at: .fixture.addingTimeInterval(1))

        let turns = try store.fetchRecent(limit: 10)
        XCTAssertTrue(turns.isEmpty)
    }

    func testInitialPlaceholderTurnIsNotPersisted() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(
            store: store,
            reader: FakeReader(results: [.readable("Ask for follow-up changes")])
        )
        coordinator.startCandidate(
            .fixture(context: .fixture(appName: "Codex", bundleID: "com.openai.codex")),
            now: .fixture
        )
        coordinator.tick(now: .fixture)
        coordinator.endActiveTurn(reason: .focusChanged, at: .fixture.addingTimeInterval(1))

        let turns = try store.fetchRecent(limit: 10)
        XCTAssertTrue(turns.isEmpty)
    }

    func testInvisibleTextTurnIsNotPersisted() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(
            store: store,
            reader: FakeReader(results: [.readable("\u{200B}")])
        )
        coordinator.startCandidate(.fixture(), now: .fixture)
        coordinator.tick(now: .fixture)
        coordinator.endActiveTurn(reason: .focusChanged, at: .fixture.addingTimeInterval(1))

        let turns = try store.fetchRecent(limit: 10)
        XCTAssertTrue(turns.isEmpty)
    }

    func testPauseEndsActiveTurn() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(store: store, reader: FakeReader(results: [.readable("draft")]))
        coordinator.startCandidate(.fixture(), now: .fixture)
        coordinator.tick(now: .fixture)
        coordinator.startRecording()
        coordinator.pause(now: .fixture.addingTimeInterval(2))

        let turns = try store.fetchRecent(limit: 10)
        XCTAssertEqual(turns[0].endReason, .paused)
    }

    func testAppendOnlyTurnReplacesPreviousTurnInSameWindow() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let context = CaptureContext.fixture(controlFingerprint: "first")
        let coordinator = CaptureCoordinator(
            store: store,
            reader: FakeReader(results: [.readable("ABC"), .readable("ABCD")])
        )

        coordinator.startCandidate(.fixture(context: context), now: .fixture)
        coordinator.tick(now: .fixture)
        coordinator.endActiveTurn(reason: .focusChanged, at: .fixture.addingTimeInterval(1))
        coordinator.startCandidate(
            .fixture(context: .fixture(controlFingerprint: "second")),
            now: .fixture.addingTimeInterval(2)
        )
        coordinator.tick(now: .fixture.addingTimeInterval(2))
        coordinator.endActiveTurn(reason: .focusChanged, at: .fixture.addingTimeInterval(3))

        let turns = try store.fetchRecent(limit: 10)
        XCTAssertEqual(turns.map(\.observedText), ["ABCD"])
        XCTAssertEqual(turns[0].context.controlFingerprint, "second")
        XCTAssertEqual(turns[0].startedAt, .fixture.addingTimeInterval(2))
    }

    func testEditedTurnDoesNotReplacePreviousTurnInSameWindow() throws {
        let store = try TurnStore(path: temporaryDatabasePath())
        let coordinator = CaptureCoordinator(
            store: store,
            reader: FakeReader(results: [.readable("ABC"), .readable("ABD")])
        )

        coordinator.startCandidate(.fixture(), now: .fixture)
        coordinator.tick(now: .fixture)
        coordinator.endActiveTurn(reason: .focusChanged, at: .fixture.addingTimeInterval(1))
        coordinator.startCandidate(.fixture(), now: .fixture.addingTimeInterval(2))
        coordinator.tick(now: .fixture.addingTimeInterval(2))
        coordinator.endActiveTurn(reason: .focusChanged, at: .fixture.addingTimeInterval(3))

        let turns = try store.fetchRecent(limit: 10)
        XCTAssertEqual(turns.map(\.observedText), ["ABD", "ABC"])
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
            .path
    }
}
