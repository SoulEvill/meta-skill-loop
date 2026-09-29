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
  # The spec's fields every tool accepts: name and description (required), and license,
  # compatibility, metadata (optional). Tool-specific fields (allowed-tools, paths, …) vary.
  keys="$(printf '%s\n' "$fm" | grep -E '^[A-Za-z_-]+:' | cut -d: -f1 | sort | tr '\n' ' ')"
  case " $keys" in *" description "*" name "*) ;; *) bad "$dir" "frontmatter needs name and description (found: $keys)" ;; esac
  for k in $keys; do
    case "$k" in name|description|license|compatibility|metadata) ;; *) bad "$dir" "frontmatter field '$k' isn't in the Agent Skills spec's portable set (name, description, license, compatibility, metadata)" ;; esac
  done
  name="$(printf '%s\n' "$fm" | sed -n 's/^name: *//p')"
  desc="$(printf '%s\n' "$fm" | sed -n 's/^description: *//p')"
  [ "$name" = "$dir" ] || bad "$dir" "name '$name' must match the folder name"
  grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' <<<"$name" || bad "$dir" "name must be lowercase letters, digits, and single hyphens"
  [ "${#name}" -le 64 ] || bad "$dir" "name longer than 64 characters"
  [ -n "$desc" ] || bad "$dir" "description is empty"
  [ "${#desc}" -le 1024 ] || bad "$dir" "description longer than 1024 characters (${#desc})"
  compat="$(printf '%s\n' "$fm" | sed -n 's/^compatibility: *//p')"
  [ "${#compat}" -le 500 ] || bad "$dir" "compatibility longer than 500 characters (${#compat})"
  # Plain YAML scalars can't contain ": " or " #"; the skills CLI skips a skill whose frontmatter doesn't parse.
  for field in description compatibility license; do
    v="$(printf '%s\n' "$fm" | sed -n "s/^$field: *//p")"
    [ -n "$v" ] || continue
    case "$v" in
      \"*\"|\'*\') ;;                                        # quoted
      '>'|'|'|'>'[-+0-9]*|'|'[-+0-9]*) ;;                    # a block scalar (text on the next lines)
      \"*|\'*|'>'*|'|'*|*": "*|*" #"*|*:|'#'*|,*|'- '*|'? '*|[][{}*\&!%@\`]*)
        bad "$dir" "$field isn't a valid plain YAML scalar (': ', ' #', a trailing ':', or a leading quote, [{*&!%@#,|> or backtick); quote it" ;;
    esac
  done
  # shellcheck disable=SC2016  # the pattern is literal on purpose
  if grep -nE '!`|\$\{CLAUDE_|\$ARGUMENTS|allowed-tools' "$f" >/dev/null; then
    bad "$dir" "uses tool-specific syntax (!\`cmd\`, \${CLAUDE_*}, \$ARGUMENTS, allowed-tools)"
  fi
done

n=0; for f in "$REPO"/skills/*/SKILL.md; do n=$((n + 1)); done
if [ "$fail" = 0 ]; then echo "skills lint: ok ($n skills)"; fi
exit "$fail"
