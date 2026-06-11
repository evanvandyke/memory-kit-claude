# How It Works

This is the master guide to the system's architecture and mechanics. It assumes you've already installed the kit and want to understand what's running under the hood.

## 1. The Two-File Memory Model

Every project gets exactly two memory files: `MEMORY.md` and `feedback.md`. That's it. No third file, no per-fact file, no category splits. The constraint is the feature.

### MEMORY.md: durable facts only

Before saving anything to memory, Claude routes it through a decision table:

| If it's... | It goes to... |
|------------|---------------|
| Forward work (a task, a next step, an idea) | the **agenda** (`AGENDA.md`) |
| A technical fact (a class name, a config value) | the **code** (or a comment in it) |
| A detail covered by a canonical doc | that **canonical doc** |
| What happened this session | the **compression note** |
| A behavioral rule earned together | **feedback.md** |

Most "I should remember this" impulses belong somewhere else. The routing table catches them before they pollute memory.

What survives routing hits the quality gate:
- **Is it long-term?** Still true in 10+ sessions, or for the rest of the project? If not, it's episodic and belongs in a compression note.
- **Is it a real fact about the project or the user?** If yes, and it survived routing, it's memory. If not, skip it.

The default answer is NO. When unsure, it is not memory. Every write is surfaced aloud ("saving to long-term memory: ___"), never silent. Each entry stays under 250 characters. The file is read in full at every session start, so it stays useful only if it stays lean.

### feedback.md: behavioral rules earned together

This is the other file. It holds corrections and confirmed approaches, the lessons you and Claude earned by working together. Not principles you brought (those live in the global `~/.claude/CLAUDE.md`), but rules that emerged from the collaboration.

The format is strict by design:
- A flat numbered list. No category headers, no sub-files.
- Each entry is 150 characters max, forward-posture framed (what TO do, not what went wrong).
- No `Why:` narrative lines. The reasoning folds into the rule itself.
- Max 15 entries. A 16th forces dropping one, surfaced and discussed, never silent.
- Purge priority: graduated-to-global (already in `~/.claude/CLAUDE.md`), then superseded, then least applicable.

### Why two files

Claude Code's default creates a new file for every fact. With no consolidation and no dedup, contradictions accumulate silently. The two-file model flips the lever: instead of controlling the file count after the fact, it gates what gets saved in the first place. One curated file you actually read beats twenty files you skim past. The gate keeps quality up. The repair cycle catches any leakage.

## 2. The Forward-Only Agenda

`AGENDA.md` is the work tracker. It's a rising priority column: work enters at the bottom and rises as it earns priority until it gets done, then it's deleted.

### The four tiers

Read top to bottom, hottest to coldest:

| Tier | Limit | What it holds |
|------|-------|---------------|
| **ACTIVE** | 1 | The one thing you're working on right now. |
| **UP NEXT** | 3 total | The next few, ordered. FOLLOW-UP lives inside this limit (see below). |
| **FOR SURE** | unlimited | Committed work, not yet scheduled. Unordered. |
| **IDEAS** | unlimited | Someday, maybe. |

The rise: `IDEAS → FOR SURE → UP NEXT → ACTIVE → done (deleted)`.

### Forward-only means forward-only

Completed items are deleted, not archived, not struck through, not moved to a "done" section. The agenda is what's ahead, never what's behind. Session history lives in the compression notes.

### FOLLOW-UP

When work is blocked on a third party (a client, a vendor, an approval), one of UP NEXT's three slots becomes a FOLLOW-UP block. Two work slots plus one FOLLOW-UP when something's blocked, three work slots when nothing is. Spending a scarce slot on blocked work is deliberate: it keeps follow-ups visible instead of letting them drift out of sight.

Each blocker carries: who, the last sent ask (date and reference), and the last nudge. The clock runs from the last *sent* contact, never a draft or an intention. If three business days pass without movement, Claude surfaces it proactively at the next session start: "you last reached out X days ago on Y, want to nudge?"

