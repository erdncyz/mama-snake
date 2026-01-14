import SwiftUI

@main
struct MambaSnakeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .ignoresSafeArea()
                .statusBar(hidden: true)
                .onAppear {
                    // Request IDFA tracking permission
                    AdMobService.shared.requestTracking()
                }
        }
    }
}
