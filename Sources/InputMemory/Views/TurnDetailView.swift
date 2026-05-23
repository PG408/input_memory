import InputMemoryCore
import SwiftUI

struct TurnDetailView: View {
    let turn: Turn?

    var body: some View {
        if let turn {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(turn.context.windowTitle.isEmpty ? turn.context.appName : turn.context.windowTitle)
                        .font(.title2)
                    Text("Status: \(turn.captureStatus.rawValue)")
                        .foregroundStyle(.secondary)
                    Text(turn.observedText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
        } else {
            ContentUnavailableView("No Turn Selected", systemImage: "text.cursor")
        }
    }
}
