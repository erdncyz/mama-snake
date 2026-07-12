import SwiftUI

@main
struct MambaSnakeApp: App {
    @ObservedObject private var featureService = FirebaseFeatureService.shared

    init() {
        FirebaseService.configure()
        FirebaseTelemetryService.shared.configure()
        FirebaseFeatureService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            if featureService.forceUpdateRequired {
                ForceUpdateView()
            } else {
                ContentView()
                    .ignoresSafeArea()
                    .statusBar(hidden: true)
                    .onAppear {
                        FirebaseTelemetryService.shared.logAppReady()
                        AdMobService.shared.requestTracking()
                    }
            }
        }
    }
}
