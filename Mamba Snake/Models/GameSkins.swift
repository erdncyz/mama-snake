//
//  GameSkins.swift
//  Mamba Snake
//
//  Oyuncunun kontrol ettiği böcek ve rakip yılan için karakter (skin) seçimleri.
//  Skinler oyunun mevcut assetleriyle aynı parlak illüstrasyon tarzındadır; statik
//  görseller oyunda "canlı" hissettiren hafif idle animasyonlarla (kanat çırpma /
//  nefes alma) hareketlendirilir. Örümcek tam kare-kare animasyonlu GIF'tir.
//

import SpriteKit
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - AppStorage Keys

enum SkinDefaults {
    static let bugKey = "bugSkin"
    static let snakeKey = "snakeSkin"
}

// MARK: - Idle animasyon türü

private enum IdleMotion {
    case none
    case flyer   // hızlı kanat çırpma (yatay squash)
    case walker  // yavaş nefes alma (uniform scale)

    func apply(to node: SKSpriteNode) {
        switch self {
        case .none:
            break
        case .flyer:
            let flap = SKAction.sequence([
                SKAction.scaleX(to: 0.82, y: 1.0, duration: 0.09),
                SKAction.scaleX(to: 1.0, y: 1.0, duration: 0.09),
            ])
            flap.timingMode = .easeInEaseOut
            node.run(SKAction.repeatForever(flap), withKey: "idle")
        case .walker:
            let breathe = SKAction.sequence([
                SKAction.scale(to: 1.05, duration: 0.55),
                SKAction.scale(to: 1.0, duration: 0.55),
            ])
            breathe.timingMode = .easeInEaseOut
            node.run(SKAction.repeatForever(breathe), withKey: "idle")
        }
    }
}

// MARK: - Bug (oyuncunun kontrol ettiği karakter)

enum BugSkin: String, CaseIterable, Identifiable {
    case spider
    case scarab
    case ladybug
    case bee
    case butterfly
    case scorpion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spider: return L10n.string("bug.spider")
        case .scarab: return L10n.string("bug.scarab")
        case .ladybug: return L10n.string("bug.ladybug")
        case .bee: return L10n.string("bug.bee")
        case .butterfly: return L10n.string("bug.butterfly")
        case .scorpion: return L10n.string("bug.scorpion")
        }
    }

    /// Menü/oyun için görsel adı. Örümcek animasyonlu GIF olduğundan nil.
    var imageName: String? {
        switch self {
        case .spider: return nil
        case .scarab: return "Bug"            // Asset kataloğu
        case .ladybug: return "Bug2_ladybug"  // Bundle PNG
        case .bee: return "Bug2_bee"
        case .butterfly: return "Bug2_butterfly"
        case .scorpion: return "Bug2_scorpion"
        }
    }

    private var idle: IdleMotion {
        switch self {
        case .spider: return .none
        case .bee, .butterfly: return .flyer
        case .scarab, .ladybug, .scorpion: return .walker
        }
    }

    private var sizeFactor: CGFloat { self == .spider ? 5.0 : 4.8 }

    static var current: BugSkin {
        BugSkin(rawValue: UserDefaults.standard.string(forKey: SkinDefaults.bugKey) ?? "") ?? .spider
    }

    /// Seçili böcek karakterini oluşturur.
    func makeNode(gridSize: CGFloat) -> SKSpriteNode {
        let size = CGSize(width: gridSize * sizeFactor, height: gridSize * sizeFactor)

        if self == .spider {
            if let node = SKSpriteNode.createAnimatedSprite(
                gifNamed: "Spider", size: size, filtering: .linear
            ) {
                return node
            }
        }

        let node: SKSpriteNode
        if let name = imageName, let texture = SKTexture.skinTexture(named: name) {
            node = SKSpriteNode(texture: texture)
        } else {
            node = SKSpriteNode(imageNamed: "Bug")
        }
        node.size = size
        idle.apply(to: node)
        return node
    }
}

// MARK: - Snake (rakip yılan)

enum SnakeSkin: String, CaseIterable, Identifiable {
    case classic
    case crimson
    case azure
    case violet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return L10n.string("snake.green")
        case .crimson: return L10n.string("snake.crimson")
        case .azure: return L10n.string("snake.azure")
        case .violet: return L10n.string("snake.violet")
        }
    }

    private var headImage: String {
        switch self {
        case .classic: return "SnakeHead"
        case .crimson: return "SnakeCrimsonHead"
        case .azure: return "SnakeAzureHead"
        case .violet: return "SnakeVioletHead"
        }
    }

    private var bodyImage: String {
        switch self {
        case .classic: return "SnakeBody"
        case .crimson: return "SnakeCrimsonBody"
        case .azure: return "SnakeAzureBody"
        case .violet: return "SnakeVioletBody"
        }
    }

    /// Menü önizlemesi için görsel adı.
    var previewImageName: String { headImage }

    static var current: SnakeSkin {
        SnakeSkin(rawValue: UserDefaults.standard.string(forKey: SkinDefaults.snakeKey) ?? "") ?? .classic
    }

    func makeHead(gridSize: CGFloat) -> SKSpriteNode {
        let size = CGSize(width: gridSize * 3.0, height: gridSize * 3.0)
        let node: SKSpriteNode
        if let texture = SKTexture.skinTexture(named: headImage) {
            node = SKSpriteNode(texture: texture)
        } else {
            node = SKSpriteNode(imageNamed: "SnakeHead")
        }
        node.size = size
        // Hafif nefes alma efekti.
        let breathe = SKAction.sequence([
            SKAction.scale(to: 1.04, duration: 0.6),
            SKAction.scale(to: 1.0, duration: 0.6),
        ])
        breathe.timingMode = .easeInEaseOut
        node.run(SKAction.repeatForever(breathe), withKey: "idle")
        return node
    }

    func makeBodySegment(gridSize: CGFloat) -> SKSpriteNode {
        let size = CGSize(width: gridSize * 2.5, height: gridSize * 2.5)
        let node: SKSpriteNode
        if let texture = SKTexture.skinTexture(named: bodyImage) {
            node = SKSpriteNode(texture: texture)
        } else {
            node = SKSpriteNode(imageNamed: "SnakeBody")
        }
        node.size = size
        return node
    }
}

// MARK: - Texture yardımcısı

extension SKTexture {
    /// Asset kataloğundan ya da bundle içindeki gevşek PNG'den texture yükler.
    static func skinTexture(named name: String) -> SKTexture? {
        #if canImport(UIKit)
            if let image = UIImage(named: name) {
                let t = SKTexture(image: image)
                t.filteringMode = .linear
                return t
            }
        #endif
        return nil
    }
}
