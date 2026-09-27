#!/usr/bin/env bash
# End-to-end tests for install.sh and msl, run in a throwaway $HOME.
# TEST_BASH picks the interpreter under test (CI uses /bin/bash 3.2 on macOS).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
SH="${TEST_BASH:-bash}"
pass=0
fail=0

ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/       /'; }
check() { # description, command...
  local d="$1" out
  shift
  if out="$("$@" 2>&1)"; then ok "$d"; else bad "$d" "$out"; fi
}
contains() { printf '%s' "$1" | grep -qF -- "$2"; }

new_home() {
  HOME="$(mktemp -d)"
  export HOME
  unset MSL_HOME
  MSL="$SH $HOME/.meta-skill-loop/bin/msl"
  cd "$HOME"
}

skill() { # dir name [body]
  mkdir -p "$1"
  printf -- '---\nname: %s\ndescription: test skill %s\n---\n\n# %s\n%s\n' "$2" "$2" "$2" "${3:-Do the thing.}" > "$1/SKILL.md"
}

echo "install"
new_home
skill "$HOME/.cursor/skills/grill-me" grill-me "Ask hard questions."
mkdir -p "$HOME/.claude"
out="$($SH "$REPO/install.sh" --claude)"
check "copies core skills to ~/.agents/skills" test -f "$HOME/.agents/skills/meta-skill-feedback/SKILL.md"
check "copies core skills to ~/.claude/skills" test -f "$HOME/.claude/skills/meta-skill-refine/SKILL.md"
check "installs msl into the workspace" test -x "$HOME/.meta-skill-loop/bin/msl"
check "workspace is a git repo" test -d "$HOME/.meta-skill-loop/.git"
check "core skills are managed as upstream" grep -q '^ownership: upstream' "$HOME/.meta-skill-loop/skills/meta-skill-loop/skill.yaml"
check "core skills get no nudge" sh -c "! grep -q 'meta-skill-feedback\` skill' '$HOME/.agents/skills/meta-skill-loop/SKILL.md'"
check "reinstall is idempotent" "$SH" "$REPO/install.sh" --claude
n="$(grep -c '^## ch-' "$HOME/.meta-skill-loop/skills/meta-skill-loop/changes.md")"
check "reinstall without changes records nothing" test "$n" = 1

echo "scan and add"
out="$($MSL scan)"
if contains "$out" "new      grill-me"; then ok "scan lists unmanaged skill"; else bad "scan lists unmanaged skill" "$out"; fi
out="$($MSL add grill-me)"
if contains "$out" "added grill-me (own)"; then ok "add defaults to own"; else bad "add defaults to own" "$out"; fi
check "nudge inserted after frontmatter" sh -c "sed -n 6p '$HOME/.cursor/skills/grill-me/SKILL.md' | grep -q 'meta-skill-feedback'"
check "base snapshot is the pristine skill" sh -c "! grep -q meta-skill-feedback '$HOME/.meta-skill-loop/skills/grill-me/base/SKILL.md'"
check "current snapshot includes nudge" grep -q meta-skill-feedback "$HOME/.meta-skill-loop/skills/grill-me/current/SKILL.md"
check "adding twice fails" sh -c "! $MSL add grill-me"
check "add unknown skill fails" sh -c "! $MSL add nope"
check "status of unmanaged skill fails" sh -c "! $MSL status nope"

echo "log"
printf -- '- asked: grill me\n- observed: 14 questions\n' | $MSL log grill-me --tool cursor --severity annoying >/dev/null
f="$HOME/.meta-skill-loop/skills/grill-me/feedback/fb-0001.md"
check "entry written" test -f "$f"
check "entry has open status" grep -q '^status: open' "$f"
check "entry has explicit origin" grep -q '^origin: explicit' "$f"
check "entry records tool" grep -q '^tool: cursor' "$f"
check "entry records skill hash" grep -q '^skill_hash: [0-9a-f]\{12\}' "$f"
printf -- '- observed: rambled\n' | $MSL log grill-me --origin observed >/dev/null
f2="$HOME/.meta-skill-loop/skills/grill-me/feedback/fb-0002.md"
check "observed entry is a candidate" grep -q '^status: candidate' "$f2"
check "observed entry defaults to medium confidence" grep -q '^confidence: medium' "$f2"
check "empty body rejected" sh -c "! printf '' | $MSL log grill-me"
check "bad severity rejected" sh -c "! echo x | $MSL log grill-me --severity huge"
check "log on unmanaged skill rejected" sh -c "! echo x | $MSL log nope"
out="$($MSL status)"
if printf '%s\n' "$out" | grep -Eq '^grill-me +own +1 +1 +clean'; then ok "status counts open and triage"; else bad "status counts open and triage" "$out"; fi

