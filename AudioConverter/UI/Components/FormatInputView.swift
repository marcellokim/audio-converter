import SwiftUI

struct FormatInputView: View {
    @Binding var outputFormat: String
    let formats: [SupportedFormat]
    let isEnabled: Bool

    private var supportedFormatsSummary: String {
        formats.map(\.id).joined(separator: " · ")
    }

    private var selectedFormatKey: String {
        FormatRegistry.normalizedKey(for: outputFormat)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WorkspaceSectionHeader(
                eyebrow: "Format",
                title: "Output format",
                message: "Type an extension or choose a chip."
            )

            HStack(alignment: .center, spacing: 8) {
                TextField("mp3", text: $outputFormat)
                    .textFieldStyle(.roundedBorder)
                    .font(WorkspaceType.detail)
                    .disabled(!isEnabled)
                    .accessibilityLabel("Output format")

                if !selectedFormatKey.isEmpty {
                    WorkspaceBadge(
                        title: selectedFormatKey.uppercased(),
                        tone: isEnabled ? .success : .muted
                    )
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 56), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(formats) { format in
                    Button {
                        outputFormat = format.id
                    } label: {
                        HStack(spacing: 4) {
                            if isSelected(format) {
                                Image(systemName: "checkmark")
                                    .font(WorkspaceType.metric)
                            }

                            Text(format.id.uppercased())
                                .font(WorkspaceType.metric)
                        }
                        .foregroundStyle(isSelected(format) ? Color.accentColor : .primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
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

            Text(fieldGuidance)
                .font(WorkspaceType.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .workspaceSurface(tone: .standard)
    }

    private var fieldGuidance: String {
        isEnabled ? "Supported formats: \(supportedFormatsSummary)" : "Format changes pause while a conversion or merge is running."
    }

    private func isSelected(_ format: SupportedFormat) -> Bool {
        selectedFormatKey == format.id
    }

    private func chipBackground(for format: SupportedFormat) -> Color {
        isSelected(format)
            ? Color.accentColor.opacity(0.14)
            : Color.primary.opacity(0.05)
    }

    private func chipStroke(for format: SupportedFormat) -> Color {
        isSelected(format)
            ? Color.accentColor.opacity(0.55)
            : Color.primary.opacity(0.10)
    }
}
