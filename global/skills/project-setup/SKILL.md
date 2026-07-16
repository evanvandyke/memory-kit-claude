---
name: project-setup
description: "Set up the doc/memory system in a new project. Creates CLAUDE.md, AGENDA.md, MEMORY.md, feedback.md, and reference files."
when_to_use: "User says 'set up this project' or wants to initialize the memory system in a new project."
---

# Project Setup

Stand up the project's doc system so it matches the structure spec. This is **create only**. Auditing and fixing drift in an existing project is `/project-repair`, not this.

Read `~/.claude/project-template/_SPEC.md` first. It defines the required files and what each must contain. You stamp from the templates beside it. Do not invent structure or embed your own copies.

## Step 1: Check what exists
For each file in the spec (`CLAUDE.md`, `AGENDA.md`, `MEMORY.md`, `feedback.md`): is it present and in the right place? (Setup checks presence and location only. Auditing whether an existing file has drifted in *shape* is `/project-repair`'s job, not setup's.)

- All present and correct → tell [USER_NAME] there's nothing to set up. If it's an existing project that may have drifted, point [USER_NAME] to `/project-repair`.
- Some missing or empty → continue.

Extra or bloated memory files, or drifted content in files that already exist, are repair's job, not setup's. Setup only creates what's absent.

## Step 2: Gather the project specifics
Ask [USER_NAME] (skip any already provided):
- A one-to-three-sentence project overview: what it is, the stack, the goal.
- The canonical docs: which files are this project's source of truth (README, specs, design docs, the code).
- Any project-specific session-start reading beyond the standard set.
- Any non-obvious conventions, or training-data assumptions to correct.

## Step 3: Stamp the files
Write each missing file from its template in `~/.claude/project-template/`, filling the placeholders with Step 2's answers. Leave any file that already exists and matches the spec untouched. Where an answer doesn't exist yet (a fresh project with no canonical docs or durable facts), note the emptiness explicitly (e.g. canonical-docs → "None yet: add as created") instead of leaving a dangling placeholder; leave body-fact prompts (MEMORY's sections) as prompts to fill later.

When stamping `MEMORY.md` and `feedback.md`, fill the frontmatter `name:` and `description:` fields too. They ship as `[project-slug]` / `[project]` placeholders, not just the body, so the harness's recall metadata isn't left as a literal placeholder. The slug here is the short human-readable project slug (e.g. `my-recipe-box`), not the harness safe-dir slug.

For `CLAUDE.md`, stamp the CORE sections, then add the OPTIONAL sections from `~/.claude/project-template/CLAUDE-SECTIONS.md` that fit this project per Step 2's answers (e.g. Key People / Relationship Boundaries for a client project, Voice Rules for one with client-facing writing). Add only what fits. When stamping `CLAUDE.md`, replace the `[MEMORY-SAFE-DIR]` placeholder in the session-start reading list with this project's ACTUAL memory safe-dir path, the same path you derive to place `MEMORY.md`/`feedback.md` (per `_SPEC`'s slug rule), so the reading list points sessions at where those files really live.

## Step 3.5: Track new files
If the project is a git repo, `git add` the newly created root files (`CLAUDE.md`, `AGENDA.md`) so they're tracked from the start. (Memory files live in the safe-dir outside the repo, so git doesn't apply to them.)

## Step 4: Summary
Report: files created and with what, anything left for [USER_NAME] to fill in, and confirm the project now matches the spec.
