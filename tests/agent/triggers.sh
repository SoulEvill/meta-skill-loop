#!/usr/bin/env bash
# Trigger eval (agentskills.io, "Optimizing skill descriptions"): does the skill load for
# the prompts in triggers.json that should trigger it, and stay out of the near-misses
# that shouldn't? Each prompt runs as a fresh conversation, RUNS times; a prompt passes
# when its trigger rate is on the right side of 0.5.
#
#   tests/agent/triggers.sh [claude-code]       # needs `claude`, `jq`, and ANTHROPIC_API_KEY
#                                               # (it runs in a throwaway HOME, so a login there isn't seen)
#   RUNS=1 tests/agent/triggers.sh              # quicker, noisier (default: 3)
#
# Only Claude Code is wired up: its stream-json output shows whether the skill was
# loaded. Costs about one short model call per prompt per run.
set -euo pipefail

AGENT="${1:-claude-code}"
[ "$AGENT" = claude-code ] || { echo "triggers.sh: only claude-code is supported so far" >&2; exit 2; }
REPO="$(cd "$(dirname "$0")/../.." && pwd -P)"
RUNS="${RUNS:-3}"
HOME="$(mktemp -d)"
export HOME DO_NOT_TRACK=1 DISABLE_TELEMETRY=1
PROJECT="$HOME/project"
mkdir -p "$PROJECT" "$HOME/runs" && (cd "$PROJECT" && git init -q)
skills_dir="$HOME/.claude/skills"

# The skill as users install it, plus the skills the prompts talk about.
npx -y skills@latest add "$REPO" --skill meta-skill-loop --agent claude-code -g -y >/dev/null 2>&1 \
  || { echo "triggers.sh: installing the skill with the skills CLI failed" >&2; exit 1; }
for s in greeting pr-review grill-me; do
  mkdir -p "$skills_dir/$s" && cp "$REPO/tests/fixtures/$s/SKILL.md" "$skills_dir/$s/"
done
[ -f "$skills_dir/meta-skill-loop/SKILL.md" ] || { echo "install failed" >&2; exit 1; }

# Did this run load meta-skill-loop: the Skill tool, or a read of its SKILL.md or references?
loaded() { # jsonl
  jq -rR 'fromjson? | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")
          | [.name, (.input.skill // ""), (.input.file_path // ""), (.input.command // "")] | @tsv' "$1" \
    | grep -E '^Skill	meta-skill-loop	|meta-skill-loop/(SKILL\.md|references/|scripts/msl)' >/dev/null
}

n="$(jq length "$REPO/tests/agent/triggers.json")"
pass=0 fail=0 i=0
while [ "$i" -lt "$n" ]; do
  query="$(jq -r ".[$i].query" "$REPO/tests/agent/triggers.json")"
  should="$(jq -r ".[$i].should_trigger" "$REPO/tests/agent/triggers.json")"
  hits=0 r=1
  while [ "$r" -le "$RUNS" ]; do
    out="$HOME/runs/$i-$r.jsonl"
    # A few turns are enough to see whether the skill was loaded.
    (cd "$PROJECT" && claude -p "$query" --max-turns 3 --allowedTools "Skill" "Read" \
      --output-format stream-json --verbose < /dev/null > "$out" 2>&1) || true
    if loaded "$out"; then hits=$((hits + 1)); fi
    r=$((r + 1))
  done
  # Passes when the trigger rate is above 0.5 for should-trigger, below it otherwise.
  if { [ "$should" = true ] && [ $((hits * 2)) -gt "$RUNS" ]; } || { [ "$should" = false ] && [ $((hits * 2)) -lt "$RUNS" ]; }; then
    verdict="ok  "; pass=$((pass + 1))
  else
    verdict="FAIL"; fail=$((fail + 1))
  fi
  printf '  %s %s/%s  should_trigger=%-5s  %s\n' "$verdict" "$hits" "$RUNS" "$should" "$(printf '%s' "$query" | tr '\n' ' ' | cut -c1-80)"
  i=$((i + 1))
done
printf '\ntriggers (%s, %s runs each): %s passed, %s failed. Transcripts: %s/runs\n' "$AGENT" "$RUNS" "$pass" "$fail" "$HOME"
[ "$fail" = 0 ]
