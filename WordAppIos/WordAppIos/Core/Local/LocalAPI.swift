import Foundation

/// Eskiden sunucuya giden veri işlemlerinin cihaz karşılığı.
///
/// `APIService` ile aynı imzalara sahiptir (async throws), böylece ekranlar
/// neredeyse değişmeden çalışır. Yalnızca yapay zekâ üretimi sunucuda kalır;
/// geri kalan her şey `WordStore` + `ProgressStore` üzerinden yereldir.
@MainActor
enum LocalAPI {

    private static var store: ProgressStore { ProgressStore.shared }

    // MARK: - Profil

    static func getProfile() -> UserProfile {
        UserProfile(dailyWordCount: store.dailyWordCount, currentLevelId: store.levelId)
    }

    @discardableResult
    static func updateProfile(dailyWordCount: Int) -> UserProfile {
        store.setDailyWordCount(dailyWordCount)
        return getProfile()
    }

    // MARK: - Kelime paketi

    static func todayPackage() throws -> WordPackage {
        try packageResponse(store.todayPackage())
    }

    static func newPackage() throws -> WordPackage {
        try packageResponse(store.createPackage())
    }

    static func todayPackageStatus() -> PackageStatus {
        guard let pkg = store.package() else {
            return PackageStatus(exists: false, completed: false)
        }
        return PackageStatus(exists: true, completed: pkg.completed)
    }

    private static func packageResponse(_ pkg: StoredPackage) throws -> WordPackage {
        let words = WordStore.shared.words(ids: pkg.wordIds)
        return WordPackage(
            id: pkg.id,
            packageDate: pkg.day,
            wordCount: words.count,
            status: pkg.completed ? "completed" : "active",
            words: words.map(packageWord)
        )
    }

    private static func packageWord(_ w: LocalWord) -> PackageWord {
        PackageWord(
            id: w.id, word: w.word, definition: w.definition,
            definitionTr: w.definitionTr, ipa: w.ipa, audioUrl: nil,
            partOfSpeech: w.partOfSpeech, primaryExample: w.primaryExample
        )
    }

    // MARK: - Günlük görevler

    static func dailyTasksStatus() -> DailyTasksStatus {
        store.dailyTasksStatus()
    }

    @discardableResult
    static func completeDailyTask(_ key: DailyTaskKey) -> DailyTasksStatus {
        store.markTaskCompleted(key)
        if key == .newWords { store.completeTodayPackage() }
        return store.dailyTasksStatus()
    }

    // MARK: - Tekrar

    static func reviewWords() -> ReviewWordsResponse {
        let words = store.dueReviewWords(limit: 10)
        return ReviewWordsResponse(count: words.count, words: words.map(packageWord))
    }

    @discardableResult
    static func submitReview(wordId: String, isCorrect: Bool) -> ReviewSubmitResponse {
        store.recordAnswer(wordId: wordId, isCorrect: isCorrect)
        return ReviewSubmitResponse(srsUpdated: true)
    }

    // MARK: - Öğrenilen kelimeler

    static func learnedWords(offset: Int, limit: Int = 8) -> LearnedWordsResponse {
        let ids = store.learnedWordIds
        let page = Array(ids.dropFirst(offset).prefix(limit))
        return LearnedWordsResponse(
            words: WordStore.shared.words(ids: page).map(packageWord),
            total: ids.count,
            offset: offset,
            hasMore: offset + page.count < ids.count
        )
    }

    static func wordDetail(id: String) throws -> WordDetail {
        guard let w = WordStore.shared.word(id: id) else {
            throw LocalAPIError.wordNotFound
        }
        let options = mcqOptions(for: w)
        // Paketteki örnek yoksa yapay zekâyla üretilip saklanmış olanı kullan.
        let examples = w.examples.isEmpty
            ? ExampleStore.shared.example(for: w.id).map { [$0] } ?? []
            : w.examples

        return WordDetail(
            id: w.id, word: w.word, definition: w.definition,
            definitionTr: w.definitionTr, ipa: w.ipa, audioUrl: nil,
            partOfSpeech: w.partOfSpeech, register: "neutral",
            examples: examples.map {
                WordExample(sentence: $0.sentence, translation: $0.translation, isPrimary: false)
            },
            mcqOptions: options,
            wordFamily: []
        )
    }

