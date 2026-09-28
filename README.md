# meta-skill-loop

Your agent skills get better as you use them.

When a skill gets something wrong, tell your agent, and meta-skill-loop saves it as
feedback. When you're ready, ask it to refine the skill: it proposes a small edit based
on that feedback and applies it only if you approve. Every version is kept, so you can
always go back.

Works in Cursor, Claude Code, and Codex.

## Install

```sh
npx skills@latest add SoulEvill/meta-skill-loop --skill '*' \
  --agent cursor claude-code codex -g
```

This installs it for all three tools, in every project. For Cursor only, use
`--agent cursor`. It needs Node.js, Git, and bash (macOS, Linux, or WSL on Windows).

The first time you use it, your agent sets it up and offers two optional settings:
offering to log feedback whenever you correct a skill, and not asking permission every
time it runs.

## Use

1. **Use your skills as usual.** When one gets something wrong, say so:
   "feedback on pr-review: it buried the real bug under style nits."
2. **Refine when you're ready:** "refine pr-review". Your agent shows the edit it would
   make. Approve it, and it becomes the skill's next version.
3. **Go back if it got worse:** "undo that change to pr-review", or "go back to v2".

You can also ask:

| Say | What happens |
| --- | --- |
| "meta-skill-loop status" | Your skills, their versions, and open feedback. |
| "show versions of pr-review" | Each version, what changed, and the feedback it fixed. |
| "update pr-review" | For a skill you installed with `npx skills`: takes its author's new version and keeps your edits. You review it first. |

## Good to know

- **Your skills stay where they are.** Nothing changes without your approval.
- **Everything stays on your machine**, in `~/.meta-skill-loop`. Feedback can include
  work details, so keep that folder private.
- **Update:** `npx skills@latest update -g`.
- **Uninstall:** `npx skills@latest remove meta-skill-loop meta-skill-feedback meta-skill-refine -g`.
  Your feedback and versions stay in `~/.meta-skill-loop` until you delete it.

How it works: [docs/design.md](docs/design.md). Contributing: [AGENTS.md](AGENTS.md).

[MIT](LICENSE).
