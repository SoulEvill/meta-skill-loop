#!/usr/bin/env bash
# End-to-end test with a real agent: install meta-skill-loop and a fixture skill the
# way users do, then drive the agent with plain-language prompts and check the
# outcomes on disk (not tool-call telemetry), so the same checks work for any agent.
#
#   tests/agent/run.sh claude-code   # needs `claude`, `jq`, and ANTHROPIC_API_KEY (or a login)
#   tests/agent/run.sh cursor        # experimental: needs `cursor-agent` and CURSOR_API_KEY
#   tests/agent/run.sh codex         # experimental: needs `codex` and OPENAI_API_KEY
#
# Model output varies; a failure here is a signal to look at the transcript in
# $HOME/transcripts, not proof of a bug. Costs a few model calls per run.
set -euo pipefail

AGENT="${1:?usage: tests/agent/run.sh claude-code|cursor|codex}"
REPO="$(cd "$(dirname "$0")/../.." && pwd -P)"
HOME="$(mktemp -d)"
export HOME DO_NOT_TRACK=1 DISABLE_TELEMETRY=1
PROJECT="$HOME/project"
mkdir -p "$PROJECT" "$HOME/transcripts"
(cd "$PROJECT" && git init -q)
fail=0
ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s (transcript: %s)\n' "$1" "${2:-}"; fail=1; }

case "$AGENT" in
  claude-code) agents="--agent claude-code"; skills_dir="$HOME/.claude/skills" ;;
  cursor) agents="--agent cursor"; skills_dir="$HOME/.agents/skills" ;;
  codex) agents="--agent codex"; skills_dir="$HOME/.agents/skills" ;;
  *) echo "unknown agent: $AGENT" >&2; exit 2 ;;
esac

# Ask the agent one thing; print its answer; keep the transcript (Claude Code: also every tool call, in N.txt.jsonl).
ask() {
  # Numbered from the files, not a counter: ask often runs in a $(…) subshell.
  local t="$HOME/transcripts/$(($(count) + 1)).txt"
  case "$AGENT" in
    claude-code)
      # shellcheck disable=SC2086
      (cd "$PROJECT" && claude -p ${CONTINUE:+--continue} "$1" --allowedTools "Skill" "Read" "Edit" "Write" "Bash(ls:*)" "Bash(test:*)" \
        "Bash(bash ~/.claude/skills/meta-skill-loop/scripts/msl:*)" "Bash(bash ~/.agents/skills/meta-skill-loop/scripts/msl:*)" \
        "Bash($skills_dir/meta-skill-loop/scripts/msl:*)" "Bash(bash $skills_dir/meta-skill-loop/scripts/msl:*)" \
        "Bash(../meta-skill-loop/scripts/msl:*)" "Bash(~/.meta-skill-loop/bin/msl:*)" "Bash($HOME/.meta-skill-loop/bin/msl:*)" \
        --output-format stream-json --verbose < /dev/null > "$t.jsonl" 2>&1   # every tool call, for diagnosing a failure
      jq -rR 'fromjson? | select(.type == "result") | .result' "$t.jsonl") ;;
    cursor)
      (cd "$PROJECT" && cursor-agent -p --force --output-format text "$1") ;;
    codex)
      (cd "$PROJECT" && codex exec --full-auto --skip-git-repo-check \
        -c "sandbox_workspace_write.writable_roots=[\"$HOME/.meta-skill-loop\"]" "$1") ;;
  esac > "$t" 2>&1 || true
  cat "$t"
}
count() { find "$HOME/transcripts" -name '*.txt' | wc -l | tr -d ' '; }
last() { printf '%s' "$HOME/transcripts/$(count).txt"; }

if [ "$AGENT" = codex ] && [ -n "${OPENAI_API_KEY:-}" ]; then
  printenv OPENAI_API_KEY | codex login --with-api-key >/dev/null  # stored in this throwaway HOME only
fi

echo "install ($AGENT)"
# shellcheck disable=SC2086
npx -y skills@latest add "$REPO" --skill meta-skill-loop $agents -g -y >/dev/null 2>&1
mkdir -p "$skills_dir/greeting" && cp "$REPO/tests/fixtures/greeting/SKILL.md" "$skills_dir/greeting/"
if [ -f "$skills_dir/meta-skill-loop/SKILL.md" ]; then ok "skills installed in $skills_dir"; else bad "skills installed"; fi

echo "feedback on a skill, first use (sets up the workspace itself)"
ask "feedback on the greeting skill: it used three exclamation marks, which is too much. One is enough." >/dev/null
fb="$(find "$HOME/.meta-skill-loop/skills/greeting/feedback" -name 'fb-*.md' 2>/dev/null | sed -n 1p)"
if [ -n "$fb" ] && grep -qi 'exclamation' "$fb"; then ok "feedback entry written for greeting"; else bad "feedback entry written for greeting" "$(last)"; fi
if [ -x "$HOME/.meta-skill-loop/bin/msl" ]; then ok "workspace and launcher set up on first use"; else bad "workspace set up on first use" "$(last)"; fi
if grep -q '!!!' "$skills_dir/greeting/SKILL.md"; then ok "logging feedback did not edit the skill"; else bad "logging feedback did not edit the skill" "$(last)"; fi

