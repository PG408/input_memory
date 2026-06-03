import Foundation

public enum PlaceholderMatchType: String, Codable, Sendable {
    case exact
    case regex
}

public enum PlaceholderRuleScope: String, Codable, Sendable {
    case app
    case global
}

public struct PlaceholderRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var appName: String
    public var bundleID: String
    public var text: String
    public var matchType: PlaceholderMatchType
    public var scope: PlaceholderRuleScope

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleID: String,
        text: String,
        matchType: PlaceholderMatchType = .exact,
        scope: PlaceholderRuleScope = .app
    ) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.text = text
        self.matchType = matchType
        self.scope = scope
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case appName
        case bundleID
        case text
        case matchType
        case scope
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        appName = try container.decode(String.self, forKey: .appName)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        text = try container.decode(String.self, forKey: .text)
        matchType = try container.decodeIfPresent(PlaceholderMatchType.self, forKey: .matchType) ?? .exact
        scope = try container.decodeIfPresent(PlaceholderRuleScope.self, forKey: .scope) ?? .app
    }
}
