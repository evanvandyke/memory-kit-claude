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

# -------------------------------------------------- malformed manifest fixture repo
R4="$WORK/upstream-malformed"
mkdir -p "$R4/files"
git -C "$WORK" init -q upstream-malformed
printf 'valid first version\n' > "$R4/files/one.md"
cat > "$R4/install-manifest.json" <<'EOF'
{ "kit": "memory-kit-claude", "manifest_schema": 1,
  "files": [ { "source": "files/one.md", "install_to": "notes/one.md", "type": "copied", "personalize": false, "owner": "kit" } ] }
EOF
git -C "$R4" add -A && gitc "$R4" -m "valid manifest"
R4C1=$(git -C "$R4" rev-parse HEAD)
printf '{"kit": "memory-kit-claude", "files": [' > "$R4/install-manifest.json"
git -C "$R4" add -A && gitc "$R4" -m "malformed manifest"

# ---------------------------------------------------------- pinned release fixture repo
RP="$WORK/upstream-pinned"
mkdir -p "$RP/files"
git -C "$WORK" init -q upstream-pinned
printf 'selected file version one\n' > "$RP/files/selected.md"
printf 'later file stays stable\n' > "$RP/files/later.md"
cat > "$RP/install-manifest.json" <<'EOF'
{ "kit": "memory-kit-claude", "manifest_schema": 1,
  "files": [
    { "source": "files/selected.md", "install_to": "notes/selected.md", "type": "copied", "personalize": false, "owner": "kit" },
    { "source": "files/later.md", "install_to": "notes/later.md", "type": "copied", "personalize": false, "owner": "kit" }
  ] }
EOF
printf 'Pinned release history\n' > "$RP/CHANGELOG.md"
git -C "$RP" add -A && gitc "$RP" -m "pinned baseline"
RP1=$(git -C "$RP" rev-parse HEAD)
printf 'selected file version two\n' > "$RP/files/selected.md"
printf 'Tested release selected file update\n' >> "$RP/CHANGELOG.md"
git -C "$RP" add -A && gitc "$RP" -m "tested release"
RP2=$(git -C "$RP" rev-parse HEAD)
git -C "$RP" tag tested-release
git -C "$RP" branch tested-branch "$RP2"
printf 'later file changed after the tested release\n' > "$RP/files/later.md"
printf 'Post release later file update\n' >> "$RP/CHANGELOG.md"
git -C "$RP" add -A && gitc "$RP" -m "newer unselected work"
RP3=$(git -C "$RP" rev-parse HEAD)

pin_home() { # home update_ref
  mkdir -p "$1/notes"
  git -C "$RP" show "$RP1:files/selected.md" > "$1/notes/selected.md"
  git -C "$RP" show "$RP1:files/later.md" > "$1/notes/later.md"
  write_config "$1" "$RP1" "$RP" "Evan"
  python3 -c 'import json,sys
p=sys.argv[1]
d=json.load(open(p))
d["update_ref"]=sys.argv[2]
open(p,"w").write(json.dumps(d,indent=2)+"\n")' "$1/kit-config/memory-kit-claude.json" "$2"
}

# ------------------------------------------------ pending approval fixture repo
RD="$WORK/upstream-pending"
mkdir -p "$RD/files"
git -C "$WORK" init -q upstream-pending
printf '#!/bin/sh\necho approval-v1\n' > "$RD/files/gated.sh"
printf 'ordinary version one\n' > "$RD/files/ordinary.md"
printf 'removed upstream later\n' > "$RD/files/removed.md"
cat > "$RD/install-manifest.json" <<'EOF'
{ "kit": "memory-kit-claude", "manifest_schema": 1,
  "files": [
    { "source": "files/gated.sh", "install_to": "kit-scripts/kit-update-check.sh", "type": "copied", "personalize": false, "owner": "kit", "mode": "755", "consent": "per-change" },
    { "source": "files/ordinary.md", "install_to": "notes/ordinary.md", "type": "copied", "personalize": false, "owner": "kit" },
    { "source": "files/removed.md", "install_to": "notes/removed.md", "type": "copied", "personalize": false, "owner": "kit" },
    { "source": null, "install_to": "notes/retired.md", "type": "copied", "personalize": false, "owner": "kit", "retired": { "date": "2026-07-16" } }
  ] }
EOF
printf 'Pending approval history\n' > "$RD/CHANGELOG.md"
git -C "$RD" add -A && gitc "$RD" -m "pre-removal baseline"
RD0=$(git -C "$RD" rev-parse HEAD)
git -C "$RD" rm -q files/removed.md
python3 -c 'import json,sys
p=sys.argv[1]
d=json.load(open(p))
d["files"]=[e for e in d["files"] if e["install_to"]!="notes/removed.md"]
open(p,"w").write(json.dumps(d,indent=2)+"\n")' "$RD/install-manifest.json"
git -C "$RD" add -A && gitc "$RD" -m "pending baseline"
RD1=$(git -C "$RD" rev-parse HEAD)
printf '#!/bin/sh\necho approval-v2\n' > "$RD/files/gated.sh"
printf '#!/bin/sh\necho new-approval\n' > "$RD/files/new-gated.sh"
python3 -c 'import json,sys
p=sys.argv[1]
d=json.load(open(p))
d["files"].append({"source":"files/new-gated.sh","install_to":"kit-scripts/new-gated.sh","type":"copied","personalize":False,"owner":"kit","mode":"755","consent":"per-change"})
open(p,"w").write(json.dumps(d,indent=2)+"\n")' "$RD/install-manifest.json"
printf 'Gated file update\n' >> "$RD/CHANGELOG.md"
git -C "$RD" add -A && gitc "$RD" -m "gated change"
RD2=$(git -C "$RD" rev-parse HEAD)
printf 'ordinary version two\n' > "$RD/files/ordinary.md"
printf 'Later ordinary update\n' >> "$RD/CHANGELOG.md"
git -C "$RD" add -A && gitc "$RD" -m "later unrelated change"
RD3=$(git -C "$RD" rev-parse HEAD)

pending_home() {
  mkdir -p "$1/kit-scripts" "$1/notes"
  git -C "$RD" show "$RD1:files/gated.sh" > "$1/kit-scripts/kit-update-check.sh"
  chmod 755 "$1/kit-scripts/kit-update-check.sh"
  git -C "$RD" show "$RD1:files/ordinary.md" > "$1/notes/ordinary.md"
  git -C "$RD" show "$RD3:files/new-gated.sh" > "$1/kit-scripts/new-gated.sh"
  chmod 755 "$1/kit-scripts/new-gated.sh"
  write_config "$1" "$RD1" "$RD" "Evan"
}

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
assert_grep "report: exit legend names code 5"           "5 kit data needs attention" "$REPORT"

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
assert_eq "schema-too-new: exit code 5" "5" "$RC"
assert_grep "schema-too-new: says update the updater first" "pdate the updater first" "$OUT"

