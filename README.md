# Memory Kit Claude

A managed documentation and memory system for Claude Code that replaces the default unbounded memory with a structured, self-healing alternative.

## The Problem

Claude Code's built-in memory system saves each fact as a separate `.md` file in `~/.claude/projects/*/memory/`. There's no consolidation, no deduplication, and no size limit. Over a few weeks of real use, a project accumulates 20, 30, 40+ individual memory files, many of them contradictory or stale.

When a session starts, Claude tries to honor all of them simultaneously. Guidance from session 3 conflicts with guidance from session 15. A preference you corrected weeks ago still lives in an old file alongside the correction. The model doesn't know which to trust, so it hedges, drifts, or flip-flops between sessions. This is the "drift" that makes long-running Claude Code projects feel progressively worse.

Check your own state:

```bash
find ~/.claude/projects/*/memory/ -type f -name "*.md" 2>/dev/null | wc -l
```

If that number is north of 10 for any single project, you're already in the zone where contradictions accumulate and session quality degrades.

## What You Get

**5 skills** (available in every project):

- `/start` - Open a session deliberately. Reads your project docs, picks up from the last compression note, surfaces what's waiting, and recommends the next move.
- `/wrap` - Close a session cleanly. Prunes the agenda, saves memory through a quality gate, triggers repair on cadence, and banks a handoff note.
- `/compress` - Write your own handoff note before context compacts, so your future self continues from your chosen context instead of the system's summary.
- `/project-setup` - Set up a new project's doc system from templates in one pass.
- `/project-repair` - Audit a project against the structure spec, auto-fix safe drift, escalate the rest. Runs every 5th session automatically.

**A template system** that creates consistent project structure: `CLAUDE.md` (project instructions), `AGENDA.md` (work tracker), `MEMORY.md` (curated long-term memory), `feedback.md` (behavioral rules earned together), `_SPEC.md` (the structure spec, the source of truth the skills audit against), and `CLAUDE-SECTIONS.md` (the canonical menu of optional CLAUDE.md sections).

**A self-healing repair cycle** that catches and fixes drift before it compounds. Two independent auditors examine the project, a fresh agent reconciles their findings, mechanical fixes are applied automatically, and structural questions are escalated for your review.

**A self-updating install** that keeps the kit current without you managing it. On the repair cadence (every 5th session), the install checks the kit's update channel for improvements. Anything it finds is explained in plain language from the changelog, backed up automatically first, and applied only if you turned on automatic updates when you set the kit up. Changed your mind? Ask Claude to "undo the last kit update" and it rolls back.

## Quick Start

Open Claude Code in any project and paste this one prompt:

```
Fetch https://raw.githubusercontent.com/evanvandyke/memory-kit-claude/main/setup.md and save it in this project as memory-kit-setup.md. Then read it and follow it exactly. It is a one-time setup wizard. Start at Step 1.
```

That's the whole install. Claude fetches the wizard, clones what it needs to a temp folder behind the scenes, walks you through the setup, and cleans up after itself. You just approve the steps as you go. The whole thing takes about 30 to 45 minutes.

If the fetch fails, download `setup.md` from this repo (click the file, then the download button), drop it in any project folder, and tell Claude:

```
Read setup.md and follow it exactly. It is a one-time setup wizard. Start at Step 1.
```

## The Daily Rhythm

The whole system reduces to three moments:

1. **Start the session.** Type `/start`. Claude reads the project docs, picks up from where you left off, and recommends what to work on.
2. **Work.** The agenda manages itself through natural conversation. Just tell Claude what you're working on or what's coming up, and it handles the rest.
3. **Close the session.** Type `/wrap`. The agenda gets pruned, memory gets updated through the quality gate, and a handoff note gets written for next time.

That's it. The repair cycle runs itself every 5th session. You'll only hear about it when something needs your decision.

## How It Works

The system is built on a few core ideas: a two-file memory model with quality gates instead of unbounded accumulation, a forward-only agenda that deletes completed work instead of archiving it, session lifecycle skills that open and close cleanly, and a self-healing repair cycle that catches drift before it compounds.

For the full architecture, see [docs/how-it-works.md](docs/how-it-works.md).

## License

MIT. See [LICENSE](LICENSE).
