import Foundation

public enum TextSanitizer {
    public static func visibleText(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: #"[\u{200B}-\u{200F}\u{202A}-\u{202E}\u{2060}\u{FEFF}]"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func isMeaningful(_ text: String) -> Bool {
        !visibleText(text).isEmpty
    }
}
