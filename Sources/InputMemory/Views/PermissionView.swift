import SwiftUI

struct PermissionView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.hasAccessibilityPermission ? "Accessibility: Granted" : "Accessibility: Required")
                .font(.headline)
            if !appState.hasAccessibilityPermission {
                Button("Open System Settings") {
                    appState.requestPermission()
                }
            }
        }
    }
}
