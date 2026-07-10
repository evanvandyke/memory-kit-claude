#!/bin/bash
# kit-update-check.sh -- kit update classifier and applier for memory-kit-claude.
#
# Layer 1 of the outer-loop cascade (see outer-loop-v2.1 design). Clones the
# kit's update source, reads the install manifest at the installed commit AND
# at HEAD, classifies every entry against the live install, and writes a
# report. THE DEFAULT INVOCATION IS A DRY RUN: without --apply it never
# applies anything.
#
# DRY-RUN GUARANTEE (default invocation): the only writes this script makes are
#   1. the report file (--report), and
#   2. the lock dir <home>/.kit-update.lock (mkdir mutex; PID + timestamp
#      inside; a lock older than 30 minutes is treated as stale and broken).
# Everything else -- the live tree, the config, the clone's origin -- is
# strictly read-only. The clone itself goes to a mktemp scratch dir that is
# removed on exit.
#
# APPLY MODE (--apply): after classification, kit-owned entries in state
# kit-ahead / new / missing (including pending renames) are written -- IF the
# config records auto_update: true. Write discipline (per the design): the
# rendered content goes to a sidecar file; any existing live file is backed
# up first to <home>/kit-backups/<timestamp>/<install_to> (an existing backup
# file is never overwritten; backup is skipped only when there is no existing
# live file); then the sidecar is mv'd into place (atomic on APFS); the
# manifest entry's mode is set if given. A RESTORE.md lands in every backup
# dir. Retired entries found live are MOVED to <home>/kit-retired/<date>/
# (a move, never a delete). NEVER written, even with --apply: user-owned
# entries; live-ahead / diverged / conflict states; entries with
# consent: per-change (reported as "needs individual approval"); and
# everything when auto_update is false (the report lists what WOULD apply,
# with the Replace/Keep vocabulary). installed_commit advances ONLY at the
# very end, written once via sidecar+mv, and only if every copied entry then
# matches render(HEAD) (or is retired-absent / declined) -- so a crash
# mid-run leaves the anchor in place and the next run self-heals.
#
# UNDO (--undo): restores every file recorded in the NEWEST
# <home>/kit-backups/<timestamp>/ dir (sidecar+mv), after first backing up
# the current state to a new backup dir -- undo is itself undoable. Needs no
# clone and no config. Refuses politely if no backups exist. Retired files
# moved to <home>/kit-retired/ are not covered by undo; they stay put.
#
# USAGE:
#   kit-update-check.sh --home <dir> [--apply] [--config <path>]
#                       [--upstream <url-or-path>] [--report <path>]
#   kit-update-check.sh --undo --home <dir> [--report <path>]
#
# PARAMETERS:
#   --home <dir>       REQUIRED. The live root to check (the directory that
#                      plays the role of ~/.claude). There is deliberately no
#                      default: the script never touches a home you did not
#                      name explicitly.
#   --apply            Apply eligible updates (see APPLY MODE above).
#   --undo             Restore from the newest backup dir (see UNDO above).
#   --config <path>    Kit config JSON. Default: <home>/kit-config/memory-kit-claude.json
#   --upstream <u>     Git URL or local path of the kit repo; overrides the
#                      config's update_source. Local paths are cloned via file://.
#   --report <path>    Where to write the markdown report. Default: ./kit-update-report.md
#
# EXIT CODES (same meanings with or without --apply):
#   0  all entries in-sync / nothing left to do
#   1  updates available (dry run) -- or, with --apply, updates REMAINED
#      UNAPPLIED (auto_update is false, or per-change consent is pending)
#   2  escalations present (live-ahead / diverged / conflict / removed-upstream /
#      retired-present / failed generated check) -- a human needs to look
#   3  error: clone failed, invalid or unreadable manifest, manifest_schema
#      newer than this script understands ("update the updater first"),
#      bad arguments, missing/empty user_name when the manifest has
#      personalize:true entries, report path unwritable, another update
#      already holds the lock, or --undo with no backups to restore
#   4  no kit config found -- this install predates the update system; the
#      adoption offer text is printed and nothing is written
#
# States emitted in the machine-readable report section:
#   in-sync, kit-ahead, already-current, live-ahead, diverged, new, missing,
#   conflict, removed-upstream, retired-present, retired-absent,
#   generated-ok, generated-failed, declined-pending
#
# Requires: git, python3 (JSON parsing), shasum, awk. Runs under macOS
# /bin/bash 3.2 (no associative arrays, no bash-4-isms).

KIT_NAME="memory-kit-claude"
MANIFEST_NAME="install-manifest.json"
MAX_SCHEMA=1
LOCK_STALE_SECS=1800

HOME_DIR=""
CONFIG=""
UPSTREAM_OVERRIDE=""
REPORT="./kit-update-report.md"
APPLY=0
UNDO=0

usage() { awk 'NR>1 && /^#/ { sub(/^# ?/,""); print; next } NR>1 { exit }' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --home)     HOME_DIR="$2"; shift 2 ;;
    --config)   CONFIG="$2"; shift 2 ;;
    --upstream) UPSTREAM_OVERRIDE="$2"; shift 2 ;;
    --report)   REPORT="$2"; shift 2 ;;
    --apply)    APPLY=1; shift ;;
    --undo)     UNDO=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "kit-update-check: unknown argument: $1" >&2; exit 3 ;;
  esac
done

if [ "$APPLY" = "1" ] && [ "$UNDO" = "1" ]; then
  echo "kit-update-check: --apply and --undo are mutually exclusive." >&2
  exit 3
fi

if [ -z "$HOME_DIR" ]; then
  echo "kit-update-check: --home <dir> is required (no default on purpose: this script never guesses at a live root)." >&2
  exit 3
fi
if [ ! -d "$HOME_DIR" ]; then
  echo "kit-update-check: --home '$HOME_DIR' is not a directory." >&2
  exit 3
fi
[ -n "$CONFIG" ] || CONFIG="$HOME_DIR/kit-config/$KIT_NAME.json"

# --------------------------------------------- shared scratch / lock / write machinery
SCRATCH=""
LOCKDIR=""
LOCKED=0

cleanup() {
  [ "$LOCKED" = "1" ] && rm -rf "$LOCKDIR"
  rm -rf "$SCRATCH"
}

write_lock_info() {
  printf 'pid=%s\ntime=%s\nepoch=%s\n' "$$" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(date +%s)" > "$LOCKDIR/info"
}

init_scratch_and_trap() {
  SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/kit-update-check.XXXXXX") || exit 3
  LOCKDIR="$HOME_DIR/.kit-update.lock"
  trap cleanup EXIT
}

acquire_lock() {
  if mkdir "$LOCKDIR" 2>/dev/null; then
    LOCKED=1
    write_lock_info
  else
    now=$(date +%s)
    lepoch=""
    [ -f "$LOCKDIR/info" ] && lepoch=$(sed -n 's/^epoch=//p' "$LOCKDIR/info" | head -1)
    case "$lepoch" in ''|*[!0-9]*) lepoch="" ;; esac
    if [ -z "$lepoch" ]; then
      lepoch=$(stat -f %m "$LOCKDIR" 2>/dev/null || stat -c %Y "$LOCKDIR" 2>/dev/null || echo "$now")
    fi
    age=$((now - lepoch))
    if [ "$age" -gt "$LOCK_STALE_SECS" ]; then
      echo "kit-update-check: breaking stale lock at $LOCKDIR (age ${age}s)."
      rm -rf "$LOCKDIR"
      if mkdir "$LOCKDIR" 2>/dev/null; then
        LOCKED=1
        write_lock_info
      else
        echo "kit-update-check: kit update already in progress (lock contested at $LOCKDIR)." >&2
        exit 3
      fi
    else
      echo "kit-update-check: kit update already in progress (lock at $LOCKDIR, age ${age}s). Nothing checked; try again later."
      exit 3
    fi
  fi
}

