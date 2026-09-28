#!/usr/bin/env bash
# End-to-end test with a real agent: install meta-skill-loop and a fixture skill the
# way users do, then drive the agent with plain-language prompts and check the
# outcomes on disk (not tool-call telemetry), so the same checks work for any agent.
#
#   tests/agent/run.sh claude-code   # needs `claude` and ANTHROPIC_API_KEY (or a login)
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
n=0
ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s (transcript: %s)\n' "$1" "${2:-}"; fail=1; }

case "$AGENT" in
  claude-code) agents="-a claude-code"; skills_dir="$HOME/.claude/skills" ;;
  cursor) agents="-a cursor"; skills_dir="$HOME/.agents/skills" ;;
  codex) agents="-a codex"; skills_dir="$HOME/.agents/skills" ;;
  *) echo "unknown agent: $AGENT" >&2; exit 2 ;;
esac

# Ask the agent one thing; print its answer; keep the transcript.
ask() {
  n=$((n + 1))
  local t="$HOME/transcripts/$n.txt"
  case "$AGENT" in
    claude-code)
      (cd "$PROJECT" && claude -p "$1" --allowedTools "Skill" "Read" "Bash(ls:*)" "Bash(test:*)" \
        "Bash(bash ~/.claude/skills/meta-skill-loop/scripts/msl:*)" "Bash(bash ~/.agents/skills/meta-skill-loop/scripts/msl:*)" \
        "Bash($skills_dir/meta-skill-loop/scripts/msl:*)" "Bash(bash $skills_dir/meta-skill-loop/scripts/msl:*)" \
        "Bash(../meta-skill-loop/scripts/msl:*)" "Bash(~/.meta-skill-loop/bin/msl:*)" "Bash($HOME/.meta-skill-loop/bin/msl:*)") ;;
    cursor)
      (cd "$PROJECT" && cursor-agent -p --force --output-format text "$1") ;;
    codex)
      (cd "$PROJECT" && codex exec --full-auto --skip-git-repo-check \
        -c "sandbox_workspace_write.writable_roots=[\"$HOME/.meta-skill-loop\"]" "$1") ;;
  esac > "$t" 2>&1 || true
  cat "$t"
}
last() { printf '%s' "$HOME/transcripts/$n.txt"; }

if [ "$AGENT" = codex ] && [ -n "${OPENAI_API_KEY:-}" ]; then
  printenv OPENAI_API_KEY | codex login --with-api-key >/dev/null  # stored in this throwaway HOME only
fi

echo "install ($AGENT)"
# shellcheck disable=SC2086
npx -y skills@latest add "$REPO" --skill '*' -g --copy $agents -y >/dev/null 2>&1
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

[ "$fail" = 0 ] && echo "agent tests ($AGENT): ok"
exit "$fail"
