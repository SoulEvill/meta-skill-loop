#!/usr/bin/env bash
# End-to-end tests for msl, run in a throwaway $HOME.
# TEST_BASH picks the interpreter under test (CI uses /bin/bash 3.2 on macOS).
set -euo pipefail
export TZ=UTC   # history dates are compared with `date -u`

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
fails() { ! "$@" >/dev/null 2>&1; }                  # command...
fails_on() { local in="$1"; shift; ! printf '%s' "$in" | "$@" >/dev/null 2>&1; }  # stdin, command...
msl() { "$SH" "$HOME/.meta-skill-loop/bin/msl" "$@"; }

new_home() {
  # A space in the path on purpose: macOS user names and folders often have one.
  HOME="$(mktemp -d "${TMPDIR:-/tmp}"/"msl home.XXXXXX")"
  HOME="$(printf '%s' "$HOME" | sed 's#//*#/#g')"   # macOS TMPDIR ends in a slash
  export HOME
  unset MSL_HOME CLAUDE_CODE_SESSION_ID CLAUDECODE
  export MSL_BASH="$SH"   # the launcher runs msl with the bash under test
  cd "$HOME"
}

skill() { # dir name [body]
  mkdir -p "$1"
  printf -- '---\nname: %s\ndescription: test skill %s\n---\n\n# %s\n%s\n' "$2" "$2" "$2" "${3:-Do the thing.}" > "$1/SKILL.md"
}

state_of() { msl status "$1" | awk -v n="$1" '$1 == n { print $5 }'; }
version_of() { msl status "$1" | awk -v n="$1" '$1 == n { print $3 }'; }
fb() { printf 'fb-%s-%s' "$(awk '/^id: /{ print $2 }' "$HOME/.meta-skill-loop/workspace.yaml")" "$1"; }

lock() { # name rev
  mkdir -p "$HOME/.agents"
  printf '{"version":3,"skills":{"%s":{"source":"acme/skills","sourceUrl":"https://github.com/acme/skills.git","skillPath":"skills/%s/SKILL.md","skillFolderHash":"%s"}}}' \
    "$1" "$1" "$2" > "$HOME/.agents/.skill-lock.json"
}

