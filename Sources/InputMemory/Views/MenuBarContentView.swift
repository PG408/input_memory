import SwiftUI

struct MenuBarContentView: View {
    var body: some View {
        Button("Open Viewer") {
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
