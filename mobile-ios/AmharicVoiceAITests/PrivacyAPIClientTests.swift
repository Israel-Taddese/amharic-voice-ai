import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import AmharicVoiceAI

@MainActor
final class PrivacyAPIClientTests: XCTestCase {
    private let configuration = BackendConfiguration(
        baseURL: URL(string: "https://privacy-tests.invalid")!
    )
    private let payload = TextTranslateRequest(text: "Hello", direction: .englishToAmharic)
    private let missingRecordingURL = URL(fileURLWithPath: "/missing/amharicvoice-consent-test.wav")

    func testTextTranslationIsDeniedByDefaultBeforeCallingSession() async {
        let session = PrivacyRecordingHTTPSession { _ in
            throw PrivacySessionTestError.unexpectedRequest
        }
        let client = APIClient(configuration: configuration, session: session)

        do {
            _ = try await client.translateText(payload)
            XCTFail("Expected consent to be required")
        } catch {
            assertConsentRequired(error)
        }

        XCTAssertEqual(session.requestCount, 0)
    }

    func testSpeechTranslationIsDeniedBeforeAccessingMissingFile() async {
        let session = PrivacyRecordingHTTPSession { _ in
            throw PrivacySessionTestError.unexpectedRequest
        }
        let client = APIClient(configuration: configuration, session: session)

        do {
            _ = try await client.translateSpeech(
                audioFileURL: missingRecordingURL,
                direction: .amharicToEnglish,
                speakOutput: true
            )
            XCTFail("Expected consent to be required before file access")
        } catch {
            assertConsentRequired(error)
        }

        XCTAssertEqual(session.requestCount, 0)
    }

    func testGeneratedAudioIsDeniedBeforeCallingSession() async {
        let session = PrivacyRecordingHTTPSession { _ in
            throw PrivacySessionTestError.unexpectedRequest
        }
        let client = APIClient(configuration: configuration, session: session)

        do {
            _ = try await client.fetchGeneratedAudio(at: "/audio/fixture.mp3")
            XCTFail("Expected consent to be required")
        } catch {
            assertConsentRequired(error)
        }

        XCTAssertEqual(session.requestCount, 0)
    }

    func testTextRequestConstructionRequiresConsent() {
        let session = PrivacyRecordingHTTPSession { _ in
            throw PrivacySessionTestError.unexpectedRequest
        }
        let client = APIClient(configuration: configuration, session: session)

        XCTAssertThrowsError(try client.makeTextTranslationRequest(payload)) { error in
            self.assertConsentRequired(error)
        }
        XCTAssertEqual(session.requestCount, 0)
    }

    func testSpeechRequestConstructionRequiresConsentBeforeFileAccess() {
        let session = PrivacyRecordingHTTPSession { _ in
            throw PrivacySessionTestError.unexpectedRequest
        }
        let client = APIClient(configuration: configuration, session: session)

        XCTAssertThrowsError(
            try client.makeSpeechTranslationRequest(
                audioFileURL: missingRecordingURL,
                direction: .amharicToEnglish,
                speakOutput: false
            )
        ) { error in
            self.assertConsentRequired(error)
        }
        XCTAssertEqual(session.requestCount, 0)
    }

