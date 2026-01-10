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
            // HUD
            if !gameManager.showLanding && !gameManager.isGameOver && !gameManager.isLevelComplete {
                // ... (Existing HUD)
                VStack {
                    HStack {
                        // Score Pill
                        HStack(spacing: 5) {
                            Text("🏆")
                            Text("\(gameManager.score)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.yellow)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(20)
                        
                        Spacer()
                        
                        // Center Pill (Level & Percent)
                        HStack(spacing: 5) {
                            Text("Lv.\(gameManager.level)")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                            Text("📊")
                            Text(String(format: "%.1f%%", gameManager.percentCovered))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(20)
                        
                        Spacer()
                        
                        // Lives Pill
                        HStack(spacing: 5) {
                            Text("❤️")
                            Text("\(gameManager.lives)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                    .padding(.top, 60) // Safe area / notch
                    .padding(.horizontal)
                    
                    Spacer()
                }
                
                // Pause Button (Top Right Absolute or part of HUD?)
                // Let's put pause button strictly top right
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onPauseToggle) {
                            Image(systemName: gameManager.isPaused ? "play.fill" : "pause.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Material.ultraThinMaterial))
                        }
                        .padding(.top, 110)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }

            // Landing Page
            if gameManager.showLanding {
                Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Logo
                    VStack(spacing: 10) {
                        Image(systemName: "circle.circle.fill") // Placeholder for snake coil
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(.green)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 2)
                            )
                        
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
                    .scaleEffect(1.0) // Could add pulse animation here via state
                    
                    Text("Developed by Erdinç Yılmaz")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 40)
                }
            }

            // Game Over / Level Complete
            if (gameManager.isGameOver || gameManager.isLevelComplete) {
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
            if gameManager.isPaused && !gameManager.showLanding && !gameManager.isGameOver && !gameManager.isLevelComplete {
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
                            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white, lineWidth: 2))
                    }
                }
            }

            
            // Crash / Ready to Continue
            // State: Not Playing, Not Paused, Not GameOver, Not Landing, Not LevelComplete
            if !gameManager.isPlaying && !gameManager.isPaused && !gameManager.showLanding && !gameManager.isGameOver && !gameManager.isLevelComplete {
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
                            .background(Color.orange) // Orange for warning/action
                            .cornerRadius(30)
                            .shadow(radius: 10)
                            .scaleEffect(1.0)
                    }
                }
            }
        }
    }
}
