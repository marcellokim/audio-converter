import SwiftUI

struct FileSelectionView: View {
    let files: [SelectedAudioFile]
    let action: () -> Void
    let onRemove: (SelectedAudioFile) -> Void
    let onMoveUp: (SelectedAudioFile) -> Void
    let onMoveDown: (SelectedAudioFile) -> Void
    let canBrowseFiles: Bool
    let canRemoveFiles: Bool
    let canReorderFiles: Bool
    let isMergeMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isMergeMode ? "Ordered source files" : "Source files")
                        .font(WorkspaceType.sectionTitle)
                    Text(
                        isMergeMode
                            ? "Move files up or down to control the final playback order in the merged export."
                            : "Original folders stay intact. Converted outputs render beside the source."
                    )
                    .font(WorkspaceType.body)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Select Files", action: action)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canBrowseFiles)
                    .accessibilityIdentifier("select-files")
            }

            Text(helperText)
                .font(WorkspaceType.detail)
                .foregroundStyle(.secondary)

            if files.isEmpty {
                Text("No source files selected yet.")
                    .font(WorkspaceType.bodyStrong)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 108 - WorkspaceChrome.insetPadding * 2, alignment: .leading)
                    .workspaceInsetSurface(tone: .muted)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                        HStack(spacing: 12) {
                            Image(systemName: isMergeMode ? "arrow.up.arrow.down.circle" : "waveform")
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.displayName)
                                    .font(WorkspaceType.bodyStrong)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .accessibilityLabel(file.displayName)
                                    .accessibilityIdentifier("staged-file-name-\(file.displayName)")
                                Text(file.directoryURL.path)
                                    .font(WorkspaceType.detail)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .layoutPriority(1)
                            Spacer(minLength: 8)
                            HStack(spacing: 8) {
                                if isMergeMode {
                                    Button {
                                        onMoveUp(file)
                                    } label: {
                                        Label("Move Up", systemImage: "arrow.up")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(!canReorderFiles || index == 0)
                                    .accessibilityIdentifier("move-staged-file-up-\(file.displayName)")

                                    Button {
                                        onMoveDown(file)
                                    } label: {
                                        Label("Move Down", systemImage: "arrow.down")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(!canReorderFiles || index == files.count - 1)
                                    .accessibilityIdentifier("move-staged-file-down-\(file.displayName)")
                                }
                                if canRemoveFiles {
                                    Button(role: .destructive) {
                                        onRemove(file)
                                    } label: {
                                        Label("Remove", systemImage: "xmark.circle.fill")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityIdentifier("remove-staged-file-\(file.displayName)")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .workspaceInsetSurface(tone: .muted, padding: 14)
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
            return isMergeMode
                ? "Choose two or more source files, then set their final playback order."
                : "Choose one or more source files to stage the next conversion batch."
        }

        return isMergeMode
            ? "\(files.count) file(s) staged in playback order."
            : "\(files.count) file(s) staged. Converted outputs stay beside each original file."
    }
}
