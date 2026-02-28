# Privacy, Opt-in AI, Sync, and Network Escalation

This document captures the policies, data transformations, and technical controls that enforce Tempus Victa's local-first, privacy-by-default model while enabling safe, auditable escalation to Internet search and optional AI services.

Principles
- Privacy-by-default: no raw user data leaves the device unless explicitly consented. All AI/telemetry is opt-in.
- User control & transparency: every external call (sync or AI) is logged in provenance with redaction metadata and user-visible audit trails.
- Minimal external surface: prefer redacted payloads and structured signals rather than free text where possible.
- Deterministic gating: network escalation paths are deterministic rules evaluated by Router with user policy overrides.

Consent model
- Consent is modeled per capability and scope; stored in `consent` settings with timestamp and scope.
- Scopes:
  - `sync:full` — full item sync to user's cloud account (encrypted in transit)
  - `sync:metadata` — sync metadata and provenance only
  - `ai:full` — full-text AI calls
  - `ai:redacted` — AI calls with redacted payloads
  - `telemetry:usage` — anonymous usage telemetry
- Consent record JSON example:
```json
{
  "consent_id":"consent-001",
  "scope":"ai:redacted",
  "granted":true,
  "granted_at":"2026-02-28T10:00:00Z",
  "via":"settings_ui",
  "notes":"Opted into redacted AI calls only"
}
```

Redaction rules
- Before any external call, construct a redacted payload and store both redacted and original locally.
- Redaction pipeline steps:
  1. Replace PII (names, emails, phone numbers) with stable opaque tokens (deterministic hashing with device key).
  2. Remove embedded attachments unless user allowed `sync:attachments`.
  3. Replace long free-text with structured entity summaries when available (e.g., {"title":"Buy dog food","when":"2026-03-01"}).
  4. Attach provenance_ref and redaction metadata: which fields were redacted and why.

Redaction payload example
```json
{
  "prov_id":"prov-123",
  "redacted": true,
  "redacted_fields": ["raw","body","attachment_1"],
  "payload": {"title":"Buy dog food","when":"2026-03-01"}
}
```

Network Escalation policy (Local -> Internet -> AI)
- Router evaluates candidate plans and applies escalation logic:
  - If `confidence >= local_threshold` -> commit locally.
  - Else if `local_data_available_to_disambiguate` -> consult Local Store.
  - Else if `connectivity==offline` -> ask user or queue for later.
  - Else run Internet search (if `policy.internet_allowed`), using redacted query first.
  - If Internet results insufficient and `consent.ai` allows, call AI (redacted or full per consent scope).
- Edge cases:
  - If user is on metered cellular and `policy.wifi_only_for_ai` is true, postpone AI until WiFi.
  - If AI provides a high-risk action (e.g., changing account settings), always require user confirmation.

Sync model
- Two sync modes:
  - `full-sync`: encrypted full-item sync for backups across devices (requires `sync:full`).
  - `meta-sync`: synchronize metadata, provenance records, and Twin+ compact model parameters (requires `sync:metadata`).
- Sync transfer rules:
  - Always encrypt in transit and at rest on server side; local encryption keys remain device-bound unless user opts to export.
  - Track `consent.sent_to_sync` per provenance entry.
  - Use incremental sync with sequence tokens; mark conflicts with provenance entries and present merge UI.

Auditability & user UI
- For every external call (search, AI, sync), store a provenance entry containing:
  - `prov_id`, `input_id`, `actor` (system/ai/sync), `action` (sent/received), `consent` snapshot, `redaction` snapshot, `timestamp`.
- UI features:
  - Audit timeline per item showing parse -> routing -> external calls -> user decisions.
  - Consent manager listing each scope, when granted, and ability to revoke.
  - Redaction inspector showing what was removed before external calls.

Security controls
- Key management: prefer device-kept keys (Secure Enclave/Android Keystore). Support explicit passphrase export/import.
- Network: validate TLS, pin certificates for first-party sync endpoints if applicable.
- Rate-limiting: throttle AI calls and require manual confirmation after repeated escalations for the same input.

Developer APIs (examples)
- Create redacted payload (JS/TS pseudo):
```ts
function buildRedactedPayload(item, provenance, consent) {
  const payload = {};
  if (consent.scope === 'ai:redacted') {
    payload.title = item.title;
    if (item.metadata?.due) payload.when = item.metadata.due;
    return { prov_id: provenance.prov_id, redacted: true, redacted_fields: ['raw','body'], payload };
  }
  // fallback full payload
  return { prov_id: provenance.prov_id, redacted: false, payload: item };
}
```

- Sync gating example (pseudocode):
```py
if plan.confidence >= local_threshold:
  commit_local(plan)
else:
  if connectivity == 'offline':
    queue_for_later(plan)
  else:
    redacted = build_redacted(plan.item, prov, consent)
    results = internet_search(redacted)
    if results.sufficient():
      commit_with_results(results)
    elif consent.ai_allowed:
      ai_payload = (consent.ai_full ? full_payload : redacted)
      ai_reply = call_ai(ai_payload)
      commit_with_ai(ai_reply)
    else:
      ask_user_for_clarification()
```

Retention, purge & legal considerations
- Provide user controls to purge sync server copies and revoke consent; follow strong deletion semantics but keep local tombstones for audit unless user requests full wipe.
- When user revokes AI consent, stop future AI calls and optionally provide a tool to remove prior AI-derived model weights and external logs (subject to server-side provider policies).

Testing & validation
- Add unit tests validating redaction pipeline, consent gating, and escalation flows.
- Include integration tests simulating offline, wifi, and cellular conditions and measuring correct gating behavior.

Next steps
- Implement client-side redaction library used by Router before any external call.
- Add Consent manager UI and provenance audit viewer.

File: [docs/privacy_sync.md](docs/privacy_sync.md)
