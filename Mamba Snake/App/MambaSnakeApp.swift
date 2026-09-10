import SwiftUI

@main
struct MambaSnakeApp: App {
    init() {
        FirebaseService.configure()
        FirebaseTelemetryService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
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
