# scripts/

## kit-update-check.sh -- dry-run update classifier (Layer 1)

Clones the kit's update source, reads `install-manifest.json` at the installed
commit AND at HEAD, classifies every manifest entry against a live install,
and writes a report of what a real update run WOULD do.

**This script is dry-run only.** It never installs, updates, moves, or deletes
anything. The only writes it makes are the report file and a transient lock
dir (`<home>/.kit-update.lock`, mkdir mutex with PID + timestamp inside;
locks older than 30 minutes are treated as stale and broken). The clone goes
to a mktemp scratch dir that is removed on exit.

### Usage

```
scripts/kit-update-check.sh --home <dir> [--config <path>] [--upstream <url-or-path>] [--report <path>]
```

| Parameter | Meaning | Default |
|---|---|---|
| `--home <dir>` | The live root to check (the directory playing the role of `~/.claude`). **Required** -- there is deliberately no default, so the script never touches a home you did not name explicitly. | none |
| `--config <path>` | Kit config JSON | `<home>/kit-config/memory-kit-claude.json` |
| `--upstream <u>` | Git URL or local path of the kit repo; overrides the config's `update_source`. Local paths are cloned via `file://`. | config's `update_source` |
| `--report <path>` | Where to write the markdown report | `./kit-update-report.md` |

### Exit codes

| Code | Meaning |
|---|---|
| 0 | All entries in-sync -- nothing to do |
| 1 | Updates available (only kit-ahead / new / missing states present) |
| 2 | Escalations present (live-ahead / diverged / conflict / removed-upstream / retired-present / failed generated check) -- a human needs to look |
| 3 | Error: clone failed, invalid manifest, `manifest_schema` newer than the script ("update the updater first"), bad arguments, or another update already holds the lock |
| 4 | No kit config found -- install predates the update system; the adoption offer is printed, nothing written |

### The report

Markdown with three parts:

1. **Entries table** -- per entry: `install_to`, classified state, and the
   action a real run WOULD take.
2. **Changelog** -- the authored `CHANGELOG.md` lines added between
   `installed_commit` and HEAD (or a note that no changelog exists).
3. **Machine-readable section** -- between `<!-- MACHINE-BEGIN -->` and
   `<!-- MACHINE-END -->`, one tab-separated line per entry:
   `state`, `install_to`, `sha256(render@installed)`, `sha256(render@HEAD)`,
   `sha256(live)` (`-` where not applicable). Tests and verifiers parse this,
   never the prose.

### How it classifies

Comparison always runs against the personalized render (`[USER_NAME]`
replaced literally with the config's `user_name` -- no regex, no sed
metacharacter exposure), never against raw sources. Every entry is
classified on every run; `HEAD == installed_commit` does not skip live-drift
detection. Retired entries get a presence check only. `generated` entries
are never content-compared; only their section checks run.

### Testing

`tests/run-tests.sh` builds a fixture kit repo and fake home dirs in a temp
dir and asserts exit codes plus per-entry machine states for the full
classifier fixture matrix. Run it from anywhere; it never touches the real
`~/.claude/`.
