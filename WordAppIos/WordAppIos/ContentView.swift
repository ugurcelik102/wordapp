import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true

    var body: some View {
        ZStack {
            content

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.route {
        case .auth:
            AuthView()
        case .placement:
            PlacementTestView()
        case .home:
            HomeView()
        }
    }
}

// MARK: - Açılış (splash) ekranı

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient.brand(.brandPrimary, .brandPrimaryDark).ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                        .fill(.white)
                        .frame(width: 132, height: 144)
                        .rotationEffect(.degrees(-8))
                        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    Text("A")
                        .font(.system(size: 92, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.brandPrimary)
                        .rotationEffect(.degrees(-8))
                }

                Text("Vocabee")
                    .font(.displayXL)
                    .foregroundStyle(Color.textOnBrand)

                Text("İngilizce kelime öğrenmenin en etkili yolu")
                    .font(.subText)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}
