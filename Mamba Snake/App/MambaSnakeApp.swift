import SwiftUI

@main
struct MambaSnakeApp: App {
    @StateObject private var featureService: FirebaseFeatureService

    init() {
        FirebaseService.configure()
        FirebaseTelemetryService.shared.configure()
        let featureService = FirebaseFeatureService.shared
        _featureService = StateObject(wrappedValue: featureService)
        featureService.start()
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
