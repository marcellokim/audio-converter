import SwiftUI

struct StatusBannerView: View {
    enum Tone {
        case checking
        case ready
        case active
        case blocked
    }

    let title: String
    let message: String
    let tone: Tone

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(symbolColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Avenir Next Condensed", size: 20).weight(.semibold))
                Text(message)
                    .font(.custom("Menlo", size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var symbolName: String {
        switch tone {
        case .checking:
            return "waveform.path.ecg"
        case .ready:
            return "checkmark.circle.fill"
        case .active:
            return "bolt.circle.fill"
        case .blocked:
            return "waveform.path.badge.minus"
        }
    }

    private var symbolColor: Color {
        switch tone {
        case .checking:
            return Color.accentColor
        case .ready:
            return .green.opacity(0.95)
        case .active:
            return .orange.opacity(0.95)
        case .blocked:
            return .red.opacity(0.95)
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .checking:
            return Color.accentColor.opacity(0.09)
        case .ready:
            return Color.green.opacity(0.10)
        case .active:
            return Color.orange.opacity(0.11)
        case .blocked:
            return Color.red.opacity(0.10)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .checking:
            return Color.accentColor.opacity(0.20)
        case .ready:
            return Color.green.opacity(0.24)
        case .active:
            return Color.orange.opacity(0.24)
        case .blocked:
            return Color.red.opacity(0.24)
        }
    }
}
