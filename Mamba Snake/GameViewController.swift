//
//  GameViewController.swift
//  Mamba Snake
//
//  Created by Erdinç Yılmaz on 10.01.2026.
//

import GameplayKit
import SpriteKit
import UIKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        if let view = self.view as! SKView? {
            // Create the scene programmatically
            let scene = GameScene(size: view.bounds.size)
            scene.scaleMode = .resizeFill

            // Present the scene
            view.presentScene(scene)

            view.ignoresSiblingOrder = true

            view.showsFPS = true
            view.showsNodeCount = true
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
