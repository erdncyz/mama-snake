import SwiftUI

struct GameOverlayView: View {
    @ObservedObject var gameManager = GameManager.shared
    var onResume: () -> Void
    var onRestart: () -> Void
    var onNextLevel: () -> Void
    var onStart: () -> Void
    var onPauseToggle: () -> Void

    var onContinue: () -> Void

    var body: some View {
        ZStack {
            // HUD (Oyun Dışı Üst Panel)
            if !gameManager.showLanding && !gameManager.isGameOver && !gameManager.isLevelComplete {
                VStack(spacing: 0) {
                    // Modern HUD Design
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
                                    .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.0))  // Bright Gold
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
                                    .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.3))  // Vivid Red
                                    .shadow(color: .red.opacity(0.5), radius: 5)
                                Text("\(gameManager.lives)")
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)

                            // Premium Menu/Pause Button
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

                                    Image(
                                        systemName: gameManager.isPaused
                                            ? "play.fill" : "pause.fill"
                                    )
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)  // Extra padding for notch/status bar
                    .padding(.bottom, 20)
                    .background(
                        ZStack {
                            // Liquid Glass Effect

                            // 0. Base Tint: Lighten the area slightly to mimic clear glass
                            Color.white.opacity(0.1)

                            // 1. Blur Material
                            Rectangle()
                                .fill(.ultraThinMaterial)

                            // 2. Stronger Glossy Gradient (High Shine)
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.5),  // Daha parlak ışık yansıması
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.0),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            // 3. Icy/Glass Border with more pop
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.0),
                                                .white.opacity(0.6),  // Kenar parlaması artırıldı
                                                .white.opacity(0.0),
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 1.5)  // Biraz daha kalın
                            }
                        }
                        .edgesIgnoringSafeArea(.top)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                    Spacer()
                }
            }

            // Landing Page
            if gameManager.showLanding {
                Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)
                VStack(spacing: 30) {
                    Spacer()

                    // Logo - GIF Animation
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
                    }
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding()

                    Spacer()

                    Button(action: onStart) {
                        Text("TAP TO PLAY")
                            .font(.title2)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                            .frame(width: 220, height: 60)
                            .background(Color.green)
                            .cornerRadius(30)
                            .shadow(radius: 10)
                    }
                    .scaleEffect(1.0)  // Could add pulse animation here via state

                    Text("Developed by Erdinç Yılmaz")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 40)
                }
            }

            // Game Over / Level Complete
            if gameManager.isGameOver || gameManager.isLevelComplete {
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
                            .foregroundColor(gameManager.isLevelComplete ? .black : .black)
                            .frame(width: 200, height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                            .padding(.top, 20)
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

            // Paused
            if gameManager.isPaused && !gameManager.showLanding && !gameManager.isGameOver
                && !gameManager.isLevelComplete
            {
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
                }
            }

            // Crash / Ready to Continue
            // State: Not Playing, Not Paused, Not GameOver, Not Landing, Not LevelComplete
            if !gameManager.isPlaying && !gameManager.isPaused && !gameManager.showLanding
                && !gameManager.isGameOver && !gameManager.isLevelComplete
            {
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
                            .background(Color.orange)  // Orange for warning/action
                            .cornerRadius(30)
                            .shadow(radius: 10)
                            .scaleEffect(1.0)
                    }
                }
            }
        }
    }
}
