import asyncio
import json

import pytest
from fastapi import Request, Response

from backend.app import rate_limiter as limiter_module
from backend.app.rate_limiter import InMemoryRateLimiter


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


class CallNext:
    def __init__(self) -> None:
        self.calls = 0

    async def __call__(self, request: Request) -> Response:
        self.calls += 1
        return Response(status_code=200)


@pytest.fixture
def clock(monkeypatch: pytest.MonkeyPatch) -> FakeClock:
    fake_clock = FakeClock()
    monkeypatch.setattr(limiter_module, "monotonic", fake_clock)
    return fake_clock


def invoke(
    limiter: InMemoryRateLimiter,
    call_next: CallNext,
    host: str = "192.0.2.1",
    path: str = "/api/text-translate",
) -> Response:
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "scheme": "http",
            "server": ("testserver", 80),
            "client": (host, 12345),
            "path": path,
            "query_string": b"",
            "headers": [],
        }
    )
    return asyncio.run(limiter(request, call_next))


@pytest.mark.parametrize("max_buckets", [0, -1, True, False, 1.5, "10", None])
def test_bucket_capacity_requires_positive_integer(max_buckets: object) -> None:
    with pytest.raises(ValueError, match="max_buckets must be a positive integer"):
        InMemoryRateLimiter(max_buckets=max_buckets)


def test_default_budget_and_rejection_contract_are_preserved(clock: FakeClock) -> None:
    limiter = InMemoryRateLimiter()
    call_next = CallNext()

    for index in range(20):
        response = invoke(limiter, call_next)
        assert response.status_code == 200
        assert response.headers["X-RateLimit-Limit"] == "20"
        assert response.headers["X-RateLimit-Remaining"] == str(19 - index)
        assert response.headers["X-RateLimit-Window-Seconds"] == "60"

    rejected = invoke(limiter, call_next)

    assert rejected.status_code == 429
    assert json.loads(rejected.body) == {
        "detail": "Rate limit exceeded. Try again in 60 seconds."
    }
    assert rejected.headers["Retry-After"] == "60"
    assert rejected.headers["X-RateLimit-Limit"] == "20"
    assert rejected.headers["X-RateLimit-Remaining"] == "0"
    assert rejected.headers["X-RateLimit-Window-Seconds"] == "60"
    assert call_next.calls == 20


def test_window_boundary_stays_inclusive_until_elapsed(clock: FakeClock) -> None:
    limiter = InMemoryRateLimiter(max_requests=1)
    call_next = CallNext()
    assert invoke(limiter, call_next).status_code == 200

    clock.now = 60.0
    assert invoke(limiter, call_next).status_code == 429
    assert call_next.calls == 1

    clock.now = 60.001
    response = invoke(limiter, call_next)
    assert response.status_code == 200
    assert response.headers["X-RateLimit-Remaining"] == "0"
    assert call_next.calls == 2
    assert len(limiter._requests) == 1


def test_limited_request_prunes_other_expired_client_buckets(clock: FakeClock) -> None:
    limiter = InMemoryRateLimiter(max_buckets=2)
    call_next = CallNext()
    invoke(limiter, call_next, host="192.0.2.1")
    invoke(limiter, call_next, host="192.0.2.2")

    clock.now = 61.0
    response = invoke(limiter, call_next, host="192.0.2.3")

    assert response.status_code == 200
    assert list(limiter._requests) == ["192.0.2.3:/api/text-translate"]


def test_capacity_rejects_new_key_without_evicting_or_resetting_active_key(clock: FakeClock) -> None:
    limiter = InMemoryRateLimiter(max_requests=2, max_buckets=1)
    call_next = CallNext()
    first = invoke(limiter, call_next)
    assert first.headers["X-RateLimit-Remaining"] == "1"

    rejected = invoke(limiter, call_next, host="192.0.2.2")
    assert rejected.status_code == 429
    assert rejected.headers["Retry-After"] == "61"
    assert rejected.headers["X-RateLimit-Remaining"] == "0"
    assert call_next.calls == 1
    assert list(limiter._requests) == ["192.0.2.1:/api/text-translate"]

    second = invoke(limiter, call_next)
    assert second.status_code == 200
    assert second.headers["X-RateLimit-Remaining"] == "0"
    assert invoke(limiter, call_next).status_code == 429
    assert call_next.calls == 2


