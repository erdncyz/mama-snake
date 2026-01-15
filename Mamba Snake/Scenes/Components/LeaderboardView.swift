import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct LeaderboardView: View {
    @ObservedObject var gameManager = GameManager.shared
    @StateObject private var supabaseService = SupabaseService.shared

    @State private var topScores: [ScoreEntry] = []
    @State private var userBest: ScoreEntry?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @Binding var isPresented: Bool

    // Local nickname state for input
    @State private var tempNickname: String = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                // Header
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)

                VStack(spacing: 5) {
                    Text("MAMBA SNAKE")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .tracking(2)

                    Text("LEADERBOARD")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .orange, radius: 10)
                }

                if gameManager.nickname.isEmpty {
                    // Nickname Input View
                    nicknameInputView
                } else {
                    // Scores View
                    scoresContentView
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(red: 0.1, green: 0.12, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
                    )
            )
            .padding(20)
        }
        .onAppear {
            if !gameManager.nickname.isEmpty {
                loadScores()
            }
        }
    }

    var nicknameInputView: some View {
        VStack(spacing: 15) {
            Text("Enter your nickname to see the leaderboard")
                .foregroundColor(.gray)
                .font(.subheadline)

            TextField("Nickname", text: $tempNickname)
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
                // Submit current pending score if exists (e.g. from just finished game)
                gameManager.submitScore()
                loadScores()
            }) {
                Text("SAVE & VIEW")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
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
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
                Button("Retry") {
                    loadScores()
                }
            } else {
                // Top 5
                VStack(spacing: 10) {
                    HStack {
                        Text("Top 10 Players")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(topScores.enumerated()), id: \.offset) {
                                index, entry in
                                scoreRow(rank: index + 1, entry: entry)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }

                Divider().background(Color.gray)

                // User Best
                VStack(spacing: 5) {
                    Text("Your Best")
                        .font(.caption)
                        .foregroundColor(.gray)

                    if let best = userBest {
                        scoreRow(rank: nil, entry: best)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    } else {
                        Text("No records yet")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.subheadline)
                    }
                }
                // Share Button
                Button(action: {
                    shareLeaderboard()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("SHARE")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 25)
                    .background(Color.yellow)  // Instagram-like color or brand color
                    .cornerRadius(20)
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
    }

    // Screenshot & Share Logic
    func shareLeaderboard() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first
        else { return }

        // Take screenshot
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { context in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        let activityVC = UIActivityViewController(
            activityItems: [image], applicationActivities: nil)

        // Find top controller to present
        if let rootVC = window.rootViewController {
            // Traverse to the top-most presented view controller
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            topVC.present(activityVC, animated: true, completion: nil)
        }
    }

    func scoreRow(rank: Int?, entry: ScoreEntry) -> some View {
        HStack {
            if let rank = rank {
                Text("#\(rank)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(rank == 1 ? .yellow : .white)
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
                Text("Lvl \(entry.level)")
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

        Task {
            do {
                async let top = supabaseService.fetchTopScores()
                async let user = supabaseService.fetchUserBest(nickname: gameManager.nickname)

                let (fetchedTop, fetchedUser) = try await (top, user)

                await MainActor.run {
                    self.topScores = fetchedTop
                    self.userBest = fetchedUser
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
