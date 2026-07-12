# Changelog

Plain-language notes on what changed in the kit, newest first. When the kit updates on your machine, the summary you see is assembled from these lines.

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
