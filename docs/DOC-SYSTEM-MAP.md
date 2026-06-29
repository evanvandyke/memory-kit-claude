# Documentation System Map  *(blueprint -- promoted to live, in production)*

How the global constitution, the skills (gates), the per-project templates, and the project docs connect -- and **what triggers what**. This is the build reference.

---

## Layer 1 -- the static architecture (who holds what)

```
╔═══════════════════════════════════════════════════════════════════╗
║  CONSTITUTION  (global · never modified · loads in every project)  ║
║                                                                     ║
║  ~/.claude/CLAUDE.md   →  partnership principles, how we work       ║
╚═══════════════════════════════════════════════════════════════════╝
                         │  loaded every session, every project
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│  SKILLS / GATES  (global verbs · act ON the project files below)      │
│                                                                       │
│   /project-setup   creates a project from _SPEC (stamps the templates)│
│   /project-repair  audits + fixes drift against _SPEC (every 5th sess)│
│   /start           opens a session   (absorbs the old /decompress)    │
│   /wrap            closes a session  → calls /compress                │
│   /compress        writes the self-authored handoff note              │
└─────────────────────────────────────────────────────────────────────┘
        │ create / read / update                       │ writes
        ▼                                               ▼
┌────────────────────────────────────────┐   ┌──────────────────────────────┐
│  PER-PROJECT CORE  (the templates       │   │  HISTORY                     │
│  /project-setup writes; instance        │   │                              │
│  per project)                           │   │  Docs_Compressions/*.md      │
│                                         │   │  one note per session,       │
│   CLAUDE.md    project orientation      │   │  written by /compress        │
│   AGENDA.md    the forward-only agenda  │   └──────────────────────────────┘
│   MEMORY.md    long-term memory         │
│   feedback.md  rules learned working    │
└────────────────────────────────────────┘
        │  CLAUDE.md names them as required reading
        ▼
┌────────────────────────────────────────┐
│  CANONICAL DOCS  (project-made, not      │
│  templated; the source-of-truth set)     │
│                                          │
│   README · COMPONENT-MAP · specs ·       │
│   design docs · …  + the CODE itself     │
└────────────────────────────────────────┘
```

**Legend:** *Constitution* = fixed, hand-authored. *Skill* = a global command (a verb). *Template* = a file `/project-setup` stamps out, one instance per project. *Canonical doc* = project-specific source of truth, named in that project's CLAUDE.md.

---

## Layer 2 -- the lifecycle (what triggers what)

```
ONCE per project
  /project-setup ──► writes CLAUDE.md · AGENDA.md · MEMORY.md · feedback.md
                     (or retrofits an existing project's files)

EVERY session
  ┌──────────────────────────────────────────────────────────────────┐
  │ /start  (Evan opens)                                               │
  │   • reads: global CLAUDE → project CLAUDE → AGENDA → MEMORY + feedback → canonical docs │
  │   • post-compact? read the latest compression note FIRST            │
  │   • surfaces parked items from AGENDA relevant to where we resume   │
  └──────────────────────────────────────────────────────────────────┘
                         │
                         ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │ WORK  →  agenda edits happen naturally during the session:          │
  │   • add      route to For Sure / Up Next / Ideas  + capture the why │
  │   • swap     before each new action: delete done Active, write next │
  │   • surface  when a new item becomes Active                         │
  │   • rise     Active done → top *work* slot climbs in (skip Follow-Up) → draw from For Sure │
  │                                                                      │
  │   memory write? run the router + long-term gate, surface it (never silent) │
  └──────────────────────────────────────────────────────────────────┘
                         │
                         ▼
  ┌─ /wrap  (Evan closes the session) ─────────────────────────────────┐
  │   1. prune: delete completed, advance the tiers                     │
  │   2. update CLAUDE.md stable facts (only if a fact changed)         │
  │   3. memory writes per the gate (surfaced)                          │
  │   4. /compress → self-authored note → Docs_Compressions/  (LAST STEP) │
  └─────────────────────────────────────────────────────────────────────┘
```

**/compress is CONTAINED in /wrap (its final step).** Run /compress *standalone* only to (a) relieve context mid-session, or (b) write the note while deliberately skipping wrap's other steps -- e.g. memory is mid-change, like the session that built this map.

