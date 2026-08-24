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
    static let blue       = Color.accentBlue
    static let green      = Color.success
    static let red        = Color.danger
    /// Tam-ekran zemin — "Kelime Tekrarı" kartıyla aynı sarı ton.
    static let backdrop   = Color.taskYellow
    /// Kart ve çip dolgusu — görev yeşili.
    static let cardFill   = Color.taskGreen
    /// Kart içindeki çipler (yeşil üstünde yeşil olmasın diye koyu ton).
    static let chipInCard = Color.taskGreenDark
    /// Yeşil üzerindeki metin/ikon — aynı sarı ton.
    static let onCard     = Color.taskYellow
    /// Sarı zemin üzerindeki başlık/ikon — koyu yeşil (okunabilirlik).
    static let onBackdrop = Color.taskGreenDark
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
            SUTheme.backdrop.ignoresSafeArea()

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
        // Görev bitti → bugünlük "Cümle İçinde Kullanım" tamamlandı olarak işaretlenir.
        .onChange(of: vm.finished) { _, isFinished in
            guard isFinished else { return }
            Task { _ = try? await APIService.completeDailyTask(.sentenceUsage) }
        }
    }

    private func submit(correct: Bool, exercise: SentenceExercise) {
        FeedbackSound.play(correct: correct)
        vm.record(correct: correct)
        feedback = FeedbackData(correct: correct, exercise: exercise)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(SUTheme.onBackdrop)
                }
                Spacer()
                Text("CÜMLE İÇİNDE KULLANIM")
                    .font(.subheadline.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(SUTheme.onBackdrop)
                Spacer()
                // denge için görünmez ikon
                Image(systemName: "xmark").opacity(0)
            }

            ProgressView(value: vm.progress)
                .tint(SUTheme.onBackdrop)
        }
        .padding()
    }

    private var summary: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(SUTheme.onBackdrop)
            Text("Alıştırma Bitti!")
                .font(.title.bold())
                .foregroundStyle(SUTheme.onBackdrop)
            Text("\(vm.correctCount) / \(vm.exercises.count) doğru")
                .font(.title3)
                .foregroundStyle(SUTheme.onBackdrop.opacity(0.85))
            Spacer()
            Button(action: onDone) {
                Text("Bitti")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(SUTheme.cardFill)
                    .foregroundStyle(SUTheme.onCard)
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
            .background(SUTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .softShadow(.elevated)
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
        .foregroundStyle(SUTheme.onCard)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(SUTheme.onCard.opacity(0.18))
        .clipShape(Capsule())
    }
}

/// Seçilen kelimeyi geri almak için açık etiketli buton.
/// (Kelimeye dokunup geri almak kullanıcılar için anlaşılır değildi.)
private struct SilButton: View {
    var title: String = "Sil"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "delete.left.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(SUTheme.onCard)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().stroke(SUTheme.onCard.opacity(0.6), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CevaplaButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Cevapla")
                .fontWeight(.semibold)
                .foregroundStyle(SUTheme.cardFill)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(enabled ? SUTheme.onCard : SUTheme.onCard.opacity(0.45))
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
    /// Kart içindeki (yeşil zemin üstündeki) çipler koyu yeşil dolgu kullanır.
    var inCard: Bool = false
    let action: () -> Void

    private var fill: Color {
        let base = inCard ? SUTheme.chipInCard : SUTheme.cardFill
        return faded ? base.opacity(0.35) : base
    }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(faded ? SUTheme.onCard.opacity(0.45) : SUTheme.onCard)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .shadow(color: .black.opacity(faded ? 0 : 0.12), radius: 3, y: 2)
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
                        .foregroundStyle(SUTheme.onCard.opacity(0.8))

                    Text(exercise.prompt)
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(SUTheme.onCard)

                    HStack(spacing: 16) {
                        audioButton(icon: "tortoise.fill") {
                            SpeechPlayer.shared.speak(exercise.prompt, language: speechLang, rate: .slow)
                        }
                        audioButton(icon: "speaker.wave.2.fill") {
                            SpeechPlayer.shared.speak(exercise.prompt, language: speechLang)
                        }
                    }

                    Divider().overlay(SUTheme.onCard.opacity(0.35))

                    // Kurulan cümle
                    FlowLayout(spacing: 8) {
                        ForEach(Array(placed.enumerated()), id: \.offset) { pos, idx in
                            WordChip(text: chips[idx], inCard: true) {
                                placed.remove(at: pos)
                            }
                        }
                    }
                    .frame(minHeight: 60, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !placed.isEmpty {
                        HStack(spacing: 10) {
                            Spacer()
                            SilButton { placed.removeLast() }
                            SilButton(title: "Temizle") { placed.removeAll() }
                        }
                    }
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
            }
            .padding(.horizontal, 4)
        }
        .padding()
    }

    private func audioButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(SUTheme.onCard)
                .frame(width: 52, height: 52)
                .overlay(Circle().stroke(SUTheme.onCard.opacity(0.5), lineWidth: 1.5))
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
                        .foregroundStyle(SUTheme.onCard.opacity(0.8))

                    Text(exercise.turkish)
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(SUTheme.onCard)

                    Divider().overlay(SUTheme.onCard.opacity(0.35))

                    Text(blankAttributed)
                        .font(.system(size: 22))
                        .foregroundStyle(SUTheme.onCard)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)

                    if selected != nil {
                        HStack {
                            Spacer()
                            SilButton { selected = nil }
                        }
                    }
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
            attr[range].foregroundColor = .white
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
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .fill(Color.cardBackground)
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