echo "status and versions"
out="$(ask "meta-skill-loop status")"
if grep -qi 'greeting' <<<"$out"; then ok "status mentions the managed skill"; else bad "status mentions the managed skill" "$(last)"; fi
out="$(ask "show me the versions of the greeting skill")"
if grep -q 'v1' <<<"$out"; then ok "versions shows v1"; else bad "versions shows v1" "$(last)"; fi

echo "unrelated request leaves meta-skill-loop alone"
before="$(find "$HOME/.meta-skill-loop/skills" -name 'fb-*.md' | wc -l | tr -d ' ')"
out="$(ask "write a python function that reverses a string; just show the code")"
after="$(find "$HOME/.meta-skill-loop/skills" -name 'fb-*.md' | wc -l | tr -d ' ')"
if grep -q 'def ' <<<"$out" && [ "$before" = "$after" ]; then ok "no feedback logged for an unrelated task"; else bad "no feedback logged for an unrelated task" "$(last)"; fi

if [ "$AGENT" = claude-code ]; then
  echo "a plain correction, without asking to log it, leaves meta-skill-loop alone"
  before="$(find "$HOME/.meta-skill-loop/skills" -name 'fb-*.md' | wc -l | tr -d ' ')"
  hello="$(ask "hello!")"
  out="$(CONTINUE=1 ask "hmm, three exclamation marks is way too much. one is enough")"
  # Guard against the checks below passing vacuously: the greeting skill ran, and the
  # correction got an answer. (Session ids can't show that --continue joined the same
  # conversation: in a Claude Code cloud session every child run reports the parent's id.)
  if grep -qF '!!!' <<<"$hello" && [ -n "$out" ]; then
    ok "the correction follows a greeting from the skill"; else bad "the correction follows a greeting from the skill" "$(last).jsonl"; fi
  after="$(find "$HOME/.meta-skill-loop/skills" -name 'fb-*.md' | wc -l | tr -d ' ')"
  if [ "$before" = "$after" ]; then ok "nothing logged"; else bad "nothing logged" "$(last)"; fi
  if ! grep -Eqi '(log|record|save|capture)[^.?!]{0,60}\?' <<<"$out"; then ok "not even offered"; else bad "not even offered" "$(last)"; fi
  if ! grep -Eq '"skill":"meta-skill-loop"|meta-skill-loop/(SKILL\.md|references/)' "$(last).jsonl"; then ok "the skill was not invoked"; else bad "the skill was not invoked" "$(last).jsonl"; fi

  echo "feedback without naming the skill"
  # Same conversation: the greeting skill was just used, so that's the one.
  CONTINUE=1 ask "ok, log feedback about that" >/dev/null
  after2="$(find "$HOME/.meta-skill-loop/skills" -name 'fb-*.md' | wc -l | tr -d ' ')"
  on_greeting="$({ grep -rli 'exclamation' "$HOME/.meta-skill-loop/skills/greeting/feedback" 2>/dev/null || true; } | wc -l | tr -d ' ')"
  if [ "$after2" = $((after + 1)) ] && [ "$on_greeting" = 2 ]; then
    ok "logged on the skill used in this conversation"; else bad "logged on the skill used in this conversation" "$(last).jsonl"; fi
  # A new conversation where no skill was used: ask which one, log nothing.
  out="$(ask "log some feedback: it was way too slow")"
  after3="$(find "$HOME/.meta-skill-loop/skills" -name 'fb-*.md' | wc -l | tr -d ' ')"
  if [ "$after3" = "$after2" ] && grep -q '?' <<<"$out"; then ok "no skill in sight: asks which, logs nothing"; else bad "no skill in sight: asks which, logs nothing" "$(last).jsonl"; fi

  echo "refine: propose, change nothing until approved, then keep"
  out="$(ask "refine the greeting skill")"
  st="$("$HOME/.meta-skill-loop/bin/msl" status greeting)"
  if grep -qF '!!!' "$skills_dir/greeting/SKILL.md" && grep -Eq 'greeting +[a-z-]+ +v1 ' <<<"$st"; then
    ok "proposed without changing the skill"; else bad "proposed without changing the skill" "$(last).jsonl"; fi
  CONTINUE=1 ask "looks good. apply it and keep it" >/dev/null
  st="$("$HOME/.meta-skill-loop/bin/msl" status greeting)"
  if ! grep -q '!!!' "$skills_dir/greeting/SKILL.md" && grep -Eq 'greeting +[a-z-]+ +v2 +0 +clean' <<<"$st"; then
    ok "approved edit kept as v2, its feedback applied"; else bad "approved edit kept as v2, its feedback applied" "$(last).jsonl
$st"; fi
fi

[ "$fail" = 0 ] && echo "agent tests ($AGENT): ok"
exit "$fail"