H="$WORK/h-malformed"; mkdir -p "$H"
write_config "$H" "$R4C1" "$R4" "Evan"
run_check "$H" "$R4"
assert_eq "malformed-head: exit code 5" "5" "$RC"
assert_grep "malformed-head: message names malformed manifest" "malformed" "$OUT"

H="$WORK/h-unreachable"; mkdir -p "$H"; home_baseline "$H"
run_check "$H" "$WORK/upstream-does-not-exist"
assert_eq "unreachable-upstream: exit code 3" "3" "$RC"
assert_grep "unreachable-upstream: message says the check failed" "Couldn't check" "$OUT"

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
assert_eq "missing-user-name: exit code 5"                       "5" "$RC"
assert_grep "missing-user-name: message names the missing field" "user_name" "$OUT"
assert_grep "missing-user-name: message names the config path"   "kit-config/memory-kit-claude.json" "$OUT"

H="$WORK/h-emptyname"; mkdir -p "$H"; home_baseline "$H"
write_config "$H" "$C1" "$REPO" ""
run_check "$H" "$REPO"
assert_eq "empty-user-name: exit code 5" "5" "$RC"

# ============================================== 22. unwritable/nonexistent report path
H="$WORK/h-badreport"; mkdir -p "$H"; home_baseline "$H"
run_check "$H" "$REPO" --report "$WORK/no-such-dir/report.md"
assert_eq "unwritable-report: exit code 3"           "3" "$RC"
assert_grep "unwritable-report: error names the path" "no-such-dir/report.md" "$OUT"

# ###########################################################################
# APPLY MODE + UNDO
# ###########################################################################

# applied_of <report> <install_to> -> action from the APPLIED machine block
applied_of() {
  awk -F'\t' -v p="$2" '
    /APPLIED-END/   {insec=0}
    insec && $2==p  {print $1; exit}
    /APPLIED-BEGIN/ {insec=1}
  ' "$1" 2>/dev/null
}

cfg_commit() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("installed_commit",""))' "$1" 2>/dev/null
}

# checksum sweep of a home, excluding backup dirs and the transient lock
sweep() {
  (cd "$1" && find . -type f ! -path './kit-backups/*' ! -path './.kit-update.lock/*' -exec shasum -a 256 {} + 2>/dev/null | LC_ALL=C sort)
}

perm_of() { stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1" 2>/dev/null; }

newest_backup() { ls -1 "$1/kit-backups" 2>/dev/null | LC_ALL=C sort | tail -1; }

write_config_auto() { # home installed_commit update_source user_name auto(true|false)
  mkdir -p "$1/kit-config"
  python3 -c 'import json,sys
cfg={"kit":"memory-kit-claude","installed_commit":sys.argv[2],
     "installed_at":"2026-07-09T00:00:00Z","update_source":sys.argv[3],
     "user_name":sys.argv[4],"auto_update":(sys.argv[5]=="true"),"declined":{}}
open(sys.argv[1],"w").write(json.dumps(cfg,indent=2))' \
    "$1/kit-config/memory-kit-claude.json" "$2" "$3" "$4" "$5"
}

# ===================================== source pinning selects the configured release
H="$WORK/h-pinned"; mkdir -p "$H"; pin_home "$H" "tested-release"
run_check "$H" "$RP" --apply
assert_eq "pinned: apply exits 0" "0" "$RC"
git -C "$RP" show "$RP2:files/selected.md" > "$WORK/want-pinned-selected.md"
if cmp -s "$H/notes/selected.md" "$WORK/want-pinned-selected.md"; then
  ok "pinned: selected release update applied"
else
  bad "pinned: selected release update applied" "selected file does not match the tag"
fi
assert_eq "pinned: later upstream change remains in-sync" "in-sync" "$(state_of "$REPORT" notes/later.md)"
git -C "$RP" show "$RP1:files/later.md" > "$WORK/want-pinned-later.md"
if cmp -s "$H/notes/later.md" "$WORK/want-pinned-later.md"; then
  ok "pinned: later upstream bytes ignored"
else
  bad "pinned: later upstream bytes ignored" "live file took changes after the tag"
fi
assert_eq "pinned: anchor advances to the tagged commit" "$RP2" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"
assert_grep "pinned: report names the configured ref" "update_ref: tested-release" "$REPORT"
assert_grep "pinned: report names the resolved commit" "resolved_commit: $RP2" "$REPORT"

H="$WORK/h-bad-pin"; mkdir -p "$H"; pin_home "$H" "release-that-does-not-exist"
sweep "$H" > "$WORK/sweep-bad-pin-before.txt"
run_check "$H" "$RP" --apply
sweep "$H" > "$WORK/sweep-bad-pin-after.txt"
assert_eq "bad-pin: unresolved ref exits 5" "5" "$RC"
assert_grep "bad-pin: message names the ref" "release-that-does-not-exist" "$OUT"
if diff -q "$WORK/sweep-bad-pin-before.txt" "$WORK/sweep-bad-pin-after.txt" >/dev/null; then
  ok "bad-pin: unresolved ref writes nothing"
else
  bad "bad-pin: unresolved ref writes nothing" "home contents changed"
fi

H="$WORK/h-pinned-branch"; mkdir -p "$H"; pin_home "$H" "tested-branch"
run_check "$H" "$RP" --apply
assert_eq "branch-pin: nondefault branch resolves" "0" "$RC"
assert_eq "branch-pin: anchor advances to the branch commit" "$RP2" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"
assert_eq "branch-pin: later upstream change remains in-sync" "in-sync" "$(state_of "$REPORT" notes/later.md)"
assert_grep "branch-pin: report names the configured branch" "update_ref: tested-branch" "$REPORT"

# ============================= an exact decline stays declined during apply
H="$WORK/h-declined-per-change"; mkdir -p "$H"; pending_home "$H"
run_check "$H" "$RD" --apply
python3 -c 'import json,sys
p=sys.argv[1]
d=json.load(open(p))
d["declined"]={"kit-scripts/kit-update-check.sh":sys.argv[2]}
open(p,"w").write(json.dumps(d,indent=2)+"\n")' "$H/kit-config/memory-kit-claude.json" "$RD3"
run_check "$H" "$RD" --apply
assert_eq "declined-per-change: state remains declined" "declined-pending" "$(state_of "$REPORT" kit-scripts/kit-update-check.sh)"
DECLINED_SHA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("declined",{}).get("kit-scripts/kit-update-check.sh",""))' "$H/kit-config/memory-kit-claude.json")
assert_eq "declined-per-change: decline record survives" "$RD3" "$DECLINED_SHA"
PENDING_SHA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("pending_approval",{}).get("kit-scripts/kit-update-check.sh",""))' "$H/kit-config/memory-kit-claude.json")
assert_eq "declined-per-change: no pending approval record appears" "" "$PENDING_SHA"
if grep -q "individual approval" "$REPORT"; then
  bad "declined-per-change: report does not ask again" "approval request found"
