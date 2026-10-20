import Foundation

// MARK: - Yerel akışlarda kullanılan istek tipleri

struct QuestionAnswer: Encodable {
    let questionId: Int
    let selectedOption: String
}

struct ExerciseSubmitRequest: Encodable {
    let wordId: String
    let exerciseType: String
    let isCorrect: Bool?
    let selectedAnswer: String?
    let responseTimeMs: Int?
}

// MARK: - Sunucuya giden istek gövdeleri (yalnızca yapay zekâ)

/// Sunucuya gönderilen hedef kelime; kelime havuzu artık cihazda olduğu için
/// üretim için gereken bilgiyi istemci taşır.
struct AIWordBody: Encodable {
    let id: String?
    let word: String
    let definition: String
    let definitionTr: String?
    let partOfSpeech: String?

    enum CodingKeys: String, CodingKey {
        case id, word, definition
        case definitionTr = "definition_tr"
        case partOfSpeech = "part_of_speech"
    }

    init(_ w: LocalWord) {
        id = w.id
        word = w.word
        definition = w.definition
        definitionTr = w.definitionTr
        partOfSpeech = w.partOfSpeech
    }
}

struct ReadingBody: Encodable {
    let levelCode: String
    let words: [AIWordBody]
    let topic: String?
    let asDialogue: Bool

    enum CodingKeys: String, CodingKey {
        case words, topic
        case levelCode  = "level_code"
        case asDialogue = "as_dialogue"
    }
}

struct ExamBody: Encodable {
    let levelCode: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case count
        case levelCode = "level_code"
    }
}

struct SentenceUsageBody: Encodable {
    let words: [AIWordBody]
}

// MARK: - Sunucu çağrıları

/// Yalnızca yapay zekâ üretimi sunucuda kalır (Anthropic anahtarı istemciye
/// gömülemez). Veri işlemleri için `LocalAPI` kullanılır.
enum APIService {
    private static let api = APIClient.shared

    enum AIError: LocalizedError {
        case noWords

        var errorDescription: String? {
            "Önce birkaç kelime çalışman gerekiyor."
        }
    }

    // MARK: Okuma

    @MainActor
    private static func reading(
        words: [LocalWord], topic: String? = nil, asDialogue: Bool = false
    ) async throws -> ReadingFromLearned {
        let body = ReadingBody(
            levelCode: ProgressStore.shared.levelCode,
            words: words.map(AIWordBody.init),
            topic: topic,
            asDialogue: asDialogue
        )
        return try await api.request("/ai/reading", method: "POST", body: body)
    }

    /// Öğrenilen kelimelerden okuma parçası.
    @MainActor
    static func readingFromLearned() async throws -> ReadingFromLearned {
        let ids = Array(ProgressStore.shared.learnedWordIds.prefix(8))
        let words = WordStore.shared.words(ids: ids)
        guard !words.isEmpty else { throw AIError.noWords }
        return try await reading(words: words)
    }

    /// Tekrarı gelen kelimelerden; yoksa son öğrenilenlere düşer.
    @MainActor
    static func readingFromReview() async throws -> ReadingFromLearned {
        var words = ProgressStore.shared.dueReviewWords(limit: 8)
        if words.isEmpty {
            let ids = Array(ProgressStore.shared.learnedWordIds.prefix(8))
            words = WordStore.shared.words(ids: ids)
        }
        guard !words.isEmpty else { throw AIError.noWords }
        return try await reading(words: words)
    }

    /// Belirli bir konu/senaryo hakkında (isteğe bağlı diyalog).
    static func readingFromTopic(topic: String, asDialogue: Bool) async throws -> ReadingFromLearned {
        try await reading(words: [], topic: topic, asDialogue: asDialogue)
    }

    /// Öğrenme akışının sonundaki okuma parçası: o oturumun kelimelerinden.
    @MainActor
    static func generateReading(sessionId: String) async throws -> ReadingFromLearned {
        let words = LocalAPI.sessionWords(sessionId)
        guard !words.isEmpty else { throw AIError.noWords }
        return try await reading(words: words)
    }

    // MARK: Sınav

    @MainActor
    static func generateExam() async throws -> ExamResponse {
        let body = ExamBody(levelCode: ProgressStore.shared.levelCode, count: 20)
        return try await api.request("/ai/exam", method: "POST", body: body)
    }

    // MARK: Cümle içinde kullanım

    /// Bugünkü paket + tekrarı gelen kelimelerden alıştırma üretir.
    @MainActor
    static func sentenceExercises() async throws -> SentenceExercisesResponse {
        var pool: [LocalWord] = []
        if let pkg = ProgressStore.shared.package() {
            pool += WordStore.shared.words(ids: pkg.wordIds)
        }
        pool += ProgressStore.shared.dueReviewWords(limit: 10)

        var seen = Set<String>()
        let words = pool.filter { seen.insert($0.id).inserted }.shuffled().prefix(10)
        guard !words.isEmpty else { throw AIError.noWords }

        let body = SentenceUsageBody(words: words.map(AIWordBody.init))
        return try await api.request("/ai/sentence-usage", method: "POST", body: body)
    }
}
