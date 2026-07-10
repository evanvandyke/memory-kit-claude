# Changelog

Plain-language notes on what changed in the kit, newest first. When the kit updates on your machine, the summary you see is assembled from these lines.

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
