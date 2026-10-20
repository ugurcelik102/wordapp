import Foundation
import UIKit

/// Sunucunun yapay zekâ kotasını uyguladığı cihaz kimliği.
///
/// Üyelik kaldırıldığı için istekleri ayırt edecek başka bir şey yok.
/// `identifierForVendor` uygulama silinip yeniden kurulduğunda değişebildiği
/// için değer bir kez üretilip UserDefaults'ta saklanır; böylece kota
/// gün içinde sıfırlanmaz.
enum DeviceID {
    private static let key = "device_id"

    static let current: String = {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        defaults.set(generated, forKey: key)
        return generated
    }()
}
