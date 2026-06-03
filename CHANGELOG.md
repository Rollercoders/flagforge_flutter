## 0.1.0

- Versione iniziale.
- `FlagForgeClient` con prefetch di tutti i flag all'avvio tramite `POST /api/evaluate/all`.
- Cache locale con `isEnabled()` sincrono.
- Refresh automatico in background con intervallo configurabile.
- Fallback silenzioso su errore nei refresh periodici.
- `EvaluationContext` per targeting per userId e attributi.
- Astrazione `HttpAdapter` per testabilità completa senza rete.
