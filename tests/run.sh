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
has() { # description, haystack, needle
  if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1" "$2"; fi
}
lacks() {
  if printf '%s' "$2" | grep -qF -- "$3"; then bad "$1" "$2"; else ok "$1"; fi
}

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

state_of() { $MSL status "$1" | awk -v n="$1" '$1 == n { print $6 }'; }
version_of() { $MSL status "$1" | awk -v n="$1" '$1 == n { print $3 }'; }
fb() { printf 'fb-%s-%s' "$(awk '/^id: /{ print $2 }' "$HOME/.meta-skill-loop/workspace.yaml")" "$1"; }

lock() { # name rev
  mkdir -p "$HOME/.agents"
  printf '{"version":3,"skills":{"%s":{"source":"acme/skills","sourceUrl":"https://github.com/acme/skills.git","skillPath":"skills/%s/SKILL.md","skillFolderHash":"%s"}}}' \
    "$1" "$1" "$2" > "$HOME/.agents/.skill-lock.json"
}

echo "install"
new_home
skill "$HOME/.cursor/skills/grill-me" grill-me "Ask hard questions."
mkdir -p "$HOME/.claude"
"$SH" "$REPO/install.sh" --claude >/dev/null
check "copies core skills to ~/.agents/skills" test -f "$HOME/.agents/skills/meta-skill-feedback/SKILL.md"
check "copies core skills to ~/.claude/skills" test -f "$HOME/.claude/skills/meta-skill-refine/SKILL.md"
check "installs msl into the workspace" test -x "$HOME/.meta-skill-loop/bin/msl"
check "workspace has an id" grep -Eq '^id: [a-z0-9]{4}$' "$HOME/.meta-skill-loop/workspace.yaml"
check "core skills are managed as framework" grep -q '^kind: framework' "$HOME/.meta-skill-loop/skills/meta-skill-loop/skill.yaml"
has "core skills start at v1" "$(version_of meta-skill-loop)" "v1"
"$SH" "$REPO/install.sh" --claude >/dev/null
has "reinstall without changes adds no version" "$(version_of meta-skill-loop)" "v1"
has "print the global feedback rule" "$("$SH" "$REPO/install.sh")" "offer to log it with the meta-skill-feedback skill"

echo "scan and add"
has "scan lists unmanaged skill" "$($MSL scan)" "new      grill-me"
before="$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")"
has "add a plain folder as local" "$($MSL add grill-me)" "added grill-me (local) as v1"
check "add leaves the skill file untouched" test "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" = "$before"
check "no .git inside the skill folder" test ! -e "$HOME/.cursor/skills/grill-me/.git"
check "adding twice fails" sh -c "! $MSL add grill-me"
check "add unknown skill fails" sh -c "! $MSL add nope"
check "status of unmanaged skill fails" sh -c "! $MSL status nope"
has "state clean after add" "$(state_of grill-me)" "clean"

echo "feedback"
printf -- '- asked: grill me\n- observed: 14 questions\n' | $MSL feedback add grill-me --tool cursor --severity annoying >/dev/null
f1="$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 001).md"
check "entry id is workspace id + sequence" test -f "$f1"
check "entry is open" grep -q '^status: open' "$f1"
check "entry records the version" grep -q '^version: v1$' "$f1"
check "entry records tool" grep -q '^tool: cursor' "$f1"
printf -- '- observed: rambled\n' | $MSL feedback add grill-me --origin observed >/dev/null
f2="$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 002).md"
check "observed entry is a candidate" grep -q '^status: candidate' "$f2"
check "empty body rejected" sh -c "! printf '' | $MSL feedback add grill-me"
check "bad severity rejected" sh -c "! echo x | $MSL feedback add grill-me --severity huge"
check "feedback on unmanaged skill rejected" sh -c "! echo x | $MSL feedback add nope"
has "list shows open and candidate" "$($MSL feedback list grill-me)" "status: candidate"
$MSL feedback mark "$(fb 002)" declined -m "one-off" >/dev/null
check "mark sets status and reason" grep -q '^resolution: one-off' "$f2"

