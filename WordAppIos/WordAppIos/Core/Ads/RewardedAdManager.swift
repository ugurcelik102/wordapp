import Foundation
import Combine
import SwiftUI
import GoogleMobileAds

// MARK: - Reklamla açılan özellikler

/// Ödüllü reklam izlenerek açılan özellikler.
enum AdGatedFeature: String, CaseIterable, Identifiable {
    case reading = "reading"     // Okuma Parçası Oluştur
    case exam    = "exam"        // Deneme Sınavı

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reading: return "Okuma Parçası"
        case .exam:    return "Deneme Sınavı"
        }
    }

    /// Reklam ekranında gösterilen açıklama.
    var rewardText: String {
        switch self {
        case .reading: return "Kısa bir reklam izle, okuma parçası oluşturma bugün boyunca açık kalsın."
        case .exam:    return "Kısa bir reklam izle, deneme sınavı bugün boyunca açık kalsın."
        }
    }
}

// MARK: - Ödüllü reklam yöneticisi

/// Ödüllü reklam akışını ve "bugün açık" kaydını yönetir.
///
/// Reklam AdMob'dan yüklenir ve kullanıcıya gösterilir; ödül kazanılınca özellik
/// gün sonuna kadar açılır. Reklam yüklenemezse (envanter yok, ağ yok, hesap
/// henüz onaylanmadı) kullanıcı özellikten mahrum bırakılmaz — özellik yine açılır.
@MainActor
final class RewardedAdManager: NSObject, ObservableObject {
    static let shared = RewardedAdManager()

    /// Reklam yükleniyor/gösteriliyor — arayüzde bekleme göstergesi için.
    @Published var isPreparingAd = false

    private var loadedAd: RewardedAd?
    private var isLoading = false

    /// Ödül alındığında çalışacak iş (özelliğin asıl akışı).
    private var onReward: (() -> Void)?
    private var rewardEarned = false
    private var currentFeature: AdGatedFeature?
    private var currentUserId: String?

    private let defaults = UserDefaults.standard

    private override init() {
        super.init()
    }

    // MARK: SDK

    /// Uygulama açılışında bir kez çağrılır.
    func start() {
        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in self?.preload() }
        }
    }

    /// Bir sonraki gösterim için reklamı önceden yükler.
    func preload() {
        guard loadedAd == nil, !isLoading else { return }
        isLoading = true
        Task { @MainActor in
            defer { isLoading = false }
            do {
                loadedAd = try await RewardedAd.load(with: AdConfig.rewardedUnitID, request: Request())
            } catch {
                loadedAd = nil
                print("[ads] Ödüllü reklam yüklenemedi: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Kilit durumu

    private func key(_ feature: AdGatedFeature, userId: String) -> String {
        "ad_unlock_\(feature.rawValue)_\(userId)"
    }

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Özellik bugün için açılmış mı? (Günde bir reklam yeterli.)
    func isUnlocked(_ feature: AdGatedFeature, userId: String) -> Bool {
        defaults.string(forKey: key(feature, userId: userId)) == today
    }

    /// Ödül verildi → özellik bugün boyunca açık.
    func unlock(_ feature: AdGatedFeature, userId: String) {
        defaults.set(today, forKey: key(feature, userId: userId))
    }

    // MARK: Akış

    /// Özellik bugün açıksa `action` doğrudan çalışır; değilse reklam gösterilir
    /// ve ödül kazanılınca `action` çalışır.
    func run(_ feature: AdGatedFeature, userId: String, action: @escaping () -> Void) {
        if isUnlocked(feature, userId: userId) {
            action()
            return
        }

        onReward = action
        currentFeature = feature
        currentUserId = userId
        rewardEarned = false

        Task { @MainActor in
            isPreparingAd = true
            defer { isPreparingAd = false }

            // Hazır reklam yoksa şimdi yüklemeyi dene.
            if loadedAd == nil {
                loadedAd = try? await RewardedAd.load(with: AdConfig.rewardedUnitID, request: Request())
            }

            guard let ad = loadedAd, let root = Self.rootViewController() else {
                // Reklam gösterilemiyor — kullanıcıyı özellikten mahrum bırakma.
                print("[ads] Reklam gösterilemedi, özellik reklamsız açılıyor.")
                grantReward()
                return
            }

            loadedAd = nil
            ad.fullScreenContentDelegate = self
            ad.present(from: root) { [weak self] in
                self?.rewardEarned = true
            }
        }
    }

    /// Ödülü ver, özelliği aç ve bekleyen işi çalıştır.
    private func grantReward() {
        if let feature = currentFeature, let userId = currentUserId {
            unlock(feature, userId: userId)
        }
        let work = onReward
        clearPending()
        work?()
    }

    private func clearPending() {
        onReward = nil
        currentFeature = nil
        currentUserId = nil
        rewardEarned = false
    }

    /// Hesap silindiğinde yerel kilit kayıtlarını temizler.
    func clearAll(for userId: String) {
        for feature in AdGatedFeature.allCases {
            defaults.removeObject(forKey: key(feature, userId: userId))
        }
    }

    /// Reklamın sunulacağı en üstteki view controller.
    private static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - Reklam yaşam döngüsü

extension RewardedAdManager: FullScreenContentDelegate {

    /// Reklam kapandı: ödül kazanıldıysa özellik açılır, yarıda kapatıldıysa açılmaz.
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if rewardEarned {
            grantReward()
        } else {
            clearPending()
        }
        preload()   // sıradaki gösterim için hazırla
    }

    /// Reklam gösterilemedi — kullanıcıyı bekletmeden özelliği aç.
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[ads] Reklam sunulamadı: \(error.localizedDescription)")
        grantReward()
        preload()
    }
}
