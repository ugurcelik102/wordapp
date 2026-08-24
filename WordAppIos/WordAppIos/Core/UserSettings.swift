import Foundation

/// CEFR seviyeleri – uygulama genelinde tek kaynak.
enum AppLevel {
    static let all: [(id: Int, code: String, name: String)] = [
        (1, "A1", "Beginner"),
        (2, "A2", "Elementary"),
        (3, "B1", "Intermediate"),
        (4, "B2", "Upper-Intermediate"),
        (5, "C1", "Advanced"),
        (6, "C2", "Mastery"),
    ]

    static func code(for id: Int) -> String {
        all.first { $0.id == id }?.code ?? "—"
    }

    static func name(for id: Int) -> String {
        all.first { $0.id == id }?.name ?? ""
    }
}

/// Kullanıcı bazlı yerel tercihler (UserDefaults).
/// Backend bu bilgileri dönerse onlar önceliklidir; bu store yedek/yerel kaynaktır.
final class UserSettings {
    static let shared = UserSettings()
    private let defaults = UserDefaults.standard

    private init() {}

    static let dailyWordCountOptions = [4, 6, 8, 10]
    static let defaultDailyWordCount = 6

    static let defaultReadingFontSize: Double = 17
    static let readingFontSizeRange: ClosedRange<Double> = 13...30

    // MARK: - Anahtarlar

    private func placementKey(_ userId: String) -> String { "placement_completed_\(userId)" }
    private func levelKey(_ userId: String) -> String     { "saved_level_id_\(userId)" }
    private func countKey(_ userId: String) -> String     { "daily_word_count_\(userId)" }
    private func readingFontKey(_ userId: String) -> String { "reading_font_size_\(userId)" }

    // MARK: - Placement tamamlandı mı

    func placementCompleted(for userId: String) -> Bool {
        defaults.bool(forKey: placementKey(userId))
    }

    func setPlacementCompleted(_ value: Bool, for userId: String) {
        defaults.set(value, forKey: placementKey(userId))
    }

    // MARK: - Kayıtlı seviye

    func savedLevelId(for userId: String) -> Int? {
        defaults.object(forKey: levelKey(userId)) as? Int
    }

    func setSavedLevelId(_ id: Int?, for userId: String) {
        if let id {
            defaults.set(id, forKey: levelKey(userId))
        } else {
            defaults.removeObject(forKey: levelKey(userId))
        }
    }

    // MARK: - Günlük kelime sayısı

    func dailyWordCount(for userId: String) -> Int {
        let value = defaults.integer(forKey: countKey(userId))
        return value == 0 ? Self.defaultDailyWordCount : value
    }

    func setDailyWordCount(_ count: Int, for userId: String) {
        defaults.set(count, forKey: countKey(userId))
    }

    // MARK: - Okuma yazı boyutu

    func readingFontSize(for userId: String) -> Double {
        let value = defaults.double(forKey: readingFontKey(userId))
        return value == 0 ? Self.defaultReadingFontSize : value
    }

    func setReadingFontSize(_ size: Double, for userId: String) {
        defaults.set(size, forKey: readingFontKey(userId))
    }

    // MARK: - Temizlik (hesap silme)

    /// Hesap silindiğinde bu kullanıcıya ait tüm yerel tercihleri kaldırır.
    func clearAll(for userId: String) {
        defaults.removeObject(forKey: placementKey(userId))
        defaults.removeObject(forKey: levelKey(userId))
        defaults.removeObject(forKey: countKey(userId))
        defaults.removeObject(forKey: readingFontKey(userId))
    }
}
