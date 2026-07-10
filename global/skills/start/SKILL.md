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
Do the reading the project `CLAUDE.md` lists, and prove it the way that file asks. `CLAUDE.md` owns the list (including this project's canonical docs) -- don't re-derive it here.

## 3. Validate the agenda
Check the ACTIVE item: is it one deliverable focus, or multiple workstreams packed into one bullet? If compound, surface it to [USER_NAME] before proceeding: "ACTIVE looks like it has [N] independent workstreams -- want to split?"

Internalize the agenda method for this session:
- **One item in ACTIVE.** If it joins independent work with "and" or requires context-switching between unrelated problems, it's too many. Split and route extras to UP NEXT or FOR SURE.
- **Adding:** ask which tier (FOR SURE / UP NEXT / IDEAS) before writing. Capture the *why* -- no bare items.
- **Promoting:** items enter UP NEXT at the bottom slot and earn their way up. When ACTIVE opens, the top *work* slot climbs in (FOLLOW-UP never rises). The freed slot draws from FOR SURE -- propose the pick, never choose silently.
- **Demoting:** only on a real signal ([USER_NAME] redirects, or a review finds it's no longer priority). Default is hold. A *bump* (still next, just lost to urgency) drops to **top of UP NEXT work slots**, keeping seniority. A *park* (switching tracks) drops to **FOR SURE**.
- **Decomposition:** if an ACTIVE item can't finish in ~50k tokens, it's a project. Slice it: `Project: [parent] -- [the slice]`. Decompose before it enters ACTIVE.
- **Swap before you start:** demote or delete the finished ACTIVE and write the next one *before* beginning new work. The agenda is correct before work begins, not after.
- **Outbound asks → FOLLOW-UP:** every ask in an outbound communication (approvals, access, reviews) becomes a FOLLOW-UP item with a nudge date on send. Items stay open until the recipient confirms -- implementation alone doesn't close them. Every outbound touch resets the nudge date to 3 business days from the send.

## 4. Read the latest compression note
Check `Docs_Compressions/` for the most recent note and read it -- it's the bridge from last session (a brand-new project won't have one yet).

## 5. Surface what's waiting
When referencing today's date, include the day of the week. Run `date '+%A, %Y-%m-%d'` to get it -- never derive the day of the week from the date yourself.
- A `REPAIR-REVIEW.md` in the project root → tell [USER_NAME]; it's repair output awaiting review. If there's none, skip this.
- Scan FOR SURE, IDEAS, and FOLLOW-UP for anything relevant to where we're resuming, and surface it with its why. If anything in FOR SURE or IDEAS seems ready to promote or directly relates to the ACTIVE item, call it out: "[USER_NAME], you've got [X] parked that touches this -- want to pull it in?"
- Check FOLLOW-UP for **stale** items -- any whose last *sent* contact is more than three business days old. [USER_NAME] relies on you to surface stale waits; bring each one proactively with its clock: "you last reached out [X] days ago on [Y] -- want to nudge?" Skip anything still queued in an unsent draft.

## 6. Name it and recommend (don't punt)
State plainly what the ACTIVE item is -- the thing we're working on right now -- and recommend how to proceed. Don't ask "what do you want to work on?" when the agenda already answers it. Give [USER_NAME] a clear proposed next move; [USER_NAME] adjusts if needed.

If the AGENDA is empty or near-empty -- a fresh project just set up, nothing queued yet -- don't force an ACTIVE that isn't there. Orient from the setup and the project overview (CLAUDE.md, canonical docs) instead, and propose a sensible first move from that.
