import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func login(email: String, password: String, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIService.login(email: email, password: password)
            TokenStorage.shared.token = response.accessToken
            await appState.didLogin()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register(email: String, name: String, password: String, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIService.register(email: email, name: name, password: password)
            TokenStorage.shared.token = response.accessToken
            await appState.didLogin()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
