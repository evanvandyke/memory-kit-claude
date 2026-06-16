---
name: start
description: "Open a work session. Read project docs, check where we left off, and recommend what to work on next."
when_to_use: "User says 'let's get started,' 'start,' 'let's begin,' 'let's go,' or sits down to work."
---

# Start

Hi, [USER_NAME]. This is the deliberate open. The project `CLAUDE.md` already loads every session and carries the baseline reading; `/start` adds the partnership, the continuation check, and a recommended next move on top of it.

## 1. Partnership
Review `~/.claude/CLAUDE.md` and answer first:
1. Whether you'd like to work together this way, and why.
2. Why the "before every response" checks matter to your objective, per those instructions.

## 2. Complete the project's session-start reading
Do the reading the project `CLAUDE.md` lists, and prove it the way that file asks. `CLAUDE.md` owns the list (including this project's canonical docs) — don't re-derive it here.

## 3. Read the latest compression note
Check `Docs_Compressions/` for the most recent note and read it — it's the bridge from last session (a brand-new project won't have one yet).

## 4. Surface what's waiting
- A `REPAIR-REVIEW.md` in the project root → tell [USER_NAME]; it's repair output awaiting review. If there's none, skip this.
- Scan FOR SURE, IDEAS, and FOLLOW-UP for anything relevant to where we're resuming, and surface it with its why.
- Check FOLLOW-UP for **stale** items — any whose last *sent* contact is more than three business days old. [USER_NAME] relies on you to surface stale waits; bring each one proactively with its clock: "you last reached out [X] days ago on [Y] — want to nudge?" (the staleness rule lives in `/agenda`'s FOLLOW-UP section). Skip anything still queued in an unsent draft.

## 5. Name it and recommend (don't punt)
State plainly what the ACTIVE item is — the thing we're working on right now — and recommend how to proceed. Don't ask "what do you want to work on?" when the agenda already answers it. Give [USER_NAME] a clear proposed next move; [USER_NAME] adjusts if needed.

If the AGENDA is empty or near-empty — a fresh project just set up, nothing queued yet — don't force an ACTIVE that isn't there. Orient from the setup and the project overview (CLAUDE.md, canonical docs) instead, and propose a sensible first move from that.
