# Skill Architecture — the settled rationale

*Captures the WHY so a cold session doesn't re-derive it; the decisions below are settled — see the Decided and Resolved sections at the bottom.*

## The governing principle: one nameable verb per skill

Each skill does one job you can name. Overloaded skills get the wrong name and breed duplication. The original `/project-setup` proved it: it welded **create** + **repair** together, which is why "setup" felt wrong AND why the same audit logic was duplicated in `/wrap`.

## The skill set (post-split)

| Skill | The one verb | Operates on | Cadence |
|---|---|---|---|
| `/project-setup` | **create** structure | the doc set as artifacts | once, at project birth |
| `/project-repair` | **repair** drift | MEMORY / feedback / structure health | every 5th session (wrap-triggered) |
| `/agenda` | **operate** forward work | content flow inside AGENDA.md | continuously, in-session |
| `/start` | **open** the session | reading + (new) the repair-clock nudge | session start |
| `/wrap` | **close** the session | prune agenda, memory per gate, compress | session end |
| `/compress` | **bank** a handoff note | the compression note | inside wrap, or standalone |

## Skill invocation graph

Skills that invoke other skills through the Skill tool. Any skill on the right side of an arrow **must be model-invocable** — a `disable-model-invocation: true` flag on it breaks the chain silently. Check this graph before adding that flag to any skill.

```
/wrap  ──►  /project-repair   (every 5th session, Step 0)
/wrap  ──►  /compress          (always, final step)
```

## Naming decisions (Evan)

- **`project-setup` + `project-repair`** — shared `project-` noun makes the pair intuitive and teachable (Evan installs this in businesses).
- **"repair," not "cleanup"** — *cleanup* pre-authorizes mess as normal; *repair* admits something broke and must be fixed. Honesty tax, kept on purpose.
- `/project-setup` stays its accurate self once repair is extracted — no rename needed.

## Why wrap's mini-audit failed (root cause)

Not because it lived in wrap. Because it ran **shallow, every session, during wind-down** = audit theater. Drift is a ~10-session phenomenon; a tired once-per-session glance never catches slow rot. `/project-repair` inverts all three conditions: **deep, rare, fresh Opus context.** Same activity, opposite conditions → it actually works.

## Self-management: cadence by session number, triggered at wrap

Pulling the audit out of wrap would lose the thing that made the system tend itself. The fix is **detect (cheap) vs. do (heavy)** — but the detector needs no stored state:

