import SwiftUI

@main
struct InputMemoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("InputMemory", systemImage: "text.cursor") {
            MenuBarContentView()
                .environment(appState)
                .onAppear {
                    appDelegate.onShutdown = {
                        appState.shutdown()
                    }
                }
        }
        .menuBarExtraStyle(.menu)

        WindowGroup("InputMemory", id: "viewer") {
            ViewerWindowView()
                .environment(appState)
                .frame(minWidth: 800, minHeight: 520)
        }
    }
}
