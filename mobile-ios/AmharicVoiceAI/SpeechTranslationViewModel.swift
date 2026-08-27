import Combine
import Foundation

enum SpeechTranslationState: Equatable {
    case idle
    case requestingPermission
    case recording
    case recordingReady
    case uploading
    case success(SpeechTranslateResponse)
    case error(String)
    case cancelled
}

@MainActor
final class SpeechTranslationViewModel: ObservableObject {
    @Published var direction: TranslationDirection = .amharicToEnglish {
        didSet {
            guard direction != oldValue else { return }
            reset()
        }
    }
    @Published var speakOutput = true
    @Published private(set) var state: SpeechTranslationState = .idle
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var isLoadingAudio = false
    @Published private(set) var playbackError: String?

    private let apiClient: SpeechAPIClientProtocol
    private let recorder: AudioRecording
    private let audioPlayer: AudioPlaying
    private var recordingURL: URL?
    private var durationTask: Task<Void, Never>?
    private var uploadTask: Task<SpeechTranslateResponse, Error>?
    private var audioTask: Task<Data, Error>?
    private var operationGeneration = 0

    init(
        apiClient: SpeechAPIClientProtocol = APIClient(),
        recorder: AudioRecording? = nil,
        audioPlayer: AudioPlaying? = nil
    ) {
        self.apiClient = apiClient
        self.recorder = recorder ?? AudioRecorder()
        self.audioPlayer = audioPlayer ?? TranslatedAudioPlayer()
    }

    func startRecording() async {
        prepareForNewRecording()
        state = .requestingPermission
        let generation = operationGeneration

        let permission: MicrophonePermission
        if recorder.permission == .undetermined {
            permission = await recorder.requestPermission()
        } else {
            permission = recorder.permission
        }

        guard generation == operationGeneration else { return }
        guard !Task.isCancelled else {
            state = .cancelled
            return
        }

        switch permission {
        case .granted:
            do {
                recordingURL = try recorder.startRecording()
                recordingDuration = 0
                state = .recording
                startDurationUpdates()
            } catch {
                deleteTemporaryRecording()
                state = .error(error.localizedDescription)
            }
        case .denied:
            state = .error("Microphone access is denied. Enable it in Settings to record speech.")
        case .restricted:
            state = .error("Microphone access is restricted on this device.")
        case .undetermined:
            state = .error("Microphone permission was not resolved.")
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        stopDurationUpdates()
        recordingDuration = max(recordingDuration, recorder.currentTime)

        do {
            recordingURL = try recorder.stopRecording()
            state = .recordingReady
        } catch {
            deleteTemporaryRecording()
            state = .error(error.localizedDescription)
        }
    }

    func uploadRecording() async {
        guard state == .recordingReady, let recordingURL else {
            state = .error(AudioRecorderError.noRecording.localizedDescription)
            return
        }

        state = .uploading
        playbackError = nil
        let generation = operationGeneration
        let direction = direction
        let speakOutput = speakOutput
        let task = Task {
            try await apiClient.translateSpeech(
                audioFileURL: recordingURL,
                direction: direction,
                speakOutput: speakOutput
            )
        }
        uploadTask = task

        do {
            let response = try await task.value
            guard generation == operationGeneration else { return }
            state = .success(response)
        } catch is CancellationError {
            guard generation == operationGeneration else { return }
            state = .cancelled
        } catch {
            guard generation == operationGeneration else { return }
            state = .error(error.localizedDescription)
        }

        if generation == operationGeneration {
            uploadTask = nil
            deleteTemporaryRecording()
        }
    }

    func playTranslatedAudio() async {
        guard case let .success(response) = state,
              let audioURL = response.audioURL else {
            return
        }

        if let mimeType = response.audioMimeType,
           mimeType.lowercased() != "audio/mpeg" {
            playbackError = AudioPlaybackError.unsupportedFormat.localizedDescription
            return
        }

        isLoadingAudio = true
        playbackError = nil
        let generation = operationGeneration
        let task = Task { try await apiClient.fetchGeneratedAudio(at: audioURL) }
        audioTask = task

        do {
            let data = try await task.value
            guard generation == operationGeneration else { return }
            try audioPlayer.play(data: data)
        } catch is CancellationError {
            // User cancellation is an expected state and should not show an error.
        } catch {
            guard generation == operationGeneration else { return }
            playbackError = error.localizedDescription
        }

        if generation == operationGeneration {
            audioTask = nil
            isLoadingAudio = false
        }
    }

    func cancel() {
        operationGeneration &+= 1
        cancelCurrentWork()
        state = .cancelled
    }

    func reset() {
        operationGeneration &+= 1
        cancelCurrentWork()
        recordingDuration = 0
        playbackError = nil
        state = .idle
    }

    private func prepareForNewRecording() {
        operationGeneration &+= 1
        cancelCurrentWork()
        recordingDuration = 0
        playbackError = nil
    }

    private func startDurationUpdates() {
        durationTask?.cancel()
        durationTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    return
                }
                guard let self else { return }
                self.recordingDuration = self.recorder.currentTime
            }
        }
    }

    private func stopDurationUpdates() {
        durationTask?.cancel()
        durationTask = nil
    }

    private func cancelCurrentWork() {
        stopDurationUpdates()
        uploadTask?.cancel()
        uploadTask = nil
        audioTask?.cancel()
        audioTask = nil
        isLoadingAudio = false
        audioPlayer.stop()

        if state == .recording {
            recorder.cancelRecording()
        }
        deleteTemporaryRecording()
    }

    private func deleteTemporaryRecording() {
        guard let recordingURL else { return }
        recorder.deleteRecording(at: recordingURL)
        self.recordingURL = nil
    }
}
