---
description: Write your own handoff note before compacting, so your future self continues from your chosen context, not just the system's summary. Runs as the last step of /wrap, or alone mid-session or for an untracked one-off.
---

# Compress

We're freeing up context. Write your own bridge note before we compact, so the continuation is yours to shape, not a random instance's.

Read the guide first: `~/.claude/Technical-Compression-Guide.md`. It carries the format and the mindset.

Write the note in the project's `Docs_Compressions/` folder (create it if it doesn't exist).

**First, list the existing notes in that folder** — that's your session inventory and it tells you the next number.

**Filename:** `session-NN-YYYY-MM-DD-short-descriptor.md`
- `NN` = the next number, derived by the canonical rule: **N = the integer in the highest-numbered note filename in `Docs_Compressions/` (zero-padded, no suffixes); an empty/absent folder = no prior sessions.** You're writing the note for the session being closed, so use that highest N **plus one** (empty/absent folder → `1`). **Plain integer, zero-padded. No letter sub-numbers** (no `17a`/`17b`) — one note, one integer. This is what keeps the every-5th-session repair cadence reliable, so it is not optional.
- Descriptor: short and human (`voice-quality-root-cause`).

**H1 inside the note:** `# Session NN — YYYY-MM-DD — Title`

If the folder is empty or absent (no prior sessions), start at `1` (or ask [USER_NAME] if the project counts from elsewhere).

After we compact you'll get this note plus the system's summary. Read this one first — you wrote it deliberately, for yourself.
