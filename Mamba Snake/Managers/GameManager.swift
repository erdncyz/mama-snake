import Combine
import Foundation
import SpriteKit
import SwiftUI

class GameManager: ObservableObject {
    static let shared = GameManager()

    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var percentCovered: Float = 0.0
    @Published var level: Int = 1
    @Published var nickname: String = UserDefaults.standard.string(forKey: "UserNickname") ?? ""
    @Published var highScore: Int = UserDefaults.standard.integer(forKey: "HighScore") {
        didSet {
            UserDefaults.standard.set(highScore, forKey: "HighScore")
        }
    }

    private init() {
        if !nickname.isEmpty {
            Task {
                await fetchUserHighScore()
            }
        }
    }

    @Published var isPlaying: Bool = false
    @Published var isPaused: Bool = false
    @Published var isGameOver: Bool = false
    @Published var isLevelComplete: Bool = false
    @Published var showLanding: Bool = true

    let targetPercent: Float = 75.0

    func reset() {
        score = 0
        lives = 3
        percentCovered = 0.0
        level = 1
        resetState()
    }

    func resetState() {
        isPlaying = false
        isPaused = false
        isGameOver = false
        isLevelComplete = false
        showLanding = true
    }

    func nextLevel() {
        // Every 10th level (10, 20, 30...) give an extra life
        if (level + 1) % 10 == 0 {
            lives += 1
        }

        level += 1
        percentCovered = 0.0
        isLevelComplete = false
        isPlaying = true
    }

    func startGame() {
        showLanding = false
        isPlaying = true
        isPaused = false
        isGameOver = false
        isLevelComplete = false
    }

    func gameOver() {
        isPlaying = false
        isGameOver = true

        // Show Interstitial Ad
        AdMobService.shared.showInterstitial()

        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "HighScore")
        }

        submitScore()
    }

    func revive() {
        lives += 1
        isGameOver = false
        isPlaying = true
    }

    func levelComplete() {
        isPlaying = false
        isLevelComplete = true
    }

    func setNickname(_ name: String) {
        let oldName = self.nickname
        self.nickname = name
        UserDefaults.standard.set(name, forKey: "UserNickname")

        // If changing from an existing nickname, update previous scores
        if !oldName.isEmpty && oldName != name {
            Task {
                do {
                    try await SupabaseService.shared.updateNickname(oldName: oldName, newName: name)
                    print("Updated nickname for previous scores")
                } catch {
                    print("Failed to update nickname on server: \(error)")
                }
            }
        }
    }

    func submitScore() {
        guard !nickname.isEmpty, score > 0 else { return }

        Task {
            do {
                try await SupabaseService.shared.submitScore(
                    nickname: nickname, score: score, level: level)
                print("Score submitted successfully")
            } catch {
                print("Failed to submit score: \(error)")
            }
        }
    }

    func fetchUserHighScore() async {
        guard !nickname.isEmpty else { return }

        do {
            if let bestEntry = try await SupabaseService.shared.fetchUserBest(nickname: nickname) {
                DispatchQueue.main.async {
                    if bestEntry.score > self.highScore {
                        self.highScore = bestEntry.score
                    }
                }
            }
        } catch {
            print("Failed to fetch user high score: \(error)")
        }
    }
}
