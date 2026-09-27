#!/usr/bin/env bash
# Install meta-skill-loop: copy its skills into your agent tools' skill folders and
# create the workspace (~/.meta-skill-loop). Safe to re-run to update.
#
#   ./install.sh              Cursor + Codex  (~/.agents/skills)
#   ./install.sh --claude     also Claude Code (~/.claude/skills)
#   ./install.sh --target DIR any other skills folder (repeatable)
#
# Skills are copied, not symlinked: Cursor does not reliably discover symlinked skills.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd -P)"
SOURCE_URL="https://github.com/SoulEvill/meta-skill-loop"
MSL_HOME="${MSL_HOME:-$HOME/.meta-skill-loop}"
export MSL_HOME

targets="$HOME/.agents/skills"
claude=0
while [ $# -gt 0 ]; do
  case "$1" in
    --claude) claude=1; targets="$targets
$HOME/.claude/skills" ;;
    --target) targets="$targets
${2:?--target needs a directory}"; shift ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

MSL="$REPO/skills/meta-skill-loop/scripts/msl"
"$MSL" init >/dev/null
MSL="$MSL_HOME/bin/msl"

for skill_dir in "$REPO"/skills/*/; do
  skill_dir="${skill_dir%/}"
  name="$(basename "$skill_dir")"
  managed=0
  [ -f "$MSL_HOME/skills/$name/skill.yaml" ] && managed=1
  if [ "$managed" = 1 ] && "$MSL" diverged "$name"; then
    echo "skip $name: you have local refinements; not overwriting (update merging arrives in v2)"
    continue
  fi
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    mkdir -p "$t"
    rm -rf "${t:?}/$name"
    cp -R "$skill_dir" "$t/$name"
    chmod +x "$t/$name/scripts/"* 2>/dev/null || true
    echo "installed $name -> $t/$name"
  done <<EOF
$targets
EOF
  if [ "$managed" = 1 ]; then
    if [ "$("$MSL" hash "$HOME/.agents/skills/$name")" != "$("$MSL" hash "$MSL_HOME/skills/$name/current")" ]; then
      "$MSL" commit "$name" -m "updated by install.sh" --base >/dev/null
    fi
  else
    "$MSL" add "$HOME/.agents/skills/$name" --upstream --source "$SOURCE_URL" --no-nudge >/dev/null
  fi
done

cat <<EOF

meta-skill-loop is installed. Workspace: $MSL_HOME

Next, in Cursor, Codex, or Claude Code, say:
  "meta-skill-loop status"     see managed skills
  "meta-skill-loop add"        bring in the skills you already have
  "feedback on <skill>: ..."   log feedback any time a skill misbehaves
  "refine <skill>"             turn feedback into an improvement

Optional: put msl on your PATH:  ln -s "$MSL_HOME/bin/msl" /usr/local/bin/msl
EOF

if [ "$claude" = 0 ] && [ -d "$HOME/.claude" ]; then
  echo
  echo "Claude Code detected: re-run with --claude to install the skills there too."
fi
if [ -d "$HOME/.codex" ]; then
  cat <<EOF

Codex: its sandbox blocks writes outside your project by default. To let skills log
feedback, add this to ~/.codex/config.toml:
  [sandbox_workspace_write]
  writable_roots = ["$MSL_HOME"]
EOF
fi
