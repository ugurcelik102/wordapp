import SwiftUI
import UIKit

/// Okuma parçası metnini gösterir; hedef (çalışılan) kelimeleri yeşil renkte vurgular.
struct HighlightedPassageText: View {
    let content: String
    let targets: [String]
    var fontSize: CGFloat = 17

    var body: some View {
        Text(attributed)
            .font(.system(size: fontSize))
            .lineSpacing(6)
    }

    private var attributed: AttributedString {
        let mutable = NSMutableAttributedString(string: content)
        let fullRange = NSRange(location: 0, length: (content as NSString).length)

        for target in targets where !target.trimmingCharacters(in: .whitespaces).isEmpty {
            // Tam kelime eşleşmesi (\bkelime\b), büyük/küçük harf duyarsız.
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: target))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            for match in regex.matches(in: content, range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: match.range)
                mutable.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize), range: match.range)
            }
        }
        return AttributedString(mutable)
    }
}

/// Okuma ekranlarında yazı boyutunu büyütüp küçültmek için kontrol.
struct FontSizeControls: View {
    @Binding var fontSize: CGFloat
    var range: ClosedRange<CGFloat> = 13...30
    var step: CGFloat = 2

    var body: some View {
        HStack(spacing: 18) {
            Button {
                fontSize = max(range.lowerBound, fontSize - step)
            } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .disabled(fontSize <= range.lowerBound)

            Button {
                fontSize = min(range.upperBound, fontSize + step)
            } label: {
                Image(systemName: "textformat.size.larger")
            }
            .disabled(fontSize >= range.upperBound)
        }
    }
}
