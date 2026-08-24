import SwiftUI
import Combine

@MainActor
final class FullTestViewModel: ObservableObject {
    @Published var words: [PackageWord]
    @Published var index = 0
    @Published var batchCorrect = 0
    @Published var totalCorrect = 0
    @Published var totalAnswered = 0
    @Published var batchDone = false
    @Published var finished = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private(set) var offset: Int
    let total: Int
    private var didSave = false

    init(words: [PackageWord], offset: Int, total: Int) {
        self.words = words
        self.offset = offset
        self.total = total
    }

    /// Test sonucunu kaydeder (bir kez).
    func saveResult() async {
        guard !didSave, totalAnswered > 0 else { return }
        didSave = true
        _ = try? await APIService.saveTestResult(correct: totalCorrect, total: totalAnswered)
    }

    var current: PackageWord? { index < words.count ? words[index] : nil }
    var hasMore: Bool { offset + words.count < total }
    var batchNumber: Int { offset / 8 + 1 }

    /// İngilizce kelime → Türkçe şıklar (doğru + 3 çeldirici, aynı paketten).
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

    func answer(_ correct: Bool) {
        totalAnswered += 1
        if correct { batchCorrect += 1; totalCorrect += 1 }
        if index + 1 < words.count {
            index += 1
        } else {
            batchDone = true
        }
    }

    func continueNextBatch() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await APIService.learnedWords(offset: offset + words.count, limit: 8)
            if resp.words.isEmpty {
                finished = true
            } else {
                offset = resp.offset
                words = resp.words
                index = 0
                batchCorrect = 0
                batchDone = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FullTestFlowView: View {
    let onDone: () -> Void
    @StateObject private var vm: FullTestViewModel

    init(words: [PackageWord], offset: Int, total: Int, onDone: @escaping () -> Void) {
        self.onDone = onDone
        _vm = StateObject(wrappedValue: FullTestViewModel(words: words, offset: offset, total: total))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .overlay {
            if vm.isLoading {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView("Sonraki paket hazırlanıyor...")
                        .padding(24)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func exit() {
        Task { await vm.saveResult(); onDone() }
    }

    private var header: some View {
        HStack {
            Button { exit() } label: {
                Image(systemName: "xmark").foregroundStyle(.secondary)
            }
            Spacer()
            Text("Kelime Testi").font(.headline)
            Spacer()
            if !vm.batchDone && !vm.finished {
                Text("\(min(vm.index + 1, vm.words.count)) / \(vm.words.count)")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Image(systemName: "xmark").opacity(0)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if vm.finished {
            finishedView
        } else if vm.batchDone {
            batchPrompt
        } else if let word = vm.current {
            MCQView(
                word: word,
                options: vm.mcqOptions(for: word),
                correctAnswer: word.definitionTr ?? word.definition
            ) { correct in
                vm.answer(correct)
            }
            .id(word.id)
        }
    }

    private var batchPrompt: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("\(vm.batchNumber). paket tamamlandı")
                .font(.title2.bold())
            Text("\(vm.batchCorrect) / \(vm.words.count) doğru")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(vm.hasMore ? "Devam etmek ister misin?" : "Bu son paketti!")
                .foregroundStyle(.secondary)
            Spacer()
            VStack(spacing: 12) {
                if vm.hasMore {
                    Button { Task { await vm.continueNextBatch() } } label: {
                        Text("Devam Et")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)

                    Button { exit() } label: {
                        Text("Bitir")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button { vm.finished = true } label: {
                        Text("Sonucu Gör")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .padding()
    }

    private var finishedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "star.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)
            Text("Tebrikler!")
                .font(.title.bold())
            Text("Öğrendiğin tüm kelimeleri test ettin.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Toplam: \(vm.totalCorrect) / \(vm.totalAnswered) doğru")
                .font(.headline)
                .padding(.top, 4)
            Spacer()
            Button { exit() } label: {
                Text("Bitti")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding()
        .onAppear { Task { await vm.saveResult() } }
    }
}
