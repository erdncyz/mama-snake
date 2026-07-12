import SpriteKit
import SwiftUI

enum GameLayout {
    /// Dynamic Island / çentik altında kalmamak için HUD içeriğinin üst boşluğu
    static let hudTopPadding: CGFloat = 60
    /// HUD satırının (skor, level, kalp, butonlar) sabit yüksekliği
    static let hudContentHeight: CGFloat = 56
    static let hudBottomPadding: CGFloat = 12
    /// Oyun alanının başladığı üst sınır: HUD ile birebir aynı
    static var headerHeight: CGFloat {
        hudTopPadding + hudContentHeight + hudBottomPadding
    }
    /// Home indicator bölgesine taşmamak için alt boşluk
    static let bottomInset: CGFloat = 40
}

struct ContentView: View {
    @ObservedObject private var multiplayerService = MultiplayerService.shared

    @State private var scene: GameScene = {
        let sc = GameScene()
        sc.scaleMode = .resizeFill
        return sc
    }()

    var body: some View {
        GeometryReader { geometry in
            let gameWidth = max(1, geometry.size.width - 10)
            let gameHeight = max(
                1,
                geometry.size.height
                    - (geometry.safeAreaInsets.top + GameLayout.headerHeight)
                    - (geometry.safeAreaInsets.bottom + GameLayout.bottomInset))

            ZStack {
                // Tüm arka plan siyah (Oyun dışı alanlar için)
                Color.black.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Üst Boşluk (HUD bu alana gelecek)
                    // HUD ile aynı yükseklik: oyun alanı başlığın altından başlar
                    Color.black
                        .frame(height: geometry.safeAreaInsets.top + GameLayout.headerHeight)

                    // Orta: Oyun Alanı
                    // Yanlardan 5px boşluk bırakarak çerçeve etkisi veriyoruz
                    HStack(spacing: 0) {
                        Color.black.frame(width: 5)

                        SpriteView(scene: scene)
                            .frame(width: gameWidth, height: gameHeight)
                            // Oyun alanı boyutunu dinamik ayarla
                            .onAppear {
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
                    .frame(width: geometry.size.width, height: gameHeight)

                    // Alt Boşluk (Home indicator bölgesi)
                    Color.black
                        .frame(height: geometry.safeAreaInsets.bottom + GameLayout.bottomInset)
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
                        scene.resetGame()
                        GameManager.shared.startGame()
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
                    },
                    onExitMultiplayer: {
                        Task {
                            await MultiplayerService.shared.leaveRoom()
                        }
                        GameManager.shared.returnToMenu()
                        scene.startLevel()
                    },
                    onMainMenu: {
                        GameManager.shared.quitToMenu()
                        if MultiplayerService.shared.role != nil {
                            Task {
                                await MultiplayerService.shared.leaveRoom()
                            }
                        }
                        scene.startLevel()
                    }
                )
            }
        }
        .onChange(of: multiplayerService.status) { oldStatus, newStatus in
            handleMultiplayerStatusChange(from: oldStatus, to: newStatus)
        }
        // Alt kenardaki kaydırmalar home hareketini tetiklemesin
        .defersSystemGestures(on: .bottom)
    }

    private func handleMultiplayerStatusChange(
        from oldStatus: MultiplayerRoomStatus,
        to newStatus: MultiplayerRoomStatus
    ) {
        guard GameManager.shared.isMultiplayer else { return }

        let message: String
        if newStatus == .closed {
            message = "The host closed the room."
        } else if oldStatus == .playing && newStatus == .waiting
            && multiplayerService.isHost
        {
            message = "The second player left the room."
        } else {
            return
        }

        GameManager.shared.returnToMenu()
        scene.startLevel()
        Task {
            await multiplayerService.endSessionAfterOpponentLeft(message: message)
        }
    }
}

#Preview {
    ContentView()
}