else
  ok "declined-per-change: report does not ask again"
fi

# ========================== a declined new per-change file stays absent
H="$WORK/h-declined-new"; mkdir -p "$H"; pending_home "$H"
cp "$RD/files/gated.sh" "$H/kit-scripts/kit-update-check.sh"
chmod 755 "$H/kit-scripts/kit-update-check.sh"
cp "$RD/files/ordinary.md" "$H/notes/ordinary.md"
rm "$H/kit-scripts/new-gated.sh"
python3 -c 'import json,sys
p=sys.argv[1]
d=json.load(open(p))
d["declined"]={"kit-scripts/new-gated.sh":sys.argv[2]}
open(p,"w").write(json.dumps(d,indent=2)+"\n")' "$H/kit-config/memory-kit-claude.json" "$RD3"
run_check "$H" "$RD" --apply
assert_eq "declined-new: state remains declined" "declined-pending" "$(state_of "$REPORT" kit-scripts/new-gated.sh)"
if grep -q "individual approval" "$REPORT"; then
  bad "declined-new: report does not request approval" "approval request found"
else
  ok "declined-new: report does not request approval"
fi

# ======================= approval with automatic updates off is narrowly scoped
H="$WORK/h-approve-auto-off"; mkdir -p "$H"; pending_home "$H"
python3 -c 'import json,sys
p=sys.argv[1]
d=json.load(open(p))
d["auto_update"]=False
d["installed_commit"]=sys.argv[2]
open(p,"w").write(json.dumps(d,indent=2)+"\n")' "$H/kit-config/memory-kit-claude.json" "$RD0"
printf 'retired file must stay live\n' > "$H/notes/retired.md"
printf 'removed upstream file must stay live\n' > "$H/notes/removed.md"
run_check "$H" "$RD" --approve kit-scripts/kit-update-check.sh
if cmp -s "$H/kit-scripts/kit-update-check.sh" "$RD/files/gated.sh"; then
  ok "approve-auto-off: approved file changed"
else
  bad "approve-auto-off: approved file changed" "approved bytes differ"
fi
git -C "$RD" show "$RD1:files/ordinary.md" > "$WORK/want-auto-off-ordinary.md"
if cmp -s "$H/notes/ordinary.md" "$WORK/want-auto-off-ordinary.md"; then
  ok "approve-auto-off: other kit update stayed unchanged"
else
  bad "approve-auto-off: other kit update stayed unchanged" "ordinary file changed"
fi
if printf 'retired file must stay live\n' | cmp -s - "$H/notes/retired.md"; then
  ok "approve-auto-off: retired file stayed live"
else
  bad "approve-auto-off: retired file stayed live" "retired file moved or changed"
fi
if printf 'removed upstream file must stay live\n' | cmp -s - "$H/notes/removed.md"; then
  ok "approve-auto-off: removed upstream file stayed live"
else
  bad "approve-auto-off: removed upstream file stayed live" "removed upstream file moved or changed"
fi
assert_eq "approve-auto-off: anchor stays at the installed commit" "$RD0" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"
BK=$(newest_backup "$H")
if grep -q $'^updated\tkit-scripts/kit-update-check.sh$' "$H/kit-backups/$BK/.kit-backup-manifest.tsv" 2>/dev/null &&
   ! grep -q $'notes/ordinary.md\|notes/retired.md\|notes/removed.md' "$H/kit-backups/$BK/.kit-backup-manifest.tsv" 2>/dev/null; then
  ok "approve-auto-off: backup manifest records only the approved file"
else
  bad "approve-auto-off: backup manifest records only the approved file" "another file action was recorded"
fi

# ================================== pending approval stays stable across later commits
H="$WORK/h-pending"; mkdir -p "$H"; pending_home "$H"
run_check "$H" "$RD" --apply
assert_eq "pending: apply exits 1" "1" "$RC"
assert_eq "pending: gated file awaits approval" "pending-approval" "$(state_of "$REPORT" kit-scripts/kit-update-check.sh)"
assert_grep "pending: report explains the approval wait" "awaiting your individual approval" "$REPORT"
assert_grep "pending: approval wait appears under needs attention" "## Needs your attention" "$REPORT"
assert_eq "pending: anchor advances past unrelated commits" "$RD3" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"
PENDING_SHA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("pending_approval",{}).get("kit-scripts/kit-update-check.sh",""))' "$H/kit-config/memory-kit-claude.json")
assert_eq "pending: config records the live render commit" "$RD1" "$PENDING_SHA"
git -C "$RD" show "$RD3:files/ordinary.md" > "$WORK/want-ordinary-v2.md"
if cmp -s "$H/notes/ordinary.md" "$WORK/want-ordinary-v2.md"; then
  ok "pending: unrelated ordinary update applied"
else
  bad "pending: unrelated ordinary update applied" "ordinary file did not update"
fi
BK=$(newest_backup "$H")
if grep -q $'^updated\tkit-config/memory-kit-claude.json$' "$H/kit-backups/$BK/.kit-backup-manifest.tsv" 2>/dev/null; then
  ok "pending: config change follows backup discipline"
else
  bad "pending: config change follows backup discipline" "config backup record missing"
fi
CONFIG_BEFORE=$(shasum -a 256 "$H/kit-config/memory-kit-claude.json" | awk '{print $1}')
run_check "$H" "$RD"
assert_eq "pending-later: dry run exits 1" "1" "$RC"
assert_eq "pending-later: state remains pending approval" "pending-approval" "$(state_of "$REPORT" kit-scripts/kit-update-check.sh)"
assert_eq "pending-later: dry run leaves config unchanged" "$CONFIG_BEFORE" "$(shasum -a 256 "$H/kit-config/memory-kit-claude.json" | awk '{print $1}')"

