import SwiftUI
import Combine

enum LearningStep {
    case overview           // tüm kelimelere genel bakış
    case mcq(PackageWord, options: [String], correctAnswer: String)   // İngilizce kelime → Türkçe anlam
    case trToEn(PackageWord, options: [String]) // Türkçe anlam → İngilizce kelime
    case sentence(PackageWord) // cümle içinde kullanım
    case pronunciation(PackageWord) // telaffuz
    case summary(SessionSummary)    // özet
    case reading(String)    // session_id ile okuma parçası
}

/// Öğrenme aşamaları (aşama bazlı: tüm kelimeler önce 1'i, sonra 2'yi… geçer)
enum LearningStage: Int {
    case mcq = 1          // İngilizce → Türkçe
    case trToEn = 2       // Türkçe → İngilizce
    case sentence = 3     // cümle içinde kullanım
    case pronunciation = 4

    var next: LearningStage? { LearningStage(rawValue: rawValue + 1) }
}

@MainActor
final class LearningViewModel: ObservableObject {
    @Published var step: LearningStep = .overview
    @Published var wordDetails: [String: WordDetail] = [:]
    @Published var isLoading = true  // başlangıçta true, session oluşunca false
    @Published var errorMessage: String?
    @Published var sessionId: String?
    @Published var currentWordIndex = 0
    @Published var showReading = false
    private var currentStage: LearningStage = .mcq

    private var package: WordPackage
    private var startTime = Date()
    private var exerciseResults: [(wordId: String, isCorrect: Bool)] = []

    init(package: WordPackage) {
        self.package = package
    }

    var words: [PackageWord] { package.words }
    var currentWord: PackageWord? {
        guard currentWordIndex < words.count else { return nil }
        return words[currentWordIndex]
    }

    // MARK: - Session başlat

    func startSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await APIService.createSession(packageId: package.id)
            sessionId = session.id
            startTime = Date()

            // Kelime detaylarını yükle
            await loadWordDetails()

            // Overview'e geç
            step = .overview
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadWordDetails() async {
        await withTaskGroup(of: (String, WordDetail?).self) { group in
            for word in words {
                group.addTask {
                    let detail = try? await APIService.wordDetail(id: word.id)
                    return (word.id, detail)
                }
            }
            for await (id, detail) in group {
                if let detail { wordDetails[id] = detail }
            }
        }
    }

    // MARK: - Adım geçişleri

    func overviewDone() {
        currentStage = .mcq
        currentWordIndex = 0
        showStage(.mcq)
    }

    func mcqAnswered(isCorrect: Bool) async {
        guard let word = currentWord else { return }
        exerciseResults.append((wordId: word.id, isCorrect: isCorrect))
        await submitExercise(wordId: word.id, type: "mcq", isCorrect: isCorrect, answer: nil)
        await advance()
    }

    func trToEnAnswered(isCorrect: Bool) async {
        guard let word = currentWord else { return }
        // tr_to_en egzersizi loglanır ama SRS interval'ini ilerletmez
        await submitExercise(wordId: word.id, type: "tr_to_en", isCorrect: isCorrect, answer: nil)
        await advance()
    }

    // Türkçe MCQ seçenekleri: 3 çeldirici (diğer kelimelerin Türkçesi) + doğru cevap
    func makeMCQOptions(for word: PackageWord) -> [String] {
        let correct = word.definitionTr ?? word.definition
        let distractors = words
            .filter { $0.id != word.id }
            .shuffled()
            .prefix(3)
            .map { $0.definitionTr ?? $0.definition }
        var options = Array(distractors) + [correct]
        options.shuffle()
        return options
    }

    private func makeTrToEnOptions(for word: PackageWord) -> [String] {
        // Diğer kelimelerden 3 rastgele çeldirici seç
        let distractors = words
            .filter { $0.id != word.id }
            .shuffled()
            .prefix(3)
            .map { $0.word }
        var options = distractors + [word.word]
        options.shuffle()
        return options
    }

    func sentenceDone() async {
        guard let word = currentWord else { return }
        // sentence_fill öğrenme aşamasında gerçek bir test değil (kullanıcı sadece okur),
        // isCorrect: nil göndererek SRS interval'inin 1→6 güne atlamasını önlüyoruz.
        await submitExercise(wordId: word.id, type: "sentence_fill", isCorrect: nil, answer: nil)
        await advance()
    }

    func pronunciationDone() async {
        guard let word = currentWord else { return }
        await submitExercise(wordId: word.id, type: "pronunciation", isCorrect: nil, answer: nil)
        await advance()
    }

    // MARK: - Aşama ilerleme

    /// Mevcut kelime + aşamaya göre gösterilecek adımı ayarlar.
    private func showStage(_ stage: LearningStage) {
        guard let word = currentWord else { return }
        switch stage {
        case .mcq:
            step = .mcq(word, options: makeMCQOptions(for: word), correctAnswer: word.definitionTr ?? word.definition)
        case .trToEn:
            step = .trToEn(word, options: makeTrToEnOptions(for: word))
        case .sentence:
            step = .sentence(word)
        case .pronunciation:
            step = .pronunciation(word)
        }
    }

    /// Aşama bazlı ilerleme: önce bu aşamada bir sonraki kelime, kelimeler bitince sonraki aşama.
    private func advance() async {
        if currentWordIndex + 1 < words.count {
            currentWordIndex += 1
            showStage(currentStage)
        } else if let next = currentStage.next {
            currentStage = next
            currentWordIndex = 0
            showStage(next)
        } else {
            await completeSession()   // tüm aşamalar bitti
        }
    }

    // MARK: - Egzersiz kaydı

    private func submitExercise(wordId: String, type: String, isCorrect: Bool?, answer: String?) async {
        guard let sessionId else { return }
        let req = ExerciseSubmitRequest(
            wordId: wordId,
            exerciseType: type,
            isCorrect: isCorrect,
            selectedAnswer: answer,
            responseTimeMs: nil
        )
        _ = try? await APIService.submitExercise(sessionId: sessionId, request: req)
    }

    // MARK: - Session tamamla

    private func completeSession() async {
        guard let sessionId else { return }
        let duration = Int(Date().timeIntervalSince(startTime))
        do {
            let summary = try await APIService.completeSession(sessionId: sessionId, durationSec: duration)
            step = .summary(summary)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestReading() {
        guard let sessionId else { return }
        step = .reading(sessionId)
    }
}
