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
            let secondBugNode,
            bugNode != nil,
            snakeNode != nil
        else { return }

        // Grid ayrı RTDB kanalından gelebilir ve motion ile aynı sequence'i
        // taşıyabilir. Önce grid'i uygula, sonra eski motion paketini ele.
        if snapshot.gridRevision != lastAppliedGridRevision {
            applyRemoteGrid(snapshot)
            lastAppliedGridRevision = snapshot.gridRevision
        }

        guard snapshot.sequence > lastAppliedSequence else { return }

        if snapshot.level != GameManager.shared.level {
            GameManager.shared.level = snapshot.level
            startLevel()
            return
        }

        let shouldSnapToTargets = !hasRemoteTargets
        lastAppliedSequence = snapshot.sequence
        lastSnapshotArrivalTime = CACurrentMediaTime()

        remoteHostTarget = denormalizedPosition(x: snapshot.hostX, y: snapshot.hostY)
        remoteGuestTarget = denormalizedPosition(x: snapshot.guestX, y: snapshot.guestY)
        let authoritativeSnakePosition = denormalizedPosition(
            x: snapshot.snakeX, y: snapshot.snakeY)
        let authoritativeSnakeBodyPositions = snapshot.snakeBody.map {
            denormalizedPosition(x: Double($0.x), y: Double($0.y))
        }

        if !shouldSnapToTargets {
            remoteSnakeVelocity = normalizedSnakeVelocity(
                from: lastAuthoritativeSnakePosition,
                to: authoritativeSnakePosition)
            if lastAuthoritativeSnakeBodyPositions.count
                == authoritativeSnakeBodyPositions.count
            {
                remoteSnakeBodyVelocities = zip(
                    lastAuthoritativeSnakeBodyPositions,
                    authoritativeSnakeBodyPositions
                ).map { normalizedSnakeVelocity(from: $0.0, to: $0.1) }
            } else {
                remoteSnakeBodyVelocities = Array(
                    repeating: .zero, count: authoritativeSnakeBodyPositions.count)
            }
        } else {
            remoteSnakeVelocity = .zero
            remoteSnakeBodyVelocities = Array(
                repeating: .zero, count: authoritativeSnakeBodyPositions.count)
        }

        lastAuthoritativeSnakePosition = authoritativeSnakePosition
        lastAuthoritativeSnakeBodyPositions = authoritativeSnakeBodyPositions
        remoteSnakeTarget = authoritativeSnakePosition
        remoteSnakeBodyTargets = authoritativeSnakeBodyPositions
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

        currentState = snapshot.gameState
        lives = snapshot.lives
        GameManager.shared.applyMultiplayerSnapshot(snapshot)
    }

    func interpolateRemoteEntities(dt: CGFloat) {
        guard hasRemoteTargets, let secondBugNode else { return }

        let snapshotAge = CACurrentMediaTime() - lastSnapshotArrivalTime
        let canExtrapolateRemoteEntities = currentState == .playing && snapshotAge < 0.2
        let canExtrapolateLocalGuest = currentState == .playing

        if canExtrapolateRemoteEntities {
            remoteHostTarget = advancedTarget(
                remoteHostTarget, direction: currentDirection, dt: dt)
            remoteSnakeTarget = clampedToMap(
                CGPoint(
                    x: remoteSnakeTarget.x + remoteSnakeVelocity.dx * dt,
                    y: remoteSnakeTarget.y + remoteSnakeVelocity.dy * dt))
            for index in remoteSnakeBodyTargets.indices
            where index < remoteSnakeBodyVelocities.count {
                let target = remoteSnakeBodyTargets[index]
                let velocity = remoteSnakeBodyVelocities[index]
                remoteSnakeBodyTargets[index] = clampedToMap(
                    CGPoint(
                        x: target.x + velocity.dx * dt,
                        y: target.y + velocity.dy * dt))
            }
        }
        if canExtrapolateLocalGuest {
            remoteGuestTarget = advancedTarget(
                remoteGuestTarget, direction: secondCurrentDirection, dt: dt)
        }

        bugNode.position = predictedBugPosition(
            from: bugNode.position,
            authoritativeTarget: remoteHostTarget,
            direction: currentDirection,
            shouldAdvance: canExtrapolateRemoteEntities,
            dt: dt)
        secondBugNode.position = predictedLocalGuestPosition(
            from: secondBugNode.position,
            authoritativeTarget: remoteGuestTarget,
            direction: secondCurrentDirection,
            shouldAdvance: canExtrapolateLocalGuest,
            dt: dt)
        snakeNode.position = predictedSnakePosition(
            from: snakeNode.position,
            authoritativeTarget: remoteSnakeTarget,
            velocity: remoteSnakeVelocity,
            shouldAdvance: canExtrapolateRemoteEntities,
            dt: dt)
        snakePosition = snakeNode.position

        for index in snakeBody.indices where index < remoteSnakeBodyTargets.count {
            let velocity = index < remoteSnakeBodyVelocities.count
                ? remoteSnakeBodyVelocities[index] : .zero
            snakeBody[index].position = predictedSnakePosition(
                from: snakeBody[index].position,
                authoritativeTarget: remoteSnakeBodyTargets[index],
                velocity: velocity,
                shouldAdvance: canExtrapolateRemoteEntities,
                dt: dt)
        }
        updateRemoteSnakeRotations()
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
        secondBugNode.zRotation = direction.angle
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

    private func predictedBugPosition(
        from position: CGPoint,
        authoritativeTarget: CGPoint,
        direction: Direction,
        shouldAdvance: Bool,
        dt: CGFloat
    ) -> CGPoint {
        let predictedPosition = shouldAdvance
            ? advancedTarget(position, direction: direction, dt: dt)
            : position
        let errorX = authoritativeTarget.x - predictedPosition.x
        let errorY = authoritativeTarget.y - predictedPosition.y
        let errorDistance = hypot(errorX, errorY)

        if errorDistance > gridSize * 8 {
            return authoritativeTarget
        }
        guard currentState != .playing || direction == .none || errorDistance > gridSize * 3
        else { return predictedPosition }

        return interpolated(
            from: predictedPosition,
            to: authoritativeTarget,
            amount: min(1, dt * 30))
    }

    private func predictedLocalGuestPosition(
        from position: CGPoint,
        authoritativeTarget: CGPoint,
        direction: Direction,
        shouldAdvance: Bool,
        dt: CGFloat
    ) -> CGPoint {
        let predictedPosition = shouldAdvance
            ? advancedTarget(position, direction: direction, dt: dt)
            : position

        guard currentState != .playing || direction == .none else {
            return predictedPosition
        }

        let errorDistance = hypot(
            authoritativeTarget.x - predictedPosition.x,
            authoritativeTarget.y - predictedPosition.y)
        if errorDistance > gridSize * 8 {
            return authoritativeTarget
        }
        return interpolated(
            from: predictedPosition,
            to: authoritativeTarget,
            amount: min(1, dt * 30))
    }

    private func normalizedSnakeVelocity(from start: CGPoint, to end: CGPoint) -> CGVector {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 0.001 else { return .zero }

        let levelMultiplier = 1 + CGFloat(GameManager.shared.level - 1) * 0.1
        let speed = snakeSpeed * levelMultiplier
        return CGVector(dx: dx / distance * speed, dy: dy / distance * speed)
    }

    private func predictedSnakePosition(
        from position: CGPoint,
        authoritativeTarget: CGPoint,
        velocity: CGVector,
        shouldAdvance: Bool,
        dt: CGFloat
    ) -> CGPoint {
        let predictedPosition = shouldAdvance
            ? clampedToMap(
                CGPoint(
                    x: position.x + velocity.dx * dt,
                    y: position.y + velocity.dy * dt))
            : position
        let errorDistance = hypot(
            authoritativeTarget.x - predictedPosition.x,
            authoritativeTarget.y - predictedPosition.y)

        if errorDistance > gridSize * 6 {
            return authoritativeTarget
        }
        guard errorDistance > gridSize * 1.5 else { return predictedPosition }

        return interpolated(
            from: predictedPosition,
            to: authoritativeTarget,
            amount: min(1, dt * 24))
    }

    private func updateRemoteSnakeRotations() {
        if hypot(remoteSnakeVelocity.dx, remoteSnakeVelocity.dy) > 0.001 {
            snakeNode.zRotation = atan2(remoteSnakeVelocity.dy, remoteSnakeVelocity.dx)
                - CGFloat.pi / 2
        }

        var leaderPosition = snakeNode.position
        for segment in snakeBody {
            let dx = leaderPosition.x - segment.position.x
            let dy = leaderPosition.y - segment.position.y
            if hypot(dx, dy) > 0.001 {
                segment.zRotation = atan2(dy, dx) - CGFloat.pi / 2
            }
            leaderPosition = segment.position
        }
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
        let nextFilledCells = Set(snapshot.filledCells)
        let nextTrailCells = Set(snapshot.trailCells)
        let changedCells = remoteFilledCells.symmetricDifference(nextFilledCells)
            .union(remoteTrailCells.symmetricDifference(nextTrailCells))

        remoteFilledCells = nextFilledCells
        remoteTrailCells = nextTrailCells

        for index in changedCells {
            let x = index / rows
            let y = index % rows
            guard x > 0, x < cols - 1, y > 0, y < rows - 1 else { continue }

            let newType: CellType
            if remoteFilledCells.contains(index) {
                newType = .filled
            } else if remoteTrailCells.contains(index) {
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