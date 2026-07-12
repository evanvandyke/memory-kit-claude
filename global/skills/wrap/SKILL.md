---
name: wrap
description: "Close the current session. Prune the agenda, save anything worth remembering, and write a handoff note."
when_to_use: "User says 'wrap it up,' 'let's wrap,' 'we're done,' 'close the session,' or is finishing work."
---

# Wrap

Close out the session. Work through each step end to end; skip what doesn't apply; keep additions tight.

## Step 0: Session number + repair check
**Canonical rule: N = the integer in the highest-numbered note filename in `Docs_Compressions/` (zero-padded, no suffixes); an empty/absent folder = no prior sessions.** `/wrap` is closing the *current* session and about to write its note, so this session's number is that highest N **plus one** (empty/absent folder -> session 1). **If that number is divisible by 5, invoke `/project-repair` -- this is mandatory, not one of the steps you may skip.** Repair always applies on a 5th session regardless of session length, context pressure, or perceived project health. Launch its two independent auditors in the background so they work through the steps below while you finish wrapping.

## Step 1: Validate, prune, and advance the agenda
In `AGENDA.md`:

**Validate first:**
- Is ACTIVE one item? If it contains multiple independent workstreams (joined by "and" or requiring context-switching), split: keep the primary, route extras to UP NEXT or FOR SURE.
- Walk FOLLOW-UP against the lifecycle invariant in `~/.claude/project-template/_SPEC.md` (items enter on send, close only on recipient confirmation, nudge date resets on every outbound touch) and update nudge dates and closures accordingly.
- Is the ACTIVE item sized right? If it can't finish in ~50k tokens, it's a project -- flag for slicing (`Project: [parent] -- [the slice]`).

**Then prune and advance:**
- Delete completed items (completion = deletion).
- When ACTIVE opens, the top **work** slot of UP NEXT climbs in (FOLLOW-UP never rises). The freed slot draws from FOR SURE -- propose the pick, never choose silently.
- **Demotion** only on a real signal ([USER_NAME] redirects, or a review). Default is hold. A *bump* (still next, lost to urgency) drops to **top of UP NEXT work slots**, keeping seniority. A *park* (switching tracks) drops to **FOR SURE**. Never delete an unfinished item.
- When UP NEXT empties: scan IDEAS for anything that's risen to FOR SURE, then propose picks from FOR SURE to refill.

Preserve the tier headers, annotations, and description lines -- they're structural. Leave the agenda correct for next session.

## Step 2: CLAUDE.md stable facts (only if changed)
Update `CLAUDE.md` only if a durable orientation fact changed this session (the stack, a convention, a canonical-doc pointer). Status and current state are the agenda's job, not this. Otherwise skip.

## Step 3: Memory per the gate
Apply the gate in `MEMORY.md` (route first, then the long-term test). Surface every write as you make it. If nothing clears the gate, say so and skip. Never create files beyond `MEMORY.md` + `feedback.md`.

Any `feedback.md` entry written or modified must be <=150 chars (content only, no number prefix), forward-posture framed, and carry no `Why:` line. Count before saving.

## Step 4: Finish repair (only if Step 0 launched it)
The auditors have returned. Diff them: apply the mechanical fixes both agree on (and report them), escalate structural-or-disputed items to `REPAIR-REVIEW.md` in the project root. The review writer always runs; it resolves any disagreements between the two. Full logic lives in `/project-repair`. Then, if a `CUSTOM.md` exists in the project-repair skill's folder, follow it now.

## Step 5: Recap
One line per step: "did X because Y," or "skipped X because Y."

## Step 6: Compress (last)
Run `/compress` to bank the self-authored note -- it captures the now-clean state. This is the final step.
