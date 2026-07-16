---
name: wrap
description: "Close the current session. Prune the agenda, save anything worth remembering, and write a handoff note."
when_to_use: "User says 'wrap it up,' 'let's wrap,' 'we're done,' 'close the session,' or is finishing work."
---

# Wrap

Close out the session. Work through each step end to end; skip what doesn't apply; keep additions tight.

## Step 0: Session number
**Canonical rule: N = the integer in the highest-numbered note filename in `Docs_Compressions/` (zero-padded, no suffixes); an empty/absent folder = no prior sessions.** `/wrap` is closing the *current* session and about to write its note, so this session's number is that highest N **plus one** (empty/absent folder -> session 1). Hold onto N. The note filename uses it, and Step 1 checks whether it ends in 0 or 5.

## Step 1: Launch repair on cadence
If the session number ends in 0 or 5, invoke a subagent to run the `/project-repair` skill in full, passing the project's absolute path, and let it work in the background while you continue. This is mandatory when the number ends in 0 or 5, not one of the steps you may skip. Any other session number: skip this step.

## Step 2: Compress
Run `/compress` to bank the self-authored handoff note now. It works in parallel with the repair subagent when one is running.

## Step 3: Finish repair (only if Step 1 launched it)
Wait for the repair subagent to finish before continuing. The steps below edit files repair may update or audit. Waiting means driving: check the subagent's output directly each time you resume, because its completion notice may route to your caller rather than to you. If it has stalled or died, resume it or spawn a replacement; stay in this step until repair has actually finished. Relay its report to [USER_NAME]: any kit-update result, what was auto-applied, whether a `REPAIR-REVIEW.md` is waiting.

## Step 4: Validate, prune, and advance the agenda
In `AGENDA.md`:

**Validate first:**
- Is ACTIVE one item? If it contains multiple independent workstreams (joined by "and" or requiring context-switching), split: keep the primary, route extras to UP NEXT or FOR SURE.
- Walk FOLLOW-UP against the lifecycle invariant in `~/.claude/project-template/_SPEC.md` (items enter on send, close only on recipient confirmation, nudge date resets on every outbound touch) and update nudge dates and closures accordingly.
- Is the ACTIVE item sized right? If it can't finish in ~50k tokens, it's a project. Flag for slicing (`Project: [parent] → [the slice]`).

**Then prune and advance:**
- Delete completed items (completion = deletion).
- When ACTIVE opens, the top **work** slot of UP NEXT climbs in (FOLLOW-UP never rises). The freed slot draws from FOR SURE. Propose the pick, never choose silently.
- **Demotion** only on a real signal ([USER_NAME] redirects, or a review). Default is hold. A *bump* (still next, lost to urgency) drops to **top of UP NEXT work slots**, keeping seniority. A *park* (switching tracks) drops to **FOR SURE**. Never delete an unfinished item.
- When UP NEXT empties: scan IDEAS for anything that's risen to FOR SURE, then propose picks from FOR SURE to refill.

Preserve the tier headers, annotations, and description lines. They're structural. Leave the agenda correct for next session.

## Step 5: CLAUDE.md stable facts (only if changed)
Update `CLAUDE.md` only if a durable orientation fact changed this session (the stack, a convention, a canonical-doc pointer). Status and current state are the agenda's job, not this. Otherwise skip.

## Step 6: Memory per the gate
Apply the gate in `MEMORY.md` (route first, then the long-term test). Surface every write as you make it. If nothing clears the gate, say so and skip. Never create files beyond `MEMORY.md` + `feedback.md`.

Any `MEMORY.md` entry written or modified must be under 250 characters. Count before saving; if over, compress the entry until it fits.

Any `feedback.md` entry written or modified must be <=150 chars (content only, no number prefix), forward-posture framed, and carry no `Why:` line. Count before saving.

## Step 7: Recap
One line per step: "did X because Y," or "skipped X because Y."
