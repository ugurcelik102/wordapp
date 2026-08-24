import SwiftUI

// MARK: - Renk yardımcıları (hex + light/dark adaptif)
//
// Bu dosya Design System'in temelidir. Tüm renkler tek kaynaktan (Theme.swift)
// bu yardımcılarla üretilir; ekranlarda ham RGB değeri kullanılmamalıdır.

extension Color {
    /// Hex string ("#1E9E52" veya "1E9E52") ile Color üretir.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b, a: Double
        switch s.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1
        case 8:
            r = Double((value & 0xFF000000) >> 24) / 255
            g = Double((value & 0x00FF0000) >> 16) / 255
            b = Double((value & 0x0000FF00) >> 8) / 255
            a = Double(value & 0x000000FF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Light/dark için ayrı hex değerleriyle adaptif renk üretir.
    /// Böylece Asset Catalog'a dokunmadan dark mode doğru çalışır.
    static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}
