import AVFoundation
import XCTest
@testable import AmharicVoiceAI

@MainActor
final class AudioRecorderTests: XCTestCase {
    func testWAVSettingsMatchBackendFormat() {
        let settings = AudioRecorder.wavSettings

        XCTAssertEqual(settings[AVFormatIDKey] as? Int, Int(kAudioFormatLinearPCM))
        XCTAssertEqual(settings[AVSampleRateKey] as? Double, 16_000.0)
        XCTAssertEqual(settings[AVNumberOfChannelsKey] as? Int, 1)
        XCTAssertEqual(settings[AVLinearPCMBitDepthKey] as? Int, 16)
        XCTAssertEqual(settings[AVLinearPCMIsBigEndianKey] as? Bool, false)
        XCTAssertEqual(settings[AVLinearPCMIsFloatKey] as? Bool, false)
    }
}
