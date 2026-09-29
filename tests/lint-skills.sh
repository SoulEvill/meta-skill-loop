#!/usr/bin/env bash
# Keep every skill portable across Cursor, Codex, and Claude Code (Agent Skills format):
# frontmatter is only `name` and `description`, the name matches its folder and the
# spec's rules, and the body uses no tool-specific syntax.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
fail=0
bad() { printf 'FAIL %s: %s\n' "$1" "$2"; fail=1; }

for f in "$REPO"/skills/*/SKILL.md; do
  dir="$(basename "$(dirname "$f")")"
  [ "$(sed -n 1p "$f")" = "---" ] || { bad "$dir" "must start with a --- frontmatter block"; continue; }
  fm="$(awk 'NR == 1 { next } $0 == "---" { exit } { print }' "$f")"
  keys="$(printf '%s\n' "$fm" | grep -E '^[A-Za-z_-]+:' | cut -d: -f1 | sort | tr '\n' ' ')"
  [ "$keys" = "description name " ] || bad "$dir" "frontmatter keys must be exactly name and description (found: $keys)"
  name="$(printf '%s\n' "$fm" | sed -n 's/^name: *//p')"
  desc="$(printf '%s\n' "$fm" | sed -n 's/^description: *//p')"
  [ "$name" = "$dir" ] || bad "$dir" "name '$name' must match the folder name"
  grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' <<<"$name" || bad "$dir" "name must be lowercase letters, digits, and single hyphens"
  [ "${#name}" -le 64 ] || bad "$dir" "name longer than 64 characters"
  [ -n "$desc" ] || bad "$dir" "description is empty"
  [ "${#desc}" -le 1024 ] || bad "$dir" "description longer than 1024 characters (${#desc})"
  # Plain YAML scalars can't contain ": " or " #"; the skills CLI skips a skill whose frontmatter doesn't parse.
  case "$desc" in
    \"*\"|\'*\') ;;                                        # quoted
    '>'|'|'|'>'[-+0-9]*|'|'[-+0-9]*) ;;                    # a block scalar (text on the next lines)
    \"*|\'*|'>'*|'|'*|*": "*|*" #"*|*:|'#'*|,*|'- '*|'? '*|[][{}*\&!%@\`]*)
      bad "$dir" "description isn't a valid plain YAML scalar (': ', ' #', a trailing ':', or a leading quote, [{*&!%@#,|> or backtick); quote it" ;;
  esac
  # shellcheck disable=SC2016  # the pattern is literal on purpose
  if grep -nE '!`|\$\{CLAUDE_|\$ARGUMENTS|allowed-tools' "$f" >/dev/null; then
    bad "$dir" "uses tool-specific syntax (!\`cmd\`, \${CLAUDE_*}, \$ARGUMENTS, allowed-tools)"
  fi
done

n=0; for f in "$REPO"/skills/*/SKILL.md; do n=$((n + 1)); done
if [ "$fail" = 0 ]; then echo "skills lint: ok ($n skills)"; fi
exit "$fail"
