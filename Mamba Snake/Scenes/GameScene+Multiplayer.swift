import SpriteKit

extension GameScene {
    func setupSecondBug() {
        let node: SKSpriteNode
        if let animatedSpider = SKSpriteNode.createAnimatedSprite(
            gifNamed: "Spider",
            size: CGSize(width: gridSize * 5, height: gridSize * 5)
        ) {
            node = animatedSpider
        } else {
            node = SKSpriteNode(imageNamed: "Bug")
            node.size = CGSize(width: gridSize * 4, height: gridSize * 4)
        }

        node.zPosition = 10
        node.color = .orange
        node.colorBlendFactor = 0.35
        addPlayerMarker(to: node, color: .orange)

        secondBugGridPos = ((cols * 2) / 3, 0)
        secondTrailStartGridPos = secondBugGridPos
        node.position = CGPoint(
            x: CGFloat(secondBugGridPos.x) * gridSize + gridSize / 2,
            y: CGFloat(secondBugGridPos.y) * gridSize + gridSize / 2)
        tileMap.addChild(node)
        secondBugNode = node
        secondCurrentDirection = .none

        let trailNode = SKShapeNode()
        trailNode.strokeColor = .orange
        trailNode.lineWidth = 3
        trailNode.lineCap = .round
        trailNode.lineJoin = .round
        trailNode.glowWidth = 2
        trailNode.zPosition = 5
        tileMap.addChild(trailNode)
        secondActiveTrailNode = trailNode
        secondActiveTrailPath = CGMutablePath()
        secondActiveTrailCorners.removeAll(keepingCapacity: true)
    }

    func addPlayerMarker(to node: SKSpriteNode, color: SKColor) {
        let marker = SKShapeNode(circleOfRadius: gridSize * 2.15)
        marker.name = "playerMarker"
        marker.strokeColor = color
        marker.lineWidth = 2.5
        marker.glowWidth = 2
        marker.fillColor = .clear
        marker.zPosition = -1
        node.addChild(marker)
    }

    func moveSecondBug(dt: CGFloat) {
        guard let secondBugNode else { return }

        let requestedDirection = MultiplayerService.shared.remoteDirection
        if requestedDirection != .none && requestedDirection != secondCurrentDirection
            && !requestedDirection.isOpposite(of: secondCurrentDirection)
        {
            if grid[secondBugGridPos.x][secondBugGridPos.y] == .trail,
                secondActiveTrailCorners.last != secondBugNode.position
            {
                secondActiveTrailCorners.append(secondBugNode.position)
            }
            secondCurrentDirection = requestedDirection
            secondBugNode.run(
                SKAction.rotate(
                    toAngle: requestedDirection.angle,
                    duration: 0.05,
                    shortestUnitArc: true))
        }

        guard secondCurrentDirection != .none else { return }

        var offset = CGVector.zero
        switch secondCurrentDirection {
        case .up: offset.dy = 1
        case .down: offset.dy = -1
        case .left: offset.dx = -1
        case .right: offset.dx = 1
        case .none: return
        }

        let currentPosition = secondBugNode.position
        let distance = bugSpeed * dt
        var finalPosition = CGPoint(
            x: currentPosition.x + offset.dx * distance,
            y: currentPosition.y + offset.dy * distance)
        let radius = gridSize / 2
        let mapWidth = CGFloat(cols) * gridSize
        let mapHeight = CGFloat(rows) * gridSize

        let hitLeft = finalPosition.x < radius
        let hitRight = finalPosition.x > mapWidth - radius
        let hitBottom = finalPosition.y < radius
        let hitTop = finalPosition.y > mapHeight - radius
        finalPosition.x = max(radius, min(mapWidth - radius, finalPosition.x))
        finalPosition.y = max(radius, min(mapHeight - radius, finalPosition.y))

        if (hitLeft && secondCurrentDirection == .left)
            || (hitRight && secondCurrentDirection == .right)
            || (hitBottom && secondCurrentDirection == .down)
            || (hitTop && secondCurrentDirection == .up)
        {
            secondCurrentDirection = .none
        }

        secondBugNode.position = finalPosition
        let logicX = max(0, min(cols - 1, Int(finalPosition.x / gridSize)))
        let logicY = max(0, min(rows - 1, Int(finalPosition.y / gridSize)))

        if logicX != secondBugGridPos.x || logicY != secondBugGridPos.y {
            handleSecondBugGridTransition(newX: logicX, newY: logicY)
        }

        if grid[secondBugGridPos.x][secondBugGridPos.y] == .trail {
            if secondActiveTrailCorners.isEmpty {
                secondActiveTrailCorners.append(currentPosition)
            }
            let path = CGMutablePath()
            path.move(to: secondActiveTrailCorners[0])
            for corner in secondActiveTrailCorners.dropFirst() {
                path.addLine(to: corner)
            }
            path.addLine(to: finalPosition)
            secondActiveTrailPath = path
            secondActiveTrailNode?.path = secondActiveTrailPath
        } else if !secondActiveTrailPath.isEmpty {
            secondActiveTrailPath = CGMutablePath()
            secondActiveTrailCorners.removeAll(keepingCapacity: true)
            secondActiveTrailNode?.path = nil
        }
    }

