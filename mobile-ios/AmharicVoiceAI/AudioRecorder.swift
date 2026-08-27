import AVFoundation
import Foundation

enum MicrophonePermission: Equatable {
    case undetermined
    case granted
    case denied
    case restricted
}

enum SpeechRecordingLimits {
    // Mirrors backend/app/main.py MAX_UPLOAD_SIZE_BYTES. The backend remains authoritative.
    static let backendMaximumUploadBytes = 5 * 1024 * 1024
    static let sampleRateHertz = 16_000
    static let channelCount = 1
    static let bitsPerSample = 16
    static let canonicalWAVHeaderBytes = 44
    static let pcmBytesPerSecond = sampleRateHertz * channelCount * bitsPerSample / 8
    static let maximumRecordingSeconds =
        (backendMaximumUploadBytes - canonicalWAVHeaderBytes) / pcmBytesPerSecond
    static let maximumRecordingDuration = TimeInterval(maximumRecordingSeconds)
    static let estimatedMaximumWAVBytes =
        canonicalWAVHeaderBytes + maximumRecordingSeconds * pcmBytesPerSecond

    static var maximumDurationDescription: String {
        "\(maximumRecordingSeconds / 60) minutes \(maximumRecordingSeconds % 60) seconds"
    }
}

enum AudioRecorderError: LocalizedError {
    case couldNotStart
    case noRecording

    var errorDescription: String? {
        switch self {
        case .couldNotStart:
            return "The microphone recording could not be started."
        case .noRecording:
            return "No recording is available to upload."
        }
    }
}

@MainActor
protocol AudioRecording: AnyObject {
    var permission: MicrophonePermission { get }
    var currentTime: TimeInterval { get }
    var isRecording: Bool { get }

    func requestPermission() async -> MicrophonePermission
    func startRecording() throws -> URL
    func stopRecording() throws -> URL
    func cancelRecording()
    func deleteRecording(at url: URL)
}

@MainActor
final class AudioRecorder: NSObject, AudioRecording, AVAudioRecorderDelegate {
    private static let recordingFilenamePrefix = "amharicvoice-"

    static let wavSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: Double(SpeechRecordingLimits.sampleRateHertz),
        AVNumberOfChannelsKey: SpeechRecordingLimits.channelCount,
        AVLinearPCMBitDepthKey: SpeechRecordingLimits.bitsPerSample,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false
    ]

    private let fileManager: FileManager
    private let temporaryDirectory: URL
    private let makeIdentifier: () -> String
    private var recorder: AVAudioRecorder?
    private(set) var lastRecordingURL: URL?

    init(
        fileManager: FileManager = .default,
        temporaryDirectory: URL? = nil,
        makeIdentifier: @escaping () -> String = { UUID().uuidString }
    ) {
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory ?? fileManager.temporaryDirectory
        self.makeIdentifier = makeIdentifier
        super.init()
        removeStaleAppOwnedRecordings()
    }

    var permission: MicrophonePermission {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined: return .undetermined
        case .granted: return .granted
        case .denied: return .denied
        @unknown default: return .restricted
        }
    }

    var currentTime: TimeInterval {
        recorder?.currentTime ?? 0
    }

    var isRecording: Bool {
        recorder?.isRecording ?? false
    }

    func requestPermission() async -> MicrophonePermission {
        guard permission == .undetermined else {
            return permission
        }

        _ = await AVAudioApplication.requestRecordPermission()
        return permission
    }

    @discardableResult
    func startRecording() throws -> URL {
        cancelRecording()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = temporaryDirectory
            .appendingPathComponent("\(Self.recordingFilenamePrefix)\(makeIdentifier())")
            .appendingPathExtension("wav")

        do {
            let recorder = try AVAudioRecorder(url: url, settings: Self.wavSettings)
            recorder.delegate = self
            recorder.prepareToRecord()
            guard recorder.record(forDuration: SpeechRecordingLimits.maximumRecordingDuration) else {
                throw AudioRecorderError.couldNotStart
            }
            self.recorder = recorder
            lastRecordingURL = url
            return url
        } catch {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try? fileManager.removeItem(at: url)
            throw error
        }
    }

    func stopRecording() throws -> URL {
        guard let recorder, let url = lastRecordingURL else {
            throw AudioRecorderError.noRecording
        }

        recorder.stop()
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard fileManager.fileExists(atPath: url.path) else {
            lastRecordingURL = nil
            throw AudioRecorderError.noRecording
        }
        return url
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if let lastRecordingURL {
            deleteRecording(at: lastRecordingURL)
        }
    }

    func deleteRecording(at url: URL) {
        try? fileManager.removeItem(at: url)
        if lastRecordingURL == url {
            lastRecordingURL = nil
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error _: Error?) {
        let recorderID = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            self?.handleEncodingError(from: recorderID)
        }
    }

    private func handleEncodingError(from recorderID: ObjectIdentifier) {
        guard let recorder, ObjectIdentifier(recorder) == recorderID else { return }
        cancelRecording()
    }

    private func removeStaleAppOwnedRecordings() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in urls where isAppOwnedTemporaryWAV(url) {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    private func isAppOwnedTemporaryWAV(_ url: URL) -> Bool {
        let filenameWithoutExtension = url.deletingPathExtension().lastPathComponent
        return url.pathExtension.lowercased() == "wav"
            && filenameWithoutExtension.hasPrefix(Self.recordingFilenamePrefix)
            && filenameWithoutExtension.count > Self.recordingFilenamePrefix.count
    }
}
