import Foundation

// MARK: - Request bodies

struct RegisterRequest: Encodable {
    let email: String
    let name: String
    let password: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct ForgotPasswordBody: Encodable {
    let email: String
}

struct TestResultBody: Encodable {
    let correct: Int
    let total: Int
}

struct DailyTaskCompleteBody: Encodable {
    let key: String
}

struct ResetPasswordBody: Encodable {
    let email: String
    let code: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case email, code
        case newPassword = "new_password"
    }
}

struct ProfileUpdateRequest: Encodable {
    let dailyWordCount: Int

    enum CodingKeys: String, CodingKey {
        case dailyWordCount = "daily_word_count"
    }
}

struct ReviewSubmitBody: Encodable {
    let wordId: String
    let isCorrect: Bool

    enum CodingKeys: String, CodingKey {
        case wordId    = "word_id"
        case isCorrect = "is_correct"
    }
}

struct QuestionAnswer: Encodable {
    let questionId: Int
    let selectedOption: String

    enum CodingKeys: String, CodingKey {
        case questionId    = "question_id"
        case selectedOption = "selected_option"
    }
}

struct PlacementSubmitRequest: Encodable {
    let testId: Int
    let answers: [QuestionAnswer]

    enum CodingKeys: String, CodingKey {
        case testId = "test_id"
        case answers
    }
}

struct LevelUpdateRequest: Encodable {
    let resultId: String
    let levelId: Int

    enum CodingKeys: String, CodingKey {
        case resultId = "result_id"
        case levelId  = "level_id"
    }
}

struct SessionCreateRequest: Encodable {
    let packageId: String

    enum CodingKeys: String, CodingKey {
        case packageId = "package_id"
    }
}

struct ExerciseSubmitRequest: Encodable {
    let wordId: String
    let exerciseType: String
    let isCorrect: Bool?
    let selectedAnswer: String?
    let responseTimeMs: Int?

    enum CodingKeys: String, CodingKey {
        case wordId        = "word_id"
        case exerciseType  = "exercise_type"
        case isCorrect     = "is_correct"
        case selectedAnswer = "selected_answer"
        case responseTimeMs = "response_time_ms"
    }
}

struct SessionCompleteRequest: Encodable {
    let durationSec: Int?

    enum CodingKeys: String, CodingKey {
        case durationSec = "duration_sec"
    }
}

struct ReadingGenerateRequest: Encodable {
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
    }
}

struct ReadingFromTopicBody: Encodable {
    let topic: String
    let asDialogue: Bool

    enum CodingKeys: String, CodingKey {
        case topic
        case asDialogue = "as_dialogue"
    }
}

// MARK: - API calls

enum APIService {
    private static let api = APIClient.shared

    // Auth
    static func register(email: String, name: String, password: String) async throws -> TokenResponse {
        try await api.request("/auth/register", method: "POST",
            body: RegisterRequest(email: email, name: name, password: password))
    }

    static func login(email: String, password: String) async throws -> TokenResponse {
        try await api.request("/auth/login", method: "POST",
            body: LoginRequest(email: email, password: password))
    }

    static func forgotPassword(email: String) async throws -> ForgotPasswordResponse {
        try await api.request("/auth/forgot-password", method: "POST",
            body: ForgotPasswordBody(email: email))
    }

    static func resetPassword(email: String, code: String, newPassword: String) async throws -> TokenResponse {
        try await api.request("/auth/reset-password", method: "POST",
            body: ResetPasswordBody(email: email, code: code, newPassword: newPassword))
    }

    static func me() async throws -> UserResponse {
        try await api.request("/auth/me")
    }

    /// Hesabı ve tüm ilişkili verileri sunucuda kalıcı olarak siler.
    static func deleteAccount() async throws {
        try await api.requestNoContent("/users/me", method: "DELETE")
    }

    // Profile
    static func getProfile() async throws -> UserProfile {
        try await api.request("/users/me/profile")
    }

    @discardableResult
    static func updateProfile(dailyWordCount: Int) async throws -> UserProfile {
        try await api.request("/users/me/profile", method: "PATCH",
            body: ProfileUpdateRequest(dailyWordCount: dailyWordCount))
    }

    // Placement
    static func getPlacementTest() async throws -> PlacementTestResponse {
        try await api.request("/placement/test")
    }

    static func submitPlacement(testId: Int, answers: [QuestionAnswer]) async throws -> PlacementResult {
        try await api.request("/placement/test/submit", method: "POST",
            body: PlacementSubmitRequest(testId: testId, answers: answers))
    }

