import SwiftUI

struct PermissionView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if !appState.hasAccessibilityPermission {
            VStack(alignment: .leading, spacing: 6) {
                Text("Accessibility Required")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)

                Button("Open System Settings") {
                    appState.requestPermission()
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
