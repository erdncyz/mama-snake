import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct LeaderboardView: View {
    @ObservedObject var gameManager = GameManager.shared
    @StateObject private var firebaseService = FirebaseService.shared

    private let leaderboardLimit = 10

    @State private var topScores: [ScoreEntry] = []
    @State private var userBest: ScoreEntry?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @Binding var isPresented: Bool

    @State private var tempNickname: String = ""

    var body: some View {
        ZStack {
            ArenaBackground(theme: .midnight).ignoresSafeArea()

            ScrollView {
              VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Liderlik tablosunu kapat")
                }
                .padding(.horizontal)

                VStack(spacing: 5) {
                    Text("MAMBA SNAKE")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(MambaStyle.mint)
                        .tracking(2)

                    Text("Liderlik tablosu")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .foregroundColor(MambaStyle.mint)
                }

                if gameManager.nickname.isEmpty {
                    nicknameInputView
                } else {
                    scoresContentView
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(MambaStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.09), lineWidth: 1)
                    )
            )
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if !gameManager.nickname.isEmpty {
                loadScores()
            }
        }
    }

    var nicknameInputView: some View {
        VStack(spacing: 15) {
            Text("Sıralamayı görmek için oyuncu adını gir")
                .foregroundColor(.gray)
                .font(.subheadline)

            TextField("Oyuncu adı", text: $tempNickname)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)
                .font(.headline)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            Button(action: {
                guard !tempNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return
                }
                gameManager.setNickname(tempNickname)
                gameManager.submitScore()
                loadScores()
            }) {
                Text("Kaydet ve göster")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(MambaStyle.mint)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    var scoresContentView: some View {
        VStack(spacing: 15) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if let error = errorMessage {
                Text("Yüklenemedi: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
                Button("Tekrar dene") {
                    loadScores()
                }
            } else {
                VStack(spacing: 10) {
                    HStack {
                        Text("En iyi \(leaderboardLimit) oyuncu")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }

                    if topScores.isEmpty {
                        Text("İlk rekoru sen yaz. Oyna ve sıralamada yerini al.")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 20)
                    }
                    LazyVStack(spacing: 8) {
                        ForEach(Array(topScores.enumerated()), id: \.offset) {
                            index, entry in
                            scoreRow(rank: index + 1, entry: entry)
                        }
                    }
                }

                Divider().background(Color.gray)

                VStack(spacing: 5) {
                    Text("Senin rekorun")
                        .font(.caption)
                        .foregroundColor(.gray)

                    if let best = userBest {
                        scoreRow(rank: nil, entry: best)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    } else {
                        Text("Henüz bir rekor yok")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.subheadline)
                    }
                }

                Button(action: {
                    shareLeaderboard()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Paylaş")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 25)
                    .background(MambaStyle.mint)
                    .cornerRadius(20)
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
    }

    func shareLeaderboard() {
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

    func scoreRow(rank: Int?, entry: ScoreEntry) -> some View {
        HStack {
            if let rank = rank {
                Text("#\(rank)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(rank == 1 ? MambaStyle.mint : .white)
                    .frame(width: 30, alignment: .leading)
            }

            Text(entry.nickname)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(entry.score)")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                Text("Seviye \(entry.level)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }

    func loadScores() {
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
