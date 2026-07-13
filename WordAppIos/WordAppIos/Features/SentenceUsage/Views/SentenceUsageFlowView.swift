import SwiftUI
import Combine

// MARK: - Basit akış tabanlı wrap layout (çipler için)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Ortak renkler

private enum SUTheme {
    static let blue    = Color(red: 0.16, green: 0.60, blue: 0.93)
    static let orange  = Color(red: 0.96, green: 0.62, blue: 0.10)
    static let orangeSoft = Color(red: 0.99, green: 0.83, blue: 0.52)
    static let green   = Color(red: 0.18, green: 0.70, blue: 0.30)
    static let red     = Color(red: 0.86, green: 0.24, blue: 0.24)
}

// MARK: - ViewModel

@MainActor
final class SentenceUsageViewModel: ObservableObject {
    @Published var index = 0
    @Published var correctCount = 0
    @Published var finished = false

    let exercises: [SentenceExercise]

    init(exercises: [SentenceExercise]) { self.exercises = exercises }

    var current: SentenceExercise? { index < exercises.count ? exercises[index] : nil }
    var progress: Double { exercises.isEmpty ? 0 : Double(index) / Double(exercises.count) }

    func record(correct: Bool) {
        if correct { correctCount += 1 }
    }

    func advance() {
        if index + 1 < exercises.count { index += 1 } else { finished = true }
    }
}

// MARK: - Akış görünümü

struct SentenceUsageFlowView: View {
    let onDone: () -> Void
    @StateObject private var vm: SentenceUsageViewModel
    @State private var feedback: FeedbackData?

    struct FeedbackData: Identifiable {
        let id = UUID()
        let correct: Bool
        let exercise: SentenceExercise
    }

    init(exercises: [SentenceExercise], onDone: @escaping () -> Void) {
        self.onDone = onDone
        _vm = StateObject(wrappedValue: SentenceUsageViewModel(exercises: exercises))
    }

    var body: some View {
        ZStack {
            SUTheme.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if vm.finished {
                    summary
                } else if let ex = vm.current {
                    Group {
                        if ex.type == "order" {
                            OrderExerciseView(exercise: ex) { correct in
                                submit(correct: correct, exercise: ex)
                            }
                        } else {
                            BlankExerciseView(exercise: ex) { correct in
                                submit(correct: correct, exercise: ex)
                            }
                        }
                    }
                    .id(ex.id)
                }
            }

            if feedback != nil {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if let fb = feedback {
                FeedbackSheet(feedback: fb) {
                    feedback = nil
                    vm.advance()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: feedback?.id)
    }

    private func submit(correct: Bool, exercise: SentenceExercise) {
        vm.record(correct: correct)
        feedback = FeedbackData(correct: correct, exercise: exercise)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("CÜMLE İÇİNDE KULLANIM")
                    .font(.subheadline.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                Spacer()
                // denge için görünmez ikon
                Image(systemName: "xmark").opacity(0)
            }

            ProgressView(value: vm.progress)
                .tint(.white)
        }
        .padding()
    }

    private var summary: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.white)
            Text("Alıştırma Bitti!")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("\(vm.correctCount) / \(vm.exercises.count) doğru")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Button(action: onDone) {
                Text("Bitti")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white)
                    .foregroundStyle(SUTheme.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
    }
}

// MARK: - Kart kabuğu (beyaz)

private struct CardShell<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .frame(maxWidth: .infinity)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

private struct AIBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption2)
            Text("AI")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(Color.purple)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.purple.opacity(0.12))
        .clipShape(Capsule())
    }
}

