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
            guard applies(rule, to: context) else {
                return false
            }
            switch rule.matchType {
            case .exact:
                return normalizedText(rule.text) == normalized
            case .regex:
                return regexMatches(pattern: normalizedText(rule.text), text: normalized)
            }
        }
    }

    public static func normalizedText(_ text: String) -> String {
        TextSanitizer.visibleText(text)
    }

    public static func isValidRegex(_ pattern: String) -> Bool {
        (try? NSRegularExpression(pattern: normalizedText(pattern))) != nil
    }

    private static func regexMatches(pattern: String, text: String) -> Bool {
        guard !pattern.isEmpty,
              let expression = try? NSRegularExpression(pattern: pattern) else {
            AppLog.placeholder.error("Invalid placeholder regex ignored patternSummary=\(AppLogMetadata.textSummary(pattern), privacy: .public)")
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: range) else {
            return false
        }
        return match.range.location == range.location && match.range.length == range.length
    }

    private static func applies(_ rule: PlaceholderRule, to context: CaptureContext) -> Bool {
        switch rule.scope {
        case .global:
            return true
        case .app:
            return rule.bundleID == context.bundleID
        }
    }
}
