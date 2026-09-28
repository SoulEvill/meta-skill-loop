#!/usr/bin/env bash
# End-to-end tests for msl, run in a throwaway $HOME.
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
  if grep -qF -- "$3" <<<"$2"; then ok "$1"; else bad "$1" "$2"; fi
}
lacks() {
  if grep -qF -- "$3" <<<"$2"; then bad "$1" "$2"; else ok "$1"; fi
}

new_home() {
  HOME="$(mktemp -d)"
  export HOME
  unset MSL_HOME CLAUDE_CODE_SESSION_ID CLAUDECODE
  export MSL_BASH="$SH"   # the launcher runs msl with the bash under test
  MSL="$SH $HOME/.meta-skill-loop/bin/msl"
  cd "$HOME"
}

skill() { # dir name [body]
  mkdir -p "$1"
  printf -- '---\nname: %s\ndescription: test skill %s\n---\n\n# %s\n%s\n' "$2" "$2" "$2" "${3:-Do the thing.}" > "$1/SKILL.md"
}

state_of() { $MSL status "$1" | awk -v n="$1" '$1 == n { print $5 }'; }
version_of() { $MSL status "$1" | awk -v n="$1" '$1 == n { print $3 }'; }
fb() { printf 'fb-%s-%s' "$(awk '/^id: /{ print $2 }' "$HOME/.meta-skill-loop/workspace.yaml")" "$1"; }

lock() { # name rev
  mkdir -p "$HOME/.agents"
  printf '{"version":3,"skills":{"%s":{"source":"acme/skills","sourceUrl":"https://github.com/acme/skills.git","skillPath":"skills/%s/SKILL.md","skillFolderHash":"%s"}}}' \
    "$1" "$1" "$2" > "$HOME/.agents/.skill-lock.json"
}

