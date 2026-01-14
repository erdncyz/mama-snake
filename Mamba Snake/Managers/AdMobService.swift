import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif
#if canImport(AppTrackingTransparency)
    import AppTrackingTransparency
#endif
#if canImport(AdSupport)
    import AdSupport
#endif

class AdMobService: NSObject {
    static let shared = AdMobService()

    // Test IDs
    // Replace these with your actual Ad Unit IDs from AdMob console before release
    #if DEBUG
        let bannerUnitID = "ca-app-pub-3940256099942544/2934735716"  // Test Banner
        let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"  // Test Interstitial
        let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313"  // Test Rewarded
    #else
        let bannerUnitID = "ca-app-pub-1271900948473545/2385460844"  // Real Banner
        let interstitialUnitID = "ca-app-pub-1271900948473545/4502350110"  // Real Interstitial
        let rewardedUnitID = "ca-app-pub-1271900948473545/2726234018"  // Real Rewarded
    #endif

    #if canImport(GoogleMobileAds)
        private var interstitial: InterstitialAd?
    #endif

    override private init() {
        super.init()
        #if canImport(GoogleMobileAds)
            // MobileAds.shared.start will be called after tracking request
        #endif
    }

    func requestTracking() {
        #if canImport(AppTrackingTransparency)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    switch status {
                    case .authorized:
                        print("Tracking Authorized")
                    case .denied, .restricted, .notDetermined:
                        print("Tracking Denied/Restricted/NotDetermined")
                    @unknown default:
                        break
                    }

                    // Start Ads SDK regardless of status
                    #if canImport(GoogleMobileAds)
                        MobileAds.shared.start()
                        // Load initial ads
                        AdMobService.shared.loadInterstitial()
                        AdMobService.shared.loadRewardedAd()
                    #endif
                }
            }
        #else
            // Fallback for older iOS
            #if canImport(GoogleMobileAds)
                MobileAds.shared.start()
                loadInterstitial()
                loadRewardedAd()
            #endif
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

    // MARK: - Rewarded Ads
    #if canImport(GoogleMobileAds)
        private var rewardedAd: RewardedAd?
    #endif

    func loadRewardedAd() {
        #if canImport(GoogleMobileAds)
            let request = Request()
            RewardedAd.load(with: rewardedUnitID, request: request) { [weak self] ad, error in
                if let error = error {
                    print("Failed to load rewarded ad with error: \(error.localizedDescription)")
                    return
                }
                self?.rewardedAd = ad
                print("Rewarded ad loaded.")
            }
        #endif
    }

    func showRewardedAd(userDidEarnReward: @escaping () -> Void) {
        #if canImport(GoogleMobileAds)
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let rootVC = windowScene.windows.first?.rootViewController,
                let ad = rewardedAd
            else {
                print("Rewarded ad not ready")
                loadRewardedAd()
                return
            }

            ad.present(from: rootVC) {
                let reward = ad.adReward
                print("Reward received with currency: \(reward.type), amount: \(reward.amount)")
                // User earned reward
                userDidEarnReward()
            }
            // Preload next
            loadRewardedAd()
        #else
            // If in simulator/no SDK, just reward immediately for testing flow
            print("Simulating reward in simulator")
            userDidEarnReward()
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
