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
    var bugNode: SKSpriteNode!
    var snakeNode: SKSpriteNode!
    var uiLayer: SKNode!

    // UI Nodes
    var gameOverPanel: SKNode!
    var pausePanel: SKNode!
    var hudNode: SKNode!
    var landingNode: SKNode!

    // UI Labels
    var scoreLabel: SKLabelNode!
    var livesLabel: SKLabelNode!
    var percentLabel: SKLabelNode!
    var messageLabel: SKLabelNode!

    // Entities
    var bugGridPos: (x: Int, y: Int) = (0, 0)
    var snakePosition: CGPoint = .zero
    var snakeVelocity: CGVector = .zero
    var snakeBody: [SKSpriteNode] = []

    // Snake Movement History for Trail Effect
    var snakeHistory: [CGPoint] = []
    var snakeBodyCount: Int {
        return GameManager.shared.level
    }
    let snakeSpacing: CGFloat = 6.0  // Distance between segments

    var lives: Int = 3

    // Textures
    var emptyTexture: SKTexture!
    var filledTexture: SKTexture!
    var trailTexture: SKTexture!
    var borderTexture: SKTexture!

    // MARK: - Lifecycle

    func playSound(_ type: SoundType) {
        // AI Generated Custom Sounds
        SoundManager.shared.play(type)
    }

    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)


        setupTextures()
        startLevel()
        setupGestures(view: view)
    }



    // MARK: - Level Setup

    func resetGame() {
        GameManager.shared.reset()
        lives = 3
    }

    func startLevel() {
        removeAllChildren()

        // Set Background Image
        let bgNode = SKSpriteNode(imageNamed: "Background")
        bgNode.position = .zero // Center since anchor is 0.5,0.5
        bgNode.zPosition = -100
        
        // Scale to fit
        let ratio = max(self.size.width / bgNode.size.width, self.size.height / bgNode.size.height)
        bgNode.setScale(ratio)
        
        addChild(bgNode)

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

        let centerYShift = (bottomMargin - topMargin) / 2.0
        tileMap.position = CGPoint(x: -mapWidth / 2, y: -mapHeight / 2 + centerYShift)
        addChild(tileMap)
        refreshTileMap()

        // --- Bug Setup ---
        bugNode = SKSpriteNode(imageNamed: "Bug")
        bugNode.size = CGSize(width: gridSize, height: gridSize)
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

        // Create Body Segments
        for _ in 0..<snakeBodyCount {
            let seg = SKSpriteNode(imageNamed: "SnakeBody")
            seg.size = CGSize(width: gridSize, height: gridSize)
            seg.zPosition = 8
            seg.position = snakePosition
            tileMap.addChild(seg)
            snakeBody.append(seg)
        }

        // Create Head
        snakeNode = SKSpriteNode(imageNamed: "SnakeHead")
        snakeNode.size = CGSize(width: gridSize * 1.2, height: gridSize * 1.2)
        snakeNode.zPosition = 9
        snakeNode.position = snakePosition

        snakeVelocity = CGVector(dx: snakeSpeed, dy: snakeSpeed)
        tileMap.addChild(snakeNode)

        // Init history for segments to sit on
        for _ in 0..<(snakeBodyCount * Int(snakeSpacing)) {
            snakeHistory.append(snakePosition)
        }
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
        playSound(.score)  // Score/Confirm
    }

    func die() {
        playSound(.crash)  // Crash sound
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

    func togglePause() {
        if currentState == .playing {
            currentState = .paused
            showPausePanel()
        } else if currentState == .paused {
            currentState = .playing
            hidePausePanel()
        }
    }

    func showPausePanel() {
        if pausePanel == nil { setupPausePanel() }
        pausePanel.isHidden = false
        pausePanel.alpha = 0
        pausePanel.run(SKAction.fadeIn(withDuration: 0.2))
        
        // Scale effect
        pausePanel.setScale(0.8)
        pausePanel.run(SKAction.scale(to: 1.0, duration: 0.2))
    }

    func hidePausePanel() {
        if pausePanel != nil {
            pausePanel.run(SKAction.fadeOut(withDuration: 0.2)) {
                self.pausePanel.isHidden = true
            }
        }
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
            playSound(.win)  // Fanfare-like
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
}
