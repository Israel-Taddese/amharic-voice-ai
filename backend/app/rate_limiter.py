from collections import defaultdict, deque
from time import monotonic
from typing import Callable, Awaitable

from fastapi import Request, Response
from starlette.responses import JSONResponse


class InMemoryRateLimiter:
    """
    Simple in-memory rate limiter for local MVP use.

    This is intended for local development and portfolio demonstration.
    For production, use a shared store such as Redis, an API gateway,
    Azure API Management, or platform-level throttling.
    """

    def __init__(
        self,
        max_requests: int = 20,
        window_seconds: int = 60,
        limited_paths: tuple[str, ...] = (
            "/api/text-translate",
            "/api/speech-translate",
        ),
    ) -> None:
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.limited_paths = set(limited_paths)
        self._requests: dict[str, deque[float]] = defaultdict(deque)

    def _client_key(self, request: Request) -> str:
        forwarded_for = request.headers.get("x-forwarded-for")

        if forwarded_for:
            client_host = forwarded_for.split(",")[0].strip()
        elif request.client:
            client_host = request.client.host
        else:
            client_host = "unknown"

        return f"{client_host}:{request.url.path}"

    def _cleanup_bucket(self, bucket: deque[float], now: float) -> None:
        while bucket and now - bucket[0] > self.window_seconds:
            bucket.popleft()

    async def __call__(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        if request.url.path not in self.limited_paths:
            return await call_next(request)

        now = monotonic()
        key = self._client_key(request)
        bucket = self._requests[key]

        self._cleanup_bucket(bucket, now)

        if len(bucket) >= self.max_requests:
            retry_after = max(int(self.window_seconds - (now - bucket[0])), 1)

            return JSONResponse(
                status_code=429,
                content={
                    "detail": (
                        "Rate limit exceeded. "
                        f"Try again in {retry_after} seconds."
                    )
                },
                headers={
                    "Retry-After": str(retry_after),
                    "X-RateLimit-Limit": str(self.max_requests),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Window-Seconds": str(self.window_seconds),
                },
            )

        bucket.append(now)
        remaining = max(self.max_requests - len(bucket), 0)

        response = await call_next(request)

        response.headers["X-RateLimit-Limit"] = str(self.max_requests)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Window-Seconds"] = str(self.window_seconds)

        return response