echo "refine bookkeeping"
echo "Ask at most 5 questions per round." >> "$HOME/.cursor/skills/grill-me/SKILL.md"
out="$($MSL status grill-me)"
if contains "$out" changed; then ok "hand edit shows as changed"; else bad "hand edit shows as changed" "$out"; fi
$MSL commit grill-me -m "cap questions" --fixes fb-0001 >/dev/null
check "commit marks feedback applied" grep -q '^status: applied' "$f"
check "commit links change id" grep -q '^resolution: ch-0002' "$f"
check "commit logs change" grep -q 'fixes: fb-0001' "$HOME/.meta-skill-loop/skills/grill-me/changes.md"
out="$($MSL status grill-me)"
if contains "$out" clean; then ok "state clean after commit"; else bad "state clean after commit" "$out"; fi
$MSL mark fb-0002 declined -m "one-off" >/dev/null
check "mark sets status" grep -q '^status: declined' "$f2"
check "mark records reason" grep -q '^resolution: one-off' "$f2"
check "commit with unknown feedback id fails" sh -c "! $MSL commit grill-me -m x --fixes fb-9999"
cp "$HOME/.meta-skill-loop/skills/grill-me/base/SKILL.md" "$HOME/.cursor/skills/grill-me/SKILL.md"
out="$($MSL status grill-me)"
if contains "$out" reverted; then ok "overwrite by upstream shows as reverted"; else bad "overwrite by upstream shows as reverted" "$out"; fi
out="$($MSL diff grill-me)"
if contains "$out" "-Ask at most 5 questions per round."; then ok "diff shows what an update removed"; else bad "diff shows what an update removed" "$out"; fi
out="$($MSL diff grill-me --refinements)"
if contains "$out" "+Ask at most 5 questions per round." && contains "$out" "+> If the user gives feedback"; then ok "diff --refinements shows local changes vs upstream"; else bad "diff --refinements shows local changes vs upstream" "$out"; fi
cp "$HOME/.meta-skill-loop/skills/grill-me/current/SKILL.md" "$HOME/.cursor/skills/grill-me/SKILL.md"
out="$($MSL diff grill-me)"
if contains "$out" "(no differences)"; then ok "diff reports no differences when restored"; else bad "diff reports no differences when restored" "$out"; fi
cp "$HOME/.meta-skill-loop/skills/grill-me/base/SKILL.md" "$HOME/.cursor/skills/grill-me/SKILL.md"
$MSL nudge grill-me >/dev/null
check "nudge re-inserts the line" grep -q 'meta-skill-feedback' "$HOME/.cursor/skills/grill-me/SKILL.md"
$MSL nudge grill-me >/dev/null
check "nudge is idempotent" test "$(grep -c 'meta-skill-feedback' "$HOME/.cursor/skills/grill-me/SKILL.md")" = 1
out="$($MSL show grill-me --all)"
if contains "$out" "cap questions" && contains "$out" "one-off"; then ok "show includes history and feedback"; else bad "show includes history and feedback" "$out"; fi

echo "copies"
skill "$HOME/.agents/skills/multi" multi
skill "$HOME/.claude/skills/multi" multi
out="$($MSL add multi)"
if contains "$out" ".claude/skills/multi"; then ok "add records every installed copy"; else bad "add records every installed copy" "$out"; fi
echo "extra" >> "$HOME/.agents/skills/multi/SKILL.md"
$MSL commit multi -m "extra" >/dev/null
check "commit propagates to other copies" grep -q extra "$HOME/.claude/skills/multi/SKILL.md"
echo "drift" >> "$HOME/.claude/skills/multi/SKILL.md"
out="$($MSL status multi)"
if contains "$out" copies-differ; then ok "diverged copy detected"; else bad "diverged copy detected" "$out"; fi

echo "project skills and ownership"
mkdir -p "$HOME/work/app" && (cd "$HOME/work/app" && git init -q)
skill "$HOME/work/app/.cursor/skills/deploy" deploy
out="$(cd "$HOME/work/app" && $MSL add deploy)"
if contains "$out" "work/app/.cursor/skills/deploy"; then ok "finds project skills from inside the repo"; else bad "finds project skills from inside the repo" "$out"; fi
$MSL set deploy ownership upstream >/dev/null
check "set ownership" grep -q '^ownership: upstream' "$HOME/.meta-skill-loop/skills/deploy/skill.yaml"
check "set rejects bad ownership" sh -c "! $MSL set deploy ownership mine"

echo "skills CLI lock file"
if command -v node >/dev/null 2>&1; then
  skill "$HOME/.agents/skills/pr-review" pr-review
  printf '{"version":3,"skills":{"pr-review":{"source":"acme/team-skills","sourceUrl":"https://github.com/acme/team-skills.git","skillPath":"skills/pr-review/SKILL.md"}}}' > "$HOME/.agents/.skill-lock.json"
  out="$($MSL add pr-review)"
  if contains "$out" "upstream, from https://github.com/acme/team-skills.git (skills/pr-review)"; then ok "source and ownership from lock file"; else bad "source and ownership from lock file" "$out"; fi
else
  echo "  skip (node not installed)"
fi

echo "remove"
skill "$HOME/.agents/skills/tmp-skill" tmp-skill
orig="$(cat "$HOME/.agents/skills/tmp-skill/SKILL.md")"
$MSL add tmp-skill >/dev/null
$MSL remove tmp-skill >/dev/null
check "remove restores the skill file exactly" test "$(cat "$HOME/.agents/skills/tmp-skill/SKILL.md")" = "$orig"
check "remove leaves the skill in place" test -f "$HOME/.agents/skills/tmp-skill/SKILL.md"
check "remove archives the data" sh -c "ls '$HOME/.meta-skill-loop/archive' | grep -q tmp-skill"
printf -- '- x\n' | $MSL log grill-me >/dev/null
check "ids stay unique" test -f "$HOME/.meta-skill-loop/skills/grill-me/feedback/fb-0003.md"

echo "install keeps refinements"
echo "my tweak" >> "$HOME/.agents/skills/meta-skill-refine/SKILL.md"
$MSL commit meta-skill-refine -m tweak >/dev/null
out="$($SH "$REPO/install.sh")"
if contains "$out" "skip meta-skill-refine"; then ok "refined core skill is not overwritten"; else bad "refined core skill is not overwritten" "$out"; fi
check "refinement still present" grep -q "my tweak" "$HOME/.agents/skills/meta-skill-refine/SKILL.md"

check "workspace history recorded" test "$(git -C "$HOME/.meta-skill-loop" rev-list --count HEAD)" -gt 10

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
