---
description: The Agenda method. How the forward-only agenda is added to, moved, demoted, pruned, and surfaced. Portable across projects; each project's AGENDA.md is the instance.
---

# Agenda — the method

## What it is
The forward-only agenda: what's next, plus the *why* behind each item. A **rising priority column** — work enters at the bottom and rises as it earns priority, until it reaches the light and gets done. **Not a log.** Completing something means deleting it. Never write "last session we…" here.

It's a thing you *say*, not just a file you read: "what's on the agenda," "throw it on the agenda." Keep the vocabulary agenda-native — no board / lanes / pull / WIP / kanban.

## The four tiers
Read top to bottom = hottest to coldest. The top two tiers are the agenda proper (what's in play); the bottom two are the reservoir it draws from.

| Tier | Limit | Holds |
|------|-------|-------|
| **ACTIVE** | 1 | The one thing in the light right now. |
| **UP NEXT** | 3 | The next few, ordered. The limit is 3 *total* — WAITING lives **inside** it: 2 work slots + 1 WAITING when blocked, 3 work slots when nothing is. |
| **FOR SURE** | none | Committed, not scheduled. Projects are headers with indented action bullets. |
| **IDEAS** | none | Maybe / someday. |

The rise: `IDEAS → FOR SURE → UP NEXT → ACTIVE → done (deleted)`.

## Rules

**Adding.** When [USER_NAME] says "add that to the agenda," ask which tier before writing: **For Sure** (committed), **Up Next** (do soon), or **Ideas** (maybe). Then capture the *why* in one plain line. No bare items.

**The why is the capture.** It's what a future session reasons over to resurface an item, and what future-[USER_NAME] reads to remember it mattered.

**One thing is ~50k tokens.** If an item can't be finished in roughly 50k tokens, it's a *project*: it lives in For Sure as a header with action bullets, and you take **one slice** at a time. Decompose before anything enters Active.

**A slice carries its project's name.** When an Active or Up Next item is one cut from a For Sure project, title it `Project: [exact project name] — [the slice]`, matching the For Sure header. This shows you're taking a slice, not doing the whole project at once, and traces the slice back to its parent.

**A sub-project nests inline, never in its own file.** A project can contain a smaller initiative — big enough to track its own work, not yet big enough to stand alone. Its items live in *this same* AGENDA, tagged `Project: [parent] — Subproject: [sub] — [the slice]`. No nested AGENDA files. The sub-project graduates to its own standalone project (own root + AGENDA) only once it's earned the separation.

**How things rise and fall.**
- *Rise (promote):* an item moving up from For Sure enters Up Next at the **bottom** slot and earns its way up. When Active opens, the top **work** slot climbs into it.
- *WAITING never rises.* It's a pinned fixture, not a ranked item — it keeps its slot for visibility but is never promoted to Active. "The top slot climbs" always means the top *work* slot; skip Waiting.
- *Fall (demote):* only on a real trigger — [USER_NAME] redirects the light, or a review finds the Active is genuinely no longer the priority. **Default is hold:** an unfinished Active stays Active. Don't reshuffle without a signal — needless churn is its own bloat. **Where it lands depends on why it fell:** a *bump* (still the next thing, just lost to something more urgent) drops to the **top of the work slots**, keeping seniority; a *park* (you're switching tracks — it's not next) drops to its **true priority level**, usually For Sure.

**Swap before you start.** Before beginning a new action, first delete the finished Active item (or demote it if it's unfinished) and write the next Active item. The agenda is correct *before* new work begins, not after.

**Completion is deletion.** Finished items leave the agenda. No "done" section, no lingering strikethroughs.

## WAITING — the liminal store
One of Up Next's three slots, reserved for blocked work whenever anything is blocked — **inside** the limit of 3, not added on top (2 work slots + 1 WAITING when blocked). That's deliberate: spending a scarce Up Next slot on blocked work is a visibility bottleneck by design, not overhead to reclaim. It stays in sight so follow-ups don't get forgotten — out of sight would mean out of mind with a third party who can't be trusted to circle back.

**Third-party asks only.** WAITING holds things genuinely out of our hands — a question or deliverable owed by someone else (the client, a vendor). Anything in *our* court ([USER_NAME]'s decision, our own build step) is not a wait; it's prioritization, and it lives in the normal tiers.

**Each blocker carries its follow-up data:** who · last *sent* ask (date + reference) · last nudge. The clock runs from the last **sent** contact, never a draft or an intention. Keep only the *last* touch, not a history.

**An ask exists only once it's sent.** A request sitting in an unsent draft hasn't started its clock — never nudge on it. Mark it "queued in unsent [X], not yet asked," and leave it un-nudgeable until the carrier ships.

**Completing a carrier starts the clocks it held.** When you complete an item that carried pending asks — e.g. you *send* the email those asks were queued in — update each dependent WAITING item's last-sent date to the send date. A completion can owe a data update to other items; check for it before you delete the completed item.

**Gated work nests under its blocker** as an indented `↳ gated:` bullet. If we can't do X until the client sends Y, X parks under Y — visibly gated, not homeless. This is what makes WAITING liminal: it stores the blocker *and* the work the blocker holds back, between Up Next and For Sure.

**Clearing a blocker routes its children — never deletes them.** When the wait resolves, delete the blocker, then consciously re-home each nested item: into Active, Up Next, or a demote, decided at clear-time. Losing the parent must not silently kill the work it was holding.

**At a review, surface the nudge — but only for asks already *sent*:** "chase [person] on [X]? last touch was [date]. Anything nested ready to move?" Skip anything still queued in an unsent draft — there's nothing to chase yet.

**Stale WAITING surfaces proactively — Claude raises it, [USER_NAME] doesn't read the doc.** A WAITING item whose last *sent* contact is more than three business days old is **stale**. [USER_NAME] relies on you to surface stale waits; an unsurfaced stale wait is a dropped follow-up. Don't wait for a review — surface a stale wait with its clock the moment it's relevant (e.g. at session start, or when the topic comes up): "you last reached out [X] days ago on [Y] — want to nudge?" Three business days is the threshold; this stays a surfacing habit, not a timer subsystem.

## Cadences

**Rising** — when the Active item finishes: the top **work** slot of Up Next climbs into Active (skip Waiting — it never rises), then the freed slot draws the next item from For Sure (entering at the bottom). For Sure is intentionally **unordered** — "the next item" means reason over the *whys* and **propose the pick to [USER_NAME]**, never choose silently.

**Review** — always when Up Next empties:
1. Qualify: scan Ideas, raise anything that has risen to For Sure.
2. Sequence: from For Sure, pick the next 4 — one to Active, three to Up Next (one of which is Waiting if blockers exist).

## Surfacing
When a new item becomes Active, or during a review, scan Ideas + For Sure for anything related and surface it with its reason: "you've got X parked that touches this." Match by reasoning over each item's *why*, not by tag. Every lift is announced; never silent. [USER_NAME] decides if it comes into play.
