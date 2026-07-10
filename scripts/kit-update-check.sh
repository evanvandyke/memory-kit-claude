#!/bin/bash
# kit-update-check.sh -- DRY-RUN kit update classifier for memory-kit-claude.
#
# Layer 1 of the outer-loop cascade (see outer-loop-v2.1 design). Clones the
# kit's update source, reads the install manifest at the installed commit AND
# at HEAD, classifies every entry against the live install, and writes a
# report of what a real update run WOULD do. It never applies anything.
#
# DRY-RUN GUARANTEE: the only writes this script ever makes are
#   1. the report file (--report), and
#   2. the lock dir <home>/.kit-update.lock (mkdir mutex; PID + timestamp
#      inside; a lock older than 30 minutes is treated as stale and broken).
# Everything else -- the live tree, the config, the clone's origin -- is
# strictly read-only. The clone itself goes to a mktemp scratch dir that is
# removed on exit.
#
# USAGE:
#   kit-update-check.sh --home <dir> [--config <path>] [--upstream <url-or-path>] [--report <path>]
#
# PARAMETERS:
#   --home <dir>       REQUIRED. The live root to check (the directory that
#                      plays the role of ~/.claude). There is deliberately no
#                      default: the script never touches a home you did not
#                      name explicitly.
#   --config <path>    Kit config JSON. Default: <home>/kit-config/memory-kit-claude.json
#   --upstream <u>     Git URL or local path of the kit repo; overrides the
#                      config's update_source. Local paths are cloned via file://.
#   --report <path>    Where to write the markdown report. Default: ./kit-update-report.md
#
# EXIT CODES:
#   0  all entries in-sync (nothing to do)
#   1  updates available (only kit-ahead / new / missing states present)
#   2  escalations present (live-ahead / diverged / conflict / removed-upstream /
#      retired-present / failed generated check) -- a human needs to look
#   3  error: clone failed, invalid or unreadable manifest, manifest_schema
#      newer than this script understands ("update the updater first"),
#      bad arguments, or another update already holds the lock
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

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --home)     HOME_DIR="$2"; shift 2 ;;
    --config)   CONFIG="$2"; shift 2 ;;
    --upstream) UPSTREAM_OVERRIDE="$2"; shift 2 ;;
    --report)   REPORT="$2"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "kit-update-check: unknown argument: $1" >&2; exit 3 ;;
  esac
done

if [ -z "$HOME_DIR" ]; then
  echo "kit-update-check: --home <dir> is required (no default on purpose: this script never guesses at a live root)." >&2
  exit 3
fi
if [ ! -d "$HOME_DIR" ]; then
  echo "kit-update-check: --home '$HOME_DIR' is not a directory." >&2
  exit 3
fi
[ -n "$CONFIG" ] || CONFIG="$HOME_DIR/kit-config/$KIT_NAME.json"

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
if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$CONFIG" 2>/dev/null; then
  echo "kit-update-check: config at $CONFIG is not valid JSON." >&2
  exit 3
fi

UPSTREAM="$UPSTREAM_OVERRIDE"
[ -n "$UPSTREAM" ] || UPSTREAM="$CFG_SOURCE"
if [ -z "$UPSTREAM" ]; then
  echo "kit-update-check: no upstream (config has no update_source and --upstream not given)." >&2
  exit 3
fi

# ------------------------------------------------------------------ scratch + lock
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/kit-update-check.XXXXXX") || exit 3
LOCKDIR="$HOME_DIR/.kit-update.lock"
LOCKED=0

cleanup() {
  [ "$LOCKED" = "1" ] && rm -rf "$LOCKDIR"
  rm -rf "$SCRATCH"
}
trap cleanup EXIT

write_lock_info() {
  printf 'pid=%s\ntime=%s\nepoch=%s\n' "$$" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(date +%s)" > "$LOCKDIR/info"
}

# --------------------------------------------------------------- step 2: lock, clone
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

# Manifest -> TSV: install_to, source, type, personalize, retired, renamed_from, checks
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
    print("\t".join([it,src,typ,pers,ret,rf,checks]))' "$1"
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
  while IFS='	' read -r it src typ pers ret rf checks <&8; do
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
  case "$1" in
    kit-ahead|new|missing) ANY_UPDATE=1 ;;
    live-ahead|diverged|conflict|removed-upstream|retired-present|generated-failed) ANY_ESCALATION=1 ;;
  esac
}

note() { printf -- '- %s\n' "$1" >> "$NOTES"; }

# regex-escape for grep BRE
bre_escape() { printf '%s\n' "$1" | sed 's/[][\.*^$]/\\&/g'; }

MATCHED="$SCRATCH/matched.txt"
: > "$MATCHED"

