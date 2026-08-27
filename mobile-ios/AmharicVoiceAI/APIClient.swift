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

protocol SpeechAPIClientProtocol {
    func translateSpeech(
        audioFileURL: URL,
        direction: TranslationDirection,
        speakOutput: Bool
    ) async throws -> SpeechTranslateResponse
    func fetchGeneratedAudio(at audioURL: String) async throws -> Data
}

enum APIClientError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String?)
    case decoding(String)
    case transport(String)
    case invalidAudioURL
    case recordingTooLarge

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
        case .invalidAudioURL:
            return "The generated audio URL is not allowed."
        case .recordingTooLarge:
            return "The recording exceeds the 5 MiB upload limit. Record no more than \(SpeechRecordingLimits.maximumDurationDescription)."
        }
    }
}

final class APIClient: APIClientProtocol, SpeechAPIClientProtocol {
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

    func translateSpeech(
        audioFileURL: URL,
        direction: TranslationDirection,
        speakOutput: Bool
    ) async throws -> SpeechTranslateResponse {
        let request = try makeSpeechTranslationRequest(
            audioFileURL: audioFileURL,
            direction: direction,
            speakOutput: speakOutput
        )
        return try await execute(request)
    }

    func fetchGeneratedAudio(at audioURL: String) async throws -> Data {
        var request = URLRequest(
            url: try resolveGeneratedAudioURL(audioURL),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 60
        )
        request.httpMethod = "GET"
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        return try await executeData(request)
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

    func makeSpeechTranslationRequest(
        audioFileURL: URL,
        direction: TranslationDirection,
        speakOutput: Bool,
        boundary: String = "AmharicVoice-\(UUID().uuidString)"
    ) throws -> URLRequest {
        let resourceValues = try audioFileURL.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = resourceValues.fileSize,
           fileSize > SpeechRecordingLimits.backendMaximumUploadBytes {
            throw APIClientError.recordingTooLarge
        }

        let audioData = try Data(contentsOf: audioFileURL, options: .mappedIfSafe)
        var body = Data()

        body.appendMultipartField(name: "direction", value: direction.rawValue, boundary: boundary)
        body.appendMultipartField(
            name: "speak_output",
            value: speakOutput ? "true" : "false",
            boundary: boundary
        )
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n")

        var request = makeRequest(path: "api/speech-translate", timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    func resolveGeneratedAudioURL(_ value: String) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: trimmed),
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            throw APIClientError.invalidAudioURL
        }

        let candidate: URL
        if components.scheme == nil, components.host == nil {
            guard trimmed.hasPrefix("/"),
                  let resolved = URL(string: trimmed, relativeTo: configuration.baseURL)?.absoluteURL else {
                throw APIClientError.invalidAudioURL
            }
            candidate = resolved
        } else {
            guard components.scheme != nil,
                  components.host != nil,
                  let absoluteURL = components.url else {
                throw APIClientError.invalidAudioURL
            }
            candidate = absoluteURL
        }

        components = URLComponents(url: candidate, resolvingAgainstBaseURL: true) ?? components
        let decodedPath = components.percentEncodedPath.removingPercentEncoding ?? components.path
        let pathSegments = decodedPath.split(separator: "/", omittingEmptySubsequences: true)

        guard sameOrigin(candidate, configuration.baseURL),
              pathSegments.count == 2,
              pathSegments.first == "audio",
              pathSegments.last?.lowercased().hasSuffix(".mp3") == true,
              !components.percentEncodedPath.contains("%"),
              !decodedPath.contains("\\"),
              !pathSegments.contains("."),
              !pathSegments.contains("..") else {
            throw APIClientError.invalidAudioURL
        }

        return candidate
    }

    private func makeRequest(path: String, timeoutInterval: TimeInterval = 90) -> URLRequest {
        var request = URLRequest(
            url: configuration.endpoint(path),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeoutInterval
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func execute<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data = try await executeData(request)

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIClientError.decoding(error.localizedDescription)
        }
    }

    private func executeData(_ request: URLRequest) async throws -> Data {
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

        return data
    }

    private func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && effectivePort(lhs) == effectivePort(rhs)
    }

    private func effectivePort(_ url: URL) -> Int? {
        if let port = url.port {
            return port
        }
        switch url.scheme?.lowercased() {
        case "https": return 443
        case "http": return 80
        default: return nil
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

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }
}
