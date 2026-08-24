import SwiftUI

// MARK: - Vocabee Design System — Boşluk, köşe ve gölge sabitleri
//
// Tüm proje aynı ölçü sistemini kullanır. "16 mı 14 mü 18 mi" kararsızlığı biter.

enum Spacing {
    /// 4 — çok küçük iç boşluk.
    static let xs: CGFloat = 4
    /// 8 — küçük.
    static let sm: CGFloat = 8
    /// 12 — öğeler arası standart.
    static let md: CGFloat = 12
    /// 16 — bölüm iç boşluğu (varsayılan).
    static let lg: CGFloat = 16
    /// 24 — bölümler arası.
    static let xl: CGFloat = 24
    /// 32 — ekran üstü/altı geniş boşluk.
    static let xxl: CGFloat = 32
}

enum Radius {
    /// 10 — chip / küçük buton.
    static let small: CGFloat = 10
    /// 14 — buton (standart).
    static let button: CGFloat = 14
    /// 18 — kart (standart).
    static let card: CGFloat = 18
    /// 28 — büyük kart / modal / öne çıkan öğe.
    static let large: CGFloat = 28
}

// MARK: - Gölge stili

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    /// Kartlar için yumuşak gölge.
    static let card = ShadowStyle(color: .black.opacity(0.06), radius: 12, y: 4)
    /// Öne çıkan / basılabilir öğeler.
    static let elevated = ShadowStyle(color: .black.opacity(0.12), radius: 16, y: 6)
}

extension View {
    func softShadow(_ style: ShadowStyle = .card) -> some View {
        self.shadow(color: style.color, radius: style.radius, y: style.y)
    }
}
