import SwiftUI

struct StatusBannerView: View {
    let title: String
    let message: String
    let isCritical: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: isCritical ? "waveform.path.badge.minus" : "waveform.path.ecg")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isCritical ? Color.red.opacity(0.95) : Color.accentColor)

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
                .fill(isCritical ? Color.red.opacity(0.10) : Color.accentColor.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isCritical ? Color.red.opacity(0.24) : Color.accentColor.opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
