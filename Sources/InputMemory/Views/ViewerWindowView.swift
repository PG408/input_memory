import SwiftUI

struct ViewerWindowView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSettingsPage: SidebarSettingsPage?

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 8) {
                CaptureControlView()
                    .padding(.horizontal, 8)
                    .padding(.top, 10)

                PermissionView()
                    .padding(.horizontal, 8)

                Divider()
                    .padding(.horizontal, 8)
                    .padding(.top, 2)

                Text("Recent Inputs")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

                TurnListView()

                SidebarSettingsView(selection: $selectedSettingsPage)
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
            .onChange(of: appState.selectedTurnID) { _, newValue in
                if newValue != nil {
                    selectedSettingsPage = nil
                }
            }
        } detail: {
            if let selectedSettingsPage {
                SidebarSettingsDetailView(page: selectedSettingsPage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TurnDetailView(turn: appState.selectedTurn)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private enum SidebarSettingsPage: String, CaseIterable, Identifiable {
    case export = "Export"
    case placeholders = "Placeholders"

    var id: String { rawValue }
}

private struct SidebarSettingsView: View {
    @Binding var selection: SidebarSettingsPage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .padding(.bottom, 2)

            Text("Settings")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 2)

            ForEach(SidebarSettingsPage.allCases) { page in
                Button {
                    selection = page
                } label: {
                    HStack {
                        Text(page.rawValue)
                        Spacer()
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(selection == page ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SidebarSettingsDetailView: View {
    let page: SidebarSettingsPage

    var body: some View {
        switch page {
        case .export:
            ExportDetailView()
        case .placeholders:
            PlaceholderDetailView()
        }
    }
}

private struct ExportDetailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export")
                    .font(.title.weight(.semibold))
                Text("Create Markdown files from recorded input history.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Automatic")
                    .font(.headline)

                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily export")
                            .font(.subheadline.weight(.medium))
                        Text("Exports the previous day automatically at the selected hour.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    ExportSettingsView()
                }
                .padding(.vertical, 2)
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("Manual")
                    .font(.headline)

                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected date")
                            .font(.subheadline.weight(.medium))
                        Text("Exports records captured on this calendar day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    DatePicker("", selection: $appState.manualExportDate, displayedComponents: .date)
                        .datePickerStyle(.field)
                        .labelsHidden()

                    Button("Export") {
                        appState.exportSelectedDate()
                    }
                }
                .padding(.vertical, 2)

                if !appState.exportStatusText.isEmpty {
                    Text(appState.exportStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: 640, alignment: .topLeading)
        .padding(.horizontal, 36)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct PlaceholderDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Placeholders")
                .font(.largeTitle.weight(.semibold))
                .padding(.horizontal)
                .padding(.top, 24)

            PlaceholderSettingsView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
