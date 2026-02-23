TEMPUS, VICTA
Engineering Handoff Document
Status: Active Development – UI Stabilization Phase
Baseline: Signal Ingestion + Voice Tasks Operational + AI Opt-In Functional (Non-Blocking)
________________________________________
1. CONCEPT
Tempus, Victa is a deterministic, local-first life ingestion and routing engine that optionally augments itself with AI, but never depends on it.
It is not a chatbot.
It is not a productivity app.
It is a structured life optimization system.
It ingests:
•	Android Notifications (Signals)
•	Voice Captures
•	Manual Tasks
•	Projects
•	(Planned) Calendar Data
It learns patterns over time and optimizes behavior.
AI is optional augmentation — never required for baseline functionality.
________________________________________
2. CORE PHILOSOPHY
Local > Internet > AI
This is routing priority, not fallback laziness.
It means:
•	Always return the best possible answer within constraints.
•	Escalate automatically from Local → Internet as needed.
•	AI is never in the critical path unless the user explicitly opts in.
________________________________________
Escalation Doctrine (Non-Negotiable)
1. Local (Offline First)
•	Use app-stored knowledge, cached content, and on-device indexes.
•	App must function fully offline:
o	Tasks
o	Recordings
o	Viewing stored signals
o	Projects
•	App knowledge about itself must be available offline.
2. Internet (Always Available, No AI Required)
•	If Local is insufficient, auto-escalate to Internet.
•	WiFi preferred.
•	Mobile data used if no WiFi.
•	External search and lookup must work without AI.
•	Internet must always work even if AI is disabled.
3. Opt-in AI (Augmentation Only)
•	Only if user explicitly enables AI.
•	Used for:
o	Learning
o	Weighing/measuring habits
o	Pattern recognition
o	Classification
o	Optional “AI refine” search button
•	Only call OpenAI when Internet search is insufficient.
•	AI must never block baseline functionality.
Some users may never opt-in.
The app must still feel complete without AI.
________________________________________
3. WHAT WE HAVE DONE
Architecture
•	Modular “Rooms” architecture
•	IndexedStack state preservation
•	Persistent bottom carousel navigation
•	User reorderable modules
•	Room-based isolation
Modules currently implemented:
•	Bridge
•	Signal Bay
•	Tasks
•	Projects
•	Ready Room
•	Daily Brief
•	Recycle Bin
•	Settings
________________________________________
Signal Ingestion (Operational)
•	Android NotificationListenerService
•	Verified via adb logcat -s TVIngest
•	Native buffer merge logic
•	Signal deduplication via fingerprint
•	Count + lastSeen tracking
•	Swipe interactions
•	Acknowledge without disappearance (state-based movement)
Signal States (in progress refinement):
•	Inbox
•	Filed
•	Muted Log
________________________________________
Task System
•	Manual task creation
•	Voice task creation
•	Auto-title from first ~6 words
•	Audio playback
•	Editable titles
•	Swipe left → Recycle
•	Swipe right → Attach to Project
________________________________________
Projects (Jira-Inspired Direction)
•	Search-first layout
•	Project key support
•	Board stub (Backlog / In Progress / Done)
•	Clickable project cards
•	Action tiles
________________________________________
AI (Opt-In)
•	OpenAI integration functional
•	API key stored locally
•	AI enabled toggle
•	Web fallback when AI disabled
•	AI never blocks normal search
________________________________________
Metrics (Local)
Tracked locally:
•	Signals ingested
•	Tasks created (manual)
•	Tasks created (voice)
•	Web searches
•	AI replies
•	Projects opened
•	Signals acknowledged
________________________________________
UI Feel Pass (Partial)
•	Theme system implemented
•	Neon accent introduced
•	Surface components created
•	Header branding: “Tempus, Victa”
However:
•	Light theme currently reads “white + neon highlighter”
•	No Appearance toggle yet
•	Emotional depth not fully achieved
________________________________________
4. WHAT MUST NEVER CHANGE
•	Local-first architecture
•	Offline functionality must remain intact
•	AI must remain opt-in
•	Internet must function without AI
•	AI must never block functionality
•	Signal ingestion must remain deterministic
•	Dedup must increment count, not flood UI
•	Everything visible must be clickable
•	Swipe interactions must be single-motion and fast
•	Busy user UX > feature completeness
•	No heavy configuration inside Signal Bay
•	Signal Bay is triage, not settings
________________________________________
5. WHAT DIDN’T WORK
•	Constructor drift between Room classes and ModuleRegistry
•	Repeated signature mismatches caused patch cascade
•	Theme overrides without Appearance toggle caused visual confusion
•	Neon as primary color overwhelmed subtle professional polish
•	Metrics API drift created compile instability
•	Over-patching instead of stabilizing baseline
•	Small inconsistent changes created cascading errors
________________________________________
6. WHAT WE LEARNED
•	Centralized builder signatures must remain stable
•	Constructor contracts must not drift
•	One baseline freeze prevents patch hell
•	AI routing must be explicit and isolated
•	Color accent ≠ emotional design
•	Subtle hierarchy > loud palette
•	Signals ≠ Tasks (must be state-based)
•	Learning must be phased and permission-aware
•	Escalation logic must be enforced at router level
________________________________________
7. WHAT IS NEXT
User-selected priority order:
2) UI Feel Pass (Primary – For Emotional Attachment)
Goals:
•	Add Appearance toggle (System / Light / Dark)
•	Reduce neon usage to highlight only
•	Improve typography hierarchy
•	Refine surfaces (cards, spacing, subtle texture)
•	Add micro-interactions (acknowledge animation, haptics)
•	Improve empty states
•	Finish Projects board polish
Acceptance criteria:
•	Dark mode toggle works instantly
•	Light mode looks professional (not fluorescent)
•	Jen says: “This looks like a real product.”
________________________________________
3) Signal State Masterpiece
Implement proper triage model:
•	Inbox (Unacknowledged)
•	Filed (Acknowledged but retained)
•	Muted Log (Auto-logged, not surfaced)
•	Vault (Long-term archive)
Add:
•	Keyword-based rule system
•	App-level mute rules
•	Signal importance classification stub (no AI yet)
•	Smooth acknowledge animations
•	Counts preserved on duplicates
________________________________________
1) Calendar Integration
Local-first Android Calendar Provider ingestion:
•	Read-only ingestion
•	Cached locally
•	Queryable offline
•	Enables Ready Room questions like:
o	“What’s on March 2nd?”
o	“Anything going on March 2nd?”
No cloud dependency required.
Google login for profile sync is later and optional.
________________________________________
8. THE ENTIRE PLAN
Phase 1 – Infrastructure (Complete)
•	Rooms
•	Carousel
•	Ingestion
•	Tasks
•	Projects
•	AI toggle
•	Metrics
Phase 2 – Routing Engine
•	Signal → Task → Project chain
•	Escalation enforcement
•	Rule engine
Phase 3 – Optimization Layer (No AI Required)
•	Habit tracking
•	Frequency analysis
•	Dwell time (in-app first)
•	Behavioral weighting
Phase 4 – Internet Layer
•	External search
•	Source weighting (using sources_of_truth)
•	Knowledge indexing
Phase 5 – Optional AI Layer
•	Learning lexicon
•	Response pattern modeling
•	Habit weighting
•	Classification assist
•	“AI refine” search
•	Never mandatory
Phase 6 – Automation Layer
•	Suggestions
•	Auto-routing
•	Workflow optimization
•	Predictive triage
________________________________________
9. USER EXPERIENCE DOCTRINE
•	Everything visible is clickable.
•	Nothing disappears without explanation.
•	Signals move state — they do not vanish.
•	Local must feel complete.
•	AI must feel magical but optional.
•	Internet must feel reliable and fast.
•	No unnecessary configuration in triage views.
•	UI must feel calm, intentional, professional.
________________________________________
10. CURRENT STATUS
•	Build compiling after stabilization
•	Architecture aligned with doctrine
•	AI functional but non-blocking
•	UI partially polished
•	Appearance toggle not yet implemented
•	Signal triage model partially implemented
•	Calendar not yet integrated
System is stable enough to continue.

