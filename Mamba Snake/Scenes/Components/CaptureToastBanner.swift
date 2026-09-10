import SwiftUI

struct CaptureToastBanner: View {
    let award: CaptureAward

    var body: some View {
        HStack(spacing: 8) {
            Text("+\(award.points.formatted())")
                .font(.system(.body, design: .rounded).weight(.bold))
                .monospacedDigit()
            if award.isBigCapture {
                Text(L10n.string("game.big_capture"))
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .tracking(0.8)
            } else if award.hasOvershoot {
                Text(L10n.string("game.overshoot"))
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .tracking(0.8)
            }
        }
        .foregroundStyle(MambaStyle.mint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(MambaStyle.mint.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(MambaStyle.mint.opacity(0.28), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if award.isBigCapture {
            L10n.string("game.big_capture_accessibility", award.points)
        } else if award.hasOvershoot {
            L10n.string("game.overshoot_accessibility", award.points)
        } else {
            L10n.string("game.capture_points_accessibility", award.points)
        }
    }
}
