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
    var placeholderRules: [PlaceholderRule]
    var placeholderDraftAppName = ""
    var placeholderDraftBundleID = ""
    var placeholderDraftText = ""
    var placeholderDraftUsesRegex = false
    var globalPlaceholderDraftText = ""
    var globalPlaceholderDraftUsesRegex = false
    var placeholderStatusText = ""
    var manualExportStartDate = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    var manualExportEndDate = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    var exportStatusText = ""
    var exportHour = AppState.loadExportHour() {
        didSet {
            UserDefaults.standard.set(exportHour, forKey: Self.exportHourDefaultsKey)
        }
    }

    let permissionService: AccessibilityPermissionService
    let store: TurnStore
    let exporter: MarkdownExporter

    private let placeholderRuleStore: PlaceholderRuleStore
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
        exporter: MarkdownExporter,
        placeholderRuleStore: PlaceholderRuleStore = PlaceholderRuleStore()
    ) {
        self.permissionService = permissionService
        self.store = store
        self.exporter = exporter
        self.placeholderRuleStore = placeholderRuleStore
        self.placeholderRules = placeholderRuleStore.load()
        self.exporter.placeholderRules = placeholderRules
        self.captureCoordinator = CaptureCoordinator(
            store: store,
            reader: accessibilityClient,
            placeholderRules: placeholderRules
        )
        AppLog.lifecycle.info("AppState initialized")
        logDiagnostics()
        do {
            let closedCount = try store.closeUnclosedTurns()
            AppLog.store.info("Closed unclosed turns count=\(closedCount, privacy: .public)")
        } catch {
            AppLog.store.error("Failed to close unclosed turns error=\(error.localizedDescription, privacy: .public)")
        }
        do {
            let result = try store.compactAppendOnlyTurns()
            AppLog.store.info(
                "Compacted turns scanned=\(result.scannedCount, privacy: .public) deletedInvisible=\(result.deletedInvisibleCount, privacy: .public) deletedAppendOnly=\(result.deletedAppendOnlyCount, privacy: .public)"
            )
        } catch {
            AppLog.store.error("Failed to compact turns error=\(error.localizedDescription, privacy: .public)")
        }
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

    var canAddAppPlaceholderRule: Bool {
        !placeholderDraftBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !placeholderDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canAddGlobalPlaceholderRule: Bool {
        !globalPlaceholderDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func refreshPermissionStatus() {
        hasAccessibilityPermission = permissionService.isTrusted
        statusText = hasAccessibilityPermission ? (isRecording ? "Recording" : "Ready") : "Accessibility permission required"
        AppLog.permission.info("Accessibility permission trusted=\(self.hasAccessibilityPermission, privacy: .public)")
    }

    func requestPermission() {
        AppLog.permission.info("Requesting accessibility permission and opening system settings")
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

    @discardableResult
    func exportNow() -> Bool {
        AppLog.export.info("Export previous day requested")
        do {
            exporter.placeholderRules = placeholderRules
            let outputURL = try exporter.exportPreviousDay()
            statusText = "Exported previous day"
            exportStatusText = "Exported \(outputURL.lastPathComponent)"
            AppLog.export.info("Export previous day succeeded file=\(outputURL.lastPathComponent, privacy: .public) path=\(outputURL.path, privacy: .private)")
            return true
        } catch {
            statusText = "Export failed: \(error.localizedDescription)"
            exportStatusText = "Export failed: \(error.localizedDescription)"
            AppLog.export.error("Export previous day failed error=\(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @discardableResult
    func exportSelectedRange() -> Bool {
        let startDay = Calendar.current.startOfDay(for: manualExportStartDate)
        let endDay = Calendar.current.startOfDay(for: manualExportEndDate)
        AppLog.export.info("Export selected range requested start=\(Self.exportDayFormatter.string(from: startDay), privacy: .public) end=\(Self.exportDayFormatter.string(from: endDay), privacy: .public)")
        guard startDay <= endDay else {
            statusText = "Export failed: start date is after end date"
            exportStatusText = "Start date must be before or equal to end date"
            AppLog.export.error("Export selected range rejected because start is after end")
            return false
        }
        do {
            exporter.placeholderRules = placeholderRules
            let outputURLs = try exporter.export(startDay: startDay, endDay: endDay)
            let fileSummary = Self.fileSummary(outputURLs)
            statusText = "Exported \(outputURLs.count) file\(outputURLs.count == 1 ? "" : "s")"
            exportStatusText = "Exported \(fileSummary)"
            AppLog.export.info("Export selected range succeeded files=\(outputURLs.count, privacy: .public) summary=\(fileSummary, privacy: .public)")
            return true
        } catch {
            statusText = "Export failed: \(error.localizedDescription)"
            exportStatusText = "Export failed: \(error.localizedDescription)"
            AppLog.export.error("Export selected range failed error=\(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func refreshRecentTurns() {
        do {
            recentTurns = try store.fetchRecent(limit: 50)
        } catch {
            recentTurns = []
            AppLog.store.error("Failed to fetch recent turns error=\(error.localizedDescription, privacy: .public)")
        }
    }

    func fillPlaceholderDraftFromSelectedTurn() {
        guard let selectedTurn else {
            return
        }
        placeholderDraftAppName = selectedTurn.context.appName
        placeholderDraftBundleID = selectedTurn.context.bundleID
        placeholderDraftText = selectedTurn.observedText
        placeholderDraftUsesRegex = false
    }

    func addAppPlaceholderRuleFromDraft() {
        let appName = placeholderDraftAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleID = placeholderDraftBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = PlaceholderPolicy.normalizedText(placeholderDraftText)
        let matchType: PlaceholderMatchType = placeholderDraftUsesRegex ? .regex : .exact
        guard !bundleID.isEmpty else {
            placeholderStatusText = "Bundle ID is required for app-specific rules"
            return
        }
        addPlaceholderRule(
            appName: appName.isEmpty ? bundleID : appName,
            bundleID: bundleID,
            text: text,
            matchType: matchType,
            scope: .app
        ) {
            placeholderDraftText = ""
            placeholderDraftUsesRegex = false
        }
    }

    func addGlobalPlaceholderRuleFromDraft() {
        let text = PlaceholderPolicy.normalizedText(globalPlaceholderDraftText)
        let matchType: PlaceholderMatchType = globalPlaceholderDraftUsesRegex ? .regex : .exact
        addPlaceholderRule(
            appName: "All Apps",
            bundleID: "",
            text: text,
            matchType: matchType,
            scope: .global
        ) {
            globalPlaceholderDraftText = ""
            globalPlaceholderDraftUsesRegex = false
        }
    }

    private func addPlaceholderRule(
        appName: String,
        bundleID: String,
        text: String,
        matchType: PlaceholderMatchType,
        scope: PlaceholderRuleScope,
        afterSave: () -> Void
    ) {
        guard !text.isEmpty else {
            placeholderStatusText = "Text is required"
            return
        }
        if matchType == .regex, !PlaceholderPolicy.isValidRegex(text) {
            placeholderStatusText = "Invalid regular expression"
            AppLog.placeholder.error("Skipped invalid placeholder regex scope=\(scope.rawValue, privacy: .public) bundleID=\(bundleID, privacy: .public) patternSummary=\(AppLogMetadata.textSummary(text), privacy: .public)")
            return
        }

        let duplicate = placeholderRules.contains { rule in
            rule.scope == scope &&
                (scope == .global || rule.bundleID == bundleID) &&
                rule.matchType == matchType &&
                PlaceholderPolicy.normalizedText(rule.text) == text
        }
        guard !duplicate else {
            placeholderStatusText = "Rule already exists"
            AppLog.placeholder.info("Skipped duplicate placeholder rule scope=\(scope.rawValue, privacy: .public) bundleID=\(bundleID, privacy: .public)")
            return
        }

        placeholderRules.append(PlaceholderRule(
            appName: appName,
            bundleID: bundleID,
            text: text,
            matchType: matchType,
            scope: scope
        ))
        persistPlaceholderRules()
        afterSave()
        AppLog.placeholder.info("Added placeholder rule scope=\(scope.rawValue, privacy: .public) app=\(appName, privacy: .public) bundleID=\(bundleID, privacy: .public) matchType=\(matchType.rawValue, privacy: .public) textSummary=\(AppLogMetadata.textSummary(text), privacy: .public)")
    }

    func deletePlaceholderRule(_ rule: PlaceholderRule) {
        placeholderRules.removeAll { $0.id == rule.id }
        persistPlaceholderRules()
        AppLog.placeholder.info("Deleted placeholder rule app=\(rule.appName, privacy: .public) bundleID=\(rule.bundleID, privacy: .public)")
    }

    func startCaptureLoop() {
        guard hasAccessibilityPermission, captureTimer == nil else {
            AppLog.capture.info("Start capture ignored trusted=\(self.hasAccessibilityPermission, privacy: .public) timerActive=\((self.captureTimer != nil), privacy: .public)")
            return
        }
        isRecording = true
        statusText = "Recording"
        AppLog.capture.info("Capture loop started interval=0.3")
        captureCoordinator?.startRecording()
        captureCoordinator?.placeholderRules = placeholderRules
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
        AppLog.capture.info("Capture loop stopped reason=\(reason.rawValue, privacy: .public)")
        refreshRecentTurns()
    }

    func shutdown() {
        AppLog.lifecycle.info("AppState shutdown")
        captureTimer?.invalidate()
        exportTimer?.invalidate()
        foregroundMonitor.stop()
        captureCoordinator?.shutdown()
    }

    func startExportScheduler() {
        exportTimer?.invalidate()
        AppLog.export.info("Export scheduler started hour=\(self.exportHour, privacy: .public)")
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
        AppLog.export.info("Scheduled export triggered key=\(key, privacy: .public)")
        exportNow()
    }

    private static let exportHourDefaultsKey = "exportHour"

    private static func loadExportHour() -> Int {
        if UserDefaults.standard.object(forKey: exportHourDefaultsKey) == nil {
            return 2
        }
        return UserDefaults.standard.integer(forKey: exportHourDefaultsKey)
    }

    private static func fileSummary(_ outputURLs: [URL]) -> String {
        guard let first = outputURLs.first else {
            return "0 files"
        }
        guard outputURLs.count > 1, let last = outputURLs.last else {
            return first.lastPathComponent
        }
        return "\(outputURLs.count) files (\(first.lastPathComponent) ... \(last.lastPathComponent))"
    }

    private func persistPlaceholderRules() {
        do {
            try placeholderRuleStore.save(placeholderRules)
            exporter.placeholderRules = placeholderRules
            captureCoordinator?.placeholderRules = placeholderRules
            placeholderStatusText = "Saved"
            AppLog.placeholder.info("Saved placeholder rules count=\(self.placeholderRules.count, privacy: .public)")
        } catch {
            placeholderStatusText = "Save failed: \(error.localizedDescription)"
            AppLog.placeholder.error("Failed to save placeholder rules error=\(error.localizedDescription, privacy: .public)")
        }
    }

    private func handleAppChanged(_ app: ForegroundAppSnapshot?) {
        captureCoordinator?.endActiveTurn(reason: .appChanged)
        currentApp = app
        currentControlFingerprint = nil
        currentCaptureStatus = app.map { "Foreground: \($0.appName)" } ?? "No foreground app"
        if let app {
            AppLog.capture.info("Foreground app changed app=\(app.appName, privacy: .public) bundleID=\(app.bundleID, privacy: .public) pid=\(app.processIdentifier, privacy: .public)")
        } else {
            AppLog.capture.info("Foreground app cleared")
        }
        refreshRecentTurns()
    }

    private func pollFocusedControl() {
        guard let currentApp else {
            currentCaptureStatus = "No foreground app"
            return
        }
        guard let candidate = accessibilityClient.focusedTextCandidate(for: currentApp) else {
            if currentControlFingerprint != nil {
                AppLog.capture.info("Focused text control cleared app=\(currentApp.appName, privacy: .public) bundleID=\(currentApp.bundleID, privacy: .public)")
                captureCoordinator?.endActiveTurn(reason: .focusChanged)
            }
            currentControlFingerprint = nil
            currentCaptureStatus = "No readable focused text control"
            refreshRecentTurns()
            return
        }

        if candidate.context.controlFingerprint != currentControlFingerprint {
            captureCoordinator?.endActiveTurn(reason: .focusChanged)
            currentControlFingerprint = candidate.context.controlFingerprint
            AppLog.capture.info(
                "Focused text control changed app=\(candidate.context.appName, privacy: .public) bundleID=\(candidate.context.bundleID, privacy: .public) window=\(candidate.context.windowTitle, privacy: .private) role=\(candidate.context.controlRole ?? "nil", privacy: .public) fingerprintPrefix=\(AppLogMetadata.prefix(candidate.context.controlFingerprint), privacy: .public)"
            )
            captureCoordinator?.startCandidate(candidate)
        }
        captureCoordinator?.tick()
        currentCaptureStatus = "Reading: \(candidate.context.appName)"
        refreshRecentTurns()
    }

    private func logDiagnostics() {
        let dbURL = AppPaths.databaseURL
        let exportURL = AppPaths.defaultExportDirectory
        let dbSize = (try? FileManager.default.attributesOfItem(atPath: dbURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        AppLog.diagnostics.info(
            "Diagnostics dbPath=\(dbURL.path, privacy: .private) dbSizeBytes=\(dbSize, privacy: .public) exportPath=\(exportURL.path, privacy: .private) placeholderRules=\(self.placeholderRules.count, privacy: .public)"
        )
    }

    private static let exportDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
