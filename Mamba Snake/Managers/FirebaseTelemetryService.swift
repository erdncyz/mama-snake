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

    func logGameStarted() {
        Analytics.logEvent("game_started", parameters: nil)
    }

    func logGameEnded(score: Int, level: Int) {
        Analytics.logEvent(
            "game_ended",
            parameters: [
                AnalyticsParameterScore: score,
                AnalyticsParameterLevel: level,
            ])
    }

    func logLevelCompleted(level: Int) {
        Analytics.logEvent(
            "level_completed",
            parameters: [AnalyticsParameterLevel: level])
    }

    func logLeaderboardViewed() {
        Analytics.logEvent("leaderboard_viewed", parameters: nil)
    }

    func record(_ error: Error, operation: String) {
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(operation, forKey: "last_failed_operation")
        crashlytics.record(error: error)
    }
}
