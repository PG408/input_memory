import InputMemoryCore
import SwiftUI

struct TurnListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        List(selection: $appState.selectedTurnID) {
            ForEach(appState.recentTurns) { turn in
                VStack(alignment: .leading, spacing: 4) {
                    Text(turn.context.appName)
                        .lineLimit(1)
                    Text(turn.observedText)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .tag(turn.id)
            }
        }
        .listStyle(.sidebar)
    }
}
