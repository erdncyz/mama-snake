import SpriteKit
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var manager = GameManager.shared
    @AppStorage("arenaTheme") private var arenaTheme = ArenaTheme.forest.rawValue
    @AppStorage("menuTheme") private var menuTheme = ArenaTheme.midnight.rawValue
    @AppStorage("showArenaGrid") private var showGrid = true
    @State private var scene: GameScene = {
        let scene = GameScene(size: CGSize(width: 390, height: 600))
        // Keep gameplay coordinates stable while filling the available display area.
        scene.scaleMode = .fill
        scene.backgroundColor = .clear
        return scene
    }()

    var body: some View {
        GeometryReader { layout in
            let bannerWidth = max(1, min(layout.size.width - 24, 700))
            ZStack {
                ArenaBackground(theme: ArenaTheme(rawValue: menuTheme) ?? .midnight, grid: false).ignoresSafeArea()
                VStack(spacing: 0) {
                    GameHUD(compact: layout.size.height < 700, onPause: togglePause)
                    GeometryReader { geometry in
                        ZStack {
                            ArenaBackground(theme: ArenaTheme(rawValue: arenaTheme) ?? .forest, grid: showGrid)
                            SpriteView(scene: scene, options: [.allowsTransparency])
                                .gesture(
                                    DragGesture(minimumDistance: 6)
                                        .onChanged { value in
                                            guard manager.isPlaying, !manager.isPaused else { return }
                                            scene.handleSwipe(translation: value.translation)
                                        }
                                        .onEnded { _ in scene.endSwipe() }
                                )
                                .accessibilityLabel("Oyun alanı. Örümceği yönlendirmek için kaydır.")
                                .accessibilityAction(named: Text("Yukarı")) { scene.handleInput(direction: .up) }
                                .accessibilityAction(named: Text("Aşağı")) { scene.handleInput(direction: .down) }
                                .accessibilityAction(named: Text("Sol")) { scene.handleInput(direction: .left) }
                                .accessibilityAction(named: Text("Sağ")) { scene.handleInput(direction: .right) }
                        }
                        .frame(width: max(1, geometry.size.width), height: max(1, geometry.size.height))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay { ArenaFrame() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(.horizontal, 12)
                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw.fill").foregroundStyle(MambaStyle.mint)
                        Text("Kaydır ve alanı kapat")
                        Spacer()
                        Image(systemName: "heart.fill").foregroundStyle(.pink)
                        Text("Seviye \((manager.level / 10 + 1) * 10) · +1 can")
                    }
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: 1000)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !manager.showLanding {
                        VStack(spacing: 6) {
                            Text("REKLAM")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(2)
                                .foregroundStyle(.secondary)
                            Group {
                                if manager.isPlaying && !manager.isPaused
                                    && !manager.isGameOver && !manager.isLevelComplete {
                                    AdMobBanner(width: bannerWidth)
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(width: bannerWidth, height: AdMobBanner.height(for: bannerWidth))
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity)
                        .background(MambaStyle.surface)
                        .overlay(alignment: .top) {
                            Color.white.opacity(0.08).frame(height: 1)
                        }
                    }
                }
                .accessibilityHidden(manager.showLanding || manager.isPaused || manager.isGameOver || manager.isLevelComplete || !manager.isPlaying)

                GameOverlayView(
                    onResume: togglePause,
                    onRestart: {
                        scene.resetGame()
                        manager.startGame()
                        scene.startLevel()
                    },
                    onNextLevel: {
                        manager.nextLevel()
                        scene.startLevel()
                    },
                    onStart: {
                        manager.startGame()
                        scene.startLevel()
                    },
                    onContinue: { manager.isPlaying = true },
                    onMainMenu: {
                        manager.quitToMenu()
                        scene.startLevel()
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && manager.isPlaying && !manager.isPaused && !manager.showLanding {
                scene.togglePause()
            }
        }
        .defersSystemGestures(on: .bottom)
    }

    private func togglePause() {
        scene.togglePause()
    }
}

#Preview { ContentView() }
