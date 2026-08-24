import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case badRequest(String)          // 4xx: backend'in kullanıcıya yönelik mesajı
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Geçersiz URL"
        case .unauthorized:        return "Oturum süresi doldu. Lütfen tekrar giriş yapın."
        case .badRequest(let msg): return msg
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

        if let token = TokenStorage.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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

            // Oturum düşmesi YALNIZCA kimliği doğrulanmış isteklerde (token varken) geçerli.
            // Token yokken gelen 401 bir giriş/kimlik-bilgisi hatasıdır → detay mesajını göster.
            if http.statusCode == 401, TokenStorage.shared.token != nil {
                TokenStorage.shared.clear()
                throw APIError.unauthorized
            }

            // 4xx istemci hataları: backend'in kullanıcıya yönelik mesajını olduğu gibi ilet.
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

        if let token = TokenStorage.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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

            if http.statusCode == 401, TokenStorage.shared.token != nil {
                TokenStorage.shared.clear()
                throw APIError.unauthorized
            }

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
