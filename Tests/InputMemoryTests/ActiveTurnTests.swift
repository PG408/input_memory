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
}
