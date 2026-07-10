#!/bin/bash
# run-tests.sh -- fixture-matrix test suite for scripts/kit-update-check.sh.
#
# Builds everything in a temp dir: a miniature fixture kit repo (several
# commits of history) plus fake home dirs, then asserts the script's exit
# code AND the per-entry states in the machine-readable report section for
# every case in the design's fixture matrix. Never touches the real
# ~/.claude/. Prints PASS/FAIL per test; exits non-zero on any FAIL.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/kit-update-check.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/kit-update-tests.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
TESTN=0

ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1 -- $2"; FAIL=$((FAIL+1)); }
assert_eq() { # name expected actual
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$2] got [$3]"; fi
}
assert_grep() { # name pattern file
  if grep -q "$2" "$3" 2>/dev/null; then ok "$1"; else bad "$1" "pattern [$2] not found in $3"; fi
}

# ------------------------------------------------------------------ fixture helpers

gitc() { git -C "$1" -c user.name=fixture -c user.email=fixture@test commit -q "${@:2}"; }

render_py() { # src-file name -> stdout (independent implementation of the render)
  python3 -c 'import sys
sys.stdout.write(open(sys.argv[1]).read().replace("[USER_NAME]", sys.argv[2]))' "$1" "$2"
}

write_config() { # home installed_commit update_source user_name [declined_json]
  mkdir -p "$1/kit-config"
  python3 -c 'import json,sys
cfg={"kit":"memory-kit-claude","installed_commit":sys.argv[2],
     "installed_at":"2026-07-09T00:00:00Z","update_source":sys.argv[3],
     "user_name":sys.argv[4],"auto_update":True,
     "declined":json.loads(sys.argv[5]) if len(sys.argv)>5 and sys.argv[5] else {}}
open(sys.argv[1],"w").write(json.dumps(cfg,indent=2))' \
    "$1/kit-config/memory-kit-claude.json" "$2" "$3" "$4" "${5:-}"
}

# state_of <report> <install_to> -> state from the machine section
state_of() {
  awk -F'\t' -v p="$2" '
    /MACHINE-END/   {insec=0}
    insec && $2==p  {print $1; exit}
    /MACHINE-BEGIN/ {insec=1}
  ' "$1" 2>/dev/null
}

run_check() { # home upstream [extra args...]  -> sets RC, REPORT, OUT
  TESTN=$((TESTN+1))
  REPORT="$WORK/report-$TESTN.md"
  OUT="$WORK/out-$TESTN.txt"
  local home="$1" up="$2"
  shift 2
  bash "$SCRIPT" --home "$home" --upstream "$up" --report "$REPORT" "$@" > "$OUT" 2>&1
  RC=$?
}

# ------------------------------------------------------------- main fixture repo
# C0: files only, no manifest. C1: manifest v1 + CHANGELOG. C2 (HEAD): alpha and
# gamma change, delta removed (entry AND file, no tombstone), epsilon added,
# zeta renamed, changelog lines added.

REPO="$WORK/upstream"
mkdir -p "$REPO/files"
git -C "$WORK" init -q upstream

printf '# Alpha\nHello [USER_NAME], version one.\n'  > "$REPO/files/alpha.md"
printf '# Beta\nStable content.\n'                   > "$REPO/files/beta.md"
printf '# Gamma\n[USER_NAME] gamma one.\n'           > "$REPO/files/gamma.md"
printf '# Delta\nWill be removed upstream.\n'        > "$REPO/files/delta.md"
printf '# Old\nRetired skill.\n'                     > "$REPO/files/old.md"
printf '# Zeta\nRename me.\n'                        > "$REPO/files/zeta.md"
printf '# Mu\nNotes use -- double hyphens.\n'        > "$REPO/files/mu.md"
git -C "$REPO" add -A && gitc "$REPO" -m "C0: files only, pre-manifest era"
C0=$(git -C "$REPO" rev-parse HEAD)