# ====================================== individual approval applies and remains undoable
git -C "$RD" show "$RD1:files/gated.sh" > "$WORK/want-approved-old.sh"
git -C "$RD" show "$RD3:files/gated.sh" > "$WORK/want-approved-new.sh"
run_check "$H" "$RD" --approve kit-scripts/kit-update-check.sh
assert_eq "approve: run exits 0" "0" "$RC"
assert_eq "approve: applied action records individual approval" "individually-approved" "$(applied_of "$REPORT" kit-scripts/kit-update-check.sh)"
assert_grep "approve: report uses individual approval wording" "individually approved" "$REPORT"
if cmp -s "$H/kit-scripts/kit-update-check.sh" "$WORK/want-approved-new.sh"; then
  ok "approve: updater script receives the selected version"
else
  bad "approve: updater script receives the selected version" "approved bytes differ"
fi
PENDING_SHA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("pending_approval",{}).get("kit-scripts/kit-update-check.sh",""))' "$H/kit-config/memory-kit-claude.json")
assert_eq "approve: pending record cleared" "" "$PENDING_SHA"
BK=$(newest_backup "$H")
if cmp -s "$H/kit-backups/$BK/kit-scripts/kit-update-check.sh" "$WORK/want-approved-old.sh"; then
  ok "approve: previous updater version backed up"
else
  bad "approve: previous updater version backed up" "backup missing or changed"
fi
run_check "$H" "$RD" --undo
assert_eq "approve: undo exits 0" "0" "$RC"
if cmp -s "$H/kit-scripts/kit-update-check.sh" "$WORK/want-approved-old.sh"; then
  ok "approve: undo restores the previous updater version"
else
  bad "approve: undo restores the previous updater version" "restored bytes differ"
fi
PENDING_SHA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("pending_approval",{}).get("kit-scripts/kit-update-check.sh",""))' "$H/kit-config/memory-kit-claude.json")
assert_eq "approve: undo restores the pending record" "$RD1" "$PENDING_SHA"
cp "$WORK/want-approved-new.sh" "$H/kit-scripts/kit-update-check.sh"
chmod 755 "$H/kit-scripts/kit-update-check.sh"
run_check "$H" "$RD" --apply
assert_eq "pending-current: apply exits 0" "0" "$RC"
PENDING_SHA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("pending_approval",{}).get("kit-scripts/kit-update-check.sh",""))' "$H/kit-config/memory-kit-claude.json")
assert_eq "pending-current: current file clears its pending record" "" "$PENDING_SHA"

# =========================== approval config failure is operational and recoverable
H="$WORK/h-approve-config-fail"; mkdir -p "$H"; pending_home "$H"
run_check "$H" "$RD" --apply
CONFIG_BEFORE=$(shasum -a 256 "$H/kit-config/memory-kit-claude.json" | awk '{print $1}')
TESTN=$((TESTN+1)); REPORT="$WORK/report-$TESTN.md"; OUT="$WORK/out-$TESTN.txt"
KUC_TEST_FAIL_CONFIG_WRITE=1 bash "$SCRIPT" --home "$H" --upstream "$RD" --report "$REPORT" --approve kit-scripts/kit-update-check.sh > "$OUT" 2>&1
RC=$?
assert_eq "approve-config-fail: exits 3" "3" "$RC"
if cmp -s "$H/kit-scripts/kit-update-check.sh" "$RD/files/gated.sh"; then
  ok "approve-config-fail: approved file was installed"
else
  bad "approve-config-fail: approved file was installed" "approved bytes differ"
fi
assert_eq "approve-config-fail: config remains unchanged" "$CONFIG_BEFORE" "$(shasum -a 256 "$H/kit-config/memory-kit-claude.json" | awk '{print $1}')"
PENDING_SHA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("pending_approval",{}).get("kit-scripts/kit-update-check.sh",""))' "$H/kit-config/memory-kit-claude.json")
assert_eq "approve-config-fail: pending record remains for reconciliation" "$RD1" "$PENDING_SHA"
assert_grep "approve-config-fail: report names the config failure" "config write failed" "$REPORT"
assert_grep "approve-config-fail: report promises reconciliation" "next run will reconcile" "$REPORT"

H="$WORK/h-approve-unknown"; mkdir -p "$H"; pending_home "$H"
sweep "$H" > "$WORK/sweep-approve-unknown-before.txt"
run_check "$H" "$RD" --approve notes/not-in-the-manifest.md
sweep "$H" > "$WORK/sweep-approve-unknown-after.txt"
assert_eq "approve-unknown: exits 3" "3" "$RC"
assert_grep "approve-unknown: message names the path" "notes/not-in-the-manifest.md" "$OUT"
if diff -q "$WORK/sweep-approve-unknown-before.txt" "$WORK/sweep-approve-unknown-after.txt" >/dev/null && [ ! -d "$H/kit-backups" ]; then
  ok "approve-unknown: writes nothing"
else
  bad "approve-unknown: writes nothing" "home contents or backups changed"
fi
run_check "$H" "$RD" --approve notes/ordinary.md
assert_eq "approve-ordinary: non-gated entry exits 3" "3" "$RC"
assert_grep "approve-ordinary: message explains no approval is required" "does not require individual approval" "$OUT"
run_check "$H" "$RD" --approve kit-scripts/kit-update-check.sh --undo
assert_eq "approve-undo: exits 3" "3" "$RC"
assert_grep "approve-undo: message names both flags" "cannot be used with --undo" "$OUT"

# ----------------------------------------------------------- apply fixture repo
# A1: baseline manifest. A2 (HEAD): a + user + exec change, zr renamed,
# eps (plain) and locked (mode 600) added, old stays retired.
RA="$WORK/upstream-apply"
mkdir -p "$RA/files"
git -C "$WORK" init -q upstream-apply

