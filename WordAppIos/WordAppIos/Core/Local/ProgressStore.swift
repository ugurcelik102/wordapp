import Combine
import Foundation

// MARK: - Diskteki kayıt tipleri

struct WordProgressRecord: Codable, Hashable {
    var status: WordStatus = .new
    var easeFactor: Double = 2.5
    var intervalDays: Int = 0
    var repetitions: Int = 0
    var lastReviewedAt: Date?
    var nextReviewDate: Date?
    var timesSeen: Int = 0
    var timesCorrect: Int = 0

    /// Kullanıcı bu kelimeyi en az bir kez çalıştı mı (yeni kelime havuzundan düşer).
    var isStudied: Bool { status != .new || timesSeen > 0 }
}

struct StoredPackage: Codable, Hashable {
    var id: String
    var day: String            // "yyyy-MM-dd"
    var wordIds: [String]
    var completed: Bool = false
}

struct StoredTestResult: Codable, Hashable {
    var correct: Int
    var total: Int
    var takenAt: Date
}

/// Diske yazılan tüm kullanıcı durumu. Eskiden Postgres'te duran ne varsa burada.
struct ProgressSnapshot: Codable {
    var levelId: Int?
    var placementCompleted = false
    var dailyWordCount = UserSettings.defaultDailyWordCount
    var readingFontSize: Double = 17

    var words: [String: WordProgressRecord] = [:]
    var packages: [String: StoredPackage] = [:]      // gün -> paket
    var completedTasks: [String: [String]] = [:]     // gün -> görev anahtarları
    var testResults: [StoredTestResult] = []
}

// MARK: - Depo

