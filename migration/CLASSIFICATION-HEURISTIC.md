# NOW → AGENDA Classification Heuristic

How a migration agent places old NOW.md content into the new system at ~80-90% confidence, leaving [USER_NAME] a short residual review. Derived from four real NOW.md files (project-alpha, project-beta, project-gamma, project-delta).

## The premise: section headers do most of the work
You do NOT need to deeply understand every line. A NOW.md self-sorts by its own headings. Map each section's heading to an archetype, route it, drop the noise, and only forward items reach the agenda. Then rank within the forward items using done/tense markers.

## Step A — Section archetype → destination

| Heading looks like… | Archetype | Goes to |
|---|---|---|
| Open Threads · What's Next · Priorities · Build Queue · Follow-Ups · Active/In Flight · Queued · Deferred | **forward work** | AGENDA (tier by Step B) |
| Completed · Resolved This Session · SHIPPED · Done · Build Log · Sessions 1-N · Last Session · ✅ · ~~struck~~ | **history** | DROP (compression note if genuinely worth keeping) |
| Architecture · Current State · Where X Stands · Stack Snapshot · Mission · Live Operational Facts · Key Paths · Source-of-Truth Pointers | **stable facts** | a canonical doc (architecture/specs) or CLAUDE *Project overview* for orientation — never the agenda |
| Open Questions · Open Design Questions | **decisions** | "we decided X" → a canonical doc (decisions live there); "we must decide X" → AGENDA (FOR SURE/IDEAS) |
| Recurring Schedule · Recurring Rhythm | **session ritual** | DROP — `/start` and `/wrap` own this now. Project-specific recurring task → a CLAUDE note. |
| `{{placeholder}}` · empty templated sections | **scaffolding** | DROP |

**Stable-facts rule — conflicting sources:** when sources disagree on a stable fact (e.g. README says one stack, code/`package.json` says another), **code wins** (the global "code is the source of truth" principle). Route the *correct* fact to CLAUDE.md and add a "not what you'd assume" correction; note the stale source for a separate fix (outside the migration's lane — don't fix it here).

