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
    var bugSpeed: CGFloat = 200.0  // Bix Challenge tarzı hızlı hareket
    let snakeSpeed: CGFloat = 160.0

    // MARK: - Game State
    var grid: [[CellType]] = []
    var currentDirection: Direction = .none
    var nextDirection: Direction = .none
    var lastUpdateTime: TimeInterval = 0
    var currentState: GameState = .ready
    var isEating: Bool = false

    // MARK: - Nodes
    var tileMap: SKTileMapNode!
    var bugNode: SKSpriteNode!
    var snakeNode: SKSpriteNode!
    var activeTrailNode: SKShapeNode!
    var activeTrailPath: CGMutablePath!
    var bugTrailEmitter: SKEmitterNode!

    // Entities
    var bugGridPos: (x: Int, y: Int) = (0, 0)
    var trailStartGridPos: (x: Int, y: Int) = (0, 0)  // Track where the trail started
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

        // Border Cell
        // Border Cell - Garden Fence Design
        let fenceContainer = SKShapeNode(rectOf: size)
        fenceContainer.fillColor = .clear
        fenceContainer.strokeColor = .clear

        // Draw Fence Plank
        let plankPath = CGMutablePath()
        // Bottom part
        plankPath.move(to: CGPoint(x: -size.width / 2 + 2, y: -size.height / 2))
        plankPath.addLine(to: CGPoint(x: size.width / 2 - 2, y: -size.height / 2))
        // Sides
        plankPath.addLine(to: CGPoint(x: size.width / 2 - 2, y: size.height / 2 - 6))
        // Pointed Top
        plankPath.addLine(to: CGPoint(x: 0, y: size.height / 2))
        plankPath.addLine(to: CGPoint(x: -size.width / 2 + 2, y: size.height / 2 - 6))
        plankPath.closeSubpath()

        let fenceNode = SKShapeNode(path: plankPath)
        fenceNode.fillColor = SKColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1.0)  // Wood Brown
        fenceNode.strokeColor = SKColor(red: 0.35, green: 0.20, blue: 0.05, alpha: 1.0)  // Darker Brown Stroke
        fenceNode.lineWidth = 1.5

        // Wood grain details
        let detailPath = CGMutablePath()
        detailPath.move(to: CGPoint(x: 0, y: -size.height / 2 + 4))
        detailPath.addLine(to: CGPoint(x: 0, y: size.height / 2 - 10))

        let detailNode = SKShapeNode(path: detailPath)
        detailNode.strokeColor = SKColor(red: 0.45, green: 0.25, blue: 0.10, alpha: 0.5)
        detailNode.lineWidth = 1

        fenceContainer.addChild(fenceNode)
        fenceContainer.addChild(detailNode)

        borderTexture = view?.texture(from: fenceContainer) ?? SKTexture()
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

        setupTextures()
        startLevel()
        setupGestures(view: view)
    }

    // MARK: - Level Setup

    func resetGame() {
        isEating = false
        GameManager.shared.reset()
        lives = 3
    }

    func startLevel() {
        // Crash Önleme: View veya Texture'lar hazır değilse devam etme
        guard let view = view else { return }
        if emptyTexture == nil { setupTextures() }
        if emptyTexture == nil { return }

        removeAllChildren()

        // Set Background Image
        let bgNode = SKSpriteNode(imageNamed: "Background")
        // Anchor (0,0) olduğu için arka planı ekranın ortasına taşıyoruz
        bgNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bgNode.zPosition = -100

        // Scale to fit
        let ratio = max(self.size.width / bgNode.size.width, self.size.height / bgNode.size.height)
        bgNode.setScale(ratio)
        addChild(bgNode)

        // TileMap anchor point ayarı (önemli!)
        // TileMap varsayılan olarak (0.5, 0.5). Koordinat sistemimiz (0,0) olduğu için
        // TileMap'in de sol alttan başlamasını istiyorsak pozisyonunu ayarlamalıyız.
        // Veya TileMap'i logic olarak kullanıp visual olarak hücreleri tek tek ekliyorsak (ki öyle yapıyoruz: sprite node'lar yok, texture'lar tilemap içinde değil)

        // Kodu inceledim: tileMap = SKTileMapNode(...) oluşturuluyor ama grid logic array olarak kullanılıyor.
        // tileMap sadece snakeBody vs için parent.
        // Ama 150-158 satırlarında grid array'i dolduruluyor.
        // Görsel olarak borderlar nasıl çiziliyor?
        // startLevel içinde 'setupTextures' ile texturelar oluşturuluyor ama border node'larını ekleyen bir döngü GÖREMİYORUM.

        // AŞAĞIDA: createLevelObjects() veya benzeri bir yerde border node'ları eklenmeli.
        // Kodun devamında 'drawBorder()' gibi bir şey var mı?
        // Hayır, startLevel'ın sonunda bir döngü olmalı.

        // Oraya da bakıp düzeltmem gerekebilir ama önce Anchor Point'i düzeltem.

        // Calculate Visible Area based on ACTUAL scene size
        // Use the smaller of view size or scene size to be safe
        let availableWidth = size.width
        let availableHeight = size.height

        // Calculate Grid
        // We want gridSize to be roughly 20-30 pts depending on screen
        // Dynamic Grid Size Calculation
        // We want exactly 'targetVisibleCols' inside the screen.
        let targetVisibleCols: CGFloat = 30.0
        gridSize = availableWidth / targetVisibleCols

        let visibleCols = Int(targetVisibleCols)
        // HUD için üstten boşluk bırak (Daha az boşluk: 115pt - HUD'a yakın)
        let hudMargin: CGFloat = 85.0
        // iPhone Home Indicator için alttan boşluk bırak
        let safeAreaBottom: CGFloat = 20.0

        // availableHeight'ten hem üst hem alt boşluğu çıkar
        let visibleRows = Int(ceil((availableHeight - hudMargin - safeAreaBottom) / gridSize))

        // Ekrana tam sığmalı, dışarı taşmamalı
        cols = visibleCols
        rows = visibleRows

        grid = Array(repeating: Array(repeating: .empty, count: rows), count: cols)

        // Set Borders (Now these will be off-screen)
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

        let totalMapWidth = CGFloat(cols) * gridSize
        let totalMapHeight = CGFloat(rows) * gridSize

        tileMap.anchorPoint = .zero

        // TileMap'i safeAreaBottom kadar yukarı kaydır
        // Böylece en alt satır home indicator'ın üzerinde kalır
        tileMap.position = CGPoint(x: 0, y: safeAreaBottom)
        addChild(tileMap)
        refreshTileMap()

        // --- Bug Setup (Animated Spider) ---
        // GIF animasyonlu örümcek kullan
        if let animatedSpider = SKSpriteNode.createAnimatedSprite(
            gifNamed: "Spider",
            size: CGSize(width: gridSize * 5.0, height: gridSize * 5.0)  // Grid küçüldüğü için çarpanı büyüttük
        ) {
            bugNode = animatedSpider
        } else {
            // Fallback: GIF yüklenemezse eski bug kullan
            print("⚠️ Spider.gif yüklenemedi, fallback Bug.png kullanılıyor")
            bugNode = SKSpriteNode(imageNamed: "Bug")
            bugNode.size = CGSize(width: gridSize * 4.0, height: gridSize * 4.0)
        }

        bugNode.zPosition = 10

        // Böceği ekranın en altına, ortaya yerleştir (Bix Challenge tarzı)
        bugGridPos = (cols / 2, 0)  // En altta, ortada (border üzerinde)
        let bugX = CGFloat(bugGridPos.x) * gridSize + gridSize / 2
        let bugY = CGFloat(bugGridPos.y) * gridSize + gridSize / 2
        bugNode.position = CGPoint(x: bugX, y: bugY)
        tileMap.addChild(bugNode)

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

        // Create Body Segments
        for _ in 0..<snakeBodyCount {
            let seg = SKSpriteNode(imageNamed: "SnakeBody")
            seg.size = CGSize(width: gridSize * 2.5, height: gridSize * 2.5)  // Grid küçüldüğü için büyüttük
            seg.zPosition = 8
            seg.position = snakePosition
            tileMap.addChild(seg)
            snakeBody.append(seg)
        }

        // Create Head
        snakeNode = SKSpriteNode(imageNamed: "SnakeHead")
        snakeNode.size = CGSize(width: gridSize * 3.0, height: gridSize * 3.0)  // Grid küçüldüğü için büyütük
        snakeNode.zPosition = 9
        snakeNode.position = snakePosition

        // Random Initial Direction
        let randomStartAngle = CGFloat.random(in: 0...(2 * .pi))

        // Increase speed by 10% each level
        let levelMultiplier = 1.0 + (CGFloat(GameManager.shared.level - 1) * 0.1)
        let currentLevelSpeed = snakeSpeed * levelMultiplier

        snakeVelocity = CGVector(
            dx: cos(randomStartAngle) * currentLevelSpeed,
            dy: sin(randomStartAngle) * currentLevelSpeed)
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
        moveSnake(dt: 1.0 / 60.0)  // Keep snake simplified fixed step for internal physics consistency or sync with dt

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

        let distance = bugSpeed * dt
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
        
        // Sol ve Alt sınır (0 yerine radius kadar içeride durmalı)
        if finalPos.x < radius { finalPos.x = radius; hitLeft = true }
        if finalPos.y < radius { finalPos.y = radius; hitBottom = true }

        // Sağ ve Üst sınır (Width/Height yerine radius kadar içeride durmalı)
        if finalPos.x > mapWidth - radius { finalPos.x = mapWidth - radius; hitRight = true }
        if finalPos.y > mapHeight - radius { finalPos.y = mapHeight - radius; hitTop = true }

        // Duvara çarptıysa, sadece o yöne gidişi durdur (ters yöne veya dik yönlere gidebilsin)
        // currentDirection'ı .none yapmak yerine, sadece çarpılan yönü engelleyen bir blockedDirection tutuyoruz
        // Ama daha basit çözüm: Duvara çarptığında currentDirection'ı sıfırla ama nextDirection'ı da temizle
        if (hitLeft && currentDirection == .left) ||
           (hitRight && currentDirection == .right) ||
           (hitBottom && currentDirection == .down) ||
           (hitTop && currentDirection == .up) {
            currentDirection = .none
            nextDirection = .none  // Böylece yeni input bekler
        }

        // Pozisyonu güncelle
        bugNode.position = finalPos

        // 4. Logic Update
        let logicX = Int(bugNode.position.x / gridSize)
        let logicY = Int(bugNode.position.y / gridSize)

        // Ekstra Güvenlik: Eğer logic grid dışına çıkarsa düzelt
        // Logic değerleri cols/rows ile sınırlı olmalı
        let safeLogicX = max(0, min(cols - 1, logicX))
        let safeLogicY = max(0, min(rows - 1, logicY))

        if safeLogicX != logicX || safeLogicY != logicY {
            // Logic koordinatları fiziksel koordinatlara uymuyorsa (floating point hatası vs)
            // handleGridTransition güvenli değerlerle çağrılacak.
        }

        // Track Logic Changes
        if safeLogicX != bugGridPos.x || safeLogicY != bugGridPos.y {
            handleGridTransition(newX: safeLogicX, newY: safeLogicY)
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
        // Random Turn Logic
        timeSinceLastSnakeTurn += TimeInterval(dt)
        if timeSinceLastSnakeTurn >= nextSnakeTurnTime {
            timeSinceLastSnakeTurn = 0
            // Random interval between 0.5 and 2.5 seconds
            nextSnakeTurnTime = Double.random(in: 0.5...2.5)

            // Randomly rotate velocity vector
            // Turn between -60 and +60 degrees to maintain forward moment but erratic path
            let currentAngle = atan2(snakeVelocity.dy, snakeVelocity.dx)
            let change = CGFloat.random(in: -CGFloat.pi / 3...CGFloat.pi / 3)
            let newAngle = currentAngle + change

            // Recalculate speed based on level
            let levelMultiplier = 1.0 + (CGFloat(GameManager.shared.level - 1) * 0.1)
            let currentLevelSpeed = snakeSpeed * levelMultiplier

            snakeVelocity = CGVector(
                dx: cos(newAngle) * currentLevelSpeed, dy: sin(newAngle) * currentLevelSpeed)
        }

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

        snakeNode.position = snakePosition

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

    func fillArea() {
        let snakeGridX = Int(snakePosition.x / gridSize)
        let snakeGridY = Int(snakePosition.y / gridSize)

        var visited = Array(repeating: Array(repeating: false, count: rows), count: cols)
        var queue: [(Int, Int)] = []

        // Robust Start: Search for an empty cell around the snake
        // The snake might be slightly overlapping a border/trail visually,
        // but it must be centered in or near an empty valid play area.
        let searchRadius = 2
        var foundStart = false

        let centerX = max(0, min(cols - 1, snakeGridX))
        let centerY = max(0, min(rows - 1, snakeGridY))

        // Spiral search or simple nested loop for start point
        searchLoop: for r in 0...searchRadius {
            for dx in -r...r {
                for dy in -r...r {
                    let nx = centerX + dx
                    let ny = centerY + dy

                    if nx >= 0 && nx < cols && ny >= 0 && ny < rows {
                        if grid[nx][ny] == .empty {
                            queue.append((nx, ny))
                            visited[nx][ny] = true
                            foundStart = true
                            break searchLoop
                        }
                    }
                }
            }
        }

        if !foundStart {
            // Fallback: If snake is somehow completely entombed (should be impossible if alive),
            // do not fill anything to avoid destroying the game state.
            print("Critical: Snake Logic Error - No empty space found around snake.")
            return
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
        let totalCells = (cols - 4) * (rows - 4)  // Approx playable area count for percent logic
        // (Adjusted totalCells logic to be more accurate if needed, but keeping simple for now)
        // Actually total cells should be count of non-border cells?
        // Let's stick to simple count for now or fix visible area count.

        for x in 0..<cols {
            for y in 0..<rows {
                if grid[x][y] == .trail {
                    grid[x][y] = .filled
                } else if grid[x][y] == .empty && !visited[x][y] {
                    grid[x][y] = .filled
                }

                // Only count visible filled cells for score
                // i.e. not the outer borders we added
                if grid[x][y] == .filled {
                    // exclude outer padding from stats
                    if x > 0 && x < cols - 1 && y > 0 && y < rows - 1 {
                        filledCount += 1
                    }
                }
            }
        }

        refreshTileMap()
        let pct = Float(filledCount) / Float(totalCells) * 100.0

        // Her doldurulan hücre için puan ver (ne kadar çok alan tararsa o kadar çok puan)
        let earnedPoints = filledCount * 2
        
        DispatchQueue.main.async {
            GameManager.shared.percentCovered = pct
            GameManager.shared.score += earnedPoints
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
                GameManager.shared.isPlaying = false  // Paused for ready
                // Maybe show "Tap to Continue" overlay?
                // For now we just wait for tap logic in ContentView
            }
        }
    }

    func resetPositions() {
        // Bug position reset - ÖLDÜĞÜ YERİN BAŞLANGICINDAN BAŞLA (Kullanıcı İsteği)
        // Eğer trailStartGridPos geçerliyse oraya dön (En son güvenli nokta)
        if trailStartGridPos.x != 0 || trailStartGridPos.y != 0 {
            bugGridPos = trailStartGridPos
        }

        // Eğer bugGridPos hiç set edilmemişse (nadiren), merkeze al.
        if bugGridPos.x == 0 && bugGridPos.y == 0 {
            bugGridPos = (cols / 2, 0)
        }

        // Snap to grid (Görseli logic'e oturt)
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
        bugNode.setScale(1.0)

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
