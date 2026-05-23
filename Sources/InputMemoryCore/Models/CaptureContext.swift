import Foundation

public struct CaptureContext: Equatable, Sendable {
    public var appName: String
    public var bundleID: String
    public var windowTitle: String
    public var controlRole: String?
    public var controlSubrole: String?
    public var controlTitle: String?
    public var controlDescription: String?
    public var controlPathHint: String?
    public var controlFrame: String?
    public var controlFingerprint: String
    public var isHeuristicTextControl: Bool

    public init(
        appName: String,
        bundleID: String,
        windowTitle: String,
        controlRole: String?,
        controlSubrole: String?,
        controlTitle: String?,
        controlDescription: String?,
        controlPathHint: String?,
        controlFrame: String?,
        controlFingerprint: String,
        isHeuristicTextControl: Bool
    ) {
        self.appName = appName
        self.bundleID = bundleID
        self.windowTitle = windowTitle
        self.controlRole = controlRole
        self.controlSubrole = controlSubrole
        self.controlTitle = controlTitle
        self.controlDescription = controlDescription
        self.controlPathHint = controlPathHint
        self.controlFrame = controlFrame
        self.controlFingerprint = controlFingerprint
        self.isHeuristicTextControl = isHeuristicTextControl
    }
}
