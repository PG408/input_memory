import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onShutdown: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationWillTerminate(_ notification: Notification) {
        onShutdown?()
    }
}
