import Foundation
import XCTest
@testable import AmharicVoiceAI

final class ModelDecodingTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testDecodesHealthResponse() throws {
        let data = Data(#"{"status":"ok","service":"amharic-voice-ai"}"#.utf8)

        let response = try decoder.decode(HealthResponse.self, from: data)

        XCTAssertEqual(response, HealthResponse(status: "ok", service: "amharic-voice-ai"))
    }

    func testDecodesTextTranslationResponse() throws {
        let data = Data(
            #"{"source_language":"am","target_language":"en","original_text":"ሰላም","translated_text":"Hello","normalized_text":"ሰላም","normalization_applied":true,"normalization_note":"Greeting normalized"}"#.utf8
        )

        let response = try decoder.decode(TextTranslateResponse.self, from: data)

        XCTAssertEqual(response.sourceLanguage, "am")
        XCTAssertEqual(response.targetLanguage, "en")
        XCTAssertEqual(response.originalText, "ሰላም")
        XCTAssertEqual(response.translatedText, "Hello")
        XCTAssertEqual(response.normalizedText, "ሰላም")
        XCTAssertTrue(response.normalizationApplied)
        XCTAssertEqual(response.normalizationNote, "Greeting normalized")
    }

    func testDecodesCurrentSpeechContractWithAudioURL() throws {
        let data = Data(
            #"{"direction":"am-en","speech_locale":"am-ET","source_language":"am","target_language":"en","transcript":"ሰላም","translated_text":"Hello","normalized_text":null,"normalization_applied":false,"normalization_note":null,"audio_url":"/audio/result.mp3","audio_mime_type":"audio/mpeg"}"#.utf8
        )

        let response = try decoder.decode(SpeechTranslateResponse.self, from: data)

        XCTAssertEqual(response.direction, .amharicToEnglish)
        XCTAssertEqual(response.audioURL, "/audio/result.mp3")
        XCTAssertEqual(response.audioMimeType, "audio/mpeg")
        XCTAssertFalse(response.normalizationApplied)
    }
}
