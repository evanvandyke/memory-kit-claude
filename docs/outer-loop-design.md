# Outer Loop v2.1 -- Manifest-Driven Update Cascade

Session 22, 2026-07-09. Supersedes `outer-loop-v2-design.md` (kept for history). Revised the same night after an adversarial round: three independent reviewers (mechanics, product/consent, failure-modes) attacked the first draft; 5 blockers and ~15 majors survived verification and are folded in below. What also survived attack, unchanged: commit-SHA detection, render-based comparison, the three-way classifier's direction protection, script-not-agent for the mechanical layer, dry-run-first with fixtures.

## The problem (premise re-verified 2026-07-09)

Outer-loop findings have no plumbing, and nothing reconciles the installed system against the kit repo. Verified: no VERSION file, no kit-config.json, no SYSTEM-SIGNALS.md, no update mechanism of any kind -- setup.md calls itself "one-time" and re-running the wizard is the only update path.

## What v2 got wrong (each verified, not assumed)

1. **"Spec -> global files" is not mechanically possible.** `_SPEC.md` defines project structure and invariants; it holds no skill text or template payloads. The payload authority has to be a separate artifact: an install manifest.
2. **A manually bumped VERSION file recreates the manual-promotion failure.** Change detection must be automatic: commit SHA.
3. **Raw diffs false-positive forever.** ~10 of 13 copied files carry `[USER_NAME]`. Comparison runs against the *personalized render*, never the raw source. (The transform round-trips cleanly today: no residue either direction.)
4. **Binary stale/current is the wrong model.** Live-ahead states exist in reality (session-20 content surviving only in `~/.claude/`). "Different means stale, overwrite" would have destroyed that work.
5. **Auto-update breaks the wizard's consent contract** (setup.md:19) unless amended by real consent: recorded, visible, revocable, undoable.
6. **The v2 doc's own drift table had an inverted direction and a false retired-skill claim.** Design rule kept: the cascade reports evidence (checksums, paths), never narrative -- and the narrative layer (below) is *authored*, never generated.

## Ground truth, 2026-07-09

