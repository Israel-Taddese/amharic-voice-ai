import Combine
import Foundation

enum LoadState<Value: Equatable>: Equatable {
    case idle
    case loading
    case success(Value)
    case error(String)
}

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var inputText = "" {
        didSet {
            guard inputText != oldValue else { return }
            invalidateTranslation()
        }
    }
    @Published var direction: TranslationDirection = .amharicToEnglish {
        didSet {
            guard direction != oldValue else { return }
            invalidateTranslation()
        }
    }
    @Published private(set) var healthState: LoadState<HealthResponse> = .idle
    @Published private(set) var translationState: LoadState<TextTranslateResponse> = .idle

    private let apiClient: APIClientProtocol
    private var translationGeneration = 0

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    var isTranslating: Bool {
        translationState == .loading
    }

    func checkHealth() async {
        healthState = .loading

        do {
            healthState = .success(try await apiClient.health())
        } catch is CancellationError {
            healthState = .idle
        } catch {
            healthState = .error(error.localizedDescription)
        }
    }

    func translate() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            translationState = .error("Enter text to translate.")
            return
        }

        let requestGeneration = translationGeneration
        translationState = .loading

        do {
            let request = TextTranslateRequest(text: text, direction: direction)
            let response = try await apiClient.translateText(request)
            guard requestGeneration == translationGeneration else { return }
            translationState = .success(response)
        } catch is CancellationError {
            guard requestGeneration == translationGeneration else { return }
            translationState = .idle
        } catch {
            guard requestGeneration == translationGeneration else { return }
            translationState = .error(error.localizedDescription)
        }
    }

    func clearTranslation() {
        invalidateTranslation()
    }

    private func invalidateTranslation() {
        translationGeneration &+= 1
        translationState = .idle
    }
}
