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
    var bugSpeed: CGFloat = 150.0 // Smooth movement speed
    let snakeSpeed: CGFloat = 160.0

    // MARK: - Game State
    var grid: [[CellType]] = []
    var currentDirection: Direction = .none
    var nextDirection: Direction = .none
    var lastUpdateTime: TimeInterval = 0
    var currentState: GameState = .ready

    // MARK: - Nodes
    var tileMap: SKTileMapNode!
    var bugNode: SKSpriteNode!
    var snakeNode: SKSpriteNode!
    var activeTrailNode: SKShapeNode!
    var activeTrailPath: CGMutablePath!
    var bugTrailEmitter: SKEmitterNode!


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

        // --- Bug Setup (Animated Spider) ---
        // GIF animasyonlu örümcek kullan
        if let animatedSpider = SKSpriteNode.createAnimatedSprite(
            gifNamed: "Spider",
            size: CGSize(width: gridSize * 2.0, height: gridSize * 2.0)
        ) {
            bugNode = animatedSpider
        } else {
            // Fallback: GIF yüklenemezse eski bug kullan
            print("⚠️ Spider.gif yüklenemedi, fallback Bug.png kullanılıyor")
            bugNode = SKSpriteNode(imageNamed: "Bug")
            bugNode.size = CGSize(width: gridSize * 1.5, height: gridSize * 1.5)
        }
        
        bugNode.zPosition = 10

        bugGridPos = (cols / 2, 0)
        updateBugPosition()
        tileMap.addChild(bugNode)
        
        // Ağ efekti setup
        setupBugTrailEffect()
        
        // --- Trail Line Setup ---
        activeTrailNode = SKShapeNode()
        activeTrailNode.strokeColor = .clear  // Görünmez yap
        activeTrailNode.lineWidth = 0  // Çizgi kalınlığı 0
        activeTrailNode.lineCap = .round
        activeTrailNode.zPosition = 5
        activeTrailPath = CGMutablePath()
        tileMap.addChild(activeTrailNode)

        // --- Snake Setup ---
        setupSnake()

        // UI
        // UI
        // UI is now handled by SwiftUI via GameManager state
        
        currentDirection = .none
        nextDirection = .none
        currentState = .ready

        GameManager.shared.percentCovered = 0.0
        
        // Initial Sync based on GameManager
        if GameManager.shared.isPlaying {
             currentState = .playing
        } else {
             currentState = .ready
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
        // Sync Helper: If manager says playing but we are ready, start!
        if GameManager.shared.isPlaying && currentState == .ready {
            currentState = .playing
        }
    
        guard currentState == .playing else {
            lastUpdateTime = currentTime
            return
        }
        
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = CGFloat(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        
        // Cap dt to prevent jumps
        let safeDt = min(dt, 0.1)

        moveBug(dt: safeDt)
        moveSnake(dt: 1.0/60.0) // Keep snake simplified fixed step for internal physics consistency or sync with dt

        checkWinCondition()
        updateLabels()
    }

    func moveBug(dt: CGFloat) {
        // 1. Handle Input Turning (Immediate)
        if nextDirection != .none && nextDirection != currentDirection {
             // Prevent u-turn logic
             var canTurn = true
             if currentDirection == .up && nextDirection == .down { canTurn = false }
             if currentDirection == .down && nextDirection == .up { canTurn = false }
             if currentDirection == .left && nextDirection == .right { canTurn = false }
             if currentDirection == .right && nextDirection == .left { canTurn = false }
             
             if canTurn || currentDirection == .none {
                 currentDirection = nextDirection
                 nextDirection = .none
                 
                 let rotateAction = SKAction.rotate(
                    toAngle: currentDirection.angle, duration: 0.1, shortestUnitArc: true)
                 bugNode.run(rotateAction)
             }
        }
        
        guard currentDirection != .none else { return }

        // 2. Calculate new position
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        switch currentDirection {
        case .up: dy = 1
        case .down: dy = -1
        case .left: dx = -1
        case .right: dx = 1
        default: break
        }
        
        let distance = bugSpeed * dt
        let currentPos = bugNode.position
        var nextPos = CGPoint(x: currentPos.x + dx * distance, y: currentPos.y + dy * distance)
        
        // 3. Wall Clamping (Soft Limits)
        // Map bounds in local tileMap coordinates
        let mapWidth = CGFloat(cols) * gridSize
        let mapHeight = CGFloat(rows) * gridSize
        let radius = gridSize / 2
        
        // Clamp
        nextPos.x = max(radius, min(mapWidth - radius, nextPos.x))
        nextPos.y = max(radius, min(mapHeight - radius, nextPos.y))
        
        // 4. Collision/Logic Trigger based on Grid Cell
        // We use the CENTER of the bug to determine its "Logic Cell"
        let logicX = Int(nextPos.x / gridSize)
        let logicY = Int(nextPos.y / gridSize)
        
        // Update Postion
        bugNode.position = nextPos
        
        // Track Logic Changes
        if logicX != bugGridPos.x || logicY != bugGridPos.y {
             handleGridTransition(newX: logicX, newY: logicY)
        }
        
        // 5. Update Visual Trail
        if grid[bugGridPos.x][bugGridPos.y] == .trail {
            // Add point to path
            if activeTrailPath.isEmpty {
                 activeTrailPath.move(to: currentPos)
            }
            activeTrailPath.addLine(to: nextPos)
            activeTrailNode.path = activeTrailPath
            
            // Ağ efektini aktif et
            updateBugTrailEmission(isActive: true)
        } else {
            // Not in trail mode (e.g. safe zone), clear path or keep it?
            // If we just entered safe zone, 'handleGridTransition' should have triggered fillArea
            if !activeTrailPath.isEmpty && grid[bugGridPos.x][bugGridPos.y] != .trail {
                activeTrailPath = CGMutablePath()
                activeTrailNode.path = nil
            }
            
            // Ağ efektini kapat
            updateBugTrailEmission(isActive: false)
        }
    }
    
    func handleGridTransition(newX: Int, newY: Int) {
        if newX < 0 || newX >= cols || newY < 0 || newY >= rows { return }
        
        let targetCell = grid[newX][newY]
        
        // Self Collision (Trail)
        if targetCell == .trail {
            die()
            return
        }
        
        // Entering Filled/Border (Safe Zone or Closing Loop)
        if targetCell == .filled || targetCell == .border {
            let currentCell = grid[bugGridPos.x][bugGridPos.y]
            if currentCell == .trail {
                // Closing Loop!
                bugGridPos = (newX, newY)
                fillArea()
                
                // Clear visual trail
                activeTrailPath = CGMutablePath()
                activeTrailNode.path = nil
                
                // Stop movement to emphasize completion
                currentDirection = .none
                return
            }
            // Just moving inside safe zone
            bugGridPos = (newX, newY)
            return
        }
        
        // Moving into Empty (Start/Continue Trail)
        if targetCell == .empty {
            // Mark new cell
            grid[newX][newY] = .trail
            // We DO NOT update visual tile here to avoid "blocks" appearing.
            // But we MUST enable logic for enemies. 
            // Optional: Show faint grid trail? NO, user wants to remove square logic.
            // We rely on SKShapeNode for visuals.
            
            bugGridPos = (newX, newY)
        }
    }
    
    // Legacy mapping (kept for reference or if we need to snap)
    func updateBugPosition() {
        // Now handled continuously by updates
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
        
        DispatchQueue.main.async {
            GameManager.shared.percentCovered = pct
            GameManager.shared.score += 100
        }
        playSound(.score)  // Score/Confirm
    }

    func die() {
        playSound(.crash)  // Crash sound
        lives -= 1
        
        DispatchQueue.main.async {
            GameManager.shared.lives = self.lives
        }

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
            
            // Clear web trail
            clearWebTrail()

            // Pause Game to avoid instant death loop
            currentState = .ready
            currentDirection = .none
            nextDirection = .none
            
            DispatchQueue.main.async {
                GameManager.shared.isPlaying = false // Paused for ready
                // Maybe show "Tap to Continue" overlay?
                // For now we just wait for tap logic in ContentView
            }
        }
    }

    func resetPositions() {
        // Bug position reset
        bugGridPos = (cols / 2, 0)
        let x = CGFloat(bugGridPos.x) * gridSize + gridSize / 2
        let y = CGFloat(bugGridPos.y) * gridSize + gridSize / 2
        bugNode.position = CGPoint(x: x, y: y)
        
        currentDirection = .none
        nextDirection = .none
        
        // Reset Trail
        activeTrailPath = CGMutablePath()
        activeTrailNode.path = nil
        
        // Clear web trail
        clearWebTrail()

        // Reset rotation
        bugNode.zRotation = 0

        // Re-setup snake fully to reset body history and positions
        setupSnake()
    }

    func togglePause() {
        if currentState == .playing {
            currentState = .paused
            DispatchQueue.main.async { GameManager.shared.isPaused = true }
        } else if currentState == .paused {
            currentState = .playing
            DispatchQueue.main.async { GameManager.shared.isPaused = false }
        }
    }



    func gameOver(win: Bool) {
        currentState = win ? .levelComplete : .gameOver
        
        DispatchQueue.main.async {
            if win {
                GameManager.shared.levelComplete()
            } else {
                GameManager.shared.gameOver()
            }
        }
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
