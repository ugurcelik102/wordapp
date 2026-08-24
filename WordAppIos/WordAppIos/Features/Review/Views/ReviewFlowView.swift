import SwiftUI
import Combine

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var index = 0
    @Published var details: [String: WordDetail] = [:]
    @Published var isLoading = true
    @Published var correctCount = 0
    @Published var finished = false
    @Published var submitError: String?   // submit başarısızsa kullanıcıya gösterilir

    let words: [PackageWord]

    init(words: [PackageWord]) {
        self.words = words
    }

    var current: PackageWord? {
        guard index < words.count else { return nil }
        return words[index]
    }

    var progress: Double {
        words.isEmpty ? 0 : Double(index) / Double(words.count)
    }

    func load() async {
        await withTaskGroup(of: (String, WordDetail?).self) { group in
            for word in words {
                group.addTask {
                    let detail = try? await APIService.wordDetail(id: word.id)
                    return (word.id, detail)
                }
            }
            for await (id, detail) in group {
                if let detail { details[id] = detail }
            }
        }
        isLoading = false
    }

    func mcqOptions(for word: PackageWord) -> [String] {
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

    func answer(_ correct: Bool) async {
        guard let word = current else { return }
        if correct { correctCount += 1 }

        // Submit hatasını sessizce yutma: başarısız olursa SRS güncellenmez
        // ve kelime tekrar tekrar gelir. Hatayı kullanıcıya ve log'a bildir.
        do {
            _ = try await APIService.submitReview(wordId: word.id, isCorrect: correct)
            submitError = nil
        } catch {
            submitError = "Tekrar sonucu kaydedilemedi. İnternet bağlantını kontrol et."
            print("[Review] submitReview hatası (word=\(word.id)): \(error)")
        }

        if index + 1 < words.count {
            index += 1
        } else {
            finished = true
        }
    }
}

struct ReviewFlowView: View {
    let onDone: () -> Void
    @StateObject private var vm: ReviewViewModel

    init(words: [PackageWord], onDone: @escaping () -> Void) {
        self.onDone = onDone
        _vm = StateObject(wrappedValue: ReviewViewModel(words: words))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Üst bar
            HStack {
                Button {
                    onDone()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Kelime Tekrarı")
                    .font(.headline)
                Spacer()
                Text("\(min(vm.index + 1, vm.words.count)) / \(vm.words.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            ProgressView(value: vm.progress)
                .tint(.green)
                .padding(.horizontal)

            if let submitError = vm.submitError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(submitError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.opacity)
            }

            Divider().padding(.top, 8)

            if vm.isLoading {
                Spacer()
                ProgressView("Tekrar hazırlanıyor...")
                Spacer()
            } else if vm.finished {
                summary
            } else if let word = vm.current {
                MCQView(
                    word: word,
                    options: vm.mcqOptions(for: word),
                    correctAnswer: word.definitionTr ?? word.definition,
                    timerDuration: 6
                ) { correct in
                    Task { await vm.answer(correct) }
                }
                .id(word.id)
            } else {
                Spacer()
                Text("Tekrar edilecek kelime yok.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task { await vm.load() }
        // Görev bitti → bugünlük "Kelime Tekrarı" tamamlandı olarak işaretlenir.
        .onChange(of: vm.finished) { _, isFinished in
            guard isFinished else { return }
            Task { _ = try? await APIService.completeDailyTask(.review) }
        }
    }

    private var summary: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Tekrar Tamamlandı!")
                .font(.title.bold())
            Text("\(vm.correctCount) / \(vm.words.count) doğru")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                onDone()
            } label: {
                Text("Bitti")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}