printf '# A\nHello [USER_NAME], apply v1.\n' > "$RA/files/a.md"
printf '# B\nStable b.\n'                    > "$RA/files/b.md"
printf '# User\nUser-owned notes v1.\n'      > "$RA/files/user.md"
printf '#!/bin/sh\necho v1\n'                > "$RA/files/exec.sh"
printf '# Zr\nRename me too.\n'              > "$RA/files/zr.md"
printf '# Old\nRetired.\n'                   > "$RA/files/old.md"
printf '# Locked\nQuiet file.\n'             > "$RA/files/locked.md"
printf '# Eps\nNew at A2.\n'                 > "$RA/files/eps.md"
cat > "$RA/install-manifest.json" <<'EOF'
{
  "kit": "memory-kit-claude",
  "manifest_schema": 1,
  "files": [
    { "source": "files/a.md",    "install_to": "skills/a/SKILL.md", "type": "copied", "personalize": true,  "owner": "kit" },
    { "source": "files/b.md",    "install_to": "skills/b/SKILL.md", "type": "copied", "personalize": false, "owner": "kit" },
    { "source": "files/user.md", "install_to": "notes/user.md",     "type": "copied", "personalize": false, "owner": "user" },
    { "source": "files/exec.sh", "install_to": "kit-scripts/exec.sh", "type": "copied", "personalize": false, "owner": "kit",
      "mode": "755", "consent": "per-change" },
    { "source": "files/zr.md",   "install_to": "notes/zr-old.md",   "type": "copied", "personalize": false, "owner": "kit" },
    { "source": "files/old.md",  "install_to": "skills/old/SKILL.md", "type": "copied", "personalize": false, "owner": "kit",
      "retired": { "date": "2026-06-29", "replaced_by": "nothing" } },
    { "source": null, "install_to": "CLAUDE.md", "type": "generated", "owner": "user",
      "checks": ["section: Alpha Rules"] }
  ]
}
EOF
printf -- '- 2026-07-01 -- apply kit initial\n' > "$RA/CHANGELOG.md"
git -C "$RA" add -A && gitc "$RA" -m "A1: apply-fixture baseline"
A1=$(git -C "$RA" rev-parse HEAD)

printf '# A\nHello [USER_NAME], apply v2.\n' > "$RA/files/a.md"
printf '# User\nUser-owned notes v2.\n'      > "$RA/files/user.md"
printf '#!/bin/sh\necho v2\n'                > "$RA/files/exec.sh"
cat > "$RA/install-manifest.json" <<'EOF'
{
  "kit": "memory-kit-claude",
  "manifest_schema": 1,
  "files": [
    { "source": "files/a.md",    "install_to": "skills/a/SKILL.md", "type": "copied", "personalize": true,  "owner": "kit" },
    { "source": "files/b.md",    "install_to": "skills/b/SKILL.md", "type": "copied", "personalize": false, "owner": "kit" },
    { "source": "files/user.md", "install_to": "notes/user.md",     "type": "copied", "personalize": false, "owner": "user" },
    { "source": "files/exec.sh", "install_to": "kit-scripts/exec.sh", "type": "copied", "personalize": false, "owner": "kit",
      "mode": "755", "consent": "per-change" },
    { "source": "files/zr.md",   "install_to": "notes/zr.md",       "type": "copied", "personalize": false, "owner": "kit",
      "renamed_from": "notes/zr-old.md" },
    { "source": "files/old.md",  "install_to": "skills/old/SKILL.md", "type": "copied", "personalize": false, "owner": "kit",
      "retired": { "date": "2026-06-29", "replaced_by": "nothing" } },
    { "source": "files/eps.md",  "install_to": "skills/eps/SKILL.md", "type": "copied", "personalize": false, "owner": "kit" },
    { "source": "files/locked.md", "install_to": "notes/locked.md", "type": "copied", "personalize": false, "owner": "kit",
      "mode": "600" },
    { "source": null, "install_to": "CLAUDE.md", "type": "generated", "owner": "user",
      "checks": ["section: Alpha Rules"] }
  ]
}
EOF
printf -- '- 2026-07-09 -- apply kit v2\n' >> "$RA/CHANGELOG.md"
git -C "$RA" add -A && gitc "$RA" -m "A2: a/user/exec v2, zr renamed, eps+locked new"
A2=$(git -C "$RA" rev-parse HEAD)

# home rendered exactly at A1, anchored at A1
apply_home() { # dir [auto=true]
  local H="$1"
  mkdir -p "$H/skills/a" "$H/skills/b" "$H/notes" "$H/kit-scripts"
  git -C "$RA" show "$A1:files/a.md" > "$WORK/tmp.src" && render_py "$WORK/tmp.src" "Evan" > "$H/skills/a/SKILL.md"
  git -C "$RA" show "$A1:files/b.md"    > "$H/skills/b/SKILL.md"
  git -C "$RA" show "$A1:files/user.md" > "$H/notes/user.md"
  git -C "$RA" show "$A1:files/exec.sh" > "$H/kit-scripts/exec.sh"
  chmod 755 "$H/kit-scripts/exec.sh"
  git -C "$RA" show "$A1:files/zr.md"   > "$H/notes/zr-old.md"
  good_claude_md "$H"
  write_config_auto "$H" "$A1" "$RA" "Evan" "${2:-true}"
}

# like apply_home, but user.md and exec.sh already hand-updated to render(A2):
# every remaining difference is auto-appliable, so a clean apply run results
apply_home_clean() {
  apply_home "$1"
  git -C "$RA" show "$A2:files/user.md" > "$1/notes/user.md"
  git -C "$RA" show "$A2:files/exec.sh" > "$1/kit-scripts/exec.sh"
  chmod 755 "$1/kit-scripts/exec.sh"
}

RETIRE_TODAY=$(date -u +%Y-%m-%d)

# =========================== A1. dry-run default still writes nothing (sweep)
H="$WORK/h-apply-dryrun"; mkdir -p "$H"; apply_home "$H"
sweep "$H" > "$WORK/sweep-before.txt"
run_check "$H" "$RA"
sweep "$H" > "$WORK/sweep-after.txt"
if diff -q "$WORK/sweep-before.txt" "$WORK/sweep-after.txt" >/dev/null; then
  ok "apply-guard: default dry run changes no byte of the home"
else
  bad "apply-guard: default dry run changes no byte of the home" "checksum sweep differs"
fi
if [ -d "$H/kit-backups" ]; then
  bad "apply-guard: dry run creates no kit-backups dir" "kit-backups exists"
else
  ok "apply-guard: dry run creates no kit-backups dir"
fi

# ================================================== A2. the mixed apply run
H="$WORK/h-apply-mixed"; mkdir -p "$H"; apply_home "$H"
run_check "$H" "$RA" --apply
assert_eq "apply-mixed: exit 1 (per-change + user-owned remained unapplied)" "1" "$RC"