def test_capacity_retry_and_recovery_use_last_accepted_timestamp(clock: FakeClock) -> None:
    limiter = InMemoryRateLimiter(max_requests=2, max_buckets=1)
    call_next = CallNext()
    invoke(limiter, call_next)
    clock.now = 10.0
    invoke(limiter, call_next)

    clock.now = 20.0
    rejected = invoke(limiter, call_next, host="192.0.2.2")
    assert rejected.status_code == 429
    assert rejected.headers["Retry-After"] == "51"
    assert call_next.calls == 2

    clock.now = 70.0
    assert invoke(limiter, call_next, host="192.0.2.2").status_code == 429
    assert call_next.calls == 2

    clock.now = 70.001
    accepted = invoke(limiter, call_next, host="192.0.2.2")
    assert accepted.status_code == 200
    assert accepted.headers["X-RateLimit-Remaining"] == "1"
    assert list(limiter._requests) == ["192.0.2.2:/api/text-translate"]


def test_active_bucket_reordering_keeps_counts_when_other_key_expires(clock: FakeClock) -> None:
    limiter = InMemoryRateLimiter(max_requests=3, max_buckets=2)
    call_next = CallNext()
    invoke(limiter, call_next, host="192.0.2.1")
    clock.now = 1.0
    invoke(limiter, call_next, host="192.0.2.2")
    clock.now = 30.0
    invoke(limiter, call_next, host="192.0.2.1")

    clock.now = 62.0
    assert invoke(limiter, call_next, host="192.0.2.3").status_code == 200
    assert "192.0.2.2:/api/text-translate" not in limiter._requests

    active = invoke(limiter, call_next, host="192.0.2.1")
    assert active.status_code == 200
    assert active.headers["X-RateLimit-Remaining"] == "1"
    assert list(limiter._requests["192.0.2.1:/api/text-translate"]) == [30.0, 62.0]


def test_rejections_do_not_reorder_or_extend_bucket_lifetime(clock: FakeClock) -> None:
    limiter = InMemoryRateLimiter(max_requests=1, max_buckets=2)
    call_next = CallNext()
    invoke(limiter, call_next, host="192.0.2.1")
    clock.now = 1.0
    invoke(limiter, call_next, host="192.0.2.2")
    clock.now = 2.0
    assert invoke(limiter, call_next, host="192.0.2.1").status_code == 429

    clock.now = 60.5
    assert invoke(limiter, call_next, host="192.0.2.3").status_code == 200
    assert list(limiter._requests) == [
        "192.0.2.2:/api/text-translate",
        "192.0.2.3:/api/text-translate",
    ]
    assert invoke(limiter, call_next, host="192.0.2.2").status_code == 429
    assert call_next.calls == 3


def test_text_and_speech_paths_keep_independent_budgets(clock: FakeClock) -> None:
    limiter = InMemoryRateLimiter(max_requests=1)
    call_next = CallNext()

    assert invoke(limiter, call_next).status_code == 200
    assert invoke(limiter, call_next, path="/api/speech-translate").status_code == 200
    assert invoke(limiter, call_next).status_code == 429
    assert invoke(limiter, call_next, path="/api/speech-translate").status_code == 429
    assert call_next.calls == 2
    assert len(limiter._requests) == 2


@pytest.mark.parametrize("path", ["/health", "/audio/fixture.mp3", "/docs"])
def test_exempt_paths_do_not_consume_or_prune_buckets(clock: FakeClock, path: str) -> None:
    limiter = InMemoryRateLimiter(max_buckets=1)
    call_next = CallNext()
    invoke(limiter, call_next)
    original_bucket = list(limiter._requests.items())
    clock.now = 61.0

    exempt = invoke(limiter, call_next, host="192.0.2.2", path=path)

    assert exempt.status_code == 200
    assert "X-RateLimit-Limit" not in exempt.headers
    assert list(limiter._requests.items()) == original_bucket
    assert call_next.calls == 2

    assert invoke(limiter, call_next, host="192.0.2.2").status_code == 200
    assert list(limiter._requests) == ["192.0.2.2:/api/text-translate"]