private struct CevaplaButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Cevapla")
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(enabled ? SUTheme.orange : SUTheme.orangeSoft)
                .clipShape(RoundedRectangle(cornerRadius: 26))
        }
        .disabled(!enabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Çip görünümü

private struct WordChip: View {
    let text: String
    var faded: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(faded ? Color.secondary.opacity(0.4) : Color.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(faded ? Color(.systemGray5) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(faded ? 0 : 0.10), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(faded)
    }
}

// MARK: - Sıralama alıştırması (order)

struct OrderExerciseView: View {
    let exercise: SentenceExercise
    let onAnswer: (Bool) -> Void

    @State private var placed: [Int] = []   // exercise.chips içindeki index'ler, sırayla

    private var chips: [String] { exercise.chips ?? [] }
    private var usedSet: Set<Int> { Set(placed) }
    private var built: [String] { placed.map { chips[$0] } }
    private var speechLang: String { exercise.promptLang == "tr" ? "tr-TR" : "en-US" }

    var body: some View {
        VStack(spacing: 16) {
            CardShell {
                VStack(spacing: 16) {
                    HStack { AIBadge(); Spacer() }

                    Text("CÜMLEYİ OLUŞTURUN")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(exercise.prompt)
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)

                    HStack(spacing: 16) {
                        audioButton(icon: "tortoise.fill") {
                            SpeechPlayer.shared.speak(exercise.prompt, language: speechLang, rate: .slow)
                        }
                        audioButton(icon: "speaker.wave.2.fill") {
                            SpeechPlayer.shared.speak(exercise.prompt, language: speechLang)
                        }
                    }

                    Divider()

                    // Kurulan cümle
                    FlowLayout(spacing: 8) {
                        ForEach(Array(placed.enumerated()), id: \.offset) { pos, idx in
                            WordChip(text: chips[idx]) {
                                placed.remove(at: pos)
                            }
                        }
                    }
                    .frame(minHeight: 60, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)

                CevaplaButton(enabled: !placed.isEmpty) {
                    let correct = built == (exercise.answerTokens ?? [])
                    onAnswer(correct)
                }
            }

            Spacer(minLength: 8)

            // Kelime bankası
            FlowLayout(spacing: 10) {
                ForEach(Array(chips.enumerated()), id: \.offset) { idx, chip in
                    WordChip(text: chip, faded: usedSet.contains(idx)) {
                        if !usedSet.contains(idx) { placed.append(idx) }
                    }
                }
                if !placed.isEmpty {
                    Button {
                        placed.removeLast()
                    } label: {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(SUTheme.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
    }

    private func audioButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(SUTheme.blue)
                .frame(width: 52, height: 52)
                .overlay(Circle().stroke(SUTheme.blue.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Boşluk doldurma alıştırması (blank)

struct BlankExerciseView: View {
    let exercise: SentenceExercise
    let onAnswer: (Bool) -> Void

    @State private var selected: Int?

    private var options: [String] { exercise.options ?? [] }

    var body: some View {
        VStack(spacing: 16) {
            CardShell {
                VStack(spacing: 16) {
                    HStack { AIBadge(); Spacer() }

                    Text("EKSİK KELİMEYİ BUL")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(exercise.turkish)
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)

                    Divider()

                    Text(blankAttributed)
                        .font(.system(size: 22))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)
                }
                .padding(20)

                CevaplaButton(enabled: selected != nil) {
                    let correct = selected.map { options[$0] == exercise.word } ?? false
                    onAnswer(correct)
                }
            }

            Spacer(minLength: 8)

            // Seçenekler
            FlowLayout(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                    WordChip(text: opt, faded: selected == idx) {
                        selected = idx
                    }
                }
                if selected != nil {
                    Button { selected = nil } label: {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(SUTheme.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
    }

    private var blankAttributed: AttributedString {
        let filled = selected.map { options[$0] }
        let placeholder = filled ?? "______"
        let full = (exercise.blankEnglish ?? "").replacingOccurrences(of: "____", with: placeholder)
        var attr = AttributedString(full)
        if filled != nil, let range = attr.range(of: placeholder) {
            attr[range].foregroundColor = SUTheme.blue
            attr[range].font = .system(size: 22, weight: .bold)
        }
        return attr
    }
}

// MARK: - Geri bildirim paneli

private struct FeedbackSheet: View {
    let feedback: SentenceUsageFlowView.FeedbackData
    let onContinue: () -> Void

    private var accent: Color { feedback.correct ? SUTheme.green : SUTheme.red }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(feedback.correct ? "Doğru" : "Yanlış")
                .font(.title2.bold())
                .foregroundStyle(accent)

            Text("Doğru cevap:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(feedback.exercise.turkish)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(feedback.exercise.english)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    SpeechPlayer.shared.speak(feedback.exercise.english)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(SUTheme.blue)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button(action: onContinue) {
                Text("Devam Et")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .ignoresSafeArea(edges: .bottom)
        )
        .onAppear {
            // Doğru/yanlış fark etmeksizin cevabın İngilizcesini otomatik seslendir
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                SpeechPlayer.shared.speak(feedback.exercise.english)
            }
        }
    }
}