git -C "$RA" show "$A2:files/a.md" > "$WORK/tmp.src" && render_py "$WORK/tmp.src" "Evan" > "$WORK/want-a.md"
if cmp -s "$H/skills/a/SKILL.md" "$WORK/want-a.md"; then
  ok "apply-mixed: kit-ahead a applied, content == render(HEAD)"
else
  bad "apply-mixed: kit-ahead a applied, content == render(HEAD)" "content differs"
fi
assert_eq "apply-mixed: applied action recorded for a" "updated" "$(applied_of "$REPORT" skills/a/SKILL.md)"

git -C "$RA" show "$A2:files/eps.md" > "$WORK/want-eps.md"
if cmp -s "$H/skills/eps/SKILL.md" "$WORK/want-eps.md"; then
  ok "apply-mixed: new eps installed with correct content"
else
  bad "apply-mixed: new eps installed with correct content" "missing or differs"
fi
assert_eq "apply-mixed: applied action recorded for eps" "installed" "$(applied_of "$REPORT" skills/eps/SKILL.md)"

assert_eq "apply-mixed: mode bit applied to locked (600)" "600" "$(perm_of "$H/notes/locked.md")"

if [ -f "$H/notes/zr.md" ] && [ ! -e "$H/notes/zr-old.md" ]; then
  ok "apply-mixed: rename applied (zr at new path, old path cleared)"
else
  bad "apply-mixed: rename applied (zr at new path, old path cleared)" "paths wrong"
fi

BK=$(newest_backup "$H")
if [ -n "$BK" ] && [ -f "$H/kit-backups/$BK/RESTORE.md" ]; then
  ok "apply-mixed: backup dir created with RESTORE.md"
else
  bad "apply-mixed: backup dir created with RESTORE.md" "missing"
fi
git -C "$RA" show "$A1:files/a.md" > "$WORK/tmp.src" && render_py "$WORK/tmp.src" "Evan" > "$WORK/orig-a.md"
if cmp -s "$H/kit-backups/$BK/skills/a/SKILL.md" "$WORK/orig-a.md"; then
  ok "apply-mixed: backup of a holds the pre-write bytes"
else
  bad "apply-mixed: backup of a holds the pre-write bytes" "backup wrong or missing"
fi
git -C "$RA" show "$A1:files/zr.md" > "$WORK/orig-zr.md"
if cmp -s "$H/kit-backups/$BK/notes/zr-old.md" "$WORK/orig-zr.md"; then
  ok "apply-mixed: renamed file's old-path bytes preserved in backup"
else
  bad "apply-mixed: renamed file's old-path bytes preserved in backup" "backup wrong or missing"
fi

git -C "$RA" show "$A1:files/user.md" > "$WORK/orig-user.md"
if cmp -s "$H/notes/user.md" "$WORK/orig-user.md"; then
  ok "apply-mixed: user-owned entry untouched"
else
  bad "apply-mixed: user-owned entry untouched" "user.md was modified"
fi
assert_eq "apply-mixed: user-owned recorded as skipped" "skipped-user-owned" "$(applied_of "$REPORT" notes/user.md)"

git -C "$RA" show "$A1:files/exec.sh" > "$WORK/orig-exec.sh"
if cmp -s "$H/kit-scripts/exec.sh" "$WORK/orig-exec.sh"; then
  ok "apply-mixed: per-change consent entry untouched"
else
  bad "apply-mixed: per-change consent entry untouched" "exec.sh was modified"
fi
assert_eq "apply-mixed: per-change recorded as needs-approval" "needs-approval" "$(applied_of "$REPORT" kit-scripts/exec.sh)"
assert_grep "apply-mixed: report says individual approval needed" "individual approval" "$REPORT"

assert_eq "apply-mixed: anchor held on a mixed run" "$A1" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"
assert_grep "apply-mixed: report explains the held anchor" "NOT advanced" "$REPORT"
assert_grep "apply-mixed: report has an Applied section" "## Applied" "$REPORT"
assert_grep "apply-mixed: summary re-states the opt-in and undo" "undo the last kit update" "$REPORT"

# =============================================== A3. reinstalls a missing file
H="$WORK/h-apply-missing"; mkdir -p "$H"; apply_home_clean "$H"
rm "$H/skills/b/SKILL.md"
run_check "$H" "$RA" --apply
git -C "$RA" show "$A2:files/b.md" > "$WORK/want-b.md"
if cmp -s "$H/skills/b/SKILL.md" "$WORK/want-b.md"; then
  ok "apply-missing: b reinstalled with correct content"
else
  bad "apply-missing: b reinstalled with correct content" "missing or differs"
fi
assert_eq "apply-missing: recorded as installed (no prior file)" "installed" "$(applied_of "$REPORT" skills/b/SKILL.md)"

# =========================== A3b. new installs are recorded and can be undone
H="$WORK/h-apply-new-only"; mkdir -p "$H"; apply_home_clean "$H"
git -C "$RA" show "$A2:files/a.md" > "$WORK/tmp.src" && render_py "$WORK/tmp.src" "Evan" > "$H/skills/a/SKILL.md"
mv "$H/notes/zr-old.md" "$H/notes/zr.md"
git -C "$RA" show "$A2:files/locked.md" > "$H/notes/locked.md"
chmod 600 "$H/notes/locked.md"
rm "$H/skills/b/SKILL.md"
TESTN=$((TESTN+1)); REPORT="$WORK/report-$TESTN.md"; OUT="$WORK/out-$TESTN.txt"; ERR="$WORK/err-$TESTN.txt"
bash "$SCRIPT" --home "$H" --upstream "$RA" --report "$REPORT" --apply > "$OUT" 2> "$ERR"
RC=$?
assert_eq "new-only: apply exits 0" "0" "$RC"
assert_eq "new-only: apply stderr is empty" "0" "$(wc -c < "$ERR" | tr -d '[:space:]')"
BK=$(newest_backup "$H")
if [ -n "$BK" ] && [ -f "$H/kit-backups/$BK/.kit-backup-manifest.tsv" ]; then
  ok "new-only: backup directory and manifest created"
else
  bad "new-only: backup directory and manifest created" "backup manifest missing"
fi
if grep -q $'^installed\tskills/b/SKILL.md$' "$H/kit-backups/$BK/.kit-backup-manifest.tsv" 2>/dev/null &&
   grep -q $'^installed\tskills/eps/SKILL.md$' "$H/kit-backups/$BK/.kit-backup-manifest.tsv" 2>/dev/null; then
  ok "new-only: manifest records every install"
else
  bad "new-only: manifest records every install" "one or more install records missing"
