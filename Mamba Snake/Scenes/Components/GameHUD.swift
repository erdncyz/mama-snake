import SwiftUI

struct GameHUD: View {
    @ObservedObject private var manager = GameManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var compact = false
    var onPause: () -> Void
    @State private var visibleAward: CaptureAward?

    private var progress: Double {
        min(max(Double(manager.percentCovered / manager.targetPercent), 0), 1)
    }

    var body: some View {
        VStack(spacing: compact ? 10 : 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("common.level", manager.level))
                        .font(.system(size: compact ? 24 : 30, weight: .semibold))
                        .tracking(-0.8)
                    Text(L10n.string("game.next_level", manager.level + 1))
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 0)
                Label("\(manager.lives)", systemImage: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.95, green: 0.48, blue: 0.51))
                    .accessibilityLabel(L10n.string("game.lives_accessibility", manager.lives))
                Button(action: onPause) {
                    Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    manager.isPaused
                        ? L10n.string("game.resume")
                        : L10n.string("game.pause")
                )
            }
            .lineLimit(1).minimumScaleFactor(0.7)

            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(manager.score.formatted())
                        .font(.system(size: compact ? 22 : 28, weight: .medium)).monospacedDigit()
                        .contentTransition(.numericText())
                    Text(L10n.string("game.points")).font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                }
                Spacer(minLength: 0)
                Text(L10n.string("game.best_score", max(manager.highScore, manager.score).formatted()))
                    .font(.system(size: 12, weight: .medium)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
                    .opacity(visibleAward == nil ? 1 : 0)
                    .accessibilityHidden(visibleAward != nil)
            }
            .overlay(alignment: .trailing) {
                if let visibleAward {
                    CaptureToastBanner(award: visibleAward)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .scale(scale: 0.9).combined(with: .opacity)
                        )
                }
            }
            .lineLimit(1).minimumScaleFactor(0.6)

            VStack(spacing: 8) {
                HStack {
                    Text(L10n.string("game.claimed_area"))
                    Spacer()
                    Text("%\(Int(manager.percentCovered)) / %\(Int(manager.targetPercent))")
                        .monospacedDigit()
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.09))
                        Capsule().fill(Color(red: 0.48, green: 0.77, blue: 0.65))
                            .frame(width: max(0, geometry.size.width * progress))
                    }
                }
                .frame(height: 4)
                .accessibilityLabel(L10n.string("game.progress_accessibility"))
                .accessibilityValue(
                    L10n.string(
                        "game.progress_value",
                        Int(manager.percentCovered),
                        Int(manager.targetPercent)
                    )
                )
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: manager.percentCovered)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: visibleAward?.id)
        .onChange(of: manager.lastCaptureAward) { award in
            visibleAward = award
        }
        .task(id: visibleAward?.id) {
            guard visibleAward != nil else { return }
            try? await Task.sleep(for: .milliseconds(1300))
            guard !Task.isCancelled else { return }
            visibleAward = nil
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, compact ? 12 : 20)
    }
}

