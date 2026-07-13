import SwiftUI
import Combine

@MainActor
final class ForgotPasswordViewModel: ObservableObject {
    enum Step { case request, reset }

    @Published var step: Step = .request
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var devCode: String?

    func requestCode(email: String) async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await APIService.forgotPassword(email: email)
            infoMessage = resp.message
            devCode = resp.devCode
            step = .reset
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset(email: String, code: String, newPassword: String, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await APIService.resetPassword(email: email, code: code, newPassword: newPassword)
            TokenStorage.shared.token = resp.accessToken
            await appState.didLogin()   // başarı → otomatik giriş, auth akışı kapanır
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ForgotPasswordView: View {
    let initialEmail: String
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ForgotPasswordViewModel()

    @State private var email: String
    @State private var code = ""
    @State private var newPassword = ""

    init(initialEmail: String = "") {
        self.initialEmail = initialEmail
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)
                        .padding(.top, 24)

                    Text(vm.step == .request ? "Şifreni mi unuttun?" : "Yeni şifre belirle")
                        .font(.title2.bold())

                    Text(vm.step == .request
                         ? "E-posta adresini gir, sana bir sıfırlama kodu gönderelim."
                         : "E-postana gelen kodu ve yeni şifreni gir.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if vm.step == .request {
                        requestForm
                    } else {
                        resetForm
                    }

                    if let info = vm.infoMessage {
                        Text(info)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let dev = vm.devCode {
                        VStack(spacing: 4) {
                            Text("Geliştirme modu kodu")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(dev)
                                .font(.title3.monospacedDigit().bold())
                                .foregroundStyle(.blue)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Şifremi Unuttum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private var requestForm: some View {
        VStack(spacing: 16) {
            TextField("E-posta", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await vm.requestCode(email: email) }
            } label: {
                buttonLabel("Kod Gönder")
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || vm.isLoading)
        }
    }

    private var resetForm: some View {
        VStack(spacing: 16) {
            TextField("E-posta", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
                .disabled(true)
                .foregroundStyle(.secondary)

            TextField("Sıfırlama kodu", text: $code)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            SecureField("Yeni şifre (en az 6 karakter)", text: $newPassword)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await vm.reset(email: email, code: code, newPassword: newPassword, appState: appState) }
            } label: {
                buttonLabel("Şifreyi Sıfırla")
            }
            .buttonStyle(.borderedProminent)
            .disabled(code.isEmpty || newPassword.count < 6 || vm.isLoading)

            Button("Kodu tekrar gönder") {
                Task { await vm.requestCode(email: email) }
            }
            .font(.subheadline)
            .disabled(vm.isLoading)
        }
    }

    private func buttonLabel(_ title: String) -> some View {
        Group {
            if vm.isLoading {
                ProgressView().tint(.white)
            } else {
                Text(title).fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
    }
}
