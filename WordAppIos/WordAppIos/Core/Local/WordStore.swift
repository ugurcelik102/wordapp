import Foundation

enum WordStoreError: LocalizedError {
    case bundleMissing
    case noNewWords

    var errorDescription: String? {
        switch self {
        case .bundleMissing:
            return "Kelime havuzu yüklenemedi."
        case .noNewWords:
            return "Çalışılacak yeni kelime kalmadı. Seviyeni Ayarlar'dan değiştirebilirsin."
        }
    }
}

/// Uygulama paketindeki kelime havuzu ve günlük paket seçimi.
///
/// Sunucudaki `app/services/words.py` seçim mantığının cihaz karşılığıdır:
/// önce seviyedeki görülmemiş kelimeler (tür çeşitliliğiyle), sonra en yakın
/// seviyeler, en son da havuz tükendiyse uzun süredir çalışılmamış kelimeler.
final class WordStore {
    static let shared = WordStore()

    private(set) var all: [LocalWord] = []
    private var byId: [String: LocalWord] = [:]
    private var byLevel: [Int: [LocalWord]] = [:]

    /// Paket başına en az kelime; bunun altındaysa "yeni kelime kalmadı" denir.
    private let minimumPackageSize = 4

    private init() {}

    // MARK: - Yükleme

    var isLoaded: Bool { !all.isEmpty }

    /// `words.json`'ı paketten okur. Tekrar çağrılırsa iş yapmaz.
    func loadIfNeeded() throws {
        guard all.isEmpty else { return }
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
            throw WordStoreError.bundleMissing
        }
        let data = try Data(contentsOf: url)
        let words = try JSONDecoder().decode([LocalWord].self, from: data)
        index(words)
    }

    private func index(_ words: [LocalWord]) {
        all = words
        byId = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        byLevel = Dictionary(grouping: words, by: \.levelId)
    }

    /// Testler için: paketi atlayıp doğrudan kelime listesi yükler.
    func loadForTesting(_ words: [LocalWord]) { index(words) }

    // MARK: - Sorgular

    func word(id: String) -> LocalWord? { byId[id] }

    func words(level: Int) -> [LocalWord] { byLevel[level] ?? [] }

    func words(ids: [String]) -> [LocalWord] { ids.compactMap { byId[$0] } }

    // MARK: - Paket seçimi

    /// Görülmemiş kelimelerden tür (isim/fiil/sıfat…) çeşitliliği olan bir seçki.
    ///
    /// Sıklık sırasına göre geniş bir aday havuzu alınır, sonra türlere göre
    /// sırayla seçilir; böylece paket tek türe kilitlenmez.
    func pickDiverseNewWords(
        levelId: Int,
        limit: Int,
        seenIds: Set<String>,
        excluding: Set<String> = [],
        sameLevelOnly: Bool = true
    ) -> [LocalWord] {
        guard limit > 0 else { return [] }

        var candidates = all.filter {
            !seenIds.contains($0.id)
                && !excluding.contains($0.id)
                && (!sameLevelOnly || $0.levelId == levelId)
        }
        guard !candidates.isEmpty else { return [] }

        candidates.sort { a, b in
            if !sameLevelOnly {
                let da = abs(a.levelId - levelId), db = abs(b.levelId - levelId)
                if da != db { return da < db }
            }
            // frequency_rank yoksa en sona.
            return (a.frequencyRank ?? .max) < (b.frequencyRank ?? .max)
        }
        let pool = Array(candidates.prefix(max(limit * 25, 100)))

        var buckets: [String: [LocalWord]] = [:]
        for w in pool {
            buckets[(w.partOfSpeech ?? "other").lowercased(), default: []].append(w)
        }
        // Az bulunan türler öne gelsin ki isim/fiil çoğunluğu her şeyi doldurmasın.
        let order = buckets.keys.sorted {
            let ca = buckets[$0]?.count ?? 0, cb = buckets[$1]?.count ?? 0
            return ca == cb ? $0 < $1 : ca < cb
        }

        var picked: [LocalWord] = []
        var cursor = [String: Int]()
        while picked.count < limit {
            var added = false
            for pos in order {
                guard picked.count < limit else { break }
                let i = cursor[pos] ?? 0
                guard let bucket = buckets[pos], i < bucket.count else { continue }
                picked.append(bucket[i])
                cursor[pos] = i + 1
                added = true
            }
            if !added { break }
        }
        return picked
    }

    /// Günlük paketin kelimelerini seçer.
    ///
    /// "Yeni Kelimeler" görevi YALNIZCA hiç görülmemiş kelimelerden oluşur;
    /// tekrar edilecekler ayrı "Kelime Tekrarı" görevinde çalışılır.
    /// - Parameters:
    ///   - recentIds: son 14 günün paketlerinde geçen kelimeler (tükenmiş
    ///     havuzda bile her gün aynı liste gelmesin diye elenir).
    ///   - lastReviewedAt: kelime bazında son çalışma zamanı (fallback sırası için).
    func selectPackageWords(
        levelId: Int,
        count: Int,
        seenIds: Set<String>,
        recentIds: Set<String>,
        lastReviewedAt: [String: Date]
    ) throws -> [LocalWord] {
        var picked = pickDiverseNewWords(
            levelId: levelId, limit: count, seenIds: seenIds
        )

        // Seviyede görülmemiş kelime kalmadıysa en yakın seviyelerden doldur.
        if picked.count < count {
            picked += pickDiverseNewWords(
                levelId: levelId,
                limit: count - picked.count,
                seenIds: seenIds,
                excluding: Set(picked.map(\.id)),
                sameLevelOnly: false
            )
        }

        // Havuz tamamen tükendiyse: son 14 günde gelmemiş, en uzun süredir
        // çalışılmamış kelimeleri rastgelelik katarak yeniden kullan.
        if picked.count < count {
            let chosen = Set(picked.map(\.id))
            let fallback = all
                .filter { seenIds.contains($0.id) }
                .filter { !chosen.contains($0.id) && !recentIds.contains($0.id) }
                .sorted { a, b in
                    let da = lastReviewedAt[a.id], db = lastReviewedAt[b.id]
                    switch (da, db) {
                    case (nil, nil): return Bool.random()
                    case (nil, _):   return true          // hiç çalışılmamış önce
                    case (_, nil):   return false
                    case let (x?, y?): return x == y ? Bool.random() : x < y
                    }
                }
            picked += fallback.prefix(count - picked.count)
        }

        guard picked.count >= minimumPackageSize else { throw WordStoreError.noNewWords }
        return Array(picked.prefix(count))
    }
}
