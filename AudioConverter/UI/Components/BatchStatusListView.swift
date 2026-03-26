import SwiftUI

struct BatchStatusListView: View {
    let snapshots: [BatchStatusSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkspaceSectionHeader(
                eyebrow: "Batch status",
                title: "Review queued, live, and completed items",
                message: snapshots.isEmpty
                    ? "The status rail stays compact until conversion or merge work begins."
                    : "Each row keeps the filename, state, detail, and progress labels visible for quick scanning."
            )

            if snapshots.isEmpty {
                emptyState
            } else {
                summaryRow

                VStack(spacing: 12) {
                    ForEach(snapshots) { snapshot in
                        snapshotRow(snapshot)
                    }
                }
            }
        }
        .workspaceSurface(tone: .standard)
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("No batch activity yet")
                    .font(WorkspaceType.bodyStrong)
                Text("Queued, running, skipped, cancelled, and completed items will appear here once work starts.")
                    .font(WorkspaceType.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .workspaceInsetSurface(tone: .muted)
    }

    private var summaryRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Array(summaryItems.enumerated()), id: \.offset) { entry in
                let item = entry.element
                Text("\(item.label) \(item.count)")
                    .font(WorkspaceType.metric)
                    .foregroundStyle(item.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(item.color.opacity(0.10), in: Capsule())
                    .accessibilityIdentifier("batch-summary-\(item.label.lowercased())")
            }
        }
    }

    private func snapshotRow(_ snapshot: BatchStatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(color(for: snapshot.state))
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.fileName)
                        .font(WorkspaceType.bodyStrong)
                        .accessibilityIdentifier("batch-file-\(snapshot.fileName)")
                    Text(snapshot.state.label.uppercased())
                        .font(WorkspaceType.metric)
                        .foregroundStyle(color(for: snapshot.state))
                        .accessibilityIdentifier("batch-state-\(snapshot.fileName)")
                }

                Spacer(minLength: 0)

                WorkspaceBadge(title: snapshot.state.label, tone: tone(for: snapshot.state))
            }

            if case .running = snapshot.state {
                progressView(for: snapshot)
            }

            Text(snapshot.displayedDetail)
                .font(WorkspaceType.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("batch-detail-\(snapshot.fileName)")
        }
        .workspaceInsetSurface(tone: tone(for: snapshot.state))
    }

    @ViewBuilder
    private func progressView(for snapshot: BatchStatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let value = snapshot.fractionCompleted {
                ProgressView(value: value, total: 1)
                    .tint(color(for: snapshot.state))
                    .accessibilityIdentifier("batch-progress-\(snapshot.fileName)")
            } else {
                ProgressView()
                    .tint(color(for: snapshot.state))
                    .accessibilityIdentifier("batch-progress-\(snapshot.fileName)")
            }

            Text(snapshot.progressPercentText ?? "LIVE")
                .font(WorkspaceType.metric)
                .foregroundStyle(color(for: snapshot.state))
                .accessibilityIdentifier("batch-progress-label-\(snapshot.fileName)")
        }
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
            return .accent
        case .failed:
            return .critical
        case .skipped:
            return .warning
        }
    }

    private func color(for state: ConversionItemState) -> Color {
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
