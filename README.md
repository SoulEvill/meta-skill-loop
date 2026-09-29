# meta-skill-loop

Your agent skills get better as you use them.

When a skill gets something wrong, ask your agent to log it, and meta-skill-loop saves
it as feedback. When you're ready, ask it to refine the skill: it proposes a small edit
based on that feedback and applies it only if you approve. Every version is kept, so you
can always go back.

Works in Cursor, Claude Code, and Codex.

## Install

```sh
npx skills@latest add SoulEvill/meta-skill-loop --skill meta-skill-loop \
  --agent cursor claude-code codex -g
```

This installs it for all three tools, in every project. For Cursor only, use
`--agent cursor`. It needs Node.js, Git, and bash (macOS, Linux, or WSL on Windows).

There is nothing else to set up: the first time you use it, your agent creates
`~/.meta-skill-loop`. The first few times, your tool may ask before running `msl`, the
script it uses; allow it.

## Use

Ask your agent in plain words, as below. To be sure it uses meta-skill-loop, start with
`/meta-skill-loop` (Cursor, Claude Code) or `$meta-skill-loop` (Codex).

1. **Use your skills as usual.** When one gets something wrong, ask to log it:
   "log feedback on pr-review: it buried the real bug under style nits."
   It's logged only when you ask.
2. **Refine when you're ready:** "refine pr-review". Your agent shows the edit it would
   make. Approve it, and it becomes the skill's next version.
3. **Go back if it got worse:** "undo that change to pr-review", or "go back to v2".

You can also ask:

| Say | What happens |
| --- | --- |
| "meta-skill-loop status" | Your skills, their versions, and open feedback. |
| "show versions of pr-review" | Each version, what changed, and the feedback it fixed. |
| "update pr-review" | For a skill you installed with `npx skills`: takes its author's new version and keeps your edits. You review it first. |
| "send this upstream" | Offers your change to the skill's author as a GitHub issue (or a pull request, if you ask). You approve the exact text first. |

## Good to know

- **Your skills stay where they are.** Nothing changes without your approval.
- **Everything stays on your machine**, in `~/.meta-skill-loop`. Feedback can include
  work details, so keep that folder private.
- **Update:** `npx skills@latest update -g`.
- **Uninstall:** `npx skills@latest remove meta-skill-loop -g`.
  Your feedback and versions stay in `~/.meta-skill-loop` until you delete it.
- **Upgrading from 0.2** (three skills): remove the two old ones,
  `npx skills@latest remove meta-skill-feedback meta-skill-refine -g`, and, if you added
  it, the line that mentions meta-skill-feedback from your agent's rules (Cursor User
  Rules, `~/.claude/CLAUDE.md`, or `~/.codex/AGENTS.md`). An allow rule for
  `~/.meta-skill-loop/bin/msl` no longer applies: the skill now runs its own
  `scripts/msl`, and your tool asks once for that instead.

How it works: [docs/design.md](docs/design.md). Contributing: [AGENTS.md](AGENTS.md).

[MIT](LICENSE).
