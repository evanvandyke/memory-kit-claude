# Project Structure Spec — the single source of truth

Both `/project-setup` (create) and `/project-repair` (audit) read THIS file. Neither holds its own copy of the structure. Setup makes a project match this; repair checks a project against this and fixes or escalates deviations. Change the structure once, here, and both skills inherit it.

## Required files (the only doc-system files a project has)

| File | Location | Purpose |
|------|----------|---------|
| `CLAUDE.md` | project root | orientation, session-start reading, canonical-docs list |
| `AGENDA.md` | project root | the forward-only agenda |
| `MEMORY.md` | memory safe-dir | long-term memory |
| `feedback.md` | memory safe-dir | behavioral rules earned together |

Templates for each live beside this file in this folder. Stamp from them. Never embed copies of structure anywhere else.

### Generated structure — `Docs_Compressions/`
Beyond the four stamped files, a project grows one generated directory: `Docs_Compressions/`, a project-root folder created on the first `/compress`. It holds one self-authored compression note per session, named `session-NN-YYYY-MM-DD-descriptor.md` — `NN` a plain zero-padded integer, no letter suffixes (no `17a`/`17b`), no gaps. It's the sequence the every-5th-session repair clock counts, so the naming is load-bearing. Absent until the first `/compress`; not something setup stamps.

## Where the memory files live
`CLAUDE.md` and `AGENDA.md` live in the **project root**. `MEMORY.md` and `feedback.md` live in the **memory safe-dir**: `~/.claude/projects/<project-safe-dir>/memory/`, where `<project-safe-dir>` is the project's absolute path **slugified the way the harness does it: every non-alphanumeric character (slash, underscore, dot, space) becomes a dash, one-for-one, with no collapsing of repeats.** E.g. `/Users/yourname/Projects/my-app` → `-Users-yourname-Projects-my-app`. The harness owns this slug, so a project that has already written memory **already has its folder** — when unsure, `ls ~/.claude/projects/` and match the one that's there. A wrong slug (e.g. converting only slashes) writes memory to a directory the harness never reads.

### Memory model — DECIDED: two files, gate over count
This system uses a single `MEMORY.md` (full content) + `feedback.md`, **not** the harness's one-fact-per-file convention. The lever is the **gate**, not the file count: one curated file you actually read beats twenty files you skim into uselessness. The gate (route first, read `MEMORY.md` before writing, 250-char-max `MEMORY.md` entries) keeps quality up, works in one file, and stays readable in full at session start. The 250-char cap is a `MEMORY.md` rule. **`feedback.md` is governed by hard limits, not just the gate — numbered entries, ≤150 chars each, no `Why:` narratives, max 15 (purge on overflow); see the feedback invariants below.**

Working *with* the harness, not purely against it:
- Both files carry `description` frontmatter so the harness's own recall surfaces the right one when relevant.
- The harness still defaults to writing a new per-fact file on save. Instruction suppresses it (CLAUDE + the MEMORY header both say "two files only"), and **`/project-repair`'s "only `MEMORY.md` + `feedback.md` exist" check is the automatic backstop** that consolidates any stray file on cadence. So this is not a fight [USER_NAME] polices; leakage is caught and folded back in.

## Version control — DECIDED: commit, don't hide
The doc-system files that live in the project repo — `CLAUDE.md`, `AGENDA.md`, and `Docs_Compressions/` — are **tracked and committed**, not gitignored. They're project history worth versioning and backing up. (`MEMORY.md` + `feedback.md` live in the safe-dir, outside the repo, so git never sees them.) Setup adds no `.gitignore` entries for these, and repair does not flag their presence in the repo as drift. This settles the old "AGENDA is leaking into the repo" reflex: it's not a leak, it's intended.

