#!/usr/bin/env bash
# Fallback installer for machines without Node.js. The recommended install is:
#
#   npx skills add SoulEvill/meta-skill-loop -g --copy
#
# This script does the same with plain file copies:
#
#   ./install.sh              Cursor + Codex  (~/.agents/skills)
#   ./install.sh --claude     also Claude Code (~/.claude/skills)
#   ./install.sh --target DIR any other skills folder (repeatable)
#
# Re-running it overwrites the installed copies. If you manage meta-skill-loop's own
# skills and refined them, meta-skill-loop reports the overwrite and can restore your
# version (msl status). Reviewed upstream updates need the npx install.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd -P)"
RULE='When the user corrects how a skill behaved or gives feedback on a skill, offer to log it with the meta-skill-feedback skill.'

targets="$HOME/.agents/skills"
while [ $# -gt 0 ]; do
  case "$1" in
    --claude) targets="$targets
$HOME/.claude/skills" ;;
    --target) targets="$targets
${2:?--target needs a directory}"; shift ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

while IFS= read -r t; do
  [ -n "$t" ] || continue
  for skill_dir in "$REPO"/skills/*/; do
    skill_dir="${skill_dir%/}"
    name="$(basename "$skill_dir")"
    mkdir -p "$t"
    rm -rf "${t:?}/$name"
    cp -R "$skill_dir" "$t/$name"
  done
  echo "installed meta-skill-loop skills -> $t"
done <<EOF
$targets
EOF

# Set up the workspace from the installed copy, so ~/.meta-skill-loop/bin/msl
# launches the installed skill (not this clone).
bash "$HOME/.agents/skills/meta-skill-loop/scripts/msl" init >/dev/null

cat <<EOF

Done. In Cursor, Codex, or Claude Code, say "meta-skill-loop add" to bring in your skills.

Recommended, once: add this line to your agent's own rules, so it offers to log
feedback when you correct a skill:

  $RULE

  Cursor: Settings > Rules > User Rules   Codex: ~/.codex/AGENTS.md   Claude Code: ~/.claude/CLAUDE.md
EOF
