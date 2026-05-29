import Foundation

public enum PlaceholderPolicy {
    public static func isPlaceholder(
        _ text: String,
        context: CaptureContext,
        rules: [PlaceholderRule] = PlaceholderRuleStore.defaultRules
    ) -> Bool {
        let normalized = normalizedText(text)
        guard !normalized.isEmpty else {
            return false
        }

        return rules.contains { rule in
            rule.bundleID == context.bundleID && normalizedText(rule.text) == normalized
        }
    }

    public static func normalizedText(_ text: String) -> String {
        TextSanitizer.visibleText(text)
    }
}
