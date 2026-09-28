# meta-skill-loop

Feedback and version history for your agent skills. Log feedback on any skill while
you use it, turn it into small improvements you approve, and keep every version, so
you can compare, roll back, and take upstream updates without losing your changes.
Works in Cursor, Claude Code, and Codex.

## Install

Requires Node.js/npm, Git, and bash (macOS or Linux; on Windows, WSL or Git Bash).

For Cursor, available across your projects:

```sh
npx skills@latest add SoulEvill/meta-skill-loop --skill '*' --agent cursor -g
```

For Cursor, Claude Code, and Codex together:

```sh
npx skills@latest add SoulEvill/meta-skill-loop --skill '*' \
  --agent cursor claude-code codex -g
```

This installs three skills with the [skills CLI](https://github.com/vercel-labs/skills).
There is no other setup: the first time you use one, it creates `~/.meta-skill-loop/`.
To update later:

```sh
npx skills@latest update -g
```

**Recommended, once.** Add this line to your agent's own rules, so it offers to log
feedback when you correct a skill:

> When the user corrects how a skill behaved or gives feedback on a skill, offer to log it with the meta-skill-feedback skill.

Cursor: Settings > Rules > User Rules. Claude Code: `~/.claude/CLAUDE.md`.
Codex: `~/.codex/AGENTS.md`.

**Codex only.** Its sandbox blocks writes outside your project. Allow the workspace in
`~/.codex/config.toml`:

```toml
[sandbox_workspace_write]
writable_roots = ["/Users/you/.meta-skill-loop"]
```

## Use it

Talk to your agent:

| Say | What happens |
| --- | --- |
| "meta-skill-loop add" | Lists your skills that aren't managed yet and adds the ones you pick as v1. |
| "feedback on grill-me: too many questions" | Logs an entry with a title, severity, what happened, what you expected, and evidence. |
| "refine grill-me" | Groups the feedback, proposes the smallest edit, and applies it after you approve. |
| "keep it" / "discard it" | The edit becomes the next version, or is thrown away (and can be restored). |
| "show versions of grill-me" | History, with the feedback each version fixed and received. |
| "undo v4" / "go back to v2" | Reverts one version or rolls back to one, as a new version. |
| "is there an update for grilling?" | Shows what upstream changed. Nothing changes until you take it. |
| "update grilling" | Merges the new upstream version with your changes, for you to review. |
| "meta-skill-loop status" | Versions, open feedback, and anything that needs attention. |

| Skill | What it does |
| --- | --- |
| [meta-skill-loop](skills/meta-skill-loop/SKILL.md) | Status, add, versions, rollback, updates. |
| [meta-skill-feedback](skills/meta-skill-feedback/SKILL.md) | Captures one piece of feedback with evidence. Never edits the skill. |
| [meta-skill-refine](skills/meta-skill-refine/SKILL.md) | Turns feedback into a proposed edit and, once you approve, a new version. |

The skills run one script, `~/.meta-skill-loop/bin/msl`. Allow it once in your tool
so it doesn't ask every time (in Claude Code: `Bash(~/.meta-skill-loop/bin/msl:*)`).
`msl help` lists its commands.

## How it works

- **Your skills stay where they are.** meta-skill-loop never edits a skill except to
  apply a change you approved.
- **One folder per skill.** The skills CLI keeps the real folder in `~/.agents/skills`
  (read by Cursor and Codex) and links the Claude Code copy to it. If a skill has
  separate copies in several tool folders, meta-skill-loop offers to link them
  (`msl link`), setting the copies aside, never deleting them.
- **Versions are git commits** in a small repo per skill, kept in
  `~/.meta-skill-loop/`. Skills installed with the skills CLI also track the
  published versions, so updates are merged with your changes instead of replacing them.
- **Feedback is one Markdown file per entry**, with a title, severity (`P0` to `P3`,
  `nit`), status, and the version it was about. In Claude Code, a copy of the
  conversation is kept with it.
- **Everything stays on your machine.** Feedback can contain work details; don't push
  `~/.meta-skill-loop` anywhere public.

## Good to know

- **Skills inside a git repo** (a team repo's `.cursor/skills`) are managed like your
  own. Git stays in charge of the repo; what a `git pull` brings shows up as a change to
  keep. For a team skill, send your change to the repo.
- **Two different skills with the same name:** only one can be managed under that
  name. `add` tells you, and never touches the other.
- **Uninstall:** `npx skills@latest remove meta-skill-loop meta-skill-feedback meta-skill-refine -g`.
  Your skills are untouched. Deleting `~/.meta-skill-loop` also deletes your feedback
  and history.

## Develop

```sh
tests/run.sh                          # end-to-end, in a throwaway $HOME
TEST_BASH=/bin/bash tests/run.sh      # on macOS: bash 3.2 compatibility
tests/lint-skills.sh                  # skills stay portable
tests/package.sh                      # install with the real skills CLI (needs network)
tests/agent/run.sh claude-code        # real agent end to end (needs an API key)
shellcheck tests/*.sh tests/agent/*.sh skills/meta-skill-loop/scripts/msl
```

Design and roadmap: [docs/design.md](docs/design.md). Current state:
[docs/handoff.md](docs/handoff.md). Releases, CI, and repository settings:
[docs/maintaining.md](docs/maintaining.md).

[MIT](LICENSE).
