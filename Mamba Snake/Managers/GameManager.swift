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
    /// Son kapanışın puanı; HUD kısa süre gösterir.
    @Published var lastCaptureAward: CaptureAward?

    let targetPercent: Float = 75.0
    private var captureAwardToken = 0

    func reset() {
        score = 0
        lives = 3
        percentCovered = 0.0
        level = 1
        lastLevelBonus = 0
        lastCaptureAward = nil
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
        if LevelRules.grantsExtraLife(at: level + 1) {
            lives += 1
        }

        level += 1
        percentCovered = 0.0
        lastLevelBonus = 0
        lastCaptureAward = nil
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
    /// Hücre × 2 × seviye; kalan boş alanın ~%12'si (en az 50 hücre) +%50;
    /// %75'i aşan her yüzde için ekstra bonus.
    @discardableResult
    func awardCapture(
        cells: Int,
        previousPercent: Float,
        newPercent: Float,
        totalPlayable: Int
    ) -> CaptureAward? {
        guard cells > 0 else { return nil }
        captureAwardToken += 1
        let award = CaptureAward.scoring(
            cells: cells,
            level: level,
            previousPercent: previousPercent,
            newPercent: newPercent,
            totalPlayable: totalPlayable,
            targetPercent: targetPercent,
            id: captureAwardToken
        )
        score += award.points
        lastCaptureAward = award
        return award
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
        isPaused = false
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
