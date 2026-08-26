import Foundation

enum TranslationDirection: String, Codable, CaseIterable, Identifiable {
    case amharicToEnglish = "am-en"
    case englishToAmharic = "en-am"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .amharicToEnglish:
            return "አማርኛ → English"
        case .englishToAmharic:
            return "English → አማርኛ"
        }
    }

    var sourceLanguageName: String {
        switch self {
        case .amharicToEnglish: return "አማርኛ"
        case .englishToAmharic: return "English"
        }
    }

    var targetLanguageName: String {
        switch self {
        case .amharicToEnglish: return "English"
        case .englishToAmharic: return "አማርኛ"
        }
    }
}

struct HealthResponse: Codable, Equatable {
    let status: String
    let service: String
}

struct TextTranslateRequest: Codable, Equatable {
    let text: String
    let direction: TranslationDirection
}

struct TextTranslateResponse: Codable, Equatable {
    let sourceLanguage: String
    let targetLanguage: String
    let originalText: String
    let translatedText: String
    let normalizedText: String?
    let normalizationApplied: Bool
    let normalizationNote: String?

    enum CodingKeys: String, CodingKey {
        case sourceLanguage = "source_language"
        case targetLanguage = "target_language"
        case originalText = "original_text"
        case translatedText = "translated_text"
        case normalizedText = "normalized_text"
        case normalizationApplied = "normalization_applied"
        case normalizationNote = "normalization_note"
    }
}

struct SpeechTranslateResponse: Codable, Equatable {
    let direction: TranslationDirection
    let speechLocale: String
    let sourceLanguage: String
    let targetLanguage: String
    let transcript: String
    let translatedText: String
    let normalizedText: String?
    let normalizationApplied: Bool
    let normalizationNote: String?
    let audioURL: String?
    let audioMimeType: String?

    enum CodingKeys: String, CodingKey {
        case direction
        case speechLocale = "speech_locale"
        case sourceLanguage = "source_language"
        case targetLanguage = "target_language"
        case transcript
        case translatedText = "translated_text"
        case normalizedText = "normalized_text"
        case normalizationApplied = "normalization_applied"
        case normalizationNote = "normalization_note"
        case audioURL = "audio_url"
        case audioMimeType = "audio_mime_type"
    }
}
