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

/// Uygulama genelindeki varsayılanlar.
///
/// Kullanıcı tercihleri artık `ProgressStore` içinde, diğer ilerleme verisiyle
/// birlikte tutulur; burada yalnızca sabitler kalır.
enum UserSettings {
    static let dailyWordCountOptions = [4, 6, 8, 10]
    static let defaultDailyWordCount = 6
    static let defaultReadingFontSize: Double = 17
}
