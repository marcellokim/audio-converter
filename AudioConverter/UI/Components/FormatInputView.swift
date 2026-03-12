import SwiftUI

struct FormatInputView: View {
    @Binding var outputFormat: String
    let formats: [SupportedFormat]
    let isEnabled: Bool

    private var suggestedFormats: String {
        formats.map(\.id).joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Render format")
                .font(.custom("Avenir Next Condensed", size: 24).weight(.semibold))
            Text("Enter a registry-backed extension. Suggestions: \(suggestedFormats)")
                .font(.custom("Menlo", size: 11))
                .foregroundStyle(.secondary)
            TextField("mp3", text: $outputFormat)
                .textFieldStyle(.roundedBorder)
                .font(.custom("Menlo", size: 14))
                .disabled(!isEnabled)
                .accessibilityLabel("Output format")
        }
    }
}
