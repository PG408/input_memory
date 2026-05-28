import Foundation

public enum TextReadResult: Equatable, Sendable {
    case readable(String)
    case empty
    case unreadable
}

public enum TurnTransition: Equatable, Sendable {
    case continueTurn
    case endTurn(EndReason)
}

public struct ActiveTurn: Sendable {
    public var databaseID: Int64?
    public var context: CaptureContext
    public var observedText: String
    public var lastRawText: String
    public var everHadNonEmptyText: Bool
    public var endedEmpty: Bool
    public var captureStatus: CaptureStatus
    public var startedAt: Date
    public var lastObservedAt: Date
    public var dirty: Bool
    public var lastFlushedAt: Date?

    public init(context: CaptureContext, startedAt: Date = Date()) {
        self.databaseID = nil
        self.context = context
        self.observedText = ""
        self.lastRawText = ""
        self.everHadNonEmptyText = false
        self.endedEmpty = false
        self.captureStatus = .pending
        self.startedAt = startedAt
        self.lastObservedAt = startedAt
        self.dirty = true
        self.lastFlushedAt = nil
    }

    @discardableResult
    public mutating func applyReadResult(_ result: TextReadResult, at date: Date) -> TurnTransition {
        lastObservedAt = date
        let effectiveResult: TextReadResult
        if case .readable(let text) = result, PlaceholderPolicy.isPlaceholder(text, context: context) {
            effectiveResult = .empty
        } else {
            effectiveResult = result
        }

        switch effectiveResult {
        case .readable(let text) where !text.isEmpty:
            observedText = text
            lastRawText = text
            everHadNonEmptyText = true
            endedEmpty = false
            captureStatus = .readable
            dirty = true
            return .continueTurn

        case .readable:
            fallthrough
        case .empty:
            lastRawText = ""
            captureStatus = everHadNonEmptyText ? .readable : .empty
            dirty = true
            if everHadNonEmptyText {
                endedEmpty = true
                return .endTurn(.textCleared)
            }
            return .continueTurn

        case .unreadable:
            captureStatus = .unreadable
            dirty = true
            return .continueTurn
        }
    }
}
