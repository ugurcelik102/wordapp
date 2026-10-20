import SwiftUI
import Combine

enum AppRoute {
    case placement
    case home
}

/// Uygulamanın açılış yönlendirmesi.
///
/// Üyelik yoktur: ilk açılışta seviye tespitine, sonrasında doğrudan ana
/// ekrana gidilir. Tüm durum cihazda (`ProgressStore`) tutulur.
@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute
    /// Kelime havuzu yüklenemezse gösterilecek hata.
    @Published var loadError: String?

    private let store = ProgressStore.shared

    init() {
        route = store.placementCompleted ? .home : .placement
    }

    /// Kelime havuzunu paketten yükler. Uygulama açılışında bir kez çağrılır.
    func loadWordPool() {
        do {
            try WordStore.shared.loadIfNeeded()
        } catch {
            loadError = error.localizedDescription
        }
    }

    func didCompletePlacement(levelId: Int) {
        store.completePlacement(levelId: levelId)
        route = .home
    }

    /// Ayarlardan seviyeyi yeniden belirleme.
    func startPlacement() {
        route = .placement
    }

    /// Tüm yerel ilerlemeyi siler ve sıfırdan başlatır.
    func resetAllData() {
        store.resetForTesting()
        RewardedAdManager.shared.clearAll()
        route = .placement
    }
}
