import XCTest
@testable import InputMemoryCore

final class CapturePolicyTests: XCTestCase {
    func testSkipsSecureTextField() {
        XCTAssertTrue(CapturePolicy.shouldSkipCandidate(
            appName: "loginwindow",
            bundleID: "com.apple.loginwindow",
            role: "AXTextField",
            subrole: "AXSecureTextField",
            value: "secret"
        ))
    }

    func testSkipsLoginwindowEvenWithoutSecureSubrole() {
        XCTAssertTrue(CapturePolicy.shouldSkipCandidate(
            appName: "loginwindow",
            bundleID: "com.apple.loginwindow",
            role: "AXTextField",
            subrole: nil,
            value: "anything"
        ))
    }

    func testAllowsNormalTextArea() {
        XCTAssertFalse(CapturePolicy.shouldSkipCandidate(
            appName: "TextEdit",
            bundleID: "com.apple.TextEdit",
            role: "AXTextArea",
            subrole: nil,
            value: "draft"
        ))
    }
}
