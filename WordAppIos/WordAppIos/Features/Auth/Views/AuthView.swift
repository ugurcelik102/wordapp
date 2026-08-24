import SwiftUI

struct AuthView: View {
    @State private var showRegister = false

    var body: some View {
        if showRegister {
            RegisterView(showRegister: $showRegister)
        } else {
            LoginView(showRegister: $showRegister)
        }
    }
}
