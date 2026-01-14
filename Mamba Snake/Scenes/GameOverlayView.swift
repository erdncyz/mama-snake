import SwiftUI

struct GameOverlayView: View {
    @ObservedObject var gameManager = GameManager.shared
    var onResume: () -> Void
    var onRestart: () -> Void
    var onNextLevel: () -> Void
    var onStart: () -> Void
    var onPauseToggle: () -> Void
    var onContinue: () -> Void

    @State private var showLeaderboard = false
    @State private var showNicknamePrompt = false
    @State private var tempNickname = ""
    @State private var isEditingFromMenu = false

    var body: some View {
        ZStack {
            // MARK: - HUD
            if !gameManager.showLanding && !gameManager.isGameOver && !gameManager.isLevelComplete {
                VStack(spacing: 0) {
                    hudContent
                    Spacer()
                }
            }

            // MARK: - Landing Page
            if gameManager.showLanding {
                landingContent
            }

            // MARK: - Game Over / Level Complete
            if gameManager.isGameOver || gameManager.isLevelComplete {
                gameOverContent
            }

            // MARK: - Paused
            if gameManager.isPaused && !gameManager.showLanding && !gameManager.isGameOver
                && !gameManager.isLevelComplete
            {
                pausedContent
            }

            // MARK: - Crash / Continue
            if !gameManager.isPlaying && !gameManager.isPaused && !gameManager.showLanding
                && !gameManager.isGameOver && !gameManager.isLevelComplete
            {
                crashContent
            }

            // MARK: - Nickname Prompt
            if showNicknamePrompt {
                nicknamePromptContent
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView(isPresented: $showLeaderboard)
        }
    }

    // MARK: - Subviews

    var hudContent: some View {
        HStack(alignment: .center) {
            // Left: Stats
            HStack(spacing: 25) {
                // Score Group
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    Text("\(gameManager.score)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.0))
                        .shadow(color: Color.yellow.opacity(0.3), radius: 8, x: 0, y: 0)
                }

                // Separator
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 2, height: 30)
                    .cornerRadius(1)

                // Level Group
                VStack(alignment: .leading, spacing: 2) {
                    Text("LEVEL")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    HStack(spacing: 4) {
                        Text("\(gameManager.level)")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)

                        Text(String(format: "%.0f%%", gameManager.percentCovered))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.leading, 2)
                            .offset(y: 4)
                    }
                }
            }

            Spacer()