Work gated behind a blocker nests under it. When the blocker clears, its children get consciously re-homed (promoted, held, or demoted), never silently dropped.

### Decomposition

If an item can't be finished in roughly 50k tokens of work, it's a project, not a task. It lives in FOR SURE as a header with indented action bullets, and one slice at a time gets pulled into ACTIVE. The slice carries its parent's name (`Project: [name] - [the slice]`) so the trace is visible.

## 3. The Session Lifecycle

Three skills manage the bookends of every session. You don't need to think about the mechanics; just use the commands.

### /start opens a session

When you say `/start`, Claude:
1. Reviews the global partnership file (`~/.claude/CLAUDE.md`)
2. Does the session-start reading the project `CLAUDE.md` prescribes (agenda, memory, feedback, canonical docs)
3. Reads the latest compression note (the bridge from last session)
4. Checks for a `REPAIR-REVIEW.md` waiting for your attention
5. Surfaces stale FOLLOW-UP items and anything relevant from the lower agenda tiers
6. States the ACTIVE item and recommends how to proceed

The goal is orientation without re-exploration. You pick up where you left off, with a clear next move proposed.

### Working

During the session, the agenda manages itself through natural conversation. When something comes up, say `/agenda add [idea]` and Claude asks which tier before placing it. When work finishes, the agenda advances: the top UP NEXT slot climbs into ACTIVE, the freed slot draws from FOR SURE.

### /wrap closes a session

When you say `/wrap`, Claude works through a sequence:

1. **Derives the session number** from the compression notes and checks whether it's a repair session (every 5th).
2. **Prunes the agenda.** Completed items get deleted, tiers advance.
3. **Updates CLAUDE.md** only if a durable orientation fact changed (rare).
4. **Saves memory through the gate.** Routes first, then applies the long-term test. Surfaces every write. If nothing clears the gate, nothing gets saved.
5. **Finishes repair** if this is a 5th session (see section 4).
6. **Recaps** what was done at each step.
7. **Runs /compress** as the final step.

### /compress writes a handoff note

This is the bridge for continuity. Before context compacts (or mid-session if you want), Claude writes a self-authored note to `Docs_Compressions/session-NN-YYYY-MM-DD-descriptor.md`. The note captures what happened, what was decided, what's next, and why, all in first person, authored by the current Claude for its future self.

The next session's `/start` reads this note first. It's the strongest continuity signal across sessions, stronger than memory or the agenda alone, because it carries the narrative thread and the reasoning behind recent decisions.

## 4. The Self-Healing Repair Cycle

Drift is inevitable. Memory leaks past the gate. Feedback entries accumulate past the limit. Paths in CLAUDE.md go stale. The repair cycle catches this before it compounds.

### How it works

`/project-repair` audits the project against `_SPEC.md` (the structure spec that defines what a correct project looks like). It runs every 5th session automatically as part of `/wrap`, or on demand whenever you want.

The audit is delegated, not done in the main thread:

1. **Two independent auditors** (Opus subagents) examine the project in parallel. Neither sees the other's work. Each reads the spec, reads the project files, and returns a list of findings with verbatim current text, the kind of drift (mechanical or structural), and a proposed fix.

2. **A review writer** (a fresh Opus agent with zero prior context) receives both auditors' raw findings and diffs them:
   - Both flagged it the same way = high confidence. If it's mechanical (a broken path, a duplicate, a stray file), it gets auto-fixed.
   - Only one flagged it, or they disagree = the review writer resolves the disagreement and escalates the finding for your review.
   - Structural findings (is this still relevant? should this move?) always go to you.

3. **The output** lands in `REPAIR-REVIEW.md` at the project root. The next `/start` surfaces it. Each finding includes the verbatim current text and the verbatim proposed replacement, so you can evaluate it without opening the source file.

### What it checks

