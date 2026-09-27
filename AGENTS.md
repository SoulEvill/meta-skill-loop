# Working on meta-skill-loop

This repo is the public source of meta-skill-loop: three agent skills plus `msl`, the bash script they call. Start every session by reading `docs/handoff.md` (where things stand, what's decided, what's next), then `docs/design.md` before changing behavior. The code is the source of truth; if the docs disagree with it, trust the code and fix the docs. At the end of a session, rewrite `docs/handoff.md` for the next one.

## Layout

- `skills/<name>/SKILL.md`: the skills. Frontmatter is **only** `name` and `description`, the subset Cursor, Codex, and Claude Code all honor. No tool-specific syntax (no `!command` injection, no `${CLAUDE_*}` variables, no hooks).
- `skills/meta-skill-loop/scripts/msl`: all mechanical work (per-skill git repos in the workspace; see design.md §5). It ships inside the hub skill so installs via the `skills` CLI carry it; `msl init` copies it to `~/.meta-skill-loop/bin/msl`, the path the skills use.
- `install.sh`: copies skills into tool folders (copy, never symlink: Cursor's symlink discovery is unreliable) and registers them.
- `tests/run.sh`: end-to-end tests in a throwaway `$HOME`.

## Rules

- **Bash 3.2 compatible** (macOS default): no associative arrays, `mapfile`, `${x,,}`, `|&`, or `readarray`. Avoid GNU-only flags: no `sed -i`, use `sha256sum` or `shasum -a 256`, and `find`/`sort`/`date` flags that BSD supports.
- **Zero dependencies** beyond POSIX tools and git. `node` is optional and only used to read the `skills` CLI lock file.
- Under `set -euo pipefail`, guard pipelines that can legitimately find nothing (`grep … || true`). Never end a pipe in something that exits early: no `head` (use `sed -n 1p`) and no `grep -q` (use `grep … >/dev/null`), or the writer gets SIGPIPE and the check fails at random.
- Never move or delete a user's skill folder. meta-skill-loop manages skills in place and never edits one except to apply a change the user approved (refine, keep, rollback, update).
- The skill texts are the product. Keep them short and imperative, and make them work in every tool.
- Every behavior change gets a test in `tests/run.sh`. Before pushing, run `tests/run.sh`, `shellcheck install.sh tests/run.sh skills/meta-skill-loop/scripts/msl`, and, if you can, `TEST_BASH=/bin/bash tests/run.sh` on macOS.
