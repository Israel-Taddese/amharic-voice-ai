from pathlib import Path
from types import ModuleType
from unittest.mock import Mock

import pytest
from fastapi.testclient import TestClient
from starlette.staticfiles import StaticFiles


def wav_upload(
    filename: str = "sample.wav",
    content: bytes = b"RIFF-controlled-test-data",
) -> dict[str, tuple[str, bytes, str]]:
    return {"audio": (filename, content, "audio/wav")}


@pytest.mark.parametrize(
    ("data", "files"),
    [
        ({}, {}),
        ({"direction": "am-en", "speak_output": "false"}, {}),
        ({"speak_output": "false"}, wav_upload()),
    ],
)
def test_speech_translation_rejects_missing_multipart_fields(
    client: TestClient,
    data: dict[str, str],
    files: dict[str, tuple[str, bytes, str]],
) -> None:
    response = client.post("/api/speech-translate", data=data, files=files)

    assert response.status_code == 422
    assert response.json()["detail"]


def test_speech_translation_rejects_invalid_direction(client: TestClient) -> None:
    response = client.post(
        "/api/speech-translate",
        data={"direction": "invalid", "speak_output": "false"},
        files=wav_upload(),
    )

    assert response.status_code == 422
    assert response.json()["detail"]


def test_speech_translation_rejects_non_wav_filename(client: TestClient) -> None:
    response = client.post(
        "/api/speech-translate",
        data={"direction": "am-en", "speak_output": "false"},
        files=wav_upload(filename="sample.mp3"),
    )

    assert response.status_code == 400
    assert "Please upload a WAV file" in response.json()["detail"]


def test_invalid_wav_returns_application_error(
    client: TestClient,
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    recognize_mock = Mock(side_effect=RuntimeError("SPXERR_INVALID_HEADER"))
    monkeypatch.setattr(app_module, "recognize_speech_from_wav", recognize_mock)

    response = client.post(
        "/api/speech-translate",
        data={"direction": "am-en", "speak_output": "false"},
        files=wav_upload(content=b"not-a-real-wav"),
    )

    assert response.status_code == 400
    assert "Invalid WAV audio" in response.json()["detail"]
    recognize_mock.assert_called_once()


def test_application_upload_size_limit_with_small_fixture(
    client: TestClient,
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The app guard runs after multipart parsing; edge request limits remain required."""
    monkeypatch.setattr(app_module, "MAX_UPLOAD_SIZE_BYTES", 8)
    monkeypatch.setattr(app_module, "MAX_UPLOAD_SIZE_MB", 0)

    response = client.post(
        "/api/speech-translate",
        data={"direction": "am-en", "speak_output": "false"},
        files=wav_upload(content=b"123456789"),
    )

    assert response.status_code == 413
    assert "too large" in response.json()["detail"]


def test_generated_audio_mount_exists(app_module: ModuleType) -> None:
    audio_mounts = [
        route
        for route in app_module.app.routes
        if getattr(route, "path", None) == "/audio"
    ]

    assert len(audio_mounts) == 1
    assert audio_mounts[0].name == "audio"
    assert isinstance(audio_mounts[0].app, StaticFiles)


def test_missing_generated_audio_returns_404(client: TestClient) -> None:
    response = client.get("/audio/does-not-exist.mp3")

    assert response.status_code == 404


def test_speech_translation_uses_controlled_mocks(
    client: TestClient,
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    temporary_path: Path | None = None

    def recognize_mock(file_path: str, locale: str) -> str:
        nonlocal temporary_path
        temporary_path = Path(file_path)
        assert temporary_path.is_file()
        assert locale == "en-US"
        return "Please call me tomorrow."

    translate_mock = Mock(return_value="እባክዎ ነገ ይደውሉልኝ።")
    synthesize_mock = Mock(return_value=b"controlled-mp3")
    save_audio_mock = Mock(return_value="/audio/translation-test.mp3")
    monkeypatch.setattr(app_module, "recognize_speech_from_wav", recognize_mock)
    monkeypatch.setattr(app_module, "translate_text", translate_mock)
    monkeypatch.setattr(app_module, "synthesize_speech_mp3", synthesize_mock)
    monkeypatch.setattr(app_module, "save_audio_file", save_audio_mock)

    response = client.post(
        "/api/speech-translate",
        data={"direction": "en-am", "speak_output": "true"},
        files=wav_upload(),
    )

    assert response.status_code == 200
    assert response.json() == {
        "direction": "en-am",
        "speech_locale": "en-US",
        "source_language": "en",
        "target_language": "am",
        "transcript": "Please call me tomorrow.",
        "translated_text": "እባክዎ ነገ ይደውሉልኝ።",
        "normalized_text": None,
        "normalization_applied": False,
        "normalization_note": None,
        "audio_url": "/audio/translation-test.mp3",
        "audio_mime_type": "audio/mpeg",
    }
    translate_mock.assert_called_once_with(
        "Please call me tomorrow.",
        target_language="am",
        source_language="en",
    )
    synthesize_mock.assert_called_once_with(
        "እባክዎ ነገ ይደውሉልኝ።",
        voice_name="am-ET-MekdesNeural",
    )
    save_audio_mock.assert_called_once_with(b"controlled-mp3")
    assert temporary_path is not None
    assert not temporary_path.exists()
