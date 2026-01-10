//
//  GameScene.swift
//  Mamba Snake
//
//  Created by Erdinç Yılmaz on 10.01.2026.
//

import AudioToolbox
import GameplayKit
import SpriteKit

#if canImport(UIKit)
    import UIKit
#else
    import AppKit
#endif

enum CellType: Int {
    case empty = 0  // Danger zone (Grid Pattern)
    case filled = 1  // Safe zone (Solid Color)
    case trail = 2  // Line being drawn
    case border = 3  // Safe perimeter
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
    case ready, playing, gameOver, levelComplete
}

class GameScene: SKScene {

    // MARK: - Configuration
    var gridSize: CGFloat = 25.0
    var cols: Int = 0
    var rows: Int = 0
    let moveSpeed: TimeInterval = 0.05  // Faster for smoother control
    let snakeSpeed: CGFloat = 160.0

    // MARK: - Game State
    var grid: [[CellType]] = []
    var currentDirection: Direction = .none
    var nextDirection: Direction = .none
    var lastMoveTime: TimeInterval = 0
    var currentState: GameState = .ready

    // MARK: - Nodes
    var tileMap: SKTileMapNode!
    var bugNode: SKShapeNode!
    var snakeNode: SKShapeNode!
    var uiLayer: SKNode!

    // UI Labels
    var scoreLabel: SKLabelNode!
    var livesLabel: SKLabelNode!
    var percentLabel: SKLabelNode!
    var messageLabel: SKLabelNode!

    // Entities
    var bugGridPos: (x: Int, y: Int) = (0, 0)
    var snakePosition: CGPoint = .zero
    var snakeVelocity: CGVector = .zero
    var snakeBody: [SKShapeNode] = []

    // Snake Movement History for Trail Effect
    var snakeHistory: [CGPoint] = []
    var snakeBodyCount: Int {
        return GameManager.shared.level
    }
    let snakeSpacing: CGFloat = 15.0  // Distance between segments

    var lives: Int = 3

    // Textures
    var emptyTexture: SKTexture!
    var filledTexture: SKTexture!
    var trailTexture: SKTexture!
    var borderTexture: SKTexture!

    // MARK: - Lifecycle

    func playSound(_ id: SystemSoundID) {
        // AI Generated Custom Sounds
        switch id {
        case 1057: SoundManager.shared.playStartSound()
        case 1003: SoundManager.shared.playCrashSound()
        case 1016: SoundManager.shared.playScoreSound()
        case 1025: SoundManager.shared.playWinSound()
        default: break
        }
    }

    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        #if os(macOS)
            self.backgroundColor = NSColor(displayP3Red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0)
        #else
            self.backgroundColor = UIColor(displayP3Red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0)
        #endif

