import Foundation

public struct PlaceholderRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var appName: String
    public var bundleID: String
    public var text: String

    public init(id: UUID = UUID(), appName: String, bundleID: String, text: String) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.text = text
    }
}