echo "edit, keep, undo, redo"
echo "Ask at most 5 questions per round." >> "$HOME/.cursor/skills/grill-me/SKILL.md"
has "edit shows as changed" "$(state_of grill-me)" "changed"
has "version marked as having edits" "$(version_of grill-me)" "v1*"
has "diff shows the edit" "$($MSL diff grill-me)" "+Ask at most 5 questions per round."
printf -- '- x\n' | $MSL feedback add grill-me >/dev/null
check "feedback during edits records +edits" grep -q '^version: v1+edits$' "$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 003).md"
$MSL feedback mark "$(fb 003)" declined >/dev/null
has "keep creates v2" "$($MSL keep grill-me -m "cap questions" --fixes "$(fb 001)")" "v2 kept"
check "keep marks feedback applied" grep -q '^status: applied' "$f1"
check "keep links the version" grep -q '^resolution: v2' "$f1"
has "clean after keep" "$(state_of grill-me)" "clean"
check "keep with nothing to keep fails" sh -c "! $MSL keep grill-me -m x"
echo "bad edit" >> "$HOME/.cursor/skills/grill-me/SKILL.md"
$MSL undo grill-me >/dev/null
lacks "undo discards the edit" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "bad edit"
$MSL redo grill-me >/dev/null
has "redo brings it back" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "bad edit"
$MSL undo grill-me >/dev/null
mkdir -p "$HOME/.cursor/skills/grill-me/references"
echo "extra" > "$HOME/.cursor/skills/grill-me/references/new.md"
$MSL undo grill-me >/dev/null
check "undo removes new files too" test ! -e "$HOME/.cursor/skills/grill-me/references/new.md"
echo "Try this edit." >> "$HOME/.cursor/skills/grill-me/SKILL.md"
$MSL diff grill-me >/dev/null
$MSL git grill-me show mine:SKILL.md > "$HOME/x" && mv "$HOME/x" "$HOME/.cursor/skills/grill-me/SKILL.md"
has "edits wiped by a reinstall are reported" "$($MSL status grill-me)" "your last live edits"
has "diff --saved previews what redo brings back" "$($MSL diff grill-me --saved)" "+Try this edit."
$MSL redo grill-me >/dev/null
has "redo recovers wiped edits" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "Try this edit."
$MSL undo grill-me >/dev/null
lacks "discarded edits are not reported as lost" "$($MSL status grill-me)" "your last live edits"

echo "history and rollback"
out="$($MSL history grill-me)"
has "history lists versions" "$out" "cap questions [fixes $(fb 001)]"
has "history marks live version" "$out" "* v2"
has "history counts feedback per version" "$out" "v1     $(date -u +%Y-%m-%d) 3"
has "diff between versions" "$($MSL diff grill-me v1 v2)" "+Ask at most 5 questions per round."
$MSL rollback grill-me v1 >/dev/null
lacks "rollback restores old content" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "Ask at most 5"
has "rollback is a new version" "$(version_of grill-me)" "v3"
check "rollback reopens feedback the undone versions fixed" grep -q '^status: open' "$f1"
sed 's/^# grill-me$/# Grill me (A)/' "$HOME/.cursor/skills/grill-me/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/.cursor/skills/grill-me/SKILL.md"
$MSL keep grill-me -m "retitle A" >/dev/null
echo "Line B." >> "$HOME/.cursor/skills/grill-me/SKILL.md"; $MSL keep grill-me -m "add B" >/dev/null
$MSL rollback grill-me v4 --only >/dev/null
out="$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")"
if printf '%s' "$out" | grep -q "Line B." && ! printf '%s' "$out" | grep -q "(A)"; then ok "rollback --only undoes just that version"; else bad "rollback --only undoes just that version" "$out"; fi
echo "dirty" >> "$HOME/.cursor/skills/grill-me/SKILL.md"
check "rollback refuses with uncommitted edits" sh -c "! $MSL rollback grill-me v1"
$MSL undo grill-me >/dev/null
printf -- '- z\n' | $MSL feedback add grill-me >/dev/null
sed 's/^Ask hard questions.$/Ask hard, specific questions./' "$HOME/.cursor/skills/grill-me/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/.cursor/skills/grill-me/SKILL.md"
$MSL keep grill-me -m "late fix" >/dev/null
lv="$(version_of grill-me)"
lf="$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 004).md"
$MSL feedback mark "$(fb 004)" applied -m "$lv" >/dev/null
$MSL rollback grill-me "$lv" --only >/dev/null
check "rollback also reopens feedback linked after the keep" grep -q '^status: open' "$lf"

echo "copies"
skill "$HOME/.agents/skills/multi" multi
skill "$HOME/.claude/skills/multi" multi
has "add records every installed copy" "$($MSL add multi)" ".claude/skills/multi"
echo "extra" >> "$HOME/.agents/skills/multi/SKILL.md"
$MSL keep multi -m extra >/dev/null
check "keep propagates to other copies" grep -q extra "$HOME/.claude/skills/multi/SKILL.md"
echo "drift" >> "$HOME/.claude/skills/multi/SKILL.md"
has "diverged copy detected" "$(state_of multi)" "copies-differ"
$MSL keep multi -m sync >/dev/null
lacks "keep re-syncs copies without a new version" "$(cat "$HOME/.claude/skills/multi/SKILL.md")" "drift"
has "no version for a pure copy sync" "$(version_of multi)" "v2"

