import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol HTTPSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}

protocol APIClientProtocol {
    func health() async throws -> HealthResponse
    func translateText(_ request: TextTranslateRequest) async throws -> TextTranslateResponse
}

enum APIClientError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String?)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The backend returned an invalid response."
        case let .httpStatus(statusCode, detail):
            return detail ?? "The backend returned HTTP \(statusCode)."
        case let .decoding(message):
            return "The backend response could not be read: \(message)"
        case let .transport(message):
            return "The backend could not be reached: \(message)"
        }
    }
}

final class APIClient: APIClientProtocol {
    private struct BackendErrorResponse: Decodable {
        let detail: String
    }

    private let configuration: BackendConfiguration
    private let session: HTTPSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: BackendConfiguration = .current,
        session: HTTPSession? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.configuration = configuration
        self.session = session ?? Self.makeEphemeralSession()
        self.encoder = encoder
        self.decoder = decoder
    }

    func health() async throws -> HealthResponse {
        try await execute(makeHealthRequest())
    }

    func translateText(_ request: TextTranslateRequest) async throws -> TextTranslateResponse {
        try await execute(makeTextTranslationRequest(request))
    }

    func makeHealthRequest() -> URLRequest {
        var request = makeRequest(path: "health")
        request.httpMethod = "GET"
        return request
    }

    func makeTextTranslationRequest(_ payload: TextTranslateRequest) throws -> URLRequest {
        var request = makeRequest(path: "api/text-translate")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)
        return request
    }

    private func makeRequest(path: String) -> URLRequest {
        var request = URLRequest(
            url: configuration.endpoint(path),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 90
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func execute<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as APIClientError {
            throw error
        } catch {
            throw APIClientError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let detail = try? decoder.decode(BackendErrorResponse.self, from: data).detail
            throw APIClientError.httpStatus(httpResponse.statusCode, detail)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIClientError.decoding(error.localizedDescription)
        }
    }

    private static func makeEphemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 120
        return URLSession(configuration: configuration)
    }
}
