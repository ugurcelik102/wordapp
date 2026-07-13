import SwiftUI

struct PlacementTestView: View {
    @StateObject private var vm = PlacementViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if vm.isLoading {
                loadingView
            } else if let result = vm.result {
                PlacementResultView(result: result, vm: vm)
            } else if let _ = vm.test {
                questionView
            } else {
                errorView
            }
        }
        .task { await vm.loadTest() }
        .animation(.easeInOut, value: vm.currentIndex)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Seviye testi hazırlanıyor...")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Soru ekranı

    private var questionView: some View {
        VStack(spacing: 0) {
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Seviye Testi")
                        .font(.headline)
                    Spacer()
                    if let total = vm.test?.questions.count {
                        Text("\(vm.currentIndex + 1) / \(total)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: vm.progress)
                    .tint(.blue)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    if let q = vm.currentQuestion {
                        // Kelime
                        VStack(spacing: 8) {
                            Text(q.word)
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.primary)

                            Text(q.questionText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 32)

                        // Seçenekler
                        VStack(spacing: 12) {
                            ForEach(q.options, id: \.self) { option in
                                OptionButton(
                                    text: option,
                                    isSelected: vm.answers[q.questionId] == option
                                ) {
                                    vm.selectAnswer(option)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Son sorudaysa "Bitir" butonu
                        if vm.isLastQuestion && vm.answers[q.questionId] != nil {
                            Button {
                                Task { await vm.submit() }
                            } label: {
                                Group {
                                    if vm.isSubmitting {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Testi Bitir")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Hata

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(vm.errorMessage ?? "Bir hata oluştu")
                .multilineTextAlignment(.center)
            Button("Tekrar Dene") {
                Task { await vm.loadTest() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Seçenek butonu

struct OptionButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
                .foregroundStyle(isSelected ? .blue : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Sonuç ekranı

struct PlacementResultView: View {
    let result: PlacementResult
    @ObservedObject var vm: PlacementViewModel
    @EnvironmentObject var appState: AppState

    @State private var selectedLevelId: Int

    private let levels = [
        (id: 1, code: "A1", name: "Beginner"),
        (id: 2, code: "A2", name: "Elementary"),
        (id: 3, code: "B1", name: "Intermediate"),
        (id: 4, code: "B2", name: "Upper-Intermediate"),
        (id: 5, code: "C1", name: "Advanced"),
        (id: 6, code: "C2", name: "Mastery"),
    ]

    init(result: PlacementResult, vm: PlacementViewModel) {
        self.result = result
        self.vm = vm
        _selectedLevelId = State(initialValue: result.recommendedLevelId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Skor
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .padding(.top, 40)

                    Text("Test Tamamlandı!")
                        .font(.title.bold())

                    Text("Skorun: \(Int(result.score))%")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                // Önerilen seviye
                VStack(spacing: 8) {
                    Text("Önerilen Seviye")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(result.recommendedLevel)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.blue)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Seviye ayarlama
                VStack(alignment: .leading, spacing: 12) {
                    Text("Seviyeni Değiştir")
                        .font(.headline)
                        .padding(.horizontal)

                    Text("İstersen seviyeni aşağı veya yukarı ayarlayabilirsin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Picker("Seviye", selection: $selectedLevelId) {
                        ForEach(levels, id: \.id) { level in
                            Text("\(level.code) — \(level.name)").tag(level.id)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // Devam et
                Button {
                    Task { await vm.updateLevel(levelId: selectedLevelId, appState: appState) }
                } label: {
                    Text("Öğrenmeye Başla")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }
}
