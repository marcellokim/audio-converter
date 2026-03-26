import SwiftUI

struct FormatInputView: View {
    @Binding var outputFormat: String
    let formats: [SupportedFormat]
    let isEnabled: Bool

    private var suggestedFormats: String {
        formats.map(\.id).joined(separator: " · ")
    }

    private var normalizedSelection: String {
        FormatRegistry.normalizedKey(for: outputFormat)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkspaceSectionHeader(
                eyebrow: "Format",
                title: "Choose the output format",
                message: "Use the registry-backed extension field or tap a quick chip. Invalid-format feedback still stays in the export panel."
            )

            HStack(spacing: 8) {
                WorkspaceBadge(title: isEnabled ? "Editable" : "Locked", tone: isEnabled ? .accent : .muted)

                if !normalizedSelection.isEmpty {
                    WorkspaceBadge(title: normalizedSelection.uppercased(), tone: .muted)
                }
            }

            TextField("mp3", text: $outputFormat)
                .textFieldStyle(.roundedBorder)
                .font(WorkspaceType.detail)
                .disabled(!isEnabled)
                .accessibilityLabel("Output format")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 56), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(formats) { format in
                    Button {
                        outputFormat = format.id
                    } label: {
                        Text(format.id.uppercased())
                            .font(WorkspaceType.metric)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(chipBackground(for: format), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(chipStroke(for: format), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEnabled)
                    .accessibilityLabel("Choose \(format.displayName) output")
                }
            }

            Text(isEnabled ? "Supported formats: \(suggestedFormats)" : "Format changes pause while a conversion or merge is running.")
                .font(WorkspaceType.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .workspaceSurface(tone: .standard)
    }

    private func chipBackground(for format: SupportedFormat) -> Color {
        normalizedSelection == format.id
            ? Color.accentColor.opacity(0.14)
            : Color.primary.opacity(0.05)
    }

    private func chipStroke(for format: SupportedFormat) -> Color {
        normalizedSelection == format.id
            ? Color.accentColor.opacity(0.55)
            : Color.primary.opacity(0.10)
    }
}
