import XCTest
@testable import InputMemoryCore

final class PlaceholderRuleStoreTests: XCTestCase {
    func testMissingStoreReturnsDefaultRules() {
        let store = PlaceholderRuleStore(url: temporaryRulesURL())

        let rules = store.load()

        XCTAssertTrue(rules.contains { $0.bundleID == "com.openai.codex" && $0.text == "Ask for follow-up changes" })
        XCTAssertTrue(rules.contains { $0.bundleID == "com.electron.lark" && $0.text == "沟通时请保持“公开可接受”" })
    }

    func testSavesAndLoadsCustomRules() throws {
        let url = temporaryRulesURL()
        let store = PlaceholderRuleStore(url: url)
        let rules = [
            PlaceholderRule(appName: "Example", bundleID: "com.example.app", text: "Type a message")
        ]

        try store.save(rules)

        XCTAssertEqual(store.load(), rules)
    }

    func testLoadsLegacyRulesAsExactMatch() throws {
        let url = temporaryRulesURL()
        let legacyJSON = """
        [
          {
            "id": "11111111-1111-1111-1111-111111111111",
            "appName": "Example",
            "bundleID": "com.example.app",
            "text": "Type a message"
          }
        ]
        """
        try legacyJSON.write(to: url, atomically: true, encoding: .utf8)

        let rules = PlaceholderRuleStore(url: url).load()

        XCTAssertEqual(rules.first?.matchType, .exact)
    }

    func testLoadsLegacyRulesAsAppScoped() throws {
        let url = temporaryRulesURL()
        let legacyJSON = """
        [
          {
            "id": "11111111-1111-1111-1111-111111111111",
            "appName": "Example",
            "bundleID": "com.example.app",
            "text": "Type a message"
          }
        ]
        """
        try legacyJSON.write(to: url, atomically: true, encoding: .utf8)

        let rules = PlaceholderRuleStore(url: url).load()

        XCTAssertEqual(rules.first?.scope, .app)
    }

    func testSavesAndLoadsGlobalRegexRule() throws {
        let url = temporaryRulesURL()
        let store = PlaceholderRuleStore(url: url)
        let rules = [
            PlaceholderRule(
                appName: "All Apps",
                bundleID: "",
                text: #".{1,4}"#,
                matchType: .regex,
                scope: .global
            )
        ]

        try store.save(rules)

        XCTAssertEqual(store.load(), rules)
    }

    private func temporaryRulesURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }
}
