# Legacy.zip import notes

This project includes recovered legacy code under:

- `lib/legacy/data/`
- `lib/legacy/domain/`
- `lib/legacy/services/`

These files are **not yet wired** into the running app to avoid breaking compilation.
They contain richer implementations of:
- ingestion dispatcher + permission gating
- orchestrator/event bus/rules engine skeleton
- learning engine + trust engine + telemetry store
- additional Drift tables (signals, routing_trace, learning_event, lexicon, meta, time_savings, trusted_sources, etc.)
- Ready Room router and other service scaffolding

Legacy user profile JSON/NDJSON are copied to:
- `assets/legacy_user_profiles/`
and referenced in `pubspec.yaml` as assets.

Next wiring targets (safe order):
1. Replace current lightweight `lib/services/learning/learning_engine.dart` with a wrapper that can optionally call legacy `lib/legacy/services/learning/learning_engine.dart`
2. Promote legacy tables into the canonical DB (requires Drift rebuild if you choose Drift; current app uses sqflite).
3. Migrate ingestion to use legacy `permission_gate` + `ingestion_dispatcher` while preserving current Android intent entrypoints.