---

## Layer 3 -- the router (where every piece of information lives)

The single rule that keeps the docs from drifting into each other:

| If it's… | It lives in… | Tense |
|----------|--------------|-------|
| Forward work: a task, next step, idea | **AGENDA.md** | future |
| A stable orientation fact: client, stack, pricing, a convention | **project CLAUDE.md** | timeless |
| Detail of a component/spec/design, or a technical fact | **canonical doc / the code** | timeless |
| What happened this session | **compression note** | past |
| A behavioral rule learned working together | **feedback.md** | timeless |
| A durable long-term fact about the project or how Evan works | **MEMORY.md** | timeless |

Memory is the *last resort*, not the first: route first, and only what survives lands in MEMORY.

---

## Build status - current vs. target

*Home base / implementation tracker. Keep it honest: a check means "done **at this stage**," and the stages are distinct -- **drafted in BUILD** is not **promoted to live.***

*Promotion now runs in three stages: **BUILD → live → kit** (author in BUILD, promote to Evan's live `~/.claude/`, then generalize into the distributable kit). See the root `README.md` "Promotion flow" section.*

**✅ Design -- complete.** The model is designed and rationalized: the four-tier rising agenda, the two-file memory, the skill split (`SKILL-ARCHITECTURE.md`), the router, the section menu. The origin design and execution sessions (since retired) seeded this; the nuts-bolts prototype migration that proved the model is history now, not active work.

**✅ Drafted in BUILD -- complete.** Every skill and template is a finished new-model draft (verified by the cold-read + a state scout):
- skills: `project-setup` · `project-repair` · `start` (absorbs decompress) · `wrap` · `compress` · `decompress` (retired tombstone) · `agenda` (retired -- absorbed into spec + template)
- templates: `_SPEC` (the authority) · `CLAUDE` · `CLAUDE-SECTIONS` · `AGENDA` · `MEMORY` · `feedback`
- migration: the fleet converted 2026-06-05; `migrate-fleet` retired and trashed 2026-06-11. The folder now holds only two live reference docs (`FAN-OUT-FINDINGS.md`, `FLEET-WORKLIST.md`) pending their queued agenda items.

**Cold-read gaps -- healed pre-promotion** (full triage in `COLD-READ-FINDINGS.md`):
- ✅ **B1** -- `Technical-Compression-Guide.md` banked into `BUILD/dot-claude/` + registered in the README promotion map.
- ✅ **B3** -- RESOLVED: doc-system files are **committed, not gitignored** (Evan's call); policy written into `_SPEC`.
- ✅ **B4** -- on-demand `/project-repair` derives `[N]` from the `Docs_Compressions/` note count.
- ✅ **session-1 cold-read cleared** -- the spec-authority, memory-entry-cap, historical-marking, and vocab nits are all fixed (see `COLD-READ-FINDINGS.md`).
- ✅ **session-2 readiness-gate heal** -- a second cold-read against the promotion gate, all healed 2026-06-04: the consolidate-don't-trash memory behavior, the `Docs_Compressions/` repair-clock holes, and the meta-doc contradictions where these blueprint docs had drifted from the authoritative `_SPEC`/skills (cadence, reading order, the phantom "manifest"). See `COLD-READ-FINDINGS.md`.

**✅ Promotion -- the rollout** (each moved up to live `~/.claude/`, one reviewed file at a time; tracked in root `AGENDA.md`):
- skills promoted; the live `decompress.md` deleted
- `/project-setup` run on this project to stand up its own MEMORY + feedback (dogfood complete)

**⬜ Global `~/.claude/CLAUDE.md` redundancy trim** -- the Subagents/Coach-Mode rename shipped (live + BUILD in sync); the leftover low-priority redundancy cut (the "four checks" dedupe / N3) is staged in `global-CLAUDE-trim-notes.md`. Tracked as the residual-polish item in root `AGENDA.md`; do when convenient.

**✅ Validated fleet-wide** -- the migration dry-run (sluice → aperture-app) cleared, and the whole fleet converted 2026-06-05, stable.