    /// Doğru tanım + 3 çeldirici, karıştırılmış. Havuzdaki kelimelerin çoğunda
    /// hazır çeldirici yok; eksikler aynı seviyedeki başka kelimelerin tanımlarından
    /// RASTGELE tamamlanır (sabit seçim her soruda aynı yanlış şıkları gösterirdi).
    /// Aynı türden (isim/fiil/sıfat) tanımlar önceliklidir ki doğru cevap türünden belli olmasın.
    private static func mcqOptions(for word: LocalWord) -> [String] {
        var options = Array(word.distractors.prefix(3))
        if options.count < 3 {
            let pool = WordStore.shared.words(level: word.levelId)
                .filter { $0.id != word.id && $0.definition != word.definition }
                .shuffled()
            let samePos = pool.filter { $0.partOfSpeech == word.partOfSpeech }
            let otherPos = pool.filter { $0.partOfSpeech != word.partOfSpeech }
            for candidate in samePos + otherPos where options.count < 3 {
                if !options.contains(candidate.definition) {
                    options.append(candidate.definition)
                }
            }
        }
        options.append(word.definition)
        return options.shuffled()
    }

    // MARK: - İlerleme

    @discardableResult
    static func saveTestResult(correct: Int, total: Int) -> ProgressSummary {
        store.addTestResult(correct: correct, total: total)
        return store.progressSummary()
    }

    static func progressSummary() -> ProgressSummary { store.progressSummary() }

    static func learnedByCategory() -> CategoryProgressResponse {
        CategoryProgressResponse(categories: store.learnedByCategory())
    }

    // MARK: - Oturum (öğrenme akışı)

    /// Oturumlar yalnızca akış süresince yaşar; kalıcı kayda gerek yok.
    private struct LocalSession {
        let packageId: String
        let wordIds: [String]
        var answers: [(wordId: String, isCorrect: Bool)] = []
    }

    private static var sessions: [String: LocalSession] = [:]

    static func createSession(packageId: String) throws -> SessionResponse {
        let pkg = store.package()
        guard let pkg, pkg.id == packageId else { throw LocalAPIError.packageNotFound }
        let id = UUID().uuidString
        sessions[id] = LocalSession(packageId: packageId, wordIds: pkg.wordIds)
        return SessionResponse(id: id, packageId: packageId, status: "active")
    }

    @discardableResult
    static func submitExercise(
        sessionId: String, request: ExerciseSubmitRequest
    ) -> ExerciseResponse {
        // Puansız aşamalar (cümle doldurma, telaffuz) SRS'i etkilemez.
        if let isCorrect = request.isCorrect {
            store.recordAnswer(wordId: request.wordId, isCorrect: isCorrect)
            sessions[sessionId]?.answers.append((request.wordId, isCorrect))
        }
        return ExerciseResponse(
            id: UUID().uuidString,
            wordId: request.wordId,
            exerciseType: request.exerciseType,
            isCorrect: request.isCorrect,
            srsUpdated: request.isCorrect != nil
        )
    }

    static func completeSession(sessionId: String, durationSec: Int?) -> SessionSummary {
        let session = sessions[sessionId]
        // Aynı kelime+tür birden fazla kez cevaplandıysa son deneme sayılır.
        var latest: [String: Bool] = [:]
        for a in session?.answers ?? [] { latest[a.wordId] = a.isCorrect }

        let total = latest.count
        let correct = latest.values.filter { $0 }.count
        store.completeTodayPackage()
        sessions[sessionId] = nil

        return SessionSummary(
            sessionId: sessionId,
            totalExercises: total,
            correctCount: correct,
            accuracy: total > 0 ? Double(correct) / Double(total) : 0,
            wordsAdvanced: correct,
            durationSec: durationSec
        )
    }

