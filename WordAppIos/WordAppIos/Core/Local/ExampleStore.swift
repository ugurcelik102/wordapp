import Foundation

/// Yapay zekâyla üretilmiş örnek cümlelerin cihazdaki önbelleği.
///
/// `words.json`'daki kelimelerin çoğunda örnek cümle yok. Öğrenme oturumunda
/// eksikler `/ai/examples`'tan bir kez istenir ve burada saklanır; sonraki
/// gösterimler internetsiz çalışır. Kayıt, ProgressStore gibi Application
/// Support altında tek bir JSON dosyasıdır (kelime id -> örnek).
@MainActor
final class ExampleStore {
    static let shared = ExampleStore()

    private var examples: [String: LocalExample] = [:]
    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "vocabee.examples.io", qos: .utility)

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("examples.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: LocalExample].self, from: data) {
            examples = decoded
        }
    }

    func example(for wordId: String) -> LocalExample? { examples[wordId] }

    /// Pakette de önbellekte de örneği olmayan kelimeler.
    func missing(in words: [LocalWord]) -> [LocalWord] {
        words.filter { $0.examples.isEmpty && examples[$0.id] == nil }
    }

    func store(_ new: [String: LocalExample]) {
        guard !new.isEmpty else { return }
        examples.merge(new) { _, latest in latest }
        guard let data = try? JSONEncoder().encode(examples) else { return }
        let url = fileURL
        ioQueue.async {
            try? data.write(to: url, options: .atomic)
        }
    }
}
