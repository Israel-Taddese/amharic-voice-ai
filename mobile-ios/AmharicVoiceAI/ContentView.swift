import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var viewModel: TranslationViewModel
    private let checksHealthOnAppear: Bool

    init(
        viewModel: TranslationViewModel = TranslationViewModel(),
        checksHealthOnAppear: Bool = true
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.checksHealthOnAppear = checksHealthOnAppear
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    healthStatus
                    directionPicker
                    textInput
                    translateButton
                    translationResult
                }
                .padding()
            }
            .navigationTitle("AmharicVoice AI")
            .task {
                guard checksHealthOnAppear else { return }
                await viewModel.checkHealth()
            }
        }
    }

    private var healthStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: healthSymbol)
                .foregroundStyle(healthColor)
                .accessibilityHidden(true)

            Text(healthMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Backend status: \(healthMessage)")

            Spacer()

            if case .error = viewModel.healthState {
                Button("Retry") {
                    Task { await viewModel.checkHealth() }
                }
                .font(.footnote)
                .accessibilityLabel("Retry backend health check")
            }
        }
    }

    private var directionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translation direction")
                .font(.headline)

            Picker("Translation direction", selection: $viewModel.direction) {
                ForEach(TranslationDirection.allCases) { direction in
                    Text(direction.displayName).tag(direction)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Choose Amharic to English or English to Amharic")
        }
    }

    private var textInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(viewModel.direction.sourceLanguageName) text")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                if viewModel.inputText.isEmpty {
                    Text(inputPlaceholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(2)
                    .accessibilityLabel("Text to translate from \(viewModel.direction.sourceLanguageName)")
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var translateButton: some View {
        Button {
            Task { await viewModel.translate() }
        } label: {
            HStack {
                if case .loading = viewModel.translationState {
                    ProgressView()
                        .tint(.white)
                        .accessibilityHidden(true)
                }

                Text(translateButtonTitle)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTranslating)
        .accessibilityHint("Sends the entered text to the AmharicVoice backend for translation")
    }

    @ViewBuilder
    private var translationResult: some View {
        switch viewModel.translationState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Translating…")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityElement(children: .combine)
        case .success(let response):
            VStack(alignment: .leading, spacing: 10) {
                Text("\(viewModel.direction.targetLanguageName) translation")
                    .font(.headline)

                Text(response.translatedText)
                    .font(.title3)
                    .textSelection(.enabled)
                    .accessibilityLabel("Translation: \(response.translatedText)")

                if response.normalizationApplied, let note = response.normalizationNote {
                    Label(note, systemImage: "text.badge.checkmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Normalization note: \(note)")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Translation error: \(message)")
        }
    }

    private var healthSymbol: String {
        switch viewModel.healthState {
        case .idle: return "circle.dotted"
        case .loading: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    private var healthColor: Color {
        switch viewModel.healthState {
        case .idle, .loading: return .secondary
        case .success: return .green
        case .error: return .orange
        }
    }

    private var healthMessage: String {
        switch viewModel.healthState {
        case .idle: return "Backend not checked"
        case .loading: return "Checking backend…"
        case .success(let response): return "\(response.service): \(response.status)"
        case .error(let message): return "Backend unavailable: \(message)"
        }
    }

    private var inputPlaceholder: String {
        switch viewModel.direction {
        case .amharicToEnglish: return "ለምሳሌ፦ ሰላም"
        case .englishToAmharic: return "For example: Hello"
        }
    }

    private var translateButtonTitle: String {
        isTranslating ? "Translating…" : "Translate / ተርጉም"
    }

    private var isTranslating: Bool {
        if case .loading = viewModel.translationState {
            return true
        }
        return false
    }
}

#Preview {
    ContentView(checksHealthOnAppear: false)
}
