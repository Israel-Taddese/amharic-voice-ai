import asyncio
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from pathlib import Path
from threading import BoundedSemaphore, Event
from types import ModuleType
from unittest.mock import Mock

import pytest
from fastapi import UploadFile
from fastapi.testclient import TestClient


# Timeouts only escape deadlocks; events establish every ordering assertion.
WAIT_SECONDS = 5
TRANSCRIPT = "Please call me tomorrow."
TRANSLATION = "እባክዎ ነገ ይደውሉልኝ።"
AUDIO_URL = f"/audio/translation_{'a' * 32}.mp3"


@pytest.mark.parametrize("blocked_stage", ["recognition", "translation", "synthesis"])
def test_health_remains_responsive_during_blocking_speech_work(
    client: TestClient,
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
    blocked_stage: str,
) -> None:
    entered = Event()
    release = Event()
    calls: list[str] = []
    upload_path: Path | None = None

    def stage(name: str) -> None:
        calls.append(name)
        if name == blocked_stage:
            entered.set()
            assert release.wait(WAIT_SECONDS), "Speech worker was not released"

    def recognize(file_path: str, locale: str) -> str:
        nonlocal upload_path
        upload_path = Path(file_path)
        assert upload_path.is_file()
        assert locale == "en-US"
        stage("recognition")
        return TRANSCRIPT

    def translate(text: str, target_language: str, source_language: str) -> str:
        assert (text, source_language, target_language) == (TRANSCRIPT, "en", "am")
        stage("translation")
        return TRANSLATION

    def synthesize(text: str, voice_name: str) -> bytes:
        assert (text, voice_name) == (TRANSLATION, "am-ET-MekdesNeural")
        stage("synthesis")
        return b"controlled-mp3"

    def save(audio_bytes: bytes) -> str:
        assert audio_bytes == b"controlled-mp3"
        calls.append("save")
        return AUDIO_URL

    monkeypatch.setattr(app_module, "recognize_speech_from_wav", recognize)
    monkeypatch.setattr(app_module, "translate_text", translate)
    monkeypatch.setattr(app_module, "synthesize_speech_mp3", synthesize)
    monkeypatch.setattr(app_module, "save_audio_file", save)

    with ThreadPoolExecutor(max_workers=2) as requests:
        upload = requests.submit(
            client.post,
            "/api/speech-translate",
            data={"direction": "en-am", "speak_output": "true"},
            files={"audio": ("sample.wav", b"RIFF-controlled", "audio/wav")},
        )
        try:
            assert entered.wait(WAIT_SECONDS), "Speech worker never reached the controlled stage"
            health = requests.submit(client.get, "/health").result(timeout=WAIT_SECONDS)
            assert health.status_code == 200
            assert health.json() == {"status": "ok", "service": "amharic-voice-ai"}
            assert not upload.done(), "Speech must still be blocked when health responds"
        finally:
            release.set()
        response = upload.result(timeout=WAIT_SECONDS)

    assert response.status_code == 200
    assert response.json() == {
        "direction": "en-am",
        "speech_locale": "en-US",
        "source_language": "en",
        "target_language": "am",
        "transcript": TRANSCRIPT,
        "translated_text": TRANSLATION,
        "normalized_text": None,
        "normalization_applied": False,
        "normalization_note": None,
        "audio_url": AUDIO_URL,
        "audio_mime_type": "audio/mpeg",
    }
    assert calls == ["recognition", "translation", "synthesis", "save"]
    assert upload_path is not None
    assert not upload_path.exists()


