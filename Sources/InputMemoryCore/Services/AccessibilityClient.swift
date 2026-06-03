import ApplicationServices
import AppKit
import Foundation

public protocol AccessibilityReading {
    func focusedTextCandidate(for app: ForegroundAppSnapshot) -> FocusedTextCandidate?
    func readText(from candidate: FocusedTextCandidate) -> TextReadResult
}

public struct FocusedTextCandidate {
    public var element: AXUIElement
    public var context: CaptureContext

    public init(element: AXUIElement, context: CaptureContext) {
        self.element = element
        self.context = context
    }
}

public final class AccessibilityClient: AccessibilityReading {
    private var lastCandidateDiagnosticAt: [String: Date] = [:]

    public init() {}

    public func focusedTextCandidate(for app: ForegroundAppSnapshot) -> FocusedTextCandidate? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedResult == .success,
              let focused else {
            logCandidateDiagnostic(
                app: app,
                reason: "focused_attribute_unavailable",
                axResult: String(describing: focusedResult),
                role: nil,
                subrole: nil,
                value: nil
            )
            return nil
        }

        let axElement = unsafeBitCast(focused, to: AXUIElement.self)
        let role = stringAttribute(kAXRoleAttribute, from: axElement)
        let subrole = stringAttribute(kAXSubroleAttribute, from: axElement)
        let value = stringAttribute(kAXValueAttribute, from: axElement)
        let isStandard = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role ?? "")
        let isHeuristic = !isStandard && value != nil
        guard isStandard || isHeuristic else {
            logCandidateDiagnostic(
                app: app,
                reason: "focused_element_not_text_like",
                axResult: "success",
                role: role,
                subrole: subrole,
                value: value
            )
            return nil
        }
        guard !CapturePolicy.shouldSkipCandidate(
            appName: app.appName,
            bundleID: app.bundleID,
            role: role,
            subrole: subrole,
            value: value
        ) else {
            logCandidateDiagnostic(
                app: app,
                reason: "focused_element_skipped_by_policy",
                axResult: "success",
                role: role,
                subrole: subrole,
                value: value
            )
            return nil
        }

        let frame = frameDescription(from: axElement)
        let context = CaptureContext(
            appName: app.appName,
            bundleID: app.bundleID,
            windowTitle: currentWindowTitle(for: app.processIdentifier),
            controlRole: role,
            controlSubrole: subrole,
            controlTitle: stringAttribute(kAXTitleAttribute, from: axElement),
            controlDescription: stringAttribute(kAXDescriptionAttribute, from: axElement),
            controlPathHint: nil,
            controlFrame: frame,
            controlFingerprint: fingerprint(app: app, role: role, frame: frame),
            isHeuristicTextControl: isHeuristic
        )
        return FocusedTextCandidate(element: axElement, context: context)
    }

    public func readText(from candidate: FocusedTextCandidate) -> TextReadResult {
        guard let text = stringAttribute(kAXValueAttribute, from: candidate.element) else {
            return .unreadable
        }
        return text.isEmpty ? .empty : .readable(text)
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func currentWindowTitle(for pid: pid_t) -> String {
        let appElement = AXUIElementCreateApplication(pid)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window else {
            return ""
        }
        return stringAttribute(kAXTitleAttribute, from: unsafeBitCast(window, to: AXUIElement.self)) ?? ""
    }

    private func frameDescription(from element: AXUIElement) -> String? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
        let positionText = pointDescription(from: position)
        let sizeText = sizeDescription(from: size)
        guard positionText != nil || sizeText != nil else {
            return nil
        }
        return "\(positionText ?? "unknown-position")|\(sizeText ?? "unknown-size")"
    }

    private func pointDescription(from value: CFTypeRef?) -> String? {
        guard let value else {
            return nil
        }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgPoint else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            return nil
        }
        return "x:\(Int(point.x)) y:\(Int(point.y))"
    }

    private func sizeDescription(from value: CFTypeRef?) -> String? {
        guard let value else {
            return nil
        }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            return nil
        }
        return "w:\(Int(size.width)) h:\(Int(size.height))"
    }

    private func fingerprint(app: ForegroundAppSnapshot, role: String?, frame: String?) -> String {
        Hashing.sha256([app.bundleID, role ?? "", frame ?? ""].joined(separator: "|"))
    }

    private func logCandidateDiagnostic(
        app: ForegroundAppSnapshot,
        reason: String,
        axResult: String,
        role: String?,
        subrole: String?,
        value: String?
    ) {
        let key = [app.bundleID, reason, role ?? "nil", subrole ?? "nil"].joined(separator: "|")
        let now = Date()
        if let last = lastCandidateDiagnosticAt[key], now.timeIntervalSince(last) < 5 {
            return
        }
        lastCandidateDiagnosticAt[key] = now
        let valueSummary = value.map(AppLogMetadata.textSummary) ?? "nil"
        AppLog.diagnostics.info(
            "Focused candidate rejected app=\(app.appName, privacy: .public) bundleID=\(app.bundleID, privacy: .public) reason=\(reason, privacy: .public) axResult=\(axResult, privacy: .public) role=\(role ?? "nil", privacy: .public) subrole=\(subrole ?? "nil", privacy: .public) valueSummary=\(valueSummary, privacy: .public)"
        )
    }
}
