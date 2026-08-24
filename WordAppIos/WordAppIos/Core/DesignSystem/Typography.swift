import SwiftUI

// MARK: - Vocabee Design System — Tipografi ölçeği
//
// `.system(size: 44)` gibi sabit değerler yerine isimli stiller kullanılır.
// Hepsi Dynamic Type ile ölçeklenir → erişilebilirlik otomatik doğru çalışır.

extension Font {
    /// Splash / büyük sayaç ekranları için en büyük başlık.
    static let displayXL = Font.system(size: 44, weight: .bold, design: .rounded)
    static let display   = Font.system(size: 34, weight: .bold, design: .rounded)

    /// Ekran başlığı.
    static let titleLarge = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title      = Font.system(.title2, design: .rounded).weight(.bold)
    static let titleSmall = Font.system(.title3, design: .rounded).weight(.semibold)

    /// Kart başlıkları / vurgulu satırlar.
    static let heading   = Font.system(.headline, design: .rounded).weight(.semibold)
    /// Gövde metni.
    static let bodyText  = Font.system(.body, design: .default)
    static let bodyStrong = Font.system(.body, design: .default).weight(.semibold)
    /// İkincil / açıklama metni.
    static let subText   = Font.system(.subheadline, design: .default)
    /// En küçük etiketler.
    static let caption   = Font.system(.caption, design: .default)
    static let captionStrong = Font.system(.caption, design: .default).weight(.semibold)

    /// Sayaç / puan gibi rakamlar için (hizalı basamaklar).
    static let numeric = Font.system(.title3, design: .rounded).weight(.bold).monospacedDigit()
}

// MARK: - Metin stil kısayolları (font + renk bir arada)

extension View {
    /// Birincil başlık stili.
    func titleStyle() -> some View {
        self.font(.title).foregroundStyle(Color.textPrimary)
    }
    /// Gövde stili.
    func bodyStyle() -> some View {
        self.font(.bodyText).foregroundStyle(Color.textPrimary)
    }
    /// İkincil açıklama stili.
    func secondaryStyle() -> some View {
        self.font(.subText).foregroundStyle(Color.textSecondary)
    }
}
