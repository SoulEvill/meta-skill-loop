#!/usr/bin/env bash
# Install meta-skill-loop: copy its skills into your agent tools' skill folders and
# create the workspace (~/.meta-skill-loop). Re-run it to update.
#
#   ./install.sh              Cursor + Codex  (~/.agents/skills)
#   ./install.sh --claude     also Claude Code (~/.claude/skills)
#   ./install.sh --target DIR any other skills folder (repeatable)
#
# Skills are copied, not symlinked: Cursor does not reliably discover symlinked skills.
# meta-skill-loop manages its own skills like any other, so if you refined one of
# them, an update is merged for your review instead of overwriting your version.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd -P)"
SOURCE_URL="https://github.com/SoulEvill/meta-skill-loop"
MSL_HOME="${MSL_HOME:-$HOME/.meta-skill-loop}"
export MSL_HOME
REV="$(git -C "$REPO" rev-parse --short=12 HEAD 2>/dev/null || echo local)"
RULE='When the user corrects how a skill behaved or gives feedback on a skill, offer to log it with the meta-skill-feedback skill.'

targets="$HOME/.agents/skills"
claude=0
while [ $# -gt 0 ]; do
  case "$1" in
    --claude) claude=1; targets="$targets
$HOME/.claude/skills" ;;
    --target) targets="$targets
${2:?--target needs a directory}"; shift ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

"$REPO/skills/meta-skill-loop/scripts/msl" init >/dev/null
MSL="$MSL_HOME/bin/msl"

for skill_dir in "$REPO"/skills/*/; do
  skill_dir="${skill_dir%/}"
  name="$(basename "$skill_dir")"
  primary="$HOME/.agents/skills/$name"

  if [ ! -f "$MSL_HOME/skills/$name/skill.yaml" ]; then
    # First install: copy everywhere, then manage it (its upstream is this repo).
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      mkdir -p "$t"
      rm -rf "${t:?}/$name"
      cp -R "$skill_dir" "$t/$name"
      chmod +x "$t/$name/scripts/"* 2>/dev/null || true
    done <<EOF
$targets
EOF
    "$MSL" add "$primary" --kind framework --source "$SOURCE_URL" --rev "$REV" >/dev/null
    echo "installed $name"
    continue
  fi

  # Update: record this repo's version as upstream, then merge it into yours.
  "$MSL" import-upstream "$name" "$skill_dir" "$REV" >/dev/null
  "$MSL" update "$name" --ff-only 2>&1 | sed 's/^/  /' || echo "  could not update $name; run: msl status $name"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if [ ! -d "$t/$name" ]; then
      mkdir -p "$t"
      cp -R "$("$MSL" path "$name")" "$t/$name"
      chmod +x "$t/$name/scripts/"* 2>/dev/null || true
      "$MSL" add-path "$name" "$t/$name"
      echo "  also installed $name -> $t/$name"
    fi
  done <<EOF
$targets
EOF
done

cat <<EOF

meta-skill-loop is installed. Workspace: $MSL_HOME

Next, in Cursor, Codex, or Claude Code, say:
  "meta-skill-loop add"        bring in the skills you already have
  "feedback on <skill>: ..."   log feedback whenever a skill misbehaves
  "refine <skill>"             turn feedback into an improvement you approve
  "meta-skill-loop status"     versions, open feedback, and anything needing attention

Recommended, once: add this line to your agent's own rules so it offers to log
feedback when you correct a skill (meta-skill-loop never edits your skills for this):

  $RULE

  Cursor:      Settings > Rules > User Rules
  Codex:       ~/.codex/AGENTS.md
  Claude Code: ~/.claude/CLAUDE.md

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