echo "skills CLI upstream: update, merge, conflicts"
skill "$HOME/.agents/skills/grilling" grilling "Ask the whole frontier in one round.
Keep going until done."
lock grilling aaaaaaaaaaaa
has "add detects the skills CLI" "$($MSL add grilling)" "(skills-cli, from https://github.com/acme/skills.git (skills/grilling))"
sed 's/Ask the whole frontier in one round./Ask at most 3 questions per round./' "$HOME/.agents/skills/grilling/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/.agents/skills/grilling/SKILL.md"
$MSL keep grilling -m "3 questions" >/dev/null
# The skills CLI installs a new upstream version over the live folder.
skill "$HOME/.agents/skills/grilling" grilling "Ask the whole frontier in one round.
Keep going until done.
Summarize at the end."
lock grilling bbbbbbbbbbbb
has "direct installer update detected" "$(state_of grilling)" "upstream-update"
check "keep refuses an upstream version" sh -c "! $MSL keep grilling -m x"
out="$($MSL update grilling --no-fetch)"
has "update records upstream and prepares a merge" "$out" "merged with your version cleanly"
has "live folder is back on your version during review" "$(cat "$HOME/.agents/skills/grilling/SKILL.md")" "Ask at most 3 questions per round."
lacks "live folder does not yet have upstream" "$(cat "$HOME/.agents/skills/grilling/SKILL.md")" "Summarize at the end."
has "diff --merge shows what would change" "$($MSL diff grilling --merge)" "+Summarize at the end."
check "a second update waits for the pending merge" sh -c "! $MSL update grilling --no-fetch"
has "apply makes the next version" "$($MSL update grilling --apply)" "v3: grilling now runs upstream bbbbbbbbbbbb with your refinements"
out="$(cat "$HOME/.agents/skills/grilling/SKILL.md")"
if printf '%s' "$out" | grep -q "Ask at most 3" && printf '%s' "$out" | grep -q "Summarize at the end."; then ok "merged skill has upstream change and your refinement"; else bad "merged skill has upstream change and your refinement" "$out"; fi
has "history shows the upstream merge" "$($MSL history grilling)" "took upstream bbbbbbbbbbbb"
has "up to date afterwards" "$($MSL update grilling --no-fetch)" "up to date"
# Reinstalling the same upstream version wipes your refinements from the folder.
skill "$HOME/.agents/skills/grilling" grilling "Ask the whole frontier in one round.
Keep going until done.
Summarize at the end."
has "known upstream put back is detected" "$(state_of grilling)" "upstream-live"
$MSL update grilling --no-fetch >/dev/null
has "update restores your version" "$(cat "$HOME/.agents/skills/grilling/SKILL.md")" "Ask at most 3 questions per round."
# Conflicting upstream change.
skill "$HOME/.agents/skills/grilling" grilling "Ask exactly one question per round.
Keep going until done.
Summarize at the end."
lock grilling cccccccccccc
has "conflicting update is reported" "$($MSL update grilling --no-fetch)" "with conflicts in"
check "apply refuses unresolved conflicts" sh -c "! $MSL update grilling --apply"
has "abort drops the merge" "$($MSL update grilling --abort)" "dropped the pending merge"
has "unmerged upstream is reported" "$($MSL status grilling)" "not merged into your version yet"
has "take-upstream replaces your version" "$($MSL update grilling --take-upstream)" "as published"
has "live is now plain upstream" "$(cat "$HOME/.agents/skills/grilling/SKILL.md")" "Ask exactly one question per round."

echo "fast-forward when you have no refinements"
skill "$HOME/.agents/skills/plain" plain "v one"
lock plain 111111111111
$MSL add plain >/dev/null
skill "$HOME/.agents/skills/plain" plain "v two"
lock plain 222222222222
has "update without refinements applies directly" "$($MSL update plain --no-fetch)" "you had no refinements to merge"
has "fast-forwarded content is live" "$(cat "$HOME/.agents/skills/plain/SKILL.md")" "v two"
skill "$HOME/.agents/skills/plain" plain "v two and a half"
lock plain 252525252525
has "update --check reports without applying" "$($MSL update plain --no-fetch --check)" "Nothing was changed"
has "check leaves your version live" "$(cat "$HOME/.agents/skills/plain/SKILL.md")" "v two"
lacks "check does not apply upstream" "$(cat "$HOME/.agents/skills/plain/SKILL.md")" "half"
has "diff --incoming shows what upstream changed" "$($MSL diff plain --incoming)" "+v two and a half"
skill "$HOME/.agents/skills/plain" plain "v three"
lock plain 333333333333
has "a second update without refinements also applies directly" "$($MSL update plain --no-fetch)" "you had no refinements to merge"
has "second fast-forward is live" "$(cat "$HOME/.agents/skills/plain/SKILL.md")" "v three"
check "own skills have no upstream" sh -c "! $MSL update grill-me"

