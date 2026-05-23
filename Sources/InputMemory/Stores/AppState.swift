import Foundation
import InputMemoryCore
import Observation

@Observable
final class AppState {
    var isRecording = false
    var hasAccessibilityPermission = false
    var recentTurns: [Turn] = []
    var selectedTurnID: Int64?
    var statusText = "Not started"
    var currentCaptureStatus = "Idle"

    var exportHour: Int {
        get {
            if UserDefaults.standard.object(forKey: "exportHour") == nil {
                return 2
            }
            return UserDefaults.standard.integer(forKey: "exportHour")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "exportHour")
        }
    }

    let permissionService: AccessibilityPermissionService
    let store: TurnStore
    let exporter: MarkdownExporter

    private let foregroundMonitor = ForegroundAppMonitor()
    private let accessibilityClient = AccessibilityClient()
    private var captureCoordinator: CaptureCoordinator?
    private var captureTimer: Timer?
    private var exportTimer: Timer?
    private var currentApp: ForegroundAppSnapshot?
    private var currentControlFingerprint: String?
    private var lastExportKey: String?

    init(
        permissionService: AccessibilityPermissionService = AccessibilityPermissionService(),
        store: TurnStore,
        exporter: MarkdownExporter
    ) {
        self.permissionService = permissionService
        self.store = store
        self.exporter = exporter
        self.captureCoordinator = CaptureCoordinator(store: store, reader: accessibilityClient)
        try? store.closeUnclosedTurns()
        refreshPermissionStatus()
        refreshRecentTurns()
        startExportScheduler()
    }

    convenience init() {
        let store = try! TurnStore()
        self.init(
            permissionService: AccessibilityPermissionService(),
            store: store,
            exporter: MarkdownExporter(store: store)
        )
    }

    var selectedTurn: Turn? {
        recentTurns.first { $0.id == selectedTurnID }
    }

    func refreshPermissionStatus() {
        hasAccessibilityPermission = permissionService.isTrusted
        statusText = hasAccessibilityPermission ? (isRecording ? "Recording" : "Ready") : "Accessibility permission required"
    }

    func requestPermission() {
        permissionService.requestPermission()
        permissionService.openSystemSettings()
        refreshPermissionStatus()
    }

    func pause() {
        stopCaptureLoop(reason: .paused)
    }

    func resume() {
        refreshPermissionStatus()
        guard hasAccessibilityPermission else {
            return
        }
        startCaptureLoop()
    }

    func exportNow() {
        do {
            _ = try exporter.exportPreviousDay()
            statusText = "Exported previous day"
        } catch {
            statusText = "Export failed: \(error.localizedDescription)"
        }
    }

    func refreshRecentTurns() {
        recentTurns = (try? store.fetchRecent(limit: 50)) ?? []
    }

    func startCaptureLoop() {
        guard hasAccessibilityPermission, captureTimer == nil else {
            return
        }
        isRecording = true
        statusText = "Recording"
        captureCoordinator?.startRecording()
        foregroundMonitor.onAppChanged = { [weak self] app in
            self?.handleAppChanged(app)
        }
        foregroundMonitor.start()
        captureTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.pollFocusedControl()
        }
    }

    func stopCaptureLoop(reason: EndReason = .paused) {
        captureTimer?.invalidate()
        captureTimer = nil
        foregroundMonitor.stop()
        if reason == .paused {
            captureCoordinator?.pause()
        } else {
            captureCoordinator?.endActiveTurn(reason: reason)
        }
        isRecording = false
        currentApp = nil
        currentControlFingerprint = nil
        currentCaptureStatus = "Paused"
        statusText = "Paused"
        refreshRecentTurns()
    }

    func shutdown() {
        captureTimer?.invalidate()
        exportTimer?.invalidate()
        foregroundMonitor.stop()
        captureCoordinator?.shutdown()
    }

    func startExportScheduler() {
        exportTimer?.invalidate()
        exportTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkScheduledExport()
        }
    }

    private func checkScheduledExport(now: Date = Date()) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        guard components.hour == exportHour, components.minute == 0 else {
            return
        }
        let key = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)-\(exportHour)"
        guard key != lastExportKey else {
            return
        }
        lastExportKey = key
        exportNow()
    }

    private func handleAppChanged(_ app: ForegroundAppSnapshot?) {
        captureCoordinator?.endActiveTurn(reason: .appChanged)
        currentApp = app
        currentControlFingerprint = nil
        currentCaptureStatus = app.map { "Foreground: \($0.appName)" } ?? "No foreground app"
        refreshRecentTurns()
    }

    private func pollFocusedControl() {
        guard let currentApp else {
            currentCaptureStatus = "No foreground app"
            return
        }
        guard let candidate = accessibilityClient.focusedTextCandidate(for: currentApp) else {
            captureCoordinator?.endActiveTurn(reason: .focusChanged)
            currentControlFingerprint = nil
            currentCaptureStatus = "No readable focused text control"
            refreshRecentTurns()
            return
        }

        if candidate.context.controlFingerprint != currentControlFingerprint {
            captureCoordinator?.endActiveTurn(reason: .focusChanged)
            currentControlFingerprint = candidate.context.controlFingerprint
            captureCoordinator?.startCandidate(candidate)
        }
        captureCoordinator?.tick()
        currentCaptureStatus = "Reading: \(candidate.context.appName)"
        refreshRecentTurns()
    }
}
