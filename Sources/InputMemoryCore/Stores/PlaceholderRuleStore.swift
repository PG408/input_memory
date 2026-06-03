import Foundation

public final class PlaceholderRuleStore {
    public static let defaultRules = [
        PlaceholderRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            appName: "Codex",
            bundleID: "com.openai.codex",
            text: "Ask for follow-up changes"
        ),
        PlaceholderRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            appName: "飞书",
            bundleID: "com.electron.lark",
            text: "沟通时请保持“公开可接受”"
        )
    ]

    private let url: URL

    public init(url: URL = AppPaths.placeholderRulesURL) {
        self.url = url
    }

    public func load() -> [PlaceholderRule] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode([PlaceholderRule].self, from: data) else {
            AppLog.placeholder.info("Loaded default placeholder rules count=\(Self.defaultRules.count, privacy: .public)")
            return Self.defaultRules
        }
        AppLog.placeholder.info("Loaded custom placeholder rules count=\(rules.count, privacy: .public) path=\(self.url.path, privacy: .private)")
        return rules
    }

    public func save(_ rules: [PlaceholderRule]) throws {
        try AppPaths.ensureDirectory(url.deletingLastPathComponent())
        let data = try JSONEncoder().encode(rules)
        try data.write(to: url, options: .atomic)
        AppLog.placeholder.info("Wrote placeholder rules count=\(rules.count, privacy: .public) path=\(self.url.path, privacy: .private)")
    }
}
