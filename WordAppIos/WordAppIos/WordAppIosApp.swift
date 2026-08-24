import SwiftUI

@main
struct WordAppIosApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Reklam SDK'sını açılışta başlat ve ilk ödüllü reklamı önden yükle.
        RewardedAdManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
