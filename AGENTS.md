# Working on meta-skill-loop

This repo is the public source of meta-skill-loop: one agent skill, and `msl`, the bash script it calls. Start every session by reading `docs/handoff.md` (where things stand, what's decided, what's next), then `docs/design.md` before changing behavior. The code is the source of truth; if the docs disagree with it, trust the code and fix the docs. At the end of a session, rewrite `docs/handoff.md` for the next one.

## Layout

- `skills/meta-skill-loop/`: the one skill. `SKILL.md` is the entry point (status, add, versions, updates) and sends the agent to `references/feedback.md` or `references/refine.md` for those two workflows. Frontmatter is **only** `name` and `description`, the subset Cursor, Codex, and Claude Code all honor. No tool-specific syntax (no `!command` injection, no `${CLAUDE_*}` variables, no hooks).
- `skills/meta-skill-loop/scripts/msl`: all mechanical work (per-skill git repos in the workspace; see design.md §5). It ships inside the skill, so the package is self-contained; `msl init` writes `~/.meta-skill-loop/bin/msl`, a launcher into the installed skill, which is the path the skill uses.
- Install is `npx skills@latest add SoulEvill/meta-skill-loop --skill meta-skill-loop --agent cursor claude-code codex -g` (the README's command). The skills CLI keeps the real folder in `~/.agents/skills` and links Claude Code's to it, which is meta-skill-loop's one-folder model. There is no installer script: first use runs `msl init`. Feedback is logged only when the user asks for it (automatic capture is a later, opt-in feature: design.md §8), so there is nothing to set up in the tools. The README stays short: install, the three-step loop, and a few facts; details belong in the skill and docs.
- `tests/run.sh`: end-to-end tests in a throwaway `$HOME`. `tests/lint-skills.sh`: the skill stays portable (and its frontmatter parses). `tests/package.sh`: real `skills` CLI install. `tests/agent/run.sh <agent>`: real-agent tests (manual; needs a key).
- `.github/workflows/`: `ci` (every push/PR), `release` (on `v*` tags), `agent-tests` (manual, owner only). See `docs/maintaining.md`.

## Rules

- **Bash 3.2 compatible** (macOS default): no associative arrays, `mapfile`, `${x,,}`, `|&`, or `readarray`. Avoid GNU-only flags: no `sed -i`, use `sha256sum` or `shasum -a 256`, and `find`/`sort`/`date` flags that BSD supports.
- **Zero dependencies** beyond POSIX tools and git. `node` is optional and only used to read the `skills` CLI lock file.
- Under `set -euo pipefail`, guard pipelines that can legitimately find nothing (`grep … || true`). Never end a pipe in something that exits early: no `head` (use `sed -n 1p`) and no `grep -q` (use `grep … >/dev/null`), or the writer gets SIGPIPE and the check fails at random.
- Never move or delete a user's skill folder. meta-skill-loop manages skills in place and never edits one except to apply a change the user approved (refine, keep, rollback, update).
- The skill texts are the product. Keep them short and imperative, and make them work in every tool.
- Every behavior change gets a test in `tests/run.sh`. Before pushing, run `tests/run.sh` (check its exit status, not a piped tail), `tests/lint-skills.sh`, `shellcheck tests/*.sh tests/agent/*.sh skills/meta-skill-loop/scripts/msl`, and, if you can, `TEST_BASH=/bin/bash tests/run.sh` on macOS. Skill texts changed? Also run `tests/agent/run.sh claude-code` if you have a key.
