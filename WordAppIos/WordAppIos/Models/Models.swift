import Foundation

// MARK: - Auth

struct TokenResponse: Decodable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType   = "token_type"
    }
}

struct ForgotPasswordResponse: Decodable {
    let message: String
    let devCode: String?

    enum CodingKeys: String, CodingKey {
        case message
        case devCode = "dev_code"
    }
}

struct UserResponse: Decodable {
    let id: String
    let email: String
    let name: String
    let currentLevelId: Int?
    let placementCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case currentLevelId     = "current_level_id"
        case placementCompleted = "placement_completed"
    }
}

struct UserProfile: Decodable {
    let dailyWordCount: Int
    let currentLevelId: Int?

    enum CodingKeys: String, CodingKey {
        case dailyWordCount = "daily_word_count"
        case currentLevelId = "current_level_id"
    }
}

// MARK: - Placement

struct PlacementQuestion: Decodable, Identifiable {
    let questionId: Int
    let word: String
    let questionType: String
    let questionText: String
    let options: [String]
    let targetLevelCode: String

    var id: Int { questionId }

    enum CodingKeys: String, CodingKey {
        case questionId      = "question_id"
        case word, options
        case questionType    = "question_type"
        case questionText    = "question_text"
        case targetLevelCode = "target_level_code"
    }
}

struct PlacementTestResponse: Decodable {
    let testId: Int
    let questions: [PlacementQuestion]

    enum CodingKeys: String, CodingKey {
        case testId   = "test_id"
        case questions
    }
}

struct PlacementResult: Decodable {
    let score: Double
    let recommendedLevel: String
    let recommendedLevelId: Int
    let resultId: String
    let breakdown: [String: Int]

    enum CodingKeys: String, CodingKey {
        case score
        case recommendedLevel   = "recommended_level"
        case recommendedLevelId = "recommended_level_id"
        case resultId           = "result_id"
        case breakdown
    }
}

// MARK: - Words

struct PackageWord: Decodable, Identifiable, Hashable {
    let id: String
    let word: String
    let definition: String
    let definitionTr: String?
    let ipa: String?
    let audioUrl: String?
    let partOfSpeech: String?
    let primaryExample: String?

    enum CodingKeys: String, CodingKey {
        case id, word, definition, ipa
        case definitionTr   = "definition_tr"
        case audioUrl       = "audio_url"
        case partOfSpeech   = "part_of_speech"
        case primaryExample = "primary_example"
    }
}

struct WordPackage: Decodable, Hashable, Identifiable {
    let id: String
    let packageDate: String
    let wordCount: Int
    let status: String
    let words: [PackageWord]

    enum CodingKeys: String, CodingKey {
        case id, status, words
        case packageDate = "package_date"
        case wordCount   = "word_count"
    }
}

struct WordDetail: Decodable, Identifiable {
    let id: String
    let word: String
    let definition: String
    let definitionTr: String?
    let ipa: String?
    let audioUrl: String?
    let partOfSpeech: String?
    let register: String
    let examples: [WordExample]
    let mcqOptions: [String]
    let wordFamily: [String]

    enum CodingKeys: String, CodingKey {
        case id, word, definition, ipa, register, examples
        case definitionTr = "definition_tr"
        case audioUrl     = "audio_url"
        case partOfSpeech = "part_of_speech"
        case mcqOptions   = "mcq_options"
        case wordFamily   = "word_family"
    }
}

struct WordExample: Decodable {
    let sentence: String
    let translation: String?
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case sentence, translation
        case isPrimary = "is_primary"
    }
}

// MARK: - Cümle İçinde Kullanım (alıştırma)

struct SentenceExercise: Decodable, Identifiable {
    let id = UUID()               // istemci tarafı kimlik (view reset için)
    let type: String              // "order" | "blank"
    let word: String
    let wordId: String?
    let prompt: String            // gösterilen cümle (yöne göre en/tr)
    let promptLang: String?       // "en" | "tr"
    let english: String
    let turkish: String
    let answerTokens: [String]?   // order: doğru sıralama
    let chips: [String]?          // order: karışık kelime çipleri
    let options: [String]?        // blank: 4 İngilizce seçenek
    let blankEnglish: String?     // blank: ____ içeren İngilizce cümle

    enum CodingKeys: String, CodingKey {
        case type, word, prompt, english, turkish, options, chips
        case wordId       = "word_id"
        case promptLang   = "prompt_lang"
        case answerTokens = "answer_tokens"
        case blankEnglish = "blank_english"
    }
}

struct SentenceExercisesResponse: Decodable {
    let count: Int
    let exercises: [SentenceExercise]
}

// MARK: - Sessions

struct SessionResponse: Decodable {
    let id: String
    let packageId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case packageId = "package_id"
    }
}

