import SwiftUI
import Combine

@MainActor
final class ExamViewModel: ObservableObject {
    let questions: [ExamQuestion]
    let durationSec: Int

    @Published var index = 0
    @Published var answers: [Int: Int] = [:]   // soru index -> seçilen şık index
    @Published var finished = false

    init(questions: [ExamQuestion], durationSec: Int) {
        self.questions = questions
        self.durationSec = durationSec
    }

    var current: ExamQuestion { questions[index] }
    var progress: Double { questions.isEmpty ? 0 : Double(index + 1) / Double(questions.count) }

    var correctCount: Int {
        var c = 0
        for (i, q) in questions.enumerated() {
            if let sel = answers[i], sel < q.options.count, q.options[sel] == q.answer { c += 1 }
        }
        return c
    }

    func isCorrect(_ i: Int) -> Bool {
        let q = questions[i]
        guard let sel = answers[i], sel < q.options.count else { return false }
        return q.options[sel] == q.answer
    }

    func select(_ optionIndex: Int) { answers[index] = optionIndex }
    func goNext() { if index + 1 < questions.count { index += 1 } else { finished = true } }
    func goPrev() { if index > 0 { index -= 1 } }
    func finish() { finished = true }
}

struct ExamFlowView: View {
    let onDone: () -> Void
    @StateObject private var vm: ExamViewModel
    @State private var remaining: Int
    @State private var showQuit = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(questions: [ExamQuestion], durationSec: Int, onDone: @escaping () -> Void) {
        self.onDone = onDone
        _vm = StateObject(wrappedValue: ExamViewModel(questions: questions, durationSec: durationSec))
        _remaining = State(initialValue: durationSec)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if vm.finished {
                ExamResultsView(vm: vm, onDone: onDone)
            } else {
                questionArea
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onReceive(ticker) { _ in
            guard !vm.finished else { return }
            if remaining > 0 { remaining -= 1 }
            if remaining <= 0 { vm.finished = true }
        }
        .alert("Sınavdan çık?", isPresented: $showQuit) {
            Button("Devam et", role: .cancel) {}
            Button("Çık", role: .destructive) { onDone() }
        } message: {
            Text("İlerlemen kaydedilmeyecek.")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button { showQuit = true } label: {
                    Image(systemName: "xmark").foregroundStyle(.secondary)
                }
                Spacer()
                if !vm.finished {
                    Label(timeString, systemImage: "clock")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(remaining <= 60 ? .red : .primary)
                }
                Spacer()
                Text("\(vm.index + 1)/\(vm.questions.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: vm.progress).tint(.purple)
        }
        .padding()
    }

    private var timeString: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private var questionArea: some View {
        let q = vm.current
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(q.type == "grammar" ? "GRAMER" : "KELİME")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.purple)

                    Text(q.question)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 12) {
                        ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                            let selected = vm.answers[vm.index] == idx
                            Button { vm.select(idx) } label: {
                                HStack {
                                    Text(opt)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(selected ? .purple : .secondary)
                                }
                                .padding()
                                .background(selected ? Color.purple.opacity(0.12) : Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }

            HStack(spacing: 12) {
                Button { vm.goPrev() } label: {
                    Text("Önceki").frame(maxWidth: .infinity).frame(height: 50)
                }
                .buttonStyle(.bordered)
                .disabled(vm.index == 0)

                if vm.index + 1 < vm.questions.count {
                    Button { vm.goNext() } label: {
                        Text("Sonraki").frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent).tint(.purple)
                } else {
                    Button { vm.finish() } label: {
                        Text("Bitir").frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                }
            }
            .padding()
        }
    }
}

// MARK: - Sonuç + inceleme

private struct ExamResultsView: View {
    @ObservedObject var vm: ExamViewModel
    let onDone: () -> Void

    private var percent: Int {
        guard !vm.questions.isEmpty else { return 0 }
        return Int((Double(vm.correctCount) / Double(vm.questions.count)) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("%\(percent)")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(.purple)
                        Text("\(vm.correctCount) / \(vm.questions.count) doğru")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    ForEach(Array(vm.questions.enumerated()), id: \.offset) { i, q in
                        reviewRow(i, q)
                    }
                }
                .padding()
            }

            Button { onDone() } label: {
                Text("Bitti")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent).tint(.purple)
            .padding()
        }
    }

    @ViewBuilder
    private func reviewRow(_ i: Int, _ q: ExamQuestion) -> some View {
        let correct = vm.isCorrect(i)
        let sel = vm.answers[i]
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(correct ? .green : .red)
                Text("Soru \(i + 1)").font(.subheadline.weight(.semibold))
            }
            Text(q.question).font(.subheadline).fixedSize(horizontal: false, vertical: true)

            if let sel, sel < q.options.count, !correct {
                Text("Senin cevabın: \(q.options[sel])")
                    .font(.caption).foregroundStyle(.red)
            } else if sel == nil {
                Text("Boş bırakıldı").font(.caption).foregroundStyle(.secondary)
            }
            Text("Doğru: \(q.answer)")
                .font(.caption).foregroundStyle(.green)
            if let ex = q.explanation, !ex.isEmpty {
                Text(ex).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
