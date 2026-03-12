import SwiftUI

struct BatchStatusListView: View {
    let snapshots: [BatchStatusSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Batch ledger")
                .font(.custom("Avenir Next Condensed", size: 24).weight(.semibold))

            if snapshots.isEmpty {
                Text("Queued, running, skipped, and completed items will appear here.")
                    .font(.custom("Menlo", size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshots) { snapshot in
                    HStack(alignment: .top, spacing: 12) {
                        Capsule()
                            .fill(color(for: snapshot.state))
                            .frame(width: 8, height: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.fileName)
                                .font(.custom("Hoefler Text", size: 20))
                            Text(snapshot.state.label.uppercased())
                                .font(.custom("Menlo", size: 10))
                                .foregroundStyle(color(for: snapshot.state))
                            Text(snapshot.detail)
                                .font(.custom("Menlo", size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func color(for state: ConversionItemState) -> Color {
        switch state {
        case .queued:
            return .secondary
        case .running:
            return .orange
        case .succeeded:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .yellow
        }
    }
}
