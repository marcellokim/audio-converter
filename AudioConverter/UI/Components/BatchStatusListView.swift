import SwiftUI

struct BatchStatusListView: View {
    let snapshots: [BatchStatusSnapshot]

    private let maxVisibleSnapshots = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WorkspaceSectionHeader(
                eyebrow: "Batch status",
                title: "Activity",
                message: snapshots.isEmpty
                    ? "Conversion and merge updates appear here."
                    : "Live rows stay grouped by current state."
            )

            if snapshots.isEmpty {
                emptyState
            } else {
                populatedState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceSurface(tone: .standard)
    }

    private var emptyState: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("Idle")
                    .font(WorkspaceType.bodyStrong)
                Text("Queued, running, skipped, cancelled, and completed files will appear once work starts.")
                    .font(WorkspaceType.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .workspaceInsetSurface(tone: .muted)
    }

    private var populatedState: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryPills

            VStack(spacing: 8) {
                ForEach(visibleSnapshots) { snapshot in
                    snapshotRow(snapshot)
                }

                if hiddenSnapshotCount > 0 {
                    Text("+ \(hiddenSnapshotCount) more activity item(s)")
                        .font(WorkspaceType.metric)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
            }
        }
    }

    private var summaryPills: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(summaryItems.enumerated()), id: \.offset) { entry in
                    summaryPill(entry.element)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Array(summaryItems.enumerated()), id: \.offset) { entry in
                    summaryPill(entry.element)
                }
            }
        }
        .workspaceInsetSurface(tone: .muted, padding: 8)
    }

    private func snapshotRow(_ snapshot: BatchStatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(accentColor(for: snapshot.state))
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.fileName)
                        .font(WorkspaceType.bodyStrong)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("batch-file-\(snapshot.fileName)")
                    Text(snapshot.state.label.uppercased())
                        .font(WorkspaceType.metric)
                        .foregroundStyle(accentColor(for: snapshot.state))
                        .accessibilityIdentifier("batch-state-\(snapshot.fileName)")
                }

                Spacer(minLength: 0)

                WorkspaceBadge(title: badgeTitle(for: snapshot), tone: tone(for: snapshot.state))
            }

            Text(snapshot.displayedDetail)
                .font(WorkspaceType.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("batch-detail-\(snapshot.fileName)")

            if case .running = snapshot.state {
                progressView(for: snapshot)
            }
        }
        .workspaceInsetSurface(tone: tone(for: snapshot.state), padding: 10)
    }

    private func summaryPill(_ item: (label: String, count: Int, color: Color)) -> some View {
        Text("\(item.label) \(item.count)")
            .font(WorkspaceType.metric)
            .foregroundStyle(item.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(item.color.opacity(0.10), in: Capsule())
            .accessibilityIdentifier("batch-summary-\(item.label.lowercased())")
    }

    private var visibleSnapshots: ArraySlice<BatchStatusSnapshot> {
        snapshots.prefix(maxVisibleSnapshots)
    }

    private var hiddenSnapshotCount: Int {
        max(snapshots.count - maxVisibleSnapshots, 0)
    }

    @ViewBuilder
    private func progressView(for snapshot: BatchStatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let value = snapshot.fractionCompleted {
                ProgressView(value: value, total: 1)
                    .tint(accentColor(for: snapshot.state))
                    .accessibilityIdentifier("batch-progress-\(snapshot.fileName)")
            } else {
                ProgressView()
                    .tint(accentColor(for: snapshot.state))
                    .accessibilityIdentifier("batch-progress-\(snapshot.fileName)")
            }

            Text(snapshot.progressPercentText ?? "LIVE")
                .font(WorkspaceType.metric)
                .foregroundStyle(accentColor(for: snapshot.state))
                .accessibilityIdentifier("batch-progress-label-\(snapshot.fileName)")
        }
    }

    private func badgeTitle(for snapshot: BatchStatusSnapshot) -> String {
        if case .running = snapshot.state {
            return snapshot.progressPercentText ?? "Live"
        }

        return snapshot.state.label
    }

    private var summaryItems: [(label: String, count: Int, color: Color)] {
        let queuedCount = snapshots.filter {
            if case .queued = $0.state {
                return true
            }
            return false
        }.count
        let runningCount = snapshots.filter {
            if case .running = $0.state {
                return true
            }
            return false
        }.count
        let cancelledCount = snapshots.filter {
            if case .cancelled = $0.state {
                return true
            }
            return false
        }.count
        let succeededCount = snapshots.filter {
            if case .succeeded = $0.state {
                return true
            }
            return false
        }.count
        let skippedCount = snapshots.filter {
            if case .skipped = $0.state {
                return true
            }
            return false
        }.count
        let failedCount = snapshots.filter {
            if case .failed = $0.state {
                return true
            }
            return false
        }.count

        return [
            ("Queued", queuedCount, .secondary),
            ("Running", runningCount, .orange),
            ("Cancelled", cancelledCount, .purple),
            ("Complete", succeededCount, .green),
            ("Skipped", skippedCount, .yellow),
            ("Failed", failedCount, .red)
        ].filter { $0.count > 0 }
    }

    private func tone(for state: ConversionItemState) -> WorkspaceSurfaceTone {
        switch state {
        case .queued:
            return .muted
        case .running:
            return .accent
        case .cancelled:
            return .warning
        case .succeeded:
            return .success
        case .failed:
            return .critical
        case .skipped:
            return .warning
        }
    }

    private func accentColor(for state: ConversionItemState) -> Color {
        switch state {
        case .queued:
            return .secondary
        case .running:
            return .orange
        case .cancelled:
            return .purple
        case .succeeded:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .yellow
        }
    }
}
