from collections import OrderedDict, deque
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

    max_buckets defaults to 10,000 as a per-process cap on retained client/path
    entries. Each bucket contains at most max_requests timestamps; this is not
    a strict byte limit because client identity strings vary in size.
    """

    def __init__(
        self,
        max_requests: int = 20,
        window_seconds: int = 60,
        limited_paths: tuple[str, ...] = (
            "/api/text-translate",
            "/api/speech-translate",
        ),
        max_buckets: int = 10_000,
    ) -> None:
        if isinstance(max_buckets, bool) or not isinstance(max_buckets, int) or max_buckets <= 0:
            raise ValueError("max_buckets must be a positive integer")

        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.limited_paths = set(limited_paths)
        self.max_buckets = max_buckets
        self._requests: OrderedDict[str, deque[float]] = OrderedDict()

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

    def _prune_expired_buckets(self, now: float) -> None:
        # Buckets are ordered by their last accepted request, not rejected hits.
        # Once the oldest bucket is still active, every later bucket is active.
        while self._requests:
            bucket = next(iter(self._requests.values()))
            if bucket and now - bucket[-1] <= self.window_seconds:
                break
            self._requests.popitem(last=False)

    def _rejection_response(self, retry_after: int) -> JSONResponse:
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

    async def __call__(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        if request.url.path not in self.limited_paths:
            return await call_next(request)

        now = monotonic()
        self._prune_expired_buckets(now)
        key = self._client_key(request)
        bucket = self._requests.get(key)

        if bucket is None:
            if len(self._requests) >= self.max_buckets:
                oldest_bucket = next(iter(self._requests.values()))
                # Expiry is strictly after the window boundary, so round up
                # past the oldest bucket's last accepted request plus window.
                retry_after = max(int(self.window_seconds - (now - oldest_bucket[-1])) + 1, 1)
                return self._rejection_response(retry_after)

            bucket = deque()
            self._requests[key] = bucket

        self._cleanup_bucket(bucket, now)

        if len(bucket) >= self.max_requests:
            retry_after = max(int(self.window_seconds - (now - bucket[0])), 1)

            return self._rejection_response(retry_after)

        bucket.append(now)
        self._requests.move_to_end(key)
        remaining = max(self.max_requests - len(bucket), 0)

        response = await call_next(request)

        response.headers["X-RateLimit-Limit"] = str(self.max_requests)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Window-Seconds"] = str(self.window_seconds)

        return response
