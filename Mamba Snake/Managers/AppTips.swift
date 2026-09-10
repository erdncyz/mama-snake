//
//  AppTips.swift
//  Mamba Snake
//
//  TipKit tabanlı, yalnızca menüde görünen (oyun sırasında rahatsız etmeyen)
//  kısa ipuçları. Örn. "Özelleştir"in ne işe yaradığını anlatır.
//  TipKit iOS 17+ olduğu için tüm kullanım availability ile korunur.
//

import SwiftUI

#if canImport(TipKit)
    import TipKit
#endif

enum AppTips {
    /// Uygulama açılışında bir kez çağrılır.
    static func configure() {
        #if canImport(TipKit)
            if #available(iOS 17.0, *) {
                try? Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault),
                ])
            }
        #endif
    }
}

#if canImport(TipKit)
    /// "Özelleştir" kutucuğunda gösterilir: karakter / yılan / arka plan değiştirme.
    @available(iOS 17.0, *)
    struct CustomizeTip: Tip {
        var title: Text { Text(L10n.string("tip.customize.title")) }
        var message: Text? { Text(L10n.string("tip.customize.message")) }
        var image: Image? { Image(systemName: "paintpalette.fill") }

        var options: [any Tip.Option] {
            Tips.MaxDisplayCount(3)
        }
    }

    /// "?" düğmesinde gösterilir: temel oynanış.
    @available(iOS 17.0, *)
    struct HowToPlayTip: Tip {
        var title: Text { Text(L10n.string("tip.howto.title")) }
        var message: Text? { Text(L10n.string("tip.howto.message")) }
        var image: Image? { Image(systemName: "hand.draw.fill") }

        var options: [any Tip.Option] {
            Tips.MaxDisplayCount(2)
        }
    }
#endif

// MARK: - Availability ile korunan yardımcılar

extension View {
    /// "Özelleştir" ipucu popover'ı (yalnızca iOS 17+).
    @ViewBuilder
    func customizeTipPopover() -> some View {
        #if canImport(TipKit)
            if #available(iOS 17.0, *) {
                self.popoverTip(CustomizeTip(), arrowEdge: .top)
            } else {
                self
            }
        #else
            self
        #endif
    }

    /// "Nasıl oynanır" ipucu popover'ı (yalnızca iOS 17+).
    @ViewBuilder
    func howToPlayTipPopover() -> some View {
        #if canImport(TipKit)
            if #available(iOS 17.0, *) {
                self.popoverTip(HowToPlayTip(), arrowEdge: .top)
            } else {
                self
            }
        #else
            self
        #endif
    }
}

enum AppTipActions {
    static func customizeTapped() {
        #if canImport(TipKit)
            if #available(iOS 17.0, *) {
                CustomizeTip().invalidate(reason: .actionPerformed)
            }
        #endif
    }

    static func howToPlayTapped() {
        #if canImport(TipKit)
            if #available(iOS 17.0, *) {
                HowToPlayTip().invalidate(reason: .actionPerformed)
            }
        #endif
    }
}
