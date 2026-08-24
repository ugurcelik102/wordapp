import SwiftUI
import AVFoundation
import UIKit
import Combine

// MARK: - Telaffuz / TTS oynatıcı

enum SpeechRate {
    case slow, normal, fast

    var multiplier: Float {
        switch self {
        case .slow:   return 0.45
        case .normal: return 0.9
        case .fast:   return 1.6
        }
    }
}

@MainActor
final class SpeechPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechPlayer()
    private let synthesizer = AVSpeechSynthesizer()

    @Published private(set) var isSpeaking = false
    private var pending = 0   // kuyruktaki bitmemiş utterance sayısı

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    private override init() {
        super.init()
        synthesizer.delegate = self
        // Sessiz mod açıkken bile sesin duyulması için audio session'ı yapılandır
        activateSession()
    }

    func speak(_ text: String, language: String = "en-US", rate: SpeechRate = .normal) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        activateSession()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rate.multiplier
        pending = 1
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// Okuma parçası: diyalog ise konuşmacılara farklı ses (kadın/erkek) atar,
    /// değilse tek sesle okur.
    func speakReading(_ text: String, rate: SpeechRate = .normal) {
        let segments = Self.dialogueSegments(text)
        let speakers = Set(segments.compactMap { $0.speaker })
        guard speakers.count >= 2 else {
            speak(text, rate: rate)   // diyalog değil → tek ses
            return
        }

        activateSession()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let (voiceA, voiceB) = Self.dialogueVoices()
        var order: [String] = []
        pending = 0
        for seg in segments {
            let spoken = seg.text.trimmingCharacters(in: .whitespaces)
            guard !spoken.isEmpty else { continue }

            let voice: AVSpeechSynthesisVoice?
            if let sp = seg.speaker {
                if !order.contains(sp) { order.append(sp) }
                let idx = order.firstIndex(of: sp) ?? 0
                voice = (idx % 2 == 0) ? voiceA : voiceB   // ilk konuşmacı A sesi, ikinci B sesi
            } else {
                voice = voiceA
            }

            let utt = AVSpeechUtterance(string: spoken)
            utt.voice = voice
            utt.rate = AVSpeechUtteranceDefaultSpeechRate * rate.multiplier
            utt.postUtteranceDelay = 0.15
            pending += 1
            synthesizer.speak(utt)
        }
        isSpeaking = pending > 0
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        pending = 0
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.pending = max(0, self.pending - 1)
            self.isSpeaking = self.pending > 0
        }
    }

    // MARK: - Diyalog yardımcıları

    private struct Segment { let speaker: String?; let text: String }

    /// Metni satırlara böler; "A: ...", "Tom: ..." gibi konuşmacı etiketlerini ayıklar.
    private static func dialogueSegments(_ text: String) -> [Segment] {
        var result: [Segment] = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if let colon = line.firstIndex(of: ":") {
                let prefix = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                let rest = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                // Konuşmacı etiketi: kısa (≤15) ve en fazla iki kelime — cümle içi ":" değil
                if !prefix.isEmpty, prefix.count <= 15, prefix.split(separator: " ").count <= 2, !rest.isEmpty {
                    result.append(Segment(speaker: prefix.lowercased(), text: rest))
                    continue
                }
            }
            result.append(Segment(speaker: nil, text: line))
        }
        return result
    }

    /// İngilizce bir kadın ve bir erkek ses seçer (yoksa iki farklı sese düşer).
    private static func dialogueVoices() -> (AVSpeechSynthesisVoice?, AVSpeechSynthesisVoice?) {
        let en = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        let female = en.first { $0.gender == .female }
        let male = en.first { $0.gender == .male }
        let v1 = female ?? AVSpeechSynthesisVoice(language: "en-US")
        let v2 = male ?? en.first { $0.identifier != v1?.identifier } ?? v1
        return (v1, v2)
    }
}

struct LearningFlowView: View {
    let package: WordPackage
    let onComplete: () -> Void

    @StateObject private var vm: LearningViewModel
    @EnvironmentObject var appState: AppState

    init(package: WordPackage, onComplete: @escaping () -> Void) {
        self.package = package
        self.onComplete = onComplete
        _vm = StateObject(wrappedValue: LearningViewModel(package: package))
    }

