import Foundation

public enum PlaceholderPolicy {
    public static func isPlaceholder(_ text: String, context: CaptureContext) -> Bool {
        let normalized = normalizedText(text)
        guard !normalized.isEmpty else {
            return false
        }

        switch context.bundleID {
        case "com.openai.codex":
            return normalized == "Ask for follow-up changes"
        case "com.electron.lark":
            return normalized == "沟通时请保持“公开可接受”"
        default:
            return false
        }
    }

    public static func normalizedText(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: #"[\u{200B}-\u{200F}\u{202A}-\u{202E}\u{2060}\u{FEFF}]"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
