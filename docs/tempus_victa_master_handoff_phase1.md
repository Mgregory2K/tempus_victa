TEMPUS VICTA
Master Project Charter + System Doctrine + Architectural Blueprint
Post Phase 0 Completion
Version: 1.0 (Authoritative Handoff)
________________________________________
0. CURRENT STATE SUMMARY
Phase 0 — COMPLETE
Validated:
•	Deterministic Flutter build
•	Deterministic emulator boot
•	DirectBoot-safe NotificationListenerService
•	Local JSONL persistence
•	Emulator ↔ host networking (10.0.2.2)
•	FastAPI backend health endpoint
•	200/202 handling
•	Restart survivability
•	Offline-first operation
•	No hacks
•	No feature creep
•	Silence-by-default preserved
Infrastructure is stable.
We now move to user-surface validation.
________________________________________
1. WHAT TEMPUS VICTA IS
Tempus Victa (Latin: Time Conquered)
It is:
•	A Regret Minimizer
•	A Time Consolidation Engine
•	A Personal Executive System
•	A Local-first Orchestration Layer
•	A Cognitive Load Reducer
•	An Automation Infrastructure
It is NOT:
•	A chatbot
•	A productivity clone
•	A SaaS dashboard
•	A task manager clone
•	A logistics marketplace
•	A surveillance system
•	A delivery company
•	Uber
•	Instacart
•	Clippy
•	A Palm Pilot
It is orchestration + governance + optimization.
AI is a tool.
Deterministic logic is the constitution.
________________________________________
2. CORE PHILOSOPHY
Silence by Default
Tempus does not talk unless:
•	Delta > threshold
•	Hard constraint violated
•	Risk detected
•	User explicitly asks
Confidence & Trust (C/T)
Automation is gated by:
•	Source authority
•	Historical reversals
•	Risk domain
•	Sensitivity level
Local First
•	All primary data stored locally
•	App must function offline
•	Sync is enhancement, not requirement
•	No internet = no crash
Working > Pretty
But:
Minimum coolness is non-negotiable.
Lean architecture.
Premium presentation.
________________________________________
3. GOVERNANCE MODEL
Authority Tiers
Tier 0 – Non-authoritative
Spam, unknown senders, marketing.
Never auto-create tasks.
Tier 1 – Soft influence
Friends, coworkers.
May generate suggestions.
Tier 2 – Trusted (Jen-level)
Can:
•	Create Grocery items
•	Create Tasks
•	Influence scheduling
•	Populate Corkboard
•	Suggest calendar changes
Still bounded by:
•	Safety constraints
•	Financial guardrails
•	Hard calendar conflicts
Tier 3 – Self
Immediate execution.
No friction.
________________________________________
Abuse Protection
•	Spam clustering detection
•	Auto-block high-confidence spam
•	Surface in Executive Brief only
•	Silent correction on misfire
•	No mid-day alerts
________________________________________
Founder “God Mode”
Includes:
•	Feature flags
•	Threshold tuning
•	Autonomy gating
•	Deterministic replay
•	Simulation mode
•	Kill switch
•	Abuse detection metrics
Does NOT include:
•	User content visibility
•	Contact graph visibility
•	Location tracking visibility
•	Data surveillance
Ethical boundary is absolute.
________________________________________
Threat / Self-Harm Governance
•	Detect credible self-harm language
•	Distinguish implied humor vs credible risk
•	Escalate only when threshold crossed
•	Never overreact to obvious humor
•	No false crisis spam
________________________________________
4. SYSTEM ARCHITECTURE
Layers
Layer 1 – Ingestion
•	NotificationListener
•	Manual input
•	(Future: Email, Call metadata)
Layer 2 – Local Store
•	JSONL or SQLite
•	Deterministic persistence
•	Survives reboot
•	Survives offline
Layer 3 – Classification
•	Deterministic parsing first
•	Entity extraction
•	Negation detection
•	Ambiguity markers
Layer 4 – Authority Filter
•	Source-level filtering
•	Not keyword filtering
Layer 5 – State Mutation
•	Grocery
•	Tasks
•	Corkboard
•	Calendar suggestions
Layer 6 – Optimization Engine (Later)
•	Time windows
•	Route consolidation
•	Impact scoring
•	Bullshit avoided metric
Layer 7 – Executive Brief
•	Daily summary
•	Delta reporting
•	Silent system review
•	Spam summary
•	Reversal log
________________________________________
5. PHASE ROADMAP (LOCKED ORDER)
1.	Grocery Automation
2.	Corkboard Capture Engine
3.	Text Ingest Automation
4.	Tasks + Buckets (Hot/Cool/Cold/Archive)
5.	Email Ingest
6.	Calendar Consolidation
7.	Executive Brief
8.	Wins & Worries
9.	Map + Location Optimization
Horizontal expansion only after module satisfaction.
________________________________________
6. PHASE 1.0 (CURRENT TARGET)
Deliver minimal installable UI shell:
Required Screens
•	Today (Status + Quick Access)
•	Signals (Ingest Log)
•	Event Detail
•	Corkboard
•	Settings
Acceptance Tests
1.	Cold reboot persistence
2.	Offline survivability
3.	Backend indicator accuracy
4.	Export logs functional
No feature creep.
No AI.
No grocery logic yet.
________________________________________
7. GROCERY MODULE (Phase 1.1)
Scope:
•	Ingest chaotic text
•	Extract grocery items
•	Deduplicate
•	Detect negation
•	Sort by store section
•	Mark ambiguity
•	Persist locally
•	No auto-replies
Ambiguous items are added with marker.
________________________________________
8. DOPAMINE MODEL
User-facing:
•	Quiet success
Founder-facing:
•	Pizza & whiskey celebration
No visible automation theater.
________________________________________
9. DESIGN DOCTRINE
Style:
Executive Tactical Minimalism
Modes:
•	Dark tactical
•	Light Azure
Requirements:
•	Token-based theme
•	High contrast
•	Elevation hierarchy
•	Accent color = meaning only
•	Focus state changes weight + border + elevation
•	No generic nonsense UI
________________________________________
10. API COST DISCIPLINE
Routing hierarchy:
1.	Deterministic logic
2.	Local cached knowledge
3.	Public dataset
4.	LLM (BYO key)
LLM:
•	User-provided API key
•	Visible usage
•	Hard caps
•	Throttle controls
•	Kill switch
•	lmgtfy mode for trivial queries
No stealth compute bills.
________________________________________
11. MAP STRATEGY (FUTURE)
•	OpenStreetMap
•	Offline tile caching
•	Local routing
•	Minimal API usage
•	No Google dependency required
Maps integrate after:
•	Tasks
•	Calendar
•	Grocery proven
________________________________________
12. CALL & EMAIL INGEST (FUTURE)
Start with:
•	Metadata only
•	No transcript
•	Spam clustering
•	Suggestion-based actions
Never:
•	Auto-transcribe everything
•	Store raw audio
•	Burn compute unnecessarily
________________________________________
13. ADHD SUPPORT SYSTEMS
Corkboard
Default capture.
Everything goes here.
Quote Board
Triggered by:
•	Explicit “quote” language
•	Self-referential irony
•	Best-effort highlight
Auto-promote on trigger.
Editable later.
Buckets
Hot
Cool
Cold
Archived
Only one “active day” at a time.
________________________________________
14. EXECUTIVE BRIEF MODEL
On request:
•	Today’s calendar
•	Open grocery items
•	Task summary
•	Unanswered texts count
•	Spam summary
•	System changes
•	Optional next actions
Never:
•	Over-summarize
•	Remove nuance
•	Skip context unless told “crucial”
________________________________________
15. SECURITY & ABUSE MITIGATION
•	Throttle API abuse
•	Kill heavy compute sessions
•	Detect runaway token burn
•	Prevent spam griefing
•	No phone-tree stalking
•	No Kevin Bacon graph abuse
________________________________________
16. PERSONAL DOCTRINES
•	Working > Pretty (but never ugly)
•	Lean like Rocky III
•	No overbuild infrastructure
•	No premature scaling
•	No microservices until required
•	No cloud dependency
•	Horizontal growth after satisfaction
•	Silent correction preferred
•	D (fix and move on) is default
________________________________________
17. WHAT TEMPUS IS ULTIMATELY BUILDING
Not tasks.
Not lists.
Not reminders.
Tempus builds:
Contiguous time blocks.
Reduced noise.
Lower anxiety.
Relationship friction reduction.
Cognitive outsourcing.
A bro that just handles it.
________________________________________
18. FINAL STRATEGIC POSITION
If this never makes money:
It is still worth building.
If it helps only Michael:
It is still successful.
If it scales:
It must scale ethically and lean.
________________________________________
19. NON-NEGOTIABLES
•	Offline must always work
•	Restart must always work
•	Data must remain local-first
•	Founder cannot see private data
•	No silent surveillance
•	No spam escalation
•	No feature creep
________________________________________
20. CURRENT STATE
Phase 0: Complete
Phase 1.0: UI Shell in progress
Design direction: Confirmed
Governance: Defined
Architecture: Defined
Cost discipline: Defined
Authority model: Locked

