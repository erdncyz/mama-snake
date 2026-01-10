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
        let sceneLoc = self.convertPoint(fromView: viewLocation)
        let nodes = self.nodes(at: sceneLoc)

        for node in nodes {
            if node.name == "credits" {
                if let url = URL(string: "https://erdincyilmaz.netlify.app/") {
                    #if canImport(UIKit)
                        UIApplication.shared.open(url)
                    #elseif os(macOS)
                        NSWorkspace.shared.open(url)
                    #endif
                }
                return
            }
        }

        if currentState == .ready {
            playSound(.start)
            currentState = .playing
            messageLabel.isHidden = true
            if landingNode != nil { landingNode.removeFromParent() }

            self.isPaused = false

            if snakeVelocity == .zero {
                let speed = snakeSpeed
                let randomDx: CGFloat = Bool.random() ? speed : -speed
                let randomDy: CGFloat = Bool.random() ? speed : -speed
                snakeVelocity = CGVector(dx: randomDx, dy: randomDy)
            }
        } else if currentState == .gameOver || currentState == .levelComplete {
            let fadeOut = SKAction.fadeOut(withDuration: 0.2)
            if gameOverPanel != nil && !gameOverPanel.isHidden {
                gameOverPanel.run(fadeOut) {
                    self.gameOverPanel.isHidden = true
                    if self.currentState == .gameOver {
                        self.resetGame()
                    } else if self.currentState == .levelComplete {
                        GameManager.shared.nextLevel()
                    }
                    self.startLevel()
                }
            } else {
                if currentState == .gameOver {
                    resetGame()
                } else if currentState == .levelComplete {
                    GameManager.shared.nextLevel()
                }
                startLevel()
            }
        }
    }
}
