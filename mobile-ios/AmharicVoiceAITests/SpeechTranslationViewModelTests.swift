import Foundation
import XCTest
@testable import AmharicVoiceAI

@MainActor
final class SpeechTranslationViewModelTests: XCTestCase {
    func testPermissionDeniedMovesToClearErrorWithoutStartingRecorder() async {
        let recorder = MockAudioRecorder(permission: .undetermined, requestedPermission: .denied)
        let viewModel = makeViewModel(recorder: recorder)

        await viewModel.startRecording()

        XCTAssertEqual(
            viewModel.state,
            .error("Microphone access is denied. Enable it in Settings to record speech.")
        )
        XCTAssertEqual(recorder.permissionRequestCount, 1)
        XCTAssertEqual(recorder.startCount, 0)
    }

    func testRestrictedPermissionMovesToClearErrorWithoutStartingRecorder() async {
        let recorder = MockAudioRecorder(permission: .restricted)
        let viewModel = makeViewModel(recorder: recorder)

        await viewModel.startRecording()

        XCTAssertEqual(viewModel.state, .error("Microphone access is restricted on this device."))
        XCTAssertEqual(recorder.permissionRequestCount, 0)
        XCTAssertEqual(recorder.startCount, 0)
    }

    func testRecordingMovesToReadyAndTracksDuration() async {
        let recorder = MockAudioRecorder(permission: .granted)
        recorder.currentTime = 4.2
        let viewModel = makeViewModel(recorder: recorder)

        await viewModel.startRecording()
        XCTAssertEqual(viewModel.state, .recording)

        viewModel.stopRecording()

        XCTAssertEqual(viewModel.state, .recordingReady)
        XCTAssertEqual(viewModel.recordingDuration, 4.2, accuracy: 0.001)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recorder.recordingURL.path))

        viewModel.cancel()
        XCTAssertFalse(FileManager.default.fileExists(atPath: recorder.recordingURL.path))
    }

    func testSuccessfulUploadUsesMocksAndDeletesTemporaryRecording() async {
        let expected = makeSpeechResponse()
        let recorder = MockAudioRecorder(permission: .granted)
        let client = MockSpeechAPIClient(translationResult: .success(expected))
        let viewModel = makeViewModel(client: client, recorder: recorder)
        viewModel.direction = .englishToAmharic
        viewModel.speakOutput = false

        await viewModel.startRecording()
        viewModel.stopRecording()
        await viewModel.uploadRecording()

        XCTAssertEqual(viewModel.state, .success(expected))
        XCTAssertEqual(client.translationRequests.count, 1)
        XCTAssertEqual(client.translationRequests.first?.direction, .englishToAmharic)
        XCTAssertEqual(client.translationRequests.first?.speakOutput, false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recorder.recordingURL.path))
        XCTAssertEqual(recorder.deletedURLs, [recorder.recordingURL])
    }

    func testUploadFailureMovesToErrorAndDeletesTemporaryRecording() async {
        let recorder = MockAudioRecorder(permission: .granted)
        let client = MockSpeechAPIClient(translationResult: .failure(SpeechViewModelTestError.uploadFailed))
        let viewModel = makeViewModel(client: client, recorder: recorder)

        await viewModel.startRecording()
        viewModel.stopRecording()
        await viewModel.uploadRecording()

        XCTAssertEqual(viewModel.state, .error("Speech upload failed"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: recorder.recordingURL.path))
        XCTAssertEqual(recorder.deletedURLs, [recorder.recordingURL])
    }

    func testCancellationDuringUploadIsNotShownAsFailureAndDeletesRecording() async {
        let uploadStarted = expectation(description: "Speech upload started")
        let recorder = MockAudioRecorder(permission: .granted)
        let client = ControlledSpeechAPIClient(uploadStarted: uploadStarted)
        let viewModel = makeViewModel(client: client, recorder: recorder)

        await viewModel.startRecording()
        viewModel.stopRecording()
        let upload = Task { await viewModel.uploadRecording() }
        await fulfillment(of: [uploadStarted], timeout: 1)
        XCTAssertEqual(viewModel.state, .uploading)

        viewModel.cancel()
        client.completeUpload(with: .failure(CancellationError()))
        await upload.value

        XCTAssertEqual(viewModel.state, .cancelled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recorder.recordingURL.path))
        XCTAssertEqual(recorder.deletedURLs, [recorder.recordingURL])
    }

    func testChangingDirectionDeletesReadyRecordingAndReturnsToIdle() async {
        let recorder = MockAudioRecorder(permission: .granted)
        let viewModel = makeViewModel(recorder: recorder)

        await viewModel.startRecording()
        viewModel.stopRecording()
        XCTAssertEqual(viewModel.state, .recordingReady)

        viewModel.direction = .englishToAmharic

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recorder.recordingURL.path))
    }

    func testTranslatedAudioUsesControlledMockDataAndPlayer() async {
        let response = makeSpeechResponse()
        let audioData = Data([0x49, 0x44, 0x33])
        let recorder = MockAudioRecorder(permission: .granted)
        let client = MockSpeechAPIClient(
            translationResult: .success(response),
            audioResult: .success(audioData)
        )
        let player = MockAudioPlayer()
        let viewModel = makeViewModel(client: client, recorder: recorder, audioPlayer: player)

        await viewModel.startRecording()
        viewModel.stopRecording()
        await viewModel.uploadRecording()
        await viewModel.playTranslatedAudio()

        XCTAssertEqual(client.audioRequests, ["/audio/result.mp3"])
        XCTAssertEqual(player.playedData, [audioData])
        XCTAssertNil(viewModel.playbackError)
        XCTAssertFalse(viewModel.isLoadingAudio)
    }

    func testUnexpectedAudioMIMETypeIsRejectedBeforeFetchOrPlayback() async {
        let response = makeSpeechResponse(audioMimeType: "audio/wav")
        let recorder = MockAudioRecorder(permission: .granted)
        let client = MockSpeechAPIClient(translationResult: .success(response))
        let player = MockAudioPlayer()
        let viewModel = makeViewModel(client: client, recorder: recorder, audioPlayer: player)

        await viewModel.startRecording()
        viewModel.stopRecording()
        await viewModel.uploadRecording()
        await viewModel.playTranslatedAudio()

        XCTAssertTrue(client.audioRequests.isEmpty)
        XCTAssertTrue(player.playedData.isEmpty)
        XCTAssertEqual(viewModel.playbackError, "The translated audio format is not supported.")
    }

    private func makeViewModel(
        client: SpeechAPIClientProtocol = MockSpeechAPIClient(),
        recorder: MockAudioRecorder,
        audioPlayer: AudioPlaying = MockAudioPlayer()
    ) -> SpeechTranslationViewModel {
        SpeechTranslationViewModel(
            apiClient: client,
            recorder: recorder,
            audioPlayer: audioPlayer
        )
    }
}