**Deliberate wins / milestone log — a named route, NOT episodic trash.** A `trophy_case.md` (or similar "wins log, read at session start") parked in the memory safe-dir is a recurring pattern: an intentional ritual doc, built on purpose. It is **not** episodic clutter to flag as a husk and discard. **Preserve it** — relocate it to `Docs_Compressions/` (it's a kept record, akin to a compression note) or note it in CLAUDE.md as a kept ritual doc — then flag the safe-dir husk for [USER_NAME] to delete once it's relocated; the agent never deletes files itself. This is **distinct from the design-doc third route** (which lands in `Docs_Dev/`/`Docs_Design/`): a wins log isn't a spec, it's a ritual, so it goes to compressions, not dev docs.

## Step B — Within forward work, place into tiers

| Tier | Signal |
|---|---|
| **ACTIVE** (1) | Labeled in-progress/in-flight AND not stamped shipped/done. If none is clearly current, propose the most-likely "resume this" item and flag it low-confidence. May legitimately be empty post-migration. **Tiebreak — severity vs (priority) on different items:** when a severity signal (🚨 CRITICAL / "users can't trust the app" / broken primary path) and an explicit "(priority)" tag land on *different* items, default to severity → ACTIVE, the "(priority)" item → UP NEXT #1. Always flag this specific call in the review so [USER_NAME] can swap them. |
| **UP NEXT** (≤3, ordered) | Numbered "what's next" lists — their existing order IS the ranking. Plus items with "unblocks / blocking / when X then Y" urgency. Take the top 3. **When forward work is an *unranked* bullet list (no numbering), you have to infer the order: 🚨 CRITICAL / "blocking" / broken-primary-path items first, then explicit "(priority)" tags, then concrete self-contained fixes, then the rest. Flag the inferred order as a low-confidence call in the review — the order is your read, not the file's.** |
| **WAITING** (a held UP NEXT slot) | Blocked on a **third party**: "pending / awaiting / carrier registration / client / vendor / approval." Out of [USER_NAME]'s hands. **Qualifier (avoid false-positives):** WAITING is ONLY a tracked, outstanding, third-party ask you've **actually sent** — not any appearance of "waiting/pending." "Waiting on a friend to decide" about a maybe-feature → IDEAS, not WAITING. |
| **FOR SURE** (unordered) | Committed but not scheduled: "Queued / Deferred / Follow-ups" beyond the top 3. Bugs/dragons that are real and will be fixed. |
| **IDEAS** | "Future / Not Now / parked / paused / passion project / maybe / could / worth exploring." |

**Conflicting session blocks — the newest-dated forward signal wins.** A NOW.md often carries a stale "next suggested prompt" / "#1 PRIORITY" line from an older session that the newest session block contradicts (e.g. Session 16's job that Session 17 then shipped, vs Session 17b's new job). **Trust the newest-dated forward signal** and place it; treat the older one as superseded. Don't silently pick — **flag the conflict** in the review so [USER_NAME] can confirm you trusted the right date.

## Step C — Drop rules (the noise)
- Any forward-section item stamped **SHIPPED / DONE / ✅ / ~~struck~~ / a commit hash** = history. Drop it even though it sits in a "priorities/active" section. (project-beta's entire "Active / in flight" is shipped items — all drop.)
- Incident post-mortems and multi-paragraph debugging archaeology = history. Drop. (project-alpha's Atlas-timeout and in-app-browser write-ups: keep only the one-line *remaining* fix as a forward item; drop the saga.)
- Empty `{{templated}}` sections. Drop.
- Keep each surviving item's **why** (one line).

## Step D — Decompose projects
An item too big for one ~50k-token slice becomes a FOR SURE project header with action bullets, not a single agenda line. (project-alpha's "Receptionist product" pointer = a sub-project header, possibly its own AGENDA.)

## Step E — The review output (so [USER_NAME] reviews only the residual)
Per project, write `MIGRATION-REVIEW.md` next to the new AGENDA, low-confidence first:

```
# Migration Review — [project]

## Needs your eyes (low confidence)
- ACTIVE pick: [item] — why I chose it / why unsure · source: [NOW.md line]
- Tier call: [item] — UP NEXT vs IDEAS? · source: [line]
- Decision vs task: [open question] — routed to [dest], confirm

## Did automatically (skim)
- Dropped as history: [N items / sections]
- Routed to canonical docs / CLAUDE: [list]
- Placed: ACTIVE [1] · UP NEXT [n] · WAITING [n] · FOR SURE [n] · IDEAS [n]
```

## Step F — The SETUP path (no NOW.md)

Steps A–E assume a NOW.md exists to self-sort. **Most projects have none** — but the forward work still exists, parked in old-world carriers. Don't stamp an empty scaffold:

- **Mine the carriers for forward work:** `TODO.md` (root or nested), `START_SESSION.md`/`END_SESSION.md`, `ACTION_PLAN.md`, `FUTURE-*.md`, `pending-implementation.md`, the **newest** compression note's "Immediate Next Steps", and any forward-work design doc in the memory safe-dir (the third-route doc can be the *source* of the seed — relocate it AND seed from it). Tier these by Step B exactly as you would NOW.md sections.
- **Reconcile against code before placing tiers — code wins.** A carrier is history; the code is truth. Long-idle projects (Jan-2025 ACTION_PLANs, 7-month-old compression notes) have "broken" items later commits already fixed and "next" items already shipped. Cross-check every seeded forward item against current code + recent `git log`; demote what's done, mark unconfirmable items "verify first." Banner a fully-inferred AGENDA as seeded-not-yet-confirmed.

## MEMORY.md is usually present-but-wrong-shape, not missing

Expect a pre-spec `MEMORY.md` to **exist** but be the **wrong shape**, not absent. The recurring shapes:
- the harness **index / one-file-per-fact** shape (a MEMORY.md that's just links to per-fact files — the convention this system overrides; passes a filename check, violates the two-file model),
- an old **"How to Use This File"** header instead of the current router/gate/NO-SILENT-WRITES header,
- a **code-mirror** (line numbers, array names, volume levels) exceeding the route-first/250-char discipline,
- a **doc-mirror** duplicating CLAUDE's canonical-docs list as its own "Source of Truth" section (drop that section, don't merge it).

The most common cleanup is **trimming MEMORY.md in place** to the current gate header — NOT merging stragglers. Trimming produces no husk to flag; the straggler-merge case (extra files to consolidate) is the exception, not the norm.

## feedback.md vs MEMORY.md — the tiebreak

A "how [USER_NAME] works" / working-preference fact (e.g. "trusts overnight builds") **defaults to MEMORY.md** per the route table. It goes to `feedback.md` **only** if it's a behavioral rule *earned with a why* (a correction you arrived at together). When in doubt, MEMORY.md.

## Worked examples (from the real files)
- **project-gamma** — "Open Threads" #1 fix-UI-mapper → UP NEXT; #2 when-10DLC-registers → WAITING (carrier); #3/#4 → UP NEXT/FOR SURE; "Deferred" → FOR SURE/IDEAS; "Current State / Mission / Live Operational Facts / Source-of-Truth Pointers" → CLAUDE. Cleanest case.
- **project-beta** — "Where Project-Beta stands" + "Stack snapshot" → CLAUDE; "Priorities" keep only the *not-yet-built* sub-bullets → FOR SURE; "Active / in flight" → nearly all SHIPPED → DROP; "Queued" → FOR SURE/IDEAS; "Known dragons" → FOR SURE; "Open questions (carried)" → IDEAS/CLAUDE. Heavy history-drop.
- **project-alpha** — "Build Queue" #1 interstitial → UP NEXT (drop the incident paragraphs); empty `{{Upcoming Builds / Architecture / Completed}}` → DROP; "Parked side projects / Receptionist" → FOR SURE project header (or its own AGENDA). Heavy scaffolding-drop.
- **project-delta** — "Real Follow-Ups / type-drift bugs" → FOR SURE; "Resolved This Session / Completed Today" → DROP; "Future Session Items" → FOR SURE/IDEAS; "Queued (Not Now) Family Workspace" → IDEAS; "Stale Docs" cleanup list → FOR SURE; "Architecture / Supabase" → CLAUDE/canonical.