fi
run_check "$H" "$RA" --undo
assert_eq "new-only: undo exits 0" "0" "$RC"
if [ ! -e "$H/skills/b/SKILL.md" ] && [ ! -e "$H/skills/eps/SKILL.md" ]; then
  ok "new-only: undo removes installed files from the live home"
else
  bad "new-only: undo removes installed files from the live home" "one or more installed files remain live"
fi
UNDO_BK=$(newest_backup "$H")
if cmp -s "$H/kit-backups/$UNDO_BK/skills/b/SKILL.md" "$RA/files/b.md" &&
   cmp -s "$H/kit-backups/$UNDO_BK/skills/eps/SKILL.md" "$RA/files/eps.md"; then
  ok "new-only: undo moves installed files into its own backup"
else
  bad "new-only: undo moves installed files into its own backup" "moved copies missing or changed"
fi

# =================================== A4. live-ahead / diverged never written
H="$WORK/h-apply-protected"; mkdir -p "$H"; apply_home "$H"
printf '\nlocal-only improvement\n' >> "$H/skills/b/SKILL.md"
printf '# A\nlocally rewritten a\n' > "$H/skills/a/SKILL.md"
sha_b_before=$(shasum -a 256 "$H/skills/b/SKILL.md" | awk '{print $1}')
sha_a_before=$(shasum -a 256 "$H/skills/a/SKILL.md" | awk '{print $1}')
run_check "$H" "$RA" --apply
assert_eq "apply-protected: exit 2 (escalations)" "2" "$RC"
assert_eq "apply-protected: b classified live-ahead" "live-ahead" "$(state_of "$REPORT" skills/b/SKILL.md)"
assert_eq "apply-protected: a classified diverged"   "diverged"   "$(state_of "$REPORT" skills/a/SKILL.md)"
assert_eq "apply-protected: live-ahead b byte-untouched" "$sha_b_before" "$(shasum -a 256 "$H/skills/b/SKILL.md" | awk '{print $1}')"
assert_eq "apply-protected: diverged a byte-untouched"   "$sha_a_before" "$(shasum -a 256 "$H/skills/a/SKILL.md" | awk '{print $1}')"
assert_eq "apply-protected: anchor held" "$A1" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"

# =============================== A5. retired entry moved to kit-retired/<date>
H="$WORK/h-apply-retired"; mkdir -p "$H"; apply_home "$H"
mkdir -p "$H/skills/old"
printf '# Old\nRetired.\n' > "$H/skills/old/SKILL.md"
run_check "$H" "$RA" --apply
assert_eq "apply-retired: exit 2 (retirement is surfaced loudly)" "2" "$RC"
if [ ! -e "$H/skills/old/SKILL.md" ]; then
  ok "apply-retired: live file gone from its old home"
else
  bad "apply-retired: live file gone from its old home" "still present"
fi
if printf '# Old\nRetired.\n' | cmp -s - "$H/kit-retired/$RETIRE_TODAY/skills/old/SKILL.md"; then
  ok "apply-retired: moved (not deleted) into kit-retired/<date>/ intact"
else
  bad "apply-retired: moved (not deleted) into kit-retired/<date>/ intact" "not found or differs"
fi
assert_eq "apply-retired: recorded as retired" "retired" "$(applied_of "$REPORT" skills/old/SKILL.md)"

# ====================== A6. removed-upstream (old fixture repo) also moves
H="$WORK/h-apply-removed"; mkdir -p "$H"; home_baseline "$H"
run_check "$H" "$REPO" --apply
assert_eq "apply-removed: exit 2 (removed-upstream stays an escalation)" "2" "$RC"
if [ ! -e "$H/skills/delta/SKILL.md" ] && [ -f "$H/kit-retired/$RETIRE_TODAY/skills/delta/SKILL.md" ]; then
  ok "apply-removed: removed-upstream delta moved to kit-retired"
else
  bad "apply-removed: removed-upstream delta moved to kit-retired" "not moved"
fi
assert_eq "apply-removed: anchor advances once everything is resolved" "$C2" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"

# ======================================= A7. auto_update false applies nothing
H="$WORK/h-apply-optout"; mkdir -p "$H"; apply_home "$H" "false"
sweep "$H" > "$WORK/sweep-optout-before.txt"
run_check "$H" "$RA" --apply
sweep "$H" > "$WORK/sweep-optout-after.txt"
assert_eq "apply-optout: exit 1 (updates remained unapplied)" "1" "$RC"
if diff -q "$WORK/sweep-optout-before.txt" "$WORK/sweep-optout-after.txt" >/dev/null; then
  ok "apply-optout: not a single byte of the home changed"
else
  bad "apply-optout: not a single byte of the home changed" "checksum sweep differs"
fi
if [ -d "$H/kit-backups" ]; then
  bad "apply-optout: no backup dir created" "kit-backups exists"
else
  ok "apply-optout: no backup dir created"
fi
assert_grep "apply-optout: Replace vocabulary offered" "Replace" "$REPORT"
assert_grep "apply-optout: Keep vocabulary offered"    "Keep"    "$REPORT"
assert_eq "apply-optout: a recorded as would-apply" "would-apply" "$(applied_of "$REPORT" skills/a/SKILL.md)"
assert_eq "apply-optout: anchor untouched" "$A1" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"

# ============================= A8. clean run advances the anchor (written last)
H="$WORK/h-apply-clean"; mkdir -p "$H"; apply_home_clean "$H"
run_check "$H" "$RA" --apply
assert_eq "apply-clean: exit 0 (nothing left to do)" "0" "$RC"
assert_eq "apply-clean: anchor advanced to HEAD" "$A2" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"
assert_grep "apply-clean: report says the anchor advanced" "installed_commit advanced" "$REPORT"
BK=$(newest_backup "$H")
if grep -q "updated	kit-config/memory-kit-claude.json" "$H/kit-backups/$BK/.kit-backup-manifest.tsv" 2>/dev/null; then
  ok "apply-clean: previous config backed up before the anchor write"
else
  bad "apply-clean: previous config backed up before the anchor write" "no config backup recorded"
fi

# =========== A9. anchor written LAST: kill between file writes and anchor
H="$WORK/h-apply-torn"; mkdir -p "$H"; apply_home_clean "$H"
TESTN=$((TESTN+1)); REPORT="$WORK/report-$TESTN.md"; OUT="$WORK/out-$TESTN.txt"
KUC_TEST_KILL_BEFORE_ANCHOR=1 bash "$SCRIPT" --home "$H" --upstream "$RA" --report "$REPORT" --apply > "$OUT" 2>&1
RC=$?
assert_eq "apply-torn: run killed before the anchor write (SIGKILL)" "137" "$RC"
if cmp -s "$H/skills/a/SKILL.md" "$WORK/want-a.md"; then
  ok "apply-torn: file writes had already landed"