/// Kullanıcının tüm ilerlemesini cihazda tutar (sunucu ve üyelik yok).
///
/// Veri, Application Support altında tek bir JSON dosyasında saklanır; kayıt
/// arka planda ve sıraya alınarak yapılır, böylece her cevapta ana iş parçacığı
/// bloklanmaz.
@MainActor
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    @Published private(set) var snapshot = ProgressSnapshot()

    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "vocabee.progress.io", qos: .utility)

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("progress.json")
        load()
    }

    // MARK: Kalıcılık

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(ProgressSnapshot.self, from: data)
        else { return }
        snapshot = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let url = fileURL
        ioQueue.async {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Testler için: her şeyi sıfırlar.
    func resetForTesting() {
        snapshot = ProgressSnapshot()
        save()
    }

    // MARK: Profil / ayarlar

    var levelId: Int { snapshot.levelId ?? 3 }          // varsayılan B1
    var levelCode: String { AppLevel.code(for: levelId) }
    var placementCompleted: Bool { snapshot.placementCompleted }
    var dailyWordCount: Int { snapshot.dailyWordCount }
    var readingFontSize: Double { snapshot.readingFontSize }

    func setLevel(_ id: Int) {
        snapshot.levelId = id
        save()
    }

    func completePlacement(levelId: Int) {
        snapshot.levelId = levelId
        snapshot.placementCompleted = true
        save()
    }

    func setDailyWordCount(_ count: Int) {
        snapshot.dailyWordCount = count
        save()
    }

    func setReadingFontSize(_ size: Double) {
        snapshot.readingFontSize = size
        save()
    }

    // MARK: Kelime ilerlemesi

    func progress(for wordId: String) -> WordProgressRecord? { snapshot.words[wordId] }

    /// Çalışılmış (en az bir kez sunulmuş) kelimelerin kimlikleri.
    var studiedWordIds: Set<String> { Set(snapshot.words.keys) }

    /// Öğrenilmiş sayılan kelimeler: learning / review / mastered.
    var learnedWordIds: [String] {
        snapshot.words
            .filter { $0.value.status != .new }
            .sorted { ($0.value.lastReviewedAt ?? .distantPast) > ($1.value.lastReviewedAt ?? .distantPast) }
            .map(\.key)
    }

    /// Kelime pakete girdiğinde "görüldü" olarak işaretlenir.
    func markPresented(_ wordIds: [String]) {
        for id in wordIds where snapshot.words[id] == nil {
            snapshot.words[id] = WordProgressRecord()
        }
        save()
    }

    /// Bir cevabı kaydeder ve SM-2 ile bir sonraki tekrarı hesaplar.
    func recordAnswer(wordId: String, isCorrect: Bool) {
        var rec = snapshot.words[wordId] ?? WordProgressRecord()
        let result = SRS.update(
            easeFactor: rec.easeFactor,
            intervalDays: rec.intervalDays,
            repetitions: rec.repetitions,
            isCorrect: isCorrect
        )
        rec.easeFactor = result.easeFactor
        rec.intervalDays = result.intervalDays
        rec.repetitions = result.repetitions
        rec.nextReviewDate = result.nextReviewDate
        rec.lastReviewedAt = Date()
        rec.timesSeen += 1
        if isCorrect { rec.timesCorrect += 1 }
        rec.status = SRS.newStatus(repetitions: rec.repetitions, intervalDays: rec.intervalDays)
        snapshot.words[wordId] = rec
        save()
    }

    /// Tekrar zamanı gelmiş kelimeler (en geciken önce).
    func dueReviewWords(limit: Int = 10) -> [LocalWord] {
        let today = Date.today
        let due = snapshot.words
            .filter { $0.value.status == .learning || $0.value.status == .review }
            .filter { ($0.value.nextReviewDate ?? today) <= today }
            .sorted { ($0.value.nextReviewDate ?? .distantPast) < ($1.value.nextReviewDate ?? .distantPast) }
            .prefix(limit)
            .map(\.key)
        return WordStore.shared.words(ids: Array(due))
    }

    // MARK: Günlük paket

    func package(for day: Date = Date()) -> StoredPackage? {
        snapshot.packages[day.dayKey]
    }

    /// Son `days` günün paketlerinde geçen kelimeler.
    func recentPackageWordIds(days: Int = 14) -> Set<String> {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date.today) ?? Date.today
        var ids = Set<String>()
        for (day, pkg) in snapshot.packages {
            guard let date = Self.date(fromDayKey: day), date >= cutoff else { continue }
            ids.formUnion(pkg.wordIds)
        }
        return ids
    }

    /// Bugünkü paketi döner; yoksa oluşturur.
    func todayPackage() throws -> StoredPackage {
        if let existing = package() { return existing }
        return try createPackage(replacingToday: false)
    }

    /// Yeni paket oluşturur (bugünkü varsa değiştirir).
    @discardableResult
    func createPackage(replacingToday: Bool = true) throws -> StoredPackage {
        let day = Date().dayKey
        if !replacingToday, let existing = snapshot.packages[day] { return existing }

        let words = try WordStore.shared.selectPackageWords(
            levelId: levelId,
            count: dailyWordCount,
            seenIds: studiedWordIds,
            recentIds: recentPackageWordIds(),
            lastReviewedAt: snapshot.words.compactMapValues(\.lastReviewedAt)
        )
        let pkg = StoredPackage(id: UUID().uuidString, day: day, wordIds: words.map(\.id))
        snapshot.packages[day] = pkg
        markPresented(pkg.wordIds)     // markPresented zaten kaydediyor
        return pkg
    }

    func completeTodayPackage() {
        let day = Date().dayKey
        snapshot.packages[day]?.completed = true
        save()
    }

    // MARK: Günlük görevler

    private static let taskOrder: [DailyTaskKey] = [.review, .newWords, .sentenceUsage]

    func completedTaskKeys(for day: Date = Date()) -> Set<DailyTaskKey> {
        var keys = Set((snapshot.completedTasks[day.dayKey] ?? []).compactMap(DailyTaskKey.init))
        // "Yeni Kelimeler" paket durumundan da türetilir (geriye dönük uyum).
        if package(for: day)?.completed == true { keys.insert(.newWords) }
        return keys
    }

    func markTaskCompleted(_ key: DailyTaskKey, day: Date = Date()) {
        var keys = snapshot.completedTasks[day.dayKey] ?? []
        if !keys.contains(key.rawValue) { keys.append(key.rawValue) }
        snapshot.completedTasks[day.dayKey] = keys
        save()
    }

    /// Ana ekrandaki sıralı görev durumu: önceki bitmeden sonraki açılmaz.
    func dailyTasksStatus() -> DailyTasksStatus {
        let done = completedTaskKeys()
        var previousDone = true
        var items: [DailyTaskItem] = []
        for (index, key) in Self.taskOrder.enumerated() {
            let isDone = done.contains(key)
            items.append(DailyTaskItem(
                key: key,
                order: index + 1,
                completed: isDone,
                unlocked: previousDone && !isDone
            ))
            previousDone = previousDone && isDone
        }
        return DailyTasksStatus(date: Date().dayKey, tasks: items)
    }

    // MARK: Test sonuçları

    func addTestResult(correct: Int, total: Int) {
        snapshot.testResults.append(
            StoredTestResult(correct: correct, total: total, takenAt: Date())
        )
        save()
    }

    func progressSummary() -> ProgressSummary {
        let results = snapshot.testResults.sorted { $0.takenAt > $1.takenAt }
        let scored = results.filter { $0.total > 0 }
        let avg = scored.isEmpty
            ? 0
            : scored.reduce(0.0) { $0 + Double($1.correct) / Double($1.total) } / Double(scored.count)
        return ProgressSummary(
            testsTaken: results.count,
            avgAccuracy: avg,
            lastCorrect: results.first?.correct,
            lastTotal: results.first?.total,
            recent: results.prefix(10).map {
                TestResultItem(correct: $0.correct, total: $0.total, takenAt: $0.takenAt.dayKey)
            }
        )
    }

    /// Öğrenilen kelimeleri türüne (part-of-speech) göre gruplar.
    func learnedByCategory() -> [CategoryProgress] {
        let learned = Set(learnedWordIds)
        var learnedCounts: [String: Int] = [:]
        var totals: [String: Int] = [:]
        for w in WordStore.shared.all {
            let key = (w.partOfSpeech ?? "other").lowercased()
            totals[key, default: 0] += 1
            if learned.contains(w.id) { learnedCounts[key, default: 0] += 1 }
        }
        return Set(learnedCounts.keys).union(totals.keys)
            .map {
                CategoryProgress(
                    key: $0,
                    label: Self.posLabel[$0] ?? $0.capitalized,
                    learned: learnedCounts[$0] ?? 0,
                    total: totals[$0] ?? 0
                )
            }
            .sorted { ($0.learned, $0.total) > ($1.learned, $1.total) }
    }

    private static let posLabel: [String: String] = [
        "noun": "İsim", "verb": "Fiil", "adjective": "Sıfat", "adverb": "Zarf",
        "preposition": "Edat", "conjunction": "Bağlaç", "pronoun": "Zamir",
        "determiner": "Belirteç", "article": "Artikel", "interjection": "Ünlem",
        "other": "Diğer",
    ]

    // MARK: Yardımcı

    private static func date(fromDayKey key: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }
}
