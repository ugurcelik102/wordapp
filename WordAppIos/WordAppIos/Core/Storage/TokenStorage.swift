import Foundation
import Security

/// Auth token'ı Keychain'de saklar (UserDefaults yerine).
/// Keychain, cihaz kilitliyken bile şifreli tutulur ve uygulama silinip
/// yeniden yüklendiğinde varsayılan olarak temizlenmez; bu yüzden App Store
/// incelemesinde beklenen "hassas veriyi güvenli saklama" pratiğine uyar.
final class TokenStorage {
    static let shared = TokenStorage()
    private let service = Bundle.main.bundleIdentifier ?? "com.aydevo.WordAppIos"
    private let account = "auth_token"
    private init() {}

    var token: String? {
        get { read() }
        set {
            if let value = newValue {
                save(value)
            } else {
                delete()
            }
        }
    }

    var isLoggedIn: Bool { token != nil }

    func clear() { token = nil }

    // MARK: - Keychain helpers

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func read() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func save(_ value: String) {
        let data = Data(value.utf8)
        var query = baseQuery()

        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            let attributes: [String: Any] = [kSecValueData as String: data]
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    private func delete() {
        let query = baseQuery()
        SecItemDelete(query as CFDictionary)
    }
}
