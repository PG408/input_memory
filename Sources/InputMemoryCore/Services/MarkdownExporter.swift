import Foundation

public final class MarkdownExporter {
    private let store: TurnStore
    private let exportDirectory: URL
    private let calendar: Calendar

    public init(
        store: TurnStore,
        exportDirectory: URL = AppPaths.defaultExportDirectory,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.exportDirectory = exportDirectory
        self.calendar = calendar
    }

    @discardableResult
    public func exportPreviousDay(triggeredAt: Date = Date()) throws -> URL {
        let targetDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: triggeredAt))!
        let turns = try store.fetchTurns(on: targetDay, calendar: calendar)
        try AppPaths.ensureDirectory(exportDirectory)

        let outputURL = exportDirectory.appendingPathComponent(Self.fileName(for: targetDay))
        try render(day: targetDay, generatedAt: triggeredAt, turns: turns)
            .write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    func render(day: Date, generatedAt: Date, turns: [Turn]) -> String {
        let filteredTurns = turns.filter { turn in
            guard turn.observedTextLength > 0 else { return false }
            guard turn.captureStatus == .readable else { return false }
            return !CapturePolicy.shouldSkipCandidate(
                appName: turn.context.appName,
                bundleID: turn.context.bundleID,
                role: turn.context.controlRole,
                subrole: turn.context.controlSubrole,
                value: turn.observedText
            )
        }
        let exportTurns = deduplicateAdjacent(filteredTurns)

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
