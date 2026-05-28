import Foundation

public enum AppPaths {
    public static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("InputMemory", isDirectory: true)
    }

    public static var databaseURL: URL {
        applicationSupportDirectory.appendingPathComponent("input_memory.sqlite")
    }

    public static var placeholderRulesURL: URL {
        applicationSupportDirectory.appendingPathComponent("placeholders.json")
    }

    public static var defaultExportDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("InputMemory", isDirectory: true)
    }

    public static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