- **File structure:** Are all required files present and in the right places?
- **Memory model:** Only `MEMORY.md` and `feedback.md` in the memory directory? Any stray files get consolidated, not trashed.
- **Feedback format:** Numbered sequentially? Each entry under 150 chars? Forward-posture framed? No `Why:` narratives? Under 15 entries?
- **CLAUDE.md structure:** Does the session-start reading point at the right files? Do all paths resolve? Do sections conform to the section index?
- **Agenda shape:** All four tiers present and in order? ACTIVE has at most one item? UP NEXT has at most three? No history or completed items lingering?
- **Compression notes:** Names conform to `session-NN-YYYY-MM-DD-descriptor.md`? Sequential integers, no gaps, no letter suffixes?
- **Scar detection:** Feedback entries framed as past failures ("last time you did X wrong") get flagged for reframing into forward postures (what TO do), per the pink-elephant principle.

### Mechanical vs. structural

Mechanical findings are objectively fixable: a broken path, a duplicate entry, a stray file, a malformed note name. These get auto-applied.

Structural findings require judgment: Is this memory entry still relevant? Should this feedback rule graduate to the global file? Is this agenda item properly tiered? These get escalated to `REPAIR-REVIEW.md` for your decision.

## 5. The Template System

Templates live at `~/.claude/project-template/` and define the starting shape of every project's doc system.

### The files

- **_SPEC.md** is the authority. It defines what files exist, where they go, what invariants they must satisfy, and what "correct" means for each file. Both `/project-setup` and `/project-repair` read this single file. Neither holds its own copy of the rules.
- **CLAUDE.md** template: project instructions with the session-start reading list, canonical docs section, and project overview.
- **AGENDA.md** template: the four-tier structure, pre-formatted with the limits and the FOLLOW-UP block.
- **MEMORY.md** template: the routing table, the quality gate, the NO SILENT WRITES rule, and section prompts.
- **feedback.md** template: the format rules and the purge protocol.
- **CLAUDE-SECTIONS.md**: the canonical menu of optional sections a project's CLAUDE.md can have (Key People, Voice Rules, Conventions, etc.). Used by both setup and repair.

### How setup works

When you run `/project-setup` in a new project, Claude reads the spec, asks you a few questions (what the project is, which docs are authoritative, any non-obvious conventions), and stamps the templates with your answers. Memory files go to the harness memory safe-dir. Project files go to the project root. Placeholders get filled, not left dangling.

Setup only creates what's missing. If a project already has some of the files, setup leaves them alone and points you to `/project-repair` for any drift.

### Migration for existing projects

The `migration/` directory includes a classification heuristic for migrating existing projects that use the old `NOW.md` pattern or have accumulated scattered memory files. It routes old content into the new system's tiers with about 80-90% confidence and produces a review doc for the remaining judgment calls.

## 6. The Global Layer

The kit installs to three locations under `~/.claude/`:

### ~/.claude/CLAUDE.md

The global partnership file. It loads in every session, in every project, automatically. It carries your partnership principles, working preferences, and behavioral instructions that apply everywhere. This is the file you personalize during setup.

### ~/.claude/commands/

The six skills live here as `.md` files. Claude Code surfaces them as slash commands (`/start`, `/wrap`, `/compress`, `/agenda`, `/project-setup`, `/project-repair`) available in every project. They reference the templates and the spec by path, so changing a template or a rule in one place propagates everywhere.

### ~/.claude/project-template/

The templates and the structure spec. `/project-setup` stamps from here. `/project-repair` audits against here. This is the single source of truth for what a correct project looks like.

### Per-project files

Each project gets its own instances:
- `CLAUDE.md` and `AGENDA.md` live in the **project root**, tracked and committed to git. They're project history worth versioning.
- `MEMORY.md` and `feedback.md` live in the **harness memory safe-dir** (`~/.claude/projects/[slugified-path]/memory/`), outside the repo. Git never sees them.
- `Docs_Compressions/` lives in the **project root**, created on the first `/compress`. One note per session, tracked and committed.
