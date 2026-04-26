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

    private let maxVisibleFiles = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            Text(selectionStatusMessage)
                .font(WorkspaceType.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if files.isEmpty {
                Spacer(minLength: 0)
                emptyState
                Spacer(minLength: 0)
            } else {
                stagedFileList
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
                Text(sectionMessage)
                    .font(WorkspaceType.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 8) {
                if !files.isEmpty && canRemoveFiles {
                    Button("Clear", action: onClearAll)
                    .buttonStyle(WorkspaceCommandButtonStyle(tone: .muted, isProminent: false))
                    .accessibilityIdentifier("clear-files")
                }

                Button("Select Files", action: action)
                    .buttonStyle(WorkspaceCommandButtonStyle(tone: .accent, isProminent: true))
                    .disabled(!canBrowseFiles)
                    .accessibilityIdentifier("select-files")
            }
        }
    }

    private var emptyState: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: canBrowseFiles ? "plus.square.dashed" : "clock")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(canBrowseFiles ? Color.accentColor : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(canBrowseFiles ? "Quick Start" : "Waiting for startup check")
                    .font(WorkspaceType.bodyStrong)
                Text(emptyStateMessage)
                    .font(WorkspaceType.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .workspaceInsetSurface(tone: canBrowseFiles ? .muted : .warning, padding: 10)
        .accessibilityIdentifier("quick-start-card")
    }

    private var stagedFileList: some View {
        VStack(spacing: 8) {
            ForEach(Array(visibleFiles.enumerated()), id: \.element.id) { index, file in
                HStack(spacing: 10) {
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
                                Label("Remove", systemImage: "xmark.circle.fill")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(WorkspaceIconButtonStyle(tone: .critical))
                            .accessibilityIdentifier("remove-staged-file-\(file.displayName)")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .workspaceInsetSurface(tone: .muted, padding: 8)
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
        isMergeMode ? "Ordered source files" : "Source files"
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
                ? "Choose two or more source files, then set their final playback order."
                : "Choose one or more source files to stage the next conversion batch."
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
