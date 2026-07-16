---
name: project-repair
description: "Audit a project's doc system against the structure spec. Auto-fix safe drift, escalate structural issues."
when_to_use: "Called by /wrap every 5 sessions, or on demand when user asks to check project health."
---

# Project Repair

Audit the project's doc system, fix what's safe, escalate what needs [USER_NAME]. Delegate the audit to Opus subagents; do not audit in the main thread.

**The project is the current working directory.** Read `~/.claude/project-template/_SPEC.md` first; it defines a correct project, and everything below checks reality against it.

## When this runs
- **Automatically:** invoked by `/wrap` every 5th session.
- **On demand:** when [USER_NAME] asks, or when behavior suggests drift.

## Step 0: Check for kit updates first (Layer 1)

Before auditing this project, reconcile the install against the kit itself. This is Layer 1 of the update cascade, and it runs first so the auditors never read templates that are mid-update.

If `~/.claude/kit-config/memory-kit-claude.json` does **not** exist, skip Layer 1 silently and go straight to Step 1. If the config exists but `~/.claude/kit-scripts/kit-update-check.sh` is missing, treat it as exit 3 below.

If both exist, run the update check. This is a dry run: it writes nothing but a report.

```bash
~/.claude/kit-scripts/kit-update-check.sh --home ~/.claude --report /tmp/kit-update-report.md
```

Run the script. When it finishes it returns a number (the exit code) that tells you what happened. Act on it:
- **0: everything is current.** Continue to Step 1 without mentioning updates.
- **1: updates are available.** Read `auto_update` in the config. If it is `true`, apply them: re-run the same command with `--apply` added, then read the assembled changelog lines from the report and relay them to [USER_NAME] in plain language: what changed, that a backup was made first, and that "undo the last kit update" reverses it. Anything the report marks as needing individual approval (such as the updater script itself) waits for [USER_NAME]'s explicit yes. If `auto_update` is `false`, tell [USER_NAME] that improvements are available and automatic updates are off, and that they can turn them on by saying "turn on auto-updates." Apply nothing.
- **2: escalations are present** (a file changed on both sides, or something needs a human). Surface these to [USER_NAME] alongside the repair review below; never auto-apply them.
- **3: the check couldn't run** (no connection, or an update is already in progress). Say one calm sentence: "I couldn't check for kit updates this time; your project checkup still ran." Continue to Step 1. Never halt the repair over this.
- **4: the kit config is missing, setup never completed or was removed; tell [USER_NAME] plainly and continue the checkup.**
- **5: the kit's own data looks corrupt or the pinned version cannot be found; do not apply anything, surface it to [USER_NAME] as needing attention, and continue the project checkup.**

Then proceed to Step 1. Layer 1 reconciles the kit's own files; Steps 1-3 audit this project. When running as a subagent, fold these update outcomes into the Step 3 report instead of addressing [USER_NAME] directly.

## Step 1: Launch two independent auditors (Opus, parallel)
Spin up TWO Opus subagents at once. Each audits independently; neither sees the other's work.

**Drive every subagent you launch (auditors here, the review writer in Step 2) to completion.** If one stalls or dies mid-run, resume it or spawn a replacement with the same brief. Each time you resume, read the child's actual output first: its completion notice may have routed to your caller instead of you, so a child that looks "still running" may already be done. Your own run ends only when the review is written and the report is delivered, never before.

Brief each identically, with the project's absolute path filled in:

