import ApplicationServices
import Foundation
@testable import InputMemoryCore

extension Date {
    static let fixture = Date(timeIntervalSince1970: 1_800_000_000)
}

extension CaptureContext {
    static func fixture() -> CaptureContext {
        CaptureContext(
            appName: "TestApp",
            bundleID: "com.example.TestApp",
            windowTitle: "Test Window",
            controlRole: "AXTextField",
            controlSubrole: nil,
            controlTitle: nil,
            controlDescription: nil,
            controlPathHint: nil,
            controlFrame: nil,
            controlFingerprint: "fixture",
            isHeuristicTextControl: false
        )
    }
}

extension FocusedTextCandidate {
    static func fixture() -> FocusedTextCandidate {
        FocusedTextCandidate(
            element: AXUIElementCreateSystemWide(),
            context: .fixture()
        )
    }
}

extension Turn {
    static func fixture(observedText: String, at date: Date) -> Turn {
        Turn(
            id: nil,
            observedText: observedText,
            observedTextHash: Hashing.sha256(observedText),
            observedTextLength: observedText.count,
            context: .fixture(),
            captureStatus: observedText.isEmpty ? .empty : .readable,
            endedEmpty: observedText.isEmpty,
            everHadNonEmptyText: !observedText.isEmpty,
            startedAt: date,
            lastObservedAt: date,
            endedAt: nil,
            endReason: nil,
            createdAt: date,
            updatedAt: date
        )
    }
}

final class FakeReader: AccessibilityReading {
    private var results: [TextReadResult]

    init(results: [TextReadResult]) {
        self.results = results
    }

    func focusedTextCandidate(for app: ForegroundAppSnapshot) -> FocusedTextCandidate? {
        .fixture()
    }

    func readText(from candidate: FocusedTextCandidate) -> TextReadResult {
        results.isEmpty ? .empty : results.removeFirst()
    }
}
