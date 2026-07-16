# Changelog

Plain-language notes on what changed in the kit, newest first. When the kit updates on your machine, the summary you see is assembled from these lines.

## July 16, 2026 update

- All kit templates and skills now use plain punctuation (commas, colons, periods) instead of double dashes. Your project files stamped from older templates will be gently restamped to match at their next checkup; that is this change propagating, not something wrong.
- Compression notes get a new heading format inside the note: `# Session NN (YYYY-MM-DD): Title`. Existing notes keep their old headings; only new notes use it.
- Memory entries now get their 250-character limit checked at the moment they're written during wrap-up, instead of waiting for a checkup to catch oversized entries later.
- The checkup coordinator and session wrap-up now actively shepherd their helper agents: if a helper stalls or quietly finishes, they check its output and restart it if needed, so checkups can't hang waiting on a helper that already stopped.
- Project-slice agenda titles use an arrow instead of a double dash: `Project: [parent] → [the slice]`. Existing agenda items keep working; new slices use the arrow.

## July 15, 2026 update

- The session-number check at wrap-up now asks "does the session number end in 0 or 5" instead of "is it divisible by 5", so the every-5th-session checkup can't be missed through a mental-math slip.
- Every project CLAUDE.md must carry its session-end wrap line; a missing line is now a checkup finding, so a project can't silently drop off the checkup schedule.
- The checkup's helper agents now skip optional consultation tools that could stall a run, keeping checkups moving.

## July 11, 2026 update

- Fresh installs now connect to the kit's update channel during setup, so a brand-new install can keep itself current instead of being frozen at the version it was installed with.
- The setup wizard installs the update checker and records your install version and name, then hands off to the same automatic check that runs every few sessions -- explained in plain language, backed up first, applied automatically once you opt in during setup, and undoable anytime.
- The project checkup gained one small extension point: if a `CUSTOM.md` file exists in the checkup skill's folder, it runs those extra steps at the end. The kit never installs or updates that file, so on a standard install it doesn't exist and the checkup works exactly as before.
- The session checkup now runs as its own helper from start to finish, instead of being split across two skills. Session wrap-up simply hands the whole checkup off in one piece, so its steps can't drift apart over time.
- Checkup reports are now labeled by project name and date, so a saved report tells you at a glance which project it's for and when it ran.
- Session wrap-up got a smarter order: the handoff note is written while the checkup runs, and the end-of-session cleanup happens after the checkup finishes -- so cleanup always follows the newest rules instead of catching up next session.

## July 10, 2026 update

This is the first changelog entry -- changes older than this predate the changelog.

- The agenda method now lives in the AGENDA file itself, so the rules travel with the file they govern.
- The /start skill got leaner: it points at the agenda's own rules instead of re-teaching them.
- The /wrap skill now enforces the agenda rules when it prunes at session end.
- The structure spec now defines what a single ACTIVE item means and when FOLLOW-UP items close.
- Feedback entries get a durability check during project repair, so only rules that hold up long-term stay.
- Every project CLAUDE.md spells out where the memory files live again, so a fresh session can always find them.
- The retired /agenda skill is fully tombstoned -- it announces itself as retired and will not run on its own.
- Skill counts and file paths were corrected across the docs to match what actually ships.
- The kit now ships an update checker (kit-scripts/kit-update-check.sh) that can check for kit updates and apply them, with automatic backups and an undo.
- New projects now get a "Verify before assuming" section in their CLAUDE.md -- written notes drift, so check the current state before acting on them.
- Update reports now read in plain language: a "What changed" summary, clear per-file actions like "kept your version", and a "Needs your attention" section whenever something needs a decision from you.
- Follow-up items that are missing their sent/nudge dates now get flagged at session start, so a wait can't quietly go untracked.