echo "install and first use"
new_home
skill "$HOME/.cursor/skills/grill-me" grill-me "Ask hard questions."
# Two separate copies (a --copy install, or by hand); the launcher tests below rely on it.
for t in "$HOME/.agents/skills" "$HOME/.claude/skills"; do mkdir -p "$t" && cp -R "$REPO"/skills/* "$t/"; done
"$SH" "$HOME/.agents/skills/meta-skill-loop/scripts/msl" init >/dev/null
check "first use installs the msl launcher" test -x "$HOME/.meta-skill-loop/bin/msl"
check "launcher runs the installed skill, not the clone" fails grep -qF "$REPO" "$HOME/.meta-skill-loop/bin/msl"
check "workspace has a format version" grep -q '^format: 1$' "$HOME/.meta-skill-loop/workspace.yaml"
check "workspace has a 6-character id" grep -Eq '^id: [a-z0-9]{6}$' "$HOME/.meta-skill-loop/workspace.yaml"
check "first use manages nothing by itself" test -z "$(ls "$HOME/.meta-skill-loop/skills")"
has "meta-skill-loop's own skills are not nagged as unmanaged" "$(msl status)" "1 installed skill folder(s) not managed yet"
lacks "no leftover note on a clean install" "$(msl status)" "left over"
skill "$HOME/.agents/skills/meta-skill-feedback" meta-skill-feedback "Log feedback (0.2)."
skill "$HOME/.agents/skills/meta-skill-refine" meta-skill-refine "Refine (0.2)."
out="$(msl status)"
has "a user-level leftover from 0.2 gets the -g command to remove it" "$out" "Remove it: npx skills@latest remove meta-skill-feedback -g"
has "each leftover gets its own note" "$out" "Remove it: npx skills@latest remove meta-skill-refine -g"
has "the note also covers the old rules line" "$out" "the line mentioning meta-skill-feedback from your agent rules"
has "they aren't counted as unmanaged" "$out" "1 installed skill folder(s) not managed yet"
out="$(msl add)"
lacks "add doesn't list meta-skill-feedback" "$out" "new      meta-skill-feedback"
lacks "add doesn't list meta-skill-refine" "$out" "new      meta-skill-refine"
lacks "add doesn't list meta-skill-loop itself" "$out" "new      meta-skill-loop"
has "add shows the leftover note too" "$out" "left over from meta-skill-loop 0.2"
has "one folder is counted in the singular" "$out" "1 skill folder found, 1 not managed yet"
rm -rf "$HOME/.agents/skills/meta-skill-feedback" "$HOME/.agents/skills/meta-skill-refine"
mkdir -p "$HOME/proj02" && git -C "$HOME/proj02" init -q
skill "$HOME/proj02/.cursor/skills/meta-skill-refine" meta-skill-refine "Refine (0.2)."
out="$(cd "$HOME/proj02" && msl status)"
has "a leftover in a project says to delete that folder" "$out" "Delete that folder"
lacks "and doesn't suggest the -g command for it" "$out" "remove meta-skill-refine -g"
rm -rf "$HOME/proj02"
lacks "the note goes away once they're removed" "$(msl status)" "left over"

echo "add"
has "add with no name lists unmanaged skills" "$(msl add)" "new      grill-me"
before="$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")"
has "add a plain folder as local" "$(msl add grill-me)" "added grill-me (local) as v1"
check "add leaves the skill file untouched" test "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" = "$before"
check "no .git inside the skill folder" test ! -e "$HOME/.cursor/skills/grill-me/.git"
check "adding twice fails" fails msl add grill-me
check "add unknown skill fails" fails msl add nope
check "status of unmanaged skill fails" fails msl status nope
has "state clean after add" "$(state_of grill-me)" "clean"

echo "feedback"
printf '## Asked\ngrill me\n\n## Observed\n14 questions\n' | msl feedback add grill-me -t "Too many questions" --tool cursor --severity P1 >/dev/null
f1="$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 001).md"
check "entry id is workspace id + sequence" test -f "$f1"
check "entry is open" grep -q '^status: open$' "$f1"
check "entry records the title" grep -q '^title: Too many questions$' "$f1"
check "entry records the version" grep -q '^version: v1$' "$f1"
check "entry records the tool" grep -q '^tool: cursor$' "$f1"
check "entry records the severity" grep -q '^severity: P1$' "$f1"
check "entry keeps the body as written" grep -q '^## Observed$' "$f1"
echo x | msl feedback add grill-me -t second >/dev/null
f2="$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 002).md"
check "severity defaults to P2" grep -q '^severity: P2$' "$f2"
check "a title is required" fails_on x msl feedback add grill-me
check "empty body rejected" fails_on "" msl feedback add grill-me -t t
check "bad severity rejected" fails_on x msl feedback add grill-me -t t --severity huge
check "feedback on unmanaged skill rejected" fails_on x msl feedback add nope -t t
check "feedback --version rejects an unknown version" fails_on x msl feedback add grill-me -t t --version v9
msl feedback mark "$(fb 002)" declined >/dev/null
check "mark sets the status" grep -q '^status: declined$' "$f2"
lacks "list shows open entries only" "$(msl feedback list grill-me)" "title: second"
has "list --all shows every entry" "$(msl feedback list grill-me --all)" "title: second"
check "mark rejects an unknown status" fails msl feedback mark "$(fb 002)" candidate

echo "conversation copies"
mkdir -p "$HOME/.claude/projects/some-project"
echo '{"turn":"record this"}' > "$HOME/.claude/projects/some-project/cur-id.jsonl"
sleep 1; echo '{"turn":"another chat"}' > "$HOME/.claude/projects/some-project/other-chat.jsonl"
out="$(echo x | CLAUDE_CODE_SESSION_ID=cur-id msl feedback add grill-me -t s1)"
has "claude code: the current conversation is copied" "$out" "-cur-id.jsonl"
copied() { find "$HOME/.meta-skill-loop/sessions" -name "*-$1" 2>/dev/null; }
check "the copy is kept in the workspace" grep -q 'record this' "$(copied cur-id.jsonl)"
check "the entry points to the copy" grep -q '^session: ~/.meta-skill-loop/sessions/[0-9a-f]*-cur-id.jsonl$' "$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 003).md"
check "inside claude code the tool is detected" grep -q '^tool: claude-code$' "$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 003).md"
check "a newer, unrelated conversation is not taken" test -z "$(copied other-chat.jsonl)"
mkdir -p "$HOME/.codex/sessions/2026/09/28" && echo '{"turn":"codex chat"}' > "$HOME/.codex/sessions/2026/09/28/rollout-1.jsonl"
has "without a known current session nothing is guessed" "$(echo x | msl feedback add grill-me -t s2 --tool codex)" "no conversation copied"
check "so no unrelated conversation is stored" test -z "$(copied rollout-1.jsonl)"
has "an explicit --session file is copied" "$(echo x | msl feedback add grill-me -t s3 --tool codex --session "$HOME/.codex/sessions/2026/09/28/rollout-1.jsonl")" "-rollout-1.jsonl"
has "cursor: says nothing was copied" "$(echo x | msl feedback add grill-me -t s4 --tool cursor)" "no conversation copied"
lacks "--session none skips the copy" "$(echo x | CLAUDE_CODE_SESSION_ID=cur-id msl feedback add grill-me -t s5 --session none)" "conversation saved"
for n in 003 004 005 006 007; do msl feedback mark "$(fb $n)" declined >/dev/null; done

echo "edit, keep, discard, restore"
echo "Ask at most 5 questions per round." >> "$HOME/.cursor/skills/grill-me/SKILL.md"
has "edit shows as changed" "$(state_of grill-me)" "changed"
has "version marked as having edits" "$(version_of grill-me)" "v1*"
has "diff shows the edit" "$(msl diff grill-me)" "+Ask at most 5 questions per round."
printf -- '- x\n' | msl feedback add grill-me -t x >/dev/null
check "feedback during edits records +edits" grep -q '^version: v1+edits$' "$HOME/.meta-skill-loop/skills/grill-me/feedback/$(fb 008).md"
msl feedback mark "$(fb 008)" declined >/dev/null
has "keep creates v2" "$(msl keep grill-me -m "cap questions" --fixes "$(fb 001)")" "v2 kept"
check "keep marks feedback applied" grep -q '^status: applied$' "$f1"
check "keep records the fixing version" grep -q '^fixed_in: v2$' "$f1"
has "clean after keep" "$(state_of grill-me)" "clean"
check "keep with nothing to keep fails" fails msl keep grill-me -m x
echo "bad edit" >> "$HOME/.cursor/skills/grill-me/SKILL.md"
msl discard grill-me >/dev/null
lacks "discard throws the edit away" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "bad edit"
msl restore grill-me >/dev/null
has "restore brings it back" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "bad edit"
msl discard grill-me >/dev/null
mkdir -p "$HOME/.cursor/skills/grill-me/references"
echo "extra" > "$HOME/.cursor/skills/grill-me/references/new.md"
msl discard grill-me >/dev/null
check "discard removes new files too" test ! -e "$HOME/.cursor/skills/grill-me/references/new.md"
echo "Try this edit." >> "$HOME/.cursor/skills/grill-me/SKILL.md"
msl diff grill-me >/dev/null
msl git grill-me show mine:SKILL.md > "$HOME/x" && mv "$HOME/x" "$HOME/.cursor/skills/grill-me/SKILL.md"
has "edits wiped by a reinstall are reported" "$(msl status grill-me)" "your last live edits"
has "diff --saved previews what restore brings back" "$(msl diff grill-me --saved)" "+Try this edit."
msl restore grill-me >/dev/null
has "restore recovers wiped edits" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "Try this edit."
msl discard grill-me >/dev/null
lacks "discarded edits are not reported as lost" "$(msl status grill-me)" "your last live edits"

echo "history and rollback"
out="$(msl history grill-me)"
has "history lists versions" "$out" "cap questions [fixes $(fb 001)]"
has "history marks live version" "$out" "* v2"
vid="$(printf -- '- about v1\n' | msl feedback add grill-me -t old --version v1 | awk 'NR == 1 { print $1 }')"
check "feedback can name the version it's about" grep -q '^version: v1$' "$HOME/.meta-skill-loop/skills/grill-me/feedback/$vid.md"
msl feedback mark "$vid" declined >/dev/null
out="$(msl history grill-me)"
has "history counts feedback per version" "$out" "v1     $(date -u +%Y-%m-%d) 9"
has "diff between versions" "$(msl diff grill-me v1 v2)" "+Ask at most 5 questions per round."
msl rollback grill-me v1 >/dev/null
lacks "rollback restores old content" "$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")" "Ask at most 5"
has "rollback is a new version" "$(version_of grill-me)" "v3"
check "rollback reopens feedback the undone versions fixed" grep -q '^status: open$' "$f1"
check "reopened feedback is no longer linked to a version" fails grep -q '^fixed_in:' "$f1"
sed 's/^# grill-me$/# Grill me (A)/' "$HOME/.cursor/skills/grill-me/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/.cursor/skills/grill-me/SKILL.md"
msl keep grill-me -m "retitle A" >/dev/null
echo "Line B." >> "$HOME/.cursor/skills/grill-me/SKILL.md"; msl keep grill-me -m "add B" >/dev/null
msl revert grill-me v4 >/dev/null
out="$(cat "$HOME/.cursor/skills/grill-me/SKILL.md")"
if grep -qF -- "Line B." <<<"$out" && ! grep -qF -- "(A)" <<<"$out"; then ok "revert undoes just that version"; else bad "revert undoes just that version" "$out"; fi
echo "dirty" >> "$HOME/.cursor/skills/grill-me/SKILL.md"
check "rollback refuses with live edits" fails msl rollback grill-me v1
check "revert refuses with live edits" fails msl revert grill-me v4
msl discard grill-me >/dev/null
lfid="$(printf -- '- z\n' | msl feedback add grill-me -t z | awk 'NR == 1 { print $1 }')"
sed 's/^Ask hard questions.$/Ask hard, specific questions./' "$HOME/.cursor/skills/grill-me/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/.cursor/skills/grill-me/SKILL.md"
msl keep grill-me -m "late fix" >/dev/null
lv="$(version_of grill-me)"
lf="$HOME/.meta-skill-loop/skills/grill-me/feedback/$lfid.md"
msl feedback mark "$lfid" applied --fixed-in "$lv" >/dev/null
has "history shows feedback linked after the keep" "$(msl history grill-me)" "late fix [fixes $lfid]"
check "mark --fixed-in rejects an unknown version" fails msl feedback mark "$lfid" applied --fixed-in v99
msl revert grill-me "$lv" >/dev/null
check "revert reopens feedback linked after the keep" grep -q '^status: open$' "$lf"

echo "one folder per skill"
skill "$HOME/.agents/skills/multi" multi
skill "$HOME/.claude/skills/multi" multi
echo "SECRET=1" > "$HOME/.claude/skills/multi/.env"
out="$(msl add multi)"
has "the real folder is the one in ~/.agents/skills" "$out" "  ~/.agents/skills/multi"
has "an identical copy in another tool folder is offered a link" "$out" "msl link multi"
check "adding never touches the copy" test -f "$HOME/.claude/skills/multi/.env"
has "status points out the separate copy" "$(msl status multi)" "is a separate copy, not a link"
has "link replaces the copy with a link" "$(msl link multi)" "linked ~/.claude/skills/multi"
check "the tool folder now links to the one folder" test -L "$HOME/.claude/skills/multi"
has "the copy is set aside, not deleted" "$(find "$HOME/.meta-skill-loop/archive/copies" -name .env)" "multi-"
has "linking again has nothing to do" "$(msl link multi)" "already loads"
echo "edited through Claude Code" >> "$HOME/.claude/skills/multi/SKILL.md"
has "an edit through any tool's folder is a live edit" "$(state_of multi)" "changed"
msl keep multi -m "tool edit" >/dev/null
check "every tool loads the kept version" grep -q "edited through Claude Code" "$HOME/.agents/skills/multi/SKILL.md"
lacks "nothing to flag once linked" "$(msl status multi)" "separate copy"
rm "$HOME/.claude/skills/multi" && cp -R "$HOME/.agents/skills/multi" "$HOME/.claude/skills/multi"
has "a copy that replaced the link (a reinstall) is flagged" "$(msl status multi)" "is a separate copy, not a link"
msl link multi >/dev/null
check "and linked again" test -L "$HOME/.claude/skills/multi"
rm "$HOME/.claude/skills/multi"
has "a removed link doesn't matter" "$(state_of multi)" "clean"
rm -rf "$HOME/.agents/skills/multi"
has "the folder deleted is missing" "$(state_of multi)" "missing"

echo "same name, different skills"
mkdir -p "$HOME/team/.cursor/skills" && (cd "$HOME/team" && git init -q)
skill "$HOME/.cursor/skills/pr-review" pr-review "My personal rules."
skill "$HOME/team/.cursor/skills/pr-review" pr-review "The team's rules."
out="$(cd "$HOME/team" && msl add pr-review)"
has "a different skill with the same name is not grouped" "$out" "is a different skill with the same name"
echo "Tweak." >> "$HOME/.cursor/skills/pr-review/SKILL.md"
(cd "$HOME/team" && msl keep pr-review -m tweak >/dev/null)
lacks "keeping one never overwrites the other" "$(cat "$HOME/team/.cursor/skills/pr-review/SKILL.md")" "Tweak."
msl remove pr-review >/dev/null

echo "skills CLI upstream: update, merge, conflicts"
skill "$HOME/.agents/skills/grilling" grilling "Ask the whole frontier in one round.
Keep going until done."
lock grilling aaaaaaaaaaaa
has "add detects the skills CLI" "$(msl add grilling)" "(skills-cli, from https://github.com/acme/skills.git (skills/grilling))"
check "source is recorded as url and path" grep -q '^source_path: skills/grilling$' "$HOME/.meta-skill-loop/skills/grilling/skill.yaml"
sed 's/Ask the whole frontier in one round./Ask at most 3 questions per round./' "$HOME/.agents/skills/grilling/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/.agents/skills/grilling/SKILL.md"
msl keep grilling -m "3 questions" >/dev/null
# The skills CLI installs a new upstream version over the live folder.
skill "$HOME/.agents/skills/grilling" grilling "Ask the whole frontier in one round.
Keep going until done.
Summarize at the end."
lock grilling bbbbbbbbbbbb
has "direct installer update detected" "$(state_of grilling)" "upstream"
check "keep refuses an upstream version" fails msl keep grilling -m x
out="$(msl update grilling --no-fetch)"
has "update records upstream and prepares a merge" "$out" "merged with your version cleanly"
has "live folder is back on your version during review" "$(cat "$HOME/.agents/skills/grilling/SKILL.md")" "Ask at most 3 questions per round."
lacks "live folder does not yet have upstream" "$(cat "$HOME/.agents/skills/grilling/SKILL.md")" "Summarize at the end."
has "diff --merge shows what would change" "$(msl diff grilling --merge)" "+Summarize at the end."
check "a second update waits for the pending merge" fails msl update grilling --no-fetch
upf="$(echo x | msl feedback add grilling -t "no summary" | awk 'NR == 1 { print $1 }')"
has "apply makes the next version" "$(msl update grilling --apply --fixes "$upf")" "v3: grilling now runs upstream bbbbbbbbbbbb with your refinements"
check "feedback fixed by the update is applied in it" grep -q '^fixed_in: v3$' "$HOME/.meta-skill-loop/skills/grilling/feedback/$upf.md"
out="$(cat "$HOME/.agents/skills/grilling/SKILL.md")"
if grep -qF -- "Ask at most 3" <<<"$out" && grep -qF -- "Summarize at the end." <<<"$out"; then ok "merged skill has upstream change and your refinement"; else bad "merged skill has upstream change and your refinement" "$out"; fi
has "history shows the upstream merge" "$(msl history grilling)" "took upstream bbbbbbbbbbbb"
has "up to date afterwards" "$(msl update grilling --no-fetch)" "up to date"
# Reinstalling the same upstream version wipes your refinements from the folder.
skill "$HOME/.agents/skills/grilling" grilling "Ask the whole frontier in one round.
Keep going until done.
Summarize at the end."
has "known upstream put back is detected" "$(state_of grilling)" "upstream"
msl update grilling --no-fetch >/dev/null
has "update restores your version" "$(cat "$HOME/.agents/skills/grilling/SKILL.md")" "Ask at most 3 questions per round."
# Conflicting upstream change.
skill "$HOME/.agents/skills/grilling" grilling "Ask exactly one question per round.
Keep going until done.
Summarize at the end."
lock grilling cccccccccccc
has "conflicting update is reported" "$(msl update grilling --no-fetch)" "with conflicts in"
check "apply refuses unresolved conflicts" fails msl update grilling --apply
has "abort drops the merge" "$(msl update grilling --abort)" "dropped the pending merge"
has "unmerged upstream is reported" "$(msl status grilling)" "not merged into your version yet"
has "take-upstream replaces your version" "$(msl update grilling --take-upstream)" "as published"
has "live is now plain upstream" "$(cat "$HOME/.agents/skills/grilling/SKILL.md")" "Ask exactly one question per round."

echo "fast-forward when you have no refinements"
skill "$HOME/.agents/skills/plain" plain "v one"
lock plain 111111111111
msl add plain >/dev/null
skill "$HOME/.agents/skills/plain" plain "v two"
lock plain 222222222222
has "update without refinements applies directly" "$(msl update plain --no-fetch)" "you had no refinements to merge"
has "fast-forwarded content is live" "$(cat "$HOME/.agents/skills/plain/SKILL.md")" "v two"
skill "$HOME/.agents/skills/plain" plain "v two and a half"
lock plain 252525252525
out="$(msl update plain --no-fetch --check)"
has "update --check reports without applying" "$out" "Nothing was changed"
has "update --check shows what upstream changed" "$out" "+v two and a half"
has "check leaves your version live" "$(cat "$HOME/.agents/skills/plain/SKILL.md")" "v two"
lacks "check does not apply upstream" "$(cat "$HOME/.agents/skills/plain/SKILL.md")" "half"
skill "$HOME/.agents/skills/plain" plain "v three"
lock plain 333333333333
has "a second update without refinements also applies directly" "$(msl update plain --no-fetch)" "you had no refinements to merge"
has "second fast-forward is live" "$(cat "$HOME/.agents/skills/plain/SKILL.md")" "v three"
check "own skills have no upstream" fails msl update grill-me

echo "skill inside a git repo"
mkdir -p "$HOME/work" && git -C "$HOME/work" init -q
skill "$HOME/work/.cursor/skills/deploy" deploy "Deploy carefully."
git -C "$HOME/work" add -A && git -C "$HOME/work" -c user.name=t -c user.email=t@t commit -qm init
has "a skill in a git repo is managed like your own" "$(cd "$HOME/work" && msl add deploy)" "added deploy (local)"
echo "Run the smoke test first." >> "$HOME/work/.cursor/skills/deploy/SKILL.md"
msl keep deploy -m "smoke test" >/dev/null
# A teammate's change arrives with git pull; git merges it with the uncommitted refinement.
git -C "$HOME/work" stash -q
sed 's/^# deploy$/# deploy (announce in the channel)/' "$HOME/work/.cursor/skills/deploy/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/work/.cursor/skills/deploy/SKILL.md"
git -C "$HOME/work" -c user.name=t -c user.email=t@t commit -qam "team change"
git -C "$HOME/work" stash pop -q
has "what a pull brought is a live edit" "$(state_of deploy)" "changed"
has "whose diff shows it" "$(msl diff deploy)" "+# deploy (announce in the channel)"
msl keep deploy -m "team: announce in the channel" >/dev/null
out="$(cat "$HOME/work/.cursor/skills/deploy/SKILL.md")"
if grep -qF -- "smoke test" <<<"$out" && grep -qF -- "announce in the channel" <<<"$out"; then ok "kept with your refinement"; else bad "kept with your refinement" "$out"; fi
has "msl never commits in the repo" "$(git -C "$HOME/work" rev-list --count HEAD)" "2"
check "a repo skill has no upstream for msl to update" fails msl update deploy

echo "edge cases"
# The skills CLI without --copy links the Claude Code folder to ~/.agents/skills.
skill "$HOME/.agents/skills/linked" linked
ln -s "$HOME/.agents/skills/linked" "$HOME/.claude/skills/linked"
has "a symlinked install is recognized as a link" "$(msl add linked)" "also loaded from ~/.claude/skills/linked (a link to it)"
echo "via the link" >> "$HOME/.claude/skills/linked/SKILL.md"
has "an edit through the link is a live edit" "$(state_of linked)" "changed"
has "and can be kept" "$(msl keep linked -m link)" "v2 kept"
# Scripts inside a skill keep their executable bit through discard and rollback.
mkdir -p "$HOME/.agents/skills/tooling/scripts"
skill "$HOME/.agents/skills/tooling" tooling
printf '#!/bin/sh\necho hi\n' > "$HOME/.agents/skills/tooling/scripts/run.sh" && chmod +x "$HOME/.agents/skills/tooling/scripts/run.sh"
msl add tooling >/dev/null
echo "x" >> "$HOME/.agents/skills/tooling/scripts/run.sh"; msl discard tooling >/dev/null
check "discard keeps scripts executable" test -x "$HOME/.agents/skills/tooling/scripts/run.sh"
for i in 2 3 4 5 6 7 8 9 10 11; do echo "line $i" >> "$HOME/.agents/skills/tooling/SKILL.md"; msl keep tooling -m "step $i" >/dev/null; done
has "versions past v9 count up correctly" "$(version_of tooling)" "v11"
has "rollback to a two-digit version" "$(msl rollback tooling v10)" "v12: tooling now has the content of v10"
check "rollback keeps scripts executable" test -x "$HOME/.agents/skills/tooling/scripts/run.sh"
# Windows line endings and a name that differs from the folder name.
mkdir -p "$HOME/.agents/skills/folder-name"
printf -- '---\r\nname: real-name\r\ndescription: crlf\r\n---\r\nbody\r\n' > "$HOME/.agents/skills/folder-name/SKILL.md"
has "a skill is found by its frontmatter name, even with CRLF" "$(msl add real-name)" "added real-name (local) as v1"
# Parallel sessions logging feedback while another checks status.
for i in 1 2 3 4 5 6; do
  ( echo x | msl feedback add tooling -t "parallel $i" >/dev/null 2>&1 ) &
  ( msl status tooling >/dev/null 2>&1 ) &
done
wait
has "parallel feedback gets distinct ids" "$(find "$HOME/.meta-skill-loop/skills/tooling/feedback" -name "fb-*.md" | wc -l | tr -d ' ')" "6"
lacks "parallel calls don't see phantom edits" "$(cat "$HOME/.meta-skill-loop/skills/tooling/feedback"/*.md)" "+edits"
has "and the skill is still clean" "$(state_of tooling)" "clean"

# `npx skills update` has no --copy: it reinstalls the Claude Code copy as a link
# into ~/.agents/skills. The one folder stays the one folder.
skill "$HOME/.agents/skills/relinked" relinked "Base."
skill "$HOME/.claude/skills/relinked" relinked "Base."
lock relinked 111111111111
msl add relinked >/dev/null
msl link relinked >/dev/null
echo "Mine." >> "$HOME/.claude/skills/relinked/SKILL.md"
msl keep relinked -m mine >/dev/null
rm -rf "$HOME/.agents/skills/relinked" "$HOME/.claude/skills/relinked"
skill "$HOME/.agents/skills/relinked" relinked "Base, updated upstream."
ln -s ../../.agents/skills/relinked "$HOME/.claude/skills/relinked"
lock relinked 222222222222
has "an installer update is detected" "$(state_of relinked)" "upstream"
lacks "the installer's own link isn't flagged" "$(msl status relinked)" "separate copy"
msl update relinked --no-fetch >/dev/null
check "recording it leaves the skill in place, not empty" test -f "$HOME/.agents/skills/relinked/SKILL.md"
has "and your version stays live in every tool" "$(cat "$HOME/.claude/skills/relinked/SKILL.md")" "Mine."

echo "review fixes"
# A pending merge is applied only if nothing changed since it was prepared.
skill "$HOME/.agents/skills/pending" pending "Line one.

Line two."
lock pending 111111111111
msl add pending >/dev/null
sed 's/^Line one.$/Line one, refined./' "$HOME/.agents/skills/pending/SKILL.md" > "$HOME/x" && mv "$HOME/x" "$HOME/.agents/skills/pending/SKILL.md"
msl keep pending -m refined >/dev/null
skill "$HOME/.agents/skills/pending" pending "Line one.

Line two, upstream."
lock pending 222222222222
msl update pending --no-fetch >/dev/null
echo "Edited during the review." >> "$HOME/.agents/skills/pending/SKILL.md"
check "apply refuses when the skill changed during the review" fails msl update pending --apply
has "and the new edit is untouched" "$(cat "$HOME/.agents/skills/pending/SKILL.md")" "Edited during the review."
has "and no version was made" "$(version_of pending)" "v2"
msl update pending --abort >/dev/null
msl discard pending >/dev/null
msl update pending --no-fetch >/dev/null
has "a fresh review applies" "$(msl update pending --apply)" "v3: pending now runs upstream 222222222222"

# A version is never claimed if git can't record it.
msl git tooling config commit.gpgsign true && msl git tooling config gpg.program false
echo "unsigned edit" >> "$HOME/.agents/skills/tooling/SKILL.md"
tfid="$(echo x | msl feedback add tooling -t signing | awk 'NR == 1 { print $1 }')"
check "keep fails when git can't commit" fails msl keep tooling -m signed --fixes "$tfid"
has "no version was claimed" "$(version_of tooling)" "v12*"
check "the feedback stays open" grep -q '^status: open$' "$HOME/.meta-skill-loop/skills/tooling/feedback/$tfid.md"
has "the edit is still live" "$(cat "$HOME/.agents/skills/tooling/SKILL.md")" "unsigned edit"
msl git tooling config --unset commit.gpgsign && msl git tooling config --unset gpg.program
msl discard tooling >/dev/null

# --fixes must name feedback on the skill being kept.
echo "B change" >> "$HOME/.agents/skills/linked/SKILL.md"
check "keep refuses feedback from another skill" fails msl keep linked -m x --fixes "$tfid"
has "and makes no version" "$(version_of linked)" "v2*"
msl discard linked >/dev/null

# One msl command at a time; a lock left by a crashed run is cleared.
for i in 1 2 3; do
  echo "par $i" >> "$HOME/.agents/skills/tooling/SKILL.md"
  ( msl keep tooling -m "par $i" >/dev/null 2>&1 ) &
  ( msl diff tooling v1 >/dev/null 2>&1 ) &
  wait
done
has "keeps racing with diffs record every edit" "$(msl git tooling show mine:SKILL.md)" "par 3"
has "and leave the skill clean" "$(state_of tooling)" "clean"
mkdir -p "$HOME/.meta-skill-loop/lock" && echo 999999 > "$HOME/.meta-skill-loop/lock/pid"
has "a stale lock doesn't block" "$(state_of tooling)" "clean"
check "and the lock is released after each command" test ! -e "$HOME/.meta-skill-loop/lock"

# Feedback ids are unique across skills, even when logged at the same moment.
for i in 1 2 3 4 5 6; do
  ( echo x | msl feedback add tooling -t "a$i" >/dev/null 2>&1 ) &
  ( echo x | msl feedback add linked -t "b$i" >/dev/null 2>&1 ) &
done
wait
check "parallel feedback on two skills gets distinct ids" test -z "$(find "$HOME/.meta-skill-loop/skills" -name 'fb-*.md' | sed 's#.*/##' | sort | uniq -d)"

