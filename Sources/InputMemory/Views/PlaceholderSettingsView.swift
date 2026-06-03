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

                    VStack(alignment: .leading, spacing: 12) {
                        Text("This App")
                            .font(.subheadline.weight(.semibold))

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
                                .lineLimit(3...5)
                        }

                        HStack(alignment: .center, spacing: 12) {
                            Toggle("Regular Expression", isOn: $appState.placeholderDraftUsesRegex)
                                .toggleStyle(.checkbox)

                            Spacer()

                            Button {
                                appState.fillPlaceholderDraftFromSelectedTurn()
                            } label: {
                                Text("Use Selected Turn")
                            }
                            .accessibilityLabel("Use Selected Turn")
                            .help("Use selected turn")
                            .disabled(appState.selectedTurn == nil)
                            .buttonStyle(.bordered)

                            Button {
                                appState.addAppPlaceholderRuleFromDraft()
                            } label: {
                                Text("Add Rule")
                            }
                            .accessibilityLabel("Add app placeholder rule")
                            .help("Add app placeholder rule")
                            .disabled(!appState.canAddAppPlaceholderRule)
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Apps")
                            .font(.subheadline.weight(.semibold))

                        PlaceholderField(title: "Placeholder Text") {
                            TextField("Short global pattern", text: $appState.globalPlaceholderDraftText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                        }

                        HStack(alignment: .center, spacing: 12) {
                            Toggle("Regular Expression", isOn: $appState.globalPlaceholderDraftUsesRegex)
                                .toggleStyle(.checkbox)

                            Spacer()

                            Button {
                                appState.addGlobalPlaceholderRuleFromDraft()
                            } label: {
                                Text("Add Rule")
                            }
                            .accessibilityLabel("Add global placeholder rule")
                            .help("Add global placeholder rule")
                            .disabled(!appState.canAddGlobalPlaceholderRule)
                            .buttonStyle(.borderedProminent)
                        }
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
                Text(rule.scope == .global ? "All apps" : rule.bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if rule.scope == .global {
                    Text("Global")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if rule.matchType == .regex {
                    Text("Regular expression")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(rule.text)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()

            Button(role: .destructive, action: delete) {
                Text("Delete")
            }
            .accessibilityLabel("Delete placeholder")
            .help("Delete placeholder")
        }
    }
}
