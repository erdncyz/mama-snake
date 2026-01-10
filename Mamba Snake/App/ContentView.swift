import SpriteKit
import SwiftUI

struct ContentView: View {
    @State private var scene: GameScene = {
        let sc = GameScene()
        sc.scaleMode = .resizeFill
        return sc
    }()

    var body: some View {
        ZStack {
            // Game Layer
            GeometryReader { proxy in
                SpriteView(scene: scene)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        scene.size = proxy.size
                        scene.scaleMode = .resizeFill
                    }
                    .gesture(
                        DragGesture(minimumDistance: 20, coordinateSpace: .local)
                            .onEnded { value in
                                let horizontal = value.translation.width
                                let vertical = value.translation.height

                                if abs(horizontal) > abs(vertical) {
                                    if horizontal > 0 {
                                        scene.handleInput(direction: .right)
                                    } else {
                                        scene.handleInput(direction: .left)
                                    }
                                } else {
                                    if vertical > 0 {
                                        scene.handleInput(direction: .down)
                                    } else {
                                        scene.handleInput(direction: .up)
                                    }
                                }
                            }
                    )
                    .onTapGesture { location in
                        // Only handle tap for game input if playing and not paused
                        if GameManager.shared.isPlaying && !GameManager.shared.isPaused {
                             scene.handleInputTap(at: location)
                        }
                    }
            }
            
            // UI Overlay Layer
            GameOverlayView(
                onResume: {
                    GameManager.shared.isPaused = false
                    scene.togglePause() // Sync scene state
                },
                onRestart: {
                    GameManager.shared.reset()
                    GameManager.shared.startGame()
                    scene.resetGame() // Reset entities
                    scene.startLevel()
                },
                onNextLevel: {
                    GameManager.shared.nextLevel()
                    scene.startLevel()
                },
                onStart: {
                    GameManager.shared.startGame()
                    scene.startLevel() 
                },
                onPauseToggle: {
                    let paused = !GameManager.shared.isPaused
                    GameManager.shared.isPaused = paused
                    scene.togglePause()
                },
                onContinue: {
                    GameManager.shared.isPlaying = true
                }
            )
        }
    }
}

#Preview {
    ContentView()
}
