import SwiftUI

struct FileSelectionView: View {
    let files: [SelectedAudioFile]
    let action: () -> Void
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source files")
                        .font(.custom("Avenir Next Condensed", size: 24).weight(.semibold))
                    Text("Original folders stay intact. Outputs render beside the source.")
                        .font(.custom("Menlo", size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Select Files", action: action)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isEnabled)
            }

            if files.isEmpty {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .frame(minHeight: 108)
                    .overlay(alignment: .leading) {
                        Text("No stems loaded yet.")
                            .font(.custom("Hoefler Text", size: 22))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }
            } else {
                VStack(spacing: 10) {
                    ForEach(files) { file in
                        HStack(spacing: 12) {
                            Image(systemName: "waveform")
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.displayName)
                                    .font(.custom("Hoefler Text", size: 19))
                                Text(file.directoryURL.path)
                                    .font(.custom("Menlo", size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }
}