private func makeSpeechResponse(audioMimeType: String? = "audio/mpeg") -> SpeechTranslateResponse {
    SpeechTranslateResponse(
        direction: .amharicToEnglish,
        speechLocale: "am-ET",
        sourceLanguage: "am",
        targetLanguage: "en",
        transcript: "ሰላም",
        translatedText: "Hello",
        normalizedText: "ሰላም",
        normalizationApplied: true,
        normalizationNote: "Greeting normalized",
        audioURL: "/audio/result.mp3",
        audioMimeType: audioMimeType
    )
}

private enum SpeechViewModelTestError: LocalizedError {
    case uploadFailed
    case unexpectedRequest

    var errorDescription: String? {
        switch self {
        case .uploadFailed: return "Speech upload failed"
        case .unexpectedRequest: return "Unexpected request"
        }
    }
}

@MainActor
private final class MockAudioRecorder: AudioRecording {
    var permission: MicrophonePermission
    var currentTime: TimeInterval = 0
    let recordingURL: URL
    private let requestedPermission: MicrophonePermission
    private(set) var permissionRequestCount = 0
    private(set) var startCount = 0
    private(set) var deletedURLs: [URL] = []

    init(
        permission: MicrophonePermission,
        requestedPermission: MicrophonePermission = .granted
    ) {
        self.permission = permission
        self.requestedPermission = requestedPermission
        recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-view-model-\(UUID().uuidString)")
            .appendingPathExtension("wav")
    }

