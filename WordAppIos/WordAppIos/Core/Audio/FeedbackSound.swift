import AudioToolbox
import UIKit

/// Doğru/yanlış cevaplarda kısa ses + titreşim geri bildirimi.
/// Sistem sesleri kullanılır; ek ses dosyası gerekmez.
enum FeedbackSound {

    /// Doğru cevap — kısa, olumlu "tink" + başarı titreşimi.
    static func correct() {
        AudioServicesPlaySystemSound(1057)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Yanlış cevap — alçalan uyarı tonu + hata titreşimi.
    static func wrong() {
        AudioServicesPlaySystemSound(1024)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func play(correct: Bool) {
        correct ? self.correct() : wrong()
    }
}
