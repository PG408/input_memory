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
        } detail: {
            TurnDetailView(turn: appState.selectedTurn)
        }
    }
}