    static func updateLevel(resultId: String, levelId: Int) async throws -> EmptyResponse {
        try await api.request("/placement/level", method: "PATCH",
            body: LevelUpdateRequest(resultId: resultId, levelId: levelId))
    }

    // Words
    static func todayPackage() async throws -> WordPackage {
        // Günlük kelime sayısı backend'de kullanıcı profilinden okunur.
        try await api.request("/words/package/today")
    }

    /// Bugünkü paket tamamlandıktan sonra yeni bir paket üretir/getirir.
    static func newPackage() async throws -> WordPackage {
        try await api.request("/words/package/new", method: "POST")
    }

    /// Bugünkü paketin durumu (paket oluşturmadan) — completed ise buton pasifleşir.
    static func todayPackageStatus() async throws -> PackageStatus {
        try await api.request("/words/package/status")
    }

    // Günlük görevler (sıralı: tekrar → yeni kelimeler → cümle içinde kullanım)
    static func dailyTasksStatus() async throws -> DailyTasksStatus {
        try await api.request("/daily-tasks/status")
    }

    @discardableResult
    static func completeDailyTask(_ key: DailyTaskKey) async throws -> DailyTasksStatus {
        try await api.request("/daily-tasks/complete", method: "POST",
            body: DailyTaskCompleteBody(key: key.rawValue))
    }

    // Review (Kelime Tekrarı)
    static func reviewWords() async throws -> ReviewWordsResponse {
        try await api.request("/words/review/words")
    }

    @discardableResult
    static func submitReview(wordId: String, isCorrect: Bool) async throws -> ReviewSubmitResponse {
        try await api.request("/words/review/submit", method: "POST",
            body: ReviewSubmitBody(wordId: wordId, isCorrect: isCorrect))
    }

    // Cümle İçinde Kullanım (alıştırmalar)
    static func sentenceExercises() async throws -> SentenceExercisesResponse {
        try await api.request("/sentence-usage/exercises")
    }

    // Deneme Sınavı
    static func generateExam() async throws -> ExamResponse {
        try await api.request("/exam/generate")
    }

    // Kelime Testi (öğrenilen tüm kelimeler, 8'li)
    static func learnedWords(offset: Int, limit: Int = 8) async throws -> LearnedWordsResponse {
        try await api.request("/words/learned?offset=\(offset)&limit=\(limit)")
    }

    // İlerleme
    @discardableResult
    static func saveTestResult(correct: Int, total: Int) async throws -> ProgressSummary {
        try await api.request("/progress/test-result", method: "POST",
            body: TestResultBody(correct: correct, total: total))
    }

    static func progressSummary() async throws -> ProgressSummary {
        try await api.request("/progress/summary")
    }

    static func learnedByCategory() async throws -> CategoryProgressResponse {
        try await api.request("/progress/by-category")
    }

    // Reading (öğrenilen kelimelerden)
    static func readingFromLearned() async throws -> ReadingFromLearned {
        try await api.request("/reading/from-learned", method: "POST")
    }

    // Reading (tekrar zamanı gelen kelimelerden)
    static func readingFromReview() async throws -> ReadingFromLearned {
        try await api.request("/reading/from-review", method: "POST")
    }

    // Reading (belirli bir konu hakkında, isteğe bağlı diyalog)
    static func readingFromTopic(topic: String, asDialogue: Bool) async throws -> ReadingFromLearned {
        try await api.request("/reading/from-topic", method: "POST",
            body: ReadingFromTopicBody(topic: topic, asDialogue: asDialogue))
    }

    static func wordDetail(id: String) async throws -> WordDetail {
        try await api.request("/words/\(id)")
    }

    // Sessions
    static func createSession(packageId: String) async throws -> SessionResponse {
        try await api.request("/sessions", method: "POST",
            body: SessionCreateRequest(packageId: packageId))
    }

    static func submitExercise(sessionId: String, request: ExerciseSubmitRequest) async throws -> ExerciseResponse {
        try await api.request("/sessions/\(sessionId)/exercises", method: "POST", body: request)
    }

    static func completeSession(sessionId: String, durationSec: Int?) async throws -> SessionSummary {
        try await api.request("/sessions/\(sessionId)/complete", method: "PATCH",
            body: SessionCompleteRequest(durationSec: durationSec))
    }

    // Reading
    static func generateReading(sessionId: String) async throws -> ReadingPassage {
        try await api.request("/reading/generate", method: "POST",
            body: ReadingGenerateRequest(sessionId: sessionId))
    }
}

struct EmptyResponse: Decodable {}
