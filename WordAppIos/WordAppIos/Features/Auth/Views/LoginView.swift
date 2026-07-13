import SwiftUI

struct LoginView: View {
    @Binding var showRegister: Bool
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject var appState: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo & Başlık
                    VStack(spacing: 12) {
                        Image(systemName: "text.book.closed.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)

                        Text("WordApp")
                            .font(.largeTitle.bold())

                        Text("İngilizce kelime öğrenmenin\nen etkili yolu")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)

                    // Form
                    VStack(spacing: 16) {
                        TextField("E-posta", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Şifre", text: $password)
                            .textFieldStyle(.roundedBorder)

                        if let error = vm.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await vm.login(email: email, password: password, appState: appState) }
                        } label: {
                            Group {
                                if vm.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Giriş Yap")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(email.isEmpty || password.isEmpty || vm.isLoading)

                        Button("Şifremi unuttum?") {
                            showForgotPassword = true
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 2)
                    }
                    .padding(.horizontal)

                    // Kayıt ol
                    Button {
                        showRegister = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Hesabın yok mu?")
                                .foregroundStyle(.secondary)
                            Text("Kayıt ol")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(initialEmail: email)
                    .environmentObject(appState)
            }
        }
    }
}