echo "skill inside a git repo"
mkdir -p "$HOME/work" && git -C "$HOME/work" init -q
skill "$HOME/work/.cursor/skills/deploy" deploy "Deploy carefully."
git -C "$HOME/work" add -A && git -C "$HOME/work" -c user.name=t -c user.email=t@t commit -qm init
has "add detects a git repo" "$(cd "$HOME/work" && $MSL add deploy)" "added deploy (git"
echo "Run the smoke test first." >> "$HOME/work/.cursor/skills/deploy/SKILL.md"
$MSL keep deploy -m "smoke test" >/dev/null
git -C "$HOME/work" stash -q
sed 's/^# deploy$/# deploy (announce in the channel)/' "$HOME/work/.cursor/skills/deploy/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/work/.cursor/skills/deploy/SKILL.md"
git -C "$HOME/work" -c user.name=t -c user.email=t@t commit -qam "team change"
has "a pulled repo change is detected" "$(state_of deploy)" "upstream-update"
$MSL update deploy >/dev/null
$MSL update deploy --apply >/dev/null
out="$(cat "$HOME/work/.cursor/skills/deploy/SKILL.md")"
if printf '%s' "$out" | grep -q "smoke test" && printf '%s' "$out" | grep -q "announce in the channel"; then ok "repo change merged with your refinement"; else bad "repo change merged with your refinement" "$out"; fi

echo "framework update through install.sh"
fake="$(mktemp -d)"
cp -R "$REPO/." "$fake/"
rm -rf "$fake/.git"
printf '\nNew upstream guidance.\n' >> "$fake/skills/meta-skill-feedback/SKILL.md"
printf '\nNew refine guidance.\n' >> "$fake/skills/meta-skill-refine/SKILL.md"
sed 's/^# meta-skill-refine$/# meta-skill-refine (My local tweak.)/' "$HOME/.agents/skills/meta-skill-refine/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/.agents/skills/meta-skill-refine/SKILL.md"
$MSL keep meta-skill-refine -m tweak >/dev/null
out="$("$SH" "$fake/install.sh" --claude)"
has "unrefined core skill is updated directly" "$(cat "$HOME/.agents/skills/meta-skill-feedback/SKILL.md")" "New upstream guidance."
check "update reaches the other installed copy" grep -q "New upstream guidance." "$HOME/.claude/skills/meta-skill-feedback/SKILL.md"
has "refined core skill asks for review" "$out" "has your refinements; review the upstream"
has "refinement still live" "$(cat "$HOME/.agents/skills/meta-skill-refine/SKILL.md")" "My local tweak."
$MSL update meta-skill-refine >/dev/null
$MSL update meta-skill-refine --apply >/dev/null
out="$(cat "$HOME/.agents/skills/meta-skill-refine/SKILL.md")"
if printf '%s' "$out" | grep -q "My local tweak." && printf '%s' "$out" | grep -q "New refine guidance."; then ok "reviewed framework update keeps your tweak"; else bad "reviewed framework update keeps your tweak" "$out"; fi

echo "remove and legacy workspace"
skill "$HOME/.agents/skills/tmp-skill" tmp-skill
orig="$(cat "$HOME/.agents/skills/tmp-skill/SKILL.md")"
$MSL add tmp-skill >/dev/null
$MSL remove tmp-skill >/dev/null
check "remove leaves the skill untouched" test "$(cat "$HOME/.agents/skills/tmp-skill/SKILL.md")" = "$orig"
check "remove archives the data" sh -c "ls '$HOME/.meta-skill-loop/archive' | grep -q tmp-skill"
check "remove stops managing it" sh -c "! $MSL status tmp-skill"
printf -- '- y\n' | $MSL feedback add grill-me >/dev/null
check "feedback ids keep increasing" test -f "$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 005).md"
legacy="$(mktemp -d)"
mkdir -p "$legacy/.git"
check "an old unreleased workspace is refused with instructions" sh -c "MSL_HOME='$legacy' $MSL status 2>&1 | grep -q 'older, unreleased build'"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
