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
}
