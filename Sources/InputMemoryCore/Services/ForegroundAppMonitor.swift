import AppKit
import Foundation

public struct ForegroundAppSnapshot: Equatable, Sendable {
    public var appName: String
    public var bundleID: String
    public var processIdentifier: pid_t

    public init(appName: String, bundleID: String, processIdentifier: pid_t) {
        self.appName = appName
        self.bundleID = bundleID
        self.processIdentifier = processIdentifier
    }
}

public final class ForegroundAppMonitor {
    public var onAppChanged: ((ForegroundAppSnapshot?) -> Void)?

    public init() {}

    public func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        onAppChanged?(currentAppSnapshot())
    }

    public func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    public func currentAppSnapshot() -> ForegroundAppSnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return ForegroundAppSnapshot(
            appName: app.localizedName ?? "Unknown",
            bundleID: app.bundleIdentifier ?? "unknown",
            processIdentifier: app.processIdentifier
        )
    }

    @objc private func activeApplicationChanged(_ notification: Notification) {
        onAppChanged?(currentAppSnapshot())
    }
}