    /// Bir oturumun (paketin) kelimeleri — okuma parçası üretimi için.
    static func sessionWords(_ sessionId: String) -> [LocalWord] {
        guard let ids = sessions[sessionId]?.wordIds else { return [] }
        return WordStore.shared.words(ids: ids)
    }

    // MARK: - Seviye tespiti

    /// Soru kimliği -> doğru tanım. Test üretilince doldurulur, puanlamada kullanılır.
    private static var placementAnswers: [Int: String] = [:]

    /// Her CEFR seviyesinden 4 kelimeyle ~24 soruluk test üretir.
    static func getPlacementTest() -> PlacementTestResponse {
        var questions: [PlacementQuestion] = []
        placementAnswers = [:]
        var qid = 1

        for level in AppLevel.all {
            let words = WordStore.shared.words(level: level.id)
                .sorted { ($0.frequencyRank ?? .max) < ($1.frequencyRank ?? .max) }
                .prefix(4)

            for word in words {
                let options = mcqOptions(for: word)

                questions.append(PlacementQuestion(
                    questionId: qid,
                    word: word.word,
                    questionType: "definition_mcq",
                    questionText: "\"\(word.word)\" kelimesinin anlamı nedir?",
                    options: options,
                    targetLevelCode: level.code
                ))
                placementAnswers[qid] = word.definition
                qid += 1
            }
        }
        return PlacementTestResponse(testId: 1, questions: questions)
    }

    /// Seviye: her seviyede en az %60 doğru yapılan en yüksek seviye (zincir kırılınca durur).
    static func submitPlacement(
        testId: Int, answers: [QuestionAnswer], questions: [PlacementQuestion]
    ) -> PlacementResult {
        let given = Dictionary(answers.map { ($0.questionId, $0.selectedOption) },
                               uniquingKeysWith: { _, last in last })
        var breakdown: [String: Int] = [:]
        var correctTotal = 0

        // Doğru yapılmayan seviyeler de sonuçta 0 olarak görünsün.
        for q in questions where breakdown[q.targetLevelCode] == nil {
            breakdown[q.targetLevelCode] = 0
        }
        for q in questions {
            guard let correct = placementAnswers[q.questionId] else { continue }
            if given[q.questionId] == correct {
                breakdown[q.targetLevelCode, default: 0] += 1
                correctTotal += 1
            }
        }

        let score = questions.isEmpty ? 0 : Double(correctTotal) / Double(questions.count) * 100
        var recommended = AppLevel.all[0]
        for level in AppLevel.all {
            let totalInLevel = questions.filter { $0.targetLevelCode == level.code }.count
            guard totalInLevel > 0 else { continue }
            let ratio = Double(breakdown[level.code] ?? 0) / Double(totalInLevel)
            if ratio >= 0.6 {
                recommended = level
            } else {
                break     // zinciri kır, üst seviyeye geçme
            }
        }

        store.completePlacement(levelId: recommended.id)
        return PlacementResult(
            score: score,
            recommendedLevel: recommended.code,
            recommendedLevelId: recommended.id,
            resultId: UUID().uuidString,
            breakdown: breakdown
        )
    }

    /// Kullanıcı önerilen seviyeyi değiştirirse.
    static func updateLevel(levelId: Int) {
        store.completePlacement(levelId: levelId)
    }
}

enum LocalAPIError: LocalizedError {
    case wordNotFound
    case packageNotFound

    var errorDescription: String? {
        switch self {
        case .wordNotFound:    return "Kelime bulunamadı."
        case .packageNotFound: return "Günün paketi bulunamadı."
        }
    }
}