cat > "$REPO/install-manifest.json" <<'EOF'
{
  "kit": "memory-kit-claude",
  "manifest_schema": 1,
  "out_of_scope": ["skills/unrelated/"],
  "files": [
    { "source": "files/alpha.md", "install_to": "skills/alpha/SKILL.md", "type": "copied", "personalize": true,  "owner": "kit" },
    { "source": "files/beta.md",  "install_to": "skills/beta/SKILL.md",  "type": "copied", "personalize": false, "owner": "kit" },
    { "source": "files/gamma.md", "install_to": "skills/gamma/SKILL.md", "type": "copied", "personalize": true,  "owner": "kit" },
    { "source": "files/delta.md", "install_to": "skills/delta/SKILL.md", "type": "copied", "personalize": false, "owner": "kit" },
    { "source": "files/old.md",   "install_to": "skills/old/SKILL.md",   "type": "copied", "personalize": false, "owner": "kit",
      "retired": { "date": "2026-06-29", "replaced_by": "nothing" } },
    { "source": "files/zeta.md",  "install_to": "skills/zeta-old/SKILL.md", "type": "copied", "personalize": false, "owner": "kit" },
    { "source": "files/mu.md",    "install_to": "notes/mu.md",           "type": "copied", "personalize": false, "owner": "kit" },
    { "source": null, "install_to": "CLAUDE.md", "type": "generated", "owner": "user",
      "checks": ["section: Alpha Rules", "section: Beta Rules"] }
  ]
}
EOF
printf -- '- 2026-07-01 -- initial release\n' > "$REPO/CHANGELOG.md"
git -C "$REPO" add -A && gitc "$REPO" -m "C1: manifest v1 + changelog"
C1=$(git -C "$REPO" rev-parse HEAD)

printf '# Alpha\nHello [USER_NAME], version two.\n' > "$REPO/files/alpha.md"
printf '# Gamma\n[USER_NAME] gamma two.\n'          > "$REPO/files/gamma.md"
printf '# Epsilon\nBrand new.\n'                    > "$REPO/files/epsilon.md"
git -C "$REPO" rm -q files/delta.md
cat > "$REPO/install-manifest.json" <<'EOF'
{
  "kit": "memory-kit-claude",
  "manifest_schema": 1,
  "out_of_scope": ["skills/unrelated/"],
  "files": [
    { "source": "files/alpha.md", "install_to": "skills/alpha/SKILL.md", "type": "copied", "personalize": true,  "owner": "kit" },
    { "source": "files/beta.md",  "install_to": "skills/beta/SKILL.md",  "type": "copied", "personalize": false, "owner": "kit" },
    { "source": "files/gamma.md", "install_to": "skills/gamma/SKILL.md", "type": "copied", "personalize": true,  "owner": "kit" },
    { "source": "files/old.md",   "install_to": "skills/old/SKILL.md",   "type": "copied", "personalize": false, "owner": "kit",
      "retired": { "date": "2026-06-29", "replaced_by": "nothing" } },
    { "source": "files/zeta.md",  "install_to": "skills/zeta/SKILL.md",  "type": "copied", "personalize": false, "owner": "kit",
      "renamed_from": "skills/zeta-old/SKILL.md" },
    { "source": "files/mu.md",    "install_to": "notes/mu.md",           "type": "copied", "personalize": false, "owner": "kit" },
    { "source": "files/epsilon.md", "install_to": "skills/epsilon/SKILL.md", "type": "copied", "personalize": false, "owner": "kit" },
    { "source": null, "install_to": "CLAUDE.md", "type": "generated", "owner": "user",
      "checks": ["section: Alpha Rules", "section: Beta Rules"] }
  ]
}
EOF
printf -- '- 2026-07-09 -- alpha improved\n- 2026-07-09 -- zeta moved, epsilon added\n' >> "$REPO/CHANGELOG.md"
git -C "$REPO" add -A && gitc "$REPO" -m "C2: alpha+gamma v2, delta dropped, epsilon new, zeta renamed"
C2=$(git -C "$REPO" rev-parse HEAD)

