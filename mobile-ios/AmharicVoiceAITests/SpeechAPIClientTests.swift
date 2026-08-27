import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import AmharicVoiceAI

final class SpeechAPIClientTests: XCTestCase {
    private let baseURL = URL(string: "https://example.com")!

    func testMultipartSpeechRequestConstruction() throws {
        let audioURL = try makeTemporaryWAV(data: Data("RIFF-test-wave".utf8))
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let client = makeClient(session: RejectingHTTPSession())

        let request = try client.makeSpeechTranslationRequest(
            audioFileURL: audioURL,
            direction: .amharicToEnglish,
            speakOutput: true,
            boundary: "TestBoundary"
        )
        let body = try XCTUnwrap(request.httpBody)
        let bodyText = String(decoding: body, as: UTF8.self)

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/speech-translate")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.timeoutInterval, 120)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "multipart/form-data; boundary=TestBoundary"
        )
        XCTAssertTrue(bodyText.contains("name=\"direction\"\r\n\r\nam-en\r\n"))
        XCTAssertTrue(bodyText.contains("name=\"speak_output\"\r\n\r\ntrue\r\n"))
        XCTAssertTrue(bodyText.contains("name=\"audio\"; filename=\"recording.wav\""))
        XCTAssertTrue(bodyText.contains("Content-Type: audio/wav\r\n\r\nRIFF-test-wave"))
        XCTAssertTrue(bodyText.hasSuffix("\r\n--TestBoundary--\r\n"))
    }

    func testOversizedRecordingIsRejectedBeforeMultipartConstruction() throws {
        let audioURL = try makeSparseTemporaryWAV(
            size: SpeechRecordingLimits.backendMaximumUploadBytes + 1
        )
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let client = makeClient(session: RejectingHTTPSession())

        XCTAssertThrowsError(
            try client.makeSpeechTranslationRequest(
                audioFileURL: audioURL,
                direction: .amharicToEnglish,
                speakOutput: true,
                boundary: "TestBoundary"
            )
        ) { error in
            guard case APIClientError.recordingTooLarge = error else {
                XCTFail("Expected recordingTooLarge, received \(error)")
                return
            }
        }
    }

    func testSpeechTranslationUsesInjectedSessionAndDecodesResponse() async throws {
        let audioURL = try makeTemporaryWAV(data: Data("RIFF".utf8))
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let responseData = Data(
            #"{"direction":"am-en","speech_locale":"am-ET","source_language":"am","target_language":"en","transcript":"ሰላም","translated_text":"Hello","normalized_text":"ሰላም","normalization_applied":true,"normalization_note":"Greeting normalized","audio_url":"/audio/result.mp3","audio_mime_type":"audio/mpeg"}"#.utf8
        )
        let session = RecordingHTTPSession { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (responseData, response)
        }
        let client = makeClient(session: session)

        let response = try await client.translateSpeech(
            audioFileURL: audioURL,
            direction: .amharicToEnglish,
            speakOutput: true
        )

        XCTAssertEqual(response.direction, .amharicToEnglish)
        XCTAssertEqual(response.speechLocale, "am-ET")
        XCTAssertEqual(response.sourceLanguage, "am")
        XCTAssertEqual(response.targetLanguage, "en")
        XCTAssertEqual(response.transcript, "ሰላም")
        XCTAssertEqual(response.translatedText, "Hello")
        XCTAssertEqual(response.normalizedText, "ሰላም")
        XCTAssertTrue(response.normalizationApplied)
        XCTAssertEqual(response.normalizationNote, "Greeting normalized")
        XCTAssertEqual(response.audioURL, "/audio/result.mp3")
        XCTAssertEqual(response.audioMimeType, "audio/mpeg")
        XCTAssertEqual(session.requests.count, 1)
    }

    func testResolvesRelativeGeneratedAudioAgainstConfiguredOrigin() throws {
        let client = makeClient(session: RejectingHTTPSession())

        let resolved = try client.resolveGeneratedAudioURL("/audio/translated.mp3")

        XCTAssertEqual(resolved.absoluteString, "https://example.com/audio/translated.mp3")
    }

    func testAcceptsAbsoluteGeneratedAudioOnlyOnConfiguredOrigin() throws {
        let client = makeClient(session: RejectingHTTPSession())

        let resolved = try client.resolveGeneratedAudioURL("https://example.com:443/audio/translated.mp3")

        XCTAssertEqual(resolved.host, "example.com")
        XCTAssertEqual(resolved.path, "/audio/translated.mp3")
    }

    func testRejectsUnexpectedGeneratedAudioHostAndUnsafePaths() {
        let client = makeClient(session: RejectingHTTPSession())
        let rejectedValues = [
            "https://attacker.example/audio/translated.mp3",
            "http://example.com/audio/translated.mp3",
            "https://example.com:444/audio/translated.mp3",
            "//attacker.example/audio/translated.mp3",
            "/audio/../private/file.mp3",
            "/audio/%2e%2e/private/file.mp3",
            "/audio/subdirectory/file.mp3",
            "/audio/file.wav",
            "/not-audio/file.mp3",
            "/audio/file.mp3?token=value",
            "/audio/file.mp3#fragment"
        ]

        for value in rejectedValues {
            XCTAssertThrowsError(try client.resolveGeneratedAudioURL(value), "Expected rejection for \(value)") {
                guard case APIClientError.invalidAudioURL = $0 else {
                    XCTFail("Expected invalidAudioURL for \(value), received \($0)")
                    return
                }
            }
        }
    }

    func testGeneratedAudioFetchUsesInjectedSession() async throws {
        let expectedData = Data([0x49, 0x44, 0x33])
        let session = RecordingHTTPSession { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "audio/mpeg"]
            )!
            return (expectedData, response)
        }
        let client = makeClient(session: session)

        let data = try await client.fetchGeneratedAudio(at: "/audio/translated.mp3")

        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(session.requests.first?.url?.absoluteString, "https://example.com/audio/translated.mp3")
        XCTAssertEqual(session.requests.first?.httpMethod, "GET")
        XCTAssertEqual(session.requests.first?.value(forHTTPHeaderField: "Accept"), "audio/mpeg")
    }

    private func makeClient(session: HTTPSession) -> APIClient {
        APIClient(
            configuration: BackendConfiguration(baseURL: baseURL),
            session: session
        )
    }

    private func makeTemporaryWAV(data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-api-client-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makeSparseTemporaryWAV(size: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-api-client-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw SpeechAPITestError.couldNotCreateTemporaryFile
        }
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(size))
        try handle.close()
        return url
    }
}

private enum SpeechAPITestError: Error {
    case unexpectedRequest
    case couldNotCreateTemporaryFile
}

private final class RejectingHTTPSession: HTTPSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        throw SpeechAPITestError.unexpectedRequest
    }
}

private final class RecordingHTTPSession: HTTPSession {
    private let handler: (URLRequest) throws -> (Data, URLResponse)
    private(set) var requests: [URLRequest] = []

    init(handler: @escaping (URLRequest) throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try handler(request)
    }
}
