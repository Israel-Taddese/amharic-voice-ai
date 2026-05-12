import Foundation

enum TranslationDirection: String, CaseIterable, Identifiable {
    case amToEn = "am-en"
    case enToAm = "en-am"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .amToEn: return "Amharic → English"
        case .enToAm: return "English → Amharic"
        }
    }
}

struct SpeechTranslateResponse: Codable {
    let direction: String
    let speechLocale: String
    let sourceLanguage: String
    let targetLanguage: String
    let transcript: String
    let translatedText: String
    let audioBase64: String?
    let audioMimeType: String?

    enum CodingKeys: String, CodingKey {
        case direction
        case speechLocale = "speech_locale"
        case sourceLanguage = "source_language"
        case targetLanguage = "target_language"
        case transcript
        case translatedText = "translated_text"
        case audioBase64 = "audio_base64"
        case audioMimeType = "audio_mime_type"
    }
}
