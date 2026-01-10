import SpriteKit
import SwiftUI

struct ContentView: View {
    @State private var scene: GameScene = {
        let sc = GameScene()
        sc.scaleMode = .resizeFill
        return sc
    }()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Tüm arka plan siyah (Oyun dışı alanlar için)
                Color.black.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Üst Boşluk (HUD bu alana gelecek)
                    // Safe area + içerik yüksekliği (50px)
                    Color.black
                        .frame(height: geometry.safeAreaInsets.top + 50)

                    // Orta: Oyun Alanı
                    // Yanlardan 5px boşluk bırakarak çerçeve etkisi veriyoruz
                    HStack(spacing: 0) {
                        Color.black.frame(width: 5)

                        SpriteView(scene: scene)
                            // Oyun alanı boyutunu dinamik ayarla
                            .onAppear {
                                let gameWidth = geometry.size.width - 10  // 5px sol + 5px sağ
                                let gameHeight =
                                    geometry.size.height - (geometry.safeAreaInsets.top + 50)
                                    - (geometry.safeAreaInsets.bottom + 5)
                                scene.size = CGSize(width: gameWidth, height: gameHeight)
                                scene.scaleMode = .resizeFill

                                // Boyutlar güncellendikten sonra grid sistemini yeniden başlat
                                // Bu, mapHeight'ın yanlış (büyük) hesaplanmasını önler.
                                scene.startLevel()
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

                        Color.black.frame(width: 5)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Alt Boşluk (Border)
                    Color.black
                        .frame(height: geometry.safeAreaInsets.bottom + 5)
                }
                .edgesIgnoringSafeArea(.all)

                // UI Overlay Layer (En üstte)
                // HUD, bu VStack'in üst kısmına denk gelecek şekilde tasarlandı
                GameOverlayView(
                    onResume: {
                        GameManager.shared.isPaused = false
                        scene.togglePause()
                    },
                    onRestart: {
                        GameManager.shared.reset()
                        GameManager.shared.startGame()
                        scene.resetGame()
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
}

#Preview {
    ContentView()
}