            // Right: Lives & Action
            HStack(spacing: 20) {
                // Lives
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.3))
                        .shadow(color: .red.opacity(0.5), radius: 5)
                    Text("\(gameManager.lives)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)

                // Pause Button
                Button(action: onPauseToggle) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.orange,
                                        Color(red: 1.0, green: 0.4, blue: 0.0),
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 4)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )

                        Image(systemName: gameManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .background(
            ZStack {
                // Liquid Glass Effect
                Color.white.opacity(0.1)

                Rectangle()
                    .fill(.ultraThinMaterial)

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.5),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack {
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.0),
                                    .white.opacity(0.6),
                                    .white.opacity(0.0),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1.5)
                }
            }
            .edgesIgnoringSafeArea(.top)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }

    var landingContent: some View {
        ZStack {
            Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)
            VStack(spacing: 30) {
                Spacer()

                // Logo
                VStack(spacing: 10) {
                    GifImageView(gifName: "LaunchScreen")
                        .frame(width: 200, height: 200)
                        .cornerRadius(20)
                        .shadow(color: .green.opacity(0.5), radius: 20, x: 0, y: 0)

                    Text("MAMBA SNAKE")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundColor(.green)
                        .shadow(color: .black, radius: 2, x: 2, y: 2)
                }

                // Instructions
                VStack(alignment: .leading, spacing: 15) {
                    Label("Swipe to Turn", systemImage: "hand.draw.fill")
                    Label("Eat Bugs to Grow", systemImage: "ant.fill")
                    Label("Avoid Walls & Tail", systemImage: "xmark.octagon.fill")
                    Label("Faster & Bigger Every Lvl", systemImage: "bolt.fill")
                    Label("+1 Life Every 10 Lvl", systemImage: "heart.circle.fill")
                }
                .font(.title3)
                .foregroundColor(.white)
                .padding()

                Spacer()

                // Buttons Stack
                VStack(spacing: 15) {
                    Button(action: {
                        if gameManager.nickname.isEmpty {
                            isEditingFromMenu = false
                            showNicknamePrompt = true
                        } else {
                            onStart()
                        }
                    }) {
                        Text("TAP TO PLAY")
                            .font(.title2)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                            .frame(width: 220, height: 60)
                            .background(Color.green)
                            .cornerRadius(30)
                            .shadow(radius: 10)
                    }

                    if !gameManager.nickname.isEmpty {
                        Button(action: {
                            tempNickname = gameManager.nickname
                            isEditingFromMenu = true
                            showNicknamePrompt = true
                        }) {
                            VStack(spacing: 5) {
                                Text("MY PROFILE")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))

                                HStack(spacing: 6) {
                                    Text(gameManager.nickname)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)

                                    Text("EDIT")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                }

                                Text("Best Score: \(gameManager.highScore)")
                                    .font(.subheadline)
                                    .foregroundColor(.yellow)
                            }
                            .frame(maxWidth: 200)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }

                    Button(action: { showLeaderboard = true }) {
                        HStack {
                            Image(systemName: "list.number")
                            Text("LEADERBOARD")
                        }
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                    }
                }
                .padding(.bottom, 20)

                Text("Developed by Erdinç Yılmaz")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }
        }
    }

    var gameOverContent: some View {
        ZStack {
            Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text(gameManager.isLevelComplete ? "LEVEL COMPLETE!" : "GAME OVER")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(gameManager.isLevelComplete ? .green : .red)
                    .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 5)

                VStack(spacing: 5) {
                    Text("SCORE")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(gameManager.score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding()

                VStack(spacing: 5) {
                    Text("LEVEL REACHED")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(gameManager.level)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                }

                Button(action: {
                    if gameManager.isLevelComplete {
                        onNextLevel()
                    } else {
                        onRestart()
                    }
                }) {
                    Text(gameManager.isLevelComplete ? "NEXT LEVEL" : "TRY AGAIN")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(width: 200, height: 50)
                        .background(Color.white)
                        .cornerRadius(25)
                        .padding(.top, 20)
                }

                Button(action: { showLeaderboard = true }) {
                    Text("VIEW LEADERBOARD")
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .padding()
                }
            }
            .padding(40)
            .background(Color(red: 0.1, green: 0.12, blue: 0.18))
            .cornerRadius(30)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.blue.opacity(0.5), lineWidth: 2)
            )
            .shadow(radius: 20)
        }
    }

    var pausedContent: some View {
        ZStack {
            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)

            VStack {
                Text("PAUSED")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 30)

                Button(action: onResume) {
                    Text("RESUME")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 60)
                        .background(Color.green)
                        .cornerRadius(30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30).stroke(Color.white, lineWidth: 2)
                        )
                }

                Button(action: { showLeaderboard = true }) {
                    HStack {
                        Image(systemName: "list.number")
                        Text("LEADERBOARD")
                    }
                    .font(.headline)
                    .foregroundColor(.yellow)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(15)
                }
                .padding(.top, 10)
            }
        }
    }

    var crashContent: some View {
        ZStack {
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("CRASHED!")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(.orange)
                    .shadow(color: .black, radius: 2, x: 2, y: 2)

                Text("Lives Remaining: \(gameManager.lives)")
                    .font(.title3)
                    .foregroundColor(.white)

                Button(action: onContinue) {
                    Text("TAP TO CONTINUE")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 240, height: 60)
                        .background(Color.orange)
                        .cornerRadius(30)
                        .shadow(radius: 10)
                }
            }
        }
    }

    var nicknamePromptContent: some View {
        ZStack {
            Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text(isEditingFromMenu ? "CHANGE NICKNAME" : "ENTER NICKNAME")
                    .font(.headline)
                    .foregroundColor(.yellow)

                TextField("Nickname", text: $tempNickname)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)

                HStack(spacing: 20) {
                    if isEditingFromMenu {
                        Button("Cancel") {
                            showNicknamePrompt = false
                        }
                        .foregroundColor(.gray)
                    }

                    Button(action: {
                        let trimmed = tempNickname.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            gameManager.setNickname(trimmed)
                            showNicknamePrompt = false
                            if !isEditingFromMenu {
                                onStart()
                            }
                        }
                    }) {
                        Text(isEditingFromMenu ? "SAVE" : "PLAY")
                            .fontWeight(.bold)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(30)
            .background(Color(red: 0.15, green: 0.15, blue: 0.2))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(40)
        }
    }
}

#Preview {
    GameOverlayView(
        onResume: {},
        onRestart: {},
        onNextLevel: {},
        onStart: {},
        onPauseToggle: {},
        onContinue: {}
    )
}
