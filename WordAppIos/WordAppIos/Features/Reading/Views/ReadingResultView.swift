import SwiftUI

/// Öğrenilen kelimelerden üretilen okuma parçasını gösterir (session'a bağlı değil).
struct ReadingResultView: View {
    let content: String
    let wordCount: Int?
    let targets: [String]
    var glossary: [GlossaryItem] = []
    var userId: String? = nil
    let onDone: () -> Void

    @State private var fontSize: CGFloat = CGFloat(UserSettings.defaultReadingFontSize)
    @ObservedObject private var speech = SpeechPlayer.shared

    private var readAloudText: String {
        content
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Okuma Parçası")
                        .font(.title2.bold())

                    HighlightedPassageText(content: content, targets: targets, fontSize: fontSize)

                    if let wc = wordCount {
                        Text("\(wc) kelime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !glossary.isEmpty {
                        GlossaryView(items: glossary)
                    }
                }
                .padding()
            }
            .onAppear {
                if let userId {
                    fontSize = CGFloat(UserSettings.shared.readingFontSize(for: userId))
                }
            }
            .onDisappear { speech.stop() }
            .onChange(of: fontSize) { _, newValue in
                if let userId {
                    UserSettings.shared.setReadingFontSize(Double(newValue), for: userId)
                }
            }
            .navigationTitle("Okuma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    FontSizeControls(fontSize: $fontSize)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if speech.isSpeaking {
                            Button(role: .destructive) { speech.stop() } label: {
                                Label("Durdur", systemImage: "stop.fill")
                            }
                        } else {
                            Button { speech.speakReading(readAloudText, rate: .slow) } label: {
                                Label("Yavaş oku", systemImage: "tortoise.fill")
                            }
                            Button { speech.speakReading(readAloudText, rate: .normal) } label: {
                                Label("Normal hız", systemImage: "speaker.wave.2.fill")
                            }
                            Button { speech.speakReading(readAloudText, rate: .fast) } label: {
                                Label("Hızlı oku", systemImage: "hare.fill")
                            }
                        }
                    } label: {
                        Image(systemName: speech.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { onDone() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Mini sözlükçe (seviyeye göre zor kelimeler + Türkçe karşılık)

struct GlossaryView: View {
    let items: [GlossaryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sözlükçe", systemImage: "character.book.closed")
                .font(.headline)

            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                if idx > 0 { Divider() }
                HStack(alignment: .top, spacing: 12) {
                    Text(item.word)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Spacer(minLength: 12)
                    Text(item.tr)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