# ---- write discipline: sidecar + atomic mv, backups that are never overwritten
NOW_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STAMP=$(date -u +%Y-%m-%dT%H%M%SZ)
BKROOT="$HOME_DIR/kit-backups"
BKDIR=""      # created lazily on the first write of the run
BKMAN=""      # machine-readable record of this run's writes (drives --undo)
SIDE_N=0

# place_file <content-file> <dest> <mode-or-->  : sidecar in the dest dir, then mv
place_file() {
  pf_dir=$(dirname "$2")
  mkdir -p "$pf_dir" || return 1
  SIDE_N=$((SIDE_N+1))
  pf_side="$pf_dir/.kuc-sidecar.$$.$SIDE_N"
  cp -p "$1" "$pf_side" 2>/dev/null || return 1
  if [ "$3" != "-" ] && [ -n "$3" ]; then
    chmod "$3" "$pf_side" || { rm -f "$pf_side"; return 1; }
  fi
  mv "$pf_side" "$2"
}

write_restore_md() { # $1 backup-dir  $2 kind: update|undo
  {
    echo "# What this folder is"
    echo
    if [ "$2" = "undo" ]; then
      echo "This is a safety backup made on $NOW_UTC, just before an UNDO of a kit"
      echo "update put files in $HOME_DIR back the way they were. The copies in"
      echo "this folder are the files exactly as they looked right before the undo"
      echo "ran -- so the undo itself can be undone."
    else
      echo "This is a safety backup made on $NOW_UTC by the kit updater, just"
      echo "before it changed any files in $HOME_DIR. Every file in this folder is"
      echo "a copy of your file exactly as it was before the update touched it."
    fi
    echo
    echo "Nothing in this folder is ever modified after it is written."
    echo
    echo "## To undo the whole update"
    echo
    echo "Easiest: tell your assistant \"undo the last kit update\"."
    echo
    echo "Or run this yourself:"
    echo
    echo "    bash \"$UNDO_HINT_SCRIPT\" --undo --home \"$HOME_DIR\""
    echo
    echo "That restores every file from the NEWEST backup folder (this one, if no"
    echo "update has run since) -- and it makes a fresh backup first, so you can"
    echo "undo the undo too."
    echo
    echo "## To restore a single file"
    echo
    echo "Copy it back by hand, for example:"
    echo
    echo "    cp -p \"$1/<file>\" \"$HOME_DIR/<file>\""
    echo
    echo "(Use the same relative path inside this folder and inside $HOME_DIR.)"
    echo
    echo "## Notes"
    echo
    echo "- The hidden file .kit-backup-manifest.tsv records what the run did"
    echo "  (updated / installed / removed, one line per file). The undo command"
    echo "  reads it; please leave it in place."
    echo "- Retired kit files are never in this folder: they are MOVED to"
    echo "  $HOME_DIR/kit-retired/<date>/ and stay there until you decide."
  } > "$1/RESTORE.md"
}

new_backup_dir() { # sets NEW_BK; unique per run, suffixing on collision
  mkdir -p "$BKROOT" || return 1
  nb_base="$BKROOT/$STAMP"
  nb_d="$nb_base"
  nb_n=2
  while ! mkdir "$nb_d" 2>/dev/null; do
    [ -e "$nb_d" ] || return 1
    nb_d="$nb_base-$nb_n"
    nb_n=$((nb_n+1))
    [ "$nb_n" -gt 1000 ] && return 1
  done
  NEW_BK="$nb_d"
}

ensure_backup_dir() { # $1 kind for RESTORE.md (update|undo)
  [ -n "$BKDIR" ] && return 0
  new_backup_dir || {
    echo "kit-update-check: cannot create a backup dir under $BKROOT -- refusing to write anything without a backup." >&2
    return 1
  }
  BKDIR="$NEW_BK"
  BKMAN="$BKDIR/.kit-backup-manifest.tsv"
  : > "$BKMAN"
  write_restore_md "$BKDIR" "$1"
}

bk_record() { printf '%s\t%s\n' "$1" "$2" >> "$BKMAN"; }

backup_copy() { # $1 rel-path  $2 live-file : copy into BKDIR; never overwrite
  bc_dst="$BKDIR/$1"
  if [ -e "$bc_dst" ]; then
    echo "kit-update-check: backup target already exists, refusing to overwrite: $bc_dst" >&2
    return 1
  fi
  mkdir -p "$(dirname "$bc_dst")" && cp -p "$2" "$bc_dst"
}

backup_move() { # $1 rel-path  $2 live-file : mv into BKDIR (backs up AND removes)
  bm_dst="$BKDIR/$1"
  if [ -e "$bm_dst" ]; then
    echo "kit-update-check: backup target already exists, refusing to overwrite: $bm_dst" >&2
    return 1
  fi
  mkdir -p "$(dirname "$bm_dst")" && mv "$2" "$bm_dst"
}

# ------------------------------------------------------------------------- undo
# Restores from the newest kit-backups/<timestamp>/ dir. The backup manifest
# records what the run being undone DID (updated/installed/removed per file);
# undoing means inverting each action, while recording this undo run's own
# actions into a fresh backup dir -- so undo is itself undoable.
UNDO_HINT_SCRIPT="$0"
case "$UNDO_HINT_SCRIPT" in /*) : ;; *) UNDO_HINT_SCRIPT="$(pwd)/$UNDO_HINT_SCRIPT" ;; esac
[ -f "$HOME_DIR/kit-scripts/kit-update-check.sh" ] && UNDO_HINT_SCRIPT="$HOME_DIR/kit-scripts/kit-update-check.sh"

do_undo() {
  newest=$(cd "$BKROOT" 2>/dev/null && ls -1d */ 2>/dev/null | tr -d '/' | LC_ALL=C sort | tail -1)
  if [ -z "$newest" ]; then
    cat <<EOF
