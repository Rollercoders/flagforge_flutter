## 1.0.1

- Translate all user-facing text to English: README, CHANGELOG, the example app,
  and every runtime exception/log message. No behavior changes.

## 1.0.0

- **Offline-first**: `FlagStore` abstraction with an in-memory default; persisted
  values are available at startup before the network fetch.
- **Fail-safe**: `initialize()` no longer throws on network errors; unavailable
  flags are `false` (all OFF).
- **Resilience**: `RetryPolicy` with exponential backoff, configurable `timeout`,
  and typed exceptions (`FlagForgeException` and subtypes).
- **Reactivity**: `flagChanges` (Stream) and `watch(key)` (`ValueListenable`).
- **Logging** configurable via `FlagForgeLogger` (no-op default); removed `print`.
- Removed the deprecated library name; adopted `flutter_lints`.
- Added an example app and CI.

### Breaking changes

- `initialize()` no longer throws on network errors (it used to). Use `refresh()`
  if you need to intercept update errors.
- `HttpAdapter.post` has a new optional named `timeout` parameter (with a
  default): additive for SDK consumers; only implementers of a custom
  `HttpAdapter` need to update.

## 0.1.0

- Initial release.
- `FlagForgeClient` with prefetch of all flags at startup via `POST /api/evaluate/all`.
- Local cache with synchronous `isEnabled()`.
- Automatic background refresh with a configurable interval.
- Silent fallback on error during periodic refreshes.
- `EvaluationContext` for targeting by userId and attributes.
- `HttpAdapter` abstraction for full testability without networking.
