import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

class AdMobService: NSObject {
    static let shared = AdMobService()

    // Test IDs
    // Replace these with your actual Ad Unit IDs from AdMob console before release
    #if DEBUG
        let bannerUnitID = "ca-app-pub-3940256099942544/2934735716"  // Test Banner
        let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"  // Test Interstitial
    #else
        let bannerUnitID = "ca-app-pub-1271900948473545/YOUR_BANNER_ID_HERE"  // Real Banner (User needs to fill)
        let interstitialUnitID = "ca-app-pub-1271900948473545/YOUR_INTERSTITIAL_ID_HERE"  // Real Interstitial (User needs to fill)
    #endif

    #if canImport(GoogleMobileAds)
        private var interstitial: InterstitialAd?
    #endif

    override private init() {
        super.init()
        #if canImport(GoogleMobileAds)
            MobileAds.shared.start(completionHandler: nil)
            loadInterstitial()
        #endif
    }

    func loadInterstitial() {
        #if canImport(GoogleMobileAds)
            let request = Request()
            InterstitialAd.load(
                with: interstitialUnitID,
                request: request
            ) { [weak self] ad, error in
                if let error = error {
                    print(
                        "Failed to load interstitial ad with error: \(error.localizedDescription)")
                    return
                }
                self?.interstitial = ad
                // self?.interstitial?.fullScreenContentDelegate = self // Create delegate extension if needed
            }
        #endif
    }

    func showInterstitial() {
        #if canImport(GoogleMobileAds)
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let rootVC = windowScene.windows.first?.rootViewController
            else {
                return
            }

            if let ad = interstitial {
                ad.present(from: rootVC)
                // Preload the next one
                loadInterstitial()
            } else {
                print("Ad wasn't ready")
                loadInterstitial()
            }
        #endif
    }
}

// MARK: - Banner View
struct AdMobBanner: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let view = UIViewController()

        #if canImport(GoogleMobileAds)
            let windowWidth = UIScreen.main.bounds.width
            let adaptiveSize = currentOrientationAnchoredAdaptiveBanner(width: windowWidth)
            let banner = BannerView(adSize: adaptiveSize)
            banner.adUnitID = AdMobService.shared.bannerUnitID
            banner.rootViewController = view
            view.view.addSubview(banner)
            view.view.frame = CGRect(origin: .zero, size: adaptiveSize.size)
            banner.load(Request())
        #endif

        return view
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
