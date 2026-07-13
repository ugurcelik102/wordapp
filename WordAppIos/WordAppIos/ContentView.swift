import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch appState.route {
        case .auth:
            AuthView()
        case .placement:
            PlacementTestView()
        case .home:
            HomeView()
        }
    }
}
