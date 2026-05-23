import SwiftUI

struct ExportSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        Stepper(value: $appState.exportHour, in: 0...23) {
            Text("Daily Export Hour: \(appState.exportHour):00")
        }
    }
}
