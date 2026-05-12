from pathlib import Path
import sys

# Add backend root to Python import path so "from app.config import settings" works
BACKEND_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_ROOT))

import azure.cognitiveservices.speech as speechsdk
from app.config import settings


def synthesize_to_wav(text: str, voice_name: str, output_path: Path) -> None:
    speech_config = speechsdk.SpeechConfig(
        subscription=settings.azure_speech_key,
        region=settings.azure_speech_region
    )

    speech_config.speech_synthesis_voice_name = voice_name

    speech_config.set_speech_synthesis_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Riff16Khz16BitMonoPcm
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)

    audio_config = speechsdk.audio.AudioOutputConfig(filename=str(output_path))

    synthesizer = speechsdk.SpeechSynthesizer(
        speech_config=speech_config,
        audio_config=audio_config
    )

    result = synthesizer.speak_text_async(text).get()

    if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
        print(f"Created: {output_path}")
    else:
        details = result.cancellation_details
        raise RuntimeError(
            f"TTS failed for {voice_name}: {details.reason} {details.error_details}"
        )


samples_dir = BACKEND_ROOT / "samples"

synthesize_to_wav(
    text="Hello, how are you?",
    voice_name="en-US-JennyNeural",
    output_path=samples_dir / "english_hello.wav"
)

synthesize_to_wav(
    text="\u1230\u120b\u121d \u12a5\u1295\u12f4\u1275 \u1290\u1205?",
    voice_name="am-ET-MekdesNeural",
    output_path=samples_dir / "amharic_hello.wav"
)

print("Done. Test audio files are ready.")
