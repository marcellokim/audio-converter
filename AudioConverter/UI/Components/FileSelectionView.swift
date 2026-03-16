import SwiftUI

struct FileSelectionView: View {
    let files: [SelectedAudioFile]
    let action: () -> Void
    let onRemove: (SelectedAudioFile) -> Void
    let canBrowseFiles: Bool
    let canRemoveFiles: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source files")
                        .font(.custom("Avenir Next Condensed", size: 24).weight(.semibold))
                    Text("Original folders stay intact. Converted outputs render beside the source.")
                        .font(.custom("Menlo", size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Select Files", action: action)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canBrowseFiles)
                    .accessibilityIdentifier("select-files")
            }

            Text(helperText)
                .font(.custom("Menlo", size: 11))
                .foregroundStyle(.secondary)

            if files.isEmpty {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .frame(minHeight: 108)
                    .overlay(alignment: .leading) {
                        Text("No source files selected yet.")
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
                            if canRemoveFiles {
                                Button(role: .destructive) {
                                    onRemove(file)
                                } label: {
                                    Label("Remove", systemImage: "xmark.circle.fill")
                                        .labelStyle(.titleAndIcon)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("remove-staged-file-\(file.displayName)")
                            }
                        }
                        .padding(14)
                        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private var helperText: String {
        if !canBrowseFiles && files.isEmpty {
            return "File browsing unlocks once the bundled ffmpeg startup check succeeds."
        }

        if files.isEmpty {
            return "Choose one or more source files to stage the next conversion batch."
        }

        return "\(files.count) file(s) staged. Converted outputs stay beside each original file."
    }
}
