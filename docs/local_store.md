# Local Store & Provenance Model

Purpose
- Define the canonical on-device storage for structured items (tasks, projects, lists, corkboard items, signals), provenance records, user preferences, and Twin+ signals/weights.

Storage options (recommended)
- SQLite (single-file, ACID) with an encrypted layer (e.g., SQLCipher) — good for relational queries and predictable backups.
- Alternative: embedded document store (LMDB/RocksDB) with JSON columns for high-throughput local writes.

Principles
- Encrypted-at-rest by default; keys held by user-controlled device.
- Immutable provenance records: do not overwrite—append new transform entries.
- Index by `updated_at`, `created_at`, `type`, `status`, and `routing_decision` for fast queries.
- Keep small denormalized views (e.g., `inbox_view`) for UI performance.

Top-level schema (SQL-relational view)
- `items` table — canonical user-facing objects
  - `item_id` TEXT PRIMARY KEY (UUID)
  - `type` TEXT (task|project|list|corkboard|signal)
  - `title` TEXT
  - `body` TEXT
  - `status` TEXT (open|done|archived|snoozed)
  - `metadata` JSON (free-form, e.g., due dates, recurrence, tags)
  - `created_at` TEXT (ISO-8601)
  - `updated_at` TEXT
  - `source_ref` TEXT (provenance id)
  - `last_routing` JSON (rule_id, router_decision, confidence)

- `provenance` table — immutable audit trail
  - `prov_id` TEXT PRIMARY KEY (prov-...)
  - `input_id` TEXT NULL (link to ingestion record)
  - `actor` TEXT (system|user|ai|import)
  - `action` TEXT (ingest|parse|route|commit|modify|delete)
  - `payload` JSON (redacted or full depending on consent)
  - `explain` JSON (tokens from Doctrine/Router)
  - `timestamp` TEXT
  - `consent` JSON (what was allowed to leave device)

- `ingestion` table — raw captures and normalized forms
  - `input_id` TEXT PRIMARY KEY
  - `source` TEXT
  - `raw` BLOB or TEXT (encrypted)
  - `normalized_text` TEXT
  - `metadata` JSON
  - `timestamp` TEXT

- `twin_signals` table — Twin+ incremental signals and deltas
  - `signal_id` TEXT PRIMARY KEY
  - `item_id` TEXT NULL
  - `signal_type` TEXT (click|accept|reject|snooze|modify|complete)
  - `features` JSON (context snapshot used for learning)
  - `weight_delta` REAL (signed)
  - `confidence_before` REAL
  - `confidence_after` REAL
  - `timestamp` TEXT

- `twin_weights` table — compact, queryable model parameters
  - `key` TEXT PRIMARY KEY (e.g., "priority:urgent:weight")
  - `value` REAL
  - `updated_at` TEXT

Example `items` JSON (document form)
```json
{
  "item_id":"item-123",
  "type":"task",
  "title":"Buy dog food",
  "body":"Pick up at local Pet Store",
  "status":"open",
  "metadata": {"due":"2026-03-01T10:00:00-05:00","location":"Pet Store","priority":"medium"},
  "created_at":"2026-02-28T09:34:00Z",
  "last_routing": {"rule_id":"rule-urgent-reminder","router_decision":"route_to:inbox:urgent","confidence":0.86}
}
```

Example `provenance` entry
```json
{
  "prov_id":"prov-123",
  "input_id":"5f8d1e2e-...",
  "actor":"doctrine",
  "action":"parse",
  "payload": {"normalized_text":"buy dog food tomorrow","candidates": ["plan-001","plan-002"]},
  "explain":["parsed_verb:create","detected_object:dog food","datetime:relative"],
  "timestamp":"2026-02-28T09:34:05Z",
  "consent": {"sent_to_ai": false}
}
```

Indexes & queries
- Index `items(type,status,updated_at)`, `provenance(input_id,timestamp)`, `ingestion(timestamp)`.
- Precompute `inbox` and `today` views for fast UI queries; keep them up-to-date via local triggers.

Retention & purge
- Provide user controls: full purge, selective purge (by date, source, AI calls), and automated retention policies (e.g., ephemeral signals older than 90 days).
- When purging items, keep a minimal `provenance` tombstone linking to deletion event (so audits show the deletion occurred) unless user requests full wipe.

Sync considerations
- During sync, only transmit data that user consented to; tag each `provenance` entry with `consent.sent_to_sync` and `consent.sent_to_ai`.
- For conflict resolution use deterministic CRDT-ish strategy: `last_writer_wins` for simple fields but store concurrent edits as separate provenance entries and expose to user for merge where needed.

Security & privacy
- Encryption: use device-bound key material; provide export/import with explicit user passphrase.
- Redaction: before any external call, produce a redacted payload and store both redacted and original locally; only send redacted unless user opts into full-text sharing.
- Transparency: provide UI to view provenance entries and a simple audit timeline for any item.

Operational notes for implementers
- Start with a single encrypted SQLite DB with the above tables; use JSON columns for flexibility.
- Create a small library (TS/Java/Kotlin/Swift) that exposes typed accessors and enforces provenance writes on every state change.
- Provide migration scripts for schema changes and version the DB file.

File: [docs/local_store.md](docs/local_store.md)
