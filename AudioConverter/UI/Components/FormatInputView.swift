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
        VStack(alignment: .leading, spacing: 10) {
            Text("Output format")
                .font(.custom("Avenir Next Condensed", size: 24).weight(.semibold))
            Text("Enter a registry-backed file extension. Supported values: \(suggestedFormats)")
                .font(.custom("Menlo", size: 11))
                .foregroundStyle(.secondary)
            TextField("mp3", text: $outputFormat)
                .textFieldStyle(.roundedBorder)
                .font(.custom("Menlo", size: 14))
                .disabled(!isEnabled)
                .accessibilityLabel("Output format")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(formats) { format in
                        Button {
                            outputFormat = format.id
                        } label: {
                            Text(format.id.uppercased())
                                .font(.custom("Menlo", size: 11))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
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
                .padding(.vertical, 1)
            }

            if !isEnabled {
                Text("Format changes pause while a conversion batch is running.")
                    .font(.custom("Menlo", size: 11))
                    .foregroundStyle(.secondary)
            }
        }
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