    func handleSecondBugGridTransition(newX: Int, newY: Int) {
        guard newX >= 0, newX < cols, newY >= 0, newY < rows else { return }
        let targetCell = grid[newX][newY]

        if targetCell == .trail {
            die()
            return
        }

        if targetCell == .filled || targetCell == .border {
            let currentCell = grid[secondBugGridPos.x][secondBugGridPos.y]
            secondBugGridPos = (newX, newY)
            if currentCell == .trail {
                fillArea()
                secondActiveTrailPath = CGMutablePath()
                secondActiveTrailCorners.removeAll(keepingCapacity: true)
                secondActiveTrailNode?.path = nil
                secondCurrentDirection = .none
            }
            return
        }

        if targetCell == .empty {
            let currentCell = grid[secondBugGridPos.x][secondBugGridPos.y]
            if currentCell == .filled || currentCell == .border {
                secondTrailStartGridPos = secondBugGridPos
            }
            grid[newX][newY] = .trail
            multiplayerGridRevision += 1
            secondBugGridPos = (newX, newY)
        }
    }

    func resetSecondBugPosition() {
        guard let secondBugNode, GameManager.shared.isMultiplayer else { return }

        secondBugGridPos = secondTrailStartGridPos
        if secondBugGridPos == (0, 0) {
            secondBugGridPos = ((cols * 2) / 3, 0)
        }
        secondBugNode.position = CGPoint(
            x: CGFloat(secondBugGridPos.x) * gridSize + gridSize / 2,
            y: CGFloat(secondBugGridPos.y) * gridSize + gridSize / 2)
        secondBugNode.zRotation = 0
        secondBugNode.setScale(1)
        secondCurrentDirection = .none
        secondActiveTrailPath = CGMutablePath()
        secondActiveTrailCorners.removeAll(keepingCapacity: true)
        secondActiveTrailNode?.path = nil
    }

    func publishMultiplayerSnapshot(
        at currentTime: TimeInterval? = nil,
        force: Bool = false
    ) {
        guard GameManager.shared.isMultiplayer,
            MultiplayerService.shared.isHost,
            let secondBugNode,
            bugNode != nil,
            snakeNode != nil,
            gridSize > 0
        else { return }

        if isMultiplayerPublishInFlight {
            if force { hasPendingForcedMultiplayerPublish = true }
            return
        }

        let timestamp = currentTime ?? lastUpdateTime
        let publishInterval = FirebaseFeatureService.shared.multiplayerSnapshotInterval
        guard force || timestamp - lastMultiplayerPublishTime >= publishInterval else { return }
        lastMultiplayerPublishTime = timestamp
        isMultiplayerPublishInFlight = true
        multiplayerSequence += 1

        let shouldPublishGrid = multiplayerGridRevision != lastPublishedGridRevision
        let filledCells = shouldPublishGrid ? encodedCells(ofType: .filled) : nil
        let trailCells = shouldPublishGrid ? encodedCells(ofType: .trail) : nil

        let normalizedHostPosition = normalizedPosition(bugNode.position)
        let normalizedGuestPosition = normalizedPosition(secondBugNode.position)
        let normalizedSnakePosition = normalizedPosition(snakeNode.position)
        let normalizedBody = snakeBody.map { normalizedPosition($0.position) }
        let sequence = multiplayerSequence
        let gridRevision = multiplayerGridRevision
        let gameState = currentState

        Task {
            let didPublish = await MultiplayerService.shared.publish(
                sequence: sequence,
                gridRevision: gridRevision,
                hostPosition: normalizedHostPosition,
                hostDirection: currentDirection,
                guestPosition: normalizedGuestPosition,
                guestDirection: secondCurrentDirection,
                snakePosition: normalizedSnakePosition,
                snakeBodyPositions: normalizedBody,
                score: GameManager.shared.score,
                lives: lives,
                level: GameManager.shared.level,
                percentCovered: GameManager.shared.percentCovered,
                gameState: gameState,
                filledCells: filledCells,
                trailCells: trailCells)

            if didPublish && shouldPublishGrid {
                lastPublishedGridRevision = max(lastPublishedGridRevision, gridRevision)
            }

            isMultiplayerPublishInFlight = false
            if hasPendingForcedMultiplayerPublish {
                hasPendingForcedMultiplayerPublish = false
                publishMultiplayerSnapshot(force: true)
            }
        }
    }

