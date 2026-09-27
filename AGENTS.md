# Working on meta-skill-loop

This repo is the public source of meta-skill-loop: three agent skills plus `msl`, the bash script they call. Read `docs/design.md` before changing behavior.

## Layout

- `skills/<name>/SKILL.md`: the skills. Frontmatter is **only** `name` and `description`, the subset Cursor, Codex, and Claude Code all honor. No tool-specific syntax (no `!command` injection, no `${CLAUDE_*}` variables, no hooks).
- `skills/meta-skill-loop/scripts/msl`: all mechanical work. It ships inside the hub skill so installs via the `skills` CLI carry it; `msl init` copies it to `~/.meta-skill-loop/bin/msl`, the path the skills use.
- `install.sh`: copies skills into tool folders (copy, never symlink: Cursor's symlink discovery is unreliable) and registers them.
- `tests/run.sh`: end-to-end tests in a throwaway `$HOME`.

## Rules

- **Bash 3.2 compatible** (macOS default): no associative arrays, `mapfile`, `${x,,}`, `|&`, or `readarray`. Avoid GNU-only flags: no `sed -i`, use `sha256sum` or `shasum -a 256`, and `find`/`sort`/`date` flags that BSD supports.
- **Zero dependencies** beyond POSIX tools and git. `node` is optional and only used to read the `skills` CLI lock file.
- Under `set -euo pipefail`, guard pipelines that can legitimately find nothing (`grep … || true`), and avoid `head` on pipes (SIGPIPE); use `sed -n 1p`.
- Never move or delete a user's skill folder. meta-skill-loop manages skills in place; the only in-place edits are the nudge line and approved refinements.
- The skill texts are the product. Keep them short and imperative, and make them work in every tool.
- Every behavior change gets a test in `tests/run.sh`. Before pushing, run `tests/run.sh`, `shellcheck install.sh tests/run.sh skills/meta-skill-loop/scripts/msl`, and, if you can, `TEST_BASH=/bin/bash tests/run.sh` on macOS.
