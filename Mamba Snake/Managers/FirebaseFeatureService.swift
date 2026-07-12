import Combine
import FirebaseRemoteConfig
import Foundation

@MainActor
final class FirebaseFeatureService: ObservableObject {
    static let shared = FirebaseFeatureService()

    @Published private(set) var multiplayerEnabled = true
    @Published private(set) var leaderboardLimit = 10
    @Published private(set) var multiplayerSnapshotInterval: TimeInterval = 0.05
    @Published private(set) var interstitialAdsEnabled = true
    @Published private(set) var rewardedAdsEnabled = true
    /// Remote Config'den true gelince kullanıcıyı App Store'a yönlendirir.
    @Published private(set) var forceUpdateRequired = false

    private let remoteConfig: RemoteConfig
    private var hasStarted = false

    private init() {
        remoteConfig = RemoteConfig.remoteConfig()

        let settings = RemoteConfigSettings()
        #if DEBUG
            settings.minimumFetchInterval = 0
        #else
            settings.minimumFetchInterval = 3600
        #endif
        settings.fetchTimeout = 10
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults([
            "multiplayer_enabled": true as NSObject,
            "leaderboard_limit": 10 as NSObject,
            "multiplayer_snapshot_interval_ms": 50 as NSObject,
            "interstitial_ads_enabled": true as NSObject,
            "rewarded_ads_enabled": true as NSObject,
            "force_update_required": false as NSObject,
            "force_update_min_version": "0.0" as NSObject,
        ])
        applyValues()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            await refresh()
        }
    }

    func refresh() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            applyValues()
            FirebaseTelemetryService.shared.logRemoteConfig(status: String(describing: status))
        } catch {
            applyValues()
            FirebaseTelemetryService.shared.record(error, operation: "remote_config_fetch")
            FirebaseTelemetryService.shared.logRemoteConfig(status: "failed")
        }
    }

    private func applyValues() {
        multiplayerEnabled = remoteConfig.configValue(forKey: "multiplayer_enabled").boolValue
        leaderboardLimit = min(
            50,
            max(5, remoteConfig.configValue(forKey: "leaderboard_limit").numberValue.intValue))

        let snapshotMilliseconds = remoteConfig.configValue(
            forKey: "multiplayer_snapshot_interval_ms"
        ).numberValue.doubleValue
        // RTDB canlı kanalı yüksek frekanslı yazımı kaldırır; taban 30 ms
        multiplayerSnapshotInterval = min(1, max(0.03, snapshotMilliseconds / 1_000))
        interstitialAdsEnabled = remoteConfig.configValue(
            forKey: "interstitial_ads_enabled"
        ).boolValue
        rewardedAdsEnabled = remoteConfig.configValue(forKey: "rewarded_ads_enabled").boolValue

        // Force update: bayrak doğruysa VEYA mevcut sürüm min_version'ın altındaysa güncelle
        let flagEnabled = remoteConfig.configValue(forKey: "force_update_required").boolValue
        let minVersionString = remoteConfig.configValue(forKey: "force_update_min_version").stringValue
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let needsUpdate = flagEnabled || Self.version(currentVersion, isLessThan: minVersionString)
        forceUpdateRequired = needsUpdate
    }

    /// "1.2.3" biçimindeki iki sürümü karşılaştırır.
    private static func version(_ a: String, isLessThan b: String) -> Bool {
        let toInts = { (v: String) in v.split(separator: ".").compactMap { Int($0) } }
        let av = toInts(a)
        let bv = toInts(b)
        for i in 0..<max(av.count, bv.count) {
            let ai = i < av.count ? av[i] : 0
            let bi = i < bv.count ? bv[i] : 0
            if ai != bi { return ai < bi }
        }
        return false
    }
}