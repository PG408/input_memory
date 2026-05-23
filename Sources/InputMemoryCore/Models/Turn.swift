import Foundation

public struct Turn: Identifiable, Equatable, Sendable {
    public var id: Int64?
    public var observedText: String
    public var observedTextHash: String
    public var observedTextLength: Int
    public var context: CaptureContext
    public var captureStatus: CaptureStatus
    public var endedEmpty: Bool
    public var everHadNonEmptyText: Bool
    public var startedAt: Date
    public var lastObservedAt: Date
    public var endedAt: Date?
    public var endReason: EndReason?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: Int64?,
        observedText: String,
        observedTextHash: String,
        observedTextLength: Int,
        context: CaptureContext,
        captureStatus: CaptureStatus,
        endedEmpty: Bool,
        everHadNonEmptyText: Bool,
        startedAt: Date,
        lastObservedAt: Date,
        endedAt: Date?,
        endReason: EndReason?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.observedText = observedText
        self.observedTextHash = observedTextHash
        self.observedTextLength = observedTextLength
        self.context = context
        self.captureStatus = captureStatus
        self.endedEmpty = endedEmpty
        self.everHadNonEmptyText = everHadNonEmptyText
        self.startedAt = startedAt
        self.lastObservedAt = lastObservedAt
        self.endedAt = endedAt
        self.endReason = endReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum CaptureStatus: String, Equatable, Sendable {
    case pending
    case readable
    case empty
    case unreadable
    case permissionDenied = "permission_denied"
}

public enum EndReason: String, Equatable, Sendable {
    case appChanged = "app_changed"
    case focusChanged = "focus_changed"
    case textCleared = "text_cleared"
    case controlUnavailable = "control_unavailable"
    case idleTimeout = "idle_timeout"
    case paused
    case appShutdown = "app_shutdown"
    case crashUnclosed = "crash_unclosed"
}
