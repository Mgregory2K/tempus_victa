# Voice Command Follow-ups (Bridge / global)

## Implemented in this ZIP (Bridge only)
- Default: creates a **Task** with:
  - `title` = first ~6 words
  - `transcript` = **full voice text** (editable later in Task UI)
  - `audioDurationMs` captured from the unified `VoiceService`

- Simple routing rules (best-effort, deterministic fallback):
  - **Corkboard**: phrase contains `cork it` or `corkboard`
    - Creates cork note via `CorkboardStore.addText(...)`
  - **Projects**: `create project <name>`
    - Creates project via `ProjectStore.addProject(...)`
  - **Lists**: if voice mentions creating a list (grocery list etc.)
    - Not implemented (no list system exists yet) → falls back to Task tagged `[LIST REQUEST]`
  - **Reminders**: phrases containing `remind` / `reminder`
    - Not implemented (no scheduler exists yet) → falls back to Task tagged `[REMINDER REQUEST]`

## Next required additions (planned)
1. Lists module:
   - Data model + store (items, checked state)
   - UI room
   - Indexing into UnifiedIndexService
   - Voice grammar:
     - `Create <list name> add <item1>, <item2>, ...`
2. Reminder / timer / scheduling:
   - Local notifications + alarm scheduling
   - Task fields: dueAt / remindAt
   - Voice grammar:
     - `... set reminder for 1 hour`
3. Full multi-action command graph:
   - Turn parsed commands into DoctrineEngine “Plans”
   - Surface plan in Dev Mode; “magic” in user mode
