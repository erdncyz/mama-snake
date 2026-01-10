import SpriteKit

extension GameScene {
    func setupTextures() {
        // Textures creation managed here or migrated? 
        // We still need textures for the Grid/Snake which are SpriteKit nodes.
        // So we keep setupTextures but remove UI specific ones if any.
        
        let size = CGSize(width: gridSize, height: gridSize)
        
        // 1. Empty (Transparent)
        emptyTexture = SKTexture() // Placeholder or clear
        // We need a real texture if we use SKTileMapNode with it, or just a clear image.
        // Using CoreGraphics to make a clear texture.
        emptyTexture = createTexture(size: size) { _ in }
        
        // 2. Filled
        filledTexture = createTexture(size: size) { ctx in
            #if os(macOS)
                NSColor(displayP3Red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0).setFill()
            #else
                UIColor(displayP3Red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0).setFill()
            #endif
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        // 3. Trail
        trailTexture = createTexture(size: size) { ctx in
             #if os(macOS)
                NSColor(displayP3Red: 1.0, green: 0.2, blue: 0.6, alpha: 0.9).setFill()
            #else
                UIColor(displayP3Red: 1.0, green: 0.2, blue: 0.6, alpha: 0.9).setFill()
            #endif
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            ctx.fill(rect)
        }

        // 4. Border
        borderTexture = createTexture(size: size) { ctx in
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

    // Stubs for removed UI methods to prevent build errors
    func setupUI(topMargin: CGFloat) {}
    func updateLabels() {}
    func showLandingPage() {}
    func setupGameOverPanel() {}
    func setupPausePanel() {}
    func showPausePanel() {}
    func hidePausePanel() {}
}
