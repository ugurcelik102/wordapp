import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var showReadingOptions = false
    @State private var showProgress = false
    @StateObject private var ads = RewardedAdManager.shared

    /// Reklam kilidi kullanıcı bazlı tutulur; oturum yoksa ortak anahtar.
    private var adUserId: String { appState.currentUserId ?? "guest" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoGrid(
                        dailyTasks: vm.allDailyTasks,
                        stateFor:   { vm.state(for: $0) },
                        onNewWords: { Task { await vm.startNewWords() } },
                        onReview:   { Task { await vm.startReview() } },
                        onSentence: { Task { await vm.startSentenceUsage() } },
                        onReading: {
                            ads.run(.reading, userId: adUserId) {
                                showReadingOptions = true
                            }
                        },
                        onExam: {
                            ads.run(.exam, userId: adUserId) {
                                Task { await vm.startExam() }
                            }
                        },
                        onFullTest: { Task { await vm.startFullTest() } },
                        readingAdLocked: !ads.isUnlocked(.reading, userId: adUserId),
                        examAdLocked:    !ads.isUnlocked(.exam, userId: adUserId)
                    )

                    ProgressStrip(summary: vm.progress) { showProgress = true }
                        .frame(height: 92)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    stops: [
                        .init(color: Color.brandPrimary.opacity(0.45), location: 0),
                        .init(color: Color.brandPrimary.opacity(0.20), location: 0.35),
                        .init(color: Color.appBackground, location: 0.65),
                        .init(color: Color.brandSecondary.opacity(0.18), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .background(Color.appBackground)
                .ignoresSafeArea()
            )
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
                if vm.isWorking || ads.isPreparingAd {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView(ads.isPreparingAd ? "Reklam hazırlanıyor..." : "Hazırlanıyor...")
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
                        Task { await vm.refreshStatus() }
                    }
                case .reading(let content, let wordCount, let targets, let glossary):
                    ReadingResultView(content: content, wordCount: wordCount, targets: targets, glossary: glossary, userId: appState.currentUserId) {
                        vm.destination = nil
                    }
                case .sentenceUsage(let exercises):
                    SentenceUsageFlowView(exercises: exercises) {
                        vm.destination = nil
                        Task { await vm.refreshStatus() }
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
    /// Ana ekranda gösterilen temel görevler (backend sırasında).
    /// Kilitli görevler de listede kalır; gri kare olarak çizilir.
    var dailyTasks: [DailyTaskKey] = [.newWords, .sentenceUsage]
    /// Görevin görsel durumu (aktif / tamamlandı / kilitli).
    var stateFor: (DailyTaskKey) -> DailyTaskState = { _ in .available }
    let onNewWords: () -> Void
    let onReview: () -> Void
    let onSentence: () -> Void
    let onReading: () -> Void
    let onExam: () -> Void
    let onFullTest: () -> Void
    /// Reklam izlenmediyse kartta "Reklam izle" rozeti gösterilir.
    var readingAdLocked: Bool = false
    var examAdLocked: Bool = false

    private let gap: CGFloat = 12
    /// Öne çıkan kartın en/boy oranı — tam genişlikte büyük kare his verir.
    private let featuredRatio: CGFloat = 1.35
    private let wideH: CGFloat = 92

    /// Öne çıkan (sıradaki oynanabilir) görev; hepsi kapalıysa listenin ilki.
    private var featuredKey: DailyTaskKey? {
        dailyTasks.first { stateFor($0) == .available } ?? dailyTasks.first
    }

    /// Altta yan yana duran küçük kareler.
    private var secondaryKeys: [DailyTaskKey] {
        dailyTasks.filter { $0 != featuredKey }
    }

    var body: some View {
        VStack(spacing: gap) {
            // Temel 3 görev: sıradaki büyük kare, diğer ikisi altında yan yana kare.
            if let featuredKey {
                taskCard(for: featuredKey, featured: true)
                    .aspectRatio(featuredRatio, contentMode: .fit)
            }

            if !secondaryKeys.isEmpty {
                HStack(spacing: gap) {
                    ForEach(secondaryKeys, id: \.self) { key in
                        taskCard(for: key, featured: false)
                            .aspectRatio(1, contentMode: .fit)
                    }
                    // Tek kart kaldıysa hizayı bozmamak için boş yer bırakılır.
                    if secondaryKeys.count == 1 {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            // Tam genişlik alt kart
            BentoCard(
                icon: "doc.text.fill",
                title: "Okuma Parçası Oluştur",
                colors: [.brandPrimary, .brandPrimaryDark],
                horizontal: true,
                adLocked: readingAdLocked,
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
                adLocked: examAdLocked,
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

    /// Günlük görev kartı. Sıradaki görev büyük kare, diğerleri küçük kare.
    @ViewBuilder
    private func taskCard(for key: DailyTaskKey, featured: Bool) -> some View {
        let state = stateFor(key)
        BentoCard(
            icon: icon(for: key),
            title: key.title,
            subtitle: subtitle(for: state),
            colors: colors(for: key),
            iconSize: featured ? 30 : 22,
            titleSize: featured ? 22 : 16,
            foreground: key == .review ? .brandPrimaryDark : .white,
            state: state,
            action: action(for: key)
        )
        .frame(maxWidth: .infinity)
    }

    private func icon(for key: DailyTaskKey) -> String {
        switch key {
        case .review:        return "arrow.triangle.2.circlepath"
        case .newWords:      return "lightbulb.fill"
        case .sentenceUsage: return "text.alignleft"
        }
    }

    private func colors(for key: DailyTaskKey) -> [Color] {
        switch key {
        case .review:
            return [.taskYellow, .taskYellowDark]
        case .newWords:
            return [Color(red: 0.20, green: 0.62, blue: 0.95),
                    Color(red: 0.16, green: 0.52, blue: 0.90)]
        case .sentenceUsage:
            return [Color(red: 0.96, green: 0.52, blue: 0.46),
                    Color(red: 0.93, green: 0.42, blue: 0.40)]
        }
    }

    private func action(for key: DailyTaskKey) -> () -> Void {
        switch key {
        case .review:        return onReview
        case .newWords:      return onNewWords
        case .sentenceUsage: return onSentence
        }
    }

    /// Karttaki durum yazısı.
    private func subtitle(for state: DailyTaskState) -> String {
        switch state {
        case .completed: return "Bugünlük tamamlandı"
        case .locked:    return "Sırası gelmedi"
        case .available: return "Sıradaki görev"
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
    /// Açık renkli kartlarda (ör. pastel sarı) yazı/ikon rengi koyu olur.
    var foreground: Color = .white
    /// Özellik reklam izlenerek açılıyorsa kartta rozet gösterilir.
    var adLocked: Bool = false
    /// Günlük görev kartları için durum. Diğer kartlar her zaman `.available`.
    var state: DailyTaskState = .available
    let action: () -> Void

    private var isPassive: Bool { state.isDisabled }

    /// Pasif kart koyu gri olduğu için yazılar her zaman beyaz.
    private var ink: Color { isPassive ? .white : foreground }

    /// Pasif kartlar renk yerine koyu gri tonlarla çizilir (beyaz yazı okunsun diye opak).
    private var fillColors: [Color] {
        isPassive
            ? [Color(red: 0.44, green: 0.47, blue: 0.50), Color(red: 0.33, green: 0.36, blue: 0.39)]
            : colors
    }

    private var badge: String? {
        switch state {
        case .completed: return "checkmark.seal.fill"
        case .locked:    return "lock.fill"
        case .available: return nil
        }
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: horizontal ? .leading : .topLeading)
                .padding(14)
                .background(
                    LinearGradient(colors: fillColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        // Kilitli kart tıklanabilir kalır (dokununca sırasını açıklayan mesaj çıkar),
        // tamamlanan görev ise pasiftir.
        .disabled(state == .completed)
    }

    @ViewBuilder
    private var content: some View {
        if horizontal {
            HStack(spacing: 14) {
                iconCircle
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ink)
                Spacer(minLength: 0)
                if adLocked {
                    HStack(spacing: 4) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Reklam izle")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.18))
                    .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.8))
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    iconCircle
                    Spacer()
                    if let badge {
                        Image(systemName: badge)
                            .font(.system(size: 20))
                            .foregroundStyle(ink.opacity(0.9))
                    }
                }
                Spacer(minLength: 10)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(isPassive ? .semibold : .regular))
                        .foregroundStyle(ink.opacity(isPassive ? 1 : 0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var iconCircle: some View {
        Image(systemName: icon)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(ink)
            .frame(width: 44, height: 44)
            .background(isPassive ? Color.white.opacity(0.18) : Color.black.opacity(0.15))
            .clipShape(Circle())
    }
}
