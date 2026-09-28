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
out="$(npx -y skills@latest add "$REPO" --list 2>&1 || true)"
for s in meta-skill-loop meta-skill-feedback meta-skill-refine; do
  if grep -qF -- "$s" <<<"$out"; then ok "package lists $s"; else bad "package lists $s" "$out"; fi
done
# The README's install: one real folder in ~/.agents/skills, a link for Claude Code.
npx -y skills@latest add "$REPO" --skill '*' --agent cursor claude-code codex -g -y >/dev/null 2>&1
for s in meta-skill-loop meta-skill-feedback meta-skill-refine; do
  if [ -f "$HOME/.agents/skills/$s/SKILL.md" ] && [ ! -L "$HOME/.agents/skills/$s" ]; then ok "installed ~/.agents/skills/$s"; else bad "installed ~/.agents/skills/$s"; fi
  if [ -f "$HOME/.claude/skills/$s/SKILL.md" ]; then ok "Claude Code sees $s"; else bad "Claude Code sees $s"; fi
done

echo "first use from the installed skill"
bash "$HOME/.agents/skills/meta-skill-loop/scripts/msl" init >/dev/null
M="$HOME/.meta-skill-loop/bin/msl"
if [ -x "$M" ]; then ok "launcher created"; else bad "launcher created"; fi
if "$M" version >/dev/null; then ok "launcher runs msl"; else bad "launcher runs msl"; fi
out="$("$M" add meta-skill-feedback)"
if grep -qF "as v1" <<<"$out"; then ok "a skill installed by the CLI can be managed"; else bad "a skill installed by the CLI can be managed" "$out"; fi
if grep -qF "a link to it" <<<"$out" && ! grep -qF "msl link" <<<"$out"; then ok "the Claude Code link is recognized; nothing to link"; else bad "the Claude Code link is recognized; nothing to link" "$out"; fi
printf -- '- observed: test\n' | "$M" feedback add meta-skill-feedback -t test --tool ci >/dev/null
out="$("$M" status meta-skill-feedback)"
if grep -qE 'meta-skill-feedback +[a-z-]+ +v1 +1 ' <<<"$out"; then ok "feedback recorded"; else bad "feedback recorded" "$out"; fi

[ "$fail" = 0 ] && echo "package: ok"
exit "$fail"