else
  bad "apply-torn: file writes had already landed" "a not updated"
fi
assert_eq "apply-torn: config unchanged -- anchor still at A1" "$A1" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"
rm -rf "$H/.kit-update.lock"   # SIGKILL skips the trap; clear the dead run's lock
run_check "$H" "$RA" --apply
assert_eq "apply-torn: healing run exits 0" "0" "$RC"
assert_eq "apply-torn: healing run sees a as already-current" "already-current" "$(state_of "$REPORT" skills/a/SKILL.md)"
assert_eq "apply-torn: healing run advances the anchor" "$A2" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"

# ============================================= A10. undo round-trip, twice over
H="$WORK/h-apply-undo"; mkdir -p "$H"; apply_home_clean "$H"
sweep "$H" > "$WORK/sweep-orig.txt"
run_check "$H" "$RA" --apply
assert_eq "undo-roundtrip: apply run exits 0" "0" "$RC"
sweep "$H" > "$WORK/sweep-applied.txt"
D1=$(newest_backup "$H")
(cd "$H/kit-backups/$D1" && find . -type f -exec shasum -a 256 {} + | LC_ALL=C sort) > "$WORK/d1-before.txt"

run_check "$H" "$RA" --undo
assert_eq "undo-roundtrip: undo exits 0" "0" "$RC"
sweep "$H" > "$WORK/sweep-undone.txt"
if diff -q "$WORK/sweep-orig.txt" "$WORK/sweep-undone.txt" >/dev/null; then
  ok "undo-roundtrip: home byte-identical to the pre-apply original"
else
  bad "undo-roundtrip: home byte-identical to the pre-apply original" "$(diff "$WORK/sweep-orig.txt" "$WORK/sweep-undone.txt" | head -4 | tr '\n' ' ')"
fi
assert_eq "undo-roundtrip: anchor rolled back with the config" "$A1" "$(cfg_commit "$H/kit-config/memory-kit-claude.json")"

D2=$(newest_backup "$H")
if [ "$D1" != "$D2" ]; then
  ok "undo-roundtrip: undo backed up into a NEW dir, not the old one"
else
  bad "undo-roundtrip: undo backed up into a NEW dir, not the old one" "same dir reused"
fi
(cd "$H/kit-backups/$D1" && find . -type f -exec shasum -a 256 {} + | LC_ALL=C sort) > "$WORK/d1-after.txt"
if diff -q "$WORK/d1-before.txt" "$WORK/d1-after.txt" >/dev/null; then
  ok "undo-roundtrip: no existing backup file was ever overwritten"
else
  bad "undo-roundtrip: no existing backup file was ever overwritten" "first backup dir changed"
fi

run_check "$H" "$RA" --undo
assert_eq "undo-roundtrip: undo-of-undo exits 0" "0" "$RC"
sweep "$H" > "$WORK/sweep-redone.txt"
if diff -q "$WORK/sweep-applied.txt" "$WORK/sweep-redone.txt" >/dev/null; then
  ok "undo-roundtrip: undo of the undo restores the applied state"
else
  bad "undo-roundtrip: undo of the undo restores the applied state" "state differs"
fi

# =============================================== A11. undo with no backups
H="$WORK/h-undo-nothing"; mkdir -p "$H"; apply_home "$H"
run_check "$H" "$RA" --undo
assert_eq "undo-empty: refuses politely (exit 3)" "3" "$RC"
assert_grep "undo-empty: says there is nothing to undo" "nothing to undo" "$OUT"
if [ -d "$H/kit-backups" ]; then
  bad "undo-empty: writes nothing" "kit-backups created"
else
  ok "undo-empty: writes nothing"
fi

# ======================================= A12. --apply --undo are exclusive
run_check "$WORK/h-undo-nothing" "$RA" --apply --undo
assert_eq "apply-undo-exclusive: exit 3" "3" "$RC"
assert_grep "apply-undo-exclusive: message names both flags" "mutually exclusive" "$OUT"

# ###########################################################################
# CLIENT-FACING REPORT PROSE
# ###########################################################################

# ================= P1. undo promise only when something was actually backed up
H="$WORK/h-promise-none"; mkdir -p "$H"; home_synced "$H"
run_check "$H" "$REPO" --apply
assert_eq "undo-promise: fully synced apply run exits 0" "0" "$RC"
if grep -q "undo the last kit update" "$REPORT"; then
  bad "undo-promise: absent when the run backed up nothing" "promise found in report"
else
  ok "undo-promise: absent when the run backed up nothing"
fi
if [ -d "$H/kit-backups" ]; then
  bad "undo-promise: synced apply run creates no backup dir" "kit-backups exists"
else
  ok "undo-promise: synced apply run creates no backup dir"
fi

H="$WORK/h-promise-yes"; mkdir -p "$H"; apply_home_clean "$H"
run_check "$H" "$RA" --apply
assert_eq "undo-promise: writing apply run exits 0" "0" "$RC"
assert_grep "undo-promise: present when the run backed files up" "undo the last kit update" "$REPORT"

# ===================== P2. "Needs your attention" section rides escalations
H="$WORK/h-attention"; mkdir -p "$H"; apply_home "$H"
printf '# A\nlocally rewritten a\n' > "$H/skills/a/SKILL.md"
run_check "$H" "$RA" --apply
assert_eq "needs-attention: diverged apply run exits 2" "2" "$RC"
assert_grep "needs-attention: section present on a diverged run" "## Needs your attention" "$REPORT"
assert_grep "needs-attention: diverged explained in plain language" "the kit also improved it" "$REPORT"
assert_eq "needs-attention: diverged a still classified diverged" "diverged" "$(state_of "$REPORT" skills/a/SKILL.md)"

H="$WORK/h-noattention"; mkdir -p "$H"; home_synced "$H"
run_check "$H" "$REPO" --apply
assert_eq "needs-attention: clean apply run exits 0" "0" "$RC"
if grep -q "Needs your attention" "$REPORT"; then
  bad "needs-attention: absent on a clean run" "section found in clean report"
else
  ok "needs-attention: absent on a clean run"
fi

# ================================================================== summary
echo
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
