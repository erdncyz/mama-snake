import SwiftUI

struct GameHUD: View {
    @ObservedObject private var manager = GameManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var compact = false
    var onPause: () -> Void

    private var progress: Double {
        min(max(Double(manager.percentCovered / manager.targetPercent), 0), 1)
    }

    var body: some View {
        VStack(spacing: compact ? 10 : 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Seviye \(manager.level)")
                        .font(.system(size: compact ? 24 : 30, weight: .semibold))
                        .tracking(-0.8)
                    Text("Sıradaki: Seviye \(manager.level + 1)")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 0)
                Label("\(manager.lives)", systemImage: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.95, green: 0.48, blue: 0.51))
                    .accessibilityLabel("\(manager.lives) can")
                Button(action: onPause) {
                    Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(manager.isPaused ? "Devam et" : "Duraklat")
            }
            .lineLimit(1).minimumScaleFactor(0.7)

            HStack(alignment: .firstTextBaseline, spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(manager.score.formatted())
                        .font(.system(size: compact ? 22 : 28, weight: .medium)).monospacedDigit()
                        .contentTransition(.numericText())
                    Text("puan").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                }
                Spacer(minLength: 0)
                Text("Rekor  \(max(manager.highScore, manager.score).formatted())")
                    .font(.system(size: 12, weight: .medium)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
            }
            .lineLimit(1).minimumScaleFactor(0.6)

            VStack(spacing: 8) {
                HStack {
                    Text("Kapatılan alan")
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
                .accessibilityLabel("Bölüm ilerlemesi")
                .accessibilityValue("Yüzde \(Int(manager.percentCovered)), hedef yüzde \(Int(manager.targetPercent))")
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: manager.percentCovered)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, compact ? 12 : 20)
    }
}

struct ArenaFrame: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .stroke(.white.opacity(0.15), lineWidth: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