@pytest.mark.parametrize(
    ("recognition_result", "status", "message"),
    [
        (RuntimeError("controlled provider failure"), 500, "controlled provider failure"),
        (RuntimeError("SPXERR_INVALID_HEADER"), 400, "Invalid WAV audio"),
        ("", 500, "No transcript returned"),
    ],
)
def test_worker_failures_preserve_errors_and_remove_upload(
    client: TestClient,
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
    recognition_result: str | RuntimeError,
    status: int,
    message: str,
) -> None:
    upload_path: Path | None = None
    processing_slots = BoundedSemaphore(1)
    monkeypatch.setattr(app_module, "speech_processing_slots", processing_slots)

    def recognize(file_path: str, locale: str) -> str:
        nonlocal upload_path
        upload_path = Path(file_path)
        assert upload_path.is_file()
        if isinstance(recognition_result, RuntimeError):
            raise recognition_result
        return recognition_result

    monkeypatch.setattr(app_module, "recognize_speech_from_wav", recognize)
    response = client.post(
        "/api/speech-translate",
        data={"direction": "en-am", "speak_output": "false"},
        files={"audio": ("sample.wav", b"RIFF-controlled", "audio/wav")},
    )

    assert response.status_code == status
    assert message in response.json()["detail"]
    assert upload_path is not None
    assert not upload_path.exists()
    assert processing_slots.acquire(blocking=False), "Failed work leaked its speech slot"
    processing_slots.release()