> **Role + hard rules.** You have zero prior context on the project at `[project path]`. You are an auditor: report findings only, modify nothing. No file you read gets edited, created, or deleted by you. Finalize from your own reading; do not call optional server-side consultation tools (e.g. advisor). The checklist is deterministic and those calls can stall your run.
>
> **Read these:**
> - `~/.claude/project-template/_SPEC.md` and `~/.claude/project-template/CLAUDE-SECTIONS.md`
> - the project's `CLAUDE.md`, `AGENDA.md`, and its `MEMORY.md` + `feedback.md` (in the memory safe-dir the spec names)
> - the memory-directory listing AND the `Docs_Compressions/` listing in the project root
>
> **Check these** (one finding per deviation):
> - **Spec + section index.** Audit the project against the spec and the section index.
> - **Template structural lines are `mechanical`, never escalations.** When an AGENDA tier header, annotation, description line, or structural blockquote differs from the current template, the template wins (per `_SPEC`): the fix is restamping the template text verbatim. Report ALL such mismatches in a file as ONE finding ("restamp structural lines to current template"), not per-line BEFORE/AFTER items.
> - **Compression-note naming.** Check every `Docs_Compressions/` note name against the spec's integer convention (`session-NN-…`, zero-padded, no letter suffixes, no gaps): a suffixed or gapped name dated **on or after 2026-06-05** is a `mechanical` finding. **Notes dated before 2026-06-05 are grandfathered (pre-convention / migrated history). Do not flag them.**
> - **Feedback scar-framing.** Sweep `feedback.md` (and any scar that's leaked into `MEMORY.md`) for scar-framing: an earned rule written as a past failure ("last time you did X wrong", "stop doing Y") instead of a forward posture. Per `_SPEC`'s feedback invariant and the pink-elephant principle (describe the desired behavior, not the avoided one), naming the behavior to avoid plants it, so a scar trains avoidance, not a heading. For each: if a forward posture is extractable, propose **reframing** to what TO do (keep the rule, drop the blame); if nothing but the wound remains once the blame is stripped, propose **cutting** it. Tag these `structural` so they reach [USER_NAME]. Never auto-rewrite or delete `feedback.md`.
> - **Feedback hard limits.** Check `feedback.md` against `_SPEC`'s hard limits: each entry ≤150 chars, numbered sequentially, no `Why:` lines, ≤15 entries total. Flag every violation: propose compressing over-long entries, folding `Why:` lines into the rule, and (if over 15) a purge set (priority: graduated-to-global → superseded → least-applicable).
> - **Feedback durability.** Apply `_SPEC`'s feedback durability invariant: propose cuts for entries that no longer earn their slot (graduated-to-global, superseded, least-applicable) even when the file is under the cap.
> - **Compound-ACTIVE.** Findings are `structural`, propose-only. Never auto-split an ACTIVE item.
> - **Client-comms closure.** Findings are `structural`, propose-only. Never auto-close a FOLLOW-UP item.
> - **Gitignore.** Check whether the project's `.gitignore` (if any) excludes `CLAUDE.md`, `AGENDA.md`, or `Docs_Compressions/`. Per the spec's version-control decision, these are tracked and committed in non-client repos. A gitignore pattern hiding them is `mechanical` drift, unless the project lives under `clients/`, where ignoring them is correct (client-repo exception).
> - **MEMORY.md structural header.** Check that `MEMORY.md` carries its required structural header: the routing table, the gate (route first → read before writing → 250-char cap), and the NO SILENT WRITES rule. A missing or incomplete header is `structural`.
> - **Migration leftovers.** Flag any `NOW.md` or `MIGRATION-REVIEW.md` in the project root as `mechanical`. These are leftover migration artifacts from the old system.
>
> All `structural` proposals go in `REPAIR-REVIEW.md`; never auto-edit feedback. Every proposed replacement for a feedback entry must itself comply: ≤150 chars (content only, no number prefix), forward-posture framed, no `Why:` lines. A non-compliant proposal gets flagged the same as a non-compliant entry.
>
> Return every deviation as a finding.

Each finding carries:
- **what:** the specific drift, with the **verbatim current text** quoted (name the file).
- **kind:** `mechanical` (objectively fixable: verbatim duplicate; a date provably past versus today; a file that shouldn't exist; a broken path; a required file missing) or `structural` (judgment: is this still relevant, should this move, is this the right shape).
- **fix:** the **verbatim proposed replacement** or, for a removal, the verbatim text being dropped + the reason. The finding must be evaluable with zero access to any source file: reproduce the current text in full. Never use a label, a line number, an ellipsis, or a summary of what it "said."

## Step 2: Launch the review writer (Opus, fresh context)

A fresh agent with one job writes the review. Launch a review-writer subagent (Opus, zero accumulated context): it diffs the auditors' findings, applies safe fixes, writes the review doc, and resolves disagreements.

Pass both auditors' complete findings to the review writer. Do not summarize, filter, or reformat them. Pass the raw output. The review writer handles everything from here.

Brief it, with the project path, memory safe-dir path, and both auditors' raw findings injected:

> You are the review writer for a project repair audit. You have zero prior context. Two independent auditors have examined the project at `[project path]` and returned their findings below. Your job: diff the findings, apply safe mechanical fixes, and write the review document for anything that needs [USER_NAME]'s decision. Finalize from your own reading; do not call optional server-side consultation tools (e.g. advisor). They can stall your run.
>
> **The source files** (read these for verbatim quoting):
> - `[project path]/CLAUDE.md`
> - `[project path]/AGENDA.md`
> - `[memory safe-dir path]/MEMORY.md`
> - `[memory safe-dir path]/feedback.md`
> - `[project path]/Docs_Compressions/` (listing)
>
> ---
>
> **AUDITOR A findings:**
> [paste Auditor A's complete output here]
>
> **AUDITOR B findings:**
> [paste Auditor B's complete output here]
>
> ---
>
> ### Your process
>
> **1. Diff the two audits.**
> - Both flagged it the same way = high confidence.
> - Only one flagged it, or they propose different fixes = a disagreement.
>
> **2. Apply mechanical fixes that both agree on.** Record each for the report. "Both agree" means agreement on the FINDING. If the auditors flagged the same drift but differ on mechanical-vs-structural, you resolve the kind yourself.
> - a missing required file → stamp from `~/.claude/project-template/`.
> - a structural line (tier header, annotation, description line, structural blockquote) that differs from the current template → restamp the template text verbatim, and report the whole file's restamp as one line ("restamped structural lines to current template"), never as per-line escalations.
> - a broken path or stale date → correct in place, but only when there is exactly one defensible fix. When the correction forks (remove the line vs create the doc; a date that can't be known without inventing an event), escalate to the review doc instead.
> - a verbatim duplicate → remove the duplicate.
> - a stray memory file (beyond `MEMORY.md` + `feedback.md` in the safe-dir) → **consolidate, don't trash.** Read it, merge durable content into `MEMORY.md` per the gate (route first; read before writing; ≤250 chars), then flag the empty husk for [USER_NAME] to delete; never delete files yourself.
> - `.DS_Store` → delete directly (system artifact, not user content).
> - any other file that shouldn't exist → flag for [USER_NAME] to delete; never delete files yourself.
>
> **3. For structural findings, or any disagreement: write the review doc.** If there are disagreements, resolve them yourself: you have both auditors' reasoning and the source files. Present your resolution clearly, noting where the auditors differed.
>
> If nothing was escalated and nothing was applied, report an all-clear and write no file.
>
> Otherwise, write `REPAIR-REVIEW.md` at `[project path]/REPAIR-REVIEW.md` using this format:
>
> ```
> # Repair Review: [project name], [YYYY-MM-DD]
>
> ## Fix this project
> *Evaluable with zero file access. Every change reproduces its current text in full. Test: if reconstructing the exact old or new text would need a source file, it's not finished.*
> - **[what + file]** · [agreed | auditors differ: A says…, B says…; resolved: …]
>   - BEFORE: [verbatim current text]
>   - AFTER:  [verbatim proposed text]
> - **DROP** · [verbatim removed text] · reason: [graduated-to-global | superseded | scar-only | duplicate]
>
> ## Auto-applied (FYI, already done)
> - [what was fixed without review]
> ```
>
> ### The verbatim rules (non-negotiable)
>
> **Every change is N verbatim BEFORE/AFTER pairs, never a summary.** A change that merges, drops, or rewrites multiple entries is not one change: it is one pair *per affected entry*. Quote each original in full as its own BEFORE, paired with the exact text that replaces it (or `DROP` + reason). A 30-into-15 rebuild is 30 pairs. A table of dispositions ("rule X → merged into #1") is not a substitute. It names what changed instead of showing it.
>
> **Read the source file and copy the text directly.** Do not reconstruct from the auditor's quote (auditors can misquote too). Every BEFORE must match the source file exactly. Every DROP must reproduce the removed text in full from the source.
>
> **Every proposed feedback replacement (AFTER) must be ≤150 chars** (content only, no number prefix) **and forward-posture framed** (what TO do, not what went wrong; no leading "never"/"don't"). If an auditor proposed non-compliant text, fix it. You have the source and the intent.
>
> **The zero-file-access test:** could [USER_NAME] evaluate every change without opening a single source file? If reconstructing any BEFORE or AFTER would require the source, the review is not finished.
>
> ### Worked example: this is the bar; match it.
>
> Note the merge: two originals collapse into one new entry, shown as two BEFORE/AFTER pairs quoted in full, not one summary line.
>
> - **"Trust [USER_NAME]'s observations" + "Process screenshots as evidence" → merged into new #1 · feedback.md** · agreed
>   - BEFORE (original, verbatim in full): "**Trust [USER_NAME]'s observations.** When [USER_NAME] shows evidence (screenshots, URLs, CSS), trust it. If you can't find what [USER_NAME] is showing, the problem is your search, not [USER_NAME]'s observation."
>   - BEFORE (original, verbatim in full): "**Process screenshots as evidence, not confirmation.** When [USER_NAME] sends a screenshot, read what it actually shows. Don't scan for details that support your existing recommendation and ignore the rest.
> **Why:** Session 12: a SaaS pricing page screenshot clearly showed '1 user' on the free plan. Claude saw 'Free' and kept recommending it."
>   - AFTER (new #1, verbatim in full): "Trust [USER_NAME]'s evidence (screenshots, URLs, CSS); if you can't find what [USER_NAME] shows, your search is the problem. Read what a screenshot actually shows."
> - **DROP · "Single hyphens" · feedback.md**
>   - BEFORE (verbatim in full): "**Single hyphens (-) not double (--) in all site content text.**"
>   - reason: graduated-to-global, already in the global CLAUDE.md's voice rules.
>
> **4. Report** what you applied and whether a review doc was written.

## Step 3: Hand off
- The review writer returns its report. Report back to your caller: any kit-update result from Step 0 (the plain-language changelog, escalations, or the couldn't-check sentence), what was auto-applied, whether a `REPAIR-REVIEW.md` is waiting, and any disagreements that were resolved. (When run directly rather than as a subagent, relay this to [USER_NAME].)
- A written review doc stays in root; the next `/start` surfaces it.
- If a `CUSTOM.md` exists in this skill's folder, follow it now.
