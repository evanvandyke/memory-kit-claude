---
name: [project-slug]-memory
description: Long-term memory for [project] — durable facts about the project and how [USER_NAME] works. One file; read fully at session start.
metadata:
  type: project
---

# [Project] — Memory

Long-term memory: durable facts about the project and about how [USER_NAME] works. NOT episodic. What happened this session is not memory; that is the compression note's job. Fast test before saving: would long-term memory hold this, or is it just what happened recently?

## Before saving — route it
Most "I should remember this" impulses belong elsewhere. If it fits a row, it goes THERE:

| If it's… | It belongs in… |
|----------|----------------|
| Forward work: a task, a next step, an idea | the **agenda** (`AGENDA.md`) |
| A technical fact: a class name, a model ID, a config value | the **code** (or a comment) |
| Detail covered by a canonical doc | that **canonical doc** |
| What happened this session | the **compression note** |
| A behavioral rule earned together | **feedback.md** |

## Then gate what's left
1. **Long-term?** Still true in ~10 sessions, or for the rest of the project? If not, it's episodic → compression note.
2. **A durable fact about the project, or about how [USER_NAME] works?** If yes and it survived routing, it's memory.

Default is NO. When unsure, it is not memory.

## NO SILENT WRITES
Surface every write as you make it: "saving to long-term memory: ___." Read the relevant section first; if it's already covered, update in place. Keep each entry under 250 characters.

## Two files only
`MEMORY.md` (this file) + `feedback.md`. Do not create others.

---

## Project context
[Durable facts about the project that aren't captured in a canonical doc.]

## How [USER_NAME] works
[Durable facts about [USER_NAME] specific to this collaboration.]
