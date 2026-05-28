import Foundation

public final class CaptureCoordinator {
    private let store: TurnStore
    private let reader: AccessibilityReading
    private var activeTurn: ActiveTurn?
    private var activeCandidate: FocusedTextCandidate?
    public var placeholderRules: [PlaceholderRule]
    public private(set) var isRecording = false

    public init(
        store: TurnStore,
        reader: AccessibilityReading,
        placeholderRules: [PlaceholderRule] = PlaceholderRuleStore.defaultRules
    ) {
        self.store = store
        self.reader = reader
        self.placeholderRules = placeholderRules
    }

    public func startRecording() {
        isRecording = true
    }

    public func pause(now: Date = Date()) {
        guard isRecording else {
            return
        }
        endActiveTurn(reason: .paused, at: now)
        isRecording = false
    }

    public func startCandidate(_ candidate: FocusedTextCandidate, now: Date = Date()) {
        activeCandidate = candidate
        activeTurn = ActiveTurn(context: candidate.context, startedAt: now)
    }

    public func tick(now: Date = Date()) {
        guard let candidate = activeCandidate, var turn = activeTurn else {
            return
        }
        let transition = turn.applyReadResult(
            reader.readText(from: candidate),
            at: now,
            placeholderRules: placeholderRules
        )

        if turn.databaseID == nil {
            if turn.everHadNonEmptyText {
                var persisted = makeTurn(from: turn, endedAt: nil, endReason: nil, now: now)
                do {
                    persisted.id = try store.insert(persisted)
                    turn.databaseID = persisted.id
                } catch {
                    activeTurn = turn
                    return
                }
            }
        } else if turn.dirty {
            do {
                try store.update(makeTurn(from: turn, endedAt: nil, endReason: nil, now: now))
                turn.dirty = false
                turn.lastFlushedAt = now
            } catch {
                activeTurn = turn
                return
            }
        }

        activeTurn = turn

        if case .endTurn(let reason) = transition {
            endActiveTurn(reason: reason, at: now)
        }
    }

    public func endActiveTurn(reason: EndReason, at date: Date = Date()) {
        guard var turn = activeTurn else {
            return
        }
        turn.lastObservedAt = date
        let persisted = makeTurn(from: turn, endedAt: date, endReason: reason, now: date)
        if persisted.id == nil {
            guard turn.everHadNonEmptyText else {
                activeTurn = nil
                activeCandidate = nil
                return
            }
            var insertable = persisted
            insertable.id = try? store.insert(insertable)
        } else {
            try? store.update(persisted)
        }
        activeTurn = nil
        activeCandidate = nil
    }

    public func shutdown(now: Date = Date()) {
        endActiveTurn(reason: .appShutdown, at: now)
    }

    private func makeTurn(from active: ActiveTurn, endedAt: Date?, endReason: EndReason?, now: Date) -> Turn {
        Turn(
            id: active.databaseID,
            observedText: active.observedText,
            observedTextHash: Hashing.sha256(active.observedText),
            observedTextLength: active.observedText.count,
            context: active.context,
            captureStatus: active.captureStatus,
            endedEmpty: active.endedEmpty,
            everHadNonEmptyText: active.everHadNonEmptyText,
            startedAt: active.startedAt,
            lastObservedAt: active.lastObservedAt,
            endedAt: endedAt,
            endReason: endReason,
            createdAt: active.startedAt,
            updatedAt: now
        )
    }
}
