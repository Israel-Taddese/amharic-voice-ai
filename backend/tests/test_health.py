from fastapi.testclient import TestClient


def test_health_returns_expected_response(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json().keys() >= {"status", "service"}
    assert response.json()["status"] == "ok"
    assert response.json()["service"] == "amharic-voice-ai"
