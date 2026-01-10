//
//  GIFAnimationHelper.swift
//  Mamba Snake
//
//  Created by Erdinç Yılmaz on 10.01.2026.
//

import SpriteKit
import ImageIO

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension SKSpriteNode {
    
    /// GIF dosyasından animasyon oluşturur ve node'a uygular
    static func createAnimatedSprite(gifNamed name: String, size: CGSize) -> SKSpriteNode? {
        guard let textures = loadGIFTextures(named: name) else {
            print("❌ GIF yüklenemedi: \(name)")
            return nil
        }
        
        guard let firstTexture = textures.first else {
            print("❌ GIF'te frame bulunamadı")
            return nil
        }
        
        let sprite = SKSpriteNode(texture: firstTexture)
        sprite.size = size
        
        // Animasyon oluştur
        let animation = SKAction.animate(with: textures, timePerFrame: 0.1)
        let repeatAnimation = SKAction.repeatForever(animation)
        
        sprite.run(repeatAnimation, withKey: "gifAnimation")
        
        return sprite
    }
    
    /// GIF dosyasını texture array'e çevirir
    private static func loadGIFTextures(named name: String) -> [SKTexture]? {
        guard let path = Bundle.main.path(forResource: name, ofType: "gif") else {
            print("❌ GIF dosyası bulunamadı: \(name).gif")
            return nil
        }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            print("❌ GIF data okunamadı")
            return nil
        }
        
        return extractFrames(from: data)
    }
    
    /// GIF data'sından frame'leri çıkarır
    private static func extractFrames(from data: Data) -> [SKTexture]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("❌ CGImageSource oluşturulamadı")
            return nil
        }
        
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else {
            print("❌ GIF'te frame yok")
            return nil
        }
        
        var textures: [SKTexture] = []
        
        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                continue
            }
            
            #if canImport(UIKit)
            let image = UIImage(cgImage: cgImage)
            let texture = SKTexture(image: image)
            #else
            let image = NSImage(cgImage: cgImage, size: .zero)
            let texture = SKTexture(image: image)
            #endif
            
            textures.append(texture)
        }
        
        print("✅ GIF yüklendi: \(frameCount) frame")
        return textures
    }
    
    /// Animasyon hızını değiştirir
    func setAnimationSpeed(_ speed: CGFloat) {
        // Mevcut animasyonu durdur
        removeAction(forKey: "gifAnimation")
        
        // Not: Yeni hızla animasyon için texture'ları saklamak gerekir
        // Bu basitleştirilmiş versiyonda sadece animasyonu durduruyoruz
    }
}

// MARK: - Animasyon Yönetimi

extension SKSpriteNode {
    
    /// Animasyonu durdurur
    func pauseAnimation() {
        isPaused = true
    }
    
    /// Animasyonu devam ettirir
    func resumeAnimation() {
        isPaused = false
    }
    
    /// Animasyonu yeniden başlatır
    func restartAnimation() {
        removeAction(forKey: "gifAnimation")
        // Yeniden başlatmak için createAnimatedSprite çağrılmalı
    }
}
