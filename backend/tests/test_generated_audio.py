import os
import re
import time
import uuid
from pathlib import Path
from types import ModuleType

import pytest
from fastapi.testclient import TestClient
from starlette.staticfiles import StaticFiles


@pytest.fixture
def generated_audio_directory(
    tmp_path: Path,
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
) -> Path:
    audio_mount = next(
        route
        for route in app_module.app.routes
        if getattr(route, "name", None) == "audio"
    )
    assert isinstance(audio_mount.app, StaticFiles)

    monkeypatch.setattr(app_module, "AUDIO_OUTPUT_DIR", tmp_path)
    monkeypatch.setattr(audio_mount.app, "directory", str(tmp_path))
    monkeypatch.setattr(audio_mount.app, "all_directories", [str(tmp_path)])
    return tmp_path


def create_generated_audio(
    directory: Path,
    *,
    age_seconds: float = 0,
    content: bytes = b"controlled-mp3",
) -> Path:
    audio_path = directory / f"translation_{uuid.uuid4().hex}.mp3"
    audio_path.write_bytes(content)
    modified_at = time.time() - age_seconds
    os.utime(audio_path, (modified_at, modified_at))
    return audio_path


def test_fresh_generated_audio_remains_accessible(
    client: TestClient,
    app_module: ModuleType,
    generated_audio_directory: Path,
) -> None:
    audio_bytes = b"fresh-controlled-mp3"
    audio_path = create_generated_audio(
        generated_audio_directory,
        age_seconds=app_module.GENERATED_AUDIO_RETENTION_SECONDS - 60,
        content=audio_bytes,
    )

    response = client.get(f"/audio/{audio_path.name}")

    assert response.status_code == 200
    assert response.content == audio_bytes
    assert response.headers["content-type"] == "audio/mpeg"
    assert response.headers["cache-control"] == "private, no-store"
    assert audio_path.exists()


def test_expired_generated_audio_is_deleted_and_never_returned(
    client: TestClient,
    app_module: ModuleType,
    generated_audio_directory: Path,
) -> None:
    audio_bytes = b"expired-sensitive-audio"
    audio_path = create_generated_audio(
        generated_audio_directory,
        age_seconds=app_module.GENERATED_AUDIO_RETENTION_SECONDS + 1,
        content=audio_bytes,
    )
    unrelated_path = generated_audio_directory / "unrelated.txt"
    unrelated_path.write_text("leave this file alone", encoding="utf-8")

    response = client.get(f"/audio/{audio_path.name}")

    assert response.status_code == 404
    assert audio_bytes not in response.content
    assert response.headers["cache-control"] == "private, no-store"
    assert not audio_path.exists()
    assert unrelated_path.read_text(encoding="utf-8") == "leave this file alone"


@pytest.mark.parametrize(
    "request_path",
    [
        "/audio/translation_not-a-uuid.mp3",
        "/audio/translation_00000000000000000000000000000000.wav",
        "/audio/subdirectory/translation_00000000000000000000000000000000.mp3",
        "/audio/%2e%2e/unrelated.txt",
    ],
)
def test_malformed_generated_audio_paths_are_unavailable(
    client: TestClient,
    generated_audio_directory: Path,
    request_path: str,
) -> None:
    unrelated_path = generated_audio_directory / "unrelated.txt"
    unrelated_bytes = b"unrelated-content"
    unrelated_path.write_bytes(unrelated_bytes)

    response = client.get(request_path)

    assert response.status_code == 404
    assert unrelated_bytes not in response.content
    assert unrelated_path.read_bytes() == unrelated_bytes


def test_cleanup_is_safe_if_an_expired_file_disappears_concurrently(
    app_module: ModuleType,
    generated_audio_directory: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    audio_path = create_generated_audio(
        generated_audio_directory,
        age_seconds=app_module.GENERATED_AUDIO_RETENTION_SECONDS + 1,
    )
    original_unlink = Path.unlink

    def disappear_before_unlink(path: Path, *args: object, **kwargs: object) -> None:
        if path == audio_path:
            original_unlink(path)
            raise FileNotFoundError(path)

        original_unlink(path, *args, **kwargs)

    monkeypatch.setattr(Path, "unlink", disappear_before_unlink)

    assert app_module.cleanup_generated_audio() == 0
    assert not audio_path.exists()


def test_cleanup_ignores_non_uuid_translation_files(
    app_module: ModuleType,
    generated_audio_directory: Path,
) -> None:
    unrelated_path = generated_audio_directory / "translation_manual.mp3"
    unrelated_path.write_bytes(b"not-app-owned")
    expired_at = time.time() - app_module.GENERATED_AUDIO_RETENTION_SECONDS - 1
    os.utime(unrelated_path, (expired_at, expired_at))

    assert app_module.cleanup_generated_audio() == 0
    assert unrelated_path.read_bytes() == b"not-app-owned"


def test_saved_audio_url_preserves_existing_contract(
    app_module: ModuleType,
    generated_audio_directory: Path,
) -> None:
    audio_bytes = b"generated-audio"

    audio_url = app_module.save_audio_file(audio_bytes)

    assert re.fullmatch(r"/audio/translation_[0-9a-f]{32}\.mp3", audio_url)
    saved_path = generated_audio_directory / audio_url.removeprefix("/audio/")
    assert saved_path.read_bytes() == audio_bytes