No kit backups found under $BKROOT -- there is nothing to undo yet.
Backup folders appear there the first time a kit update writes anything.
Nothing was changed.
EOF
    exit 3
  fi
  OLD_BK="$BKROOT/$newest"

  # Build the action list: the recorded manifest, or (fallback for a hand-made
  # backup dir) every file present, treated as "updated".
  UNDO_LIST="$SCRATCH/undo-list.tsv"
  if [ -f "$OLD_BK/.kit-backup-manifest.tsv" ]; then
    grep -v '^#' "$OLD_BK/.kit-backup-manifest.tsv" > "$UNDO_LIST" || : > "$UNDO_LIST"
  else
    (cd "$OLD_BK" && find . -type f ! -name RESTORE.md ! -name .kit-backup-manifest.tsv | sed 's|^\./||' | LC_ALL=C sort) \
      | awk '{print "updated\t" $0}' > "$UNDO_LIST"
  fi
  if [ ! -s "$UNDO_LIST" ]; then
    echo "kit-update-check: the newest backup dir ($OLD_BK) records no file actions -- nothing to undo. Nothing was changed."
    exit 3
  fi

  ensure_backup_dir "undo" || exit 3

  UNDONE="$SCRATCH/undone.md"
  UNDONE_MACH="$SCRATCH/undone.tsv"
  : > "$UNDONE"; : > "$UNDONE_MACH"
  UNDO_FAIL=0

  while IFS='	' read -r act p rest <&9; do
    [ -n "$p" ] || continue
    live="$HOME_DIR/$p"
    case "$act" in
      updated)
        if [ -f "$live" ]; then
          if ! backup_copy "$p" "$live"; then
            printf -- '- `%s` -- FAILED: could not back up the current file; left untouched\n' "$p" >> "$UNDONE"
            printf 'failed\t%s\t-\n' "$p" >> "$UNDONE_MACH"; UNDO_FAIL=1; continue
          fi
          bk_record "updated" "$p"
        else
          bk_record "removed" "$p"
        fi
        if place_file "$OLD_BK/$p" "$live" "-"; then
          printf -- '- `%s` -- restored from %s\n' "$p" "$OLD_BK/$p" >> "$UNDONE"
          printf 'restored\t%s\t%s\n' "$p" "$OLD_BK/$p" >> "$UNDONE_MACH"
        else
          printf -- '- `%s` -- FAILED to restore from %s\n' "$p" "$OLD_BK/$p" >> "$UNDONE"
          printf 'failed\t%s\t%s\n' "$p" "$OLD_BK/$p" >> "$UNDONE_MACH"; UNDO_FAIL=1
        fi
        ;;
      installed)
        if [ -f "$live" ]; then
          if backup_move "$p" "$live"; then
            bk_record "removed" "$p"
            printf -- '- `%s` -- was installed by that run; moved out of the live tree into %s (a move, never a delete)\n' "$p" "$BKDIR/$p" >> "$UNDONE"
            printf 'removed\t%s\t%s\n' "$p" "$BKDIR/$p" >> "$UNDONE_MACH"
          else
            printf -- '- `%s` -- FAILED: could not move the installed file into the new backup; left untouched\n' "$p" >> "$UNDONE"
            printf 'failed\t%s\t-\n' "$p" >> "$UNDONE_MACH"; UNDO_FAIL=1
          fi
        else
          printf -- '- `%s` -- was installed by that run but is already absent; nothing to do\n' "$p" >> "$UNDONE"
          printf 'noop\t%s\t-\n' "$p" >> "$UNDONE_MACH"
        fi
        ;;
      removed)
        if [ ! -f "$OLD_BK/$p" ]; then
          printf -- '- `%s` -- FAILED: backup copy missing at %s\n' "$p" "$OLD_BK/$p" >> "$UNDONE"
          printf 'failed\t%s\t%s\n' "$p" "$OLD_BK/$p" >> "$UNDONE_MACH"; UNDO_FAIL=1; continue
        fi
        if [ -f "$live" ]; then
          if ! backup_copy "$p" "$live"; then
            printf -- '- `%s` -- FAILED: could not back up the current file; left untouched\n' "$p" >> "$UNDONE"
            printf 'failed\t%s\t-\n' "$p" >> "$UNDONE_MACH"; UNDO_FAIL=1; continue
          fi
          bk_record "updated" "$p"
        else
          bk_record "installed" "$p"
        fi
        if place_file "$OLD_BK/$p" "$live" "-"; then
          printf -- '- `%s` -- was removed by that run; put back from %s\n' "$p" "$OLD_BK/$p" >> "$UNDONE"
          printf 'restored\t%s\t%s\n' "$p" "$OLD_BK/$p" >> "$UNDONE_MACH"
        else
          printf -- '- `%s` -- FAILED to restore from %s\n' "$p" "$OLD_BK/$p" >> "$UNDONE"
          printf 'failed\t%s\t%s\n' "$p" "$OLD_BK/$p" >> "$UNDONE_MACH"; UNDO_FAIL=1
        fi
        ;;
      *)
        printf -- '- `%s` -- unknown recorded action "%s"; skipped\n' "$p" "$act" >> "$UNDONE"
        printf 'skipped\t%s\t-\n' "$p" >> "$UNDONE_MACH"
        ;;
    esac
  done 9< "$UNDO_LIST"

  {
    echo "# Kit Update Report -- UNDO"
    echo
    echo "Restored the live install from the newest kit backup. The state right"
    echo "before this undo was itself backed up first, so the undo can be undone:"
    echo "run the same undo command again to re-apply the update."
    echo
    echo "- kit: $KIT_NAME"
    echo "- generated: $NOW_UTC"
    echo "- home: $HOME_DIR"
    echo "- restored from: $OLD_BK"
    echo "- pre-undo state backed up to: $BKDIR"
    echo
    echo "## Restored"
    echo
    cat "$UNDONE"
    echo
    echo "Retired files under $HOME_DIR/kit-retired/ are not covered by undo;"
    echo "they stay where they are until you decide."
    echo
    echo "## Machine-readable"
    echo
    echo '<!-- APPLIED-BEGIN -->'
    cat "$UNDONE_MACH"
    echo '<!-- APPLIED-END -->'
  } > "$REPORT"
  if [ ! -s "$REPORT" ]; then
    echo "kit-update-check: could not write the undo report to $REPORT." >&2
    exit 3
  fi
  if [ "$UNDO_FAIL" = "1" ]; then
    echo "kit-update-check: undo finished WITH FAILURES. Report: $REPORT"
    exit 3
  fi
  echo "kit-update-check: undo complete. Restored from $OLD_BK; pre-undo state saved to $BKDIR. Report: $REPORT"
  exit 0
}

if [ "$UNDO" = "1" ]; then
  init_scratch_and_trap
  acquire_lock
  do_undo
fi

# ---------------------------------------------------------------- step 1: config
if [ ! -f "$CONFIG" ]; then
  cat <<EOF
No kit config found at: $CONFIG

This install predates the kit's update system (or was never set up with it).
That does not mean stop -- it means adopt:

  I can connect this install to the kit's update channel. I'll record your
  name and the kit version once, then about every 5 sessions I'll check for
  kit improvements. You'll always get a list of what changed, I always keep
  a backup, and you can say "turn off auto-updates" anytime. Files you have
  changed yourself are kept as yours -- you decide Replace or Keep, file by
  file.

Dry run: nothing was written.
EOF
  exit 4
fi

command -v python3 >/dev/null 2>&1 || { echo "kit-update-check: python3 is required." >&2; exit 3; }
command -v git >/dev/null 2>&1 || { echo "kit-update-check: git is required." >&2; exit 3; }

cfg_field() {
  python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
v=d.get(sys.argv[2],"")
print(v if isinstance(v,str) else "")' "$CONFIG" "$1" 2>/dev/null
}

