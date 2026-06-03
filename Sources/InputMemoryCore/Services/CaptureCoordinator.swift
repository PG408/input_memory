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
        AppLog.capture.info("Coordinator recording started")
    }

    public func pause(now: Date = Date()) {
        guard isRecording else {
            AppLog.capture.info("Coordinator pause ignored because recording is already stopped")
            return
        }
        endActiveTurn(reason: .paused, at: now)
        isRecording = false
        AppLog.capture.info("Coordinator recording paused")
    }

    public func startCandidate(_ candidate: FocusedTextCandidate, now: Date = Date()) {
        activeCandidate = candidate
        activeTurn = ActiveTurn(context: candidate.context, startedAt: now)
        AppLog.capture.info(
            "Candidate started app=\(candidate.context.appName, privacy: .public) bundleID=\(candidate.context.bundleID, privacy: .public) window=\(candidate.context.windowTitle, privacy: .private) role=\(candidate.context.controlRole ?? "nil", privacy: .public) fingerprintPrefix=\(AppLogMetadata.prefix(candidate.context.controlFingerprint), privacy: .public)"
        )
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
                    AppLog.turn.info(
                        "Turn inserted id=\(persisted.id ?? 0, privacy: .public) app=\(persisted.context.appName, privacy: .public) bundleID=\(persisted.context.bundleID, privacy: .public) \(AppLogMetadata.textSummary(persisted.observedText), privacy: .public)"
                    )
                } catch {
                    activeTurn = turn
                    AppLog.turn.error("Turn insert failed error=\(error.localizedDescription, privacy: .public)")
                    return
                }
            }
        } else if turn.dirty {
            do {
                try store.update(makeTurn(from: turn, endedAt: nil, endReason: nil, now: now))
                turn.dirty = false
                turn.lastFlushedAt = now
                AppLog.turn.debug("Turn updated id=\(turn.databaseID ?? 0, privacy: .public) \(AppLogMetadata.textSummary(turn.observedText), privacy: .public)")
            } catch {
                activeTurn = turn
                AppLog.turn.error("Turn update failed id=\(turn.databaseID ?? 0, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
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
        var persisted = makeTurn(from: turn, endedAt: date, endReason: reason, now: date)
        if persisted.id == nil {
            guard turn.everHadNonEmptyText else {
                AppLog.turn.info("Skipped empty turn reason=\(reason.rawValue, privacy: .public)")
                activeTurn = nil
                activeCandidate = nil
                return
            }
            do {
                persisted.id = try store.insert(persisted)
            } catch {
                AppLog.turn.error("Final turn insert failed reason=\(reason.rawValue, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            }
            compactAppendOnlyPreviousTurn(before: persisted)
        } else {
            do {
                try store.update(persisted)
            } catch {
                AppLog.turn.error("Final turn update failed id=\(persisted.id ?? 0, privacy: .public) reason=\(reason.rawValue, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            }
            compactAppendOnlyPreviousTurn(before: persisted)
        }
        AppLog.turn.info(
            "Turn ended id=\(persisted.id ?? 0, privacy: .public) reason=\(reason.rawValue, privacy: .public) status=\(persisted.captureStatus.rawValue, privacy: .public) endedEmpty=\(persisted.endedEmpty, privacy: .public) \(AppLogMetadata.textSummary(persisted.observedText), privacy: .public)"
        )
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

    private func compactAppendOnlyPreviousTurn(before turn: Turn) {
        guard let previous = try? store.fetchPreviousTurnInSameWindow(as: turn),
              let previousID = previous.id,
              shouldReplacePreviousTurn(previous, with: turn) else {
            return
        }
        try? store.deleteTurn(id: previousID)
        AppLog.turn.info("Deleted append-only previous turn previousID=\(previousID, privacy: .public) currentID=\(turn.id ?? 0, privacy: .public)")
    }

    private func shouldReplacePreviousTurn(_ previous: Turn, with current: Turn) -> Bool {
        current.observedText == previous.observedText ||
            current.observedText.hasPrefix(previous.observedText)
    }
}