# ------------------------------------------------------- schema-too-new fixture repo
R2="$WORK/upstream-schema"
mkdir -p "$R2/files"
git -C "$WORK" init -q upstream-schema
printf 'one v1\n' > "$R2/files/one.md"
cat > "$R2/install-manifest.json" <<'EOF'
{ "kit": "memory-kit-claude", "manifest_schema": 1,
  "files": [ { "source": "files/one.md", "install_to": "notes/one.md", "type": "copied", "personalize": false, "owner": "kit" } ] }
EOF
git -C "$R2" add -A && gitc "$R2" -m "schema1"
R2C1=$(git -C "$R2" rev-parse HEAD)
cat > "$R2/install-manifest.json" <<'EOF'
{ "kit": "memory-kit-claude", "manifest_schema": 2,
  "files": [ { "source": "files/one.md", "install_to": "notes/one.md", "type": "copied", "personalize": false, "owner": "kit" } ] }
EOF
git -C "$R2" add -A && gitc "$R2" -m "schema2"

# --------------------------------------------- no-changelog / updates-only fixture repo
R3="$WORK/upstream-nochangelog"
mkdir -p "$R3/files"
git -C "$WORK" init -q upstream-nochangelog
printf 'solo v1\n' > "$R3/files/solo.md"
cat > "$R3/install-manifest.json" <<'EOF'
{ "kit": "memory-kit-claude", "manifest_schema": 1,
  "files": [ { "source": "files/solo.md", "install_to": "notes/solo.md", "type": "copied", "personalize": false, "owner": "kit" } ] }
EOF
git -C "$R3" add -A && gitc "$R3" -m "solo v1"
R3C1=$(git -C "$R3" rev-parse HEAD)
printf 'solo v2\n' > "$R3/files/solo.md"
git -C "$R3" add -A && gitc "$R3" -m "solo v2"

# ------------------------------------------------------------------- home builders

good_claude_md() {
  printf '# My CLAUDE\n\n## Alpha Rules\nstuff here\n\n## Beta Rules\nmore stuff\n' > "$1/CLAUDE.md"
}

# home rendered exactly at C1 (the anchor), user Evan; anchor C1
home_baseline() { # dir [declined_json]
  local H="$1"
  mkdir -p "$H/skills/alpha" "$H/skills/beta" "$H/skills/gamma" "$H/skills/delta" "$H/skills/zeta-old" "$H/notes"
  git -C "$REPO" show "$C1:files/alpha.md" > "$WORK/tmp.src" && render_py "$WORK/tmp.src" "Evan" > "$H/skills/alpha/SKILL.md"
  git -C "$REPO" show "$C1:files/beta.md"  > "$H/skills/beta/SKILL.md"
  git -C "$REPO" show "$C1:files/gamma.md" > "$WORK/tmp.src" && render_py "$WORK/tmp.src" "Evan" > "$H/skills/gamma/SKILL.md"
  git -C "$REPO" show "$C1:files/delta.md" > "$H/skills/delta/SKILL.md"
  git -C "$REPO" show "$C1:files/zeta.md"  > "$H/skills/zeta-old/SKILL.md"
  git -C "$REPO" show "$C1:files/mu.md"    > "$H/notes/mu.md"
  good_claude_md "$H"
  write_config "$H" "$C1" "$REPO" "Evan" "${2:-}"
}

