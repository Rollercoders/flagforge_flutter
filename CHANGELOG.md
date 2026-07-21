## 1.0.0

- **Offline-first**: astrazione `FlagStore` con default in-memory; i valori
  persistiti sono disponibili all'avvio prima del fetch di rete.
- **Fail-safe**: `initialize()` non lancia più per errori di rete; flag non
  disponibili valgono `false` (tutto OFF).
- **Resilienza**: `RetryPolicy` con backoff esponenziale, `timeout`
  configurabile ed eccezioni tipizzate (`FlagForgeException` e sottotipi).
- **Reattività**: `flagChanges` (Stream) e `watch(key)` (`ValueListenable`).
- **Logging** configurabile via `FlagForgeLogger` (default no-op); rimosso `print`.
- Rimosso il nome libreria deprecato; adottato `flutter_lints`.
- Aggiunti example app e CI.

### Breaking changes

- `initialize()` non lancia più in caso di errore di rete (prima sì). Usa
  `refresh()` se devi intercettare gli errori di aggiornamento.
- `HttpAdapter.post` ha un nuovo parametro nominale opzionale `timeout`.

## 0.1.0

- Versione iniziale.
- `FlagForgeClient` con prefetch di tutti i flag all'avvio tramite `POST /api/evaluate/all`.
- Cache locale con `isEnabled()` sincrono.
- Refresh automatico in background con intervallo configurabile.
- Fallback silenzioso su errore nei refresh periodici.
- `EvaluationContext` per targeting per userId e attributi.
- Astrazione `HttpAdapter` per testabilità completa senza rete.