- **The clock IS the session number.** Repair fires when the session number is divisible by 5 (ends in 0 or 5). No `.last-repair` marker, no tracking — the compression-note sequence already holds the number. (My earlier marker idea is dead; Evan's cadence idea deletes the problem it solved.)
- **Triggered at `/wrap`, not `/start`.** Evan cleans up at night so mornings are friction-free; and the *subagent* does the work, so his context weight at close is irrelevant. **Correctness bonus:** repairing at wrap means drift never sleeps overnight and the compression note banks the *clean* state, so the next session starts from truth.
- **"Wrap is still just wrap"** — wrap carries a one-line cadence check that **delegates** to `/project-repair`; it holds none of the audit logic. Wrap sequence: prune agenda → (if session ÷ 5) run repair → memory per gate → **compress last** (so the note captures the post-repair state).
- **`/start`'s tiny role:** surface any repair escalation doc waiting in root, so the morning review isn't a passive file Evan might miss.
- **Dependency (DECIDED):** `/compress` always writes the session number as a plain integer, `n+1`, **no letter suffixes ever** (the old 31/31b/31c sub-numbering is banned). That single rule makes the ÷5 counter reliable.

## `.last-cleanup` (resolved): not ours

A single overwritten timestamp written by Claude Code's own internal housekeeping (prunes old sessions/caches). Nothing of Evan's references it. Not a log. Irrelevant to our system — leave it alone.

## Shared spec: setup and repair STACK, they don't mirror (Evan's key insight)

If `/project-setup` defines "a correct project" and `/project-repair` *also* defines it, that's two copies of the spec that drift — the exact disease we're curing. Fix: **one shared spec layer; both skills stack on it.**

- The **`project-template/` files + `_SPEC.md`** = the *single* definition of how a project should look.
- `/project-setup` **stamps** from it (create).
- `/project-repair` **audits against** it (check); when it finds a structural deviation, its *fix is to re-apply that same canonical template.*
- Neither skill owns the definition; both reference it. The create/repair split stays clean (different verbs/triggers/cadence) with **zero drift risk between them.**
- This makes the outer loop structural: improve the system = edit the shared spec **once** = both skills inherit it next run.

## `/project-repair` contract (multi-agent, run from wrap)

1. **Always launches Opus subagents.** Heavy read-legwork → subagents (coach doesn't take the field).
2. **Zero-context bar.** Skill text must be complete enough that agents with *no* project knowledge can repair from instructions alone. This bar is what makes repair self-validating (below).
3. **Two independent auditors, not proposer→verifier.** Both audit the same project from scratch, in parallel, never seeing each other. Independent audits beat sequential review (no anchoring). **The diff between their findings is the confidence signal.** A 3rd **reconciler** agent spins up *only if they diverge* (cheap, conflict-resolution only).
4. **Apply-vs-review matrix** (honors "automate simple, I review structural"):
   - **mechanical + both agree** → auto-apply + report in the compression note (reported = not silent). Evan never sees these.
   - **structural, OR the two disagree** → review doc in project root; do not touch. Structural always gets Evan's eyes even when both agree.
5. **Scope = content drift + structural integrity.** Memory failure modes (doc-mirror, code-mirror, session-log drift, stale dates, contradictions, mis-routed entries, gate violations, and the feedback wellness check — scar-framing, `Why:` narratives, over-150-char entries, over-15-entry bloat) AND structure checks against the shared spec (files present, paths resolve, AGENDA well-formed, CLAUDE reading list valid). **Plus CLAUDE.md drift** — it's editable mid-session via `/wrap`, so it bloats and wanders; audit it against `CLAUDE-SECTIONS.md` (every section in the menu, holding only what the menu says).
6. **Every finding tagged inner or outer.** *inner* = this project's content drifted through normal use → fix here. *outer* = a violation the structure should have prevented → likely in every project → signal back to global-project-manager. Test: *"could this happen in any project?"* → outer.
7. **Prototype of its output already exists:** `memory-audit-FINDINGS.md` (11 CUT / 4 RELOCATE / 2 KEEP, caught a year-stale date). Repair = make that repeatable + self-contained.

## How repair rides inside `/wrap` (Evan's pipeline)

1. **Early in wrap:** launch the 2 auditors in the background; they work while the rest of wrap proceeds.
2. **Meanwhile:** main agent prunes the agenda, applies memory per the gate.
3. **Auditors return → diff:** mechanical+agreed → auto-fix + note; structural-or-disagreed → write to the review doc in root.
4. **Compression note** records the clean state + what repair auto-applied + whether a review doc is pending.
5. **Last step of wrap:** if the review doc is non-empty → spin up the reconciler to organize it into one clean, prioritized artifact (inner/outer split, Evan's-call items flagged), then done. Empty → done, nothing for Evan.
6. **Next `/start`** surfaces any pending review doc so Evan reviews it fresh in the morning (not a passive file he might miss).

## The two-loop self-improving system 🔥 (this project's permanent identity)

- **Inner loop (per project):** repair heals the project; the zero-context bar means **every repair run is also a cold dry-run** that re-proves the docs are operable from instructions alone. Heal loop = validate loop.
- **Outer loop (global):** outer-tagged findings flow back **here, to global-project-manager.** A drift pattern across projects = a shared-spec/skill bug, not a project bug. Diagnose here → fix the shared spec or `/project-repair` → propagates on next install/update.
- **Therefore:** this project is not a workshop we abandon after rollout. It's the **control tower the outer loop reports to, permanently.** Repair's outer-tagged findings are its standing inbound feed.

## Always-loaded vs optional (who owns the reading)
`CLAUDE.md` auto-loads every session; `/start` is optional (skills are toolboxes, not mandates). So **what must happen every session lives in the always-loaded `CLAUDE.md`; `/start` is the deliberate-open layer on top and never duplicates it.**
- `CLAUDE.md` owns the session-start reading list (+ prove-it) and the per-project canonical-docs list — it has to work even when `/start` isn't run, and it's the only file that knows the project's canonical docs.
- `/start` does NOT re-list the reads. It triggers CLAUDE's reading, then adds what only matters on a deliberate open: partnership ritual · continuation check · surface `REPAIR-REVIEW.md` · name the ACTIVE item and recommend the move.
- Canonical docs (README, specs, design) are **project-authored, not templated** by this system. `CLAUDE.md`'s "Canonical docs" section is the slot where the project names them.

## Merge vs keep-separate (the rule)
**Absorb a skill when it's always "the other one, plus"; keep it separate when it's sometimes "instead of."**
- `/decompress` is always "`/start`, plus read the note" → **absorbed into `/start`** (continuation check, Step 3); the live one was deleted on promotion. Clean because `AGENDA.md` is now the forward truth, so the compression note dropped from lifeline to supplement.
- `/compress` is sometimes run **instead of** `/wrap` (mid-session context relief; an untracked one-off handoff Evan doesn't want in memory/agenda) → **kept separate**, and also called as wrap's last step. Bundling it into wrap would force tracking on the exact sessions Evan wants untracked.

## Decided

Split skills · names (setup/repair; "repair" not "cleanup") · cadence = every 5 sessions · wrap-triggered · integer session numbers in `/compress` (no letter sub-numbers) · shared-spec stacking · two independent auditors + conditional reconciler · mechanical-auto / structural-review · inner-outer classification · memory = two files, gate-over-count, repair as backstop · CLAUDE.md stays lean (no Key-Decisions catchall; architecture/decisions live in canonical docs) · decompress absorbed into start · compress kept separate but called by wrap.

## Resolved (these shipped during the build)

- **Contents of the shared spec** — written as `_SPEC.md`: the exact "correct project" definition both skills read (required files, memory model, version-control policy, the per-doc invariants repair checks).
- **Review-doc section template** — shipped in `project-repair.md` (Step 4): inner / outer / auto-applied sections, each item carrying what drifted · auditor agreement-or-disagreement · proposed fix.
- **Standing-approval / apply-vs-escalate list** — shipped in `project-repair.md` (Step 3): mechanical-and-both-agree auto-applies (stamp a missing file, fix a broken path or stale date, remove a verbatim duplicate, consolidate a stray memory file); structural-or-disagreement always escalates to `REPAIR-REVIEW.md`. Grows with use.
