import Foundation
import XCTest
@testable import AmharicVoiceAI

@MainActor
final class TranslationViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        let viewModel = TranslationViewModel(apiClient: MockAPIClient())

        XCTAssertEqual(viewModel.healthState, .idle)
        XCTAssertEqual(viewModel.translationState, .idle)
    }

    func testEmptyInputMovesToErrorWithoutCallingBackend() async {
        let client = MockAPIClient()
        let viewModel = TranslationViewModel(apiClient: client)
        viewModel.inputText = "  \n "

        await viewModel.translate()

        XCTAssertEqual(viewModel.translationState, .error("Enter text to translate."))
        XCTAssertTrue(client.translationRequests.isEmpty)
    }

    func testTranslationMovesThroughLoadingToSuccess() async {
        let expected = makeTranslationResponse()
        let translationStarted = expectation(description: "Translation request started")
        let client = ControlledTranslationAPIClient(translationStarted: translationStarted)
        let viewModel = TranslationViewModel(apiClient: client)
        viewModel.inputText = "  ሰላም  "

        let task = Task { await viewModel.translate() }
        await fulfillment(of: [translationStarted], timeout: 1)

        XCTAssertEqual(viewModel.translationState, .loading)

        client.completeTranslation(with: .success(expected))
        await task.value

        XCTAssertEqual(viewModel.translationState, .success(expected))
        XCTAssertEqual(
            client.translationRequests,
            [TextTranslateRequest(text: "ሰላም", direction: .amharicToEnglish)]
        )
    }

    func testEditingInputAfterSuccessClearsTranslation() async {
        let expected = makeTranslationResponse()
        let client = MockAPIClient(translationResult: .success(expected))
        let viewModel = TranslationViewModel(apiClient: client)
        viewModel.inputText = "ሰላም"

        await viewModel.translate()
        XCTAssertEqual(viewModel.translationState, .success(expected))

        viewModel.inputText = "ሰላም!"

        XCTAssertEqual(viewModel.translationState, .idle)
    }

    func testChangingDirectionAfterSuccessClearsTranslation() async {
        let expected = makeTranslationResponse()
        let client = MockAPIClient(translationResult: .success(expected))
        let viewModel = TranslationViewModel(apiClient: client)
        viewModel.inputText = "ሰላም"

        await viewModel.translate()
        XCTAssertEqual(viewModel.translationState, .success(expected))

        viewModel.direction = .englishToAmharic

        XCTAssertEqual(viewModel.translationState, .idle)
    }

    func testChangingDirectionDuringRequestDiscardsStaleResponse() async {
        let expected = makeTranslationResponse()
        let translationStarted = expectation(description: "Translation request started")
        let client = ControlledTranslationAPIClient(translationStarted: translationStarted)
        let viewModel = TranslationViewModel(apiClient: client)
        viewModel.inputText = "ሰላም"

        let task = Task { await viewModel.translate() }
        await fulfillment(of: [translationStarted], timeout: 1)
        XCTAssertEqual(viewModel.translationState, .loading)

        viewModel.direction = .englishToAmharic
        XCTAssertEqual(viewModel.translationState, .idle)

        client.completeTranslation(with: .success(expected))
        await task.value

        XCTAssertEqual(viewModel.translationState, .idle)
    }

    func testTranslationFailureMovesToError() async {
        let client = MockAPIClient(translationResult: .failure(MockError.unavailable))
        let viewModel = TranslationViewModel(apiClient: client)
        viewModel.inputText = "Hello"
        viewModel.direction = .englishToAmharic

        await viewModel.translate()

        XCTAssertEqual(viewModel.translationState, .error("Backend unavailable"))
    }

    func testTranslationCancellationReturnsToIdle() async {
        let client = MockAPIClient(translationResult: .failure(CancellationError()))
        let viewModel = TranslationViewModel(apiClient: client)
        viewModel.inputText = "Hello"

        await viewModel.translate()

        XCTAssertEqual(viewModel.translationState, .idle)
    }

    func testHealthCheckMovesToSuccess() async {
        let expected = HealthResponse(status: "ok", service: "amharic-voice-ai")
        let client = MockAPIClient(healthResult: .success(expected))
        let viewModel = TranslationViewModel(apiClient: client)

        await viewModel.checkHealth()

        XCTAssertEqual(viewModel.healthState, .success(expected))
        XCTAssertEqual(client.healthRequestCount, 1)
    }

    func testHealthCheckFailureMovesToError() async {
        let client = MockAPIClient(healthResult: .failure(MockError.unavailable))
        let viewModel = TranslationViewModel(apiClient: client)

        await viewModel.checkHealth()

        XCTAssertEqual(viewModel.healthState, .error("Backend unavailable"))
        XCTAssertEqual(client.healthRequestCount, 1)
    }

    func testHealthCheckCancellationReturnsToIdle() async {
        let client = MockAPIClient(healthResult: .failure(CancellationError()))
        let viewModel = TranslationViewModel(apiClient: client)

        await viewModel.checkHealth()

        XCTAssertEqual(viewModel.healthState, .idle)
        XCTAssertEqual(client.healthRequestCount, 1)
    }
}

private func makeTranslationResponse() -> TextTranslateResponse {
    TextTranslateResponse(
        sourceLanguage: "am",
        targetLanguage: "en",
        originalText: "ሰላም",
        translatedText: "Hello",
        normalizedText: "ሰላም",
        normalizationApplied: false,
        normalizationNote: nil
    )
}

private enum MockError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Backend unavailable"
    }
}

private final class MockAPIClient: APIClientProtocol {
    private let healthResult: Result<HealthResponse, Error>
    private let translationResult: Result<TextTranslateResponse, Error>

    private(set) var healthRequestCount = 0
    private(set) var translationRequests: [TextTranslateRequest] = []

    init(
        healthResult: Result<HealthResponse, Error> = .success(
            HealthResponse(status: "ok", service: "amharic-voice-ai")
        ),
        translationResult: Result<TextTranslateResponse, Error> = .failure(MockError.unavailable)
    ) {
        self.healthResult = healthResult
        self.translationResult = translationResult
    }

    func health() async throws -> HealthResponse {
        healthRequestCount += 1
        return try healthResult.get()
    }

    func translateText(_ request: TextTranslateRequest) async throws -> TextTranslateResponse {
        translationRequests.append(request)
        return try translationResult.get()
    }
}

private final class ControlledTranslationAPIClient: APIClientProtocol {
    private let translationStarted: XCTestExpectation
    private var translationContinuation: CheckedContinuation<TextTranslateResponse, Error>?
    private(set) var translationRequests: [TextTranslateRequest] = []

    init(translationStarted: XCTestExpectation) {
        self.translationStarted = translationStarted
    }

    func health() async throws -> HealthResponse {
        HealthResponse(status: "ok", service: "amharic-voice-ai")
    }

    func translateText(_ request: TextTranslateRequest) async throws -> TextTranslateResponse {
        translationRequests.append(request)
        return try await withCheckedThrowingContinuation { continuation in
            translationContinuation = continuation
            translationStarted.fulfill()
        }
    }

    func completeTranslation(with result: Result<TextTranslateResponse, Error>) {
        guard let continuation = translationContinuation else {
            preconditionFailure("No translation request is waiting for completion")
        }

        translationContinuation = nil
        switch result {
        case .success(let response):
            continuation.resume(returning: response)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
