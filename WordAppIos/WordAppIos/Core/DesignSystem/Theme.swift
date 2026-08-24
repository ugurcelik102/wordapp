import SwiftUI

// MARK: - Vocabee Design System — Renk Paleti (tek kaynak)
//
// Yeni görsel dil. Tüm ekranlar renkleri buradan alır.
// Ham `Color(red:green:blue:)` kullanımı kaldırılacak; yerine `Color.brand...`,
// `Color.accent...` ve semantik roller (`Color.appBackground`, `.textPrimary`...) gelir.

extension Color {

    // MARK: Marka renkleri
    /// Ana marka rengi — Vocabee yeşili.
    static let brandPrimary   = Color.adaptive(light: "#47875D", dark: "#47875D")
    /// Ana marka renginin koyu tonu (gradient/pressed durumlar).
    static let brandPrimaryDark = Color.adaptive(light: "#37694A", dark: "#37694A")
    /// İkincil marka rengi — Vocabee sarısı (açık, pastel).
    static let brandSecondary = Color.adaptive(light: "#F6F7C5", dark: "#F6F7C5")

    // MARK: Aksan paleti (kategori kartları, ikonlar, vurgu)
    static let accentBlue   = Color.adaptive(light: "#2F9BF0", dark: "#57B0F5")
    static let accentOrange = Color.adaptive(light: "#F59211", dark: "#FFAA3D")
    static let accentPurple = Color.adaptive(light: "#7E63D6", dark: "#9C85E8")
    static let accentTeal   = Color.adaptive(light: "#17A6A8", dark: "#33C4C6")
    static let accentPink   = Color.adaptive(light: "#F0857A", dark: "#F7A199")
    /// Görev ekranlarının yeşili — marka yeşiliyle aynı (#47875D) ve koyu karşılığı.
    static let taskGreen     = brandPrimary
    static let taskGreenDark = brandPrimaryDark

    /// Görev sarısı — marka sarısıyla aynı (#F6F7C5) ve bir tık koyu karşılığı.
    static let taskYellow     = brandSecondary
    static let taskYellowDark = Color.adaptive(light: "#E8EAAF", dark: "#E8EAAF")

    static let accentBrown  = Color.adaptive(light: "#8B5E3C", dark: "#A3714B")
    static let accentBrownDark = Color.adaptive(light: "#6B462B", dark: "#7E5537")

    // MARK: Anlamsal (semantic) renkler
    static let success = brandPrimary
    static let warning = Color.adaptive(light: "#F5A623", dark: "#FFBB4D")
    static let danger  = Color.adaptive(light: "#DB3D3D", dark: "#F26060")

    // MARK: Yüzeyler ve zemin
    /// Ekran zemini.
    static let appBackground     = Color.adaptive(light: "#F4F6F8", dark: "#0E1214")
    /// Kart / panel yüzeyi.
    static let cardBackground    = Color.adaptive(light: "#FFFFFF", dark: "#1A2024")
    /// Kart üzerinde ikinci kademe yüzey (input, chip vb.).
    static let surfaceSecondary  = Color.adaptive(light: "#EEF1F4", dark: "#242C31")
    /// İnce ayraç / kenarlık.
    static let separator         = Color.adaptive(light: "#E2E6EA", dark: "#2E363C")

    // MARK: Immersive akış zeminleri (renkli kimlik + mod uyumlu)
    // Alıştırma/akış ekranlarının tam-ekran renkli zeminleri. Gündüz canlı,
    // gece derin ton → üstteki kartlar ve beyaz metin her iki modda okunur.
    static let flowBlue   = Color.adaptive(light: "#2A8FE0", dark: "#0E2233")
    static let flowGreen  = Color.adaptive(light: "#47875D", dark: "#1B3325")
    static let flowPurple = Color.adaptive(light: "#6E56C8", dark: "#1A1430")

    // MARK: Metin renkleri
    static let textPrimary   = Color.adaptive(light: "#131A1F", dark: "#F2F5F7")
    static let textSecondary = Color.adaptive(light: "#5B6670", dark: "#A3AEB6")
    static let textTertiary  = Color.adaptive(light: "#8A939B", dark: "#6C767E")
    /// Renkli/koyu zemin üzerindeki metin.
    static let textOnBrand   = Color.white
}

// MARK: - Gradyanlar (kart ve buton dolguları)

extension LinearGradient {
    /// İki renkli, sol-üst → sağ-alt marka gradyanı.
    static func brand(_ top: Color, _ bottom: Color) -> LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let primary = LinearGradient.brand(.brandPrimary, .brandPrimaryDark)
}