    func applyLatestMultiplayerSnapshot() {
        guard let snapshot = MultiplayerService.shared.latestSnapshot,
            snapshot.sequence > lastAppliedSequence,
            let secondBugNode,
            bugNode != nil,
            snakeNode != nil
        else { return }

        if snapshot.level != GameManager.shared.level {
            GameManager.shared.level = snapshot.level
            startLevel()
            return
        }

        let shouldSnapToTargets = !hasRemoteTargets
        lastAppliedSequence = snapshot.sequence

        let previousSnakeTarget = remoteSnakeTarget
        let arrivalTime = CACurrentMediaTime()
        let elapsed = arrivalTime - lastSnapshotArrivalTime
        lastSnapshotArrivalTime = arrivalTime

        remoteHostTarget = denormalizedPosition(x: snapshot.hostX, y: snapshot.hostY)
        remoteGuestTarget = denormalizedPosition(x: snapshot.guestX, y: snapshot.guestY)
        remoteSnakeTarget = denormalizedPosition(x: snapshot.snakeX, y: snapshot.snakeY)
        remoteSnakeBodyTargets = snapshot.snakeBody.map {
            denormalizedPosition(x: Double($0.x), y: Double($0.y))
        }

        // Yılanın hızını ardışık snapshot'lardan tahmin et (dead reckoning için)
        if !shouldSnapToTargets, elapsed > 0.02, elapsed < 0.8 {
            remoteSnakeVelocity = CGVector(
                dx: (remoteSnakeTarget.x - previousSnakeTarget.x) / CGFloat(elapsed),
                dy: (remoteSnakeTarget.y - previousSnakeTarget.y) / CGFloat(elapsed))
        } else {
            remoteSnakeVelocity = .zero
        }
        hasRemoteTargets = true

        if shouldSnapToTargets {
            bugNode.position = remoteHostTarget
            secondBugNode.position = remoteGuestTarget
            snakeNode.position = remoteSnakeTarget
            for (segment, position) in zip(snakeBody, remoteSnakeBodyTargets) {
                segment.position = position
            }
        }
        snakePosition = remoteSnakeTarget

        bugNode.zRotation = snapshot.hostDirection.angle
        bugGridPos = gridPosition(x: snapshot.hostX, y: snapshot.hostY)
        secondBugGridPos = gridPosition(x: snapshot.guestX, y: snapshot.guestY)
        currentDirection = snapshot.hostDirection

        // Misafirin yerel yön tahmini: host aynı yönü onaylayana kadar (veya 1 sn
        // geçene kadar) yerel yönü koru; böylece dönüşler geri sekmez.
        if predictedGuestDirection != .none {
            if snapshot.guestDirection == predictedGuestDirection
                || CACurrentMediaTime() - predictedGuestDirectionTime > 1.0
            {
                predictedGuestDirection = .none
                secondCurrentDirection = snapshot.guestDirection
                secondBugNode.zRotation = snapshot.guestDirection.angle
            }
        } else {
            secondCurrentDirection = snapshot.guestDirection
            secondBugNode.zRotation = snapshot.guestDirection.angle
        }

        if snapshot.gridRevision != lastAppliedGridRevision {
            applyRemoteGrid(snapshot)
            lastAppliedGridRevision = snapshot.gridRevision
        }

        currentState = snapshot.gameState
        lives = snapshot.lives
        GameManager.shared.applyMultiplayerSnapshot(snapshot)
    }