- Session 21's revert destroyed session 20's uncommitted kit edits; its partial reinstall pushed reverted content over live `_SPEC.md`, `project-template/CLAUDE.md`, and `project-repair/SKILL.md`.
- Session-20 content survived only in live `start`, `wrap`, `project-template/AGENDA.md`. Recovered tonight to branch `recovery/session-20-live-ahead` (3 commits, independently verified byte-exact). Note for review: the branch's template-`CLAUDE.md`/`_SPEC.md` edits are *reconstructions* of destroyed content (Tier B category), not copies -- flagged, not silently blended.
- Live is incoherent for new projects: template carries `[MEMORY-SAFE-DIR]`, live project-setup lacks the stamping instruction.
- Full drift inventory (every kit-vs-live difference, post-Tier-A): `Compression-Guide.md` (kit has a 52-line de-technicalization rewrite live lacks), `project-template/feedback.md` (direction needs Evan's call: kit "your global" vs live "the global ... (the constitution)"), `compress/SKILL.md` (4 live em-dashes), wrap Step 0 sequencing text (race, below). Every one of these is assigned to a Phase 0 tier -- an unassigned drift file would otherwise classify diverged on run one and freeze as permanent escalation noise.
- Kit-internal inconsistencies: six-vs-five skill counts (setup.md:391 still installs retired `agenda`); how-it-works says `~/.claude/commands/`; `_SPEC.md:77` "four templates"; setup.md:409/501 still reference `[MEMORY-SAFE-DIR]`; Step 4b installs `_SPEC.md`/`CLAUDE-SECTIONS.md`/`CLAUDE-QUICK-REF.md` into project roots (jurisdiction hole, below).
- `~/.claude/skills/` holds non-kit skills (design-intake, notifications-*) and orphaned kit-family skills (orient, quality). The manifest must declare out-of-scope explicitly.

## The two artifacts

### `install-manifest.json` (kit repo root -- versioned WITH the payload)

```json
{
  "kit": "memory-kit-claude",
  "manifest_schema": 1,
  "out_of_scope": ["skills/design-intake/", "skills/notifications-on/",
                    "skills/notifications-off/", "skills/orient/", "skills/quality/",
                    "CLAUDE.md", "kit-config/"],
  "files": [
    { "source": "global/skills/start/SKILL.md", "install_to": "skills/start/SKILL.md",
      "type": "copied", "personalize": true, "owner": "kit" },
    { "source": "scripts/kit-update-check.sh", "install_to": "kit-scripts/kit-update-check.sh",
      "type": "copied", "personalize": false, "owner": "kit", "mode": "755",
      "consent": "per-change" },
    { "source": null, "install_to": "CLAUDE.md", "type": "generated", "owner": "user",
      "checks": ["section: Before Every Response", "section: Core Partnership Behaviors",
                  "section: Core Safety", "section: Navigating System Reminders"] },
    { "source": "global/skills/agenda/SKILL.md", "install_to": "skills/agenda/SKILL.md",
      "type": "copied", "owner": "kit",
      "retired": { "date": "2026-06-29", "replaced_by": "start + wrap + _SPEC.md" } }
  ]
}
```

Rules:
- `install_to` relative to `~/.claude/`. Manifest validation (script-enforced, fails loudly): unique case-folded `install_to` (macOS is case-insensitive), every non-null `source` exists in the tree at that commit, schema fields well-formed.
- `type: copied` -> render-comparable. `type: generated` -> never content-compared; only `checks` run.
- `owner: kit` -> eligible for auto-update under opt-in. `owner: user` -> never written. `consent: "per-change"` overrides blanket opt-in for entries where a change must be individually approved -- **required on the updater script and anything executable**: the update mechanism never updates itself silently. (Trust model, named: `auto_update` = trusting the future contents of Evan's repo. Repo protections -- protected main, 2FA -- are part of the system.)
- `retired` entries short-circuit the classifier: presence check only, never rendered, never reinstalled. Found live -> moved to `~/.claude/kit-retired/<date>/` (a move, not a delete -- the no-deletion rule survives, and no Finder-in-a-hidden-dir instructions for non-technical users). The manifest is the single retirement authority.
- `mode` for executables. `manifest_schema` newer than the script understands -> bail with "update the updater first" (per-change consent prompt).
- Per-project stamped files (project CLAUDE/AGENDA/MEMORY/feedback) stay `_SPEC.md`'s jurisdiction. The Step 4b project-root copies of `_SPEC.md`/`CLAUDE-SECTIONS.md` are shadow authorities frozen at migration day -- **recommendation: kill them** (Step 4b reads from `~/.claude/project-template/` anyway) rather than invent a `scope: project` mechanism. `CLAUDE-QUICK-REF.md`'s destination is Evan's call (open question); whatever it is, it enters either the manifest or the spec's recognized-files list so audits stop flagging the kit's own installs.

### `~/.claude/kit-config/memory-kit-claude.json` (machine-owned, one file per kit -- multi-kit ready)

```json
{
  "kit": "memory-kit-claude",
  "installed_commit": "<full SHA, written ONCE per run, as the LAST operation>",
  "installed_at": "2026-07-09T21:30:00Z",
  "update_source": "https://github.com/evanvandyke/memory-kit-claude",
  "user_name": "Evan",
  "auto_update": true,
  "declined": { "skills/wrap/SKILL.md": "<HEAD SHA at decline time>" },
  "outer_loop_target": "<path to Kit Manager's SYSTEM-SIGNALS.md -- the kit author's machine only; client configs omit this field>"
}
```

- `installed_commit` is the three-way anchor. **Advance rule (the blocker fix): it is written exactly once per run, at the end, and only if every copied entry then satisfies `live == render(HEAD)`. Otherwise it holds.** No per-file "heal." A crash mid-run therefore leaves the anchor at the old SHA; the next run re-classifies partially-updated files as already-current and finishes the job -- torn state is self-healing instead of latched.
- `declined` records per-file declined SHAs (`auto_update: false` path): a Kept file is re-prompted only when it changes upstream again -- no nag loop, no soft-coercion.
- `user_name` recorded because it is machine-readable nowhere else. `outer_loop_target` present only for Evan. Clients' outer findings deliberately never flow upstream (privacy boundary -- held by the absence of any outbound code path, not just config: nothing in the update flow sends data out; the clone is inbound, the report is a local write).

## The classifier

Every run classifies every entry -- **there is no SHA-equal short-circuit for comparison.** When `HEAD == installed_commit` only the update direction is skipped; live-ahead detection still runs, because live drift between pushes is the founding scenario (session 20's loss window) and a short-circuit reopens it. One render suffices in that case.

Per `copied` entry, with `Ri = render(source@installed_commit)`, `Rh = render(source@HEAD)`:

| live | vs Ri | vs Rh | State | Action |
|---|---|---|---|---|
| present | = | = | in-sync | nothing |
| present | = | ≠ | kit-ahead | update under opt-in (backup first) |
| present | ≠ | = | already-current | record only (anchor advances at run end) |
| present | ≠ | ≠, Ri = Rh | **live-ahead** | never touch; escalate; for Evan: "upstream this" signal |
| present | ≠ | ≠, Ri ≠ Rh | **diverged** | never touch; escalate (both sides moved; needs a human merge) |
| absent | -- | source exists @HEAD, absent @installed | **new** | install under opt-in |
| absent | source exists both | -- | **missing** | reinstall under opt-in |
| present | source absent @installed | = Rh | already-current | record only |
| present | source absent @installed | ≠ Rh | conflict | escalate |
| (any) | entry only in installed-manifest | -- | removed-upstream | move to kit-retired, report |

- **Both manifests are read** (`manifest@installed_commit` and `manifest@HEAD`), joined on `install_to`; each side's render uses its own manifest's `source`/`personalize`. Optional `renamed_from` handles moves. An entry deleted from the manifest without a `retired` tombstone classifies removed-upstream: a loud escalation (exit 2), not a validation halt -- the run still completes and reports everything else.
- Pinned behaviors (implemented and test-covered): a renamed entry whose live file still sits at the old path classifies kit-ahead ("would move"), never in-sync. Re-baseline posture with the live file absent classifies missing (would install under opt-in). "Locked by another run" exits as error code 3, documented. A declined file re-prompts only when `render(source@declined-SHA) != render(source@HEAD)` -- unrelated commits never re-nag.
- Upstreaming a live-ahead file is always a human-reviewed edit in the kit repo -- never a mechanical name -> `[USER_NAME]` reverse-replace (not invertible when the user's name is an English word).
- A kit-owned file classified diverged whose current bytes match a file in `kit-backups/` is a torn write, not user work: restore-and-offer flow instead of a dead-end escalation.

## One render implementation

The render (literal-string `[USER_NAME]` -> name replacement; no regex/sed metacharacter exposure) lives in the shipped script, and **the wizard calls the same script for every `personalize: true` install**. Agent-performed find-and-replace during install is what creates seam drift (normalized newlines, "corrected" possessives) that would mass-classify a pristine client install as diverged. The agent narrates; the script writes.

## The cascade

- **Layer 1 -- upstream -> installed kit files.** Clone `update_source` to a scratch temp dir (full clone -- the classifier needs `installed_commit`'s tree). Classify all entries; apply per consent; report.
  - Clone fails (offline) -> **degrade, don't halt**: skip Layers 1-2 with one plain sentence ("Couldn't check for kit updates -- no connection. Your project checkup still ran; I'll check next time."), run Layer 3 locally. "Halt" is reserved for an unreadable/invalid manifest on a successful clone.
  - `installed_commit` missing from history (force-push) -> degrade to two-way vs `render(HEAD)`: matches record as already-current, mismatches classify diverged with an explicit "anchor lost, re-baseline" warning -- same posture as adoption.
- **Layer 2 -- structure checks on the global layer** (network-free): generated files' `checks`; placeholder integrity in `~/.claude/project-template/` (`[Project]`, `[project-slug]` verbatim); template-conformance (template CLAUDE.md contains every CORE section of CLAUDE-SECTIONS.md); no retired entry present. Gate.
- **Layer 3 -- spec -> project files.** Existing `/project-repair` audit, unchanged.

**Write discipline (applies to every live write, updater or bootstrap):** write to a sidecar file, `mv` into place (atomic on APFS); backup before overwrite to `~/.claude/kit-backups/<ISO-timestamp>/<install_to>` -- unique per run, never overwriting an existing backup file; a `RESTORE.md` dropped in each backup dir; "undo the last kit update" is a named user-facing action that restores from the newest backup dir.

**Concurrency:** `mkdir ~/.claude/.kit-update.lock` as mutex (dir with PID + timestamp inside; stale-broken after 30 minutes). A second concurrent repair skips Layers 1-2 with "kit update already in progress" and proceeds to its own Layer 3.

**Sequencing (full wrap order, replacing today's racy Step 0/Step 4):** wrap's own project edits first (prune agenda, CLAUDE.md facts, memory) -> then `/project-repair` (Layer 1 cascade -> Layer 2 -> Layer 3 auditors -> review writer) -> then compress, last, banking the post-repair state. Auditors never run while wrap is still editing the files they read, and never against templates mid-update. Both wrap Steps 0 and 4 get rewritten together; this fix is Tier C item 1 and its live promotion rides the Phase 0 bootstrap protocol.

## Consent model (amends setup.md:19, with teeth)

- **Opt-in, once, in plain language with consequence and reversibility:** "About every 5 sessions I'll check GitHub for kit improvements and apply them to the kit's own files. You'll always get a list of what changed, I always keep a backup, and you can say 'turn off auto-updates' anytime." Recorded as `auto_update`.
- **Revocation is a named action** ("turn off auto-updates" -> repair flips the flag). **Undo is a named action** (restore from newest backup). **Every update summary re-states the opt-in and how to change it** -- the "why did my files change?" moment self-answers.
- `auto_update: false` -> Replace/Keep per changed file, with `declined` bookkeeping (no re-nag).
- Executables and the updater itself: per-change consent regardless of the flag.
- user-owned files never written; live-ahead/diverged never auto-touched; nothing ever deleted (moves to `kit-retired/`).
- setup.md's hard-rules section gains one line acknowledging the recorded opt-in.

## The narrative layer (authored, never generated)

The kit repo carries a `CHANGELOG.md`: Evan writes one plain-language line per meaningful change, keyed by commit. The update summary a client sees is **mechanical assembly** of the authored lines between `installed_commit` and HEAD -- no agent summarizing diffs (hallucination risk), no raw checksum tables (unreadable to a coaching client). Evidence lives in the report file; narrative lives in the chat relay, which repair already does. The changelog also supplies the human version story: a date-derived label ("July 9, 2026 update") answers "am I up to date?" in the client's language; the SHA stays the detector underneath.

Client-facing texts for the three escalation experiences (offline, diverged file, retired skill) are Layer 1 deliverables, drafted with the mechanism, not afterthoughts.

## Adoption (existing installs -- the whole current client base)

No `kit-config/` entry does NOT mean "stop": repair offers adoption once. Interview for `user_name` if unknown, ask the opt-in question, then classify every entry against `render(HEAD)` only: byte-identical files anchor silently; genuine mismatches get the classic Replace/Keep vocabulary the client learned in the wizard -- **never a diverged-wall report.** `installed_commit` anchors at HEAD once the pass completes. The same posture serves the lost-anchor fallback.

## SYSTEM-SIGNALS.md lifecycle

- Created by repair on first append (with an explaining header). Surfaced by kit-manager's /start via its CLAUDE.md reading list; no dangling path before first signal.
- Entry format: a stable dedupe key (`project + check-id-or-file-path`) plus `## YYYY-MM-DD -- <project> -- <one-line finding>` and a short evidence body. A key match bumps `seen: N, last: <date>` instead of duplicating -- free-text prose never carries the dedupe.
- Resolution is deletion (mirrors the agenda). No "done" section.

## Dogfood (the guarantee, made real this time)

Evan's config sets `auto_update: true` and **Evan stops hand-installing**: edit kit repo -> push -> his own next repair applies the update through the same classifier, backup, and summary machinery clients use. Kit-manager's CLAUDE.md "How changes flow" section is amended accordingly (Phase 0 deliverable). Without this, Evan's live files always equal `render(HEAD)`, his runs always classify already-current, and the kit-ahead write path -- the one clients live on -- is once again never exercised by its author. Divergences that remain by design: `outer_loop_target`, and richer live-ahead/diverged traffic on Evan's machine (he's the only one generating upstream candidates).

## Phase 0 -- reconciliation and bootstrap (one-time, prerequisite)

**Step 1 -- version the live system.** `git init ~/.claude` (with a `.gitignore` for volatile harness state) and commit the current state, *before anything writes*. One command structurally closes revert-safety, torn-write detection, and future live-ahead backup -- the class of loss session 21 caused. (Evan's call -- open question -- but the design assumes it; a full snapshot is the fallback.)
**Step 2 -- Tier A (done tonight, verified):** branch `recovery/session-20-live-ahead` -- live-only session-20 content into the kit; `[MEMORY-SAFE-DIR]` removal completed coherently; agenda skill re-tombstoned. Reconstructed (not copied) template-CLAUDE/_SPEC wording flagged for Evan's review.
**Step 3 -- Tier B (Evan reviews):** reconstruct session-20's lost `_SPEC.md`/project-repair edits (compound-ACTIVE, FOLLOW-UP annotation, client-comms lifecycle, feedback durability, auditor checks) -- diff the session-20 note's edit list against current spec text first; some may exist via commit 16b4549. Decide feedback-template direction (kit vs live wording).
**Step 4 -- Tier C (mechanical, kit repo):** wrap/repair sequencing rewrite (Steps 0+4); Compression-Guide already in kit (no action -- it ships via the first update); compress em-dash fix ships the same way; six-vs-five counts; drop `agenda` from setup.md:391; `commands/` -> `skills/`; "four templates"; setup.md:409/501 placeholder refs; quick-ref table break; kill Step 4b root copies (pending open question); `.DS_Store` out of the payload.
**Step 5 -- write `install-manifest.json` + `CHANGELOG.md`; merge to main.**
**Step 6 -- bootstrap install (the step v1 skipped and session 21 fumbled):** scripted install from the anchor commit -- same script, same write discipline (sidecar+mv, backup, lock) -- bringing every copied file byte-equal to `render(anchor)`. **Verification gate: the dry-run must report all-in-sync BEFORE `kit-config` is written.** Only then does the cascade exist.

## Layer 1 implementation spec (the authorized slice -- DRY-RUN ONLY)

`scripts/kit-update-check.sh` (POSIX shell, shipped in the kit, invoked by repair's instructions):
1. Locate config (`~/.claude/kit-config/<kit>.json`); absent -> print the adoption offer text and exit (dry-run never writes).
2. Acquire the lock (or report "in progress" and exit). Clone to scratch; resolve HEAD.
3. Read and validate both manifests (installed_commit's and HEAD's; absent at installed -> adoption/re-baseline posture).
4. Classify every entry per the table -- including existence states and retired presence. Run `generated` checks read-only.
5. Emit the report: machine section (per-entry state, checksums, paths) + assembled changelog lines. Exit code encodes the aggregate (0 = all in-sync, 1 = updates available, 2 = escalations present, 3 = error) so tests assert outcomes mechanically -- no verifier vibes.
6. Write nothing else. Release the lock.

Report location: dry-run runs write to the kit-manager project dir (Evan's review surface). Steady-state location is `~/.claude/kit-update-report.md` with the chat relay as the client surface; `KIT-UPDATE-REPORT.md` gets named in `_SPEC.md`'s recognized transient files either way so audits don't flag the system's own output.

**Fixture matrix (test-first, before touching the real system):** a fixture git repo + fake live dir seeding every classifier row: in-sync, kit-ahead, already-current, live-ahead, diverged, new-upstream, missing-live, removed-upstream, renamed entry, retired-present, generated-missing-section, no-config, no-manifest-at-installed, lost anchor (force-push), declined-then-changed-again, torn write (half-written file + backup present), schema-version-too-new, locked. Assertions run on exit codes and per-entry states; the independent verifier returns checksums and raw outputs the orchestrator spot-checks -- never bare verdicts (the v1 fake-verifier hole).

Then one read-only run against the real `~/.claude/` with the real kit repo as upstream, reviewed by a blind verifier.

## Open questions for Evan

1. **`git init ~/.claude`** -- the design assumes yes; it's the structural fix for the unversioned-live wound. Fallback: timestamped snapshots.
2. **Kill Step 4b's project-root copies** of `_SPEC.md`/`CLAUDE-SECTIONS.md` (shadow authorities) vs adding project-scope manifest machinery. Recommendation: kill.
3. **CLAUDE-QUICK-REF.md destination** -- the wizard's contract instructs installing it to project roots, but it has never been installed on this machine; pick a home or drop it.
4. **orient/quality skills** -- declared out-of-scope in the manifest for now; adopt into the kit later as a separate agenda item?
5. **feedback-template wording direction** (kit "your global" vs live "(the constitution)").
6. **Tier B go-ahead** after reviewing the recovery branch, including its two reconstructed files.
7. **Merge `recovery/session-20-live-ahead`** into main -- it becomes the reconciled anchor's foundation.
8. **Evan's own `auto_update: true`** (dogfood) and retiring the hand-install workflow from kit-manager's CLAUDE.md.
