import InputMemoryCore
import SwiftUI

struct TurnDetailView: View {
    let turn: Turn?

    var body: some View {
        if let turn {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(turn.context.appName)
                            .font(.title2.weight(.semibold))

                        if !turn.context.windowTitle.isEmpty && turn.context.windowTitle != turn.context.appName {
                            Text(turn.context.windowTitle)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    }

                    HStack(spacing: 18) {
                        TurnMetadataItem(label: "Status", value: turn.captureStatus.rawValue)
                        TurnMetadataItem(label: "Started", value: turn.startedAt.formatted(date: .abbreviated, time: .shortened))
                        TurnMetadataItem(label: "Length", value: "\(turn.observedTextLength)")
                    }
                    .padding(.top, 14)

                    Divider()
                        .padding(.vertical, 18)

                    Text(turn.observedText)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: 860, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else {
            VStack(spacing: 8) {
                Text("No Turn Selected")
                    .font(.title3.weight(.semibold))
                Text("Select a record from the sidebar.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct TurnMetadataItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .textSelection(.enabled)
        }
    }
}