        setupTextures()
        startLevel()
        setupGestures(view: view)
    }

    func setupGestures(view: SKView) {
        #if canImport(UIKit)
            let swipes: [UISwipeGestureRecognizer.Direction] = [.up, .down, .left, .right]
            for dir in swipes {
                let swipe = UISwipeGestureRecognizer(
                    target: self, action: #selector(handleSwipe(_:)))
                swipe.direction = dir
                view.addGestureRecognizer(swipe)
            }

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            view.addGestureRecognizer(tap)
        #endif
        // MacOS gesture handling would go here if needed, or key presses
    }

    #if canImport(UIKit)
        @objc func handleSwipe(_ sender: UISwipeGestureRecognizer) {
            guard currentState == .playing else { return }

            switch sender.direction {
            case .up: nextDirection = .up
            case .down: nextDirection = .down
            case .left: nextDirection = .left
            case .right: nextDirection = .right
            default: break
            }
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            // Check for tap on credits label first if possible, but gesture might swallow touches.
            // Actually, UITapGestureRecognizer converts to location.
            // Let's check location here too.
            let location = sender.location(in: self.view)
            let sceneLoc = self.convertPoint(fromView: location)
            let nodes = self.nodes(at: sceneLoc)

            for node in nodes {
                if node.name == "credits" {
                    if let url = URL(string: "https://erdincyilmaz.netlify.app/") {
                        UIApplication.shared.open(url)
                    }
                    return  // Don't process game tap
                }
            }

            if currentState == .ready {
                playSound(1057)
                currentState = .playing
                messageLabel.isHidden = true
                if landingNode != nil { landingNode.removeFromParent() }

                self.isPaused = false

                // Resume from death prompt (Restore velocity)
                if snakeVelocity == .zero {
                    let speed = snakeSpeed
                    let randomDx: CGFloat = Bool.random() ? speed : -speed
                    let randomDy: CGFloat = Bool.random() ? speed : -speed
                    snakeVelocity = CGVector(dx: randomDx, dy: randomDy)
                }
            } else if currentState == .gameOver || currentState == .levelComplete {
                // Animate out
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
                    // Fallback if panel somehow missing
                    if currentState == .gameOver {
                        resetGame()
                    } else if currentState == .levelComplete {
                        GameManager.shared.nextLevel()
                    }
                    startLevel()
                }
            }
        }
    #endif

    // MARK: - Assets & Design

    func setupTextures() {
        let size = CGSize(width: gridSize, height: gridSize)

        // 1. Empty (Danger): Dark Dirt/Dry Ground
        emptyTexture = createTexture(size: size) { ctx in
            // Background
            #if os(macOS)
                NSColor(calibratedRed: 0.25, green: 0.22, blue: 0.18, alpha: 1.0).setFill()
            #else
                UIColor(red: 0.25, green: 0.22, blue: 0.18, alpha: 1.0).setFill()
            #endif
            ctx.fill(CGRect(origin: .zero, size: size))
            // Subtle texture/pebble marks?
            // Simple low-alpha noise or grid
            #if os(macOS)
                NSColor(white: 1.0, alpha: 0.05).setStroke()
            #else
                UIColor(white: 1.0, alpha: 0.05).setStroke()
            #endif
            ctx.stroke(CGRect(origin: .zero, size: size))
        }

        // 2. Filled (Safe): Fresh Grass Green
        filledTexture = createTexture(size: size) { ctx in
            #if os(macOS)
                NSColor(displayP3Red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0).setFill()
            #else
                UIColor(displayP3Red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0).setFill()
            #endif
            ctx.fill(CGRect(origin: .zero, size: size))

            // Grass blade styling or bezel
            #if os(macOS)
                NSColor(displayP3Red: 0.3, green: 0.7, blue: 0.4, alpha: 0.4).setStroke()
            #else
                UIColor(displayP3Red: 0.3, green: 0.7, blue: 0.4, alpha: 0.4).setStroke()
            #endif
            ctx.setLineWidth(2)
            ctx.stroke(CGRect(origin: .zero, size: size))
        }

        // 3. Trail (Drawing): Bright Electric Cyan (High Contrast on Dirt)
        trailTexture = createTexture(size: size) { ctx in
            #if os(macOS)
                NSColor(displayP3Red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0).setFill()
            #else
                UIColor(displayP3Red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0).setFill()
            #endif
            ctx.fill(CGRect(origin: .zero, size: size))

            // Inner glowing core
            #if os(macOS)
                NSColor.white.setFill()
            #else
                UIColor.white.setFill()
            #endif
            ctx.fill(
                CGRect(
                    x: size.width * 0.25, y: size.height * 0.25, width: size.width * 0.5,
                    height: size.height * 0.5))
        }

        // 4. Border: Visible (Matches Green Grass to look Full Screen)
        borderTexture = createTexture(size: size) { ctx in
            #if os(macOS)
                NSColor(displayP3Red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0).setFill()
            #else
                UIColor(displayP3Red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0).setFill()
            #endif
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    // Cross-platform texture creation
    func createTexture(size: CGSize, draw: (CGContext) -> Void) -> SKTexture {
        #if canImport(UIKit)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                draw(ctx.cgContext)
            }
            return SKTexture(image: image)
        #else
            let img = NSImage(size: size)
            img.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                draw(ctx)
            }
            img.unlockFocus()
            return SKTexture(image: img)
        #endif
    }

    // MARK: - Path Generation

    func createBugPath() -> CGPath {
        #if canImport(UIKit)
            let path = UIBezierPath()
            let size = gridSize
            // Body (Oval)
            path.append(
                UIBezierPath(
                    ovalIn: CGRect(x: -size * 0.4, y: -size * 0.5, width: size * 0.8, height: size))
            )
            // Head
            path.append(
                UIBezierPath(
                    ovalIn: CGRect(
                        x: -size * 0.25, y: size * 0.4, width: size * 0.5, height: size * 0.3)))
            return path.cgPath
        #else
            let path = CGMutablePath()
            let size = gridSize
            path.addEllipse(
                in: CGRect(x: -size * 0.4, y: -size * 0.5, width: size * 0.8, height: size))
            path.addEllipse(
                in: CGRect(x: -size * 0.25, y: size * 0.4, width: size * 0.5, height: size * 0.3))
            return path
        #endif
    }

    func createSnakePath() -> CGPath {
        #if canImport(UIKit)
            let path = UIBezierPath()
            // Rounded "Kawaii" Head
            // Oval centered
            let headRect = CGRect(
                x: -gridSize * 0.6, y: -gridSize * 0.5, width: gridSize * 1.2,
                height: gridSize * 1.1)
            path.append(UIBezierPath(ovalIn: headRect))
            return path.cgPath
        #else
            let path = CGMutablePath()
            let headRect = CGRect(
                x: -gridSize * 0.6, y: -gridSize * 0.5, width: gridSize * 1.2,
                height: gridSize * 1.1)
            path.addEllipse(in: headRect)
            return path
        #endif
    }

    // MARK: - Level Setup

    func resetGame() {
        GameManager.shared.reset()
        lives = 3
    }

    func startLevel() {
        removeAllChildren()

        // Fix UI Margin: Adjusted for clean full-screen look
        let topMargin: CGFloat = 70.0
        let bottomMargin: CGFloat = 40.0  // Increased for Footer
        let availableHeight = self.size.height - (topMargin + bottomMargin)

        // Dynamic Grid Size for Full Width No-Gap
        // We target roughly 25.0 but adjust to fit perfectly
        let targetCols: CGFloat = 15.0
        let rawGridSize = self.size.width / targetCols
        gridSize = rawGridSize  // Precise float

        cols = Int(targetCols)
        rows = Int(availableHeight / gridSize)

        // Ensure odd number for centering if preferred, or just even.
        // Actually, just use what fits.
        // snake wants a center point.
        // If cols is odd, center is integer index.
        if cols % 2 == 0 { cols -= 1 }
        if rows % 2 == 0 { rows -= 1 }

        grid = Array(repeating: Array(repeating: .empty, count: rows), count: cols)

        // Borders
        for x in 0..<cols {
            grid[x][0] = .border
            grid[x][rows - 1] = .border
        }
        for y in 0..<rows {
            grid[0][y] = .border
            grid[cols - 1][y] = .border
        }

        let tileSet = SKTileSet(tileGroups: [
            SKTileGroup(
                tileDefinition: SKTileDefinition(
                    texture: emptyTexture, size: CGSize(width: gridSize, height: gridSize))),
            SKTileGroup(
                tileDefinition: SKTileDefinition(
                    texture: filledTexture, size: CGSize(width: gridSize, height: gridSize))),
            SKTileGroup(
                tileDefinition: SKTileDefinition(
                    texture: trailTexture, size: CGSize(width: gridSize, height: gridSize))),
            SKTileGroup(
                tileDefinition: SKTileDefinition(
                    texture: borderTexture, size: CGSize(width: gridSize, height: gridSize))),
        ])

        tileMap = SKTileMapNode(
            tileSet: tileSet, columns: cols, rows: rows,
            tileSize: CGSize(width: gridSize, height: gridSize))

        let mapWidth = CGFloat(cols) * gridSize
        let mapHeight = CGFloat(rows) * gridSize
        tileMap.anchorPoint = .zero

        // Center vertically in the available area
        let totalPlayAreaY = (self.size.height - mapHeight) / 2.0
        // But we want to respect margins.
        // Actually, if we use dynamic grid, width is EXACTLY self.size.width (if cols wasn't decremented).
        // Since we decrement cols to be odd, there is a small gap (1 grid unit).
        // To cover sides completely, we should probably keep cols even if needed or center it.
        // If user wants NO GAP, we should not decrement cols.
        // Let's remove the "cols -= 1" check for width?
        // But snake starts at `cols/2`. Integer division handles even/odd.
        // Let's keep width full.

        // RE-CALCULATION without odd constraint for COLS if possible, or just center.
        // User said "Right Left NO space".
        // If I make `cols` derived exactly, it fits.
        // I will center `tileMap` horizontally.

        let centerYShift = (bottomMargin - topMargin) / 2.0
        tileMap.position = CGPoint(x: -mapWidth / 2, y: -mapHeight / 2 + centerYShift)
        addChild(tileMap)
        refreshTileMap()

        // --- Bug Setup ---
        // Enhanced Vector Bug (Metallic Beetle)
        bugNode = SKShapeNode(path: createBugPath())
        #if os(macOS)
            bugNode.fillColor = NSColor(displayP3Red: 0.0, green: 0.8, blue: 0.2, alpha: 1.0)
            bugNode.strokeColor = NSColor(displayP3Red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        #else
            bugNode.fillColor = UIColor(displayP3Red: 0.0, green: 0.8, blue: 0.2, alpha: 1.0)
            bugNode.strokeColor = UIColor(displayP3Red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        #endif
        bugNode.lineWidth = 2.0
        bugNode.zPosition = 10

        bugGridPos = (cols / 2, 0)
        updateBugPosition()
        tileMap.addChild(bugNode)

        // --- Snake Setup ---
        setupSnake()

        // UI
        setupUI(topMargin: topMargin)

        currentDirection = .none
        nextDirection = .none
        currentState = .ready

        GameManager.shared.percentCovered = 0.0
        updateLabels()

        if GameManager.shared.level == 1 && GameManager.shared.score == 0 {
            messageLabel.isHidden = true
            showLandingPage()
        } else {
            messageLabel.text = "TAP TO START"
            messageLabel.isHidden = false

            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5),
            ])
            messageLabel.run(SKAction.repeatForever(pulse), withKey: "pulse")
        }
    }

    func setupSnake() {
        if snakeNode != nil { snakeNode.removeFromParent() }
        snakeBody.forEach { $0.removeFromParent() }
        snakeBody.removeAll()
        snakeHistory.removeAll()

        // Find valid spawn point (Nearest to center that is EMPTY)
        var spawnX = cols / 2
        var spawnY = rows / 2

        // If center is blocked (Filled/Border/Trail), search spiral
        if grid[spawnX][spawnY] != .empty {
            var found = false
            let maxRad = max(cols, rows)
            searchLoop: for r in 1...maxRad {
                for dx in -r...r {
                    for dy in -r...r {
                        // Only check perimeter of this radius to avoid re-checking
                        if abs(dx) != r && abs(dy) != r { continue }

                        let nx = spawnX + dx
                        let ny = spawnY + dy
                        if nx >= 1 && nx < cols - 1 && ny >= 1 && ny < rows - 1 {
                            if grid[nx][ny] == .empty {
                                spawnX = nx
                                spawnY = ny
                                found = true
                                break searchLoop
                            }
                        }
                    }
                }
            }
        }

        let centerX = CGFloat(spawnX) * gridSize + gridSize / 2
        let centerY = CGFloat(spawnY) * gridSize + gridSize / 2
        snakePosition = CGPoint(x: centerX, y: centerY)

        // Create Body Segments with Shapes and Patterns
        for _ in 0..<snakeBodyCount {
            let segRadius = gridSize * 0.55  // Slightly larger overlaps
            let seg = SKShapeNode(circleOfRadius: segRadius)

            // Natural Green Body
            #if os(macOS)
                let bodyColor = NSColor(displayP3Red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
                let patternColor = NSColor(displayP3Red: 0.8, green: 0.9, blue: 0.2, alpha: 1.0)
                seg.fillColor = bodyColor
                seg.strokeColor = NSColor(white: 0.0, alpha: 0.1)  // Subtle outline
            #else
                let bodyColor = UIColor(displayP3Red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
                let patternColor = UIColor(displayP3Red: 0.8, green: 0.9, blue: 0.2, alpha: 1.0)
                seg.fillColor = bodyColor
                seg.strokeColor = UIColor(white: 0.0, alpha: 0.1)
            #endif
            seg.lineWidth = 1
            seg.zPosition = 8
            seg.position = snakePosition

            // Add Pattern (Yellow Stripe/Triangle)
            // Simple triangle pointing up (which becomes "back" when rotated?)
            // Actually snake rotates, so pattern should be directional.
            // Let's make a "Lightning Bolt" or "V" shape
            let patPath = CGMutablePath()
            patPath.move(to: CGPoint(x: -segRadius * 0.6, y: -segRadius * 0.2))
            patPath.addLine(to: CGPoint(x: 0, y: segRadius * 0.5))
            patPath.addLine(to: CGPoint(x: segRadius * 0.6, y: -segRadius * 0.2))
            patPath.addLine(to: CGPoint(x: 0, y: 0))  // V shape
            patPath.closeSubpath()

            let patternNode = SKShapeNode(path: patPath)
            patternNode.fillColor = patternColor  // Yellow
            patternNode.lineWidth = 0
            patternNode.position = CGPoint(x: 0, y: 0)
            seg.addChild(patternNode)

            tileMap.addChild(seg)
            snakeBody.append(seg)
        }

        // Create Head
        snakeNode = SKShapeNode(path: createSnakePath())
        #if os(macOS)
            snakeNode.fillColor = NSColor(displayP3Red: 0.2, green: 0.85, blue: 0.35, alpha: 1.0)  // Lighter green head
            snakeNode.strokeColor = NSColor(white: 0.0, alpha: 0.1)
        #else
            snakeNode.fillColor = UIColor(displayP3Red: 0.2, green: 0.85, blue: 0.35, alpha: 1.0)
            snakeNode.strokeColor = UIColor(white: 0.0, alpha: 0.1)
        #endif
        snakeNode.lineWidth = 1.0
        snakeNode.zPosition = 9
        snakeNode.position = snakePosition

        // Cartoon Eyes
        func createEye(x: CGFloat) -> SKShapeNode {
            let eye = SKShapeNode(circleOfRadius: gridSize * 0.22)
            eye.fillColor = .white
            eye.lineWidth = 0
            eye.position = CGPoint(x: x, y: gridSize * 0.2)

            let pupil = SKShapeNode(circleOfRadius: gridSize * 0.12)
            pupil.fillColor = .black
            pupil.lineWidth = 0
            // Look slightly forward
            pupil.position = CGPoint(x: 0, y: gridSize * 0.05)
            eye.addChild(pupil)

            let gleam = SKShapeNode(circleOfRadius: gridSize * 0.04)
            gleam.fillColor = .white
            gleam.lineWidth = 0
            gleam.position = CGPoint(x: gridSize * 0.04, y: gridSize * 0.06)
            pupil.addChild(gleam)

            return eye
        }

        let eyeLeft = createEye(x: -gridSize * 0.25)
        let eyeRight = createEye(x: gridSize * 0.25)

        snakeNode.addChild(eyeLeft)
        snakeNode.addChild(eyeRight)

        snakeVelocity = CGVector(dx: snakeSpeed, dy: snakeSpeed)
        tileMap.addChild(snakeNode)

        // Init history for segments to sit on
        for _ in 0..<(snakeBodyCount * Int(snakeSpacing)) {
            snakeHistory.append(snakePosition)
        }
    }

    // MARK: - UI Nodes
    var gameOverPanel: SKNode!
    var hudNode: SKNode!
    var landingNode: SKNode!

    // MARK: - UI Setup

    func setupUI(topMargin: CGFloat) {
        if hudNode != nil { hudNode.removeFromParent() }
        hudNode = SKNode()

        // Position HUD for Dynamic Island
        // Dynamic Island is at top center approx 30-40pt height, but we use safe area.
        // Screen Top -> 0 (Anchor centered means +H/2)
        // We want to be below the island.
        // Let's go down by 'topMargin' + 10 padding.

        let safeTopY = self.size.height / 2 - topMargin - 10
        hudNode.position = CGPoint(x: 0, y: safeTopY)
        hudNode.zPosition = 50  // Above tilemap
        addChild(hudNode)

        // Remove old UI
        uiLayer?.removeFromParent()
        scoreLabel?.removeFromParent()
        livesLabel?.removeFromParent()
        percentLabel?.removeFromParent()
        messageLabel?.removeFromParent()

        let width = self.size.width
        // Inset calculations for corner safe areas
        let sideOffset = width * 0.32

        // --- Score Pill ---
        let scorePill = createHUDItem(icon: "🏆", text: "0", color: .yellow, width: 100)
        scorePill.position = CGPoint(x: -sideOffset, y: 0)
        scorePill.name = "scorePill"
        hudNode.addChild(scorePill)

        // --- Level/Percent Pill ---
        let centerPill = createHUDItem(icon: "", text: "Lv.1 📊 0%", color: .white, width: 150)
        centerPill.position = CGPoint(x: 0, y: 0)
        centerPill.name = "percentPill"
        hudNode.addChild(centerPill)

        // --- Lives Pill ---
        let livesPill = createHUDItem(icon: "❤️", text: "3", color: .red, width: 80)
        livesPill.position = CGPoint(x: sideOffset, y: 0)
        livesPill.name = "livesPill"
        hudNode.addChild(livesPill)

        // Setup Game Over Panel
        setupGameOverPanel()

        // Start Message
        messageLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        messageLabel.fontSize = 32
        messageLabel.fontColor = .white
        messageLabel.text = "TAP TO START"
        messageLabel.position = CGPoint(x: 0, y: 0)
        messageLabel.zPosition = 1000
        messageLabel.name = "startMsg"

        // Shadow
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.fontSize = 32
        shadow.fontColor = .black
        shadow.alpha = 0.5
        shadow.text = "TAP TO START"
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        messageLabel.addChild(shadow)
        addChild(messageLabel)

        // Credits Link
        let creditsLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        creditsLabel.text = "Developed by Erdinç Yılmaz"
        creditsLabel.fontSize = 14
        creditsLabel.fontColor = .white
        creditsLabel.position = CGPoint(x: 0, y: -self.size.height / 2 + 25)
        creditsLabel.name = "credits"
        creditsLabel.zPosition = 100
        addChild(creditsLabel)
    }

    func showLandingPage() {
        if landingNode != nil { landingNode.removeFromParent() }
        landingNode = SKNode()
        landingNode.zPosition = 2000
        addChild(landingNode)

        // Dim Background
        let bg = SKShapeNode(rectOf: self.size)
        // Dark overlay
        #if os(macOS)
            bg.fillColor = NSColor.black.withAlphaComponent(0.85)
        #else
            bg.fillColor = UIColor.black.withAlphaComponent(0.85)  // Darker for focus
        #endif
        bg.strokeColor = .clear
        landingNode.addChild(bg)

        // --- GRAPHICAL LOGO ---
        let logoNode = SKNode()
        logoNode.position = CGPoint(x: 0, y: self.size.height * 0.28)  // Higher up
        landingNode.addChild(logoNode)

        // 1. Coiled Body (Spiral)
        // Simplified ring for vector cleanliness
        let bodyRing = SKShapeNode(circleOfRadius: 40)
        #if os(macOS)
            bodyRing.strokeColor = NSColor(displayP3Red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
        #else
            bodyRing.strokeColor = UIColor(displayP3Red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
        #endif
        bodyRing.lineWidth = 15
        logoNode.addChild(bodyRing)

        // 2. Head
        let head = SKShapeNode(circleOfRadius: 25)
        #if os(macOS)
            head.fillColor = NSColor(displayP3Red: 0.25, green: 0.9, blue: 0.4, alpha: 1.0)
        #else
            head.fillColor = UIColor(displayP3Red: 0.25, green: 0.9, blue: 0.4, alpha: 1.0)
        #endif
        head.lineWidth = 0
        head.position = CGPoint(x: 35, y: 15)  // Offset on the ring
        logoNode.addChild(head)

        // 3. Eyes (Cute)
        let eyeWhite = SKShapeNode(circleOfRadius: 8)
        eyeWhite.fillColor = .white
        eyeWhite.position = CGPoint(x: -8, y: 5)
        head.addChild(eyeWhite)

        let eyePupil = SKShapeNode(circleOfRadius: 4)
        eyePupil.fillColor = .black
        eyePupil.position = CGPoint(x: 2, y: 0)
        eyeWhite.addChild(eyePupil)

        let eyeWhite2 = eyeWhite.copy() as! SKShapeNode
        eyeWhite2.position = CGPoint(x: 8, y: 5)
        head.addChild(eyeWhite2)

        // TEXT LOGO
        let logo = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        logo.text = "MAMBA SNAKE"
        logo.fontSize = 52
        #if os(macOS)
            logo.fontColor = NSColor(displayP3Red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
        #else
            logo.fontColor = UIColor(displayP3Red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)  // Vibrant Green
        #endif
        logo.position = CGPoint(x: 0, y: -60)  // Below graphic logic
        logoNode.addChild(logo)

        let shadow = logo.copy() as! SKLabelNode
        shadow.fontColor = .black
        shadow.position = CGPoint(x: 4, y: -64)
        shadow.zPosition = -1
        logoNode.addChild(shadow)

        // Instructions
        let instructions = [
            "👆 Swipe to Turn",
            "🐛 Eat Bugs to Grow",
            "🚫 Avoid Walls & Tail",
        ]

        for (i, text) in instructions.enumerated() {
            let lbl = SKLabelNode(fontNamed: "AvenirNext-Bold")  // Bold for readability
            lbl.text = text
            lbl.fontSize = 22
            lbl.fontColor = .white
            lbl.position = CGPoint(x: 0, y: 50 - CGFloat(i * 50))
            landingNode.addChild(lbl)
        }

        // START BUTTON visual
        // We'll use a Pill shape for button appearance
        let btnSize = CGSize(width: 220, height: 60)
        let btnBg = SKShapeNode(rectOf: btnSize, cornerRadius: 30)
        #if os(macOS)
            btnBg.fillColor = NSColor(displayP3Red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
            btnBg.strokeColor = NSColor.white
        #else
            btnBg.fillColor = UIColor(displayP3Red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
            btnBg.strokeColor = UIColor.white
        #endif
        btnBg.lineWidth = 3
        btnBg.position = CGPoint(x: 0, y: -self.size.height * 0.25)
        btnBg.name = "startBtn"  // Name for tap detection if needed

        let btnText = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        btnText.text = "TAP TO PLAY"
        btnText.fontSize = 24
        btnText.fontColor = .white
        btnText.verticalAlignmentMode = .center
        btnText.position = CGPoint(x: 0, y: 0)
        btnBg.addChild(btnText)

        // Pulse Animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8),
        ])
        btnBg.run(SKAction.repeatForever(pulse))

        landingNode.addChild(btnBg)
    }

    func createHUDItem(icon: String, text: String, color: SKColor, width: CGFloat) -> SKShapeNode {
        let size = CGSize(width: width, height: 40)  // Sleeker height
        let bg = SKShapeNode(rectOf: size, cornerRadius: 20)

        // Glassmorphism: Semi-transparent Black
        #if os(macOS)
            bg.fillColor = NSColor.black.withAlphaComponent(0.6)
            bg.strokeColor = NSColor.white.withAlphaComponent(0.2)
        #else
            bg.fillColor = UIColor.black.withAlphaComponent(0.6)
            bg.strokeColor = UIColor.white.withAlphaComponent(0.2)
        #endif
        bg.lineWidth = 1.0

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")  // Bolder font
        label.text = "\(icon) \(text)"
        label.fontSize = 15  // Slightly smaller for elegance
        label.fontColor = .white  // Text is always white, Icon provides color logic in string?
        // Actually earlier code used 'color' param for text.
        // Let's use 'color' param for the text color to keep existing logic working.
        label.fontColor = color

        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -1)
        label.name = "label"

        bg.addChild(label)
        return bg
    }

    func setupGameOverPanel() {
        if gameOverPanel != nil { gameOverPanel.removeFromParent() }
        gameOverPanel = SKNode()
        gameOverPanel.zPosition = 200
        gameOverPanel.alpha = 0
        gameOverPanel.isHidden = true
        addChild(gameOverPanel)

        // Dark Overlay background
        let bgOverlay = SKShapeNode(rectOf: self.size)
        #if os(macOS)
            bgOverlay.fillColor = NSColor.black.withAlphaComponent(0.7)
        #else
            bgOverlay.fillColor = UIColor.black.withAlphaComponent(0.7)
        #endif
        bgOverlay.lineWidth = 0
        gameOverPanel.addChild(bgOverlay)

        // Panel Container
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 380
        let panel = SKShapeNode(
            rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 30)
        #if os(macOS)
            panel.fillColor = NSColor(calibratedRed: 0.1, green: 0.12, blue: 0.18, alpha: 1.0)
            panel.strokeColor = NSColor(calibratedRed: 0.0, green: 0.8, blue: 1.0, alpha: 0.8)
        #else
            panel.fillColor = UIColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0)
            panel.strokeColor = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.8)
        #endif
        panel.lineWidth = 3

        gameOverPanel.addChild(panel)

        // Title
        let titleLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLbl.name = "goTitle"
        titleLbl.fontSize = 32
        titleLbl.position = CGPoint(x: 0, y: 120)
        panel.addChild(titleLbl)

        // Score Labels
        let scoreTitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        scoreTitle.text = "SCORE"
        scoreTitle.fontSize = 16
        scoreTitle.fontColor = .lightGray
        scoreTitle.position = CGPoint(x: 0, y: 70)
        panel.addChild(scoreTitle)

        let scoreVal = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreVal.name = "goScore"
        scoreVal.fontSize = 42
        scoreVal.fontColor = .white
        scoreVal.position = CGPoint(x: 0, y: 30)
        panel.addChild(scoreVal)

        // Level Labels
        let levelTitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        levelTitle.text = "LEVEL REACHED"
        levelTitle.fontSize = 16
        levelTitle.fontColor = .lightGray
        levelTitle.position = CGPoint(x: 0, y: -20)
        panel.addChild(levelTitle)

        let levelVal = SKLabelNode(fontNamed: "AvenirNext-Bold")
        levelVal.name = "goLevel"
        levelVal.fontSize = 36
        levelVal.fontColor = .yellow
        levelVal.position = CGPoint(x: 0, y: -60)
        panel.addChild(levelVal)

        // Button (Visual representation)
        let btn = SKShapeNode(rectOf: CGSize(width: 220, height: 56), cornerRadius: 28)
        #if os(macOS)
            btn.fillColor = .white
        #else
            btn.fillColor = .white
        #endif
        btn.position = CGPoint(x: 0, y: -130)
        panel.addChild(btn)

        let btnLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        btnLbl.text = "TAP TO PLAY"
        #if os(macOS)
            btnLbl.fontColor = .black
        #else
            btnLbl.fontColor = .black
        #endif
        btnLbl.fontSize = 20
        btnLbl.verticalAlignmentMode = .center
        btn.addChild(btnLbl)

        // Pulse animation for button
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.8),
            SKAction.scale(to: 0.95, duration: 0.8),
        ])
        btn.run(SKAction.repeatForever(pulse))
    }

    // MARK: - Game Loop & Logic

    override func update(_ currentTime: TimeInterval) {
        guard currentState == .playing else { return }

        // Bug Movement
        if currentTime - lastMoveTime > moveSpeed {
            moveBug()
            lastMoveTime = currentTime
        }

        // Snake Movement
        let dt = 1.0 / 60.0
        moveSnake(dt: dt)

        checkWinCondition()
        updateLabels()
    }

    func moveBug() {
        if nextDirection != .none {
            var canTurn = true
            if currentDirection == .up && nextDirection == .down { canTurn = false }
            if currentDirection == .down && nextDirection == .up { canTurn = false }
            if currentDirection == .left && nextDirection == .right { canTurn = false }
            if currentDirection == .right && nextDirection == .left { canTurn = false }
            if canTurn { currentDirection = nextDirection }
        }

        guard currentDirection != .none else { return }

        // Rotate Bug to face direction
        let rotateAction = SKAction.rotate(
            toAngle: currentDirection.angle, duration: 0.1, shortestUnitArc: true)
        bugNode.run(rotateAction)

        var newX = bugGridPos.x
        var newY = bugGridPos.y

        switch currentDirection {
        case .up: newY += 1
        case .down: newY -= 1
        case .left: newX -= 1
        case .right: newX += 1
        default: break
        }

        if newX < 0 || newX >= cols || newY < 0 || newY >= rows { return }

        let targetCell = grid[newX][newY]

        if targetCell == .trail {
            die()
            return
        }

        // MOVEMENT RESTRICTION: Cannot enter filled area unless closing a loop or sliding along safe zone
        if targetCell == .filled {
            let currentCell = grid[bugGridPos.x][bugGridPos.y]
            // Allow if drawing (Closing loop) OR if already safe (Sliding along filled/border)
            if currentCell != .trail && currentCell != .filled && currentCell != .border {
                // Block movement into filled zone if trying to enter from outside without drawing
                return
            }
        }

        if targetCell == .empty {
            grid[newX][newY] = .trail
            updateSingleTile(x: newX, y: newY)
            bugGridPos = (newX, newY)
        } else {
            // Target is Border or Filled (closing loop)
            let currentCell = grid[bugGridPos.x][bugGridPos.y]

            if currentCell == .trail {
                // Closed Loop
                bugGridPos = (newX, newY)
                fillArea()
                currentDirection = .none
                nextDirection = .none
            } else {
                // Moving along border or safe zone
                bugGridPos = (newX, newY)
            }
        }
        updateBugPosition()
    }

    func updateBugPosition() {
        let x = CGFloat(bugGridPos.x) * gridSize + gridSize / 2
        let y = CGFloat(bugGridPos.y) * gridSize + gridSize / 2
        bugNode.position = CGPoint(x: x, y: y)
    }

    func moveSnake(dt: CGFloat) {
        let dx = snakeVelocity.dx * dt
        let dy = snakeVelocity.dy * dt
        let nextPos = CGPoint(x: snakePosition.x + dx, y: snakePosition.y + dy)

        // Update History for Body
        // Add current position to front of history
        // To smooth it out, we record every frame or based on distance.
        // Every frame is smoother for "follow the leader" with fixed index offset.
        snakeHistory.insert(snakePosition, at: 0)

        let requiredHistory = snakeBodyCount * Int(snakeSpacing) + 1
        if snakeHistory.count > requiredHistory {
            snakeHistory.removeLast(snakeHistory.count - requiredHistory)
        }

        // Update Body Segments
        for i in 0..<snakeBody.count {
            let historyIndex = (i + 1) * Int(snakeSpacing)
            if historyIndex < snakeHistory.count {
                snakeBody[i].position = snakeHistory[historyIndex]
                snakeBody[i].zRotation = snakeNode.zRotation  // Follow rotation or calculate proper angle?
                // Calculate proper angle for body segment
                if historyIndex + 1 < snakeHistory.count {
                    let p1 = snakeHistory[historyIndex]
                    let p2 = snakeHistory[historyIndex - 1]  // Look slightly ahead
                    let angle = atan2(p2.y - p1.y, p2.x - p1.x) - CGFloat.pi / 2
                    snakeBody[i].zRotation = angle
                }
            }
        }

        // Rotate Head
        let angle = atan2(snakeVelocity.dy, snakeVelocity.dx) - CGFloat.pi / 2
        snakeNode.zRotation = angle

        let radius = gridSize / 2 - 2
        let checkPoints = [
            CGPoint(x: nextPos.x + radius, y: nextPos.y),
            CGPoint(x: nextPos.x - radius, y: nextPos.y),
            CGPoint(x: nextPos.x, y: nextPos.y + radius),
            CGPoint(x: nextPos.x, y: nextPos.y - radius),
        ]

        var bouncedX = false
        var bouncedY = false

        for p in checkPoints {
            let gx = Int(p.x / gridSize)
            let gy = Int(p.y / gridSize)

            if gx < 0 || gx >= cols || gy < 0 || gy >= rows {
                if !bouncedX && (gx < 0 || gx >= cols) {
                    snakeVelocity.dx *= -1
                    bouncedX = true
                }
                if !bouncedY && (gy < 0 || gy >= rows) {
                    snakeVelocity.dy *= -1
                    bouncedY = true
                }
                continue
            }

            let cell = grid[gx][gy]
            if cell == .trail {
                die()
                return
            }
            if cell == .filled || cell == .border {
                if !bouncedX && abs(p.x - nextPos.x) > 0.01 {
                    snakeVelocity.dx *= -1
                    bouncedX = true
                } else if !bouncedY && abs(p.y - nextPos.y) > 0.01 {
                    snakeVelocity.dy *= -1
                    bouncedY = true
                }
            }
        }

        if !bouncedX && !bouncedY {
            snakePosition = nextPos
        } else {
            snakePosition = CGPoint(
                x: snakePosition.x + snakeVelocity.dx * dt,
                y: snakePosition.y + snakeVelocity.dy * dt)
        }
        snakeNode.position = snakePosition

        // Check collision HEAD
        if snakeNode.intersects(bugNode) {
            // Safe Zone Logic: If bug is on border or filled area, it's immune
            // Safe Zone Logic: If bug is on/near border or filled area, it's immune
            let bx = bugGridPos.x
            let by = bugGridPos.y
            var isSafe = false

            // Allow safety if bug is even adjacent to safe zones (Visual leniency)
            let neighborOffsets = [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]
            for offset in neighborOffsets {
                let nx = bx + offset.0
                let ny = by + offset.1
                if nx >= 0 && nx < cols && ny >= 0 && ny < rows {
                    let cell = grid[nx][ny]
                    if cell == .border || cell == .filled {
                        isSafe = true
                        break
                    }
                }
            }

            if !isSafe {
                die()
                return
            }
        }

        // Check collision BODY
        for segment in snakeBody {
            if segment.intersects(bugNode) {
                die()
                return
            }
        }
    }

    func fillArea() {
        let snakeGridX = Int(snakePosition.x / gridSize)
        let snakeGridY = Int(snakePosition.y / gridSize)

        var visited = Array(repeating: Array(repeating: false, count: rows), count: cols)
        var queue: [(Int, Int)] = []

        let sx = max(0, min(cols - 1, snakeGridX))
        let sy = max(0, min(rows - 1, snakeGridY))

        if grid[sx][sy] == .empty {
            queue.append((sx, sy))
            visited[sx][sy] = true
        }

        while !queue.isEmpty {
            let (cx, cy) = queue.removeFirst()
            let neighbors = [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]

            for (nx, ny) in neighbors {
                if nx >= 0 && nx < cols && ny >= 0 && ny < rows {
                    if !visited[nx][ny] && grid[nx][ny] == .empty {
                        visited[nx][ny] = true
                        queue.append((nx, ny))
                    }
                }
            }
        }

        var filledCount = 0
        let totalCells = cols * rows

        for x in 0..<cols {
            for y in 0..<rows {
                if grid[x][y] == .trail {
                    grid[x][y] = .filled
                } else if grid[x][y] == .empty && !visited[x][y] {
                    grid[x][y] = .filled
                }
                if grid[x][y] == .filled { filledCount += 1 }
            }
        }

        refreshTileMap()
        let pct = Float(filledCount) / Float(totalCells) * 100.0
        GameManager.shared.percentCovered = pct
        GameManager.shared.score += 100
        playSound(1016)  // Score/Confirm
    }

    func die() {
        playSound(SystemSoundID(1003))  // Crash sound
        lives -= 1
        GameManager.shared.lives = lives

        // Shake Camera
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -10, y: 0, duration: 0.05),
            SKAction.moveBy(x: 20, y: 0, duration: 0.05),
            SKAction.moveBy(x: -10, y: 0, duration: 0.05),
        ])
        self.run(shake)

        if lives <= 0 {
            gameOver(win: false)
        } else {
            resetPositions()
            // Clear trails
            for x in 0..<cols {
                for y in 0..<rows {
                    if grid[x][y] == .trail { grid[x][y] = .empty }
                }
            }
            refreshTileMap()

            // Pause Game to avoid instant death loop
            currentState = .ready
            currentDirection = .none
            nextDirection = .none
            snakeVelocity = .zero  // Stop moving

            messageLabel.text = "TAP TO CONTINUE"
            messageLabel.fontColor = .white
            messageLabel.zPosition = 1000
            messageLabel.isHidden = false
            // Ensure pulse animation is running
            if messageLabel.action(forKey: "pulse") == nil {
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.5),
                    SKAction.scale(to: 1.0, duration: 0.5),
                ])
                messageLabel.run(SKAction.repeatForever(pulse), withKey: "pulse")
            }
        }
    }

    func resetPositions() {
        bugGridPos = (cols / 2, 0)
        updateBugPosition()
        currentDirection = .none

        // Reset rotation
        bugNode.zRotation = 0

        // Re-setup snake fully to reset body history and positions
        setupSnake()

        // Randomize direction handled in handleTap if needed
        // snakeVelocity = ... (Removed to prevent override)
    }

    func gameOver(win: Bool) {
        currentState = win ? .levelComplete : .gameOver

        // Update Panel Content
        // Ensure panel exists in case setupUI ran before
        if gameOverPanel == nil { setupGameOverPanel() }

        if let panel = gameOverPanel.children.first(where: { $0.children.count > 0 }) {  // The background container
            if let title = panel.childNode(withName: "goTitle") as? SKLabelNode {
                title.text = win ? "LEVEL COMPLETE!" : "GAME OVER"
                title.fontColor = win ? .green : .red
            }
            if let sVal = panel.childNode(withName: "goScore") as? SKLabelNode {
                sVal.text = "\(GameManager.shared.score)"
            }
            if let lVal = panel.childNode(withName: "goLevel") as? SKLabelNode {
                lVal.text = "\(GameManager.shared.level)"
            }
        }

        messageLabel.isHidden = true
        gameOverPanel.isHidden = false
        gameOverPanel.alpha = 0
        gameOverPanel.run(SKAction.fadeIn(withDuration: 0.3))

        // Scale effect for panel
        gameOverPanel.setScale(0.8)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.4)
        scaleUp.timingMode = .easeOut
        gameOverPanel.run(scaleUp)
    }

    func checkWinCondition() {
        if GameManager.shared.percentCovered >= GameManager.shared.targetPercent {
            playSound(1025)  // Fanfare-like
            gameOver(win: true)
        }
    }

    func refreshTileMap() {
        for x in 0..<cols {
            for y in 0..<rows {
                updateSingleTile(x: x, y: y)
            }
        }
    }

    func updateSingleTile(x: Int, y: Int) {
        let type = grid[x][y]
        if type.rawValue < tileMap.tileSet.tileGroups.count {
            tileMap.setTileGroup(tileMap.tileSet.tileGroups[type.rawValue], forColumn: x, row: y)
        }
    }

    func updateLabels() {
        guard hudNode != nil else { return }

        if let scorePill = hudNode.childNode(withName: "scorePill"),
            let lbl = scorePill.childNode(withName: "label") as? SKLabelNode
        {
            lbl.text = "🏆 \(GameManager.shared.score)"
        }

        if let pill = hudNode.childNode(withName: "percentPill"),
            let lbl = pill.childNode(withName: "label") as? SKLabelNode
        {
            lbl.text = String(
                format: "Lv.%d 📊 %.1f%%", GameManager.shared.level,
                GameManager.shared.percentCovered)
        }

        if let pill = hudNode.childNode(withName: "livesPill"),
            let lbl = pill.childNode(withName: "label") as? SKLabelNode
        {
            lbl.text = "❤️ \(lives)"
        }
    }
}
