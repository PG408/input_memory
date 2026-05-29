import AppKit
import InputMemoryCore
import SwiftUI

struct TurnListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        List(selection: $appState.selectedTurnID) {
            ForEach(appState.recentTurns) { turn in
                HStack(alignment: .top, spacing: 10) {
                    AppIconView(bundleID: turn.context.bundleID)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(turn.context.appName)
                            .lineLimit(1)
                        Text(turn.observedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(turn.startedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(minHeight: 34)
                .listRowInsets(EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8))
                .tag(turn.id)
            }
        }
        .listStyle(.sidebar)
    }
}

private struct AppIconView: View {
    let bundleID: String

    var body: some View {
        Image(nsImage: AppIconResolver.icon(for: bundleID))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 22, height: 22)
            .cornerRadius(4)
            .accessibilityHidden(true)
    }
}

private enum AppIconResolver {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for bundleID: String) -> NSImage {
        let key = NSString(string: bundleID)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let icon: NSImage
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            icon = NSWorkspace.shared.icon(forFile: appURL.path)
        } else {
            icon = NSImage(named: NSImage.applicationIconName) ?? NSImage()
        }
        cache.setObject(icon, forKey: key)
        return icon
    }
}
