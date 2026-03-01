# Test Summary

## Implemented Suites
- `tests/test_main.py`
  - `test_full_chat_flow`: Exercises full happy-path (register → login → create room → send + fetch messages) against FastAPI endpoints using an in-memory SQLite DB override.
  - `test_duplicate_username_rejected`: Verifies the registration endpoint enforces username uniqueness and returns HTTP 400 on duplicates.

## Prerequisites
1. Install backend dependencies (includes pytest and sqlite/httpx pins):
   ```
   cd chat_app
   python -m pip install -r requirements.txt
   ```
2. Ensure MySQL-specific settings (from `.env`) are not required for tests; the suite swaps in SQLite automatically.

## Running Tests
Execute from the `chat_app` directory:
```
python -m pytest
```
This command uses FastAPI's `TestClient` with the dependency override defined in `tests/test_main.py`.

## Latest Execution (2026-03-01)
- Command: `python -m pytest`
- Result: `2 passed` (warnings about deprecated FastAPI `on_event` hooks and Pydantic Config classes are known and do not affect pass/fail.)

## Next Steps
- Silence or address deprecation warnings (e.g., migrate to FastAPI lifespan hooks, adopt `ConfigDict`, switch JWT timestamp helpers to timezone-aware values).
- Expand coverage to websocket flows and error scenarios once a websocket test harness is in place.
