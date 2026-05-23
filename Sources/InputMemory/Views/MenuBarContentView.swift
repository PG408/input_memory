import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(appState.statusText)
        Divider()
        Button(appState.isRecording ? "Pause" : "Resume") {
            appState.isRecording ? appState.pause() : appState.resume()
        }
        Button("Open Viewer") {
            openWindow(id: "viewer")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Export Now") {
            appState.exportNow()
        }
        Divider()
        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
