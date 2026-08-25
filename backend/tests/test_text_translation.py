from types import ModuleType
from unittest.mock import Mock

import pytest
from fastapi.testclient import TestClient


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"text": "Hello"},
        {"direction": "en-am"},
    ],
)
def test_text_translation_rejects_missing_fields(
    client: TestClient,
    payload: dict[str, str],
) -> None:
    response = client.post("/api/text-translate", json=payload)

    assert response.status_code == 422
    assert response.json()["detail"]


def test_text_translation_rejects_invalid_direction(client: TestClient) -> None:
    response = client.post(
        "/api/text-translate",
        json={"text": "Hello", "direction": "invalid"},
    )

    assert response.status_code == 422
    assert response.json()["detail"]


def test_text_translation_uses_mocked_translator(
    client: TestClient,
    app_module: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    translate_mock = Mock(return_value="አየር ማረፊያው የት ነው?")
    monkeypatch.setattr(app_module, "translate_text", translate_mock)

    response = client.post(
        "/api/text-translate",
        json={"text": "Where is the airport?", "direction": "en-am"},
    )

    assert response.status_code == 200
    assert response.json() == {
        "source_language": "en",
        "target_language": "am",
        "original_text": "Where is the airport?",
        "translated_text": "አየር ማረፊያው የት ነው?",
        "normalized_text": None,
        "normalization_applied": False,
        "normalization_note": None,
    }
    translate_mock.assert_called_once_with(
        "Where is the airport?",
        target_language="am",
        source_language="en",
    )
