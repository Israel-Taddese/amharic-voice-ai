import azure.cognitiveservices.speech as speechsdk
from .config import settings


def recognize_speech_from_wav(file_path: str, locale: str) -> str:
    """Recognize one utterance from a WAV file using Azure Speech to Text."""
    settings.validate()

    speech_config = speechsdk.SpeechConfig(
        subscription=settings.azure_speech_key,
        region=settings.azure_speech_region,
    )
    speech_config.speech_recognition_language = locale

    audio_config = speechsdk.audio.AudioConfig(filename=file_path)
    recognizer = speechsdk.SpeechRecognizer(
        speech_config=speech_config,
        audio_config=audio_config,
    )

    result = recognizer.recognize_once_async().get()

    if result.reason == speechsdk.ResultReason.RecognizedSpeech:
        return result.text.strip()

    if result.reason == speechsdk.ResultReason.NoMatch:
        raise RuntimeError("Azure Speech could not recognize speech from this audio file.")

    if result.reason == speechsdk.ResultReason.Canceled:
        cancellation = result.cancellation_details
        raise RuntimeError(f"Speech recognition canceled: {cancellation.reason} - {cancellation.error_details}")

    raise RuntimeError(f"Unexpected speech recognition result: {result.reason}")


def synthesize_speech_mp3(text: str, voice_name: str) -> bytes:
    """Convert text to MP3 audio using Azure Neural TTS."""
    settings.validate()

    speech_config = speechsdk.SpeechConfig(
        subscription=settings.azure_speech_key,
        region=settings.azure_speech_region,
    )
    speech_config.speech_synthesis_voice_name = voice_name
    speech_config.set_speech_synthesis_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Audio16Khz32KBitRateMonoMp3
    )

    synthesizer = speechsdk.SpeechSynthesizer(
        speech_config=speech_config,
        audio_config=None,
    )

    result = synthesizer.speak_text_async(text).get()

    if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
        return result.audio_data

    if result.reason == speechsdk.ResultReason.Canceled:
        cancellation = result.cancellation_details
        raise RuntimeError(f"Speech synthesis canceled: {cancellation.reason} - {cancellation.error_details}")

    raise RuntimeError(f"Unexpected speech synthesis result: {result.reason}")
