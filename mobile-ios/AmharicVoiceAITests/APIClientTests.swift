import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import AmharicVoiceAI

final class APIClientTests: XCTestCase {
    func testHealthRequestConstruction() throws {
        let session = MockHTTPSession { _ in
            throw TestError.unexpectedRequest
        }
        let client = APIClient(
            configuration: BackendConfiguration(baseURL: URL(string: "https://example.com")!),
            session: session
        )

        let request = client.makeHealthRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/health")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNil(request.httpBody)
    }

    func testTextTranslationRequestConstruction() throws {
        let session = MockHTTPSession { _ in
            throw TestError.unexpectedRequest
        }
        let client = APIClient(
            configuration: BackendConfiguration(baseURL: URL(string: "https://example.com")!),
            session: session
        )
        let payload = TextTranslateRequest(text: "ሰላም", direction: .amharicToEnglish)

        let request = try client.makeTextTranslationRequest(payload)

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/text-translate")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(try JSONDecoder().decode(TextTranslateRequest.self, from: request.httpBody!), payload)
    }

    func testHealthUsesInjectedSessionAndDecodesResponse() async throws {
        let session = MockHTTPSession { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (Data(#"{"status":"ok","service":"amharic-voice-ai"}"#.utf8), response)
        }
        let client = APIClient(
            configuration: BackendConfiguration(baseURL: URL(string: "https://example.com")!),
            session: session
        )

        let health = try await client.health()

        XCTAssertEqual(health, HealthResponse(status: "ok", service: "amharic-voice-ai"))
        XCTAssertEqual(session.requests.count, 1)
    }

    func testTextTranslationUsesInjectedSessionAndDecodesResponse() async throws {
        let responseData = Data(
            #"{"source_language":"en","target_language":"am","original_text":"Hello","translated_text":"ሰላም","normalized_text":"hello","normalization_applied":true,"normalization_note":"Greeting normalized"}"#.utf8
        )
        let session = MockHTTPSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (responseData, response)
        }
        let client = APIClient(
            configuration: BackendConfiguration(baseURL: URL(string: "https://example.com")!),
            session: session
        )

        let response = try await client.translateText(
            TextTranslateRequest(text: "Hello", direction: .englishToAmharic)
        )

        XCTAssertEqual(response.translatedText, "ሰላም")
        XCTAssertTrue(response.normalizationApplied)
        XCTAssertEqual(session.requests.count, 1)
    }

    func testBackendErrorDetailIsExposedWithoutMakingAnotherRequest() async {
        let session = MockHTTPSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 422,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(#"{"detail":"Invalid direction"}"#.utf8), response)
        }
        let client = APIClient(
            configuration: BackendConfiguration(baseURL: URL(string: "https://example.com")!),
            session: session
        )

        do {
            _ = try await client.translateText(
                TextTranslateRequest(text: "Hello", direction: .englishToAmharic)
            )
            XCTFail("Expected the request to fail")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Invalid direction")
        }

        XCTAssertEqual(session.requests.count, 1)
    }

    func testMalformedSuccessfulResponseThrowsDecodingError() async {
        let session = MockHTTPSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (Data("{\"status\":\"ok\"".utf8), response)
        }
        let client = APIClient(
            configuration: BackendConfiguration(baseURL: URL(string: "https://example.com")!),
            session: session
        )

        do {
            _ = try await client.health()
            XCTFail("Expected malformed JSON to fail decoding")
        } catch let error as APIClientError {
            guard case let .decoding(message) = error else {
                XCTFail("Expected a decoding error, received \(error)")
                return
            }
            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Expected APIClientError.decoding, received \(error)")
        }
    }

    func testTransportFailureIsWrappedAsTransportError() async {
        let session = MockHTTPSession { _ in
            throw URLError(.notConnectedToInternet)
        }
        let client = APIClient(
            configuration: BackendConfiguration(baseURL: URL(string: "https://example.com")!),
            session: session
        )

        do {
            _ = try await client.health()
            XCTFail("Expected the transport to fail")
        } catch let error as APIClientError {
            guard case let .transport(message) = error else {
                XCTFail("Expected a transport error, received \(error)")
                return
            }
            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Expected APIClientError.transport, received \(error)")
        }
    }

    func testNonHTTPResponseThrowsInvalidResponseError() async {
        let session = MockHTTPSession { request in
            let response = URLResponse(
                url: request.url!,
                mimeType: "application/json",
                expectedContentLength: 0,
                textEncodingName: "utf-8"
            )
            return (Data(), response)
        }
        let client = APIClient(
            configuration: BackendConfiguration(baseURL: URL(string: "https://example.com")!),
            session: session
        )

        do {
            _ = try await client.health()
            XCTFail("Expected a non-HTTP response to fail")
        } catch let error as APIClientError {
            guard case .invalidResponse = error else {
                XCTFail("Expected an invalid-response error, received \(error)")
                return
            }
        } catch {
            XCTFail("Expected APIClientError.invalidResponse, received \(error)")
        }
    }

    func testCancellationIsNotWrappedAsTransportError() async {
        let session = MockHTTPSession { _ in
            throw CancellationError()
        }
        let client = APIClient(
            configuration: BackendConfiguration(baseURL: URL(string: "https://example.com")!),
            session: session
        )

        do {
            _ = try await client.health()
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Cancellation must remain distinguishable from user-facing network failures.
        } catch {
            XCTFail("Expected CancellationError, received \(error)")
        }
    }
}

private enum TestError: Error {
    case unexpectedRequest
}

private final class MockHTTPSession: HTTPSession {
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
