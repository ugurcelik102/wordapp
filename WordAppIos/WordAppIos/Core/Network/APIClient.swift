import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case badRequest(String)          // 4xx: backend'in kullanıcıya yönelik mesajı
    case unavailable                 // 404: uç sunucuda yok (ör. henüz deploy edilmemiş)
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Geçersiz URL"
        case .unauthorized:        return "Oturum süresi doldu. Lütfen tekrar giriş yapın."
        case .badRequest(let msg): return msg
        case .unavailable:         return "Bu özellik şu an kullanılamıyor. Lütfen daha sonra tekrar dene."
        case .serverError(let code, let msg): return "Sunucu hatası (\(code)): \(msg)"
        case .decodingError(let e):    return "Veri hatası: \(e.localizedDescription)"
        case .networkError(let e):     return e.localizedDescription
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private let baseURL = "https://wordapp-production-bf22.up.railway.app/api/v1"
    private let session = URLSession.shared

    private init() {}

    // MARK: - Core request

    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Üyelik yok; sunucu kotayı cihaz başına uygular.
        req.setValue(DeviceID.current, forHTTPHeaderField: "X-Device-Id")

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        guard (200..<300).contains(http.statusCode) else {
            // Önce {detail: ...} dene; yoksa ham gövdeyi göster (teşhis için).
            let detail = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.detail

            // 404: istenen uç sunucuda yok. FastAPI'nin "Not Found" metni
            // kullanıcıya bir şey anlatmadığı için yerine anlaşılır bir mesaj göster.
            if http.statusCode == 404 { throw APIError.unavailable }

            // 4xx istemci hataları: backend'in kullanıcıya yönelik mesajını olduğu gibi ilet.
            // (Üyelik olmadığı için 401 beklenmez; 429 kota mesajı buradan geçer.)
            if (400..<500).contains(http.statusCode), let detail {
                throw APIError.badRequest(detail)
            }

            let rawBody = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let msg = detail ?? (rawBody.isEmpty ? "bilinmeyen hata" : String(rawBody.prefix(300)))
            throw APIError.serverError(http.statusCode, msg)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// Gövde beklemeyen istekler için (ör. 204 No Content dönen DELETE).
    func requestNoContent(
        _ endpoint: String,
        method: String = "DELETE",
        body: Encodable? = nil
    ) async throws {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Üyelik yok; sunucu kotayı cihaz başına uygular.
        req.setValue(DeviceID.current, forHTTPHeaderField: "X-Device-Id")

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.detail

            if http.statusCode == 404 { throw APIError.unavailable }

            if (400..<500).contains(http.statusCode), let detail {
                throw APIError.badRequest(detail)
            }

            let rawBody = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let msg = detail ?? (rawBody.isEmpty ? "bilinmeyen hata" : String(rawBody.prefix(300)))
            throw APIError.serverError(http.statusCode, msg)
        }
        // 2xx: gövde yok/önemsiz, başarı.
    }
}

private struct APIErrorResponse: Decodable {
    let detail: String
}
