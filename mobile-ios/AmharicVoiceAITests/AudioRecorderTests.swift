import AVFoundation
import XCTest
@testable import AmharicVoiceAI

@MainActor
final class AudioRecorderTests: XCTestCase {
    func testWAVSettingsMatchBackendFormat() {
        let settings = AudioRecorder.wavSettings

        XCTAssertEqual(settings[AVFormatIDKey] as? Int, Int(kAudioFormatLinearPCM))
        XCTAssertEqual(
            settings[AVSampleRateKey] as? Double,
            Double(SpeechRecordingLimits.sampleRateHertz)
        )
        XCTAssertEqual(settings[AVNumberOfChannelsKey] as? Int, SpeechRecordingLimits.channelCount)
        XCTAssertEqual(settings[AVLinearPCMBitDepthKey] as? Int, SpeechRecordingLimits.bitsPerSample)
        XCTAssertEqual(settings[AVLinearPCMIsBigEndianKey] as? Bool, false)
        XCTAssertEqual(settings[AVLinearPCMIsFloatKey] as? Bool, false)
    }

    func testRecordingLimitIsDerivedFromWAVFormatAndBackendLimit() {
        XCTAssertEqual(SpeechRecordingLimits.backendMaximumUploadBytes, 5 * 1024 * 1024)
        XCTAssertEqual(SpeechRecordingLimits.pcmBytesPerSecond, 32_000)
        XCTAssertEqual(SpeechRecordingLimits.maximumRecordingSeconds, 163)
        XCTAssertEqual(SpeechRecordingLimits.estimatedMaximumWAVBytes, 5_216_044)
        XCTAssertLessThanOrEqual(
            SpeechRecordingLimits.estimatedMaximumWAVBytes,
            SpeechRecordingLimits.backendMaximumUploadBytes
        )
        XCTAssertGreaterThan(
            SpeechRecordingLimits.estimatedMaximumWAVBytes + SpeechRecordingLimits.pcmBytesPerSecond,
            SpeechRecordingLimits.backendMaximumUploadBytes
        )
    }

    func testInitializationRemovesOnlyAppOwnedTemporaryWAVs() throws {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("audio-recorder-cleanup-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let ownedWAV = temporaryDirectory.appendingPathComponent("amharicvoice-stale.wav")
        let ownedUppercaseWAV = temporaryDirectory.appendingPathComponent("amharicvoice-stale-two.WAV")
        let unrelatedWAV = temporaryDirectory.appendingPathComponent("another-app.wav")
        let wrongExtension = temporaryDirectory.appendingPathComponent("amharicvoice-stale.mp3")
        let emptyIdentifier = temporaryDirectory.appendingPathComponent("amharicvoice-.wav")
        let matchingDirectory = temporaryDirectory
            .appendingPathComponent("amharicvoice-directory.wav", isDirectory: true)

        for url in [ownedWAV, ownedUppercaseWAV, unrelatedWAV, wrongExtension, emptyIdentifier] {
            try Data("test".utf8).write(to: url)
        }
        try fileManager.createDirectory(at: matchingDirectory, withIntermediateDirectories: false)

        _ = AudioRecorder(fileManager: fileManager, temporaryDirectory: temporaryDirectory)

        XCTAssertFalse(fileManager.fileExists(atPath: ownedWAV.path))
        XCTAssertFalse(fileManager.fileExists(atPath: ownedUppercaseWAV.path))
        XCTAssertTrue(fileManager.fileExists(atPath: unrelatedWAV.path))
        XCTAssertTrue(fileManager.fileExists(atPath: wrongExtension.path))
        XCTAssertTrue(fileManager.fileExists(atPath: emptyIdentifier.path))
        XCTAssertTrue(fileManager.fileExists(atPath: matchingDirectory.path))
    }
}
