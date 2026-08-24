import SwiftUI
import Combine

// MARK: - Sunum state'i (tek enum → çakışan fullScreenCover sorunu yok)

enum HomeDestination: Identifiable {
    case learning(WordPackage)
    case review([PackageWord])
    case reading(content: String, wordCount: Int?, targets: [String], glossary: [GlossaryItem])
    case sentenceUsage([SentenceExercise])
    case exam(questions: [ExamQuestion], durationSec: Int)
    case fullTest(words: [PackageWord], offset: Int, total: Int)

    var id: String {
        switch self {
        case .learning(let p):  return "learning-\(p.id)"
        case .review:           return "review"
        case .reading:          return "reading"
        case .sentenceUsage:    return "sentence-usage"
        case .exam:             return "exam"
        case .fullTest:         return "full-test"
        }
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var isWorking = false
    @Published var banner: String?            // hata veya bilgilendirme mesajı
    @Published var destination: HomeDestination?
    @Published var newWordsLocked = false     // bugünkü paket tamamlandıysa true
    @Published var progress: ProgressSummary?  // test ilerleme özeti

    /// Günlük görevlerin bugünkü durumu (sıra: tekrar → yeni kelimeler → cümle).
    @Published var dailyTasks: DailyTasksStatus?

    // MARK: - Günlük görev durumu

    /// Bir görev bugün tamamlandı mı? (pasif/gri gösterim)
    func isCompleted(_ key: DailyTaskKey) -> Bool {
        dailyTasks?.item(key)?.completed ?? (key == .newWords ? newWordsLocked : false)
    }

    /// Bir görev şu an oynanabilir mi? Önceki öncelikler bitmeden açılmaz.
    ///
    /// Durum henüz yüklenmediyse (ilk açılış / ağ hatası) yalnızca "Yeni Kelimeler"
    /// açık sayılır; aksi halde yeni kullanıcıda "Kelime Tekrarı" aktif görünürdü.
    func isUnlocked(_ key: DailyTaskKey) -> Bool {
        guard let tasks = dailyTasks else { return key == .newWords }
        guard let item = tasks.item(key) else { return false }
        return item.unlocked
    }

    /// Kartın görsel durumu.
    func state(for key: DailyTaskKey) -> DailyTaskState {
        if isCompleted(key) { return .completed }
        return isUnlocked(key) ? .available : .locked
    }

    /// Ana ekranda gösterilen temel görevler — backend sırasına göre.
    ///
    /// Kilitli görevler de listede kalır (gri kare olarak çizilir) ki ana ekran
    /// düzeni gün içinde değişmesin. Durum yüklenene kadar "Kelime Tekrarı"
    /// gösterilmez: yeni kullanıcının tekrar havuzu boştur ve akış "Yeni
    /// Kelimeler" ile başlar.
    var allDailyTasks: [DailyTaskKey] {
        guard let tasks = dailyTasks, !tasks.tasks.isEmpty else {
            return [.newWords, .sentenceUsage]
        }
        return tasks.tasks.sorted { $0.order < $1.order }.map(\.key)
    }

    /// Kilitli bir göreve dokunulduğunda gösterilecek mesaj.
    private func lockMessage(for key: DailyTaskKey) -> String {
        if isCompleted(key) {
            switch key {
            case .review:        return "Bugünkü kelime tekrarını tamamladın. Yarın yeniden açılacak."
            case .newWords:      return "Bugünkü yeni kelimeleri tamamladın. Yeni kelimeler yarın gelecek."
            case .sentenceUsage: return "Bugünkü cümle alıştırmalarını tamamladın. Yarın yeniden açılacak."
            }
        }
        // Önce tamamlanması gereken görevleri (bugünkü sıraya göre) adıyla söyle.
        let pending = (dailyTasks?.tasks ?? [])
            .filter { $0.order < (dailyTasks?.item(key)?.order ?? 0) && !$0.completed }
            .sorted { $0.order < $1.order }
            .map { $0.key.title }
        if pending.isEmpty { return "Bu görev şu an kapalı." }
        return "Önce \(pending.joined(separator: " ve ")) görevini tamamla."
    }

    /// Kilitliyse uyarı gösterir ve true döner (çağıran akış durur).
    private func blockIfLocked(_ key: DailyTaskKey) -> Bool {
        guard !isUnlocked(key) else { return false }
        banner = lockMessage(for: key)
        return true
    }

    // MARK: - Durum

    /// Bugünkü görev durumlarını tazeler (paket durumu + günlük görev kayıtları).
    func refreshStatus() async {
        if let status = try? await APIService.todayPackageStatus() {
            newWordsLocked = status.completed
        }
        dailyTasks = try? await APIService.dailyTasksStatus()
    }

    /// Ana menüdeki ilerleme özetini yükler.
    func loadProgress() async {
        progress = try? await APIService.progressSummary()
    }

    // MARK: - Yeni Kelimeler

    func startNewWords() async {
        // Bugünkü seri zaten öğrenildiyse veya sıra gelmediyse buton pasif.
        if blockIfLocked(.newWords) { return }
        if newWordsLocked {
            banner = "Bugünkü yeni kelimeleri tamamladın. Yeni kelimeler yarın gelecek."
            return
        }
        isWorking = true
        banner = nil
        defer { isWorking = false }
        do {
            let pkg = try await APIService.todayPackage()
            if pkg.status == "completed" {
                newWordsLocked = true
                banner = "Bugünkü yeni kelimeleri tamamladın. Yeni kelimeler yarın gelecek."
                return
            }
            if pkg.words.isEmpty {
                banner = "Bu seviyede çalışılacak yeni kelime kalmadı. Seviyeni Ayarlar'dan değiştirebilirsin."
            } else {
                destination = .learning(pkg)
            }
        } catch {
            banner = error.localizedDescription
        }
    }

    // MARK: - Kelime Tekrarı

    func startReview() async {
        if blockIfLocked(.review) { return }
        isWorking = true
        banner = nil
        defer { isWorking = false }
        do {
            let resp = try await APIService.reviewWords()
            if resp.words.isEmpty {
                // Tekrar edilecek kelime yoksa görev bugünlük tamamlanmış sayılır,
                // aksi halde sıradaki görevler hiç açılmaz.
                dailyTasks = try? await APIService.completeDailyTask(.review)
                banner = "Bugün tekrar edilecek kelime yok. Yeni Kelimeler görevi açıldı."
            } else {
                destination = .review(resp.words)
            }
        } catch {
            banner = error.localizedDescription
        }
    }

    // MARK: - Kelime Testi (öğrenilen tüm kelimeler, 8'li)

    func startFullTest() async {
        isWorking = true
        banner = nil
        defer { isWorking = false }
        do {
            let resp = try await APIService.learnedWords(offset: 0, limit: 8)
            if resp.words.isEmpty {
                banner = "Henüz test edilecek öğrenilmiş kelime yok. Önce birkaç kelime çalış."
            } else {
                destination = .fullTest(words: resp.words, offset: resp.offset, total: resp.total)
            }
        } catch {
            banner = error.localizedDescription
        }
    }

    // MARK: - Deneme Sınavı

    func startExam() async {
        isWorking = true
        banner = nil
        defer { isWorking = false }
        do {
            let r = try await APIService.generateExam()
            if r.questions.isEmpty {
                banner = "Sınav oluşturulamadı, lütfen tekrar dene."
            } else {
                destination = .exam(questions: r.questions, durationSec: r.durationSec)
            }
        } catch {
            banner = error.localizedDescription
        }
    }

    // MARK: - Cümle İçinde Kullanım

    func startSentenceUsage() async {
        if blockIfLocked(.sentenceUsage) { return }
        isWorking = true
        banner = nil
        defer { isWorking = false }
        do {
            let resp = try await APIService.sentenceExercises()
            if resp.exercises.isEmpty {
                banner = "Şu an alıştırma oluşturulamadı. Önce birkaç kelime çalış, sonra tekrar dene."
            } else {
                destination = .sentenceUsage(resp.exercises)
            }
        } catch {
            banner = error.localizedDescription
        }
    }

    // MARK: - Okuma Parçası (öğrenilen kelimelerden)

    func startReading() async {
        isWorking = true
        banner = nil
        defer { isWorking = false }
        do {
            let r = try await APIService.readingFromReview()
            destination = .reading(content: r.content, wordCount: r.wordCount, targets: r.targetWordTexts ?? [], glossary: r.glossary ?? [])
        } catch {
            banner = error.localizedDescription
        }
    }

    /// Belirli bir konu/senaryo hakkında (isteğe bağlı diyalog) okuma parçası üretir.
    func startTopicReading(topic: String, asDialogue: Bool) async {
        isWorking = true
        banner = nil
        defer { isWorking = false }
        do {
            let r = try await APIService.readingFromTopic(topic: topic, asDialogue: asDialogue)
            destination = .reading(content: r.content, wordCount: r.wordCount, targets: r.targetWordTexts ?? [], glossary: r.glossary ?? [])
        } catch {
            banner = error.localizedDescription
        }
    }
}