# The skills CLI lock speaks only for folders the CLI installed.
skill "$HOME/.agents/skills/shared-name" shared-name "The public one."
lock shared-name 333333333333
mkdir -p "$HOME/team3/.cursor/skills" && git -C "$HOME/team3" init -q
skill "$HOME/team3/.cursor/skills/shared-name" shared-name "The team's own."
git -C "$HOME/team3" add -A && git -C "$HOME/team3" -c user.name=t -c user.email=t@t commit -qm init
has "a project skill sharing a name with a CLI install isn't taken for it" "$(msl add "$HOME/team3/.cursor/skills/shared-name")" "added shared-name (local)"

echo "review round 2"
# An installer release that changes only a dotfile is acknowledged, so a later edit is yours.
skill "$HOME/.agents/skills/dotrel" dotrel "Base."
lock dotrel 111111111111
msl add dotrel >/dev/null
echo "meta" > "$HOME/.agents/skills/dotrel/.skill-meta"
lock dotrel 222222222222
has "a dotfile-only release leaves the skill clean" "$(state_of dotrel)" "clean"
echo "My edit." >> "$HOME/.agents/skills/dotrel/SKILL.md"
has "a later edit is a live edit, not an installer update" "$(state_of dotrel)" "changed"
msl update dotrel --no-fetch --check >/dev/null 2>&1 || true
has "and checking for updates never takes it away" "$(cat "$HOME/.agents/skills/dotrel/SKILL.md")" "My edit."
has "it can be kept" "$(msl keep dotrel -m mine)" "v2 kept"

