import InputMemoryCore
import SwiftUI

struct PlaceholderSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Placeholder")
                        .font(.headline)

                    PlaceholderField(title: "App Name") {
                        TextField("Codex", text: $appState.placeholderDraftAppName)
                            .textFieldStyle(.roundedBorder)
                    }

                    PlaceholderField(title: "Bundle ID") {
                        TextField("com.openai.codex", text: $appState.placeholderDraftBundleID)
                            .textFieldStyle(.roundedBorder)
                    }

                    PlaceholderField(title: "Placeholder Text") {
                        TextField("Ask for follow-up changes", text: $appState.placeholderDraftText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button {
                                appState.fillPlaceholderDraftFromSelectedTurn()
                            } label: {
                                Label("Use Selected Turn", systemImage: "text.badge.plus")
                            }
                            .labelStyle(.titleAndIcon)
                            .accessibilityLabel("Use Selected Turn")
                            .help("Use selected turn")
                            .disabled(appState.selectedTurn == nil)

                            Button {
                                appState.addPlaceholderRuleFromDraft()
                            } label: {
                                Label("Add Rule", systemImage: "plus")
                            }
                            .labelStyle(.titleAndIcon)
                            .accessibilityLabel("Add Rule")
                            .help("Add placeholder rule")
                            .disabled(!appState.canAddPlaceholderRule)

                            Spacer()
                        }

                        Button {
                            appState.restoreDefaultPlaceholderRules()
                        } label: {
                            Label("Restore Defaults", systemImage: "arrow.counterclockwise")
                        }
                        .labelStyle(.titleAndIcon)
                        .accessibilityLabel("Restore Defaults")
                        .help("Restore default placeholders")
                    }

                    if !appState.placeholderStatusText.isEmpty {
                        Text(appState.placeholderStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Configured Placeholders")
                        .font(.headline)

                    ForEach(appState.placeholderRules) { rule in
                        PlaceholderRuleRow(rule: rule) {
                            appState.deletePlaceholderRule(rule)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

private struct PlaceholderField<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

private struct PlaceholderRuleRow: View {
    let rule: PlaceholderRule
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.appName.isEmpty ? rule.bundleID : rule.appName)
                    .font(.headline)
                Text(rule.bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(rule.text)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()

            Button(role: .destructive, action: delete) {
                Label("Delete", systemImage: "trash")
            }
            .labelStyle(.titleAndIcon)
            .accessibilityLabel("Delete placeholder")
            .help("Delete placeholder")
        }
    }
}
