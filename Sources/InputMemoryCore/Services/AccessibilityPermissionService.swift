import AppKit
import ApplicationServices

public final class AccessibilityPermissionService {
    public init() {}

    public var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func requestPermission() {
        AppLog.permission.info("AX permission prompt requested")
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            AppLog.permission.info("Opening Accessibility system settings")
            NSWorkspace.shared.open(url)
        }
    }
}
