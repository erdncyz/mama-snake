import SwiftUI

@main
struct MambaSnakeApp: App {
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.system.rawValue

    init() {
        FirebaseService.configure()
        FirebaseTelemetryService.shared.configure()
        AppTips.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(
                    \.locale,
                    (AppLanguage(rawValue: appLanguage) ?? .system).locale
                )
                .statusBar(hidden: true)
                .onAppear {
                    FirebaseTelemetryService.shared.logAppReady()
                    AdMobService.shared.requestTracking()
                }
        }
    }
}