    func requestPermission() async -> MicrophonePermission {
        permissionRequestCount += 1
        permission = requestedPermission
        return requestedPermission
    }

    func startRecording() throws -> URL {
        startCount += 1
        try Data("RIFF-mocked-wave".utf8).write(to: recordingURL, options: .atomic)
        return recordingURL
    }

    func stopRecording() throws -> URL {
        recordingURL
    }

    func cancelRecording() {
        deleteRecording(at: recordingURL)
    }

    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        if !deletedURLs.contains(url) {
            deletedURLs.append(url)
        }
    }
}

private struct SpeechTranslationRequestRecord: Equatable {
    let audioFileURL: URL
    let direction: TranslationDirection
    let speakOutput: Bool
}

private final class MockSpeechAPIClient: SpeechAPIClientProtocol {
    private let translationResult: Result<SpeechTranslateResponse, Error>
    private let audioResult: Result<Data, Error>
    private(set) var translationRequests: [SpeechTranslationRequestRecord] = []
    private(set) var audioRequests: [String] = []

    init(
        translationResult: Result<SpeechTranslateResponse, Error> = .failure(
            SpeechViewModelTestError.unexpectedRequest
        ),
        audioResult: Result<Data, Error> = .failure(SpeechViewModelTestError.unexpectedRequest)
    ) {
        self.translationResult = translationResult
        self.audioResult = audioResult
    }

    func translateSpeech(
        audioFileURL: URL,
        direction: TranslationDirection,
        speakOutput: Bool
    ) async throws -> SpeechTranslateResponse {
        translationRequests.append(
            SpeechTranslationRequestRecord(
                audioFileURL: audioFileURL,
                direction: direction,
                speakOutput: speakOutput
            )
        )
        return try translationResult.get()
    }

    func fetchGeneratedAudio(at audioURL: String) async throws -> Data {
        audioRequests.append(audioURL)
        return try audioResult.get()
    }
}

private final class ControlledSpeechAPIClient: SpeechAPIClientProtocol {
    private let uploadStarted: XCTestExpectation
    private var uploadContinuation: CheckedContinuation<SpeechTranslateResponse, Error>?

    init(uploadStarted: XCTestExpectation) {
        self.uploadStarted = uploadStarted
    }

    func translateSpeech(
        audioFileURL: URL,
        direction: TranslationDirection,
        speakOutput: Bool
    ) async throws -> SpeechTranslateResponse {
        try await withCheckedThrowingContinuation { continuation in
            uploadContinuation = continuation
            uploadStarted.fulfill()
        }
    }

    func fetchGeneratedAudio(at audioURL: String) async throws -> Data {
        throw SpeechViewModelTestError.unexpectedRequest
    }

    func completeUpload(with result: Result<SpeechTranslateResponse, Error>) {
        guard let uploadContinuation else {
            preconditionFailure("No speech upload is waiting for completion")
        }
        self.uploadContinuation = nil

        switch result {
        case .success(let response):
            uploadContinuation.resume(returning: response)
        case .failure(let error):
            uploadContinuation.resume(throwing: error)
        }
    }
}

@MainActor
private final class MockAudioPlayer: AudioPlaying {
    private(set) var playedData: [Data] = []
    private(set) var stopCount = 0

    func play(data: Data) throws {
        playedData.append(data)
    }

    func stop() {
        stopCount += 1
    }
}
