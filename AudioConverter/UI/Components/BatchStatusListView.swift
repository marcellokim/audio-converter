import SwiftUI

struct BatchStatusListView: View {
    let snapshots: [BatchStatusSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Batch status")
                .font(.custom("Avenir Next Condensed", size: 24).weight(.semibold))

            if snapshots.isEmpty {
                Text("Queued, running, skipped, cancelled, and completed items will appear here once conversion wiring is active.")
                    .font(.custom("Menlo", size: 11))
                    .foregroundStyle(.secondary)
            } else {
                summaryRow

                ForEach(snapshots) { snapshot in
                    HStack(alignment: .top, spacing: 12) {
                        Capsule()
                            .fill(color(for: snapshot.state))
                            .frame(width: 8, height: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.fileName)
                                .font(.custom("Hoefler Text", size: 20))
                                .accessibilityIdentifier("batch-file-\(snapshot.fileName)")
                            Text(snapshot.state.label.uppercased())
                                .font(.custom("Menlo", size: 10))
                                .foregroundStyle(color(for: snapshot.state))
                                .accessibilityIdentifier("batch-state-\(snapshot.fileName)")
                            Text(snapshot.detail)
                                .font(.custom("Menlo", size: 11))
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("batch-detail-\(snapshot.fileName)")
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
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

    private var summaryRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(summaryItems.enumerated()), id: \.offset) { entry in
                let item = entry.element
                Text("\(item.label) \(item.count)")
                    .font(.custom("Menlo", size: 10))
                    .foregroundStyle(item.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(item.color.opacity(0.10), in: Capsule())
                    .accessibilityIdentifier("batch-summary-\(item.label.lowercased())")
            }
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