struct ExerciseResponse: Decodable {
    let id: String
    let wordId: String
    let exerciseType: String
    let isCorrect: Bool?
    let srsUpdated: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case wordId       = "word_id"
        case exerciseType = "exercise_type"
        case isCorrect    = "is_correct"
        case srsUpdated   = "srs_updated"
    }
}

struct SessionSummary: Decodable {
    let sessionId: String
    let totalExercises: Int
    let correctCount: Int
    let accuracy: Double
    let wordsAdvanced: Int
    let durationSec: Int?

    enum CodingKeys: String, CodingKey {
        case accuracy
        case sessionId      = "session_id"
        case totalExercises = "total_exercises"
        case correctCount   = "correct_count"
        case wordsAdvanced  = "words_advanced"
        case durationSec    = "duration_sec"
    }
}

// MARK: - Reading

struct ReadingPassage: Decodable {
    let id: String
    let sessionId: String
    let content: String
    let wordCount: Int?
    let targetWordTexts: [String]?
    let modelUsed: String?

    enum CodingKeys: String, CodingKey {
        case id, content
        case sessionId       = "session_id"
        case wordCount       = "word_count"
        case targetWordTexts = "target_word_texts"
        case modelUsed       = "model_used"
    }
}

struct GlossaryItem: Decodable, Identifiable {
    var id: String { word }
    let word: String
    let tr: String
}

struct ReadingFromLearned: Decodable {
    let content: String
    let wordCount: Int?
    let targetWordTexts: [String]?
    let glossary: [GlossaryItem]?

    enum CodingKeys: String, CodingKey {
        case content, glossary
        case wordCount       = "word_count"
        case targetWordTexts = "target_word_texts"
    }
}

struct PackageStatus: Decodable {
    let exists: Bool
    let completed: Bool
}

// MARK: - Günlük görevler (öncelik sıralı)

/// Ana ekrandaki üç günlük görev. Sıra: tekrar → yeni kelimeler → cümle içinde kullanım.
enum DailyTaskKey: String, Decodable, Hashable {
    case review          = "review"
    case newWords        = "new_words"
    case sentenceUsage   = "sentence_usage"

    /// Ana ekranda ve uyarı mesajlarında kullanılan görev adı.
    var title: String {
        switch self {
        case .review:        return "Kelime Tekrarı"
        case .newWords:      return "Yeni Kelimeler"
        case .sentenceUsage: return "Cümle İçinde Kullanım"
        }
    }
}

struct DailyTaskItem: Decodable {
    let key: DailyTaskKey
    let order: Int
    let completed: Bool
    let unlocked: Bool
}

/// Ana ekrandaki günlük görev kartının görsel durumu.
enum DailyTaskState {
    case available    // sıradaki görev — renkli ve tıklanabilir
    case completed    // bugünlük bitti — gri
    case locked       // önceki görev bitmedi — gri

    var isDisabled: Bool { self != .available }
}

struct DailyTasksStatus: Decodable {
    let date: String
    let tasks: [DailyTaskItem]

    func item(_ key: DailyTaskKey) -> DailyTaskItem? {
        tasks.first { $0.key == key }
    }
}

struct LearnedWordsResponse: Decodable {
    let words: [PackageWord]
    let total: Int
    let offset: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case words, total, offset
        case hasMore = "has_more"
    }
}

// MARK: - İlerleme

struct TestResultItem: Decodable, Identifiable {
    let id = UUID()
    let correct: Int
    let total: Int
    let takenAt: String

    enum CodingKeys: String, CodingKey {
        case correct, total
        case takenAt = "taken_at"
    }
}

struct ProgressSummary: Decodable {
    let testsTaken: Int
    let avgAccuracy: Double
    let lastCorrect: Int?
    let lastTotal: Int?
    let recent: [TestResultItem]

    enum CodingKeys: String, CodingKey {
        case recent
        case testsTaken  = "tests_taken"
        case avgAccuracy = "avg_accuracy"
        case lastCorrect = "last_correct"
        case lastTotal   = "last_total"
    }
}

struct CategoryProgress: Decodable, Identifiable {
    var id: String { key }
    let key: String
    let label: String
    let learned: Int
    let total: Int
}

struct CategoryProgressResponse: Decodable {
    let categories: [CategoryProgress]
}

// MARK: - Deneme Sınavı

struct ExamQuestion: Decodable, Identifiable {
    let id = UUID()
    let type: String            // "vocab" | "grammar"
    let question: String
    let options: [String]
    let answer: String
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case type, question, options, answer, explanation
    }
}

struct ExamResponse: Decodable {
    let count: Int
    let durationSec: Int
    let questions: [ExamQuestion]

    enum CodingKeys: String, CodingKey {
        case count, questions
        case durationSec = "duration_sec"
    }
}

// MARK: - Review

struct ReviewWordsResponse: Decodable {
    let count: Int
    let words: [PackageWord]
}

struct ReviewSubmitResponse: Decodable {
    let srsUpdated: Bool

    enum CodingKeys: String, CodingKey {
        case srsUpdated = "srs_updated"
    }
}
