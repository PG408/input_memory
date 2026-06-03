import Foundation
import OSLog

public enum AppLog {
    private static let subsystem = "local.inputmemory"

    public static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    public static let permission = Logger(subsystem: subsystem, category: "permission")
    public static let capture = Logger(subsystem: subsystem, category: "capture")
    public static let turn = Logger(subsystem: subsystem, category: "turn")
    public static let store = Logger(subsystem: subsystem, category: "store")
    public static let export = Logger(subsystem: subsystem, category: "export")
    public static let placeholder = Logger(subsystem: subsystem, category: "placeholder")
    public static let diagnostics = Logger(subsystem: subsystem, category: "diagnostics")
}

public enum AppLogMetadata {
    public static func textSummary(_ text: String) -> String {
        "length=\(text.count) hashPrefix=\(prefix(Hashing.sha256(text)))"
    }

    public static func prefix(_ value: String, maxLength: Int = 8) -> String {
        String(value.prefix(maxLength))
    }
}