# The skill's own .gitignore doesn't change what msl versions.
skill "$HOME/.agents/skills/ignored" ignored
echo "notes" > "$HOME/.agents/skills/ignored/notes.txt"
msl add ignored >/dev/null
printf 'notes.txt\ndraft.md\n' > "$HOME/.agents/skills/ignored/.gitignore"
has "a new .gitignore doesn't make tracked files look deleted" "$(state_of ignored)" "clean"
lacks "and the diff shows nothing" "$(msl diff ignored)" "notes.txt"
echo "draft" > "$HOME/.agents/skills/ignored/draft.md"
has "a file the skill's .gitignore lists is still a skill file" "$(state_of ignored)" "changed"
msl keep ignored -m draft >/dev/null
has "keep leaves the skill clean" "$(state_of ignored)" "clean"
has "and the version has the file" "$(msl git ignored show mine:draft.md)" "draft"
echo "more" >> "$HOME/.agents/skills/ignored/notes.txt"; msl discard ignored >/dev/null
has "discard leaves it clean too" "$(state_of ignored)" "clean"

# Two conversation files with the same name never overwrite each other's copy.
mkdir -p "$HOME/chats/a" "$HOME/chats/b"
echo '{"chat":"A"}' > "$HOME/chats/a/session.jsonl"; echo '{"chat":"B"}' > "$HOME/chats/b/session.jsonl"
sa="$(echo x | msl feedback add ignored -t a --session "$HOME/chats/a/session.jsonl" | awk 'NR == 1 { print $1 }')"
echo x | msl feedback add ignored -t b --session "$HOME/chats/b/session.jsonl" >/dev/null
check "each feedback keeps its own conversation" grep -q '"A"' "$(msl feedback list ignored --all | awk -v id="$sa" '$0 == "id: " id { f = 1 } f && /^session: / { print $2; exit }' | sed "s#^~#$HOME#")"

