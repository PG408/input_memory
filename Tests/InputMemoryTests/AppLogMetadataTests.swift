import XCTest
@testable import InputMemoryCore

final class AppLogMetadataTests: XCTestCase {
    func testTextSummaryDoesNotExposeRawInput() {
        let summary = AppLogMetadata.textSummary("private message")

        XCTAssertTrue(summary.contains("length=15"))
        XCTAssertTrue(summary.contains("hashPrefix="))
        XCTAssertFalse(summary.contains("private message"))
    }

    func testPrefixShortensIdentifiers() {
        XCTAssertEqual(AppLogMetadata.prefix("1234567890abcdef"), "12345678")
        XCTAssertEqual(AppLogMetadata.prefix("abc"), "abc")
    }
}
