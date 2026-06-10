---
description: Audit a project's doc system against the structure spec, auto-fix safe drift, escalate the rest. Runs every 5th session from /wrap, or on demand. Launches Opus subagents.
---

# Project Repair

Audit the project's doc system, fix what's safe, escalate what needs [USER_NAME]. Delegate the audit to Opus subagents; do not audit in the main thread.

**The project is the current working directory.** Read `~/.claude/project-template/_SPEC.md` first; it defines a correct project, and everything below checks reality against it.

## When this runs
- **Automatically:** as a step inside `/wrap`, when the new session number is divisible by 5. (`/wrap` supplies the number.)
- **On demand:** when [USER_NAME] asks, or when behavior suggests drift. No `/wrap` here to supply the number, so derive it. **Canonical rule: N = the integer in the highest-numbered note filename in `Docs_Compressions/` (zero-padded, no suffixes); an empty/absent folder = no prior sessions.** The REPAIR-REVIEW header is labelled with the *current* session number — i.e. that highest N **plus one**, the in-progress session whose note isn't written yet (empty/absent folder → `1`), exactly as `/wrap` would supply it. If that's somehow ambiguous, use the date alone.

## Step 1 — Launch two independent auditors (Opus, parallel)
Spin up TWO Opus subagents at once. Each audits independently; neither sees the other's work.

Brief each identically, with the project's absolute path filled in:

