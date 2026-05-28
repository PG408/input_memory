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

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
            .path
    }
}