# home rendered exactly at C2 (HEAD); anchor C2
home_synced() { # dir [user_name]
  local H="$1" NAME="${2:-Evan}"
  mkdir -p "$H/skills/alpha" "$H/skills/beta" "$H/skills/gamma" "$H/skills/zeta" "$H/skills/epsilon" "$H/notes"
  git -C "$REPO" show "$C2:files/alpha.md" > "$WORK/tmp.src" && render_py "$WORK/tmp.src" "$NAME" > "$H/skills/alpha/SKILL.md"
  git -C "$REPO" show "$C2:files/beta.md"  > "$H/skills/beta/SKILL.md"
  git -C "$REPO" show "$C2:files/gamma.md" > "$WORK/tmp.src" && render_py "$WORK/tmp.src" "$NAME" > "$H/skills/gamma/SKILL.md"
  git -C "$REPO" show "$C2:files/zeta.md"  > "$H/skills/zeta/SKILL.md"
  git -C "$REPO" show "$C2:files/mu.md"    > "$H/notes/mu.md"
  git -C "$REPO" show "$C2:files/epsilon.md" > "$H/skills/epsilon/SKILL.md"
  good_claude_md "$H"
  write_config "$H" "$C2" "$REPO" "$NAME"
}

echo "=== kit-update-check.sh test suite ==="
echo "work dir: $WORK"
echo

# ================================================================ 1. all in-sync
H="$WORK/h-insync"; mkdir -p "$H"; home_synced "$H"
run_check "$H" "$REPO"
assert_eq "in-sync: exit code 0"                        "0" "$RC"
assert_eq "in-sync: alpha state"                        "in-sync" "$(state_of "$REPORT" skills/alpha/SKILL.md)"
assert_eq "in-sync: renamed zeta at new path is in-sync" "in-sync" "$(state_of "$REPORT" skills/zeta/SKILL.md)"
assert_eq "in-sync: epsilon state"                      "in-sync" "$(state_of "$REPORT" skills/epsilon/SKILL.md)"
assert_eq "in-sync: retired old absent"                 "retired-absent" "$(state_of "$REPORT" skills/old/SKILL.md)"
assert_eq "generated-all-sections: CLAUDE.md ok"        "generated-ok" "$(state_of "$REPORT" CLAUDE.md)"
assert_grep "changelog: no delta when anchored at HEAD" "No new changelog lines" "$REPORT"

# ============================================== 2. baseline mixed home (anchor C1)
H="$WORK/h-baseline"; mkdir -p "$H"; home_baseline "$H"
run_check "$H" "$REPO"
assert_eq "baseline: exit code 2 (escalations present)" "2" "$RC"
assert_eq "kit-ahead: alpha"                            "kit-ahead" "$(state_of "$REPORT" skills/alpha/SKILL.md)"
assert_eq "in-sync entry within mixed run: beta"        "in-sync" "$(state_of "$REPORT" skills/beta/SKILL.md)"
assert_eq "new-upstream: epsilon"                       "new" "$(state_of "$REPORT" skills/epsilon/SKILL.md)"
assert_eq "removed-upstream: delta"                     "removed-upstream" "$(state_of "$REPORT" skills/delta/SKILL.md)"
assert_eq "retired-absent: old"                         "retired-absent" "$(state_of "$REPORT" skills/old/SKILL.md)"
assert_eq "renamed: zeta live at old path -> kit-ahead" "kit-ahead" "$(state_of "$REPORT" skills/zeta/SKILL.md)"
assert_grep "renamed: report notes the pending move"    "would move live file from" "$REPORT"
assert_eq "generated-all-sections (mixed run)"          "generated-ok" "$(state_of "$REPORT" CLAUDE.md)"
assert_grep "changelog: assembled new lines present"    "alpha improved" "$REPORT"
assert_grep "changelog: assembled second line present"  "zeta moved, epsilon added" "$REPORT"
if grep -q "initial release" "$REPORT"; then
  bad "changelog: old lines excluded" "found 'initial release' in delta"
else
  ok "changelog: old lines excluded"
fi

# ============================================================= 3. already-current
H="$WORK/h-current"; mkdir -p "$H"; home_baseline "$H"
git -C "$REPO" show "$C2:files/alpha.md" > "$WORK/tmp.src" && render_py "$WORK/tmp.src" "Evan" > "$H/skills/alpha/SKILL.md"
run_check "$H" "$REPO"
assert_eq "already-current: alpha hand-updated to HEAD" "already-current" "$(state_of "$REPORT" skills/alpha/SKILL.md)"

