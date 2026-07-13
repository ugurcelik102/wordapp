import SwiftUI

struct ReadingView: View {
    let sessionId: String
    var userId: String? = nil
    let onDone: () -> Void

    @State private var passage: ReadingPassage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var fontSize: CGFloat = CGFloat(UserSettings.defaultReadingFontSize)
    @ObservedObject private var speech = SpeechPlayer.shared

    private var readAloudText: String {
        (passage?.content ?? "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
    }

    var body: some View {
        NavigationStack {
            Group {
                if let passage {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Okuma Parçası")
                                .font(.title2.bold())

                            HighlightedPassageText(
                                content: passage.content,
                                targets: passage.targetWordTexts ?? [],
                                fontSize: fontSize
                            )

                            if let wc = passage.wordCount {
                                Text("\(wc) kelime")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Tekrar Dene") {
                            Task { await load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    // Varsayılan: yükleniyor (ilk render dahil — beyaz ekran olmaz).
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("Okuma parçası oluşturuluyor...")
                            .foregroundStyle(.secondary)
                        Text("Bu birkaç saniye sürebilir")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("Okuma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if passage != nil {
                        FontSizeControls(fontSize: $fontSize)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if passage != nil {
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
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { onDone() }
                        .fontWeight(.semibold)
                }
            }
            .onDisappear { speech.stop() }
            .task { await load() }
            .onAppear {
                if let userId {
                    fontSize = CGFloat(UserSettings.shared.readingFontSize(for: userId))
                }
            }
            .onChange(of: fontSize) { _, newValue in
                if let userId {
                    UserSettings.shared.setReadingFontSize(Double(newValue), for: userId)
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            passage = try await APIService.generateReading(sessionId: sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
