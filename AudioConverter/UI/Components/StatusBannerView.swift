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
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(WorkspaceType.bodyStrong)
                    .lineLimit(1)
                Text(message)
                    .font(WorkspaceType.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .workspaceSurface(tone: surfaceTone, padding: 10)
        .accessibilityElement(children: .combine)
    }

    private var surfaceTone: WorkspaceSurfaceTone {
        switch tone {
        case .checking:
            return .accent
        case .ready:
            return .success
        case .active:
            return .warning
        case .blocked:
            return .critical
        }
    }

    private var iconName: String {
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

    private var iconColor: Color {
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
}
