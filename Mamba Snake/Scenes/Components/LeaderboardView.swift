import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct LeaderboardView: View {
    @ObservedObject var gameManager = GameManager.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @AppStorage(ArenaTheme.storageKey) private var menuTheme = ArenaTheme.midnight.rawValue

    private let leaderboardLimit = 10

    @State private var topScores: [ScoreEntry] = []
    @State private var userBest: ScoreEntry?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @Binding var isPresented: Bool

    @State private var tempNickname: String = ""

    var body: some View {
        ZStack {
            ArenaBackground(theme: ArenaTheme.resolved(menuTheme))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header

                    if gameManager.nickname.isEmpty {
                        nicknameInputView
                    } else {
                        scoresContentView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .menuTheme(ArenaTheme.resolved(menuTheme))
        .preferredColorScheme(.dark)
        .onAppear {
            if !gameManager.nickname.isEmpty {
                loadScores()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 18) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(MambaStyle.mint).frame(width: 6, height: 6)
                    Text("MAMBA ARCADE")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(2)
                }
                .foregroundStyle(MambaStyle.mint)

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.07), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.09)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("leaderboard.close"))
            }

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.string("leaderboard.hero"))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .tracking(-1.5)
                        .lineSpacing(-4)
                    Text(L10n.string("leaderboard.subtitle"))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 88, height: 88)
                    .background(Color.orange.opacity(0.11), in: RoundedRectangle(cornerRadius: 26))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.orange.opacity(0.24)))
                    .shadow(color: .orange.opacity(0.12), radius: 18, y: 8)
            }
        }
    }

    private var nicknameInputView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(L10n.string("leaderboard.nickname_title"), systemImage: "person.crop.circle.badge.plus")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(MambaStyle.mint)

            Text(L10n.string("leaderboard.nickname_help"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(L10n.string("overlay.nickname_placeholder"), text: $tempNickname)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.headline, design: .rounded))
                .padding(17)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.10)))
                .onChange(of: tempNickname) { value in
                    tempNickname = String(value.prefix(PlayerNickname.maxLength))
                }

            Button {
                let nickname = PlayerNickname.sanitize(tempNickname)
                guard !nickname.isEmpty else { return }
                gameManager.setNickname(nickname)
                gameManager.submitScore()
                loadScores()
            } label: {
                Label(L10n.string("leaderboard.save_show"), systemImage: "arrow.right")
            }
            .buttonStyle(MambaButtonStyle(primary: true))
            .disabled(PlayerNickname.sanitize(tempNickname).isEmpty)
            .opacity(PlayerNickname.sanitize(tempNickname).isEmpty ? 0.45 : 1)
        }
        .mambaCard()
    }

    private var scoresContentView: some View {
        VStack(spacing: 16) {
            if isLoading {
                VStack(spacing: 14) {
                    ProgressView().tint(MambaStyle.mint).controlSize(.large)
                    Text(L10n.string("leaderboard.loading"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .mambaCard()
            } else if let error = errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 30))
                        .foregroundStyle(.orange)
                    Text(L10n.string("leaderboard.load_failed"))
                        .font(.system(.title3, design: .rounded).bold())
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(L10n.string("leaderboard.retry"), action: loadScores)
                        .buttonStyle(MambaButtonStyle(primary: true))
                }
                .mambaCard()
            } else {
                personalBestCard
                leaderboardCard

                Button(action: shareLeaderboard) {
                    Label(L10n.string("leaderboard.share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(MambaButtonStyle())
            }
        }
    }

    private var personalBestCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MambaStyle.mint)
                .frame(width: 46, height: 46)
                .background(MambaStyle.mint.opacity(0.11), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string("leaderboard.your_best"))
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Text(gameManager.nickname)
                    .font(.system(.headline, design: .rounded).bold())
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let best = userBest {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(best.score.formatted())
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text(L10n.string("common.level_upper", best.level))
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(MambaStyle.mint)
                }
            } else {
                Text(L10n.string("leaderboard.no_score"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(MambaStyle.mint.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(MambaStyle.mint.opacity(0.18)))
    }

    private var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.string("leaderboard.global"))
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(MambaStyle.mint)
                    Text(L10n.string("leaderboard.top_players", leaderboardLimit))
                        .font(.system(.title3, design: .rounded).bold())
                }
                Spacer()
                Image(systemName: "globe.europe.africa.fill")
                    .foregroundStyle(.white.opacity(0.45))
            }

            if topScores.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "trophy")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text(L10n.string("leaderboard.first_record"))
                        .font(.system(.headline, design: .rounded).bold())
                    Text(L10n.string("leaderboard.play_to_rank"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(topScores.enumerated()), id: \.offset) { index, entry in
                        scoreRow(rank: index + 1, entry: entry)
                    }
                }
            }
        }
        .mambaCard()
    }

    private func shareLeaderboard() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first
        else { return }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { context in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        let activityVC = UIActivityViewController(
            activityItems: [image], applicationActivities: nil)

        if let rootVC = window.rootViewController {
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 1, height: 1)
                popover.permittedArrowDirections = []
            }
            topVC.present(activityVC, animated: true, completion: nil)
        }
    }

    private func scoreRow(rank: Int, entry: ScoreEntry) -> some View {
        let isCurrentUser = PlayerNickname.sanitize(entry.nickname)
            .localizedCaseInsensitiveCompare(PlayerNickname.sanitize(gameManager.nickname)) == .orderedSame
        let accent = rankColor(rank)

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accent.opacity(rank <= 3 ? 0.14 : 0.06))
                if rank <= 3 {
                    Image(systemName: rank == 1 ? "crown.fill" : "medal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)
                } else {
                    Text("\(rank)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.nickname)
                        .font(.system(.subheadline, design: .rounded).bold())
                        .lineLimit(1)
                    if isCurrentUser {
                        Text(L10n.string("leaderboard.you"))
                            .font(.system(size: 7, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(MambaStyle.mint, in: Capsule())
                    }
                }
                Text(L10n.string("common.level", entry.level))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.score.formatted())
                .font(.system(size: 17, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rank <= 3 ? accent : .white)
        }
        .padding(10)
        .background(
            isCurrentUser ? MambaStyle.mint.opacity(0.08) : .white.opacity(rank <= 3 ? 0.05 : 0.025),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentUser ? MambaStyle.mint.opacity(0.24) : .white.opacity(0.06))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.string(
                "leaderboard.row_accessibility",
                rank,
                entry.nickname,
                entry.score,
                entry.level
            )
        )
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(red: 0.78, green: 0.84, blue: 0.90)
        case 3: return Color(red: 0.80, green: 0.47, blue: 0.25)
        default: return .white
        }
    }

    private func loadScores() {
        isLoading = true
        errorMessage = nil
        let limit = leaderboardLimit

        Task {
            do {
                async let top = firebaseService.fetchTopScores(limit: limit)
                async let user = firebaseService.fetchUserBest(nickname: gameManager.nickname)

                let (fetchedTop, fetchedUser) = try await (top, user)

                await MainActor.run {
                    self.topScores = fetchedTop
                    self.userBest = fetchedUser
                    self.isLoading = false
                    FirebaseTelemetryService.shared.logLeaderboardViewed()
                }
            } catch {
                await MainActor.run {
                    FirebaseTelemetryService.shared.record(
                        error, operation: "leaderboard_fetch")
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