echo "install and first use"
new_home
skill "$HOME/.cursor/skills/grill-me" grill-me "Ask hard questions."
# What `npx skills add … -a cursor -a codex -a claude-code --copy` does: plain copies.
for t in "$HOME/.agents/skills" "$HOME/.claude/skills"; do mkdir -p "$t" && cp -R "$REPO"/skills/* "$t/"; done
"$SH" "$HOME/.agents/skills/meta-skill-loop/scripts/msl" init >/dev/null
check "first use installs the msl launcher" test -x "$HOME/.meta-skill-loop/bin/msl"
check "launcher runs the installed skill, not the clone" sh -c "! grep -q '$REPO' '$HOME/.meta-skill-loop/bin/msl'"
check "workspace has a format version" grep -q '^format: 1$' "$HOME/.meta-skill-loop/workspace.yaml"
check "workspace has a 6-character id" grep -Eq '^id: [a-z0-9]{6}$' "$HOME/.meta-skill-loop/workspace.yaml"
check "first use manages nothing by itself" test -z "$(ls "$HOME/.meta-skill-loop/skills")"
has "meta-skill-loop's own skills are not nagged as unmanaged" "$($MSL status)" "1 installed skill folder(s) not managed yet"

echo "add"
has "add with no name lists unmanaged skills" "$($MSL add)" "new      grill-me"
before="$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")"
has "add a plain folder as local" "$($MSL add grill-me)" "added grill-me (local) as v1"
check "add leaves the skill file untouched" test "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" = "$before"
check "no .git inside the skill folder" test ! -e "$HOME/.cursor/skills/grill-me/.git"
check "adding twice fails" sh -c "! $MSL add grill-me"
check "add unknown skill fails" sh -c "! $MSL add nope"
check "status of unmanaged skill fails" sh -c "! $MSL status nope"
has "state clean after add" "$(state_of grill-me)" "clean"

echo "feedback"
printf '## Asked\ngrill me\n\n## Observed\n14 questions\n' | $MSL feedback add grill-me -t "Too many questions" --tool cursor --severity P1 >/dev/null
f1="$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 001).md"
check "entry id is workspace id + sequence" test -f "$f1"
check "entry is open" grep -q '^status: open$' "$f1"
check "entry records the title" grep -q '^title: Too many questions$' "$f1"
check "entry records the version" grep -q '^version: v1$' "$f1"
check "entry records the tool" grep -q '^tool: cursor$' "$f1"
check "entry records the severity" grep -q '^severity: P1$' "$f1"
check "entry keeps the body as written" grep -q '^## Observed$' "$f1"
check "severity defaults to P2" sh -c "echo x | $MSL feedback add grill-me -t second >/dev/null && grep -q '^severity: P2$' '$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 002).md'"
f2="$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 002).md"
check "a title is required" sh -c "! echo x | $MSL feedback add grill-me"
check "empty body rejected" sh -c "! printf '' | $MSL feedback add grill-me -t t"
check "bad severity rejected" sh -c "! echo x | $MSL feedback add grill-me -t t --severity huge"
check "feedback on unmanaged skill rejected" sh -c "! echo x | $MSL feedback add nope -t t"
check "feedback --version rejects an unknown version" sh -c "! echo x | $MSL feedback add grill-me -t t --version v9"
$MSL feedback mark "$(fb 002)" declined >/dev/null
check "mark sets the status" grep -q '^status: declined$' "$f2"
lacks "list shows open entries only" "$($MSL feedback list grill-me)" "title: second"
has "list --all shows every entry" "$($MSL feedback list grill-me --all)" "title: second"
check "mark rejects an unknown status" sh -c "! $MSL feedback mark $(fb 002) candidate"

echo "conversation copies"
proj="$HOME/.claude/projects/$(printf '%s' "$HOME" | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$proj" && echo '{"old":1}' > "$proj/old.jsonl" && sleep 1 && echo '{"turn":"record this"}' > "$proj/cur.jsonl"
out="$(echo x | $MSL feedback add grill-me -t s1 --tool claude-code)"
has "claude code: the current conversation is copied" "$out" "conversation saved: ~/.meta-skill-loop/sessions/cur.jsonl"
check "the copy is kept in the workspace" grep -q 'record this' "$HOME/.meta-skill-loop/sessions/cur.jsonl"
check "the entry points to the copy" grep -q '^session: ~/.meta-skill-loop/sessions/cur.jsonl$' "$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 003).md"
echo '{"turn":"by id"}' > "$proj/abc-123.jsonl"; touch -t 200001010000 "$proj/abc-123.jsonl"
has "claude code: the session id wins over the newest file" "$(echo x | CLAUDE_CODE_SESSION_ID=abc-123 $MSL feedback add grill-me -t s2)" "sessions/abc-123.jsonl"
check "inside claude code the tool is detected" grep -q '^tool: claude-code$' "$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 004).md"
mkdir -p "$HOME/.codex/sessions/2026/09/28" && echo '{}' > "$HOME/.codex/sessions/2026/09/28/rollout-1.jsonl"
has "codex: the newest rollout is copied" "$(echo x | $MSL feedback add grill-me -t s3 --tool codex)" "sessions/rollout-1.jsonl"
has "cursor: says there is no file to copy" "$(echo x | $MSL feedback add grill-me -t s4 --tool cursor)" "no conversation file to copy for cursor"
lacks "--session none skips the copy" "$(echo x | $MSL feedback add grill-me -t s5 --tool claude-code --session none)" "conversation saved"
for n in 003 004 005 006 007; do $MSL feedback mark "$(fb $n)" declined >/dev/null; done

echo "edit, keep, discard, restore"
echo "Ask at most 5 questions per round." >> "$HOME/.cursor/skills/grill-me/SKILL.md"
has "edit shows as changed" "$(state_of grill-me)" "changed"
has "version marked as having edits" "$(version_of grill-me)" "v1*"
has "diff shows the edit" "$($MSL diff grill-me)" "+Ask at most 5 questions per round."
printf -- '- x\n' | $MSL feedback add grill-me -t x >/dev/null
check "feedback during edits records +edits" grep -q '^version: v1+edits$' "$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 008).md"
$MSL feedback mark "$(fb 008)" declined >/dev/null
has "keep creates v2" "$($MSL keep grill-me -m "cap questions" --fixes "$(fb 001)")" "v2 kept"
check "keep marks feedback applied" grep -q '^status: applied$' "$f1"
check "keep records the fixing version" grep -q '^fixed_in: v2$' "$f1"
has "clean after keep" "$(state_of grill-me)" "clean"
check "keep with nothing to keep fails" sh -c "! $MSL keep grill-me -m x"
echo "bad edit" >> "$HOME/.cursor/skills/grill-me/SKILL.md"
$MSL discard grill-me >/dev/null
lacks "discard throws the edit away" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "bad edit"
$MSL restore grill-me >/dev/null
has "restore brings it back" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "bad edit"
$MSL discard grill-me >/dev/null
mkdir -p "$HOME/.cursor/skills/grill-me/references"
echo "extra" > "$HOME/.cursor/skills/grill-me/references/new.md"
$MSL discard grill-me >/dev/null
check "discard removes new files too" test ! -e "$HOME/.cursor/skills/grill-me/references/new.md"
echo "Try this edit." >> "$HOME/.cursor/skills/grill-me/SKILL.md"
$MSL diff grill-me >/dev/null
$MSL git grill-me show mine:SKILL.md > "$HOME/x" && mv "$HOME/x" "$HOME/.cursor/skills/grill-me/SKILL.md"
has "edits wiped by a reinstall are reported" "$($MSL status grill-me)" "your last live edits"
has "diff --saved previews what restore brings back" "$($MSL diff grill-me --saved)" "+Try this edit."
$MSL restore grill-me >/dev/null
has "restore recovers wiped edits" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "Try this edit."
$MSL discard grill-me >/dev/null
lacks "discarded edits are not reported as lost" "$($MSL status grill-me)" "your last live edits"

echo "history and rollback"
out="$($MSL history grill-me)"
has "history lists versions" "$out" "cap questions [fixes $(fb 001)]"
has "history marks live version" "$out" "* v2"
vid="$(printf -- '- about v1\n' | $MSL feedback add grill-me -t old --version v1 | awk 'NR == 1 { print $1 }')"
check "feedback can name the version it's about" grep -q '^version: v1$' "$HOME/.meta-skill-loop/skills/grill-me/feedback/$vid.md"
$MSL feedback mark "$vid" declined >/dev/null
out="$($MSL history grill-me)"
has "history counts feedback per version" "$out" "v1     $(date -u +%Y-%m-%d) 9"
has "diff between versions" "$($MSL diff grill-me v1 v2)" "+Ask at most 5 questions per round."
$MSL rollback grill-me v1 >/dev/null
lacks "rollback restores old content" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "Ask at most 5"
has "rollback is a new version" "$(version_of grill-me)" "v3"
check "rollback reopens feedback the undone versions fixed" grep -q '^status: open$' "$f1"
check "reopened feedback is no longer linked to a version" sh -c "! grep -q '^fixed_in:' '$f1'"
sed 's/^# grill-me$/# Grill me (A)/' "$HOME/.cursor/skills/grill-me/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/.cursor/skills/grill-me/SKILL.md"
$MSL keep grill-me -m "retitle A" >/dev/null
echo "Line B." >> "$HOME/.cursor/skills/grill-me/SKILL.md"; $MSL keep grill-me -m "add B" >/dev/null
$MSL revert grill-me v4 >/dev/null
out="$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")"
if grep -qF -- "Line B." <<<"$out" && ! grep -qF -- "(A)" <<<"$out"; then ok "revert undoes just that version"; else bad "revert undoes just that version" "$out"; fi
echo "dirty" >> "$HOME/.cursor/skills/grill-me/SKILL.md"
check "rollback refuses with live edits" sh -c "! $MSL rollback grill-me v1"
check "revert refuses with live edits" sh -c "! $MSL revert grill-me v4"
$MSL discard grill-me >/dev/null
lfid="$(printf -- '- z\n' | $MSL feedback add grill-me -t z | awk 'NR == 1 { print $1 }')"
sed 's/^Ask hard questions.$/Ask hard, specific questions./' "$HOME/.cursor/skills/grill-me/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/.cursor/skills/grill-me/SKILL.md"
$MSL keep grill-me -m "late fix" >/dev/null
lv="$(version_of grill-me)"
lf="$HOME/.meta-skill-loop/skills/grill-me/feedback/$lfid.md"
$MSL feedback mark "$lfid" applied --fixed-in "$lv" >/dev/null
has "history shows feedback linked after the keep" "$($MSL history grill-me)" "late fix [fixes $lfid]"
check "mark --fixed-in rejects an unknown version" sh -c "! $MSL feedback mark $lfid applied --fixed-in v99"
$MSL revert grill-me "$lv" >/dev/null
check "revert reopens feedback linked after the keep" grep -q '^status: open$' "$lf"

echo "copies"
skill "$HOME/.agents/skills/multi" multi
skill "$HOME/.claude/skills/multi" multi
has "add records every installed copy" "$($MSL add multi)" ".claude/skills/multi"
echo "extra" >> "$HOME/.agents/skills/multi/SKILL.md"
$MSL keep multi -m extra >/dev/null
check "keep propagates to other copies" grep -q extra "$HOME/.claude/skills/multi/SKILL.md"
echo "edited in the other copy" >> "$HOME/.claude/skills/multi/SKILL.md"
has "an edit in any copy is a live edit" "$(state_of multi)" "changed"
has "diff shows an edit made in the other copy" "$($MSL diff multi)" "+edited in the other copy"
has "keep of an edit made in the other copy" "$($MSL keep multi -m other)" "v3 kept"
check "that edit reaches every copy" grep -q "edited in the other copy" "$HOME/.agents/skills/multi/SKILL.md"
check "and is kept, not overwritten" grep -q "edited in the other copy" "$HOME/.claude/skills/multi/SKILL.md"
echo "edit A" >> "$HOME/.agents/skills/multi/SKILL.md"
echo "edit B" >> "$HOME/.claude/skills/multi/SKILL.md"
has "copies edited differently are a conflict" "$(state_of multi)" "copies-differ"
check "keep refuses to pick a copy by itself" sh -c "! $MSL keep multi -m x"
$MSL keep multi -m "take B" --from "$HOME/.claude/skills/multi" >/dev/null
check "keep --from takes the chosen copy" grep -q "edit B" "$HOME/.agents/skills/multi/SKILL.md"
has "the chosen copy is the new version" "$(version_of multi)" "v4"
rm -rf "$HOME/.claude/skills/multi"
has "a deleted copy is not a missing skill" "$(state_of multi)" "clean"
rm -rf "$HOME/.agents/skills/multi"
has "all copies deleted is missing" "$(state_of multi)" "missing"

echo "same name, different skills"
mkdir -p "$HOME/team/.cursor/skills" && (cd "$HOME/team" && git init -q)
skill "$HOME/.cursor/skills/pr-review" pr-review "My personal rules."
skill "$HOME/team/.cursor/skills/pr-review" pr-review "The team's rules."
out="$(cd "$HOME/team" && $MSL add pr-review)"
has "a different skill with the same name is not grouped" "$out" "is a different skill with the same name"
echo "Tweak." >> "$HOME/.cursor/skills/pr-review/SKILL.md"
(cd "$HOME/team" && $MSL keep pr-review -m tweak >/dev/null)
lacks "keeping one never overwrites the other" "$(cat "$HOME/team/.cursor/skills/pr-review/SKILL.md")" "Tweak."
$MSL remove pr-review >/dev/null

echo "skills CLI upstream: update, merge, conflicts"
skill "$HOME/.agents/skills/grilling" grilling "Ask the whole frontier in one round.
Keep going until done."
lock grilling aaaaaaaaaaaa
has "add detects the skills CLI" "$($MSL add grilling)" "(skills-cli, from https://github.com/acme/skills.git (skills/grilling))"
check "source is recorded as url and path" grep -q '^source_path: skills/grilling$' "$HOME/.meta-skill-loop/skills/grilling/skill.yaml"
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
upf="$(echo x | $MSL feedback add grilling -t "no summary" | awk 'NR == 1 { print $1 }')"
has "apply makes the next version" "$($MSL update grilling --apply --fixes "$upf")" "v3: grilling now runs upstream bbbbbbbbbbbb with your refinements"
check "feedback fixed by the update is applied in it" grep -q '^fixed_in: v3$' "$HOME/.meta-skill-loop/skills/grilling/feedback/$upf.md"
out="$(cat "$HOME/.agents/skills/grilling/SKILL.md")"
if grep -qF -- "Ask at most 3" <<<"$out" && grep -qF -- "Summarize at the end." <<<"$out"; then ok "merged skill has upstream change and your refinement"; else bad "merged skill has upstream change and your refinement" "$out"; fi
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
out="$($MSL update plain --no-fetch --check)"
has "update --check reports without applying" "$out" "Nothing was changed"
has "update --check shows what upstream changed" "$out" "+v two and a half"
has "check leaves your version live" "$(cat "$HOME/.agents/skills/plain/SKILL.md")" "v two"
lacks "check does not apply upstream" "$(cat "$HOME/.agents/skills/plain/SKILL.md")" "half"
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
$MSL update deploy --check >/dev/null
check "checking a repo skill never rewrites the repo" test -z "$(git -C "$HOME/work" status --porcelain)"
$MSL update deploy >/dev/null
$MSL update deploy --apply >/dev/null
out="$(cat "$HOME/work/.cursor/skills/deploy/SKILL.md")"
if grep -qF -- "smoke test" <<<"$out" && grep -qF -- "announce in the channel" <<<"$out"; then ok "repo change merged with your refinement"; else bad "repo change merged with your refinement" "$out"; fi

echo "remove"
skill "$HOME/.agents/skills/tmp-skill" tmp-skill
orig="$(cat "$HOME/.agents/skills/tmp-skill/SKILL.md")"
$MSL add tmp-skill >/dev/null
$MSL remove tmp-skill >/dev/null
check "remove leaves the skill untouched" test "$(cat "$HOME/.agents/skills/tmp-skill/SKILL.md")" = "$orig"
check "remove archives the data" sh -c "ls '$HOME/.meta-skill-loop/archive' | grep -q tmp-skill"
check "remove stops managing it" sh -c "! $MSL status tmp-skill"
check "remove keeps the conversation copies" test -f "$HOME/.meta-skill-loop/sessions/cur.jsonl"

echo "launcher follows the installed skill"
hub="$HOME/.agents/skills/meta-skill-loop/scripts/msl"
sed 's/^MSL_VERSION="[^"]*"/MSL_VERSION="9.9.9"/' "$hub" > "$HOME/x" && mv "$HOME/x" "$hub"
has "updating the skill updates msl (no stale copy)" "$($MSL version)" "9.9.9"
rm -rf "$HOME/.agents/skills/meta-skill-loop"
has "launcher falls back to another installed copy" "$($MSL version)" "0."
check "launcher now points at that copy" grep -q '.claude/skills/meta-skill-loop" "' "$HOME/.meta-skill-loop/bin/msl"
rm -rf "$HOME/.claude/skills/meta-skill-loop"
has "launcher explains how to reinstall" "$($MSL status 2>&1 || true)" "npx skills add SoulEvill/meta-skill-loop"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
