from __future__ import annotations

from dataclasses import dataclass
from threading import Lock
from time import monotonic


@dataclass
class _RateLimitEntry:
    window_started_at: float
    count: int


_state: dict[str, _RateLimitEntry] = {}
_lock = Lock()


def check_rate_limit(key: str, limit: int, window_seconds: int) -> tuple[bool, int]:
    """Return (allowed, retry_after_seconds)."""
    now = monotonic()

    with _lock:
        entry = _state.get(key)
        if entry is None or now - entry.window_started_at >= window_seconds:
            _state[key] = _RateLimitEntry(window_started_at=now, count=1)
            return True, 0

        if entry.count >= limit:
            retry_after = max(1, int(window_seconds - (now - entry.window_started_at)))
            return False, retry_after

        entry.count += 1
        return True, 0


def reset_rate_limits() -> None:
    with _lock:
        _state.clear()