# ================================================================== 4. live-ahead
H="$WORK/h-liveahead"; mkdir -p "$H"; home_baseline "$H"
printf '\nA local improvement the kit does not have yet.\n' >> "$H/notes/mu.md"
run_check "$H" "$REPO"
assert_eq "live-ahead: mu edited live, unchanged upstream" "live-ahead" "$(state_of "$REPORT" notes/mu.md)"
assert_eq "live-ahead: exit code 2"                        "2" "$RC"

# ==================================================================== 5. diverged
H="$WORK/h-diverged"; mkdir -p "$H"; home_baseline "$H"
printf '# Gamma\nlocally rewritten gamma.\n' > "$H/skills/gamma/SKILL.md"
run_check "$H" "$REPO"
assert_eq "diverged: gamma moved on both sides" "diverged" "$(state_of "$REPORT" skills/gamma/SKILL.md)"
assert_eq "diverged: exit code 2"               "2" "$RC"

# ================================================================ 6. missing-live
H="$WORK/h-missing"; mkdir -p "$H"; home_baseline "$H"
rm "$H/skills/beta/SKILL.md"
run_check "$H" "$REPO"
assert_eq "missing-live: beta absent" "missing" "$(state_of "$REPORT" skills/beta/SKILL.md)"

# ============================================== 7. exit 1: updates only, no escalations
H="$WORK/h-updatesonly"; mkdir -p "$H"; home_synced "$H"
rm "$H/skills/beta/SKILL.md"
run_check "$H" "$REPO"
assert_eq "exit-1: missing-only run exits 1" "1" "$RC"
assert_eq "exit-1: beta missing"             "missing" "$(state_of "$REPORT" skills/beta/SKILL.md)"

# ===================================================================== 8. conflict
H="$WORK/h-conflict"; mkdir -p "$H"; home_baseline "$H"
mkdir -p "$H/skills/epsilon"
printf 'something the user already had here\n' > "$H/skills/epsilon/SKILL.md"
run_check "$H" "$REPO"
assert_eq "conflict: epsilon live differs from new upstream file" "conflict" "$(state_of "$REPORT" skills/epsilon/SKILL.md)"
assert_eq "conflict: exit code 2"                                 "2" "$RC"

# ================================= 9. source absent at installed, live == render(HEAD)
H="$WORK/h-newcurrent"; mkdir -p "$H"; home_baseline "$H"
mkdir -p "$H/skills/epsilon"
git -C "$REPO" show "$C2:files/epsilon.md" > "$H/skills/epsilon/SKILL.md"
run_check "$H" "$REPO"
assert_eq "new-but-already-current: epsilon matches render(HEAD)" "already-current" "$(state_of "$REPORT" skills/epsilon/SKILL.md)"

# ============================================================== 10. retired-present
H="$WORK/h-retired"; mkdir -p "$H"; home_baseline "$H"
mkdir -p "$H/skills/old"
printf '# Old\nRetired skill.\n' > "$H/skills/old/SKILL.md"
run_check "$H" "$REPO"
assert_eq "retired-present: old found live" "retired-present" "$(state_of "$REPORT" skills/old/SKILL.md)"
assert_eq "retired-present: exit code 2"    "2" "$RC"
assert_grep "retired-present: action is a move, not a delete" "kit-retired" "$REPORT"

# ====================================================== 11. generated-missing-section
H="$WORK/h-genfail"; mkdir -p "$H"; home_baseline "$H"
printf '# My CLAUDE\n\n## Alpha Rules\nstuff here\n' > "$H/CLAUDE.md"
run_check "$H" "$REPO"
assert_eq "generated-missing-section: state"    "generated-failed" "$(state_of "$REPORT" CLAUDE.md)"
assert_eq "generated-missing-section: exit 2"   "2" "$RC"
assert_grep "generated-missing-section: names the missing section" "Beta Rules" "$REPORT"

