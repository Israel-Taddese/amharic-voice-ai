import os
from collections.abc import Generator
from types import ModuleType

import dotenv
import pytest
from fastapi.testclient import TestClient


def _load_backend_without_credentials() -> ModuleType:
    """Import the app without loading dotenv files or reading Azure variables."""
    original_load_dotenv = dotenv.load_dotenv
    original_getenv = os.getenv
    controlled_environment = {
        "AZURE_SPEECH_KEY": "",
        "AZURE_SPEECH_REGION": "",
        "AZURE_TRANSLATOR_KEY": "",
        "AZURE_TRANSLATOR_REGION": "",
        "AZURE_TRANSLATOR_ENDPOINT": "https://example.invalid",
        "APP_ENV": "test",
        "ALLOWED_ORIGINS": "http://testserver",
    }

    def disable_dotenv(*args: object, **kwargs: object) -> bool:
        return False

    def controlled_getenv(key: str, default: str | None = None) -> str | None:
        if key in controlled_environment:
            return controlled_environment[key]
        return original_getenv(key, default)

    dotenv.load_dotenv = disable_dotenv
    os.getenv = controlled_getenv
    try:
        from backend.app import main as main_module
    finally:
        os.getenv = original_getenv
        dotenv.load_dotenv = original_load_dotenv

    return main_module


main_module = _load_backend_without_credentials()


@pytest.fixture
def app_module() -> ModuleType:
    return main_module


@pytest.fixture(autouse=True)
def prevent_cloud_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """Fail every test that reaches an unmocked Azure service boundary."""

    def unexpected_cloud_call(*args: object, **kwargs: object) -> None:
        pytest.fail("Test attempted an unmocked Azure service call")

    monkeypatch.setattr(main_module, "translate_text", unexpected_cloud_call)
    monkeypatch.setattr(main_module, "recognize_speech_from_wav", unexpected_cloud_call)
    monkeypatch.setattr(main_module, "synthesize_speech_mp3", unexpected_cloud_call)


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    main_module.rate_limiter._requests.clear()
    with TestClient(main_module.app) as test_client:
        yield test_client
    main_module.rate_limiter._requests.clear()
