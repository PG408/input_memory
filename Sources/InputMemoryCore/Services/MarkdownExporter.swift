import Foundation

public final class MarkdownExporter {
    private let store: TurnStore
    private let exportDirectory: URL
    private let calendar: Calendar
    public var placeholderRules: [PlaceholderRule]

    public init(
        store: TurnStore,
        exportDirectory: URL = AppPaths.defaultExportDirectory,
        calendar: Calendar = .current,
        placeholderRules: [PlaceholderRule] = PlaceholderRuleStore.defaultRules
    ) {
        self.store = store
        self.exportDirectory = exportDirectory
        self.calendar = calendar
        self.placeholderRules = placeholderRules
    }

    @discardableResult
    public func exportPreviousDay(triggeredAt: Date = Date()) throws -> URL {
        let targetDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: triggeredAt))!
        return try export(day: targetDay, generatedAt: triggeredAt)
    }

    @discardableResult
    public func export(day: Date, generatedAt: Date = Date()) throws -> URL {
        let targetDay = calendar.startOfDay(for: day)
        AppLog.export.info("Markdown export started day=\(Self.dayFormatter.string(from: targetDay), privacy: .public)")
        let turns = try store.fetchTurns(on: targetDay, calendar: calendar)
        try AppPaths.ensureDirectory(exportDirectory)

        let outputURL = exportDirectory.appendingPathComponent(Self.fileName(for: targetDay))
        let rendered = render(day: targetDay, generatedAt: generatedAt, turns: turns)
        try rendered
            .write(to: outputURL, atomically: true, encoding: .utf8)
        AppLog.export.info("Markdown export finished day=\(Self.dayFormatter.string(from: targetDay), privacy: .public) rawTurns=\(turns.count, privacy: .public) bytes=\(rendered.utf8.count, privacy: .public) path=\(outputURL.path, privacy: .private)")
        return outputURL
    }

    @discardableResult
    public func export(startDay: Date, endDay: Date, generatedAt: Date = Date()) throws -> [URL] {
        let start = calendar.startOfDay(for: startDay)
        let end = calendar.startOfDay(for: endDay)
        guard start <= end else {
            throw ExportError.invalidDateRange
        }

        var outputURLs: [URL] = []
        var current = start
        while current <= end {
            outputURLs.append(try export(day: current, generatedAt: generatedAt))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = next
        }
        AppLog.export.info("Markdown export range finished start=\(Self.dayFormatter.string(from: start), privacy: .public) end=\(Self.dayFormatter.string(from: end), privacy: .public) files=\(outputURLs.count, privacy: .public)")
        return outputURLs
    }

    func render(day: Date, generatedAt: Date, turns: [Turn]) -> String {
        let filteredTurns = turns.compactMap { turn -> Turn? in
            let visibleText = TextSanitizer.visibleText(turn.observedText)
            guard !visibleText.isEmpty else { return nil }
            guard turn.captureStatus == .readable else { return nil }
            guard !CapturePolicy.shouldSkipCandidate(
                appName: turn.context.appName,
                bundleID: turn.context.bundleID,
                role: turn.context.controlRole,
                subrole: turn.context.controlSubrole,
                value: visibleText
            ), !PlaceholderPolicy.isPlaceholder(visibleText, context: turn.context, rules: placeholderRules) else {
                return nil
            }

            var sanitized = turn
            sanitized.observedText = visibleText
            sanitized.observedTextHash = Hashing.sha256(visibleText)
            sanitized.observedTextLength = visibleText.count
            return sanitized
        }
        let exportTurns = deduplicateAdjacent(filteredTurns)
        AppLog.export.debug("Markdown export render filtered=\(filteredTurns.count, privacy: .public) deduplicated=\(exportTurns.count, privacy: .public)")

        let grouped = Dictionary(grouping: exportTurns) { turn in
            [
                turn.context.appName,
                turn.context.bundleID,
                normalizedWindowTitle(turn.context.windowTitle)
            ].joined(separator: "|")
        }

        var lines: [String] = [
            "# InputMemory Export: \(Self.dayFormatter.string(from: day))",
            "",
            "- Generated At: \(Self.timestampFormatter.string(from: generatedAt))",
            "- Turn Count: \(exportTurns.count)",
            ""
        ]

        for key in grouped.keys.sorted() {
            guard let sessionTurns = grouped[key]?.sorted(by: { $0.startedAt < $1.startedAt }),
                  let first = sessionTurns.first else {
                continue
            }
            lines.append("## \(first.context.appName) | \(normalizedWindowTitle(first.context.windowTitle))")
            lines.append("")
            lines.append("- Bundle ID: \(first.context.bundleID)")
            lines.append("- Turns: \(sessionTurns.count)")
            lines.append("")

            for turn in sessionTurns {
                lines.append("### Turn \(turn.id ?? 0) | \(Self.timestampFormatter.string(from: turn.startedAt))")
                lines.append("")
                lines.append("- Capture Status: \(turn.captureStatus.rawValue)")
                lines.append("- End Reason: \(turn.endReason?.rawValue ?? "active")")
                lines.append("- Ended Empty: \(turn.endedEmpty)")
                lines.append("- Text Length: \(turn.observedTextLength)")
                lines.append("")
                lines.append("```text")
                lines.append(turn.observedText)
                lines.append("```")
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func deduplicateAdjacent(_ turns: [Turn]) -> [Turn] {
        var result: [Turn] = []
        var previousKey: String?

        for turn in turns.sorted(by: { $0.startedAt < $1.startedAt }) {
            let key = [
                turn.context.bundleID,
                normalizedWindowTitle(turn.context.windowTitle),
                turn.context.controlFingerprint,
                turn.observedTextHash
            ].joined(separator: "|")

            if key == previousKey {
                continue
            }
            result.append(turn)
            previousKey = key
        }

        return result
    }

    private func normalizedWindowTitle(_ title: String) -> String {
        var normalized = title
            .replacingOccurrences(
                of: #"[\u{200B}-\u{200F}\u{202A}-\u{202E}\u{2060}\u{FEFF}]"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"内存使用量高 - [^-]+ - "#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "睡眠 - ", with: "")
            .replacingOccurrences(of: "音频正在播放 - ", with: "")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized
    }

    private static func fileName(for day: Date) -> String {
        "\(dayFormatter.string(from: day)).md"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

public enum ExportError: Error, LocalizedError {
    case invalidDateRange

    public var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            return "Start date must be before or equal to end date."
        }
    }
}
