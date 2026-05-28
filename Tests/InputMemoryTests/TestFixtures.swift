import ApplicationServices
import Foundation
@testable import InputMemoryCore

extension Date {
    static let fixture = Date(timeIntervalSince1970: 1_800_000_000)
}

extension CaptureContext {
    static func fixture(
        appName: String = "TestApp",
        bundleID: String = "com.example.TestApp",
        windowTitle: String = "Test Window",
        controlRole: String? = "AXTextField",
        controlSubrole: String? = nil,
        controlFingerprint: String = "fixture",
        isHeuristicTextControl: Bool = false
    ) -> CaptureContext {
        CaptureContext(
            appName: appName,
            bundleID: bundleID,
            windowTitle: windowTitle,
            controlRole: controlRole,
            controlSubrole: controlSubrole,
            controlTitle: nil,
            controlDescription: nil,
            controlPathHint: nil,
            controlFrame: nil,
            controlFingerprint: controlFingerprint,
            isHeuristicTextControl: isHeuristicTextControl
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
        fixture(observedText: observedText, context: .fixture(), at: date)
    }

    static func fixture(
        observedText: String,
        context: CaptureContext,
        at date: Date
    ) -> Turn {
        Turn(
            id: nil,
            observedText: observedText,
            observedTextHash: Hashing.sha256(observedText),
            observedTextLength: observedText.count,
            context: context,
            captureStatus: observedText.isEmpty ? .empty : .readable,
            endedEmpty: observedText.isEmpty,
            everHadNonEmptyText: !observedText.isEmpty,
            startedAt: date,
            lastObservedAt: date,
            endedAt: date.addingTimeInterval(1),
            endReason: .focusChanged,
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
