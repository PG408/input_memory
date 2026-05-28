import XCTest
@testable import InputMemoryCore

final class PlaceholderPolicyTests: XCTestCase {
    func testMatchesCodexFollowUpPlaceholder() {
        XCTAssertTrue(PlaceholderPolicy.isPlaceholder(
            " Ask for follow-up changes\n",
            context: .fixture(appName: "Codex", bundleID: "com.openai.codex")
        ))
    }

    func testMatchesLarkPubliclyAcceptablePlaceholderWithZeroWidthCharacters() {
        XCTAssertTrue(PlaceholderPolicy.isPlaceholder(
            "沟通时请保持“公开可接受”\n\u{200B}\n\u{200B}",
            context: .fixture(appName: "飞书", bundleID: "com.electron.lark")
        ))
    }

    func testDoesNotMatchSameTextInDifferentApp() {
        XCTAssertFalse(PlaceholderPolicy.isPlaceholder(
            "Ask for follow-up changes",
            context: .fixture(appName: "TextEdit", bundleID: "com.apple.TextEdit")
        ))
    }
}
