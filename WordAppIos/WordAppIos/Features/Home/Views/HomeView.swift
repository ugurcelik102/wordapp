import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var showReadingOptions = false
    @State private var showProgress = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoGrid(
                        newWordsLocked: vm.newWordsLocked,
                        onNewWords: { Task { await vm.startNewWords() } },
                        onReview:   { Task { await vm.startReview() } },
                        onSentence: { Task { await vm.startSentenceUsage() } },
                        onReading:  { showReadingOptions = true },
                        onExam:     { Task { await vm.startExam() } },
                        onFullTest: { Task { await vm.startFullTest() } }
                    )

                    ProgressStrip(summary: vm.progress) { showProgress = true }
                }
                .padding()
            }
            .task {
                await vm.refreshStatus()
                await vm.loadProgress()
            }
            .navigationTitle("Günün görevleri")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if vm.isWorking {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView("Hazırlanıyor...")
                            .padding(24)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .fullScreenCover(item: $vm.destination) { dest in
                switch dest {
                case .learning(let pkg):
                    LearningFlowView(package: pkg) {
                        vm.destination = nil
                        Task { await vm.refreshStatus() }
                    }
                    .environmentObject(appState)
                case .review(let words):
                    ReviewFlowView(words: words) {
                        vm.destination = nil
                    }
                case .reading(let content, let wordCount, let targets, let glossary):
                    ReadingResultView(content: content, wordCount: wordCount, targets: targets, glossary: glossary, userId: appState.currentUserId) {
                        vm.destination = nil
                    }
                case .sentenceUsage(let exercises):
                    SentenceUsageFlowView(exercises: exercises) {
                        vm.destination = nil
                    }
                case .exam(let questions, let durationSec):
                    ExamFlowView(questions: questions, durationSec: durationSec) {
                        vm.destination = nil
                    }
                case .fullTest(let words, let offset, let total):
                    FullTestFlowView(words: words, offset: offset, total: total) {
                        vm.destination = nil
                        Task { await vm.loadProgress() }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(onDailyCountChanged: {})
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showReadingOptions) {
                ReadingOptionsView(
                    onLearned: { Task { await vm.startReading() } },
                    onTopic: { scenario, dialogue in
                        Task { await vm.startTopicReading(topic: scenario, asDialogue: dialogue) }
                    }
                )
            }
            .sheet(isPresented: $showProgress) {
                ProgressDetailView()
            }
            .alert("Bilgi", isPresented: Binding(
                get: { vm.banner != nil },
                set: { if !$0 { vm.banner = nil } }
            )) {
                Button("Tamam", role: .cancel) { vm.banner = nil }
            } message: {
                Text(vm.banner ?? "")
            }
        }
    }
}

// MARK: - Bento ızgara (farklı boyutlu kartlar)

struct BentoGrid: View {
    var newWordsLocked: Bool = false
    let onNewWords: () -> Void
    let onReview: () -> Void
    let onSentence: () -> Void
    let onReading: () -> Void
    let onExam: () -> Void
    let onFullTest: () -> Void

    private let gap: CGFloat = 12
    private let smallH: CGFloat = 104
    private var bigH: CGFloat { smallH * 2 + gap }
    private let wideH: CGFloat = 92

    var body: some View {
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                // Öne çıkan büyük kart
                BentoCard(
                    icon: "lightbulb.fill",
                    title: "Yeni Kelimeler",
                    subtitle: newWordsLocked ? "Bugünlük tamamlandı" : "Bugünün önerisi",
                    colors: [Color(red: 0.20, green: 0.62, blue: 0.95),
                             Color(red: 0.16, green: 0.52, blue: 0.90)],
                    iconSize: 26,
                    titleSize: 20,
                    locked: newWordsLocked,
                    action: onNewWords
                )
                .frame(maxWidth: .infinity)
                .frame(height: bigH)

                // Sağ sütun: iki küçük kart
                VStack(spacing: gap) {
                    BentoCard(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Kelime Tekrarı",
                        colors: [Color(red: 0.99, green: 0.70, blue: 0.15),
                                 Color(red: 0.97, green: 0.58, blue: 0.05)],
                        action: onReview
                    )
                    .frame(height: smallH)

                    BentoCard(
                        icon: "text.alignleft",
                        title: "Cümle İçinde Kullanım",
                        colors: [Color(red: 0.96, green: 0.52, blue: 0.46),
                                 Color(red: 0.93, green: 0.42, blue: 0.40)],
                        action: onSentence
                    )
                    .frame(height: smallH)
                }
                .frame(maxWidth: .infinity)
            }

            // Tam genişlik alt kart
            BentoCard(
                icon: "doc.text.fill",
                title: "Okuma Parçası Oluştur",
                colors: [Color(red: 0.22, green: 0.74, blue: 0.28),
                         Color(red: 0.13, green: 0.64, blue: 0.20)],
                horizontal: true,
                action: onReading
            )
            .frame(maxWidth: .infinity)
            .frame(height: wideH)

            // Deneme sınavı
            BentoCard(
                icon: "graduationcap.fill",
                title: "Deneme Sınavı",
                colors: [Color(red: 0.51, green: 0.40, blue: 0.85),
                         Color(red: 0.42, green: 0.31, blue: 0.78)],
                horizontal: true,
                action: onExam
            )
            .frame(maxWidth: .infinity)
            .frame(height: wideH)

            // Kelime testi (öğrenilen tüm kelimeler, 8'li)
            BentoCard(
                icon: "checklist",
                title: "Kelime Testi",
                colors: [Color(red: 0.10, green: 0.65, blue: 0.66),
                         Color(red: 0.06, green: 0.55, blue: 0.58)],
                horizontal: true,
                action: onFullTest
            )
            .frame(maxWidth: .infinity)
            .frame(height: wideH)
        }
    }
}

// MARK: - Bento kartı

struct BentoCard: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let colors: [Color]
    var iconSize: CGFloat = 22
    var titleSize: CGFloat = 15
    var horizontal: Bool = false
    var locked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: horizontal ? .leading : .topLeading)
                .padding(14)
                .background(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .opacity(locked ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    @ViewBuilder
    private var content: some View {
        if horizontal {
            HStack(spacing: 14) {
                iconCircle
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    iconCircle
                    Spacer()
                    if locked {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                Spacer(minLength: 10)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var iconCircle: some View {
        Image(systemName: icon)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Color.black.opacity(0.15))
            .clipShape(Circle())
    }
}