CFG_INSTALLED=$(cfg_field installed_commit) || true
CFG_SOURCE=$(cfg_field update_source)
USER_NAME=$(cfg_field user_name)
CFG_AUTO=$(python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
print("true" if d.get("auto_update") is True else "false")' "$CONFIG" 2>/dev/null)
if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$CONFIG" 2>/dev/null; then
  echo "kit-update-check: config at $CONFIG is not valid JSON." >&2
  exit 3
fi
if [ "$CFG_AUTO" = "true" ]; then AUTO_PHRASE="auto-update is on"; else AUTO_PHRASE="auto-update is off"; fi

UPSTREAM="$UPSTREAM_OVERRIDE"
[ -n "$UPSTREAM" ] || UPSTREAM="$CFG_SOURCE"
if [ -z "$UPSTREAM" ]; then
  echo "kit-update-check: no upstream (config has no update_source and --upstream not given)." >&2
  exit 3
fi

# --------------------------------------------------------------- step 2: lock, clone
init_scratch_and_trap
acquire_lock

case "$UPSTREAM" in
  /*)  CLONE_URL="file://$UPSTREAM" ;;
  *)   CLONE_URL="$UPSTREAM" ;;
esac
CLONE="$SCRATCH/clone"
if ! git clone --quiet "$CLONE_URL" "$CLONE" 2>"$SCRATCH/clone.err"; then
  echo "Couldn't check for kit updates -- the clone of $UPSTREAM failed (offline?)." >&2
  sed 's/^/  /' "$SCRATCH/clone.err" >&2
  exit 3
fi
HEAD_SHA=$(git -C "$CLONE" rev-parse HEAD) || exit 3

gshow() { git -C "$CLONE" show "$1:$2" 2>/dev/null; }
gexists() { git -C "$CLONE" cat-file -e "$1:$2" 2>/dev/null; }
sha_of() { shasum -a 256 "$1" | awk '{print $1}'; }

# ------------------------------------------------- step 3: manifests at HEAD + anchor
manifest_schema_of() {
  python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
s=d.get("manifest_schema",1)
print(s if isinstance(s,int) else -1)' "$1" 2>/dev/null
}

# Manifest -> TSV: install_to, source, type, personalize, retired, renamed_from,
#                  checks, owner, mode, consent
manifest_tsv() {
  python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for e in d.get("files",[]):
    it=e.get("install_to")
    if not isinstance(it,str) or not it or "\t" in it: sys.exit(11)
    typ=e.get("type","copied")
    if typ not in ("copied","generated"): sys.exit(12)
    src=e.get("source") or "-"
    pers="true" if e.get("personalize") else "false"
    ret="retired" if e.get("retired") else "-"
    rf=e.get("renamed_from") or "-"
    checks="|".join(e.get("checks") or []) or "-"
    own=e.get("owner","kit")
    if own not in ("kit","user"): sys.exit(13)
    mode=e.get("mode") or "-"
    if not isinstance(mode,str): sys.exit(14)
    cons=e.get("consent") or "-"
    print("\t".join([it,src,typ,pers,ret,rf,checks,own,mode,cons]))' "$1"
}

HEAD_MANIFEST="$SCRATCH/manifest-head.json"
if ! gshow "$HEAD_SHA" "$MANIFEST_NAME" > "$HEAD_MANIFEST" || [ ! -s "$HEAD_MANIFEST" ]; then
  echo "kit-update-check: no $MANIFEST_NAME at HEAD ($HEAD_SHA) -- invalid kit repo." >&2
  exit 3
fi
HEAD_SCHEMA=$(manifest_schema_of "$HEAD_MANIFEST")
if [ -z "$HEAD_SCHEMA" ] || [ "$HEAD_SCHEMA" = "-1" ]; then
  echo "kit-update-check: manifest at HEAD is unreadable or malformed." >&2
  exit 3
fi
if [ "$HEAD_SCHEMA" -gt "$MAX_SCHEMA" ]; then
  echo "kit-update-check: manifest_schema $HEAD_SCHEMA is newer than this script understands (max $MAX_SCHEMA). Update the updater first: the kit ships a newer kit-update-check.sh; install that (per-change consent) and re-run." >&2
  exit 3
fi
HEAD_TSV="$SCRATCH/head.tsv"
if ! manifest_tsv "$HEAD_MANIFEST" > "$HEAD_TSV"; then
  echo "kit-update-check: manifest at HEAD failed validation (malformed entry)." >&2
  exit 3
fi

# A missing/empty user_name would render every personalize:true entry with the
# empty string and misclassify in-sync files as live-ahead. Hard error instead.
if [ -z "$USER_NAME" ] && \
   awk -F'\t' '$3=="copied" && $4=="true" && $5!="retired" {found=1; exit} END{exit !found}' "$HEAD_TSV"; then
  echo "kit-update-check: config at $CONFIG is missing or has an empty 'user_name', but the manifest has personalize:true entries -- refusing to render with an empty name (every personalized file would misclassify)." >&2
  exit 3
fi

# Anchor: installed_commit must resolve in the cloned history.
REBASELINE=0
REBASELINE_REASON=""
INSTALLED_SHA=""
if [ -n "$CFG_INSTALLED" ]; then
  INSTALLED_SHA=$(git -C "$CLONE" rev-parse --verify --quiet "$CFG_INSTALLED^{commit}") || INSTALLED_SHA=""
fi
if [ -z "$INSTALLED_SHA" ]; then
  REBASELINE=1
  REBASELINE_REASON="anchor lost: installed_commit '$CFG_INSTALLED' is not in the upstream history (force-push?). Re-baseline posture: comparing against render(HEAD) only."
else
  INST_MANIFEST="$SCRATCH/manifest-installed.json"
  if ! gshow "$INSTALLED_SHA" "$MANIFEST_NAME" > "$INST_MANIFEST" || [ ! -s "$INST_MANIFEST" ]; then
    REBASELINE=1
    REBASELINE_REASON="no $MANIFEST_NAME at installed_commit $INSTALLED_SHA (install predates the manifest). Re-baseline posture: comparing against render(HEAD) only."
  fi
fi

INST_TSV="$SCRATCH/installed.tsv"
if [ "$REBASELINE" = "0" ]; then
  INST_SCHEMA=$(manifest_schema_of "$INST_MANIFEST")
  if [ -z "$INST_SCHEMA" ] || [ "$INST_SCHEMA" = "-1" ]; then
    echo "kit-update-check: manifest at installed_commit is unreadable or malformed." >&2
    exit 3
  fi
  if [ "$INST_SCHEMA" -gt "$MAX_SCHEMA" ]; then
    echo "kit-update-check: manifest_schema $INST_SCHEMA at installed_commit is newer than this script understands (max $MAX_SCHEMA). Update the updater first." >&2
    exit 3
  fi
  if ! manifest_tsv "$INST_MANIFEST" > "$INST_TSV"; then
    echo "kit-update-check: manifest at installed_commit failed validation (malformed entry)." >&2
    exit 3
  fi
else
  : > "$INST_TSV"
fi

# ------------------------------------------------------------- manifest validation
validate_manifest() { # $1 tsv, $2 commit, $3 label
  if ! awk -F'\t' '{k=tolower($1); if (k in seen) exit 1; seen[k]=1}' "$1"; then
    echo "kit-update-check: manifest at $3 has duplicate case-folded install_to entries (macOS is case-insensitive)." >&2
    return 1
  fi
  while IFS='	' read -r it src typ pers ret rf checks own modep cons <&8; do
    if [ "$modep" != "-" ]; then
      case "$modep" in
        [0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) : ;;
        *) echo "kit-update-check: manifest at $3: entry '$it' has a malformed mode '$modep'." >&2; return 1 ;;
      esac
      case "$(printf '%s' "$modep" | tail -c 3)" in
        *[1357]*)
          if [ "$cons" != "per-change" ]; then
            echo "kit-update-check: manifest at $3: entry '$it' is executable (mode $modep) but lacks consent: per-change -- anything executable needs individual approval, per the design." >&2
            return 1
          fi ;;
      esac
    fi
    [ "$typ" = "generated" ] && continue
    [ "$ret" = "retired" ] && continue   # retired: presence-check only, source may be gone
    [ "$src" = "-" ] && { echo "kit-update-check: manifest at $3: copied entry '$it' has no source." >&2; return 1; }
    if ! gexists "$2" "$src"; then
      echo "kit-update-check: manifest at $3: source '$src' (for '$it') does not exist in the tree at $2." >&2
      return 1
    fi
  done 8< "$1"
  return 0
}

validate_manifest "$HEAD_TSV" "$HEAD_SHA" "HEAD" || exit 3
if [ "$REBASELINE" = "0" ]; then
  validate_manifest "$INST_TSV" "$INSTALLED_SHA" "installed_commit" || exit 3
fi

# Declined bookkeeping: install_to <TAB> declined-at SHA
DECLINED_TSV="$SCRATCH/declined.tsv"
python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k,v in (d.get("declined") or {}).items():
    if isinstance(v,str): print(k+"\t"+v)' "$CONFIG" > "$DECLINED_TSV" 2>/dev/null || : > "$DECLINED_TSV"

# ------------------------------------------------------------------------- render
# Literal [USER_NAME] -> user_name replacement. Literal means literal: the name
# goes through awk's ENVIRON (no escape processing) and index()/substr()
# splicing (no regex), so &, /, backslash, quotes in a name cannot corrupt
# the output. If the source file has no final newline, the render preserves that.
render_file() { # $1 raw-source-file  $2 out-file  $3 personalize(true|false)
  if [ "$3" = "true" ]; then
    KUC_NAME="$USER_NAME" awk '{
      line=$0; out=""
      while ((i = index(line, "[USER_NAME]")) > 0) {
        out = out substr(line, 1, i-1) ENVIRON["KUC_NAME"]
        line = substr(line, i+11)
      }
      print out line
    }' "$1" > "$2"
    if [ -s "$1" ] && [ -n "$(tail -c 1 "$1")" ]; then
      n=$(($(wc -c < "$2") - 1))
      head -c "$n" "$2" > "$2.nn" && mv "$2.nn" "$2"
    fi
  else
    cat "$1" > "$2"
  fi
}

# render source@commit -> file; echoes rendered path; returns 1 if source absent
render_at() { # $1 commit  $2 source  $3 personalize  $4 out-file
  gshow "$1" "$2" > "$4.raw" || return 1
  gexists "$1" "$2" || return 1
  render_file "$4.raw" "$4" "$3"
}

# --------------------------------------------------------------------- report accu
TABLE="$SCRATCH/table.md"
MACH="$SCRATCH/mach.tsv"
NOTES="$SCRATCH/notes.md"
: > "$TABLE"; : > "$MACH"; : > "$NOTES"
ANY_UPDATE=0
ANY_ESCALATION=0

emit() { # $1 state  $2 install_to  $3 would  $4 sha_ri  $5 sha_rh  $6 sha_live
  printf '| `%s` | %s | %s |\n' "$2" "$1" "$3" >> "$TABLE"
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$4" "$5" "$6" >> "$MACH"
  LAST_STATE="$1"
  case "$1" in
    kit-ahead|new|missing) ANY_UPDATE=1 ;;
    live-ahead|diverged|conflict|removed-upstream|retired-present|generated-failed) ANY_ESCALATION=1 ;;
  esac
}

note() { printf -- '- %s\n' "$1" >> "$NOTES"; }

# Apply plan: one row per copied/retired/removed-upstream entry, written during
# classification and consumed by the apply phase and the post-apply verification.
# Fields: state, install_to, owner, mode, consent, renpend, renamed_from, rh-file
PLAN="$SCRATCH/plan.tsv"
: > "$PLAN"
ENTRY_N=0
LAST_STATE=""
plan_row() { # $1 state $2 it $3 own $4 mode $5 cons $6 renpend $7 rf $8 rh-file
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" >> "$PLAN"
}

# regex-escape for grep BRE
bre_escape() { printf '%s\n' "$1" | sed 's/[][\.*^$]/\\&/g'; }

MATCHED="$SCRATCH/matched.txt"
: > "$MATCHED"

# ------------------------------------------------------- step 4: classify every entry
while IFS='	' read -r it src typ pers ret rf checks own modep cons <&9; do
  ENTRY_N=$((ENTRY_N+1))
  live="$HOME_DIR/$it"
  live_note=""

  # ---- generated entries: never content-compared; only checks run (read-only)
  if [ "$typ" = "generated" ]; then
    printf '%s\n' "$it" >> "$MATCHED"
    missing=""
    if [ ! -f "$live" ]; then
      missing="(live file absent)"
    elif [ "$checks" != "-" ]; then
      OLDIFS=$IFS; IFS='|'
      for c in $checks; do
        IFS=$OLDIFS
        case "$c" in
          "section: "*)
            sec=${c#section: }
            esc=$(bre_escape "$sec")
            grep -q "^##.*$esc" "$live" || missing="$missing '$sec'"
            ;;
          *) missing="$missing [unknown check: $c]" ;;
        esac
        IFS='|'
      done
      IFS=$OLDIFS
    fi
    lsha="-"; [ -f "$live" ] && lsha=$(sha_of "$live")
    if [ -z "$missing" ]; then
      emit "generated-ok" "$it" "nothing (all expected sections present; this file is yours -- the kit never writes it)" "-" "-" "$lsha"
    else
      emit "generated-failed" "$it" "needs a look -- missing:$missing (this file is yours; the kit never writes it)" "-" "-" "$lsha"
    fi
    continue
  fi

  # ---- retired entries short-circuit: presence check only, never rendered
  if [ "$ret" = "retired" ]; then
    printf '%s\n' "$it" >> "$MATCHED"
    if [ -e "$live" ]; then
      lsha=$(sha_of "$live")
      emit "retired-present" "$it" "would move to kit-retired/<date>/ (a move, never a delete)" "-" "-" "$lsha"
    else
      emit "retired-absent" "$it" "nothing (retired from the kit and not on your machine)" "-" "-" "-"
    fi
    plan_row "$LAST_STATE" "$it" "$own" "-" "$cons" "0" "-" "-"
    continue
  fi

  # ---- copied entries
  RH="$SCRATCH/rh.$ENTRY_N"
  if ! render_at "$HEAD_SHA" "$src" "$pers" "$RH"; then
    echo "kit-update-check: internal: source '$src' vanished from HEAD after validation." >&2
    exit 3
  fi
  rh_sha=$(sha_of "$RH")

  # installed-side counterpart: join on install_to, then on renamed_from
  inst_line=""
  renpend=0
  if [ "$REBASELINE" = "0" ]; then
    inst_line=$(awk -F'\t' -v k="$it" '$1==k{print; exit}' "$INST_TSV")
    if [ -z "$inst_line" ] && [ "$rf" != "-" ]; then
      inst_line=$(awk -F'\t' -v k="$rf" '$1==k{print; exit}' "$INST_TSV")
      if [ -n "$inst_line" ]; then
        printf '%s\n' "$rf" >> "$MATCHED"
        # renamed: if live not yet at the new path, classify the old-path file
        if [ ! -e "$live" ] && [ -e "$HOME_DIR/$rf" ]; then
          live="$HOME_DIR/$rf"
          renpend=1
          live_note=" (live file still at old path \`$rf\`; a real run would move it)"
        fi
      fi
    fi
    [ -n "$inst_line" ] && printf '%s\n' "$it" >> "$MATCHED"
  fi

  lsha="-"; [ -f "$live" ] && lsha=$(sha_of "$live")

  # ---- re-baseline posture: two-way against render(HEAD) only
  if [ "$REBASELINE" = "1" ]; then
    if [ -f "$live" ]; then
      if cmp -s "$live" "$RH"; then
        emit "already-current" "$it" "nothing to change (already matches the kit's latest version)" "-" "$rh_sha" "$lsha"
      else
        emit "diverged" "$it" "kept your version (update history unavailable; your file differs from the kit's latest version)" "-" "$rh_sha" "$lsha"
      fi
    else
      emit "missing" "$it" "would be installed (missing from your machine; $AUTO_PHRASE)" "-" "$rh_sha" "-"
    fi
    rm -f "$RH.raw"
    plan_row "$LAST_STATE" "$it" "$own" "$modep" "$cons" "0" "-" "$RH"
    continue
  fi

  # ---- three-way: build Ri from the installed manifest's own source/personalize
  RI="$SCRATCH/ri.$$.$RANDOM"
  have_ri=0
  if [ -n "$inst_line" ]; then
    inst_src=$(printf '%s' "$inst_line" | awk -F'\t' '{print $2}')
    inst_pers=$(printf '%s' "$inst_line" | awk -F'\t' '{print $4}')
    if [ "$inst_src" != "-" ] && render_at "$INSTALLED_SHA" "$inst_src" "$inst_pers" "$RI"; then
      have_ri=1
    fi
  fi
  ri_sha="-"; [ "$have_ri" = "1" ] && ri_sha=$(sha_of "$RI")

  if [ -f "$live" ]; then
    if [ "$have_ri" = "1" ]; then
      if cmp -s "$live" "$RI"; then
        if cmp -s "$live" "$RH"; then
          if [ "$renpend" = "1" ]; then
            # content is current but the file still needs moving: that is an
            # available update, not in-sync
            emit "kit-ahead" "$it" "would move live file from \`$rf\` to \`$it\` (a backup is kept first; content already current)" "$ri_sha" "$rh_sha" "$lsha"
          else
            emit "in-sync" "$it" "nothing" "$ri_sha" "$rh_sha" "$lsha"
          fi
        else
          # kit-ahead -- unless this exact upstream change was already declined
          state="kit-ahead"
          would="would be updated ($AUTO_PHRASE; a backup is always kept)$live_note"
          dsha=$(awk -F'\t' -v k="$it" '$1==k{print $2; exit}' "$DECLINED_TSV")
          if [ -n "$dsha" ] && git -C "$CLONE" rev-parse --verify --quiet "$dsha^{commit}" >/dev/null; then
            RD="$SCRATCH/rd.$$.$RANDOM"
            if render_at "$dsha" "$src" "$pers" "$RD" && cmp -s "$RD" "$RH"; then
              state="declined-pending"
              would="nothing (you chose Keep for this change; you will be asked again only if the kit changes it again)"
            fi
            rm -f "$RD" "$RD.raw"
          fi
          emit "$state" "$it" "$would" "$ri_sha" "$rh_sha" "$lsha"
        fi
      elif cmp -s "$live" "$RH"; then
        if [ "$renpend" = "1" ]; then
          emit "kit-ahead" "$it" "would move live file from \`$rf\` to \`$it\` (a backup is kept first; content already current)" "$ri_sha" "$rh_sha" "$lsha"
        else
          emit "already-current" "$it" "nothing to change (already matches the kit's latest version)" "$ri_sha" "$rh_sha" "$lsha"
        fi
      elif cmp -s "$RI" "$RH"; then
        emit "live-ahead" "$it" "kept your version (you improved this file; the kit has not changed it)" "$ri_sha" "$rh_sha" "$lsha"
      else
        emit "diverged" "$it" "kept your version (you changed it and the kit also improved it)" "$ri_sha" "$rh_sha" "$lsha"
      fi
    else
      # live present, source absent at installed (or entry new in HEAD manifest)
      if cmp -s "$live" "$RH"; then
        emit "already-current" "$it" "nothing to change (already matches the kit's latest version)" "-" "$rh_sha" "$lsha"
      else
        emit "conflict" "$it" "kept your version (the kit added a file you already had, with different content)" "-" "$rh_sha" "$lsha"
      fi
    fi
  else
    if [ "$have_ri" = "1" ]; then
      emit "missing" "$it" "would be reinstalled (missing from your machine; $AUTO_PHRASE)$live_note" "$ri_sha" "$rh_sha" "-"
    else
      emit "new" "$it" "would be installed (new in the kit; $AUTO_PHRASE)" "-" "$rh_sha" "-"
    fi
  fi
  rm -f "$RI" "$RI.raw" "$RH.raw"
  plan_row "$LAST_STATE" "$it" "$own" "$modep" "$cons" "$renpend" "$rf" "$RH"
done 9< "$HEAD_TSV"

# ---- entries only in the installed manifest: removed upstream without a tombstone
if [ "$REBASELINE" = "0" ]; then
  while IFS='	' read -r it src typ pers ret rf checks own modep cons <&9; do
    grep -qxF "$it" "$MATCHED" && continue
    live="$HOME_DIR/$it"
    lsha="-"; [ -f "$live" ] && lsha=$(sha_of "$live")
    if [ -e "$live" ]; then
      emit "removed-upstream" "$it" "would move live file to kit-retired/<date>/ (the kit no longer includes this file; a move, never a delete)" "-" "-" "$lsha"
    else
      emit "removed-upstream" "$it" "report only (the kit no longer includes this file; nothing on your machine)" "-" "-" "-"
    fi
    plan_row "removed-upstream" "$it" "$own" "-" "$cons" "0" "-" "-"
    note "manifest rule: entry \`$it\` was deleted from the HEAD manifest without a \`retired\` tombstone -- surfaced loudly as removed-upstream."
  done 9< "$INST_TSV"
fi

# ----------------------------------------------------------------- apply phase
# Only entered with --apply. Everything below the classification is decision +
# write; the classification above is byte-identical to a dry run.
APPLIED_TABLE="$SCRATCH/applied.md"
APPLIED_MACH="$SCRATCH/applied.tsv"
: > "$APPLIED_TABLE"; : > "$APPLIED_MACH"
APPLIED_N=0
UNAPPLIED_N=0
ANCHOR_NOTE=""
ANCHOR_ADVANCED=0

applied() { # $1 action  $2 install_to  $3 detail  $4 backup-path-or--
  printf -- '- `%s` -- %s: %s\n' "$2" "$1" "$3" >> "$APPLIED_TABLE"
  printf '%s\t%s\t%s\n' "$1" "$2" "$4" >> "$APPLIED_MACH"
}

retire_live() { # $1 install_to -> moves live file to kit-retired/<date>/, echoes dest
  rl_src="$HOME_DIR/$1"
  rl_base="$HOME_DIR/kit-retired/$RETIRE_DATE/$1"
  rl_dst="$rl_base"
  rl_n=1
  while [ -e "$rl_dst" ]; do rl_dst="$rl_base.$rl_n"; rl_n=$((rl_n+1)); done
  mkdir -p "$(dirname "$rl_dst")" && mv "$rl_src" "$rl_dst" && printf '%s\n' "$rl_dst"
}

if [ "$APPLY" = "1" ]; then
  RETIRE_DATE=$(date -u +%Y-%m-%d)

  if [ "$CFG_AUTO" != "true" ]; then
    # ---- auto-update is OFF: nothing is written, not even the anchor. The
    # report lists each pending change with the Replace/Keep vocabulary the
    # wizard taught; interactive prompting is repair's job, not this script's.
    while IFS='	' read -r pstate pit pown pmode pcons prenpend prf prh <&7; do
      case "$pstate" in
        kit-ahead|new|missing)
          if [ "$pown" != "kit" ]; then
            applied "skipped-user-owned" "$pit" "user-owned -- never written" "-"
            UNAPPLIED_N=$((UNAPPLIED_N+1))
          elif [ "$pcons" = "per-change" ]; then
            applied "needs-approval" "$pit" "per-change consent -- needs your individual approval even with auto-update on" "-"
            UNAPPLIED_N=$((UNAPPLIED_N+1))
          else
            applied "would-apply" "$pit" "auto-update is off, so nothing was changed. Your choice, file by file: Replace (take the kit's version -- a backup is always kept) or Keep (stay with yours -- you will not be asked again unless it changes upstream)" "-"
            UNAPPLIED_N=$((UNAPPLIED_N+1))
          fi
          ;;
        retired-present)
          applied "would-retire" "$pit" "auto-update is off, so nothing was moved. A real apply would move it to kit-retired/$RETIRE_DATE/ (a move, never a delete)" "-"
          ;;
      esac
    done 7< "$PLAN"
    ANCHOR_NOTE="installed_commit unchanged (auto-update is off; this run wrote nothing)."
  else
    # ---- auto-update is ON: write per entry, with backup-first discipline.
    while IFS='	' read -r pstate pit pown pmode pcons prenpend prf prh <&7; do
      case "$pstate" in
        kit-ahead|new|missing)
          if [ "$pown" != "kit" ]; then
            applied "skipped-user-owned" "$pit" "user-owned -- never written" "-"
            UNAPPLIED_N=$((UNAPPLIED_N+1))
            continue
          fi
          if [ "$pcons" = "per-change" ]; then
            applied "needs-approval" "$pit" "per-change consent -- this file needs your individual approval; nothing was changed" "-"
            UNAPPLIED_N=$((UNAPPLIED_N+1))
            continue
          fi
          if [ "$prh" = "-" ] || [ ! -f "$prh" ]; then
            applied "failed" "$pit" "internal: rendered content unavailable; nothing was changed" "-"
            UNAPPLIED_N=$((UNAPPLIED_N+1))
            continue
          fi
          dest="$HOME_DIR/$pit"
          ren_note=""
          if [ "$prenpend" = "1" ]; then
            # pending rename: the old-path live file is MOVED into the backup
            # (that both preserves and clears it -- never a delete)
            if ! ensure_backup_dir "update" || ! backup_move "$prf" "$HOME_DIR/$prf"; then
              applied "failed" "$pit" "could not back up the old-path file \`$prf\`; move not performed" "-"
              UNAPPLIED_N=$((UNAPPLIED_N+1))
              continue
            fi
            bk_record "removed" "$prf"
            ren_note=" (moved from \`$prf\`; the old file is preserved at $BKDIR/$prf)"
          fi
          if [ -f "$dest" ]; then
            if ! ensure_backup_dir "update" || ! backup_copy "$pit" "$dest"; then
              applied "failed" "$pit" "could not back up the existing file; nothing was changed" "-"
              UNAPPLIED_N=$((UNAPPLIED_N+1))
              continue
            fi
            rec="updated"
            bpath="$BKDIR/$pit"
          else
            rec="installed"   # no existing file: backup skipped, by design
            bpath="-"
          fi
          if place_file "$prh" "$dest" "$pmode"; then
            bk_record "$rec" "$pit"
            APPLIED_N=$((APPLIED_N+1))
            if [ "$rec" = "updated" ]; then
              applied "updated" "$pit" "updated to the kit's latest version; the previous version was backed up$ren_note" "$bpath"
            else
              applied "installed" "$pit" "installed the kit's latest version; there was no previous file to back up$ren_note" "$bpath"
            fi
          else
            applied "failed" "$pit" "write failed; the backup (if any) is intact" "$bpath"
            UNAPPLIED_N=$((UNAPPLIED_N+1))
          fi
          ;;
        retired-present)
          rdst=$(retire_live "$pit")
          if [ -n "$rdst" ]; then
            ensure_backup_dir "update" && bk_record "# retired-to $rdst" "$pit"
            APPLIED_N=$((APPLIED_N+1))
            applied "retired" "$pit" "moved to $rdst -- a move, never a delete. Undo does not cover this; the file stays there until you decide" "-"
          else
            applied "failed" "$pit" "could not move to kit-retired/; left in place" "-"
          fi
          ;;
        removed-upstream)
          # Design table: removed-upstream live files also move to kit-retired
          # (the loud exit-2 escalation still stands either way).
          if [ -e "$HOME_DIR/$pit" ]; then
            rdst=$(retire_live "$pit")
            if [ -n "$rdst" ]; then
              ensure_backup_dir "update" && bk_record "# retired-to $rdst" "$pit"
              APPLIED_N=$((APPLIED_N+1))
              applied "retired" "$pit" "removed upstream without a tombstone -- moved to $rdst and flagged for review (a move, never a delete)" "-"
            else
              applied "failed" "$pit" "could not move to kit-retired/; left in place" "-"
            fi
          fi
          ;;
      esac
    done 7< "$PLAN"

    # Test hook: simulate a crash after the file writes, before verification
    # and the anchor write. Used by the test suite to prove the anchor is
    # written last and that a torn run self-heals.
    if [ -n "${KUC_TEST_KILL_BEFORE_ANCHOR:-}" ]; then kill -9 $$; fi

    # ---- anchor advance: re-verify EVERY entry against render(HEAD); the
    # anchor is written exactly once, last, and only if everything is clean.
    NOT_CLEAN=0
    while IFS='	' read -r pstate pit pown pmode pcons prenpend prf prh <&7; do
      case "$pstate" in
        retired-present|retired-absent|removed-upstream)
          [ -e "$HOME_DIR/$pit" ] && NOT_CLEAN=$((NOT_CLEAN+1))
          ;;
        declined-pending)
          : ;;   # a recorded decline counts as clean, by design
        *)
          if [ "$prh" = "-" ] || ! cmp -s "$HOME_DIR/$pit" "$prh"; then
            NOT_CLEAN=$((NOT_CLEAN+1))
          fi
          ;;
      esac
    done 7< "$PLAN"

    if [ "$NOT_CLEAN" -eq 0 ]; then
      if [ -n "$INSTALLED_SHA" ] && [ "$HEAD_SHA" = "$INSTALLED_SHA" ]; then
        ANCHOR_NOTE="installed_commit already at HEAD ($HEAD_SHA); nothing to advance."
      else
        case "$CONFIG" in
          "$HOME_DIR"/*) relcfg="${CONFIG#"$HOME_DIR"/}" ;;
          *) relcfg="" ;;
        esac
        cfg_ok=1
        if ensure_backup_dir "update"; then
          if [ -n "$relcfg" ]; then
            backup_copy "$relcfg" "$CONFIG" && bk_record "updated" "$relcfg" || cfg_ok=0
          else
            note "config lives outside --home ($CONFIG); its previous version was NOT backed up and --undo will not restore it."
          fi
        else
          cfg_ok=0
        fi
        if [ "$cfg_ok" = "1" ]; then
          SIDE_N=$((SIDE_N+1))
          cfgside="$(dirname "$CONFIG")/.kuc-sidecar.$$.$SIDE_N"
          if python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
d["installed_commit"]=sys.argv[2]
d["installed_at"]=sys.argv[3]
open(sys.argv[4],"w").write(json.dumps(d,indent=2)+"\n")' "$CONFIG" "$HEAD_SHA" "$NOW_UTC" "$cfgside" \
             && mv "$cfgside" "$CONFIG"; then
            ANCHOR_ADVANCED=1
            ANCHOR_NOTE="installed_commit advanced: ${INSTALLED_SHA:-<none>} -> $HEAD_SHA (written once, last, after verifying every entry against render(HEAD))."
            if [ -n "$relcfg" ]; then abpath="$BKDIR/$relcfg"; else abpath="-"; fi
            applied "anchor-advanced" "${relcfg:-$CONFIG}" "installed_commit -> $HEAD_SHA, installed_at -> $NOW_UTC" "$abpath"
          else
            rm -f "$cfgside"
            ANCHOR_NOTE="installed_commit NOT advanced: the config write failed. The anchor holds; the next run re-classifies and finishes the job."
          fi
        else
          ANCHOR_NOTE="installed_commit NOT advanced: could not back up the config first. The anchor holds; the next run re-classifies and finishes the job."
        fi
      fi
    else
      if [ "$NOT_CLEAN" -eq 1 ]; then
        NC_PHRASE="1 file still differs"
      else
        NC_PHRASE="$NOT_CLEAN files still differ"
      fi
      ANCHOR_NOTE="installed_commit NOT advanced: $NC_PHRASE from the kit's latest version. The anchor holds; the next run re-classifies whatever this run completed as already-current and finishes the job (self-healing)."
    fi
  fi
fi

# ------------------------------------------------------------ step 5: changelog assembly
CHANGELOG_SECTION="$SCRATCH/changelog.md"
if gshow "$HEAD_SHA" "CHANGELOG.md" > "$SCRATCH/cl-head.md" && gexists "$HEAD_SHA" "CHANGELOG.md"; then
  if [ "$REBASELINE" = "1" ]; then
    {
      echo "Anchor unavailable (re-baseline posture) -- cannot assemble the changelog delta."
      echo "See CHANGELOG.md at HEAD for the full history."
    } > "$CHANGELOG_SECTION"
  else
    gshow "$INSTALLED_SHA" "CHANGELOG.md" > "$SCRATCH/cl-inst.md" || : > "$SCRATCH/cl-inst.md"
    diff "$SCRATCH/cl-inst.md" "$SCRATCH/cl-head.md" | sed -n 's/^> //p' > "$SCRATCH/cl-new.md"
    if [ -s "$SCRATCH/cl-new.md" ]; then
      cp "$SCRATCH/cl-new.md" "$CHANGELOG_SECTION"
    else
      echo "No new changelog lines between installed_commit and HEAD." > "$CHANGELOG_SECTION"
    fi
  fi
else
  echo "No CHANGELOG.md at HEAD -- the kit has not published authored change notes." > "$CHANGELOG_SECTION"
fi

# --------------------------------------------------------------------- write report
RESULT=0
if [ "$APPLY" = "1" ]; then
  [ "$UNAPPLIED_N" -gt 0 ] && RESULT=1
else
  [ "$ANY_UPDATE" = "1" ] && RESULT=1
fi
[ "$ANY_ESCALATION" = "1" ] && RESULT=2

{
  if [ "$APPLY" = "1" ]; then
    echo "# Kit Update Report -- APPLY RUN"
    echo
    if [ "$CFG_AUTO" = "true" ]; then
      echo "Auto-update is ON -- you opted in to having kit improvements applied"
      echo "automatically, and you can say \"turn off auto-updates\" anytime."
      # The undo promise is printed ONLY when this run actually backed
      # something up -- a run that wrote nothing has nothing to undo.
      if [ -n "$BKDIR" ] && [ -s "$BKMAN" ]; then
        echo "Every changed file was backed up first; say \"undo the last kit update\""
        echo "to put everything back exactly as it was."
      fi
    else
      echo "Auto-update is OFF, so this run wrote nothing. The list below shows"
      echo "what is waiting, each with a Replace/Keep choice. Say \"turn on"
      echo "auto-updates\" to have future updates applied automatically."
    fi
  else
    echo "# Kit Update Report -- DRY RUN"
    echo
    echo "Nothing was applied. This report lists what a real update run WOULD do."
  fi
  echo
  echo "- kit: $KIT_NAME"
  echo "- generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- home: $HOME_DIR"
  echo "- upstream: $UPSTREAM"
  if [ "$ANCHOR_ADVANCED" = "1" ]; then
    old_short="<none>"
    [ -n "$CFG_INSTALLED" ] && old_short=$(printf '%.7s' "$CFG_INSTALLED")
    echo "- installed_commit: was $old_short -> now $(printf '%.7s' "$HEAD_SHA")"
  else
    echo "- installed_commit: ${CFG_INSTALLED:-<none>}"
  fi
  echo "- head_commit: $HEAD_SHA"
  if [ "$APPLY" = "1" ]; then
    echo "- exit code: $RESULT (0 nothing left to do, 1 updates remained unapplied, 2 escalations present)"
  else
    echo "- exit code: $RESULT (0 all in-sync, 1 updates available, 2 escalations present)"
  fi
  if [ "$REBASELINE" = "1" ]; then
    echo
    echo "WARNING: $REBASELINE_REASON"
  fi
  echo
  echo "## Entries"
  echo
  echo "| install_to | state | action a real run WOULD take |"
  echo "|---|---|---|"
  cat "$TABLE"
  if [ "$ANY_ESCALATION" = "1" ]; then
    echo
    echo "## Needs your attention"
    echo
    while IFS='	' read -r mstate mit msri msrh mslive; do
      case "$mstate" in
        diverged)
          echo "- \`$mit\` -- You changed this file yourself and the kit also improved it. We kept your version -- nothing was overwritten. Ask your assistant to review the difference when convenient." ;;
        live-ahead)
          echo "- \`$mit\` -- You improved this file yourself and the kit has not changed it since. We kept your version -- nothing was overwritten. Your change may be worth sharing back to the kit." ;;
        conflict)
          echo "- \`$mit\` -- The kit added a new file that you already have your own version of. We kept your version -- nothing was overwritten. Ask your assistant to compare the two when convenient." ;;
        removed-upstream)
          if [ "$mslive" = "-" ]; then
            echo "- \`$mit\` -- The kit no longer includes this file, and it is not on your machine either. Nothing to do -- this is just so you know."
          else
            echo "- \`$mit\` -- The kit no longer includes this file. Your copy is never deleted -- at most it is moved to the kit-retired folder, where it stays until you decide."
          fi ;;
        retired-present)
          echo "- \`$mit\` -- The kit has retired this file. Your copy is never deleted -- at most it is moved to the kit-retired folder, where it stays until you decide." ;;
        generated-failed)
          echo "- \`$mit\` -- This file is yours and the kit never writes it, but it seems to be missing a section the kit expects. Nothing was changed -- ask your assistant to take a look when convenient." ;;
      esac
    done < "$MACH"
  fi
  if [ "$APPLY" = "1" ]; then
    echo
    echo "## Applied"
    echo
    if [ -s "$APPLIED_TABLE" ]; then
      cat "$APPLIED_TABLE"
    else
      echo "Nothing needed applying."
    fi
    echo
    [ -n "$BKDIR" ] && echo "- backup dir for this run: $BKDIR (RESTORE.md inside explains recovery)"
    echo "- $ANCHOR_NOTE"
  fi
  if [ -s "$NOTES" ]; then
    echo
    echo "## Notes"
    echo
    cat "$NOTES"
  fi
  echo
  echo "## What changed"
  echo
  cat "$CHANGELOG_SECTION"
  echo
  echo "## Machine-readable"
  echo
  echo "One line per entry: state, install_to, sha256(render@installed), sha256(render@HEAD), sha256(live). \"-\" = not applicable."
  echo
  echo '<!-- MACHINE-BEGIN -->'
  cat "$MACH"
  echo '<!-- MACHINE-END -->'
  if [ "$APPLY" = "1" ]; then
    echo
    echo "One line per apply action: action, install_to, backup path (\"-\" = no backup needed)."
    echo
    echo '<!-- APPLIED-BEGIN -->'
    cat "$APPLIED_MACH"
    echo '<!-- APPLIED-END -->'
  fi
} > "$REPORT"
REPORT_STATUS=$?

# A run whose only deliverable failed to land must not exit success-ish.
if [ "$REPORT_STATUS" -ne 0 ] || [ ! -s "$REPORT" ]; then
  echo "kit-update-check: could not write the report to $REPORT (directory missing or unwritable?). The classification ran but its evidence was lost, so this run counts as an error." >&2
  exit 3
fi

if [ "$APPLY" = "1" ]; then
  echo "kit-update-check: apply run complete. Applied: $APPLIED_N, remained unapplied: $UNAPPLIED_N. Report: $REPORT (exit $RESULT)"
else
  echo "kit-update-check: dry run complete. Report: $REPORT (exit $RESULT)"
fi
exit $RESULT
