//
//  GameScene+UI.swift
//  Mamba Snake
//
//  Created by Erdinç Yılmaz on 10.01.2026.
//

import SpriteKit

#if canImport(UIKit)
    import UIKit
#else
    import AppKit
#endif

extension GameScene {

    // MARK: - Assets & Design

    func setupTextures() {
        let size = CGSize(width: gridSize, height: gridSize)

        // 1. Empty (Danger): Transparent to show Background
        emptyTexture = createTexture(size: size) { ctx in
            // No Fill (Clear) so background image shows through
            // Just a subtle grid line
            #if os(macOS)
                NSColor(white: 1.0, alpha: 0.1).setStroke()
            #else
                UIColor(white: 1.0, alpha: 0.1).setStroke()
            #endif
            ctx.setLineWidth(1)
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

        // 3. Trail (Drawing): Hot Pink / Plasma (Stylish & High Contrast)
        trailTexture = createTexture(size: size) { ctx in
            #if os(macOS)
                NSColor(displayP3Red: 1.0, green: 0.2, blue: 0.6, alpha: 0.9).setFill()
            #else
                UIColor(displayP3Red: 1.0, green: 0.2, blue: 0.6, alpha: 0.9).setFill()
            #endif
            // Slight inset for "floating" tile look
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            ctx.fill(rect)

            // White Border/Glow
            #if os(macOS)
                NSColor(white: 1.0, alpha: 0.5).setStroke()
            #else
                UIColor(white: 1.0, alpha: 0.5).setStroke()
            #endif
            ctx.setLineWidth(2)
            ctx.stroke(rect)
        }

        // 4. Border: Transparent / Invisible Wall
        borderTexture = createTexture(size: size) { ctx in
            // No fill so background shows through
            // Optional: Subtle danger indication or just clean
            #if os(macOS)
                NSColor.clear.setFill()
            #else
                UIColor.clear.setFill()
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

        // --- Pause Button ---
        let pauseBtn = createHUDItem(icon: "⏸", text: "", color: .white, width: 50)
        pauseBtn.position = CGPoint(x: width * 0.45, y: 0) // Far right
        pauseBtn.name = "pauseBtn"
        hudNode.addChild(pauseBtn)

        // Setup Game Over Panel
        setupGameOverPanel()
        setupPausePanel()

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

    func setupPausePanel() {
        if pausePanel != nil { pausePanel.removeFromParent() }
        pausePanel = SKNode()
        pausePanel.zPosition = 2000
        pausePanel.alpha = 0
        pausePanel.isHidden = true
        addChild(pausePanel)

        // Overlay
        let bgOverlay = SKShapeNode(rectOf: self.size)
        #if os(macOS)
            bgOverlay.fillColor = NSColor.black.withAlphaComponent(0.7)
        #else
            bgOverlay.fillColor = UIColor.black.withAlphaComponent(0.7)
        #endif
        bgOverlay.lineWidth = 0
        pausePanel.addChild(bgOverlay)

        // Title
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "PAUSED"
        title.fontSize = 48
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 50)
        pausePanel.addChild(title)

        // Resume Button
        let resumeBtn = SKShapeNode(rectOf: CGSize(width: 200, height: 60), cornerRadius: 30)
        #if os(macOS)
            resumeBtn.fillColor = NSColor(displayP3Red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
            resumeBtn.strokeColor = .white
        #else
            resumeBtn.fillColor = UIColor(displayP3Red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
            resumeBtn.strokeColor = .white
        #endif
        resumeBtn.lineWidth = 2
        resumeBtn.position = CGPoint(x: 0, y: -50)
        resumeBtn.name = "resumeBtn"
        pausePanel.addChild(resumeBtn)

        let btnLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        btnLbl.text = "RESUME"
        btnLbl.fontSize = 24
        btnLbl.fontColor = .white
        btnLbl.verticalAlignmentMode = .center
        resumeBtn.addChild(btnLbl)
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