    func testHealthRemainsAvailableWithoutConsent() async throws {
        let session = PrivacyRecordingHTTPSession { request in
            let response = try privacyHTTPResponse(for: request)
            return (Data(#"{"status":"ok","service":"amharic-voice-ai"}"#.utf8), response)
        }
        let client = APIClient(configuration: configuration, session: session)

        let response = try await client.health()

        XCTAssertEqual(response, HealthResponse(status: "ok", service: "amharic-voice-ai"))
        XCTAssertEqual(session.requestCount, 1)
    }

    func testGrantedConsentAllowsTextTranslation() async throws {
        let consent = ProcessingConsentStore()
        consent.grant()
        let session = PrivacyRecordingHTTPSession { request in
            (privacyTranslationResponseData(), try privacyHTTPResponse(for: request))
        }
        let client = APIClient(configuration: configuration, session: session, consent: consent)

        let response = try await client.translateText(payload)

        XCTAssertEqual(response.translatedText, "ሰላም")
        XCTAssertEqual(session.requestCount, 1)
    }

    func testRegrantDoesNotAuthorizeLateResponseFromWithdrawnConsent() async throws {
        let started = expectation(description: "First translation reached injected session")
        let consent = ProcessingConsentStore()
        consent.grant()
        let session = PrivacyControlledHTTPSession(firstRequestStarted: started)
        let client = APIClient(configuration: configuration, session: session, consent: consent)

        let translation = Task { try await client.translateText(payload) }
        await fulfillment(of: [started], timeout: 1)

        consent.withdraw()
        consent.grant()
        session.completeFirstRequest()

        do {
            _ = try await translation.value
            XCTFail("A later grant must not authorize the old response")
        } catch is CancellationError {
            // A stale authorization stays invalid even when consent is granted again.
        } catch {
            XCTFail("Expected CancellationError, received \(error)")
        }

        let newResponse = try await client.translateText(payload)
        XCTAssertEqual(newResponse.translatedText, "ሰላም")
        XCTAssertEqual(session.requestCount, 2)
    }

    private func assertConsentRequired(
        _ error: Error,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case ProcessingConsentError.required = error else {
            XCTFail("Expected ProcessingConsentError.required, received \(error)", file: file, line: line)
            return
        }
    }
}

private enum PrivacySessionTestError: Error {
    case unexpectedRequest
    case invalidRequest
}

private func privacyHTTPResponse(for request: URLRequest) throws -> HTTPURLResponse {
    guard let url = request.url,
          let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
          ) else {
        throw PrivacySessionTestError.invalidRequest
    }
    return response
}

private func privacyTranslationResponseData() -> Data {
    Data(
        #"{"source_language":"en","target_language":"am","original_text":"Hello","translated_text":"ሰላም","normalized_text":null,"normalization_applied":false,"normalization_note":null}"#.utf8
    )
}

private final class PrivacyRecordingHTTPSession: HTTPSession {
    private let handler: (URLRequest) throws -> (Data, URLResponse)
    private let lock = NSLock()
    private var count = 0

    init(handler: @escaping (URLRequest) throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        recordRequest()
        return try handler(request)
    }

    private func recordRequest() {
        lock.lock()
        defer { lock.unlock() }
        count += 1
    }
}

private final class PrivacyControlledHTTPSession: HTTPSession {
    private let firstRequestStarted: XCTestExpectation
    private let lock = NSLock()
    private var count = 0
    private var continuation: CheckedContinuation<(Data, URLResponse), Error>?
    private var firstResponse: HTTPURLResponse?

    init(firstRequestStarted: XCTestExpectation) {
        self.firstRequestStarted = firstRequestStarted
    }

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = try privacyHTTPResponse(for: request)
        if isFirstRequest() {
            return try await withCheckedThrowingContinuation { continuation in
                holdFirstRequest(continuation, response: response)
                firstRequestStarted.fulfill()
            }
        }
        return (privacyTranslationResponseData(), response)
    }

    func completeFirstRequest() {
        lock.lock()
        let pending = continuation
        let response = firstResponse
        continuation = nil
        firstResponse = nil
        lock.unlock()

        guard let pending, let response else {
            preconditionFailure("No first request is waiting for completion")
        }
        pending.resume(returning: (privacyTranslationResponseData(), response))
    }

    private func isFirstRequest() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count == 1
    }

    private func holdFirstRequest(
        _ continuation: CheckedContinuation<(Data, URLResponse), Error>,
        response: HTTPURLResponse
    ) {
        lock.lock()
        defer { lock.unlock() }
        self.continuation = continuation
        firstResponse = response
    }
}
