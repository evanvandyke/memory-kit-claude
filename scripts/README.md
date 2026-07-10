# scripts/

## kit-update-check.sh -- update classifier and applier (Layer 1)

Clones the kit's update source, reads `install-manifest.json` at the installed
commit AND at HEAD, classifies every manifest entry against a live install,
and writes a report. **The default invocation is a dry run**; writing requires
the explicit `--apply` flag.

**Dry-run guarantee (default invocation).** Without `--apply` the script never
installs, updates, moves, or deletes anything. The only writes it makes are
the report file and a transient lock dir (`<home>/.kit-update.lock`, mkdir
mutex with PID + timestamp inside; locks older than 30 minutes are treated as
stale and broken). The clone goes to a mktemp scratch dir removed on exit.

### Usage

```
scripts/kit-update-check.sh --home <dir> [--apply] [--config <path>] [--upstream <url-or-path>] [--report <path>]
scripts/kit-update-check.sh --undo --home <dir> [--report <path>]
```

| Parameter | Meaning | Default |
|---|---|---|
| `--home <dir>` | The live root to check (the directory playing the role of `~/.claude`). **Required** -- there is deliberately no default, so the script never touches a home you did not name explicitly. | none |
| `--apply` | Apply eligible updates (see below) | off (dry run) |
| `--undo` | Restore from the newest backup dir (see below) | off |
| `--config <path>` | Kit config JSON | `<home>/kit-config/memory-kit-claude.json` |
| `--upstream <u>` | Git URL or local path of the kit repo; overrides the config's `update_source`. Local paths are cloned via `file://`. | config's `update_source` |
| `--report <path>` | Where to write the markdown report | `./kit-update-report.md` |

### Apply mode (`--apply`)

After classification, kit-owned entries in state kit-ahead / new / missing
(including pending renames) are written -- **if** the config records
`auto_update: true` (the recorded opt-in). Every write follows the design's
discipline:

1. The rendered content goes to a sidecar file next to the destination.
2. Any existing live file is backed up first to
   `<home>/kit-backups/<timestamp>/<install_to>`. An existing backup file is
   never overwritten; the backup step is skipped only when there is no
   existing live file. A plain-language `RESTORE.md` lands in every backup
   dir, alongside a machine-readable `.kit-backup-manifest.tsv` that drives
   `--undo`.
3. The sidecar is `mv`'d into place (atomic on APFS), and the manifest
   entry's `mode` is applied when given.

Never written, even with `--apply`:

- **user-owned entries** -- never, in any state;
- **live-ahead / diverged / conflict** states -- escalated, never touched;
- **`consent: per-change` entries** -- reported as "needs individual
  approval"; applying those is repair's interactive job, not this script's;
- **everything, when `auto_update` is false** -- the report lists what WOULD
  apply, each with the Replace/Keep vocabulary; `declined` bookkeeping stays
  as-is;
- **retired entries** are never deleted: a retired file found live is MOVED
  to `<home>/kit-retired/<date>/` with a report note. Files removed upstream
  without a `retired` tombstone get the same move, plus the loud
  removed-upstream escalation.

**Anchor advance, written last.** After all writes, every entry is re-verified
against `render(HEAD)`. Only if all copied entries are then byte-identical to
their render (or retired-absent / declined-recorded) does the script write the
new `installed_commit` + `installed_at` to the config -- once, at the very
end, via sidecar+mv, after backing the config up too. Otherwise the anchor
holds and the report says so; the next run re-classifies whatever landed as
already-current and finishes the job (torn runs self-heal, never latch).

The lock covers the whole apply run.

### Undo (`--undo`)

Restores every file recorded in the NEWEST `kit-backups/<timestamp>/` dir
(sidecar+mv), after first backing up the current state to a new backup dir --
so undo is itself undoable, and running `--undo` twice round-trips back to
the applied state. Files the update had newly installed are moved out of the
live tree into the new backup dir (a move, never a delete). Needs no clone
and no config; refuses politely (exit 3) if no backups exist. Retired files
under `kit-retired/` are not covered by undo; they stay put.

### Exit codes

Meanings are the same with or without `--apply`:

| Code | Meaning |
|---|---|
| 0 | All entries in-sync / nothing left to do |
| 1 | Updates available (dry run) -- or, with `--apply`, updates REMAINED UNAPPLIED (e.g. `auto_update` is false, or per-change consent is pending) |
| 2 | Escalations present (live-ahead / diverged / conflict / removed-upstream / retired-present / failed generated check) -- a human needs to look |
| 3 | Error: clone failed, invalid manifest, `manifest_schema` newer than the script ("update the updater first"), bad arguments, missing/empty `user_name` when the manifest has personalize:true entries, unwritable report path, another update already holds the lock, or `--undo` with no backups to restore |
| 4 | No kit config found -- install predates the update system; the adoption offer is printed, nothing written |

### The report

Markdown with these parts:

1. **Entries table** -- per entry: `install_to`, classified state, and the
   action a real run WOULD take.
2. **Applied section** (apply runs only) -- per entry, what was actually done
   and where the backup went; the backup dir; whether the anchor advanced.
   Every apply summary re-states the recorded opt-in and how to reverse it
   ("undo the last kit update" / "turn off auto-updates").
3. **Changelog** -- the authored `CHANGELOG.md` lines added between
   `installed_commit` and HEAD (or a note that no changelog exists).
4. **Machine-readable sections** -- between `<!-- MACHINE-BEGIN -->` and
   `<!-- MACHINE-END -->`, one tab-separated line per entry:
   `state`, `install_to`, `sha256(render@installed)`, `sha256(render@HEAD)`,
   `sha256(live)` (`-` where not applicable). Apply and undo runs add an
   `<!-- APPLIED-BEGIN -->` / `<!-- APPLIED-END -->` block: `action`,
   `install_to`, `backup path`. Tests and verifiers parse these, never the
   prose.

### How it classifies

Comparison always runs against the personalized render (`[USER_NAME]`
replaced literally with the config's `user_name` -- no regex, no sed
metacharacter exposure), never against raw sources. Every entry is
classified on every run; `HEAD == installed_commit` does not skip live-drift
detection. Retired entries get a presence check only. `generated` entries
are never content-compared; only their section checks run.

### Testing

`tests/run-tests.sh` builds fixture kit repos and fake home dirs in a temp
dir and asserts exit codes plus per-entry machine states for the full
classifier fixture matrix, and the apply/undo write path: backup-first
discipline, protected states left byte-untouched, anchor advance only on
all-clean runs, a SIGKILL between the file writes and the anchor write
(self-healing), and byte-identical undo round-trips. Run it from anywhere;
it never touches the real `~/.claude/`.