def test_cancellation_keeps_upload_until_running_worker_finishes(
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    entered = Event()
    release = Event()
    cleaned = Event()
    slot_released = Event()
    processing_slots = BoundedSemaphore(1)
    upload_path: Path | None = None
    original_cleanup = app_module._remove_temporary_upload
    original_release = processing_slots.release

    def release_slot(n: int = 1) -> None:
        original_release(n)
        slot_released.set()

    def recognize(file_path: str, locale: str) -> str:
        nonlocal upload_path
        upload_path = Path(file_path)
        entered.set()
        assert release.wait(WAIT_SECONDS), "Speech worker was not released"
        assert upload_path.is_file(), "Cancellation removed a WAV still owned by the worker"
        return TRANSCRIPT

    def cleanup(file_path: str | None) -> None:
        original_cleanup(file_path)
        if upload_path is not None and file_path == str(upload_path):
            cleaned.set()

    monkeypatch.setattr(app_module, "recognize_speech_from_wav", recognize)
    monkeypatch.setattr(app_module, "translate_text", Mock(return_value=TRANSLATION))
    monkeypatch.setattr(app_module, "_remove_temporary_upload", cleanup)
    monkeypatch.setattr(processing_slots, "release", release_slot)
    monkeypatch.setattr(app_module, "speech_processing_slots", processing_slots)

    async def exercise() -> None:
        audio = UploadFile(filename="sample.wav", file=BytesIO(b"RIFF-controlled"))
        request = asyncio.create_task(
            app_module.speech_translate(direction="en-am", speak_output=False, audio=audio)
        )
        try:
            assert await asyncio.to_thread(entered.wait, WAIT_SECONDS)
            request.cancel()
            with pytest.raises(asyncio.CancelledError):
                await request
            assert upload_path is not None
            assert upload_path.is_file()
            assert not cleaned.is_set()
            assert not slot_released.is_set()
            assert not processing_slots.acquire(blocking=False)
        finally:
            release.set()
            assert await asyncio.to_thread(cleaned.wait, WAIT_SECONDS)
            assert await asyncio.to_thread(slot_released.wait, WAIT_SECONDS)
            await audio.close()

    asyncio.run(exercise())
    assert upload_path is not None
    assert not upload_path.exists()
    assert processing_slots.acquire(blocking=False)
    processing_slots.release()


def test_cancellation_before_worker_claim_cleans_upload_and_skips_late_work(
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    queued: dict[str, object] = {}
    processing_slots = BoundedSemaphore(1)
    monkeypatch.setattr(app_module, "speech_processing_slots", processing_slots)

    async def exercise() -> None:
        queued_event = asyncio.Event()
        release = asyncio.Event()

        async def hold_threadpool(function, *args, **kwargs):
            queued.update(function=function, args=args, kwargs=kwargs)
            queued_event.set()
            await release.wait()

        monkeypatch.setattr(app_module, "run_in_threadpool", hold_threadpool)
        audio = UploadFile(filename="sample.wav", file=BytesIO(b"RIFF-controlled"))
        request = asyncio.create_task(
            app_module.speech_translate(direction="en-am", speak_output=False, audio=audio)
        )
        try:
            await asyncio.wait_for(queued_event.wait(), timeout=WAIT_SECONDS)
            upload_path = Path(queued["args"][0])
            assert upload_path.is_file()
            assert not processing_slots.acquire(blocking=False)
            request.cancel()
            with pytest.raises(asyncio.CancelledError):
                await request
            assert not upload_path.exists()
            assert processing_slots.acquire(blocking=False)
            processing_slots.release()
            # Simulate a queued wrapper racing with cancellation. Unmocked cloud
            # boundaries fail automatically if it processes this deleted upload.
            with pytest.raises(asyncio.CancelledError):
                queued["function"](*queued["args"], **queued["kwargs"])
            assert not upload_path.exists()
            assert processing_slots.acquire(blocking=False)
            processing_slots.release()
        finally:
            request.cancel()
            await audio.close()

    asyncio.run(exercise())


def test_small_oversized_upload_is_removed_before_worker_dispatch(
    client: TestClient,
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    removed_paths: list[Path] = []
    original_cleanup = app_module._remove_temporary_upload

    def cleanup(file_path: str | None) -> None:
        original_cleanup(file_path)
        if file_path is not None:
            removed_paths.append(Path(file_path))

    monkeypatch.setattr(app_module, "MAX_UPLOAD_SIZE_BYTES", 8)
    monkeypatch.setattr(app_module, "_remove_temporary_upload", cleanup)
    dispatch = Mock(side_effect=AssertionError("Oversized upload reached worker dispatch"))
    monkeypatch.setattr(app_module, "run_in_threadpool", dispatch)

    response = client.post(
        "/api/speech-translate",
        data={"direction": "en-am", "speak_output": "false"},
        files={"audio": ("sample.wav", b"123456789", "audio/wav")},
    )

    assert response.status_code == 413
    assert "too large" in response.json()["detail"]
    dispatch.assert_not_called()
    assert len(removed_paths) == 1
    assert not removed_paths[0].exists()


def test_busy_speech_admission_rejects_without_cloud_work_then_recovers(
    client: TestClient,
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    entered = Event()
    release = Event()
    processing_slots = BoundedSemaphore(1)
    recognition_count = 0
    removed_paths: list[Path] = []
    original_cleanup = app_module._remove_temporary_upload

    def recognize(file_path: str, locale: str) -> str:
        nonlocal recognition_count
        recognition_count += 1
        if recognition_count == 1:
            entered.set()
            assert release.wait(WAIT_SECONDS), "Speech worker was not released"
        return TRANSCRIPT

    def cleanup(file_path: str | None) -> None:
        original_cleanup(file_path)
        if file_path is not None:
            removed_paths.append(Path(file_path))

    def upload():
        return client.post(
            "/api/speech-translate",
            data={"direction": "en-am", "speak_output": "false"},
            files={"audio": ("sample.wav", b"RIFF-controlled", "audio/wav")},
        )

    monkeypatch.setattr(app_module, "speech_processing_slots", processing_slots)
    monkeypatch.setattr(app_module, "recognize_speech_from_wav", recognize)
    monkeypatch.setattr(app_module, "translate_text", Mock(return_value=TRANSLATION))
    monkeypatch.setattr(app_module, "_remove_temporary_upload", cleanup)

    with ThreadPoolExecutor(max_workers=1) as requests:
        first = requests.submit(upload)
        try:
            assert entered.wait(WAIT_SECONDS), "First speech worker did not start"
            busy = upload()
            assert busy.status_code == 429
            assert busy.headers["Retry-After"] == "1"
            assert recognition_count == 1
            assert len(removed_paths) == 1
            assert not removed_paths[0].exists()
        finally:
            release.set()
        assert first.result(timeout=WAIT_SECONDS).status_code == 200

    assert upload().status_code == 200
    assert recognition_count == 2
    assert len(removed_paths) == 3
    assert all(not path.exists() for path in removed_paths)
