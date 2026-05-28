import XCTest
@testable import InputMemoryCore

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

    func testPlaceholderDoesNotOverwriteExistingNonEmptyText() {
        var turn = ActiveTurn(context: .fixture(appName: "Codex", bundleID: "com.openai.codex"))
        turn.applyReadResult(.readable("my actual question"), at: .fixture)
        let transition = turn.applyReadResult(
            .readable("Ask for follow-up changes"),
            at: .fixture.addingTimeInterval(1)
        )

        XCTAssertEqual(turn.observedText, "my actual question")
        XCTAssertTrue(turn.endedEmpty)
        XCTAssertEqual(transition, .endTurn(.textCleared))
    }

    func testInitialPlaceholderDoesNotBecomeObservedText() {
        var turn = ActiveTurn(context: .fixture(appName: "飞书", bundleID: "com.electron.lark"))
        let transition = turn.applyReadResult(
            .readable("沟通时请保持“公开可接受”\n\u{200B}"),
            at: .fixture
        )

        XCTAssertEqual(turn.observedText, "")
        XCTAssertFalse(turn.everHadNonEmptyText)
        XCTAssertEqual(transition, .continueTurn)
    }
}
