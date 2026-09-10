import SpriteKit

extension GameScene {
    /// Keeps gameplay positions and actions on the carrier while drawing artwork at its original aspect ratio.
    func makeActorCarrier(_ artwork: SKSpriteNode) -> SKSpriteNode {
        let carrier = SKSpriteNode(color: .clear, size: artwork.size)
        carrier.position = artwork.position
        carrier.zPosition = artwork.zPosition
        carrier.zRotation = artwork.zRotation
        artwork.position = .zero
        artwork.zPosition = 0
        artwork.zRotation = 0
        artwork.name = "actorArtwork"
        if let textureSize = artwork.texture?.size(), textureSize.width > 0, textureSize.height > 0 {
            let factor = min(artwork.size.width / textureSize.width, artwork.size.height / textureSize.height)
            artwork.size = CGSize(width: textureSize.width * factor, height: textureSize.height * factor)
        }
        let correction = SKNode()
        correction.name = "aspectCorrection"
        correction.addChild(artwork)
        carrier.addChild(correction)
        return carrier
    }

    func updateActorPresentation() {
        guard let view, size.width > 0, size.height > 0,
            view.bounds.width > 0, view.bounds.height > 0 else { return }
        let sx = view.bounds.width / size.width
        let sy = view.bounds.height / size.height
        let uniformScale = min(sx, sy)
        let actors = [bugNode, snakeNode].compactMap { $0 } + snakeBody
        for actor in actors {
            guard let correction = actor.childNode(withName: "aspectCorrection"),
                let artwork = correction.childNode(withName: "actorArtwork") else { continue }
            // Cancel the carrier rotation before undoing the scene's unequal axis scales,
            // then rotate the artwork in screen space. This also works during turn actions.
            correction.zRotation = -actor.zRotation
            correction.xScale = uniformScale / sx
            correction.yScale = uniformScale / sy
            artwork.zRotation = actor.zRotation
        }
    }
}
