# Tempus Victa — High-level architecture & data flow

Overview
- Tempus Victa is local-first: user device stores canonical data and handles routing decisions.
- Three escalation tiers: Local -> Internet -> Opt-in AI (external models). Network choice and AI use are policy-driven and user-controlled.
- Every piece of data gets immutable provenance metadata (source, timestamp, transforms, confidence, routing decisions).

Core components
- Ingestion: voice, text, share sheet, notifications, manual entry, import connectors.
- Doctrine engine: intent parser + planner that maps inputs to structured objects (task, project, list, corkboard item, signal).
- Router / Execution planner: applies routing rules, priority weights, constraints and outputs actionable items and side-effects.
- Local Store: encrypted store for items, provenance, user preferences, Twin+ model weights and telemetry.
- Twin+ learning layer: incremental preference model that learns signals, weights, and confidence over time.
- Sync & Escalation: background sync, internet search, and optional AI calls with opt-in gating.
- UI & Actions: task lists, notifications, assistant suggestions, automation flows.

Key data flow (sequence)
1. Input captured (e.g., voice capture). Source metadata logged.
2. Ingestion pipeline normalizes and attaches provenance (raw payload, normalized text, source id, timestamp).
3. Doctrine engine parses intent, produces candidate plans (with confidence scores) and a canonical structured item.
4. Router evaluates candidate plans against local rules, user preferences, and context (time, location, connectivity).
5. If local data suffices, commit to Local Store; else escalate to Internet search; if still insufficient and user opted-in, call AI.
6. Final decision is stored with full provenance; Twin+ receives anonymized/controlled signals to update weights (if user opted-in).
7. UI surfaces action suggestions; user can accept/modify/reject — each action is recorded for provenance and Twin+ feedback.

Design decisions and constraints
- Local-first: all core flows must work offline using Local Store and cached knowledge.
- Privacy-by-default: AI and telemetry are opt-in; provenance and Twin+ training data are controlled and inspectable by the user.
- Deterministic routing: the Router is rule-based with clear precedence; Twin+ only adjusts ranking/weights, not hard rules.
- Small, auditable AI calls: when AI is used, store inputs/outputs and redaction metadata; provide UI to purge or audit calls.
- Provenance model: every object includes origin, transform chain, actor (system/user), confidence, and TTL for ephemeral data.

Mermaid diagram
```mermaid
flowchart LR
  User[User / Device] -->|voice/text/share| Ingest(Ingestion)
  Ingest --> Doctrine[Doctrine Engine]
  Doctrine --> Router[Routing / Planner]
  Router --> LocalDB[Local Store (encrypted)]
  Router -->|needs more info| Internet[Internet Search]
  Internet --> Router
  Router -->|AI-optin| AI[Opt-in AI]
  AI --> Router
  Router --> Actions[UI & Execution]
  Actions --> LocalDB
  LocalDB --> Twin[Twin+ Learning Layer]
  Actions --> Provenance[Provenance Log]
  Twin --> Router
  classDef store fill:#f9f,stroke:#333,stroke-width:1px;
  class LocalDB,Twin,Provenance store;
```

Next steps (recommended)
- Formalize `Doctrine` engine public interfaces (parser input/output, plan representation, confidence schema).
- Define Local Store schema for items, provenance, and Twin+ signals.
- Draft routing rule language (JSON/YAML) and precedence semantics.

File: [docs/architecture.md](docs/architecture.md)
