from typing import Literal

from pydantic import BaseModel, Field


TranslationDirection = Literal["am-en", "en-am"]


class HealthResponse(BaseModel):
    status: str = Field(
        examples=["ok"],
        description="Current backend health status.",
    )
    service: str = Field(
        examples=["amharic-voice-ai"],
        description="Service identifier.",
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "status": "ok",
                    "service": "amharic-voice-ai",
                }
            ]
        }
    }


class TextTranslateRequest(BaseModel):
    text: str = Field(
        examples=["ሰላም እንዴት ነው?"],
        description="Text to translate. Supports Amharic or English depending on the selected direction.",
    )
    direction: TranslationDirection = Field(
        examples=["am-en"],
        description="Translation direction. Use 'am-en' for Amharic to English and 'en-am' for English to Amharic.",
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "text": "ሰላም እንዴት ነው?",
                    "direction": "am-en",
                },
                {
                    "text": "Hello, how are you?",
                    "direction": "en-am",
                },
            ]
        }
    }


class TextTranslateResponse(BaseModel):
    source_language: str = Field(
        examples=["am"],
        description="Source text language code used by the translation layer.",
    )
    target_language: str = Field(
        examples=["en"],
        description="Target text language code used by the translation layer.",
    )
    original_text: str = Field(
        examples=["ሰላም እንዴት ነው?"],
        description="Original user-provided text.",
    )
    translated_text: str = Field(
        examples=["Hello. How are you?"],
        description="Final translated text returned by the app.",
    )
    normalized_text: str | None = Field(
        default=None,
        examples=["ሰላም። እንዴት ነው?"],
        description="Normalized phrase used before translation, if a normalization rule was applied.",
    )
    normalization_applied: bool = Field(
        default=False,
        examples=[True],
        description="Indicates whether the app applied a phrase normalization rule before translation.",
    )
    normalization_note: str | None = Field(
        default=None,
        examples=[
            "Recognized common Amharic greeting phrase and translated by meaning instead of literal word-by-word translation."
        ],
        description="Explanation of the normalization rule that was applied.",
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "source_language": "am",
                    "target_language": "en",
                    "original_text": "ሰላም እንዴት ነው?",
                    "translated_text": "Hello. How are you?",
                    "normalized_text": "ሰላም። እንዴት ነው?",
                    "normalization_applied": True,
                    "normalization_note": "Recognized common Amharic greeting phrase and translated by meaning instead of literal word-by-word translation.",
                }
            ]
        }
    }


class SpeechTranslateResponse(BaseModel):
    direction: TranslationDirection = Field(
        examples=["am-en"],
        description="Translation direction requested by the client.",
    )
    speech_locale: str = Field(
        examples=["am-ET"],
        description="Speech recognition locale used by Azure Speech.",
    )
    source_language: str = Field(
        examples=["am"],
        description="Source text language code used after transcription.",
    )
    target_language: str = Field(
        examples=["en"],
        description="Target text language code used for translation.",
    )
    transcript: str = Field(
        examples=["ሰላም እንዴት ነው?"],
        description="Speech-to-text transcript returned from the uploaded WAV audio.",
    )
    translated_text: str = Field(
        examples=["Hello. How are you?"],
        description="Final translated text returned by the app.",
    )
    normalized_text: str | None = Field(
        default=None,
        examples=["ሰላም። እንዴት ነው?"],
        description="Normalized transcript used before translation, if a normalization rule was applied.",
    )
    normalization_applied: bool = Field(
        default=False,
        examples=[True],
        description="Indicates whether phrase normalization was applied before translation.",
    )
    normalization_note: str | None = Field(
        default=None,
        examples=[
            "Recognized common Amharic greeting phrase and translated by meaning instead of literal word-by-word translation."
        ],
        description="Explanation of phrase normalization, if applied.",
    )
    audio_url: str | None = Field(
        default=None,
        examples=["/audio/translation_example.mp3"],
        description="URL path for the generated translated MP3 audio file, if speech output was requested.",
    )
    audio_mime_type: str | None = Field(
        default=None,
        examples=["audio/mpeg"],
        description="MIME type of the generated audio file.",
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "direction": "am-en",
                    "speech_locale": "am-ET",
                    "source_language": "am",
                    "target_language": "en",
                    "transcript": "ሰላም እንዴት ነው?",
                    "translated_text": "Hello. How are you?",
                    "normalized_text": "ሰላም። እንዴት ነው?",
                    "normalization_applied": True,
                    "normalization_note": "Recognized common Amharic greeting phrase and translated by meaning instead of literal word-by-word translation.",
                    "audio_url": "/audio/translation_example.mp3",
                    "audio_mime_type": "audio/mpeg",
                }
            ]
        }
    }