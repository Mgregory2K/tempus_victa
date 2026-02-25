# Follow-ups: Lists + Parsing + Jen grocery texts

## What exists after this ZIP
- Real Lists entity store (local-first).
- Lists UI room.
- Bridge voice deterministic list commands:
  - create <list> [add <items>]
  - add <items> to <list>
  - remove <items> from <list>
  - clear <list>
  - show <list>

## What is NOT done yet (explicit follow-up)
1) Share->Auto-parse into Lists
- When Share Sheet ingests text from Messages:
  - detect list-like text (newlines, bullets, commas)
  - propose list name (Grocery / Hardware / Home Depot) deterministically
  - add items into ListStore
- Dev mode should show detected intent + parsed items; user mode remains "magic".

2) Notification listener -> auto-suggestion
- If Jen texts are ingested through notifications:
  - parse best-effort (content may be truncated)
  - show suggestion chip: "Add to Grocery List?"

3) DoctrineEngine integration
- Move parsing into DoctrineEngine intent router so:
  - Ready Room
  - Search
  - Signal Bay (share/notification)
  can all invoke the same routing.