    var body: some View {
        VStack(spacing: 20) {
            if vm.isLoading {
                Spacer()
                ProgressView("Session başlatılıyor...")
                    .tint(.blue)
                Text("Yükleniyor...")
                    .font(.headline)
                    .foregroundColor(.black)
                Spacer()
            } else if let error = vm.errorMessage {
                Spacer()
                Text("Hata: \(error)")
                    .foregroundColor(.red)
                    .padding()
                Button("Tekrar Dene") {
                    Task { await vm.startSession() }
                }
                .buttonStyle(.borderedProminent)
                Button("Kapat") { onComplete() }
                Spacer()
            } else {
                stepView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .task { await vm.startSession() }
    }

    private var stepKey: String {
        switch vm.step {
        case .overview:              return "overview"
        case .mcq(let w, _, _):      return "mcq-\(w.id)"
        case .trToEn(let w, _):      return "trToEn-\(w.id)"
        case .sentence(let w):       return "sentence-\(w.id)"
        case .pronunciation(let w):  return "pron-\(w.id)"
        case .summary:               return "summary"
        case .reading:               return "reading"
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch vm.step {
        case .overview:
            OverviewView(words: vm.words, wordDetails: vm.wordDetails, onDone: {
                vm.overviewDone()
            }, onExit: onComplete)

        case .mcq(let word, let options, let correctAnswer):
            MCQView(word: word, options: options, correctAnswer: correctAnswer) { isCorrect in
                Task { await vm.mcqAnswered(isCorrect: isCorrect) }
            }
            .id("mcq-\(word.id)")

        case .trToEn(let word, let options):
            TrToEnView(word: word, options: options) { isCorrect in
                Task { await vm.trToEnAnswered(isCorrect: isCorrect) }
            }
            .id("tren-\(word.id)")

        case .sentence(let word):
            SentenceView(word: word, detail: vm.wordDetails[word.id]) {
                Task { await vm.sentenceDone() }
            }
            .id("sent-\(word.id)")

        case .pronunciation(let word):
            PronunciationView(word: word) {
                Task { await vm.pronunciationDone() }
            }
            .id("pron-\(word.id)")

        case .summary(let summary):
            SummaryView(
                summary: summary,
                wordCount: package.words.count,
                onReading: { vm.requestReading() },
                onDone: onComplete
            )

        case .reading(let sessionId):
            ReadingView(sessionId: sessionId, userId: appState.currentUserId, onDone: onComplete)
        }
    }
}

// MARK: - Overview

struct OverviewView: View {
    let words: [PackageWord]
    let wordDetails: [String: WordDetail]
    let onDone: () -> Void
    var onExit: (() -> Void)? = nil

    @State private var currentIndex = 0

    private let overviewGreen  = Color.brandPrimary
    private let overviewYellow = Color.brandSecondary

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let onExit {
                    Button(action: onExit) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Genel Bakış")
                    .font(.headline)
                Spacer()
                Text("\(currentIndex + 1) / \(words.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            ProgressView(value: Double(currentIndex + 1), total: Double(words.count))
                .tint(.blue)
                .padding(.horizontal)

            Divider().padding(.top, 8)

            // Kelime kartı — sade: İngilizce kelime + okunuş + Türkçe anlam
            if currentIndex < words.count {
                let word = words[currentIndex]

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 28)

                        // İngilizce kelime
                        Text(word.word)
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(overviewYellow)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        // Hoparlör — okunuş için
                        Button {
                            SpeechPlayer.shared.speak(word.word)
                        } label: {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(overviewYellow)
                                .frame(width: 92, height: 92)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 24)

                        // Türkçe anlam (belirgin)
                        if let tr = word.definitionTr {
                            Text(tr)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(overviewYellow)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                        }

                        Spacer(minLength: 28)
                    }
                    .frame(maxWidth: .infinity, minHeight: 380)
                    .background(overviewGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding()
                }
            }

            // Alt butonlar
            VStack(spacing: 10) {
                Button {
                    if currentIndex + 1 < words.count {
                        withAnimation { currentIndex += 1 }
                    } else {
                        onDone()
                    }
                } label: {
                    Text(currentIndex + 1 < words.count ? "Sonraki" : "Testlere Başla")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)

                if let onExit {
                    Button(role: .cancel, action: onExit) {
                        Text("Ana Menüye Dön")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .onAppear { speakCurrentWord() }
        .onChange(of: currentIndex) { _, _ in speakCurrentWord() }
    }

    // Kart açılınca / sonraki kelimeye geçince İngilizce telaffuzu otomatik seslendir.
    private func speakCurrentWord() {
        guard currentIndex < words.count else { return }
        let text = words[currentIndex].word
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            SpeechPlayer.shared.speak(text)
        }
    }
}

// MARK: - Alıştırma kartı (yeşil zemin, sarı yazı)

struct ExerciseCard: View {
    let prompt: String              // alt başlık, örn "DOĞRU ÇEVİRİ SEÇ"
    let headline: String            // büyük gösterilen kelime/anlam
    var topLabel: String? = nil     // opsiyonel üst etiket (örn bayrak)
    /// Verilirse başlığın altında seslendirme butonu görünür.
    var onSpeak: (() -> Void)? = nil
    let options: [String]
    let selected: String?
    let showResult: Bool
    let isCorrect: (String) -> Bool
    let onSelect: (String) -> Void

    private let cardGreen     = Color.brandPrimary
    private let cardGreenDark = Color(red: 0.10, green: 0.44, blue: 0.22)
    private let yellow        = Color.brandSecondary
    private let wrongRed      = Color(red: 0.86, green: 0.24, blue: 0.24)

    var body: some View {
        VStack(spacing: 0) {
            // Üst: kelime + yönerge
            VStack(spacing: 12) {
                Spacer(minLength: 24)
                if let topLabel {
                    Text(topLabel)
                        .font(.system(size: 34))
                }
                Text(headline)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(yellow)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Text(prompt)
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(yellow.opacity(0.70))
                if let onSpeak {
                    Button(action: onSpeak) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(yellow)
                            .frame(width: 52, height: 52)
                            .overlay(Circle().stroke(yellow.opacity(0.5), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, minHeight: 260)

            // Seçenekler — kenarlıklı kutular
            VStack(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button {
                        onSelect(option)
                    } label: {
                        HStack(spacing: 10) {
                            Text(option)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(textColor(option))
                                .multilineTextAlignment(.center)
                            if showResult && isCorrect(option) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(cardGreenDark)
                            } else if showResult && selected == option {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 12)
                        .background(background(option))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(borderColor(option), lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(cardGreen)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    private func background(_ option: String) -> Color {
        guard showResult else { return Color.white.opacity(0.10) }
        if isCorrect(option)      { return yellow }
        if selected == option     { return wrongRed }
        return Color.white.opacity(0.10)
    }

    private func textColor(_ option: String) -> Color {
        guard showResult else { return .white }            // farklı renk: beyaz
        if isCorrect(option)      { return cardGreenDark }
        if selected == option     { return .white }
        return .white.opacity(0.7)
    }

    private func borderColor(_ option: String) -> Color {
        guard showResult else { return Color.white.opacity(0.65) }
        if isCorrect(option)      { return cardGreenDark }
        if selected == option     { return .white }
        return Color.white.opacity(0.25)
    }
}

// MARK: - MCQ

struct MCQView: View {
    let word: PackageWord
    let options: [String]
    let correctAnswer: String
    /// Saniye cinsinden yanıt süresi. nil ise sayaç gösterilmez (Learning/FullTest akışları etkilenmez).
    var timerDuration: Double? = nil
    let onAnswer: (Bool) -> Void

    @State private var selected: String?
    @State private var showResult = false
    @State private var timerProgress: CGFloat = 1
    @State private var secondsLeft: Int = 0
    @State private var timeoutTask: DispatchWorkItem?
    @State private var countdownTimer: Timer?

    var body: some View {
        VStack {
            Spacer(minLength: 8)
            ZStack(alignment: .top) {
                ExerciseCard(
                    prompt: "DOĞRU ÇEVİRİ SEÇ",
                    headline: word.word,
                    onSpeak: speakWord,
                    options: options,
                    selected: selected,
                    showResult: showResult,
                    isCorrect: { $0 == correctAnswer },
                    onSelect: select
                )
                if timerDuration != nil {
                    CountdownRing(progress: timerProgress, secondsLeft: secondsLeft)
                        .padding(.top, 18)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        // Test edilen kelime karta girer girmez okunur.
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { speakWord() }
            if let timerDuration {
                startTimer(duration: timerDuration)
            }
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func speakWord() {
        SpeechPlayer.shared.speak(word.word)
    }

    private func startTimer(duration: Double) {
        timerProgress = 1
        secondsLeft = Int(duration.rounded(.up))
        withAnimation(.linear(duration: duration)) {
            timerProgress = 0
        }
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsLeft > 0 { secondsLeft -= 1 }
        }
        let task = DispatchWorkItem { timeoutExpired() }
        timeoutTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    private func stopTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        timeoutTask?.cancel()
    }

    // Süre dolduğunda kullanıcı seçim yapmadıysa yanlış sayılır ve doğru cevap gösterilip bir sonraki kelimeye geçilir.
    private func timeoutExpired() {
        guard selected == nil else { return }
        showResult = true
        FeedbackSound.play(correct: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onAnswer(false)
        }
    }

    private func select(_ option: String) {
        guard selected == nil else { return }
        stopTimer()
        selected = option
        showResult = true
        let correct = option == correctAnswer
        FeedbackSound.play(correct: correct)
        DispatchQueue.main.asyncAfter(deadline: .now() + (correct ? 0.8 : 2.0)) {
            onAnswer(correct)
        }
    }
}

// MARK: - Countdown Ring

/// Kelime kartlarında kalan cevap süresini gösteren yuvarlak, sayısal sayaç.
struct CountdownRing: View {
    var progress: CGFloat   // 1 (dolu) -> 0 (bitti)
    var secondsLeft: Int
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.18))
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(secondsLeft)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }

    private var ringColor: Color {
        progress > 0.34 ? Color.brandSecondary : Color(red: 0.86, green: 0.24, blue: 0.24)
    }
}

// MARK: - TrToEn

struct TrToEnView: View {
    let word: PackageWord
    let options: [String]        // 4 İngilizce kelime, biri doğru
    let onAnswer: (Bool) -> Void

    @State private var selected: String?
    @State private var showResult = false

    var body: some View {
        VStack {
            Spacer(minLength: 8)
            ExerciseCard(
                prompt: "İNGİLİZCE KARŞILIĞINI SEÇ",
                headline: word.definitionTr ?? word.definition,
                options: options,
                selected: selected,
                showResult: showResult,
                isCorrect: { $0 == word.word },
                onSelect: select
            )
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
    }

    private func select(_ option: String) {
        guard selected == nil else { return }
        selected = option
        showResult = true
        let correct = option == word.word
        FeedbackSound.play(correct: correct)
        // Doğru İngilizce karşılığı seslendir (yanlışta da öğretici olsun).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            SpeechPlayer.shared.speak(word.word)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (correct ? 0.8 : 2.0)) {
            onAnswer(correct)
        }
    }
}

// MARK: - Sentence

struct SentenceView: View {
    let word: PackageWord
    let detail: WordDetail?
    let onDone: () -> Void

    private let cardGreen = Color.brandPrimary
    private let yellow    = Color.brandSecondary
    private let skyBlue   = Color(red: 0.36, green: 0.78, blue: 0.98)

    private var example: WordExample? {
        detail?.examples.first(where: { $0.isPrimary }) ?? detail?.examples.first
    }

    var body: some View {
        VStack {
            Spacer(minLength: 8)

            VStack(spacing: 20) {
                Text("CÜMLE İÇİNDE KULLANIM")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(yellow.opacity(0.70))

                Text(word.word)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(yellow)
                    .multilineTextAlignment(.center)

                if let example {
                    VStack(spacing: 12) {
                        Text(highlightedSentence(example.sentence))
                            .multilineTextAlignment(.center)
                        if let tr = example.translation {
                            Text(tr)
                                .font(.system(size: 17))
                                .foregroundStyle(yellow.opacity(0.80))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 4)
                } else {
                    Text("Bu kelime için örnek cümle bulunamadı.")
                        .font(.body)
                        .foregroundStyle(yellow.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .frame(minHeight: 340)
            .background(cardGreen)
            .clipShape(RoundedRectangle(cornerRadius: 24))

            Spacer(minLength: 8)

            Button {
                onDone()
            } label: {
                Text("Anladım")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(cardGreen)
        }
        .padding()
        .onAppear {
            guard let example else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                SpeechPlayer.shared.speak(example.sentence)
            }
        }
    }

    // Örnek cümlede hedef kelimeyi gökyüzü mavisi + biraz büyük fontla vurgular.
    private func highlightedSentence(_ sentence: String) -> AttributedString {
        let mutable = NSMutableAttributedString(
            string: sentence,
            attributes: [
                .foregroundColor: UIColor(yellow),
                .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            ]
        )
        let full = NSRange(location: 0, length: (sentence as NSString).length)
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word.word) + "\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            for m in regex.matches(in: sentence, range: full) {
                mutable.addAttribute(.foregroundColor, value: UIColor(skyBlue), range: m.range)
                mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: 25, weight: .bold), range: m.range)
            }
        }
        return AttributedString(mutable)
    }
}

// MARK: - Pronunciation

struct PronunciationView: View {
    let word: PackageWord
    let onDone: () -> Void

    private let cardGreen = Color.brandPrimary
    private let yellow    = Color.brandSecondary

    var body: some View {
        VStack {
            Spacer(minLength: 8)

            VStack(spacing: 24) {
                Text("TELAFFUZ")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(yellow.opacity(0.70))

                VStack(spacing: 8) {
                    Text(word.word)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(yellow)
                        .multilineTextAlignment(.center)

                    // Anlam da kartta görünsün — sadece sesi duyup anlamı
                    // hatırlamak zorunda kalınmasın.
                    Text(word.definitionTr ?? word.definition)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                // Ses ikonu — basınca kelimeyi seslendirir
                Button {
                    SpeechPlayer.shared.speak(word.word)
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(yellow)
                        .frame(width: 100, height: 100)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("Dinlemek için hoparlöre dokun, sonra sesli tekrar et")
                    .font(.subheadline)
                    .foregroundStyle(yellow.opacity(0.80))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .frame(minHeight: 380)
            .background(cardGreen)
            .clipShape(RoundedRectangle(cornerRadius: 24))

            Spacer(minLength: 8)

            Button {
                onDone()
            } label: {
                Text("Tekrar Ettim")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(cardGreen)
        }
        .padding()
        .onAppear {
            SpeechPlayer.shared.speak(word.word)
        }
    }
}

// MARK: - Summary

struct SummaryView: View {
    let summary: SessionSummary
    let wordCount: Int
    let onReading: () -> Void
    let onDone: () -> Void

    private let cardGreen = Color.brandPrimary
    private let yellow    = Color.brandSecondary

    /// Doğruluk yüzdesi — yuvarlama farkı yüzünden %100 yerine %99 görünmesin.
    private var accuracyText: String {
        "%\(Int((summary.accuracy * 100).rounded()))"
    }

    var body: some View {
        VStack {
            Spacer(minLength: 8)

            VStack(spacing: 24) {
                Image(systemName: "star.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(yellow)

                Text("Harika iş!")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(yellow)

                VStack(spacing: 14) {
                    StatRow(icon: "book.fill", label: "Öğrenilen", value: "\(wordCount) kelime", tint: yellow)
                    StatRow(icon: "checkmark.circle.fill", label: "Doğruluk", value: accuracyText, tint: yellow)
                    StatRow(icon: "clock.fill", label: "Süre",
                            value: summary.durationSec.map { "\($0 / 60)dk \($0 % 60)sn" } ?? "-",
                            tint: yellow)
                }
                .padding(18)
                .background(Color.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .frame(minHeight: 380)
            .background(cardGreen)
            .clipShape(RoundedRectangle(cornerRadius: 24))

            Spacer(minLength: 8)

            VStack(spacing: 12) {
                Button {
                    onReading()
                } label: {
                    Label("Okuma Parçası Oluştur", systemImage: "doc.text.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .tint(cardGreen)

                Button {
                    onDone()
                } label: {
                    Text("Ana Sayfaya Dön")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(cardGreen)
            }
        }
        .padding()
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    var tint: Color = .brandSecondary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(tint.opacity(0.80))
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
        }
    }
}
