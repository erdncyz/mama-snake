import SpriteKit
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var manager = GameManager.shared
    @AppStorage(ArenaScene.storageKey) private var arenaScene = ArenaScene.space.rawValue
    @AppStorage(ArenaTheme.storageKey) private var menuTheme = ArenaTheme.midnight.rawValue
    @AppStorage("showArenaGrid") private var showGrid = true
    @AppStorage(SkinDefaults.bugKey) private var bugSkin = BugSkin.spider.rawValue
    @AppStorage(SkinDefaults.snakeKey) private var snakeSkin = SnakeSkin.classic.rawValue
    @State private var scene: GameScene = {
        let scene = GameScene(size: CGSize(width: 390, height: 600))
        // Match SpriteKit's coordinate space to the arena so cells, borders,
        // movement and artwork are not stretched at different axis ratios.
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        return scene
    }()

    var body: some View {
        GeometryReader { layout in
            let bannerWidth = max(1, min(layout.size.width - 24, 700))
            let compact = layout.size.height < 700
            let hudHeight: CGFloat = compact ? 142 : 176
            let hintHeight: CGFloat = 34
            let adHeight =
                manager.showLanding
                ? CGFloat(0)
                : AdMobBanner.height(for: bannerWidth) + 32
            let remainingHeight = max(
                120,
                layout.size.height - hudHeight - hintHeight - adHeight
            )
            let arenaWidth = max(1, min(layout.size.width, 1000) - 24)
            let arenaHeight = min(
                remainingHeight,
                arenaWidth * 4 / 3
            )
            let nextLifeLevel = (manager.level / 10 + 1) * 10
            ZStack {
                ArenaBackground(theme: ArenaTheme.resolved(menuTheme), grid: false).ignoresSafeArea()
                VStack(spacing: 0) {
                    GameHUD(compact: compact, onPause: togglePause)
                        .frame(height: hudHeight)
                    ZStack {
                        ArenaSceneBackground(scene: ArenaScene(rawValue: arenaScene) ?? .space, grid: showGrid)
                        SpriteView(scene: scene, options: [.allowsTransparency])
                            .onAppear {
                                scene.size = CGSize(width: arenaWidth, height: arenaHeight)
                            }
                            .onChange(of: arenaHeight) { newHeight in
                                scene.size = CGSize(width: arenaWidth, height: newHeight)
                            }
                            .onChange(of: arenaWidth) { newWidth in
                                scene.size = CGSize(width: newWidth, height: arenaHeight)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 6)
                                    .onChanged { value in
                                        guard manager.isPlaying, !manager.isPaused else { return }
                                        scene.handleSwipe(translation: value.translation)
                                    }
                                    .onEnded { _ in scene.endSwipe() }
                            )
                            .accessibilityLabel(L10n.string("game.area_accessibility"))
                            .accessibilityAction(named: Text(L10n.string("game.up"))) { scene.handleInput(direction: .up) }
                            .accessibilityAction(named: Text(L10n.string("game.down"))) { scene.handleInput(direction: .down) }
                            .accessibilityAction(named: Text(L10n.string("game.left"))) { scene.handleInput(direction: .left) }
                            .accessibilityAction(named: Text(L10n.string("game.right"))) { scene.handleInput(direction: .right) }
                            .frame(width: arenaWidth, height: arenaHeight)
                    }
                    .frame(width: arenaWidth, height: arenaHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(MambaStyle.mint.opacity(0.78), lineWidth: 3)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw.fill").foregroundStyle(MambaStyle.mint)
                        Text(L10n.string("game.swipe_hint"))
                        Spacer()
                        Image(systemName: "heart.fill").foregroundStyle(.pink)
                        Text(L10n.string("game.life_reward_hint", nextLifeLevel))
                    }
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 20)
                    .frame(height: hintHeight)

                    if !manager.showLanding {
                        VStack(spacing: 6) {
                            Text(L10n.string("common.ad"))
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
                        .frame(height: adHeight)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.18))
                        .overlay(alignment: .top) {
                            Color.white.opacity(0.08).frame(height: 1)
                        }
                    }
                }
                .frame(maxWidth: 1000, maxHeight: .infinity)
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
                    onRevive: {
                        manager.revive()
                        scene.reviveAfterAd()
                    },
                    onMainMenu: {
                        manager.quitToMenu()
                        scene.startLevel()
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
        .menuTheme(ArenaTheme.resolved(menuTheme))
        .onChange(of: scenePhase) { phase in
            if phase != .active && manager.isPlaying && !manager.isPaused && !manager.showLanding {
                scene.togglePause()
            }
        }
        .onChange(of: bugSkin) { _ in scene.applySelectedSkins() }
        .onChange(of: snakeSkin) { _ in scene.applySelectedSkins() }
        .defersSystemGestures(on: .bottom)
    }

    private func togglePause() {
        scene.togglePause()
    }
}

#Preview { ContentView() }
