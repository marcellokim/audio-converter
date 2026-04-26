import SwiftUI

struct FileSelectionView: View {
    let files: [SelectedAudioFile]
    let action: () -> Void
    let onRemove: (SelectedAudioFile) -> Void
    let onClearAll: () -> Void
    let onMoveUp: (SelectedAudioFile) -> Void
    let onMoveDown: (SelectedAudioFile) -> Void
    let canBrowseFiles: Bool
    let canRemoveFiles: Bool
    let canReorderFiles: Bool
    let isMergeMode: Bool

    private let maxVisibleFiles = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if files.isEmpty {
                emptyState
                Spacer(minLength: 0)
            } else {
                stagedFileList
                Spacer(minLength: 0)
                bottomControls
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceSurface(tone: .standard, padding: 12)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sectionTitle)
                    .font(WorkspaceType.sectionTitle)
                Text(selectionStatusMessage)
                    .font(WorkspaceType.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)

            Spacer()

            HStack(spacing: 8) {
                if !files.isEmpty {
                    Button("Add", action: action)
                        .buttonStyle(WorkspaceCommandButtonStyle(tone: .accent, isProminent: true))
                        .disabled(!canBrowseFiles)
                        .accessibilityIdentifier("select-files")
                }

                Button {
                } label: {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(WorkspaceIconButtonStyle(tone: .muted))
                .disabled(true)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: canBrowseFiles ? "doc.badge.plus" : "clock")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(canBrowseFiles ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(canBrowseFiles ? "Drop audio files here" : "Waiting for startup check")
                    .font(WorkspaceType.bodyStrong)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(emptyStateMessage)
                    .font(WorkspaceType.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }

            Button("Add Files...", action: action)
                .buttonStyle(WorkspaceCommandButtonStyle(tone: .accent, isProminent: false))
                .disabled(!canBrowseFiles)
                .accessibilityIdentifier("select-files")
        }
        .frame(maxWidth: .infinity, minHeight: 184, alignment: .center)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(canBrowseFiles ? 0.045 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    canBrowseFiles ? Color.accentColor.opacity(0.42) : Color.orange.opacity(0.26),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                )
        )
        .accessibilityIdentifier("quick-start-card")
    }

    private var stagedFileList: some View {
        VStack(spacing: 8) {
            ForEach(Array(visibleFiles.enumerated()), id: \.element.id) { index, file in
                HStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

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
                            .buttonStyle(WorkspaceIconButtonStyle(tone: .muted))
                            .disabled(!canReorderFiles || index == 0)
                            .accessibilityIdentifier("move-staged-file-up-\(file.displayName)")

                            Button {
                                onMoveDown(file)
                            } label: {
                                Label("Move Down", systemImage: "arrow.down")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(WorkspaceIconButtonStyle(tone: .muted))
                            .disabled(!canReorderFiles || isLastFile(file))
                            .accessibilityIdentifier("move-staged-file-down-\(file.displayName)")
                        }

                        if canRemoveFiles {
                            Button(role: .destructive) {
                                onRemove(file)
                            } label: {
                                Label("Remove", systemImage: "xmark")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(WorkspaceIconButtonStyle(tone: .critical))
                            .accessibilityIdentifier("remove-staged-file-\(file.displayName)")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .workspaceInsetSurface(tone: .muted, padding: 7)
            }

            if hiddenFileCount > 0 {
                Text("+ \(hiddenFileCount) more staged file(s)")
                    .font(WorkspaceType.metric)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 8) {
            if canRemoveFiles {
                Button("Clear All", action: onClearAll)
                    .buttonStyle(WorkspaceCommandButtonStyle(tone: .muted, isProminent: false))
                    .accessibilityIdentifier("clear-files")
            }

            Spacer(minLength: 0)

            if isMergeMode {
                Image(systemName: "arrow.up.arrow.down")
                    .font(WorkspaceType.metric)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "folder")
                    .font(WorkspaceType.metric)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var visibleFiles: ArraySlice<SelectedAudioFile> {
        files.prefix(maxVisibleFiles)
    }

    private var hiddenFileCount: Int {
        max(files.count - maxVisibleFiles, 0)
    }

    private func isLastFile(_ file: SelectedAudioFile) -> Bool {
        files.last?.id == file.id
    }

    private var sectionTitle: String {
        isMergeMode ? "Source Deck" : "Source Deck"
    }

    private var sectionMessage: String {
        isMergeMode
            ? "Move files up or down to control the final playback order in the merged export."
            : "Original folders stay intact. Converted outputs render beside the source."
    }

    private var selectionStatusMessage: String {
        if !canBrowseFiles && files.isEmpty {
            return "File browsing unlocks once the bundled ffmpeg startup check succeeds."
        }

        if files.isEmpty {
            return isMergeMode
                ? "Add at least two files."
                : "Add files to build the queue."
        }

        return isMergeMode
            ? "\(files.count) file(s) staged in playback order."
            : "\(files.count) file(s) staged. Converted outputs stay beside each original file."
    }

    private var emptyStateMessage: String {
        if !canBrowseFiles {
            return "File selection unlocks after the bundled ffmpeg check succeeds."
        }

        return isMergeMode
            ? "Select at least two files, order them, then choose a destination."
            : "Select one or more files to prepare the conversion queue."
    }
}
