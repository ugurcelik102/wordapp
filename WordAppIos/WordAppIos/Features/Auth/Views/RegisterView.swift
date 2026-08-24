import SwiftUI

struct RegisterView: View {
    @Binding var showRegister: Bool
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject var appState: AppState

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty &&
        password.count >= 6 && password == confirmPassword &&
        !vm.isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Başlık
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 56))
                            .foregroundStyle(.blue)
                            .padding(.top, 40)

                        Text("Hesap Oluştur")
                            .font(.largeTitle.bold())

                        Text("Öğrenmeye hemen başla")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Form
                    VStack(spacing: 14) {
                        TextField("Adın", text: $name)
                            .textFieldStyle(.roundedBorder)

                        TextField("E-posta", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Şifre (en az 6 karakter)", text: $password)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Şifre tekrar", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)

                        if passwordMismatch {
                            Text("Şifreler eşleşmiyor")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let error = vm.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task {
                                await vm.register(
                                    email: email, name: name,
                                    password: password, appState: appState
                                )
                            }
                        } label: {
                            Group {
                                if vm.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Kayıt Ol")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isFormValid)
                    }
                    .padding(.horizontal)

                    // Geri
                    Button {
                        showRegister = false
                    } label: {
                        HStack(spacing: 4) {
                            Text("Zaten hesabın var mı?")
                                .foregroundStyle(.secondary)
                            Text("Giriş yap")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }
}
