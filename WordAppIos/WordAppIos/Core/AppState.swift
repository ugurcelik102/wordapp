import SwiftUI
import Combine

enum AppRoute {
    case auth
    case placement
    case home
}

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute
    @Published var currentUserId: String?

    init() {
        // Token varsa geçici olarak home'da başla; bootstrap doğru route'u belirler.
        route = TokenStorage.shared.isLoggedIn ? .home : .auth
        if TokenStorage.shared.isLoggedIn {
            Task { await bootstrap() }
        }
    }

    /// Uygulama açılışında token varsa kullanıcıyı çöz ve placement durumuna göre yönlendir.
    func bootstrap() async {
        guard TokenStorage.shared.isLoggedIn else {
            route = .auth
            return
        }
        await resolveRoute(fallback: .home)
    }

    /// Login/register sonrası çağrılır.
    func didLogin() async {
        await resolveRoute(fallback: .placement)
    }

    /// /auth/me ile kullanıcıyı çözer, placement tamamlandıysa home aksi halde placement.
    private func resolveRoute(fallback: AppRoute) async {
        do {
            let me = try await APIService.me()
            currentUserId = me.id

            // Seviyeyi göstermek için sakla. DİKKAT: current_level_id register'da hep
            // set edilir, bu yüzden placement sinyali DEĞİLDİR.
            if let levelId = me.currentLevelId {
                UserSettings.shared.setSavedLevelId(levelId, for: me.id)
            }

            // Placement yapıldı mı: backend placement_completed VEYA cihazdaki kayıt.
            let done = (me.placementCompleted ?? false)
                || UserSettings.shared.placementCompleted(for: me.id)

            route = done ? .home : .placement
        } catch {
            // Kullanıcı çözülemedi: güvenli varsayılana düş.
            route = fallback
        }
    }

    func didCompletePlacement(levelId: Int) {
        if let uid = currentUserId {
            UserSettings.shared.setPlacementCompleted(true, for: uid)
            UserSettings.shared.setSavedLevelId(levelId, for: uid)
        }
        route = .home
    }

    /// Ayarlardan seviyeyi yeniden belirleme.
    func startPlacement() {
        route = .placement
    }

    func logout() {
        TokenStorage.shared.clear()
        currentUserId = nil
        route = .auth
    }
}
