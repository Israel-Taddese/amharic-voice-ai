import os
import tempfile
import uuid
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import settings
from .models import (
    HealthResponse,
    SpeechTranslateResponse,
    TextTranslateRequest,
    TextTranslateResponse,
    TranslationDirection,
)
from .normalizer import normalize_before_translation
from .rate_limiter import InMemoryRateLimiter
from .speech import recognize_speech_from_wav, synthesize_speech_mp3
from .translator import translate_text

BASE_DIR = Path(__file__).resolve().parents[1]
AUDIO_OUTPUT_DIR = BASE_DIR / "generated_audio"
AUDIO_OUTPUT_DIR.mkdir(exist_ok=True)

MAX_UPLOAD_SIZE_BYTES = 5 * 1024 * 1024
MAX_UPLOAD_SIZE_MB = MAX_UPLOAD_SIZE_BYTES // (1024 * 1024)
UPLOAD_READ_CHUNK_SIZE_BYTES = 1024 * 1024

openapi_tags = [
    {
        "name": "System",
        "description": "Health checks and backend service status.",
    },
    {
        "name": "Translation",
        "description": "Text translation between Amharic and English.",
    },
    {
        "name": "Speech",
        "description": "Speech-to-text, translation, and translated speech output.",
    },
]

app = FastAPI(
    title="AmharicVoice AI API",
    description="Azure-powered Amharic <-> English speech and text translation backend.",
    version="0.1.0",
    openapi_tags=openapi_tags,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.allowed_origins) if settings.allowed_origins else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/audio", StaticFiles(directory=str(AUDIO_OUTPUT_DIR)), name="audio")

rate_limiter = InMemoryRateLimiter(max_requests=20, window_seconds=60)


@app.middleware("http")
async def rate_limit_requests(request: Request, call_next):
    return await rate_limiter(request, call_next)

LANGUAGE_ROUTES = {
    "am-en": {
        "speech_locale": "am-ET",
        "source_text_lang": "am",
        "target_text_lang": "en",
        "target_voice": "en-US-JennyNeural",
    },
    "en-am": {
        "speech_locale": "en-US",
        "source_text_lang": "en",
        "target_text_lang": "am",
        "target_voice": "am-ET-MekdesNeural",
    },
}


def translate_with_normalization(text: str, route: dict[str, str]) -> tuple[str, object]:
    """
    Normalize supported phrases before translation.

    If the normalizer returns a translation override, use that direct meaning-based
    translation. Otherwise, send the normalized text to Azure Translator.
    """
    normalization = normalize_before_translation(
        text=text,
        source_language=route["source_text_lang"],
        target_language=route["target_text_lang"],
    )

    if normalization.translation_override:
        translated = normalization.translation_override
    else:
        translated = translate_text(
            normalization.normalized_text,
            target_language=route["target_text_lang"],
            source_language=route["source_text_lang"],
        )

    return translated, normalization


def save_audio_file(audio_bytes: bytes) -> str:
    """
    Save generated MP3 bytes and return a frontend-friendly audio URL.
    """
    filename = f"translation_{uuid.uuid4().hex}.mp3"
    output_path = AUDIO_OUTPUT_DIR / filename
    output_path.write_bytes(audio_bytes)
    return f"/audio/{filename}"


@app.get(
    "/health",
    response_model=HealthResponse,
    tags=["System"],
    summary="Check backend health",
    description="Returns a simple health check response confirming that the AmharicVoice AI backend is running.",
)
def health() -> HealthResponse:
    return HealthResponse(status="ok", service="amharic-voice-ai")


@app.post(
    "/api/text-translate",
    response_model=TextTranslateResponse,
    tags=["Translation"],
    summary="Translate text",
    description="Translates Amharic text to English or English text to Amharic. Applies phrase normalization when a supported conversational pattern is detected.",
)
def text_translate(payload: TextTranslateRequest) -> TextTranslateResponse:
    route = LANGUAGE_ROUTES[payload.direction]

    try:
        translated, normalization = translate_with_normalization(payload.text, route)

        return TextTranslateResponse(
            source_language=route["source_text_lang"],
            target_language=route["target_text_lang"],
            original_text=payload.text,
            translated_text=translated,
            normalized_text=normalization.normalized_text if normalization.was_normalized else None,
            normalization_applied=normalization.was_normalized,
            normalization_note=normalization.note,
        )

    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.post(
    "/api/speech-translate",
    response_model=SpeechTranslateResponse,
    tags=["Speech"],
    summary="Translate speech from WAV audio",
    description="Accepts a WAV audio file, transcribes it with Azure Speech, translates the transcript, optionally generates translated MP3 audio, and returns an audio URL.",
)
async def speech_translate(
    direction: TranslationDirection = Form(..., description="Use 'am-en' for Amharic to English or 'en-am' for English to Amharic."),
    speak_output: bool = Form(True, description="When true, generate translated MP3 speech output."),
    audio: UploadFile = File(..., description="WAV audio file to transcribe and translate."),
) -> SpeechTranslateResponse:
    route = LANGUAGE_ROUTES[direction]

    if not audio.filename or not audio.filename.lower().endswith(".wav"):
        raise HTTPException(
            status_code=400,
            detail="Please upload a WAV file. The current MVP expects WAV/PCM audio for Azure Speech compatibility.",
        )

    suffix = os.path.splitext(audio.filename)[1] or ".wav"

    try:
        bytes_written = 0

        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp_path = tmp.name

            while chunk := await audio.read(UPLOAD_READ_CHUNK_SIZE_BYTES):
                bytes_written += len(chunk)

                if bytes_written > MAX_UPLOAD_SIZE_BYTES:
                    raise HTTPException(
                        status_code=413,
                        detail=f"Uploaded audio file is too large. Maximum allowed size is {MAX_UPLOAD_SIZE_MB} MB.",
                    )

                tmp.write(chunk)

        transcript = recognize_speech_from_wav(tmp_path, locale=route["speech_locale"])

        if not transcript:
            raise RuntimeError("No transcript returned from Azure Speech.")

        translated, normalization = translate_with_normalization(transcript, route)

        audio_url = None
        audio_mime_type = None

        if speak_output:
            audio_bytes = synthesize_speech_mp3(translated, voice_name=route["target_voice"])
            audio_url = save_audio_file(audio_bytes)
            audio_mime_type = "audio/mpeg"

        return SpeechTranslateResponse(
            direction=direction,
            speech_locale=route["speech_locale"],
            source_language=route["source_text_lang"],
            target_language=route["target_text_lang"],
            transcript=transcript,
            translated_text=translated,
            normalized_text=normalization.normalized_text if normalization.was_normalized else None,
            normalization_applied=normalization.was_normalized,
            normalization_note=normalization.note,
            audio_url=audio_url,
            audio_mime_type=audio_mime_type,
        )

    except HTTPException:
        raise

    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    finally:
        try:
            if "tmp_path" in locals():
                os.remove(tmp_path)
        except OSError:
            pass