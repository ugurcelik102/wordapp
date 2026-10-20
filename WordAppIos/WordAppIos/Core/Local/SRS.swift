import Foundation

/// SM-2 aralıklı tekrar algoritması.
///
/// Sunucudaki `app/services/srs.py` ile birebir aynı davranır; hesap artık
/// cihazda yapılır.
/// Referans: https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
enum SRS {

    struct Result {
        let easeFactor: Double
        let intervalDays: Int
        let repetitions: Int
        let nextReviewDate: Date
    }

    /// Bir cevaptan sonra yeni SRS durumunu hesaplar.
    /// - Parameter quality: 0-5 arası; verilmezse `isCorrect`'ten türetilir.
    static func update(
        easeFactor: Double,
        intervalDays: Int,
        repetitions: Int,
        isCorrect: Bool,
        quality: Int? = nil
    ) -> Result {
        let q = quality ?? (isCorrect ? 4 : 1)

        let newRepetitions: Int
        let newInterval: Int
        if q < 3 {
            // Yanlış cevap: sıfırdan başla.
            newRepetitions = 0
            newInterval = 1
        } else {
            switch repetitions {
            case 0:  newInterval = 1
            case 1:  newInterval = 6
            default: newInterval = Int(ceil(Double(intervalDays) * easeFactor))
            }
            newRepetitions = repetitions + 1
        }

        let delta = 0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02)
        let newEase = max(1.3, easeFactor + delta)

        let next = Calendar.current.date(
            byAdding: .day, value: newInterval, to: Date.today
        ) ?? Date.today

        return Result(
            easeFactor: newEase,
            intervalDays: newInterval,
            repetitions: newRepetitions,
            nextReviewDate: next
        )
    }

    /// Tekrar sayısına göre kelime durumu.
    ///
    /// Asla "new" dönmez: bu yalnızca kullanıcı cevap verdikten SONRA çağrılır,
    /// yani kelime artık çalışılmıştır. Yanlış cevapta SM-2 tekrar sayısını
    /// sıfırlar; kelime "new" değil yeniden öğrenilen ("learning") bir kelimedir
    /// ve tekrar havuzunda KALMALIDIR.
    static func newStatus(repetitions: Int, intervalDays: Int) -> WordStatus {
        if repetitions < 3 { return .learning }
        if intervalDays < 21 { return .review }
        return .mastered
    }
}

/// Bir kelimenin öğrenilme durumu.
enum WordStatus: String, Codable, Hashable {
    case new, learning, review, mastered
}

extension Date {
    /// Günün başlangıcı — SRS tarih karşılaştırmaları gün bazlıdır.
    static var today: Date { Calendar.current.startOfDay(for: Date()) }

    var dayKey: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }
}
