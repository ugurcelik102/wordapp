import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// Günlük kelime sayısı backend'de güncellenince ana ekranın paketi yeniden yüklemesi için.
    let onDailyCountChanged: () -> Void

    @State private var dailyWordCount = UserSettings.defaultDailyWordCount
    @State private var serverValue: Int?          // son bilinen sunucu değeri (gereksiz PATCH'i önler)
    @State private var levelId: Int?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteErrorMessage: String?

    private var userId: String? { appState.currentUserId }

    private var currentLevelText: String {
        let id = levelId ?? userId.flatMap { UserSettings.shared.savedLevelId(for: $0) }
        guard let id else { return "Belirlenmedi" }
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

                // MARK: Hesap
                Section {
                    Button(role: .destructive) {
                        appState.logout()
                        dismiss()
                    } label: {
                        Label("Çıkış Yap", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // MARK: Hesabı Sil
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        if isDeletingAccount {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Hesap Siliniyor...")
                            }
                        } else {
                            Label("Hesabımı Sil", systemImage: "trash")
                        }
                    }
                    .disabled(isDeletingAccount)
                } footer: {
                    if let deleteErrorMessage {
                        Text(deleteErrorMessage).foregroundStyle(.red)
                    } else {
                        Text("Hesabın ve tüm ilerleme verilerin kalıcı olarak silinir. Bu işlem geri alınamaz.")
                    }
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
            .task { await loadProfile() }
            .onChange(of: dailyWordCount) { _, newValue in
                guard !isLoading, newValue != serverValue else { return }
                Task { await save(newValue) }
            }
            .confirmationDialog(
                "Hesabını kalıcı olarak silmek istediğine emin misin?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Hesabımı Sil", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Tüm ilerleme, kelime kayıtları ve hesap bilgilerin kalıcı olarak silinecek. Bu işlem geri alınamaz.")
            }
        }
    }

    // MARK: - Yükle / Kaydet

    private func loadProfile() async {
        // Önce yerel önbellekten hızlı bir başlangıç değeri.
        if let uid = userId {
            dailyWordCount = UserSettings.shared.dailyWordCount(for: uid)
        }
        do {
            let profile = try await APIService.getProfile()
            serverValue = profile.dailyWordCount
            dailyWordCount = profile.dailyWordCount
            if let lid = profile.currentLevelId { levelId = lid }
            if let uid = userId {
                UserSettings.shared.setDailyWordCount(profile.dailyWordCount, for: uid)
                if let lid = profile.currentLevelId { UserSettings.shared.setSavedLevelId(lid, for: uid) }
            }
        } catch {
            // Profil çekilemezse yerel değerle devam; serverValue'yu eşitle ki ilk PATCH gereksiz olmasın.
            serverValue = dailyWordCount
            errorMessage = "Profil yüklenemedi (\(error.localizedDescription)). Yerel değer gösteriliyor."
        }
        isLoading = false
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        deleteErrorMessage = nil
        do {
            try await appState.deleteAccount()
            dismiss()
        } catch {
            deleteErrorMessage = "Hesap silinemedi: \(error.localizedDescription)"
        }
        isDeletingAccount = false
    }

    private func save(_ newValue: Int) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let updated = try await APIService.updateProfile(dailyWordCount: newValue)
            serverValue = updated.dailyWordCount
            if let uid = userId {
                UserSettings.shared.setDailyWordCount(updated.dailyWordCount, for: uid)
            }
            onDailyCountChanged()
        } catch {
            // Seçimi geri alma — kullanıcının seçimi ekranda kalsın, sadece bilgilendir.
            errorMessage = "Kaydedilemedi: \(error.localizedDescription)"
        }
    }
}
