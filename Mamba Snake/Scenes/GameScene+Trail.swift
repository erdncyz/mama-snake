//
//  GameScene+Trail.swift
//  Mamba Snake
//
//  Created by Erdinç Yılmaz on 10.01.2026.
//

import SpriteKit

extension GameScene {

    // MARK: - Web Trail System

    /// Gerçekçi örümcek ağı trail sistemi
    var webSegments: [SKSpriteNode] {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.webSegments) as? [SKSpriteNode]
                ?? []
        }
        set {
            objc_setAssociatedObject(
                self, &AssociatedKeys.webSegments, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var webJoints: [SKPhysicsJoint] {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.webJoints) as? [SKPhysicsJoint]
                ?? []
        }
        set {
            objc_setAssociatedObject(
                self, &AssociatedKeys.webJoints, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var lastWebPoint: CGPoint? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.lastWebPoint) as? CGPoint }
        set {
            objc_setAssociatedObject(
                self, &AssociatedKeys.lastWebPoint, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var webAnchorPoints: [CGPoint] {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.webAnchorPoints) as? [CGPoint]
                ?? []
        }
        set {
            objc_setAssociatedObject(
                self, &AssociatedKeys.webAnchorPoints, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    /// Böceğin arkasından gerçekçi ağ çıkması için setup
    func setupBugTrailEffect() {
        // Particle emitter oluştur (ek parıltı efekti için)
        let trailEmitter = SKEmitterNode()

        // Temel ayarlar - Daha az particle, sadece parıltı için
        trailEmitter.particleTexture = createDewdropTexture()
        trailEmitter.particleBirthRate = 5  // Az sayıda çiy damlası
        trailEmitter.particleLifetime = 1.2
        trailEmitter.particleLifetimeRange = 0.4

        // Boyut ayarları - Küçük parıltılar
        trailEmitter.particleScale = 0.15
        trailEmitter.particleScaleRange = 0.05
        trailEmitter.particleScaleSpeed = -0.1

        // Renk - Beyaz parıltılı çiy damlaları
        trailEmitter.particleColor = .white
        trailEmitter.particleColorBlendFactor = 1.0

        // Alpha - Parlak başla, yavaş kaybol
        trailEmitter.particleAlpha = 0.9
        trailEmitter.particleAlphaRange = 0.1
        trailEmitter.particleAlphaSpeed = -0.7

        // Pozisyon - Böceğin tam arkasında
        trailEmitter.particlePosition = .zero
        trailEmitter.particlePositionRange = CGVector(dx: gridSize * 0.2, dy: gridSize * 0.2)

        // Hareket - Hafif aşağı düşsün (gravity efekti)
        trailEmitter.particleSpeed = 5
        trailEmitter.particleSpeedRange = 3
        trailEmitter.emissionAngle = .pi * 1.5  // Aşağı
        trailEmitter.emissionAngleRange = .pi * 0.3
        trailEmitter.yAcceleration = -20  // Hafif gravity

        // Blend mode - Parlak
        trailEmitter.particleBlendMode = .add
        trailEmitter.zPosition = 7
        trailEmitter.targetNode = tileMap

        // Başlangıçta kapalı
        trailEmitter.particleBirthRate = 0

        bugNode.addChild(trailEmitter)
        bugTrailEmitter = trailEmitter

        // Web arrays'i initialize et
        webSegments = []
        webJoints = []
        webAnchorPoints = []
        lastWebPoint = nil
    }

    /// Gerçekçi ağ teli oluşturma
    func createWebStrand(from startPoint: CGPoint, to endPoint: CGPoint) {
        let distance = hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)

        // Çok kısa mesafeler için ağ oluşturma
        guard distance > gridSize * 0.3 else { return }

        // Segment sayısı - Daha uzun mesafe = daha fazla segment (daha gerçekçi)
        let segmentCount = max(2, Int(distance / (gridSize * 0.4)))
        let segmentLength = distance / CGFloat(segmentCount)

        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let dx = cos(angle) * segmentLength
        let dy = sin(angle) * segmentLength

        var previousNode: SKSpriteNode?
        var currentPoint = startPoint

        for i in 0..<segmentCount {
            // Segment node oluştur
            let segment = SKSpriteNode(texture: createWebStrandTexture())
            segment.size = CGSize(width: segmentLength, height: 2.0)  // İnce tel
            segment.zPosition = 6
            segment.alpha = 0.7

            // Pozisyon
            currentPoint = CGPoint(
                x: startPoint.x + dx * CGFloat(i) + dx / 2,
                y: startPoint.y + dy * CGFloat(i) + dy / 2
            )
            segment.position = currentPoint
            segment.zRotation = angle

            // Physics body - Çok hafif, esnek
            let physicsBody = SKPhysicsBody(rectangleOf: segment.size)
            physicsBody.mass = 0.001  // Çok hafif
            physicsBody.friction = 0.2
            physicsBody.restitution = 0.1
            physicsBody.linearDamping = 0.5  // Hava direnci
            physicsBody.angularDamping = 0.3
            physicsBody.categoryBitMask = 0x1 << 10  // Web category
            physicsBody.collisionBitMask = 0  // Collision yok
            physicsBody.contactTestBitMask = 0
            physicsBody.allowsRotation = true
            physicsBody.isDynamic = true

            segment.physicsBody = physicsBody
            tileMap.addChild(segment)
            webSegments.append(segment)

            // Joint ile önceki segment'e bağla
            if let previous = previousNode {
                let joint = SKPhysicsJointPin.joint(
                    withBodyA: previous.physicsBody!,
                    bodyB: segment.physicsBody!,
                    anchor: CGPoint(
                        x: previous.position.x + dx / 2,
                        y: previous.position.y + dy / 2
                    )
                )

                // Joint ayarları - Esnek ama sağlam
                joint.shouldEnableLimits = false
                joint.frictionTorque = 0.1

                tileMap.scene?.physicsWorld.add(joint)
                webJoints.append(joint)
            } else {
                // İlk segment - Başlangıç noktasına sabitle
                segment.physicsBody?.isDynamic = false  // İlk nokta sabit
            }

            previousNode = segment

            // Fade out animasyonu - Ağ yavaşça kaybolsun
            let fadeDelay = SKAction.wait(forDuration: 0.5)
            let fadeOut = SKAction.fadeOut(withDuration: 1.5)
            let remove = SKAction.run { [weak self, weak segment] in
                if let segment = segment, let index = self?.webSegments.firstIndex(of: segment) {
                    self?.webSegments.remove(at: index)
                }
            }
            let sequence = SKAction.sequence([
                fadeDelay, fadeOut, remove, SKAction.removeFromParent(),
            ])
            segment.run(sequence)
        }

        // Son segment'i de sabitle (bitiş noktası)
        if let lastSegment = previousNode {
            lastSegment.physicsBody?.isDynamic = false
        }
    }

    /// Radyal ağ deseni oluştur (örümcek ağı gibi)
    func createRadialWeb(at center: CGPoint, radius: CGFloat, spokes: Int = 6) {
        webAnchorPoints.removeAll()

        // Radyal çizgiler (merkez noktadan dışa)
        for i in 0..<spokes {
            let angle = (CGFloat(i) / CGFloat(spokes)) * .pi * 2
            let endPoint = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            createWebStrand(from: center, to: endPoint)
            webAnchorPoints.append(endPoint)
        }

        // Spiral çizgiler (dairesel bağlantılar)
        let rings = 3
        for ring in 1...rings {
            let ringRadius = radius * CGFloat(ring) / CGFloat(rings)

            for i in 0..<spokes {
                let angle1 = (CGFloat(i) / CGFloat(spokes)) * .pi * 2
                let angle2 = (CGFloat((i + 1) % spokes) / CGFloat(spokes)) * .pi * 2

                let point1 = CGPoint(
                    x: center.x + cos(angle1) * ringRadius,
                    y: center.y + sin(angle1) * ringRadius
                )
                let point2 = CGPoint(
                    x: center.x + cos(angle2) * ringRadius,
                    y: center.y + sin(angle2) * ringRadius
                )

                createWebStrand(from: point1, to: point2)
            }
        }
    }

    /// Trail modunda ağ oluşturma
    func updateBugWebTrail() {
        let currentPos = bugNode.position

        if let lastPoint = lastWebPoint {
            let distance = hypot(currentPos.x - lastPoint.x, currentPos.y - lastPoint.y)

            // Belirli bir mesafe kat edildiğinde ağ oluştur
            if distance > gridSize * 0.6 {
                // Basit tel oluştur
                createWebStrand(from: lastPoint, to: currentPos)

                // Her 3-4 segment'te bir radyal ağ oluştur
                if webSegments.count % 15 == 0 {
                    createRadialWeb(at: currentPos, radius: gridSize * 1.5, spokes: 4)
                }

                lastWebPoint = currentPos
            }
        } else {
            lastWebPoint = currentPos
        }
    }

    /// Trail efektini aktif/pasif yapar
    func updateBugTrailEmission(isActive: Bool) {
        guard let emitter = bugTrailEmitter else { return }

        if isActive {
            // Trail modunda parıltı + ağ
            emitter.particleBirthRate = 5
            updateBugWebTrail()
        } else {
            // Safe zone'da dur
            emitter.particleBirthRate = 0
            lastWebPoint = nil
        }
    }

    /// Tüm ağları temizle
    func clearWebTrail() {
        // Segment'leri temizle
        webSegments.forEach { $0.removeFromParent() }
        webSegments.removeAll()

        // Joint'leri temizle
        webJoints.forEach { tileMap.scene?.physicsWorld.remove($0) }
        webJoints.removeAll()

        webAnchorPoints.removeAll()
        lastWebPoint = nil
    }

    // MARK: - Texture Creation

    /// İnce, parlak ağ teli texture'ı
    private func createWebStrandTexture() -> SKTexture {
        let size = CGSize(width: 32, height: 4)

        return createTexture(size: size) { ctx in
            // Gradient - Ortada parlak, kenarlarda şeffaf
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors =
                [
                    CGColor(red: 1, green: 1, blue: 1, alpha: 0),  // Şeffaf
                    CGColor(red: 0.9, green: 0.95, blue: 1, alpha: 1),  // Parlak beyaz-mavi
                    CGColor(red: 1, green: 1, blue: 1, alpha: 0),  // Şeffaf
                ] as CFArray

            if let gradient = CGGradient(
                colorsSpace: colorSpace, colors: colors, locations: [0, 0.5, 1])
            {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: size.height / 2),
                    end: CGPoint(x: size.width, y: size.height / 2),
                    options: []
                )
            }

            // İnce parlak çizgi (highlight)
            ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.8))
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: 0, y: size.height / 2))
            ctx.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            ctx.strokePath()
        }
    }

    /// Çiy damlası texture'ı (parıltı efekti için)
    private func createDewdropTexture() -> SKTexture {
        let size = CGSize(width: 16, height: 16)

        return createTexture(size: size) { ctx in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2

            // Radyal gradient - Parlak merkez
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors =
                [
                    CGColor(red: 1, green: 1, blue: 1, alpha: 1),  // Parlak beyaz
                    CGColor(red: 0.7, green: 0.9, blue: 1, alpha: 0.6),  // Açık mavi
                    CGColor(red: 0.5, green: 0.8, blue: 1, alpha: 0),  // Şeffaf mavi
                ] as CFArray

            if let gradient = CGGradient(
                colorsSpace: colorSpace, colors: colors, locations: [0, 0.5, 1])
            {
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: radius,
                    options: []
                )
            }

            // Parlak nokta (highlight)
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
            let highlightRect = CGRect(
                x: center.x - 2,
                y: center.y + 2,
                width: 3,
                height: 3
            )
            ctx.fillEllipse(in: highlightRect)
        }
    }

    /// Yardımcı fonksiyon: CoreGraphics ile texture oluşturma
    private func createTexture(size: CGSize, draw: (CGContext) -> Void) -> SKTexture {
        #if os(macOS)
            let img = NSImage(size: size)
            img.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                draw(ctx)
            }
            img.unlockFocus()
            return SKTexture(image: img)
        #else
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            if let ctx = UIGraphicsGetCurrentContext() {
                draw(ctx)
            }
            let img = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return SKTexture(image: img ?? UIImage())
        #endif
    }
}

// MARK: - Associated Objects Helper

private struct AssociatedKeys {
    static var webSegments = "webSegments"
    static var webJoints = "webJoints"
    static var lastWebPoint = "lastWebPoint"
    static var webAnchorPoints = "webAnchorPoints"
}
