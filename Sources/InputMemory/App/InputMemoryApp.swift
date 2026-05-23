import SwiftUI

@main
struct InputMemoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("InputMemory", systemImage: "text.cursor") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.menu)

        WindowGroup("InputMemory", id: "viewer") {
            Text("InputMemory")
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
