import SpriteKit

#if canImport(UIKit)
    import UIKit
#endif
#if os(macOS)
    import AppKit
#endif

extension GameScene {

    func setupGestures(view: SKView) {
    }

    func handleInput(direction: Direction) {
        guard currentState == .playing else { return }

        switch direction {
        case .up:
            if currentDirection != .down { nextDirection = .up }
        case .down:
            if currentDirection != .up { nextDirection = .down }
        case .left:
            if currentDirection != .right { nextDirection = .left }
        case .right:
            if currentDirection != .left { nextDirection = .right }
        default: break
        }
    }

    func handleInputTap(at viewLocation: CGPoint) {
        // Legacy UI tap handling removed.
        // Input is now handled by SwiftUI Overlay.
    }
}
