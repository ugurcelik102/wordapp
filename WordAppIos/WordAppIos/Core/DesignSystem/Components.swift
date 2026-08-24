import SwiftUI

// MARK: - Vocabee Design System — Ortak bileşenler
//
// Her ekranın paylaştığı yapı taşları. Ekranlar bunları kullanınca
// görsel tutarlılık otomatik gelir.

// MARK: Ekran sarmalayıcı (zemin + kaydırma + padding)

/// Standart ekran zemini ve kenar boşluğunu tek yerden verir.
struct AppScreen<Content: View>: View {
    var scroll: Bool = true
    var padded: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Group {
                if scroll {
                    ScrollView { inner }
                } else {
                    inner
                }
            }
        }
    }

    private var inner: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padded ? Spacing.lg : 0)
    }
}

// MARK: Kart

/// Standart kart yüzeyi: köşe, zemin ve gölge tutarlı.
struct Card<Content: View>: View {
    var padding: CGFloat = Spacing.lg
    var radius: CGFloat = Radius.card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .softShadow()
    }
}

extension View {
    /// Herhangi bir view'ı kart yüzeyine oturtur.
    func cardSurface(padding: CGFloat = Spacing.lg, radius: CGFloat = Radius.card) -> some View {
        self
            .padding(padding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .softShadow()
    }
}

// MARK: Butonlar

/// Ana eylem butonu — dolu, marka renginde.
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var fill: Color = .brandPrimary
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title).font(.bodyStrong)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(Color.textOnBrand)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .disabled(isLoading)
    }
}

/// İkincil eylem butonu — çerçeveli, saydam zemin.
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = .brandPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.bodyStrong)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(tint)
            .background(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(tint.opacity(0.4), lineWidth: 1.5)
            )
        }
    }
}

// MARK: Bölüm başlığı

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "Tümü"

    var body: some View {
        HStack {
            Text(title).font(.heading).foregroundStyle(Color.textPrimary)
            Spacer()
            if let action {
                Button(actionTitle, action: action)
                    .font(.subText).foregroundStyle(Color.brandPrimary)
            }
        }
    }
}
