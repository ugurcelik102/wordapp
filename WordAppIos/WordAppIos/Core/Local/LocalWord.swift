import Foundation

/// Uygulama paketindeki `words.json` kaydı.
///
/// Kelime havuzu artık sunucudan değil, uygulamayla birlikte gelen bu
/// dosyadan okunur (bkz. backend/scripts/export_words_json.py).
struct LocalWord: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    let definition: String
    let definitionTr: String?
    let ipa: String?
    let partOfSpeech: String?
    let frequencyRank: Int?
    let levelId: Int
    let examples: [LocalExample]
    /// Çoktan seçmeli sorularda kullanılan yanlış tanımlar.
    let distractors: [String]

    var primaryExample: String? { examples.first?.sentence }
}

struct LocalExample: Codable, Hashable {
    let sentence: String
    let translation: String?
}
