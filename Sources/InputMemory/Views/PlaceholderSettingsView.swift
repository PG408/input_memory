import InputMemoryCore
import SwiftUI

struct PlaceholderSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        GroupBox("Placeholders") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("App Name", text: $appState.placeholderDraftAppName)
                    .textFieldStyle(.roundedBorder)
                TextField("Bundle ID", text: $appState.placeholderDraftBundleID)
                    .textFieldStyle(.roundedBorder)
                TextField("Placeholder Text", text: $appState.placeholderDraftText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)

                HStack {
                    Button {
                        appState.fillPlaceholderDraftFromSelectedTurn()
                    } label: {
                        Label("Use Selected", systemImage: "text.badge.plus")
                    }
                    .disabled(appState.selectedTurn == nil)

                    Button {
                        appState.addPlaceholderRuleFromDraft()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(!appState.canAddPlaceholderRule)

                    Spacer()

                    Button {
                        appState.restoreDefaultPlaceholderRules()
                    } label: {
                        Label("Restore", systemImage: "arrow.counterclockwise")
                    }
                }
                .buttonStyle(.borderless)

                if !appState.placeholderStatusText.isEmpty {
                    Text(appState.placeholderStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(appState.placeholderRules) { rule in
                        HStack(alignment: .top, spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.appName.isEmpty ? rule.bundleID : rule.appName)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text(rule.bundleID)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text(rule.text)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Button {
                                appState.deletePlaceholderRule(rule)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete placeholder")
                        }
                    }
                }
            }
        }
    }
}
