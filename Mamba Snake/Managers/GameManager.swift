import Foundation
import SpriteKit
import SwiftUI
import Combine

class GameManager: ObservableObject {
    static let shared = GameManager()

    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var percentCovered: Float = 0.0
    @Published var level: Int = 1
    
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
    }
    
    func levelComplete() {
        isPlaying = false
        isLevelComplete = true
    }
}
