import XCTest
@testable import InputMemoryCore

final class MarkdownExporterTests: XCTestCase {
    func testExportsPreviousDayGroupedByContextWithTextFence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = try TurnStore(path: directory.appendingPathComponent("test.sqlite").path)
        let targetDay = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 22))!
        var turn = Turn.fixture(observedText: "# hello\nbody", at: targetDay.addingTimeInterval(3600))
        turn.id = try store.insert(turn)

        let exporter = MarkdownExporter(store: store, exportDirectory: directory)
        let outputURL = try exporter.exportPreviousDay(triggeredAt: targetDay.addingTimeInterval(86_400))

        let markdown = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertTrue(markdown.contains("# InputMemory Export: 2026-05-22"))
        XCTAssertTrue(markdown.contains("## TestApp | Test Window"))
        XCTAssertTrue(markdown.contains("```text\n# hello\nbody\n```"))
    }

    func testExportSkipsEmptyAndSensitiveTurns() throws {
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 27))!
        let safe = Turn.fixture(
            observedText: "real input",
            context: .fixture(),
            at: day.addingTimeInterval(60)
        )
        let empty = Turn.fixture(
            observedText: "",
            context: .fixture(controlFingerprint: "empty"),
            at: day.addingTimeInterval(120)
        )
        let secure = Turn.fixture(
            observedText: "do-not-export",
            context: .fixture(
                appName: "loginwindow",
                bundleID: "com.apple.loginwindow",
                controlRole: "AXTextField",
                controlSubrole: "AXSecureTextField",
                controlFingerprint: "secure"
            ),
            at: day.addingTimeInterval(180)
        )

        let exporter = MarkdownExporter(store: try TurnStore(path: temporaryDatabasePath()))
        let markdown = exporter.render(day: day, generatedAt: day, turns: [safe, empty, secure])

        XCTAssertTrue(markdown.contains("- Turn Count: 1"))
        XCTAssertTrue(markdown.contains("real input"))
        XCTAssertFalse(markdown.contains("do-not-export"))
        XCTAssertFalse(markdown.contains("- Text Length: 0"))
    }

    func testExportSkipsPlaceholderTurns() throws {
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 27))!
        let placeholder = Turn.fixture(
            observedText: "Ask for follow-up changes",
            context: .fixture(
                appName: "Codex",
                bundleID: "com.openai.codex",
                controlFingerprint: "codex"
            ),
            at: day.addingTimeInterval(60)
        )
        let real = Turn.fixture(
            observedText: "real codex input",
            context: .fixture(
                appName: "Codex",
                bundleID: "com.openai.codex",
                controlFingerprint: "codex"
            ),
            at: day.addingTimeInterval(120)
        )

        let exporter = MarkdownExporter(store: try TurnStore(path: temporaryDatabasePath()))
        let markdown = exporter.render(day: day, generatedAt: day, turns: [placeholder, real])

        XCTAssertTrue(markdown.contains("- Turn Count: 1"))
        XCTAssertTrue(markdown.contains("real codex input"))
        XCTAssertFalse(markdown.contains("Ask for follow-up changes"))
    }

    func testExportCollapsesAdjacentIdenticalTurnsInSameControl() throws {
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 27))!
        let context = CaptureContext.fixture(controlFingerprint: "same-control")
        let first = Turn.fixture(observedText: "same text", context: context, at: day.addingTimeInterval(60))
        let second = Turn.fixture(observedText: "same text", context: context, at: day.addingTimeInterval(120))
        let changed = Turn.fixture(observedText: "changed text", context: context, at: day.addingTimeInterval(180))

        let exporter = MarkdownExporter(store: try TurnStore(path: temporaryDatabasePath()))
        let markdown = exporter.render(day: day, generatedAt: day, turns: [first, second, changed])

        XCTAssertTrue(markdown.contains("- Turn Count: 2"))
        XCTAssertEqual(markdown.components(separatedBy: "same text").count - 1, 1)
        XCTAssertTrue(markdown.contains("changed text"))
    }

    func testExportNormalizesDynamicBrowserWindowTitles() throws {
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 27))!
        let first = Turn.fixture(
            observedText: "draft one",
            context: .fixture(
                appName: "Microsoft Edge",
                bundleID: "com.microsoft.edgemac",
                windowTitle: "广告策略 - 飞书云文档 - 内存使用量高 - 1.2 GB - Microsoft Edge",
                controlFingerprint: "a"
            ),
            at: day.addingTimeInterval(60)
        )
        let second = Turn.fixture(
            observedText: "draft two",
            context: .fixture(
                appName: "Microsoft Edge",
                bundleID: "com.microsoft.edgemac",
                windowTitle: "广告策略 - 飞书云文档 - 睡眠 - Microsoft Edge",
                controlFingerprint: "b"
            ),
            at: day.addingTimeInterval(120)
        )

        let exporter = MarkdownExporter(store: try TurnStore(path: temporaryDatabasePath()))
        let markdown = exporter.render(day: day, generatedAt: day, turns: [first, second])

        XCTAssertEqual(
            markdown.components(separatedBy: "## Microsoft Edge | 广告策略 - 飞书云文档 - Microsoft Edge").count - 1,
            1
        )
        XCTAssertFalse(markdown.contains("内存使用量高"))
        XCTAssertFalse(markdown.contains("睡眠 -"))
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
            .path
    }
}
