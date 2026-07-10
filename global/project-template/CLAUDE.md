# [Project] -- Session Instructions

Partnership principles live in `~/.claude/CLAUDE.md` (already loaded every session). This file is project-specific only. It loads every session and stays in context the whole time, so keep it lean: orientation and pointers, never a state log.

## At session start, read in order
1. `AGENDA.md` (project root) -- what's next, and why.
2. `MEMORY.md` + `feedback.md` -- long-term context and earned rules. **These live in this project's harness memory safe-dir, NOT the project root.** (The harness surfaces the path and the memory itself in context at session start.)
3. The canonical docs below.

Prove you read them by summarizing their current state in your first response. If you can't summarize it, you didn't read it -- go read it before doing anything else.

**At session end:** run `/wrap`.

## Canonical docs (this project's source of truth)
The handful of documents that are authoritative for this project -- the ones a fresh session reads to get up to speed, and where durable facts live instead of memory. Architecture, decisions, and specs live in these docs (and the code), not in this file.

Examples: `README.md` (overview + architecture) · a product or spec doc · a design doc · the key source files. List the real ones:
-

## Project overview
[One to three sentences: what this is, the stack, the goal. Orientation only.]

---
Need a section beyond these? The canonical menu of project sections, each with its purpose, is `~/.claude/project-template/CLAUDE-SECTIONS.md`. Add only what fits; keep this file lean.