> You have zero prior context on the project at `[project path]`. Read `~/.claude/project-template/_SPEC.md` and `~/.claude/project-template/CLAUDE-SECTIONS.md`, then read that project's `CLAUDE.md`, `AGENDA.md`, and its `MEMORY.md` + `feedback.md` (in the memory safe-dir the spec names), plus the memory-directory listing AND the `Docs_Compressions/` listing in the project root. Audit the project against the spec and the section index. Check every `Docs_Compressions/` note name against the spec's integer convention (`session-NN-…`, zero-padded, no letter suffixes, no gaps) — a suffixed or gapped name dated **on or after 2026-06-05** is a mechanical finding. **Notes dated before 2026-06-05 are grandfathered (pre-convention / migrated history) — do not flag them.** Also sweep **`feedback.md`** (and any scar that's leaked into `MEMORY.md`) for **scar-framing** — an earned rule written as a past failure ("last time you did X wrong", "stop doing Y") instead of a forward posture. Per `_SPEC`'s feedback invariant and the pink-elephant principle (describe the desired behavior, not the avoided one), naming the behavior to avoid plants it, so a scar trains avoidance, not a heading. For each: if a forward posture is extractable, propose **reframing** to what TO do (keep the rule, drop the blame); if nothing but the wound remains once the blame is stripped, propose **cutting** it. Tag these `structural` so they reach [USER_NAME] — never an auto-rewrite or delete of `feedback.md`. Also check `feedback.md` against `_SPEC`'s hard limits — each entry ≤150 chars, numbered sequentially, no `Why:` lines, ≤15 entries total — and flag every violation: propose compressing over-long entries, folding `Why:` lines into the rule, and (if over 15) a purge set (priority: graduated-to-global → superseded → least-applicable). All `structural` proposals in `REPAIR-REVIEW.md`; never auto-edit feedback. Every proposed replacement for a feedback entry must itself comply: ≤150 chars (content only, no number prefix), forward-posture framed, no `Why:` lines — a non-compliant proposal gets flagged the same as a non-compliant entry. Return every deviation as a finding.

Each finding carries:
- **what** — the specific drift, with the **verbatim current text** quoted (name the file).
- **kind** — `mechanical` (objectively fixable: verbatim duplicate; a date provably past versus today; a file that shouldn't exist; a broken path; a required file missing) or `structural` (judgment: is this still relevant, should this move, is this the right shape).
- **loop** — `inner` (this project's content drifted through use) or `outer` (a violation the structure should have prevented, so it likely affects every project). Test: could this happen in any project? If yes, outer.
- **fix** — the **verbatim proposed replacement** — or, for a removal, the verbatim text being dropped + the reason. The finding must be evaluable with zero access to any source file: reproduce the current text in full — never a label, a line number, an ellipsis, or a summary of what it "said."

## Step 2 — Launch the review writer (Opus, fresh context)

**The session agent never writes the review.** By this point in the session, the session agent may be deep into context and prone to summarizing instead of quoting verbatim. A fresh Opus agent — zero accumulated context, one job — diffs the auditors' findings, applies safe fixes, writes the review doc, and resolves disagreements.

Pass both auditors' complete findings to the review writer. Do not summarize, filter, or reformat them — pass the raw output. The review writer handles everything from here.

Brief it, with the project path, memory safe-dir path, session number, and both auditors' raw findings injected:

> You are the review writer for a project repair audit. You have zero prior context. Two independent auditors have examined the project at `[project path]` and returned their findings below. Your job: diff the findings, apply safe mechanical fixes, and write the review document for anything that needs [USER_NAME]'s decision.
>
> **The source files** (read these — you will need them for verbatim quoting):
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
> **2. Apply mechanical fixes that both agree on.** Record each for the report.
> - a missing required file → stamp from `~/.claude/project-template/`.
> - a broken path or stale date → correct in place.
> - a verbatim duplicate → remove the duplicate.
> - a stray memory file (beyond `MEMORY.md` + `feedback.md` in the safe-dir) → **consolidate, don't trash.** Read it, merge durable content into `MEMORY.md` per the gate (route first; read before writing; ≤250 chars), then flag the empty husk for [USER_NAME] to delete; never delete files yourself.
> - `.DS_Store` → delete directly (system artifact, not user content).
> - any other file that shouldn't exist → flag for [USER_NAME] to delete; never delete files yourself.
>
> **3. For structural findings, or any disagreement — write the review doc.** If there are disagreements, resolve them yourself: you have both auditors' reasoning and the source files. Present your resolution clearly, noting where the auditors differed.
>
> If nothing was escalated and nothing was applied, report an all-clear and write no file.
>
> Otherwise, write `REPAIR-REVIEW.md` at `[project path]/REPAIR-REVIEW.md` using this format:
>
> ```
> # Repair Review — session [N], [date]
>
> ## Fix this project (inner)
> *Evaluable with zero file access — every change reproduces its current text in full. Test: if reconstructing the exact old or new text would need a source file, it's not finished.*
> - **[what + file]** · [agreed | auditors differ: A says…, B says…; resolved: …]
>   - BEFORE: [verbatim current text]
>   - AFTER:  [verbatim proposed text]
> - **DROP** · [verbatim removed text] · reason: [graduated-to-global | superseded | scar-only | duplicate]
>
> ## Signals for the system (outer)
> - [what] · why it's systemic: [reason] · proposed spec/skill change: [fix]
>
> ## Auto-applied (FYI, already done)
> - [what was fixed without review]
> ```
>
> ### The verbatim rules (non-negotiable)
>
> **Every change is N verbatim BEFORE/AFTER pairs — never a summary.** A change that merges, drops, or rewrites multiple entries is not one change: it is one pair *per affected entry*. Quote each original in full as its own BEFORE, paired with the exact text that replaces it (or `DROP` + reason). A 30-into-15 rebuild is 30 pairs. A table of dispositions ("rule X → merged into #1") is not a substitute — it names what changed instead of showing it.
>
> **Read the source file and copy the text directly** — do not reconstruct from the auditor's quote (auditors can misquote too). Every BEFORE must match the source file exactly. Every DROP must reproduce the removed text in full from the source.
>
> **Every proposed feedback replacement (AFTER) must be ≤150 chars** (content only, no number prefix) **and forward-posture framed** (what TO do, not what went wrong; no leading "never"/"don't"). If an auditor proposed non-compliant text, fix it — you have the source and the intent.
>
> **The zero-file-access test:** could [USER_NAME] evaluate every change without opening a single source file? If reconstructing any BEFORE or AFTER would require the source, the review is not finished.
>
> ### Worked example — this is the bar; match it.
>
> Note the merge: two originals collapse into one new entry, shown as two BEFORE/AFTER pairs quoted in full, not one summary line.
>
> - **"Trust [USER_NAME]'s observations" + "Process screenshots as evidence" → merged into new #1 · feedback.md** · agreed
>   - BEFORE (original, verbatim in full): "**Trust [USER_NAME]'s observations.** When [USER_PRONOUN_SUBJECT] shows evidence (screenshots, URLs, CSS), trust it. If you can't find what [USER_PRONOUN_SUBJECT]'s showing, the problem is your search, not [USER_PRONOUN_POSSESSIVE] observation."
>   - BEFORE (original, verbatim in full): "**Process screenshots as evidence, not confirmation.** When [USER_NAME] sends a screenshot, read what it actually shows. Don't scan for details that support your existing recommendation and ignore the rest.
> **Why:** Session 12 — a SaaS pricing page screenshot clearly showed '1 user' on the free plan. Claude saw 'Free' and kept recommending it."
>   - AFTER (new #1, verbatim in full): "Trust [USER_NAME]'s evidence (screenshots, URLs, CSS); if you can't find what [USER_PRONOUN_SUBJECT] shows, your search is the problem. Read what a screenshot actually shows."
> - **DROP · "Single hyphens" · feedback.md**
>   - BEFORE (verbatim in full): "**Single hyphens (-) not double (--) in all site content text.**"
>   - reason: graduated-to-global — already in the global CLAUDE.md's voice rules.
>
> **4. Report** what you applied and whether a review doc was written.

## Step 3 — Hand off
- The review writer returns its report. Relay it to [USER_NAME]: what was auto-applied, whether a `REPAIR-REVIEW.md` is waiting, and any disagreements that were resolved.
- A written review doc stays in root; the next `/start` surfaces it.
- Outer-loop items are the feedback to your global system: a pattern seen across projects means the fix belongs in the global layer — `~/.claude/project-template/_SPEC.md`, the templates, or the command files in `~/.claude/commands/` — so it propagates to every project.
