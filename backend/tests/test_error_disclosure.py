from pathlib import Path
from threading import BoundedSemaphore
from types import ModuleType
from unittest.mock import Mock

import pytest
from fastapi.testclient import TestClient


INTERNAL_DIAGNOSTIC = "controlled-internal-diagnostic-marker"


def test_text_translation_failure_hides_internal_details(
    client: TestClient,
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    translate = Mock(side_effect=RuntimeError(INTERNAL_DIAGNOSTIC))
    monkeypatch.setattr(app_module, "translate_text", translate)

    response = client.post(
        "/api/text-translate",
        json={"text": "Where is the airport?", "direction": "en-am"},
    )

    assert response.status_code == 500
    assert response.json() == {"detail": "Text translation failed. Please try again."}
    assert INTERNAL_DIAGNOSTIC not in response.text
    translate.assert_called_once()


@pytest.mark.parametrize("failed_stage", ["recognition", "translation", "synthesis", "save"])
def test_speech_failure_hides_internal_details_and_cleans_up(
    client: TestClient,
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
    failed_stage: str,
) -> None:
    stages = ["recognition", "translation", "synthesis", "save"]
    calls: list[str] = []
    upload_path: Path | None = None
    processing_slots = BoundedSemaphore(1)
    monkeypatch.setattr(app_module, "speech_processing_slots", processing_slots)

    def record_stage(name: str) -> None:
        calls.append(name)
        if name == failed_stage:
            raise RuntimeError(INTERNAL_DIAGNOSTIC)

    def recognize(file_path: str, locale: str) -> str:
        nonlocal upload_path
        upload_path = Path(file_path)
        assert upload_path.is_file()
        record_stage("recognition")
        return "Please call me tomorrow."

    def translate(text: str, target_language: str, source_language: str) -> str:
        record_stage("translation")
        return "Controlled translation."

    def synthesize(text: str, voice_name: str) -> bytes:
        record_stage("synthesis")
        return b"controlled-mp3"

    def save(audio_bytes: bytes) -> str:
        record_stage("save")
        return f"/audio/translation_{'a' * 32}.mp3"

    monkeypatch.setattr(app_module, "recognize_speech_from_wav", recognize)
    monkeypatch.setattr(app_module, "translate_text", translate)
    monkeypatch.setattr(app_module, "synthesize_speech_mp3", synthesize)
    monkeypatch.setattr(app_module, "save_audio_file", save)

    response = client.post(
        "/api/speech-translate",
        data={"direction": "en-am", "speak_output": "true"},
        files={"audio": ("sample.wav", b"RIFF-controlled", "audio/wav")},
    )

    assert response.status_code == 500
    assert response.json() == {"detail": "Speech translation failed. Please try again."}
    assert INTERNAL_DIAGNOSTIC not in response.text
    assert calls == stages[: stages.index(failed_stage) + 1]
    assert upload_path is not None
    assert not upload_path.exists()
    assert processing_slots.acquire(blocking=False), "Failed work leaked its speech slot"
    processing_slots.release()
