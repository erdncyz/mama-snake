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
    @Published var nickname: String = PlayerNickname.sanitize(
        UserDefaults.standard.string(forKey: "UserNickname") ?? "")
    @Published var highScore: Int = UserDefaults.standard.integer(forKey: "HighScore") {
        didSet {
            UserDefaults.standard.set(highScore, forKey: "HighScore")
        }
    }

    private init() {
        UserDefaults.standard.set(nickname, forKey: "UserNickname")
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

    /// Son tamamlanan bölümde kazanılan bonus (bölüm sonu ekranında gösterilir)
    @Published var lastLevelBonus: Int = 0

    let targetPercent: Float = 75.0

    func reset() {
        score = 0
        lives = 3
        percentCovered = 0.0
        level = 1
        lastLevelBonus = 0
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
        lastLevelBonus = 0
        isLevelComplete = false
        isPlaying = true
    }

    func startGame() {
        showLanding = false
        isPlaying = true
        isPaused = false
        isGameOver = false
        isLevelComplete = false
        FirebaseTelemetryService.shared.logGameStarted()
    }

    func returnToMenu() {
        reset()
    }

    /// Aktif oyundan ana menüye dönüş: skoru kaybettirmeden kaydedip menüye döner.
    func quitToMenu() {
        if !isGameOver {
            if score > highScore {
                highScore = score
            }
            FirebaseTelemetryService.shared.logGameEnded(score: score, level: level)
            submitScore()
        }
        returnToMenu()
    }

    /// Kapatılan YENİ hücreler için puan verir.
    /// Hücre başına 2 puan × seviye; tek hamlede 40+ hücre kapatmak +%50 bonus verir.
    @discardableResult
    func awardCapture(cells: Int) -> Int {
        guard cells > 0 else { return 0 }
        var earned = cells * 2 * level
        if cells >= 40 {
            earned = (earned * 3) / 2
        }
        score += earned
        return earned
    }

    func gameOver() {
        isPlaying = false
        isGameOver = true

        AdMobService.shared.showInterstitial()

        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "HighScore")
        }

        FirebaseTelemetryService.shared.logGameEnded(score: score, level: level)
        submitScore()
    }

    func revive() {
        lives += 1
        isGameOver = false
        isPlaying = true
    }

    func levelComplete() {
        // Bölüm bonusu: seviye × 100 + kalan her can × 25
        let bonus = 100 * level + 25 * lives
        lastLevelBonus = bonus
        score += bonus
        isPlaying = false
        isLevelComplete = true
        FirebaseTelemetryService.shared.logLevelCompleted(level: level)
    }

    func setNickname(_ name: String) {
        let sanitizedName = PlayerNickname.sanitize(name)
        guard !sanitizedName.isEmpty else { return }

        let oldName = self.nickname
        self.nickname = sanitizedName
        UserDefaults.standard.set(sanitizedName, forKey: "UserNickname")

        // If changing from an existing nickname, update previous scores
        if !oldName.isEmpty && oldName != sanitizedName {
            Task {
                do {
                    try await FirebaseService.shared.updateNickname(
                        oldName: oldName, newName: sanitizedName)
                    print("Updated nickname for previous scores")
                } catch {
                    FirebaseTelemetryService.shared.record(error, operation: "nickname_update")
                    print("Failed to update nickname on server: \(error)")
                }
            }
        }
    }

    func submitScore() {
        guard !nickname.isEmpty, score > 0 else { return }

        Task {
            do {
                try await FirebaseService.shared.submitScore(
                    nickname: nickname, score: score, level: level)
                print("Score submitted successfully")
            } catch {
                FirebaseTelemetryService.shared.record(error, operation: "solo_score_submit")
                print("Failed to submit score: \(error)")
            }
        }
    }

    func fetchUserHighScore() async {
        guard !nickname.isEmpty else { return }

        do {
            if let bestEntry = try await FirebaseService.shared.fetchUserBest(nickname: nickname) {
                DispatchQueue.main.async {
                    if bestEntry.score > self.highScore {
                        self.highScore = bestEntry.score
                    }
                }
            }
        } catch {
            FirebaseTelemetryService.shared.record(error, operation: "solo_high_score_fetch")
            print("Failed to fetch user high score: \(error)")
        }
    }
}
