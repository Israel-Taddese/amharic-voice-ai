import Foundation
import SwiftUI

@MainActor
struct ContentView: View {
    private enum TranslationMode: String, CaseIterable, Identifiable {
        case text = "Text"
        case speech = "Speech"

        var id: String { rawValue }
    }

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: TranslationViewModel
    @StateObject private var speechViewModel: SpeechTranslationViewModel
    @State private var translationMode: TranslationMode = .text
    private let checksHealthOnAppear: Bool

    init(
        viewModel: TranslationViewModel? = nil,
        speechViewModel: SpeechTranslationViewModel? = nil,
        checksHealthOnAppear: Bool = true
    ) {
        _viewModel = StateObject(wrappedValue: viewModel ?? TranslationViewModel())
        _speechViewModel = StateObject(wrappedValue: speechViewModel ?? SpeechTranslationViewModel())
        self.checksHealthOnAppear = checksHealthOnAppear
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    healthStatus
                    translationModePicker

                    if translationMode == .text {
                        directionPicker
                        textInput
                        translateButton
                        translationResult
                    } else {
                        speechTranslation
                    }
                }
                .padding()
            }
            .navigationTitle("AmharicVoice AI")
            .task {
                guard checksHealthOnAppear else { return }
                await viewModel.checkHealth()
            }
            .onChange(of: translationMode) { _, mode in
                if mode == .text {
                    speechViewModel.cancel()
                }
            }
            .onDisappear {
                speechViewModel.cancel()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else { return }
                speechViewModel.handleSceneInactivity()
            }
        }
    }

    private var translationModePicker: some View {
        Picker("Translation input", selection: $translationMode) {
            ForEach(TranslationMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityHint("Choose typed text or microphone speech translation")
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

    private var speechTranslation: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Speech direction")
                    .font(.headline)

                Picker("Speech translation direction", selection: $speechViewModel.direction) {
                    ForEach(TranslationDirection.allCases) { direction in
                        Text(direction.displayName).tag(direction)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(speechControlsAreLocked)
                .accessibilityHint("Choose the language you will speak and the translation language")
            }

            Toggle("Generate translated audio", isOn: $speechViewModel.speakOutput)
                .disabled(speechControlsAreLocked)
                .accessibilityHint("Ask the backend to create an MP3 of the translated text")

            speechStateContent
        }
    }

    @ViewBuilder
    private var speechStateContent: some View {
        switch speechViewModel.state {
        case .idle:
            startRecordingButton(title: "Record speech")
        case .requestingPermission:
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Requesting microphone permission…")
                }
                .accessibilityElement(children: .combine)

                cancelSpeechButton
            }
            .frame(maxWidth: .infinity)
        case .recording:
            VStack(spacing: 14) {
                Label("Recording \(formattedRecordingDuration)", systemImage: "waveform.circle.fill")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.red)
                    .accessibilityLabel("Recording duration \(accessibleRecordingDuration)")

                HStack {
                    Button("Stop recording") {
                        speechViewModel.stopRecording()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Stops recording and prepares the WAV file for upload")

                    cancelSpeechButton
                }
            }
            .frame(maxWidth: .infinity)
        case .recordingReady:
            VStack(alignment: .leading, spacing: 12) {
                Label("Recording ready · \(formattedRecordingDuration)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Recording ready. Duration \(accessibleRecordingDuration)")

                if let limitMessage = speechViewModel.recordingLimitMessage {
                    Label(limitMessage, systemImage: "timer")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .accessibilityLabel(limitMessage)
                }

                Button {
                    Task { await speechViewModel.uploadRecording() }
                } label: {
                    Text("Translate recording")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("Uploads the temporary WAV recording to the AmharicVoice backend")

                cancelSpeechButton
            }
        case .uploading:
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Translating speech…")
                }
                .accessibilityElement(children: .combine)

                cancelSpeechButton
            }
            .frame(maxWidth: .infinity)
        case .success(let response):
            speechResult(response)
        case .error(let message):
            VStack(alignment: .leading, spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Speech translation error: \(message)")
                startRecordingButton(title: "Try recording again")
            }
        case .cancelled:
            VStack(alignment: .leading, spacing: 12) {
                Label("Speech translation cancelled", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
                startRecordingButton(title: "Record again")
            }
        }
    }

    private func speechResult(_ response: SpeechTranslateResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recognized speech")
                .font(.headline)
            Text(response.transcript)
                .textSelection(.enabled)
                .accessibilityLabel("Recognized speech: \(response.transcript)")

            if response.normalizationApplied, let normalizedText = response.normalizedText {
                Text("Normalized speech")
                    .font(.headline)
                Text(normalizedText)
                    .textSelection(.enabled)
                    .accessibilityLabel("Normalized speech: \(normalizedText)")
            }

            Divider()

            Text("Translation")
                .font(.headline)
            Text(response.translatedText)
                .font(.title3)
                .textSelection(.enabled)
                .accessibilityLabel("Speech translation: \(response.translatedText)")

            if response.normalizationApplied, let note = response.normalizationNote {
                Label(note, systemImage: "text.badge.checkmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Normalization note: \(note)")
            }

            if response.audioURL != nil {
                Button {
                    Task { await speechViewModel.playTranslatedAudio() }
                } label: {
                    HStack {
                        if speechViewModel.isLoadingAudio {
                            ProgressView()
                                .accessibilityHidden(true)
                        }
                        Text(speechViewModel.isLoadingAudio ? "Loading audio…" : "Play translated audio")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(speechViewModel.isLoadingAudio)
                .accessibilityHint("Downloads generated audio from the configured backend and plays it")
            }

            if let playbackError = speechViewModel.playbackError {
                Label(playbackError, systemImage: "speaker.slash.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Audio playback error: \(playbackError)")
            }

            startRecordingButton(title: "Record another")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func startRecordingButton(title: String) -> some View {
        Button {
            Task { await speechViewModel.startRecording() }
        } label: {
            Label(title, systemImage: "mic.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel(title)
        .accessibilityHint("Requests microphone access if needed, then starts a temporary WAV recording")
    }

    private var cancelSpeechButton: some View {
        Button("Cancel") {
            speechViewModel.cancel()
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Cancel speech translation")
        .accessibilityHint("Stops current speech work and deletes the temporary recording")
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

    private var speechControlsAreLocked: Bool {
        switch speechViewModel.state {
        case .requestingPermission, .recording, .uploading:
            return true
        default:
            return false
        }
    }

    private var formattedRecordingDuration: String {
        let totalSeconds = max(0, Int(speechViewModel.recordingDuration.rounded(.down)))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var accessibleRecordingDuration: String {
        let totalSeconds = max(0, Int(speechViewModel.recordingDuration.rounded()))
        return "\(totalSeconds / 60) minutes, \(totalSeconds % 60) seconds"
    }
}

#Preview {
    ContentView(checksHealthOnAppear: false)
}