# ==================================================================== 12. no-config
H="$WORK/h-noconfig"; mkdir -p "$H"
run_check "$H" "$REPO"
assert_eq "no-config: exit code 4" "4" "$RC"
assert_grep "no-config: adoption offer printed" "No kit config found" "$OUT"
assert_grep "no-config: dry-run reassurance"    "nothing was written" "$OUT"

# ==================================== 13. no-manifest-at-installed (re-baseline posture)
H="$WORK/h-nomanifest"; mkdir -p "$H"; home_baseline "$H"
write_config "$H" "$C0" "$REPO" "Evan"
run_check "$H" "$REPO"
assert_eq "no-manifest-at-installed: exit 2"                 "2" "$RC"
assert_grep "no-manifest-at-installed: re-baseline warning"  "Re-baseline posture" "$REPORT"
assert_eq "no-manifest-at-installed: beta matches HEAD -> already-current" "already-current" "$(state_of "$REPORT" skills/beta/SKILL.md)"
assert_eq "no-manifest-at-installed: alpha (old render) -> diverged"       "diverged" "$(state_of "$REPORT" skills/alpha/SKILL.md)"
assert_eq "no-manifest-at-installed: absent epsilon -> missing"            "missing" "$(state_of "$REPORT" skills/epsilon/SKILL.md)"

# ================================================= 14. lost anchor (fake SHA, force-push)
H="$WORK/h-lostanchor"; mkdir -p "$H"; home_baseline "$H"
write_config "$H" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" "$REPO" "Evan"
run_check "$H" "$REPO"
assert_eq "lost-anchor: exit 2"                        "2" "$RC"
assert_grep "lost-anchor: explicit warning"            "anchor lost" "$REPORT"
assert_eq "lost-anchor: beta -> already-current"       "already-current" "$(state_of "$REPORT" skills/beta/SKILL.md)"
assert_eq "lost-anchor: alpha (old render) -> diverged" "diverged" "$(state_of "$REPORT" skills/alpha/SKILL.md)"

# ============================================================ 15. declined bookkeeping
H="$WORK/h-declined"; mkdir -p "$H"
home_baseline "$H" "{\"skills/alpha/SKILL.md\": \"$C2\"}"
run_check "$H" "$REPO"
assert_eq "declined-pending: alpha declined at HEAD, not re-nagged" "declined-pending" "$(state_of "$REPORT" skills/alpha/SKILL.md)"

H="$WORK/h-redeclined"; mkdir -p "$H"
home_baseline "$H" "{\"skills/alpha/SKILL.md\": \"$C1\"}"
run_check "$H" "$REPO"
assert_eq "declined-then-changed-again: alpha re-prompts as kit-ahead" "kit-ahead" "$(state_of "$REPORT" skills/alpha/SKILL.md)"

# ============================================================ 16. schema-version-too-new
H="$WORK/h-schema"; mkdir -p "$H"
write_config "$H" "$R2C1" "$R2" "Evan"
run_check "$H" "$R2"
assert_eq "schema-too-new: exit code 3" "3" "$RC"
assert_grep "schema-too-new: says update the updater first" "pdate the updater first" "$OUT"

# ======================================================================== 17. locking
H="$WORK/h-lockfresh"; mkdir -p "$H"; home_baseline "$H"
mkdir "$H/.kit-update.lock"
printf 'pid=99999\ntime=now\nepoch=%s\n' "$(date +%s)" > "$H/.kit-update.lock/info"
run_check "$H" "$REPO"
assert_eq "locked-fresh: exit code 3"          "3" "$RC"
assert_grep "locked-fresh: reports in progress" "in progress" "$OUT"
if [ -d "$H/.kit-update.lock" ]; then
  ok "locked-fresh: does not remove the other run's lock"
else
  bad "locked-fresh: does not remove the other run's lock" "lock dir was removed"
fi

