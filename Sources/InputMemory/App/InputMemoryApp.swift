import SwiftUI

@main
struct InputMemoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("InputMemory", id: "viewer") {
            ViewerWindowView()
                .environment(appState)
                .frame(minWidth: 800, minHeight: 520)
        }

        MenuBarExtra {
            MenuBarContentView()
                .environment(appState)
                .onAppear {
                    appDelegate.onShutdown = {
                        appState.shutdown()
                    }
                }
        } label: {
            Label {
                Text("InputMemory")
            } icon: {
                Image(nsImage: StatusBarIcon.image)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