# ------------------------------------------------------- step 4: classify every entry
while IFS='	' read -r it src typ pers ret rf checks <&9; do
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
      emit "generated-ok" "$it" "nothing (all section checks pass; user-owned, never written)" "-" "-" "$lsha"
    else
      emit "generated-failed" "$it" "escalate: failed checks:$missing (user-owned, never written)" "-" "-" "$lsha"
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
      emit "retired-absent" "$it" "nothing (retired and not present)" "-" "-" "-"
    fi
    continue
  fi

  # ---- copied entries
  RH="$SCRATCH/rh.$$.$RANDOM"
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
        emit "already-current" "$it" "record only (re-baseline: matches render(HEAD))" "-" "$rh_sha" "$lsha"
      else
        emit "diverged" "$it" "never touch; escalate (anchor lost / no manifest at anchor -- re-baseline needed; live differs from render(HEAD))" "-" "$rh_sha" "$lsha"
      fi
    else
      emit "missing" "$it" "would install under opt-in (re-baseline: absent live)" "-" "$rh_sha" "-"
    fi
    rm -f "$RH" "$RH.raw"
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
            emit "kit-ahead" "$it" "would move live file from \`$rf\` to \`$it\` under opt-in (backup first; content already current)" "$ri_sha" "$rh_sha" "$lsha"
          else
            emit "in-sync" "$it" "nothing" "$ri_sha" "$rh_sha" "$lsha"
          fi
        else
          # kit-ahead -- unless this exact upstream change was already declined
          state="kit-ahead"
          would="would update under opt-in (backup first)$live_note"
          dsha=$(awk -F'\t' -v k="$it" '$1==k{print $2; exit}' "$DECLINED_TSV")
          if [ -n "$dsha" ] && git -C "$CLONE" rev-parse --verify --quiet "$dsha^{commit}" >/dev/null; then
            RD="$SCRATCH/rd.$$.$RANDOM"
            if render_at "$dsha" "$src" "$pers" "$RD" && cmp -s "$RD" "$RH"; then
              state="declined-pending"
              would="nothing (declined at $dsha; unchanged upstream since -- will re-prompt only if it changes again)"
            fi
            rm -f "$RD" "$RD.raw"
          fi
          emit "$state" "$it" "$would" "$ri_sha" "$rh_sha" "$lsha"
        fi
      elif cmp -s "$live" "$RH"; then
        if [ "$renpend" = "1" ]; then
          emit "kit-ahead" "$it" "would move live file from \`$rf\` to \`$it\` under opt-in (backup first; content already current)" "$ri_sha" "$rh_sha" "$lsha"
        else
          emit "already-current" "$it" "record only (anchor advances at run end)" "$ri_sha" "$rh_sha" "$lsha"
        fi
      elif cmp -s "$RI" "$RH"; then
        emit "live-ahead" "$it" "never touch; escalate; for the kit author: upstream-this signal" "$ri_sha" "$rh_sha" "$lsha"
      else
        emit "diverged" "$it" "never touch; escalate (both sides moved; needs a human merge)" "$ri_sha" "$rh_sha" "$lsha"
      fi
    else
      # live present, source absent at installed (or entry new in HEAD manifest)
      if cmp -s "$live" "$RH"; then
        emit "already-current" "$it" "record only" "-" "$rh_sha" "$lsha"
      else
        emit "conflict" "$it" "escalate (upstream added a file that already exists live, with different content)" "-" "$rh_sha" "$lsha"
      fi
    fi
  else
    if [ "$have_ri" = "1" ]; then
      emit "missing" "$it" "would reinstall under opt-in$live_note" "$ri_sha" "$rh_sha" "-"
    else
      emit "new" "$it" "would install under opt-in (new upstream)" "-" "$rh_sha" "-"
    fi
  fi
  rm -f "$RI" "$RI.raw" "$RH" "$RH.raw"
done 9< "$HEAD_TSV"

# ---- entries only in the installed manifest: removed upstream without a tombstone
if [ "$REBASELINE" = "0" ]; then
  while IFS='	' read -r it src typ pers ret rf checks <&9; do
    grep -qxF "$it" "$MATCHED" && continue
    live="$HOME_DIR/$it"
    lsha="-"; [ -f "$live" ] && lsha=$(sha_of "$live")
    if [ -e "$live" ]; then
      emit "removed-upstream" "$it" "would move live file to kit-retired/<date>/ and report (entry left the manifest with no retired tombstone)" "-" "-" "$lsha"
    else
      emit "removed-upstream" "$it" "report only (entry left the manifest with no retired tombstone; nothing live)" "-" "-" "-"
    fi
    note "manifest rule: entry \`$it\` was deleted from the HEAD manifest without a \`retired\` tombstone -- surfaced loudly as removed-upstream."
  done 9< "$INST_TSV"
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
[ "$ANY_UPDATE" = "1" ] && RESULT=1
[ "$ANY_ESCALATION" = "1" ] && RESULT=2

{
  echo "# Kit Update Report -- DRY RUN"
  echo
  echo "Nothing was applied. This report lists what a real update run WOULD do."
  echo
  echo "- kit: $KIT_NAME"
  echo "- generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- home: $HOME_DIR"
  echo "- upstream: $UPSTREAM"
  echo "- installed_commit: ${CFG_INSTALLED:-<none>}"
  echo "- head_commit: $HEAD_SHA"
  echo "- exit code: $RESULT (0 all in-sync, 1 updates available, 2 escalations present)"
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
  if [ -s "$NOTES" ]; then
    echo
    echo "## Notes"
    echo
    cat "$NOTES"
  fi
  echo
  echo "## Changelog (authored lines between installed_commit and HEAD)"
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
} > "$REPORT"

echo "kit-update-check: dry run complete. Report: $REPORT (exit $RESULT)"
exit $RESULT
