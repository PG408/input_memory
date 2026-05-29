import SwiftUI

struct ExportSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        HStack(spacing: 8) {
            Text("\(appState.exportHour):00")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)

            Stepper("Daily Export Hour", value: $appState.exportHour, in: 0...23)
                .labelsHidden()
        }
    }
}
