#!/usr/bin/env bash
# Install this repo the way users do, with the real `skills` CLI, for Cursor, Codex,
# and Claude Code, then run first use from the installed copy. Needs Node.js (npx)
# and network access.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
HOME="$(mktemp -d)"
export HOME DO_NOT_TRACK=1 DISABLE_TELEMETRY=1
fail=0
ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/       /'; fail=1; }

echo "skills CLI install"
# The CLI colors its output on CI (Found \e[32m1\e[39m skill); compare plain text.
out="$(npx -y skills@latest add "$REPO" --list 2>&1 | sed "s/$(printf '\033')\[[0-9;?]*[A-Za-z]//g" || true)"
if grep -qF "Found 1 skill" <<<"$out" && grep -qE '^[^A-Za-z]*meta-skill-loop[[:space:]]*$' <<<"$out"; then ok "package is one skill, meta-skill-loop"; else bad "package is one skill, meta-skill-loop" "$out"; fi
# The README's install: one real folder in ~/.agents/skills, a link for Claude Code.
npx -y skills@latest add "$REPO" --skill meta-skill-loop --agent cursor claude-code codex -g -y >/dev/null 2>&1 || bad "skills CLI install"
s="$HOME/.agents/skills/meta-skill-loop"
if [ -f "$s/SKILL.md" ] && [ ! -L "$s" ]; then ok "installed ~/.agents/skills/meta-skill-loop"; else bad "installed ~/.agents/skills/meta-skill-loop"; fi
if [ -f "$HOME/.claude/skills/meta-skill-loop/SKILL.md" ]; then ok "Claude Code sees it"; else bad "Claude Code sees it"; fi
for f in references/feedback.md references/refine.md references/contribute.md scripts/msl; do
  if [ -f "$s/$f" ]; then ok "installed with $f"; else bad "installed with $f"; fi
done
# A skill from another source, installed the same way, to manage below.
npx -y skills@latest add "$REPO/tests/fixtures" --skill greeting --agent cursor claude-code codex -g -y >/dev/null 2>&1 || bad "skills CLI install of the fixture"

echo "first use from the installed skill"
bash "$HOME/.agents/skills/meta-skill-loop/scripts/msl" init >/dev/null
M="$HOME/.meta-skill-loop/bin/msl"
if [ -x "$M" ]; then ok "launcher created"; else bad "launcher created"; fi
if "$M" version >/dev/null; then ok "launcher runs msl"; else bad "launcher runs msl"; fi
out="$("$M" add greeting)"
if grep -qF "as v1" <<<"$out"; then ok "a skill installed by the CLI can be managed"; else bad "a skill installed by the CLI can be managed" "$out"; fi
if grep -qF "a link to it" <<<"$out" && ! grep -qF "msl link" <<<"$out"; then ok "the Claude Code link is recognized; nothing to link"; else bad "the Claude Code link is recognized; nothing to link" "$out"; fi
printf -- '- observed: test\n' | "$M" feedback add greeting -t test --tool ci >/dev/null
out="$("$M" status greeting)"
if grep -qE 'greeting +[a-z-]+ +v1 +1 ' <<<"$out"; then ok "feedback recorded"; else bad "feedback recorded" "$out"; fi

[ "$fail" = 0 ] && echo "package: ok"
exit "$fail"
