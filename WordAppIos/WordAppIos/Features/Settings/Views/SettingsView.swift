import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// Günlük kelime sayısı değişince ana ekranın paketi yeniden yüklemesi için.
    let onDailyCountChanged: () -> Void

    @State private var dailyWordCount = UserSettings.defaultDailyWordCount
    @State private var levelId: Int?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var showDeleteConfirmation = false

    private var currentLevelText: String {
        let id = levelId ?? ProgressStore.shared.levelId
        guard let id = Optional(id) else { return "Belirlenmedi" }
        return "\(AppLevel.code(for: id)) — \(AppLevel.name(for: id))"
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Günlük hedef
                Section {
                    Picker("Günlük Kelime Sayısı", selection: $dailyWordCount) {
                        ForEach(UserSettings.dailyWordCountOptions, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isSaving)

                    if isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Kaydediliyor...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Günlük Hedef")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else {
                        Text("Her gün öğrenmek istediğin yeni kelime sayısı. Değişiklik bir sonraki paketten itibaren geçerli olur.")
                    }
                }

                // MARK: Seviye
                Section {
                    HStack {
                        Text("Mevcut Seviye")
                        Spacer()
                        Text(currentLevelText)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        appState.startPlacement()
                        dismiss()
                    } label: {
                        Label("Seviyeyi Yeniden Belirle", systemImage: "arrow.triangle.2.circlepath")
                    }
                } header: {
                    Text("Seviye")
                } footer: {
                    Text("Seviye tespit sınavını yeniden yaparak seviyeni güncelleyebilirsin.")
                }

                // MARK: Verileri Sil
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Tüm Verilerimi Sil", systemImage: "trash")
                    }
                } footer: {
                    Text("Öğrendiğin kelimeler, tekrar planın ve test sonuçların bu cihazdan kalıcı olarak silinir. Bu işlem geri alınamaz.")
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task { loadProfile() }
            .onChange(of: dailyWordCount) { _, newValue in
                guard !isLoading else { return }
                save(newValue)
            }
            .confirmationDialog(
                "Tüm verilerini silmek istediğine emin misin?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Verilerimi Sil", role: .destructive) { deleteAllData() }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Tüm ilerleme ve kelime kayıtların silinecek, seviye tespitine dönersin. Bu işlem geri alınamaz.")
            }
        }
    }

    // MARK: - Yükle / Kaydet

    private func loadProfile() {
        let profile = LocalAPI.getProfile()
        dailyWordCount = profile.dailyWordCount
        levelId = profile.currentLevelId
        isLoading = false
    }

    /// Cihazdaki tüm ilerlemeyi siler ve seviye tespitine döner.
    private func deleteAllData() {
        appState.resetAllData()
        dismiss()
    }

    private func save(_ newValue: Int) {
        LocalAPI.updateProfile(dailyWordCount: newValue)
        onDailyCountChanged()
    }
}
