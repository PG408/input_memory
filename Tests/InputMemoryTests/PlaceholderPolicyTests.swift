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

    func testMatchesCustomRule() {
        let rules = [
            PlaceholderRule(
                appName: "Example",
                bundleID: "com.example.app",
                text: "Type a message"
            )
        ]

        XCTAssertTrue(PlaceholderPolicy.isPlaceholder(
            " Type a message ",
            context: .fixture(appName: "Example", bundleID: "com.example.app"),
            rules: rules
        ))
    }

    func testRegexRuleMatchesFullNormalizedText() {
        let rules = [
            PlaceholderRule(
                appName: "Example",
                bundleID: "com.example.app",
                text: "^Ask for .* changes$",
                matchType: .regex
            )
        ]

        XCTAssertTrue(PlaceholderPolicy.isPlaceholder(
            "\u{200B}Ask for follow-up changes\n",
            context: .fixture(appName: "Example", bundleID: "com.example.app"),
            rules: rules
        ))
    }

    func testRegexRuleDoesNotMatchPartialText() {
        let rules = [
            PlaceholderRule(
                appName: "Example",
                bundleID: "com.example.app",
                text: "follow-up",
                matchType: .regex
            )
        ]

        XCTAssertFalse(PlaceholderPolicy.isPlaceholder(
            "Ask for follow-up changes",
            context: .fixture(appName: "Example", bundleID: "com.example.app"),
            rules: rules
        ))
    }

    func testInvalidRegexRuleDoesNotMatch() {
        let rules = [
            PlaceholderRule(
                appName: "Example",
                bundleID: "com.example.app",
                text: "[",
                matchType: .regex
            )
        ]

        XCTAssertFalse(PlaceholderPolicy.isPlaceholder(
            "[",
            context: .fixture(appName: "Example", bundleID: "com.example.app"),
            rules: rules
        ))
    }

    func testGlobalExactRuleMatchesDifferentApps() {
        let rules = [
            PlaceholderRule(
                appName: "All Apps",
                bundleID: "",
                text: "placeholder",
                scope: .global
            )
        ]

        XCTAssertTrue(PlaceholderPolicy.isPlaceholder(
            "placeholder",
            context: .fixture(appName: "TextEdit", bundleID: "com.apple.TextEdit"),
            rules: rules
        ))
        XCTAssertTrue(PlaceholderPolicy.isPlaceholder(
            "placeholder",
            context: .fixture(appName: "Codex", bundleID: "com.openai.codex"),
            rules: rules
        ))
    }

    func testGlobalRegexRuleMatchesDifferentApps() {
        let rules = [
            PlaceholderRule(
                appName: "All Apps",
                bundleID: "",
                text: #"(?!(?=.*[\p{Han}A-Za-z0-9])).{1,4}"#,
                matchType: .regex,
                scope: .global
            )
        ]

        XCTAssertTrue(PlaceholderPolicy.isPlaceholder(
            "@@@",
            context: .fixture(appName: "TextEdit", bundleID: "com.apple.TextEdit"),
            rules: rules
        ))
        XCTAssertFalse(PlaceholderPolicy.isPlaceholder(
            "abc",
            context: .fixture(appName: "TextEdit", bundleID: "com.apple.TextEdit"),
            rules: rules
        ))
    }
}
