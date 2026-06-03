import AppKit
import InputMemoryCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onShutdown: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        AppLog.lifecycle.info("Application launched version=\(version, privacy: .public) build=\(build, privacy: .public)")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLog.lifecycle.info("Application will terminate")
        onShutdown?()
    }
}
