# meta-skill-loop

**Feedback and version history for your agent skills.** Log feedback on any skill while you use it, turn it into small improvements you approve, and keep every version, so you can compare, roll back, and take upstream updates without losing your changes. It works the same in **Cursor, Codex, and Claude Code**.

```
use a skill ──► "feedback on pr-review: too many style nits"      → feedback entry with evidence
"refine pr-review" ──► brief → proposed edit → you approve         → live edit
"keep it" ──► pr-review v4 (fixes fb-k3x9-012, -015)                → a version you can diff or roll back
"update pr-review" ──► new upstream merged with your v4, for review → v5, nothing lost
```

- **Your skills stay where they are.** Nothing is moved or symlinked, and **meta-skill-loop never edits a skill except to apply a change you approved.** Keep installing skills however you like (the [`skills` CLI](https://github.com/vercel-labs/skills), git, by hand, a skill creator).
- **Holds only its own data.** Feedback and versions live in `~/.meta-skill-loop/`, local to your machine.
- **Git under the hood.** Each managed skill gets a small git repo whose working tree is the skill's own folder. It has two branches: `upstream` (as published) and `mine` (what you run).
- **Portable by construction.** Plain `SKILL.md` skills (only `name` and `description` frontmatter), one bash script (`msl`, bash 3.2+), and git. No hooks, plugins, or tool-specific features.

## Install

```sh
npx skills add SoulEvill/meta-skill-loop -g --copy
```

That's the standard [`skills` CLI](https://github.com/vercel-labs/skills): pick Cursor, Codex, and/or Claude Code when it asks, or pass `-a cursor -a codex -a claude-code`. `--copy` matters for Cursor, which doesn't reliably load symlinked skills. There's no other setup: the first time you use one of the skills, it creates `~/.meta-skill-loop/`.

- **Update:** `npx skills update`. If you've refined meta-skill-loop's own skills, say "update meta-skill-loop" to merge the new version with your changes for review instead.
- **Pin a version (or try a branch):** add `#<tag or branch>`, e.g. `npx skills add "SoulEvill/meta-skill-loop#v0.2.0" -g --copy`.
- **No Node.js?** `git clone https://github.com/SoulEvill/meta-skill-loop && meta-skill-loop/install.sh` (add `--claude` for Claude Code) copies the same folders.
- **Privacy note:** the `skills` CLI sends anonymous usage stats; set `DO_NOT_TRACK=1` to turn that off.

**Recommended, once:** add this line to your agent's own rules, so it offers to log feedback when you correct a skill:

> When the user corrects how a skill behaved or gives feedback on a skill, offer to log it with the meta-skill-feedback skill.

Where to add it:
- Cursor: Settings > Rules > User Rules
- Codex: `~/.codex/AGENTS.md`
- Claude Code: `~/.claude/CLAUDE.md`

**Codex:** its sandbox blocks writes outside your project by default. Add the workspace to `~/.codex/config.toml`:

```toml
[sandbox_workspace_write]
writable_roots = ["/Users/you/.meta-skill-loop"]
```

## Use it

Talk to your agent:

| Say | What happens |
|---|---|
| "meta-skill-loop add" | lists skills you have that aren't managed yet, and adds the ones you pick (as v1) |
| "feedback on grill-me: it asks way too many questions" | logs an entry: what you asked, what happened, what you expected, evidence, and which version |
| "refine grill-me" | groups feedback into themes, proposes the smallest edit, and applies it after you approve |
| "keep it" / "undo that" | the edit becomes the next version, or is discarded (and can be redone) |
| "show versions of grill-me" / "compare v2 and v4" | history with the feedback each version fixed and received |
| "grill-me got worse, undo v4" / "go back to v2" | rollback, as a new version; the feedback those versions fixed is reopened |
| "is there an update for grilling?" | checks and shows what upstream changed; nothing changes |
| "update grilling" | fetches the new upstream version and merges it with your changes for review; your version stays live until you approve |
| "meta-skill-loop status" | versions, open feedback, and anything needing attention |

### The skills

| Skill | Job |
|---|---|
| `meta-skill-loop` | status, add, versions, rollback, updates, remove |
| `meta-skill-feedback` | capture one piece of feedback with evidence; never edits the skill |
| `meta-skill-refine` | feedback → brief → proposed edit → your approval → a new version |

### `msl` (what the skills call; you can too)

```
msl status [name]                 msl scan                    msl add <name|path>        msl remove <name>
msl feedback add <name> < body    msl feedback list <name>    msl feedback mark <id> <status>
msl diff <name> [vA [vB] | --upstream | --incoming | --merge | --saved]      msl history <name>
msl keep <name> -m <summary> [--fixes ids]          msl undo <name>            msl redo <name>
msl rollback <name> <vN> [--only]                   msl update <name> [--check | --apply | --abort | --take-upstream]
```

## How it thinks about skills

- **Where a skill comes from** is detected when you add it, by asking who else writes its folder:
  - `local`: only you.
  - `skills-cli`: `npx skills update` writes it; the lock file tells us the upstream version.
  - `git`: `git pull` and teammates write it; the repo history tells us.
- **States:**
  - `clean`: the folder is your current version.
  - `changed`: live edits not kept yet; they're saved automatically.
  - `upstream-update`: an installer or `git pull` put a new upstream version in place. Your version is safe; `msl update` merges.
  - `upstream-live`: an older upstream version was put back.
  - `copies-differ`: the same skill in several tool folders no longer matches.
  - `missing`: the folder is gone.
- **Feedback entries** are one file each, with ids like `fb-k3x9-012`: this workspace's id plus a sequence number. Frontmatter records:
  - `version`: the version the feedback was about;
  - `tool`, `project`, `severity`;
  - `origin`: `explicit`, or `observed` for future automatic capture;
  - `status`: `candidate`, `open`, `applied`, `declined`, or `resolved-upstream`.
- **Privacy.** Feedback can contain work details. The workspace is local; never push it anywhere public.

## Docs

Design, roadmap, and the latest session handoff live in [`docs/`](docs/): [design.md](docs/design.md) and [handoff.md](docs/handoff.md). The code is the source of truth; the docs may lag behind it.

## Develop

```sh
tests/run.sh                          # end-to-end, in a throwaway $HOME
TEST_BASH=/bin/bash tests/run.sh      # on macOS: check bash 3.2 compatibility
tests/lint-skills.sh                  # skills stay portable (Agent Skills format)
tests/package.sh                      # install with the real skills CLI (needs Node)
tests/agent/run.sh claude-code        # real agent end to end (needs an API key; costs model calls)
shellcheck install.sh tests/*.sh tests/agent/*.sh skills/meta-skill-loop/scripts/msl
```

Releases, CI, and repository settings: [docs/maintaining.md](docs/maintaining.md).

MIT licensed.
