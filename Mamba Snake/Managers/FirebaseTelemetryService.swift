import FirebaseAnalytics
import FirebaseCrashlytics
import Foundation

@MainActor
final class FirebaseTelemetryService {
    static let shared = FirebaseTelemetryService()

    private var isConfigured = false

    private init() {}

    func configure() {
        guard !isConfigured else { return }
        isConfigured = true

        Analytics.setAnalyticsCollectionEnabled(true)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        Crashlytics.crashlytics().log("Firebase services configured")
    }

    func logAppReady() {
        Analytics.logEvent("app_ready", parameters: nil)
    }

    func logGameStarted(mode: GameMode) {
        Analytics.logEvent("game_started", parameters: ["mode": mode.rawValue])
    }

    func logGameEnded(mode: GameMode, score: Int, level: Int) {
        Analytics.logEvent(
            "game_ended",
            parameters: [
                "mode": mode.rawValue,
                AnalyticsParameterScore: score,
                AnalyticsParameterLevel: level,
            ])
    }

    func logLevelCompleted(mode: GameMode, level: Int) {
        Analytics.logEvent(
            "level_completed",
            parameters: ["mode": mode.rawValue, AnalyticsParameterLevel: level])
    }

    func logMultiplayerRoom(action: String) {
        Analytics.logEvent("multiplayer_room", parameters: ["action": action])
    }

    func logLeaderboardViewed(category: LeaderboardCategory) {
        Analytics.logEvent("leaderboard_viewed", parameters: ["category": category.rawValue])
    }

    func logRemoteConfig(status: String) {
        Analytics.logEvent("remote_config_result", parameters: ["status": status])
    }

    func record(_ error: Error, operation: String) {
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(operation, forKey: "last_failed_operation")
        crashlytics.record(error: error)
    }
}