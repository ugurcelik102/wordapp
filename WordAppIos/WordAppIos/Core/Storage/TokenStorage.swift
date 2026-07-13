import Foundation

final class TokenStorage {
    static let shared = TokenStorage()
    private let key = "auth_token"
    private init() {}

    var token: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    var isLoggedIn: Bool { token != nil }

    func clear() { token = nil }
}