# Taking upstream as published is a valid decision while a merge waits for review.
msl update pending --no-fetch >/dev/null 2>&1 || true
skill "$HOME/.agents/skills/pending" pending "Line one.

Line two, upstream again."
lock pending 444444444444
msl update pending --no-fetch >/dev/null
has "--take-upstream works with a merge waiting" "$(msl update pending --take-upstream --no-fetch)" "as published"

echo "remove"
skill "$HOME/.agents/skills/tmp-skill" tmp-skill
orig="$(cat "$HOME/.agents/skills/tmp-skill/SKILL.md")"
msl add tmp-skill >/dev/null
msl remove tmp-skill >/dev/null
check "remove leaves the skill untouched" test "$(cat "$HOME/.agents/skills/tmp-skill/SKILL.md")" = "$orig"
has "remove archives the data" "$(ls "$HOME/.meta-skill-loop/archive")" "tmp-skill"
check "remove stops managing it" fails msl status tmp-skill
check "remove keeps the conversation copies" test -n "$(copied cur-id.jsonl)"

echo "launcher follows the installed skill"
hub="$HOME/.agents/skills/meta-skill-loop/scripts/msl"
sed 's/^MSL_VERSION="[^"]*"/MSL_VERSION="9.9.9"/' "$hub" > "$HOME/x" && mv "$HOME/x" "$hub"
has "updating the skill updates msl (no stale copy)" "$(msl version)" "9.9.9"
rm -rf "$HOME/.agents/skills/meta-skill-loop"
has "launcher falls back to another installed copy" "$(msl version)" "0."
check "launcher now points at that copy" grep -q '.claude/skills/meta-skill-loop" "' "$HOME/.meta-skill-loop/bin/msl"
rm -rf "$HOME/.claude/skills/meta-skill-loop"
has "launcher explains how to reinstall" "$(msl status 2>&1 || true)" "npx skills@latest add SoulEvill/meta-skill-loop --skill meta-skill-loop"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
