import SwiftUI

struct ViewerWindowView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                PermissionView()
                ExportSettingsView()
                Text(appState.currentCaptureStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TurnListView()
            }
            .padding()
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            VSplitView {
                TurnDetailView(turn: appState.selectedTurn)
                    .frame(minHeight: 180)

                PlaceholderSettingsView()
                    .frame(minHeight: 360)
            }
        }
    }
}
