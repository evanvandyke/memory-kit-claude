# Claude Memory Kit

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

**6 skills** (available as slash commands in every project):

- `/start` - Open a session deliberately. Reads your project docs, picks up from the last compression note, surfaces what's waiting, and recommends the next move.
- `/wrap` - Close a session cleanly. Prunes the agenda, saves memory through a quality gate, triggers repair on cadence, and banks a handoff note.
- `/compress` - Write your own handoff note before context compacts, so your future self continues from your chosen context instead of the system's summary.
- `/agenda` - Manage a forward-only priority agenda. Four tiers, rising priority, completed items deleted instead of archived.
- `/project-setup` - Set up a new project's doc system from templates in one pass.
- `/project-repair` - Audit a project against the structure spec, auto-fix safe drift, escalate the rest. Runs every 5th session automatically.

**A template system** that stamps consistent project structure: `CLAUDE.md` (project instructions), `AGENDA.md` (work tracker), `MEMORY.md` (curated long-term memory), `feedback.md` (behavioral rules earned together), `_SPEC.md` (the structure spec, the source of truth the skills audit against), and `CLAUDE-SECTIONS.md` (the canonical menu of optional CLAUDE.md sections).

**A self-healing repair cycle** that catches and fixes drift before it compounds. Two independent auditors examine the project, a fresh agent reconciles their findings, mechanical fixes are applied automatically, and structural questions are escalated for your review.

## Quick Start

Open Claude Code in any project and paste this one prompt:

```
Clone https://github.com/evanvandyke/claude-memory-kit.git into the home folder, then read claude-memory-kit/setup.md and follow it exactly. It is a one-time setup wizard. Start at Step 1.
```

That's the whole install. Claude runs the clone itself; you just approve it. The setup wizard then walks you through personalizing and installing the system. It takes about 15 to 30 minutes.

If the clone fails, download the repo as a ZIP from GitHub (green "Code" button, then "Download ZIP"), unzip it into your home folder, and tell Claude:

```
Find the claude-memory-kit folder in my home directory (it may be named claude-memory-kit-main), then read its setup.md and follow it exactly. Start at Step 1.
```

## The Daily Rhythm

The whole system reduces to three moments:

1. **Start the session.** Say `/start`. Claude reads the project docs, picks up from where you left off, and recommends what to work on.
2. **Work.** The agenda manages itself through natural conversation. Say `/agenda add [idea]` when something comes up.
3. **Close the session.** Say `/wrap`. The agenda gets pruned, memory gets updated through the quality gate, and a compression note gets written for next time.

That's it. The repair cycle runs itself every 5th session. You'll only hear about it when something needs your decision.

## How It Works

The system is built on a few core ideas: a two-file memory model with quality gates instead of unbounded accumulation, a forward-only agenda that deletes completed work instead of archiving it, session lifecycle skills that open and close cleanly, and a self-healing repair cycle that catches drift before it compounds.

For the full architecture, see [docs/how-it-works.md](docs/how-it-works.md).

## License

MIT. See [LICENSE](LICENSE).
