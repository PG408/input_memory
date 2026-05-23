import AppKit
import ApplicationServices

public final class AccessibilityPermissionService {
    public init() {}

    public var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
