import Foundation
import SpriteKit

class GameManager {
    static let shared = GameManager()

    var score: Int = 0
    var lives: Int = 3
    var percentCovered: Float = 0.0
    var level: Int = 1

    let targetPercent: Float = 75.0

    func reset() {
        score = 0
        lives = 3
        percentCovered = 0.0
        level = 1
    }

    func nextLevel() {
        level += 1
        percentCovered = 0.0
    }
}
