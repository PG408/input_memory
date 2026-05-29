import SwiftUI

struct CaptureControlView: View {
    @Environment(AppState.self) private var appState

    private var accentColor: Color {
        if appState.isRecording {
            return .green
        }
        return appState.hasAccessibilityPermission ? .blue : .secondary
    }

    private var actionText: String {
        appState.isRecording ? "Pause Recording" : "Resume Recording"
    }

    private var detailText: String {
        appState.isRecording ? "Currently recording inputs" : "Recording is paused"
    }

    var body: some View {
        Button {
            appState.isRecording ? appState.pause() : appState.resume()
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 9, height: 9)

                VStack(alignment: .leading, spacing: 2) {
                    Text(actionText)
                        .foregroundStyle(.primary)

                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accentColor.opacity(appState.hasAccessibilityPermission ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accentColor.opacity(appState.hasAccessibilityPermission ? 0.20 : 0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!appState.hasAccessibilityPermission)
        .opacity(appState.hasAccessibilityPermission ? 1 : 0.72)
        .help(appState.hasAccessibilityPermission ? actionText : "Grant Accessibility permission first")
    }
}