**Client-repo exception.** The above is for *your own* repos. In a **client repo** — a deliverable handed to someone else (e.g. anything under `clients/`) — the opposite holds: keep `CLAUDE.md` / `AGENDA.md` / `Docs_Compressions/` **gitignored**. Committing your working notes into the client's git history is a confidentiality leak, not a backup (the client doesn't know about Claude). There the ignore is **intended**: setup leaves it in place, and repair must treat it as correct, not flag it as drift. (`MEMORY.md` + `feedback.md` live in the safe-dir outside the repo, so they're unaffected either way.)

## Invariants (what "correct" means — repair checks each)

**CLAUDE.md**
- Session-start reading points at `AGENDA.md` (never `NOW.md`), then `MEMORY.md` + `feedback.md`, then the canonical docs.
- The reading list **names where `MEMORY.md`/`feedback.md` live — the resolved memory safe-dir path (`~/.claude/projects/<project-safe-dir>/memory/`), not just their filenames** — so a reader never looks for them in the project root and wrongly concludes they don't exist. The path must be the actual slugified path for this project (no leftover `[MEMORY-SAFE-DIR]` placeholder), and must match the directory the memory files actually occupy.
- Has a Canonical Docs list (the project's source-of-truth set memory routes to).
- Every path it names resolves to a real file.
- Its sections conform to `CLAUDE-SECTIONS.md` (the section menu); repair audits this.

**AGENDA.md**
- All four tiers, in order: ACTIVE / UP NEXT / FOR SURE / IDEAS.
- ACTIVE holds at most one item. UP NEXT holds at most three items *total* — and WAITING is **inside** that three, not on top of it: when work is blocked on a third party, one of the three slots **is** the WAITING block (2 work slots + 1 WAITING when blocked; 3 work slots when nothing's blocked). This is intentional — a deliberate visibility bottleneck that keeps blocked/third-party work in view, not overhead to optimize away.
- Forward-only: no history, no "last session," no completed-and-struck items.
- Sub-projects nest **inline, not in their own files**: a slice of a nested initiative is tagged `Project: [parent] — Subproject: [sub] — [slice]` in this one AGENDA. A sub-project graduates to a standalone project (its own root + AGENDA) only when it's earned the separation. A nested `AGENDA.md` created for a sub-project is drift — its work belongs in the root AGENDA.

> **On the duplication repair will see:** the tier limits above are authoritative here. The `AGENDA.md` template and the `/agenda` method restate them as teaching copies, and the route-table is taught in several places by design (the `MEMORY.md` header, DOC-SYSTEM-MAP Layer 3). That overlap is intended, not drift — `_SPEC` is the tiebreaker if any restatement ever disagrees.

**MEMORY.md**
- Carries the long-term-not-episodic header: the router, the gate, NO SILENT WRITES.
- Holds only durable facts (the project, how [USER_NAME] works). No session log, no doc-mirror, no code-mirror.

**feedback.md**
- One file only, a flat numbered list. No `feedback_*.md` siblings, no category headers.
- Rules are **forward postures** (what TO do), not scars — a rule written as a past failure fights the pink-elephant principle (describe the desired behavior, not the avoided one). Reframe a scar to a heading, or cut it if no rule survives.
- **Numbered sequentially (1, 2, 3…), ≤150 chars each, no `Why:` narrative lines, max 15 entries.** The reasoning folds into the rule itself, not a separate replay.
- **Purge on overflow:** a 16th entry forces dropping one to stay ≤15 — surfaced, never silent; priority graduated-to-global → superseded → least-applicable. Repair **proposes** purges in `REPAIR-REVIEW.md`; in-session, surface and confirm. Never an auto-rewrite or auto-delete.

**Memory directory**
- Contains ONLY `MEMORY.md` and `feedback.md`. Any other file is bloat to consolidate.
- Exception: `.DS_Store` → **auto-removed directly**, not flagged — it's harmless macOS cruft.

**Docs_Compressions/**
- Every note name conforms to `session-NN-YYYY-MM-DD-descriptor.md` with `NN` a plain zero-padded integer — no letter suffixes (`17a`/`17b`), no gaps in the sequence. A non-conforming or gapped name is a mechanical finding (it breaks the repair clock). **Grandfather clause (convention set 2026-06-05):** this applies only to notes created **on or after 2026-06-05**. Notes dated before that — date-only names, letter suffixes, or gaps inherited from a pre-convention project or a migration — are immutable history and are **never** flagged as drift. The clock is derived from the highest conforming integer regardless.
- Tracked and committed per the Version Control policy above; its presence in the repo is intended, never flagged as drift.

## Where this lives when promoted
Global: `~/.claude/project-template/` (this spec + the four templates). The skills reference that path.