    func interpolateRemoteEntities(dt: CGFloat) {
        guard hasRemoteTargets, let secondBugNode else { return }

        // Dead reckoning: hedefleri bilinen yön ve hızla her kare ilerlet.
        // Böylece hareket, yeni snapshot beklemeden gerçek oyun hızında akar.
        if currentState == .playing {
            remoteHostTarget = advancedTarget(
                remoteHostTarget, direction: currentDirection, dt: dt)
            remoteGuestTarget = advancedTarget(
                remoteGuestTarget, direction: secondCurrentDirection, dt: dt)
            remoteSnakeTarget = clampedToMap(
                CGPoint(
                    x: remoteSnakeTarget.x + remoteSnakeVelocity.dx * dt,
                    y: remoteSnakeTarget.y + remoteSnakeVelocity.dy * dt))
        }

        let blend = min(1, dt * 18)

        bugNode.position = interpolated(
            from: bugNode.position, to: remoteHostTarget, amount: blend)
        secondBugNode.position = interpolated(
            from: secondBugNode.position, to: remoteGuestTarget, amount: blend)
        snakeNode.position = interpolated(
            from: snakeNode.position, to: remoteSnakeTarget, amount: blend)
        snakePosition = snakeNode.position

        for (segment, target) in zip(snakeBody, remoteSnakeBodyTargets) {
            segment.position = interpolated(from: segment.position, to: target, amount: blend)
        }
    }

    /// Misafirin kendi böceğine anında tepki: yönü yerel olarak uygular,
    /// host onayı sürerken dead reckoning bu yönde ilerletir.
    func applyLocalGuestPrediction(_ direction: Direction) {
        guard direction != .none,
            let secondBugNode,
            direction != secondCurrentDirection,
            !direction.isOpposite(of: secondCurrentDirection)
        else { return }

        predictedGuestDirection = direction
        predictedGuestDirectionTime = CACurrentMediaTime()
        secondCurrentDirection = direction
        secondBugNode.run(
            SKAction.rotate(toAngle: direction.angle, duration: 0.05, shortestUnitArc: true))
    }

    private func advancedTarget(
        _ target: CGPoint, direction: Direction, dt: CGFloat
    ) -> CGPoint {
        var offset = CGVector.zero
        switch direction {
        case .up: offset.dy = 1
        case .down: offset.dy = -1
        case .left: offset.dx = -1
        case .right: offset.dx = 1
        case .none: return target
        }
        return clampedToMap(
            CGPoint(
                x: target.x + offset.dx * bugSpeed * dt,
                y: target.y + offset.dy * bugSpeed * dt))
    }

    private func clampedToMap(_ point: CGPoint) -> CGPoint {
        let radius = gridSize / 2
        let mapWidth = CGFloat(cols) * gridSize
        let mapHeight = CGFloat(rows) * gridSize
        return CGPoint(
            x: max(radius, min(mapWidth - radius, point.x)),
            y: max(radius, min(mapHeight - radius, point.y)))
    }

    private func interpolated(from start: CGPoint, to end: CGPoint, amount: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * amount,
            y: start.y + (end.y - start.y) * amount)
    }

    private func applyRemoteGrid(_ snapshot: MultiplayerGameSnapshot) {
        let filled = Set(snapshot.filledCells)
        let trails = Set(snapshot.trailCells)

        // Yalnızca DEĞİŞEN karoları güncelle: tüm haritayı (1890 karo) yeniden
        // çizmek misafir tarafındaki donmanın ana kaynağıydı.
        for x in 1..<(cols - 1) {
            for y in 1..<(rows - 1) {
                let index = x * rows + y
                let newType: CellType
                if filled.contains(index) {
                    newType = .filled
                } else if trails.contains(index) {
                    newType = .trail
                } else {
                    newType = .empty
                }
                if grid[x][y] != newType {
                    grid[x][y] = newType
                    updateSingleTile(x: x, y: y)
                }
            }
        }
    }

    private func encodedCells(ofType type: CellType) -> [Int] {
        var result: [Int] = []
        for x in 0..<cols {
            for y in 0..<rows where grid[x][y] == type {
                result.append(x * rows + y)
            }
        }
        return result
    }

    private func normalizedPosition(_ position: CGPoint) -> CGPoint {
        CGPoint(x: position.x / gridSize, y: position.y / gridSize)
    }

    private func denormalizedPosition(x: Double, y: Double) -> CGPoint {
        CGPoint(x: CGFloat(x) * gridSize, y: CGFloat(y) * gridSize)
    }

    private func gridPosition(x: Double, y: Double) -> (x: Int, y: Int) {
        (
            max(0, min(cols - 1, Int(x))),
            max(0, min(rows - 1, Int(y)))
        )
    }
}

extension Direction {
    func isOpposite(of direction: Direction) -> Bool {
        switch (self, direction) {
        case (.up, .down), (.down, .up), (.left, .right), (.right, .left):
            return true
        default:
            return false
        }
    }
}