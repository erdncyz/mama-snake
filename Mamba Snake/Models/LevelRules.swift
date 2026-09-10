import CoreGraphics
import Foundation

/// Seviye geçtikçe zorluk ve skorun nasıl değişeceği.
/// Hız ve gövde tavanlı; geç seviyede tempo dönüş sıklığından gelir.
enum LevelRules {
    static let maxSpeedMultiplier: CGFloat = 2.0
    static let speedStep: CGFloat = 0.08
    static let maxBodyCount = 8
    static let pointsPerCell = 2
    static let bigCaptureMinimumCells = 50
    static let bigCaptureRemainingPercent = 12
    static let overshootPointsPerPercent = 10

    enum Change: Hashable {
        case fasterSnake
        case longerSnake
        case sharperTurns
        case extraLife
        case scoreMultiplier

        var titleKey: String {
            switch self {
            case .fasterSnake: "overlay.faster_snake"
            case .longerSnake: "overlay.snake_segment"
            case .sharperTurns: "overlay.sharper_turns"
            case .extraLife: "overlay.life_prize"
            case .scoreMultiplier: "overlay.score_multiplier"
            }
        }

        var icon: String {
            switch self {
            case .fasterSnake: "bolt.fill"
            case .longerSnake: "plus.circle.fill"
            case .sharperTurns: "arrow.uturn.right"
            case .extraLife: "heart.fill"
            case .scoreMultiplier: "star.fill"
            }
        }
    }

    static func snakeSpeedMultiplier(for level: Int) -> CGFloat {
        let steps = CGFloat(max(0, level - 1))
        return min(maxSpeedMultiplier, 1 + steps * speedStep)
    }

    static func snakeSpeed(base: CGFloat, level: Int) -> CGFloat {
        base * snakeSpeedMultiplier(for: level)
    }

    static func snakeBodyCount(for level: Int) -> Int {
        min(maxBodyCount, 1 + max(0, level - 1) / 2)
    }

    static func snakeTurnInterval(for level: Int) -> TimeInterval {
        let range = turnIntervalRange(for: level)
        return Double.random(in: range.lower...range.upper)
    }

    static func grantsExtraLife(at level: Int) -> Bool {
        level > 0 && level.isMultiple(of: 10)
    }

    static func upcomingChanges(entering level: Int) -> [Change] {
        let previous = max(1, level - 1)
        var changes: [Change] = []

        if snakeSpeedMultiplier(for: level) > snakeSpeedMultiplier(for: previous) + 0.0001 {
            changes.append(.fasterSnake)
        }
        if snakeBodyCount(for: level) > snakeBodyCount(for: previous) {
            changes.append(.longerSnake)
        }
        if turnsTighten(from: previous, to: level) {
            changes.append(.sharperTurns)
        }
        if grantsExtraLife(at: level) {
            changes.append(.extraLife)
        }
        if changes.isEmpty {
            changes.append(.scoreMultiplier)
        }
        return changes
    }

    static func bigCaptureThreshold(remainingCells: Int) -> Int {
        max(bigCaptureMinimumCells, remainingCells * bigCaptureRemainingPercent / 100)
    }

    private static func turnIntervalRange(for level: Int) -> (lower: TimeInterval, upper: TimeInterval) {
        let steps = Double(max(0, level - 1))
        return (
            lower: max(0.35, 0.5 - steps * 0.02),
            upper: max(0.8, 2.5 - steps * 0.12)
        )
    }

    private static func turnsTighten(from previous: Int, to next: Int) -> Bool {
        let before = turnIntervalRange(for: previous)
        let after = turnIntervalRange(for: next)
        return after.upper < before.upper - 0.0001 || after.lower < before.lower - 0.0001
    }
}
