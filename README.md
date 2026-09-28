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
- **No Node.js?** Copy the folders yourself: `git clone https://github.com/SoulEvill/meta-skill-loop && mkdir -p ~/.agents/skills && cp -R meta-skill-loop/skills/* ~/.agents/skills/` (for Claude Code, also copy them to `~/.claude/skills/`).
- **Fewer prompts:** the skills run one script, `~/.meta-skill-loop/bin/msl`. Allow it once in your tool (in Cursor, add it to the command allowlist; in Claude Code, allow `Bash(~/.meta-skill-loop/bin/msl:*)`), so it doesn't ask every time.
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
| "meta-skill-loop add" | lists skills you have that aren't managed yet, and adds the ones you pick (as v1); offers to link copies in other tool folders to one folder |
| "feedback on grill-me: it asks way too many questions" / "record this" | logs an entry: a title, severity, what you asked, what happened, what you expected, evidence, the version, and a copy of the conversation |
| "refine grill-me" | groups feedback into themes, proposes the smallest edit, and applies it after you approve |
| "keep it" / "discard it" | the edit becomes the next version, or is thrown away (saved, so it can be restored) |
| "show versions of grill-me" / "compare v2 and v4" | history with the feedback each version fixed and received |
| "grill-me got worse, undo v4" / "go back to v2" | revert one version, or roll back to one, as a new version; the feedback those versions fixed is reopened |
| "is there an update for grilling?" | checks and shows what upstream changed; nothing live changes |
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
msl status [name]                  msl add [name|path]         msl link <name>          msl remove <name>
msl feedback add <name> -t <title> [--severity P0|P1|P2|P3|nit] < body
msl feedback list <name> [--all]   msl feedback mark <id> open|applied|declined [--fixed-in vN]
msl diff <name> [vA [vB] | --upstream | --merge | --saved]      msl history <name>
msl keep <name> -m <summary> [--fixes ids]    msl discard <name>    msl restore <name>
msl revert <name> <vN>             msl rollback <name> <vN>
msl update <name> [--check | --apply | --abort | --take-upstream]
```

`msl help` has every option.

## How it thinks about skills

- **One folder per skill.** A skill installed for several tools (say `~/.agents/skills` and `~/.claude/skills`) is managed as its one real folder, preferably the one in `~/.agents/skills`, which Cursor and Codex read directly. The other tool folders should link to it, so an edit reaches every tool. `msl link` does that for you, with your approval; a separate copy it replaces is set aside, never deleted.
- **Two kinds of skill**, detected when you add it:
  - `skills-cli`: installed with the `skills` CLI. It has published upstream versions, and `msl update` merges them with your refinements for review.
  - `local`: everything else: your own skills, and skills inside a git repo. Whatever changes the folder (you, a skill creator, a `git pull`) shows up as live edits you keep or discard.
- **States:**
  - `clean`: the folder is your current version.
  - `changed`: live edits not kept yet; they're saved automatically.
  - `upstream`: an installer (`npx skills update`, a reinstall) replaced your version in the folder. Your version is safe; `msl update` takes it from there.
  - `missing`: the folder is gone.
- **Feedback entries** are one Markdown file each, with ids like `fb-k3x9a2-012`: this workspace's id plus a sequence number. The header records the title, the version the feedback was about, when, the tool, a pointer to the saved conversation, the severity (`P0` harmful, `P1` wrong result, `P2` worked badly, `P3` minor, `nit`), the status (`open`, `applied`, `declined`), and `fixed_in` (the version that fixed it). The body is free-form: usually what was asked, observed, and expected, what the user said, and evidence. The full format is in [design.md](docs/design.md#5-data-model).
- **Conversations.** In Claude Code, a copy of the current conversation is saved in `~/.meta-skill-loop/sessions/` with the feedback, since tools delete old ones. msl only copies a conversation it can identify for certain, so in Cursor and Codex the entry itself carries the relevant exchanges (or the agent passes `--session <file>`).
- **Privacy.** Feedback and conversation copies can contain work details. The workspace is local; never push it anywhere public.

## Good to know

- **Skills that live in a git repo** (a team repo's `.cursor/skills`): git stays in charge of the repo. meta-skill-loop keeps your feedback and versions; what a `git pull` brings shows up as live edits to keep. Your refinements are uncommitted changes in that repo, so for a team skill, send the change to the repo.
- **`npx skills update` and links.** The `skills` CLI's `update` has no `--copy` option: it reinstalls the Claude Code copy as a link to `~/.agents/skills`, which is the layout meta-skill-loop wants anyway.
- **Two different skills with the same name** (say, your personal `pr-review` and a project's own): only one can be managed under that name. The other is left untouched, and `add` tells you how to switch.
- **Your data** is plain folders in `~/.meta-skill-loop` (feedback files, conversation copies, and a small git repo per skill). Back it up like any folder. It stays on your machine. Conversation copies are the bulk of it; delete old ones in `sessions/` if it grows.
- **Uninstall:** `npx skills remove meta-skill-loop meta-skill-feedback meta-skill-refine -g`. Your skills are untouched either way. Deleting `~/.meta-skill-loop` also deletes your feedback and version history.
- **Windows:** use WSL or Git Bash (meta-skill-loop needs bash and git).

## Docs

Design, roadmap, and the latest session handoff live in [`docs/`](docs/): [design.md](docs/design.md) and [handoff.md](docs/handoff.md). The code is the source of truth; the docs may lag behind it.

## Develop

```sh
tests/run.sh                          # end-to-end, in a throwaway $HOME
TEST_BASH=/bin/bash tests/run.sh      # on macOS: check bash 3.2 compatibility
tests/lint-skills.sh                  # skills stay portable (Agent Skills format)
tests/package.sh                      # install with the real skills CLI (needs Node)
tests/agent/run.sh claude-code        # real agent end to end (needs an API key; costs model calls)
shellcheck tests/*.sh tests/agent/*.sh skills/meta-skill-loop/scripts/msl
```

Releases, CI, and repository settings: [docs/maintaining.md](docs/maintaining.md).

MIT licensed.
