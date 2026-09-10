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
    static let boundaryInset = 0

    var gridSize: CGFloat = 25.0
    var cols: Int = 0
    var rows: Int = 0
    var bugSpeed: CGFloat = 200.0  // iPhone referans arenasında nokta/sn
    let snakeSpeed: CGFloat = 160.0
    /// 390pt genişlik / 30 hücre — iPhone’daki his. iPad’de hücre büyür, hız da onunla ölçeklenir.
    private let referenceGridSize: CGFloat = 390.0 / 30.0

    private var speedScale: CGFloat {
        max(gridSize, 1) / referenceGridSize
    }

    // MARK: - Game State
    var grid: [[CellType]] = []
    var currentDirection: Direction = .none
    var nextDirection: Direction = .none
    var hasHandledSwipeInput = false
    var lastUpdateTime: TimeInterval = 0
    var currentState: GameState = .ready
    var isEating: Bool = false

    // MARK: - Nodes
    var boardNode: SKNode!
    var tileMap: SKTileMapNode!
    var bugNode: SKSpriteNode!
    var snakeNode: SKSpriteNode!
    var activeTrailNode: SKShapeNode!
    var activeTrailPath: CGMutablePath!
    var activeTrailCorners: [CGPoint] = []
    var bugTrailEmitter: SKEmitterNode!

    // Entities
    var bugGridPos: (x: Int, y: Int) = (0, 0)
    var trailStartGridPos: (x: Int, y: Int) = (0, 0)  // Track where the trail started
    var snakePosition: CGPoint = .zero
    var snakeVelocity: CGVector = .zero
    var snakeBody: [SKSpriteNode] = []
    var trailCellIndices = Set<Int>()

    // Snake Movement History for Trail Effect
    var snakeHistory: [CGPoint] = []
    var snakeBodyCount: Int {
        LevelRules.snakeBodyCount(for: GameManager.shared.level)
    }

    var currentLevelSnakeSpeed: CGFloat {
        LevelRules.snakeSpeed(base: snakeSpeed, level: GameManager.shared.level) * speedScale
    }
    var snakeSegmentSpacing: CGFloat { gridSize * 1.5 }

    var lives: Int = 3

    var timeSinceLastSnakeTurn: TimeInterval = 0
    var nextSnakeTurnTime: TimeInterval = 2.0

    // Textures
    var emptyTexture: SKTexture!
    var filledTexture: SKTexture!
    var trailTexture: SKTexture!
    var borderTexture: SKTexture!

    // MARK: - Setup (Fix for missing textures)
    func setupTextures() {
        let size = CGSize(width: gridSize, height: gridSize)

        // Empty Cell
        let emptyShape = SKShapeNode(rectOf: size)
        emptyShape.fillColor = .clear
        emptyShape.strokeColor = .clear
        emptyTexture = view?.texture(from: emptyShape) ?? SKTexture()

        // Filled Cell
        let filledShape = SKShapeNode(rectOf: size)
        filledShape.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 0.3)
        filledShape.strokeColor = .clear
        filledTexture = view?.texture(from: filledShape) ?? SKTexture()

        // Trail Cell
        let trailShape = SKShapeNode(rectOf: size)
        trailShape.fillColor = SKColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.5)
        trailShape.strokeColor = .clear
        trailTexture = view?.texture(from: trailShape) ?? SKTexture()

        // Opaque enough to read against both dune shadows and the night sky.
        let border = SKShapeNode(rectOf: size, cornerRadius: 3)
        border.fillColor = SKColor(red: 0.65, green: 0.96, blue: 0.55, alpha: 0.34)
        border.strokeColor = SKColor(red: 0.65, green: 0.96, blue: 0.55, alpha: 0.8)
        border.lineWidth = 1
        borderTexture = view?.texture(from: border) ?? SKTexture()
    }

    func updateLabels() {
        // UI is handled by SwiftUI overlay
    }
    // MARK: - Lifecycle

    func playSound(_ type: SoundType) {
        // AI Generated Custom Sounds
        SoundManager.shared.play(type)
    }

    override func didMove(to view: SKView) {
        // Koordinat sistemi sol alt (0,0) olsun
        self.anchorPoint = CGPoint(x: 0, y: 0)
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        // Edge tiles vanish when SpriteKit culls nodes that touch the view bounds.
        view.shouldCullNonVisibleNodes = false
        view.isAsynchronous = false

        startLevel()
        setupGestures(view: view)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard tileMap != nil,
            abs(size.width - oldSize.width) > 0.5 || abs(size.height - oldSize.height) > 0.5
        else { return }

        // resizeFill keeps scene coordinates equal to SpriteView coordinates.
        // Rebuild after layout changes so the logical and visible borders stay aligned.
        startLevel()
    }

    // MARK: - Level Setup

    func resetGame() {
        isEating = false
        GameManager.shared.reset()
        lives = 3
    }

    func startLevel() {
        // Crash Önleme: View hazır değilse devam etme
        guard view != nil, size.width > 1, size.height > 1 else { return }

        removeAllChildren()

        // SwiftUI renders the selected arena beneath the transparent scene.
        backgroundColor = .clear

        // ContentView explicitly keeps scene.size equal to the clipped arena.
        // SKView.bounds can report the hosting view's full-screen height here,
        // which places horizontal gameplay boundaries outside the arena.
        let viewSize = size

        let targetShortAxisCells = 30
        let boardInset: CGFloat = 0
        let availableWidth = max(1, viewSize.width - boardInset * 2)
        let availableHeight = max(1, viewSize.height - boardInset * 2)

        // Keep cells square while filling both portrait and landscape arenas.
        // On wide iPad layouts the row count anchors the cell size; on portrait
        // layouts the column count does. This prevents a square map floating in
        // the middle of a wide arena.
        if availableWidth <= availableHeight {
            cols = targetShortAxisCells
            gridSize = availableWidth / CGFloat(cols)
            rows = max(targetShortAxisCells, Int(floor(availableHeight / gridSize)))
        } else {
            rows = targetShortAxisCells
            gridSize = availableHeight / CGFloat(rows)
            cols = max(targetShortAxisCells, Int(floor(availableWidth / gridSize)))
        }
        gridSize = min(
            availableWidth / CGFloat(cols),
            availableHeight / CGFloat(rows)
        )
        // Textures must be regenerated after calculating the current device's
        // cell size. Reusing the initial 25-point textures clips edge rows.
        setupTextures()

        grid = Array(repeating: Array(repeating: .empty, count: rows), count: cols)
        trailCellIndices.removeAll(keepingCapacity: true)
        activeTrailCorners.removeAll(keepingCapacity: true)
        hasHandledSwipeInput = false
        lastUpdateTime = 0

        // Outermost cells are the walkable walls; keep them on the arena edge
        // so the bug and snake sit against the visible frame.
        for inset in 0...Self.boundaryInset {
            for x in 0..<cols {
                grid[x][inset] = .border
                grid[x][rows - 1 - inset] = .border
            }
            for y in 0..<rows {
                grid[inset][y] = .border
                grid[cols - 1 - inset][y] = .border
            }
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

        tileMap.anchorPoint = .zero
        tileMap.position = .zero

        let mapWidth = CGFloat(cols) * gridSize
        let mapHeight = CGFloat(rows) * gridSize
        boardNode = SKNode()
        boardNode.position = CGPoint(
            x: boardInset + max(0, (availableWidth - mapWidth) / 2),
            y: boardInset + max(0, (availableHeight - mapHeight) / 2))
        addChild(boardNode)
        boardNode.addChild(tileMap)
        refreshTileMap()

        // --- Bug Setup (kullanıcının seçtiği animasyonlu karakter) ---
        bugNode = BugSkin.current.makeNode(gridSize: gridSize)
        bugNode.zPosition = 10

        // Start on the real, inset bottom gameplay wall.
        bugGridPos = (cols / 2, Self.boundaryInset)
        let bugX = CGFloat(bugGridPos.x) * gridSize + gridSize / 2
        let bugY = CGFloat(bugGridPos.y) * gridSize + gridSize / 2
        bugNode.position = CGPoint(x: bugX, y: bugY)
        bugNode = makeActorCarrier(bugNode)
        boardNode.addChild(bugNode)

        // Ağ efekti setup
        setupBugTrailEffect()

        // --- Trail Line Setup (Bix Challenge Style) ---
        activeTrailNode = SKShapeNode()
        activeTrailNode.strokeColor = SKColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0)  // Parlak mavi
        activeTrailNode.lineWidth = 3.0  // Kalın çizgi
        activeTrailNode.lineCap = .round
        activeTrailNode.lineJoin = .round
        activeTrailNode.zPosition = 5
        activeTrailNode.glowWidth = 2.0  // Glow effect
        activeTrailPath = CGMutablePath()
        boardNode.addChild(activeTrailNode)

        // --- Snake Setup ---
        setupSnake()

        // UI
        // UI
        // UI is now handled by SwiftUI via GameManager state

        currentDirection = .none
        nextDirection = .none
        currentState = .ready

        GameManager.shared.percentCovered = 0.0
        GameManager.shared.lastCaptureAward = nil

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

        // Find valid spawn point - Snake'i sol üst köşeye yerleştir (böcekle çakışmasın)
        var spawnX = cols / 4  // Sol taraf
        var spawnY = (rows * 3) / 4  // Üst taraf

        // If center is blocked (Filled/Border/Trail) OR Too Close to Bug, search spiral
        let initialDist = abs(spawnX - bugGridPos.x) + abs(spawnY - bugGridPos.y)
        if grid[spawnX][spawnY] != .empty || initialDist < 8 {
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
                            // Check empty AND distance from bug
                            let distToBug = abs(nx - bugGridPos.x) + abs(ny - bugGridPos.y)
                            if grid[nx][ny] == .empty && distToBug > 5 {
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

        // Final Safety Check: If spawn is ON TOP of bug, move it
        if spawnX == bugGridPos.x && spawnY == bugGridPos.y {
            spawnX = (spawnX + 10) % (cols - 1)
            spawnY = (spawnY + 10) % (rows - 1)
        }

        let centerX = CGFloat(spawnX) * gridSize + gridSize / 2
        let centerY = CGFloat(spawnY) * gridSize + gridSize / 2
        snakePosition = CGPoint(x: centerX, y: centerY)

        // Kullanıcının seçtiği yılan görünümü
        let snakeSkin = SnakeSkin.current

        // Create Body Segments
        for _ in 0..<snakeBodyCount {
            var seg = snakeSkin.makeBodySegment(gridSize: gridSize)
            seg.zPosition = 8
            seg.position = snakePosition
            seg = makeActorCarrier(seg)
            boardNode.addChild(seg)
            snakeBody.append(seg)
        }

        // Create Head (animasyonlu — dil çıkarma)
        snakeNode = snakeSkin.makeHead(gridSize: gridSize)
        snakeNode.zPosition = 9
        snakeNode.position = snakePosition

        // Random Initial Direction
        let randomStartAngle = CGFloat.random(in: 0...(2 * .pi))
        timeSinceLastSnakeTurn = 0
        nextSnakeTurnTime = LevelRules.snakeTurnInterval(for: GameManager.shared.level)
        let currentLevelSpeed = currentLevelSnakeSpeed

        snakeVelocity = CGVector(
            dx: cos(randomStartAngle) * currentLevelSpeed,
            dy: sin(randomStartAngle) * currentLevelSpeed)
        snakeNode = makeActorCarrier(snakeNode)
        boardNode.addChild(snakeNode)

        snakeHistory.append(snakePosition)
    }

    // MARK: - Game Loop & Logic

    override func didFinishUpdate() {
        updateActorPresentation()
    }

    override func update(_ currentTime: TimeInterval) {
        // Sync Helper: If manager says playing but we are ready, start!
        if GameManager.shared.isPlaying && currentState == .ready {
            currentState = .playing
        }

        if isEating { return }

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
        guard currentState == .playing, !isEating else { return }
        moveSnake(dt: safeDt)
        guard currentState == .playing, !isEating else { return }

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
                if grid[bugGridPos.x][bugGridPos.y] == .trail,
                    activeTrailCorners.last != bugNode.position
                {
                    activeTrailCorners.append(bugNode.position)
                }
                currentDirection = nextDirection
                nextDirection = .none

                let rotateAction = SKAction.rotate(
                    toAngle: currentDirection.angle, duration: 0.05, shortestUnitArc: true)  // Bix Challenge tarzı hızlı dönüş
                bugNode.run(rotateAction)
            } else {
                // U-turn engellendiğinde nextDirection'ı temizle
                // böylece yeni input alınabilir
                nextDirection = .none
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

        let distance = bugSpeed * speedScale * dt
        let currentPos = bugNode.position
        var nextPos = CGPoint(x: currentPos.x + dx * distance, y: currentPos.y + dy * distance)

        // 3. Kesin Sınırlandırma (Hard Clamp)
        // Harita sınırlarını al
        // Güvenlik: Grid boyutu ile Sahne boyutu arasından küçük olanı seç
        // Böylece grid taşsa bile sahne dışına çıkamaz, sahne küçükse grid dışına çıkamaz.
        let mapWidth = min(CGFloat(cols) * gridSize, size.width)
        let mapHeight = min(CGFloat(rows) * gridSize, size.height)
        let radius = gridSize / 2  // Karakter yarıçapı

        // Önce hareket ettir
        var finalPos = nextPos

        // Sonra sınırların içine zorla (Asla dışarı çıkamaz)
        // Hangi duvara çarptığını takip et
        var hitLeft = false
        var hitRight = false
        var hitBottom = false
        var hitTop = false
        
        let boundaryInset = CGFloat(Self.boundaryInset) * gridSize

        if finalPos.x < boundaryInset + radius {
            finalPos.x = boundaryInset + radius
            hitLeft = true
        }
        if finalPos.y < boundaryInset + radius {
            finalPos.y = boundaryInset + radius
            hitBottom = true
        }

        if finalPos.x > mapWidth - boundaryInset - radius {
            finalPos.x = mapWidth - boundaryInset - radius
            hitRight = true
        }
        if finalPos.y > mapHeight - boundaryInset - radius {
            finalPos.y = mapHeight - boundaryInset - radius
            hitTop = true
        }

        let hitMovementBoundary =
            (hitLeft && currentDirection == .left)
            || (hitRight && currentDirection == .right)
            || (hitBottom && currentDirection == .down)
            || (hitTop && currentDirection == .up)

        // Pozisyonu güncelle
        bugNode.position = finalPos

        // 4. Logic Update
        let logicX = Int(bugNode.position.x / gridSize)
        let logicY = Int(bugNode.position.y / gridSize)

        // Ekstra Güvenlik: Eğer logic grid dışına çıkarsa düzelt
        // Logic değerleri cols/rows ile sınırlı olmalı
        let safeLogicX = max(
            Self.boundaryInset,
            min(cols - 1 - Self.boundaryInset, logicX)
        )
        let safeLogicY = max(
            Self.boundaryInset,
            min(rows - 1 - Self.boundaryInset, logicY)
        )

        if safeLogicX != logicX || safeLogicY != logicY {
            // Logic koordinatları fiziksel koordinatlara uymuyorsa (floating point hatası vs)
            // handleGridTransition güvenli değerlerle çağrılacak.
        }

        let targetGridPosition = (x: safeLogicX, y: safeLogicY)
        for cell in traversedGridCells(from: bugGridPos, to: targetGridPosition) {
            handleGridTransition(newX: cell.x, newY: cell.y)
            if currentState != .playing { break }
        }

        if hitMovementBoundary {
            currentDirection = .none
            nextDirection = .none
        }

        // 5. Update Visual Trail
        if grid[bugGridPos.x][bugGridPos.y] == .trail {
            if activeTrailCorners.isEmpty {
                activeTrailCorners.append(currentPos)
            }
            let path = CGMutablePath()
            path.move(to: activeTrailCorners[0])
            for corner in activeTrailCorners.dropFirst() {
                path.addLine(to: corner)
            }
            path.addLine(to: finalPos)
            activeTrailPath = path
            activeTrailNode.path = activeTrailPath

            // Ağ efektini aktif et
            updateBugTrailEmission(isActive: true)
        } else {
            // Not in trail mode (e.g. safe zone), clear path or keep it?
            // If we just entered safe zone, 'handleGridTransition' should have triggered fillArea
            if !activeTrailPath.isEmpty && grid[bugGridPos.x][bugGridPos.y] != .trail {
                activeTrailPath = CGMutablePath()
                activeTrailCorners.removeAll(keepingCapacity: true)
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
                activeTrailCorners.removeAll(keepingCapacity: true)
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
            // Check if we are starting a new trail from a safe zone
            let currentCell = grid[bugGridPos.x][bugGridPos.y]
            if currentCell == .filled || currentCell == .border {
                trailStartGridPos = bugGridPos
            } else if trailStartGridPos == (0, 0) {
                // Fallback if somehow undefined
                trailStartGridPos = bugGridPos
            }

            // Mark new cell
            grid[newX][newY] = .trail
            trailCellIndices.insert(newX * rows + newY)
            // We DO NOT update visual tile here to avoid "blocks" appearing.
            // But we MUST enable logic for enemies.
            // Optional: Show faint grid trail? NO, user wants to remove square logic.
            // We rely on SKShapeNode for visuals.

            bugGridPos = (newX, newY)
        }
    }

    func traversedGridCells(
        from start: (x: Int, y: Int),
        to end: (x: Int, y: Int)
    ) -> [(x: Int, y: Int)] {
        guard start != end else { return [] }

        var cells: [(x: Int, y: Int)] = []
        var current = start
        let horizontalStep = end.x == start.x ? 0 : (end.x > start.x ? 1 : -1)
        let verticalStep = end.y == start.y ? 0 : (end.y > start.y ? 1 : -1)

        while current.x != end.x {
            current.x += horizontalStep
            cells.append(current)
        }
        while current.y != end.y {
            current.y += verticalStep
            cells.append(current)
        }
        return cells
    }

    // Legacy mapping (kept for reference or if we need to snap)
    func updateBugPosition() {
        // Now handled continuously by updates
    }

    func moveSnake(dt: CGFloat) {
        let movementDistance = hypot(snakeVelocity.dx, snakeVelocity.dy) * dt
        let maxStepDistance = max(1, gridSize * 0.35)
        if movementDistance > maxStepDistance {
            let stepCount = Int(ceil(movementDistance / maxStepDistance))
            let stepDuration = dt / CGFloat(stepCount)
            for _ in 0..<stepCount {
                moveSnake(dt: stepDuration)
                if currentState != .playing || isEating { return }
            }
            return
        }

        // Random Turn Logic
        timeSinceLastSnakeTurn += TimeInterval(dt)
        if timeSinceLastSnakeTurn >= nextSnakeTurnTime {
            timeSinceLastSnakeTurn = 0
            nextSnakeTurnTime = LevelRules.snakeTurnInterval(for: GameManager.shared.level)

            // Randomly rotate velocity vector
            // Turn between -60 and +60 degrees to maintain forward moment but erratic path
            let currentAngle = atan2(snakeVelocity.dy, snakeVelocity.dx)
            let change = CGFloat.random(in: -CGFloat.pi / 3...CGFloat.pi / 3)
            let newAngle = currentAngle + change
            let currentLevelSpeed = currentLevelSnakeSpeed

            snakeVelocity = CGVector(
                dx: cos(newAngle) * currentLevelSpeed, dy: sin(newAngle) * currentLevelSpeed)
        }

        let dx = snakeVelocity.dx * dt
        let dy = snakeVelocity.dy * dt
        let nextPos = CGPoint(x: snakePosition.x + dx, y: snakePosition.y + dy)

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
        updateSnakeBodyAlongPath()

        // --- Improved Collision Detection ---
        // Calculate distance between centers
        let dist = hypot(
            snakeNode.position.x - bugNode.position.x, snakeNode.position.y - bugNode.position.y)

        // Check collision HEAD
        // PIXEL PERFECT Kontrol (Kullanıcı: "Hiç mesafe olmasın")
        // Grid Size 25. Head ~75. Bug ~100.
        // 15.0 değeri, merkezlerin neredeyse üst üste gelmesini gerektirir.
        if dist < 15.0 {
            triggerDeathSequence()
            return
        }

        // Check collision BODY (Tail checks)
        // Kuyruk için de tam merkez kontrolü
        for segment in snakeBody {
            let bodyDist = hypot(
                segment.position.x - bugNode.position.x, segment.position.y - bugNode.position.y)

            // 10.0 değeri - tam isabet.
            if bodyDist < 10.0 {
                triggerDeathSequence()
                return
            }
        }
    }

    private func updateSnakeBodyAlongPath() {
        if snakeHistory.first != snakePosition {
            snakeHistory.insert(snakePosition, at: 0)
        }

        let requiredDistance = snakeSegmentSpacing * CGFloat(snakeBody.count + 1)
        trimSnakeHistory(to: requiredDistance)

        for (index, segment) in snakeBody.enumerated() {
            let targetDistance = snakeSegmentSpacing * CGFloat(index + 1)
            let sample = snakeHistorySample(at: targetDistance)
            segment.position = sample.position
            if hypot(sample.direction.dx, sample.direction.dy) > 0.001 {
                segment.zRotation = atan2(sample.direction.dy, sample.direction.dx)
                    - CGFloat.pi / 2
            }
        }
    }

    private func snakeHistorySample(
        at targetDistance: CGFloat
    ) -> (position: CGPoint, direction: CGVector) {
        guard let first = snakeHistory.first else {
            return (snakePosition, snakeVelocity)
        }
        guard snakeHistory.count > 1 else {
            return (first, snakeVelocity)
        }

        var traversedDistance: CGFloat = 0
        for index in 0..<(snakeHistory.count - 1) {
            let newerPoint = snakeHistory[index]
            let olderPoint = snakeHistory[index + 1]
            let dx = olderPoint.x - newerPoint.x
            let dy = olderPoint.y - newerPoint.y
            let pathLength = hypot(dx, dy)
            guard pathLength > 0.001 else { continue }

            if traversedDistance + pathLength >= targetDistance {
                let amount = (targetDistance - traversedDistance) / pathLength
                return (
                    CGPoint(
                        x: newerPoint.x + dx * amount,
                        y: newerPoint.y + dy * amount),
                    CGVector(dx: -dx, dy: -dy))
            }
            traversedDistance += pathLength
        }

        let lastPoint = snakeHistory[snakeHistory.count - 1]
        let previousPoint = snakeHistory[snakeHistory.count - 2]
        return (
            lastPoint,
            CGVector(
                dx: previousPoint.x - lastPoint.x,
                dy: previousPoint.y - lastPoint.y))
    }

    private func trimSnakeHistory(to requiredDistance: CGFloat) {
        guard snakeHistory.count > 2 else { return }

        var traversedDistance: CGFloat = 0
        for index in 0..<(snakeHistory.count - 1) {
            traversedDistance += hypot(
                snakeHistory[index + 1].x - snakeHistory[index].x,
                snakeHistory[index + 1].y - snakeHistory[index].y)
            if traversedDistance >= requiredDistance {
                let keepCount = index + 2
                if snakeHistory.count > keepCount {
                    snakeHistory.removeLast(snakeHistory.count - keepCount)
                }
                return
            }
        }
    }

    private func activeSnakePathPoints() -> [CGPoint] {
        var points = [snakePosition] + snakeBody.map(\.position)
        guard snakeBody.count > 0, snakeHistory.count > 1 else { return points }

        let occupiedDistance = snakeSegmentSpacing * CGFloat(snakeBody.count)
        var traversedDistance: CGFloat = 0
        points.append(snakeHistory[0])

        for index in 0..<(snakeHistory.count - 1) {
            let start = snakeHistory[index]
            let end = snakeHistory[index + 1]
            let dx = end.x - start.x
            let dy = end.y - start.y
            let segmentDistance = hypot(dx, dy)
            guard segmentDistance > 0.001 else { continue }

            if traversedDistance + segmentDistance <= occupiedDistance {
                points.append(end)
                traversedDistance += segmentDistance
                continue
            }

            let remainingDistance = max(0, occupiedDistance - traversedDistance)
            let amount = remainingDistance / segmentDistance
            points.append(
                CGPoint(
                    x: start.x + dx * amount,
                    y: start.y + dy * amount))
            break
        }
        return points
    }

    func fillArea() {
        guard !trailCellIndices.isEmpty else { return }

        var visited = Array(repeating: Array(repeating: false, count: rows), count: cols)
        var queue: [(Int, Int)] = []

        // Only seed cells actually occupied from the head through the final
        // body segment. Older history points are behind the visible snake.
        var snakeSeedCells = Set<Int>()
        for point in activeSnakePathPoints() {
            let x = max(0, min(cols - 1, Int(point.x / gridSize)))
            let y = max(0, min(rows - 1, Int(point.y / gridSize)))
            let index = x * rows + y
            if grid[x][y] == .empty {
                snakeSeedCells.insert(index)
            }
        }

        if snakeSeedCells.isEmpty {
            print("Critical: No reachable area found around the snake.")
            return
        }

        for index in snakeSeedCells {
            let x = index / rows
            let y = index % rows
            queue.append((x, y))
            visited[x][y] = true
        }

        var queueIndex = 0
        while queueIndex < queue.count {
            let (cx, cy) = queue[queueIndex]
            queueIndex += 1
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
        var newlyFilled = 0
        let playableColumns = cols - (Self.boundaryInset + 1) * 2
        let playableRows = rows - (Self.boundaryInset + 1) * 2
        let totalCells = playableColumns * playableRows

        for x in 0..<cols {
            for y in 0..<rows {
                let index = x * rows + y
                if trailCellIndices.contains(index) {
                    grid[x][y] = .filled
                    newlyFilled += 1
                } else if grid[x][y] == .empty && !visited[x][y] {
                    grid[x][y] = .filled
                    newlyFilled += 1
                }

                // Only count visible filled cells for score
                // i.e. not the outer borders we added
                if grid[x][y] == .filled {
                    // exclude outer padding from stats
                    if x > Self.boundaryInset
                        && x < cols - 1 - Self.boundaryInset
                        && y > Self.boundaryInset
                        && y < rows - 1 - Self.boundaryInset
                    {
                        filledCount += 1
                    }
                }
            }
        }

        trailCellIndices.removeAll(keepingCapacity: true)

        refreshTileMap()
        let pct = Float(filledCount) / Float(totalCells) * 100.0
        let previousPercent = GameManager.shared.percentCovered

        // Puan yalnızca bu hamlede YENİ kapatılan hücreler için verilir;
        // seviye çarpanı, büyük alan ve hedef-üstü bonus GameManager.awardCapture içinde.
        DispatchQueue.main.async {
            GameManager.shared.percentCovered = pct
            GameManager.shared.awardCapture(
                cells: newlyFilled,
                previousPercent: previousPercent,
                newPercent: pct,
                totalPlayable: totalCells
            )
        }
        playSound(.score)  // Score/Confirm
    }

    func triggerDeathSequence() {
        if isEating { return }
        isEating = true

        // Play crash/eat sound immediately
        playSound(.crash)

        // Animation Sequence
        // 1. Move Head to Bug (Snap)
        let moveAction = SKAction.move(to: bugNode.position, duration: 0.2)
        moveAction.timingMode = .easeOut

        // 2. Crunch Animation (Scale Up/Down)
        let scaleUp = SKAction.scale(to: 1.5, duration: 0.15)
        let scaleDown = SKAction.scale(to: 0.8, duration: 0.15)
        let crunch = SKAction.sequence([scaleUp, scaleDown, scaleUp, scaleDown])

        // 3. Bug Reacts (Shake/Shrink - pretending to be eaten/fighting)
        let shakeLeft = SKAction.moveBy(x: -8, y: 0, duration: 0.05)
        let shakeRight = SKAction.moveBy(x: 8, y: 0, duration: 0.05)
        let shakeSeq = SKAction.repeat(SKAction.sequence([shakeLeft, shakeRight]), count: 10)
        let shrink = SKAction.scale(to: 0.01, duration: 1.0)
        let bugAction = SKAction.sequence([shakeSeq, shrink])

        snakeNode.run(SKAction.sequence([moveAction, crunch]))
        bugNode.run(bugAction)

        // 4. Wait 2-3 seconds then Die
        let wait = SKAction.wait(forDuration: 2.5)
        self.run(wait) { [weak self] in
            // Bug scale reset is handled in resetPositions
            self?.isEating = false
            self?.die()
        }
    }

    func die() {
        // playSound(.crash) // Moved to triggerDeathSequence for immediate feedback
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
            restoreAfterLifeLost()
            currentState = .ready

            DispatchQueue.main.async {
                GameManager.shared.isPlaying = false
            }
        }
    }

    /// Watch-ad extra life: leave claimed area, return to last safe cell, resume.
    func reviveAfterAd() {
        lives = max(1, GameManager.shared.lives)
        restoreAfterLifeLost()
        currentState = .playing
        lastUpdateTime = 0
    }

    private func restoreAfterLifeLost() {
        isEating = false
        removeAllActions()
        bugNode?.removeAllActions()
        snakeNode?.removeAllActions()
        snakeBody.forEach { $0.removeAllActions() }

        for x in 0..<cols {
            for y in 0..<rows {
                if grid[x][y] == .trail { grid[x][y] = .empty }
            }
        }
        trailCellIndices.removeAll(keepingCapacity: true)
        resetPositions()
        refreshTileMap()
        currentDirection = .none
        nextDirection = .none
    }

    func resetPositions() {
        // Bug position reset - ÖLDÜĞÜ YERİN BAŞLANGICINDAN BAŞLA (Kullanıcı İsteği)
        // Eğer trailStartGridPos geçerliyse oraya dön (En son güvenli nokta)
        if trailStartGridPos.x != 0 || trailStartGridPos.y != 0 {
            bugGridPos = trailStartGridPos
        }

        // Eğer bugGridPos hiç set edilmemişse (nadiren), merkeze al.
        if bugGridPos.x == 0 && bugGridPos.y == 0 {
            bugGridPos = (cols / 2, Self.boundaryInset)
        }

        // Snap to grid (Görseli logic'e oturt)
        let x = CGFloat(bugGridPos.x) * gridSize + gridSize / 2
        let y = CGFloat(bugGridPos.y) * gridSize + gridSize / 2
        bugNode.position = CGPoint(x: x, y: y)

        currentDirection = .none
        nextDirection = .none

        // Reset Trail
        activeTrailPath = CGMutablePath()
        activeTrailCorners.removeAll(keepingCapacity: true)
        activeTrailNode.path = nil

        // Clear web trail
        clearWebTrail()

        // Reset rotation
        bugNode.zRotation = 0
        bugNode.setScale(1.0)

        // Re-setup snake fully to reset body history and positions
        setupSnake()
    }

    func togglePause() {
        if currentState == .playing {
            currentState = .paused
            GameManager.shared.isPaused = true
        } else if currentState == .paused {
            currentState = .playing
            GameManager.shared.isPaused = false
            lastUpdateTime = 0
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
        let visualType: CellType =
            type == .trail || type == .border ? .empty : type
        if visualType.rawValue < tileMap.tileSet.tileGroups.count {
            tileMap.setTileGroup(
                tileMap.tileSet.tileGroups[visualType.rawValue], forColumn: x, row: y)
        }
    }
}
