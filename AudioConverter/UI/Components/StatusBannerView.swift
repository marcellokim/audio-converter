import SwiftUI

struct StatusBannerView: View {
    enum Tone {
        case checking
        case blocked
        case ready
        case active

        var iconName: String {
            switch self {
            case .checking:
                return "waveform.path.ecg"
            case .blocked:
                return "waveform.path.badge.minus"
            case .ready:
                return "checkmark.seal"
            case .active:
                return "arrow.triangle.2.circlepath.circle"
            }
        }

        var label: String {
            switch self {
            case .checking:
                return "Checking"
            case .blocked:
                return "Blocked"
            case .ready:
                return "Ready"
            case .active:
                return "Running"
            }
        }

        var surfaceTone: WorkspaceSurfaceTone {
            switch self {
            case .checking:
                return .muted
            case .blocked:
                return .critical
            case .ready:
                return .accent
            case .active:
                return .accent
            }
        }

        var accentColor: Color {
            switch self {
            case .checking:
                return .secondary
            case .blocked:
                return .red
            case .ready, .active:
                return .accentColor
            }
        }
    }

    let title: String
    let message: String
    let tone: Tone

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: tone.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tone.accentColor)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(WorkspaceType.sectionTitle)

                    WorkspaceBadge(title: tone.label, tone: tone.surfaceTone)
                }

                Text(message)
                    .font(WorkspaceType.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .workspaceSurface(tone: tone.surfaceTone)
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
