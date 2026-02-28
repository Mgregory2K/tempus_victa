# Doctrine Engine — interfaces, plan representation, and routing rules

Purpose
- Define the contract between ingestion -> Doctrine -> Router so parsing, planning, and routing are auditable and testable.

1) Parser input (normalized)
- Fields provided to the Doctrine parser:
  - `input_id`: string (UUID)
  - `source`: enum {voice, text, notification, share, import, manual}
  - `raw`: string (original payload)
  - `normalized_text`: string (post-transcription/normalization)
  - `metadata`: object (device, app, locale, location?, connectivity)
  - `timestamp`: ISO-8601

2) Parser output — CandidatePlans container (JSON)
- Top-level shape (array of candidate plan objects), Doctrine returns ordered candidates with explainability tokens and a confidence score.

Example candidate plan (JSON)
```json
{
  "input_id": "5f8d1e2e-...",
  "candidates": [
    {
      "plan_id": "plan-001",
      "intent": "create_task",
      "confidence": 0.86,
      "entities": {
        "title": "Buy dog food",
        "when": "2026-03-01T10:00:00-05:00",
        "location": "Pet Store"
      },
      "priority": "medium",
      "actions": [
        {"type": "create_task", "target_list": "inbox"}
      ],
      "explain": ["parsed_verb:create","detected_object:dog food","datetime:explicit"],
      "provenance_ref": "prov-123"
    },
    {
      "plan_id": "plan-002",
      "intent": "add_to_shopping_list",
      "confidence": 0.45,
      "entities": {"item":"dog food"},
      "actions": [{"type":"add_to_list","list":"shopping"}],
      "explain": ["lower_confidence:partial_phrase"],
      "provenance_ref": "prov-123"
    }
  ]
}
```

Fields explanation
- `intent`: normalized intent token
- `confidence`: [0..1] aggregate score (parser + heuristics)
- `entities`: slot map (strings, timestamps, structured objects)
- `actions`: canonical action sequence (see Action Types below)
- `explain`: tokens used for UI audit and Twin+ learning signals
- `provenance_ref`: pointer to ingestion provenance entry

3) Action Types (canonical)
- `create_task` {title, description?, when?, due?, listId?, priority?}
- `create_project` {title, description?, members?}
- `add_to_list` {list, item}
- `create_corkboard_item` {title, body, tags?}
- `set_reminder` {at, repeat?}
- `search` {query, scope?}
- `signal` {type:read|dismiss|snooze, reason?}
- `execute_workflow` {workflow_id, params}

4) Plan confidence & gating
- The Doctrine returns ranked candidates. Router will accept the top candidate if `confidence >= local_threshold` (default 0.7). Otherwise Router may:
  - consult Local Store for disambiguation
  - escalate to Internet search
  - ask the user inline (confirmation)
  - if authenticated opt-in AI allowed, call AI to expand candidates

5) Routing rule language (JSON rule example)
- Rules are deterministic and evaluated in decreasing `priority`. Each rule has a `condition` and `effect`.

Example rule
```json
{
  "rule_id": "rule-urgent-reminder",
  "priority": 100,
  "condition": {
    "intent": "create_task",
    "entities.priority": "urgent",
    "connectivity": "any"
  },
  "effect": {
    "route_to": "inbox:urgent",
    "notify_immediately": true,
    "set_confidence_override": 0.95
  }
}
```

Condition operators
- equality, exists, regex, numeric ranges, time-of-day, location proximity, connectivity state (offline/wifi/cellular), boolean flags (user_present).

Effect operations
- `route_to` (destination), `escalate_to` (Internet|AI), `set_priority`, `attach_tag`, `defer`, `ask_user` (confirmation prompt id), `block` (suppress auto-commit).

6) Rule precedence & deterministic application
- Rules evaluated by descending `priority` number. The first matching rule with a terminal effect (e.g., `block`, `route_to` without further conditions) stops evaluation. Non-terminal effects can accumulate (e.g., `attach_tag` + `set_priority`).

7) Explainability hooks
- Doctrine must output `explain` tokens and the Router must log which rules fired. All explain data is stored in provenance so users can audit decisions.

8) TypeScript-like interfaces (reference)
```ts
interface DoctrineInput {
  input_id: string;
  source: 'voice'|'text'|'notification'|'share'|'manual'|'import';
  raw: string;
  normalized_text: string;
  metadata?: Record<string, any>;
  timestamp: string;
}

interface CandidatePlan {
  plan_id: string;
  intent: string;
  confidence: number;
  entities: Record<string, any>;
  actions: Array<{type:string, [k:string]: any}>;
  explain?: string[];
  provenance_ref?: string;
}

interface DoctrineOutput { input_id: string; candidates: CandidatePlan[] }
```

9) Testing & validation
- Unit tests should verify: deterministic parsing on stable inputs, candidate ranking reproducibility, gating thresholds, and routing rule precedence.
- Record seed inputs and expected outputs in `tests/data/doctrine/` for regression tests.

10) Security & privacy notes
- Doctrine must never send raw user data outside device without explicit opt-in; any external calls must be logged with redaction metadata and user consent status attached.

File: [docs/doctrine.md](docs/doctrine.md)
