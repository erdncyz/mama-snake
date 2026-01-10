import CoreGraphics
import Foundation

enum CellType: Int {
    case empty = 0
    case filled = 1
    case trail = 2
    case border = 3
}

enum Direction {
    case none, up, down, left, right

    var angle: CGFloat {
        switch self {
        case .up: return 0
        case .down: return .pi
        case .left: return .pi / 2
        case .right: return -.pi / 2
        case .none: return 0
        }
    }
}

enum GameState {
    case ready, playing, paused, gameOver, levelComplete
}