H="$WORK/h-lockstale"; mkdir -p "$H"; home_baseline "$H"
mkdir "$H/.kit-update.lock"
printf 'pid=99999\ntime=old\nepoch=%s\n' "$(($(date +%s) - 3600))" > "$H/.kit-update.lock/info"
run_check "$H" "$REPO"
assert_eq "locked-stale: stale lock broken, run proceeds (exit 2)" "2" "$RC"
if [ -d "$H/.kit-update.lock" ]; then
  bad "locked-stale: lock released after run" "lock dir still present"
else
  ok "locked-stale: lock released after run"
fi

# ==================================================== 18. user name with metacharacters
NAME="O'Brien & Co/"
H="$WORK/h-metaname"; mkdir -p "$H"; home_synced "$H" "$NAME"
run_check "$H" "$REPO"
assert_eq "metachar-name: all in-sync (render is literal)" "0" "$RC"
assert_eq "metachar-name: alpha in-sync"                   "in-sync" "$(state_of "$REPORT" skills/alpha/SKILL.md)"
assert_grep "metachar-name: name landed literally in live file" "O'Brien & Co/" "$H/skills/alpha/SKILL.md"

NAME2='Back\slash "Quotes"'
H="$WORK/h-backslashname"; mkdir -p "$H"; home_synced "$H" "$NAME2"
run_check "$H" "$REPO"
assert_eq "backslash-name: all in-sync (no awk escape corruption)" "0" "$RC"
assert_eq "backslash-name: gamma in-sync"                          "in-sync" "$(state_of "$REPORT" skills/gamma/SKILL.md)"

# ========================================================= 19. em-dash byte difference
H="$WORK/h-emdash"; mkdir -p "$H"; home_synced "$H"
printf '# Mu\nNotes use \xe2\x80\x94 double hyphens.\n' > "$H/notes/mu.md"
run_check "$H" "$REPO"
assert_eq "em-dash-difference: detected as live-ahead" "live-ahead" "$(state_of "$REPORT" notes/mu.md)"
assert_eq "em-dash-difference: exit code 2"            "2" "$RC"

# ============================================= 20. changelog absent / updates-only repo
H="$WORK/h-nochangelog"; mkdir -p "$H/notes"
printf 'solo v1\n' > "$H/notes/solo.md"
write_config "$H" "$R3C1" "$R3" "Evan"
run_check "$H" "$R3"
assert_eq "updates-available: kit-ahead only run exits 1" "1" "$RC"
assert_eq "updates-available: solo kit-ahead"             "kit-ahead" "$(state_of "$REPORT" notes/solo.md)"
assert_grep "changelog-absent: report says so"            "No CHANGELOG.md at HEAD" "$REPORT"

# =========================== 21. missing user_name with personalize:true entries
H="$WORK/h-noname"; mkdir -p "$H"; home_baseline "$H"
python3 -c "import json; open('$H/kit-config/memory-kit-claude.json','w').write(json.dumps({'kit':'memory-kit-claude','installed_commit':'$C1','update_source':'$REPO','auto_update':True}))"
run_check "$H" "$REPO"
assert_eq "missing-user-name: exit code 3"                       "3" "$RC"
assert_grep "missing-user-name: message names the missing field" "user_name" "$OUT"
assert_grep "missing-user-name: message names the config path"   "kit-config/memory-kit-claude.json" "$OUT"

H="$WORK/h-emptyname"; mkdir -p "$H"; home_baseline "$H"
write_config "$H" "$C1" "$REPO" ""
run_check "$H" "$REPO"
assert_eq "empty-user-name: exit code 3" "3" "$RC"

# ============================================== 22. unwritable/nonexistent report path
H="$WORK/h-badreport"; mkdir -p "$H"; home_baseline "$H"
run_check "$H" "$REPO" --report "$WORK/no-such-dir/report.md"
assert_eq "unwritable-report: exit code 3"           "3" "$RC"
assert_grep "unwritable-report: error names the path" "no-such-dir/report.md" "$OUT"

# ================================================================== summary
echo
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
