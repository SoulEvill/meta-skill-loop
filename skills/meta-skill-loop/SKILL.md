---
name: meta-skill-loop
description: Manage agent skills, their versions, and their feedback. Use when the user says "meta-skill-loop" or "msl", asks which skills they have or which have open feedback, wants to add (manage) existing skills, see a skill's versions or history, compare versions, undo a change or go back to an earlier version, keep or discard edits to a skill, update a skill from its upstream source, or stop managing a skill. For logging feedback use meta-skill-feedback; for improving a skill from feedback use meta-skill-refine.
---

# meta-skill-loop

meta-skill-loop keeps feedback and a version history for the user's skills. Skills stay where their tools load them (`~/.cursor/skills`, `~/.agents/skills`, `~/.claude/skills`, a repo's `.cursor/skills`, …), and meta-skill-loop **never edits a skill except to apply a change the user approved**. Its own data lives in `~/.meta-skill-loop/`.

All bookkeeping goes through one script, `msl`. Run it as `~/.meta-skill-loop/bin/msl`. The first time, that file won't exist yet. Set it up once by running the setup script where this skill is installed, then continue:

```sh
bash ~/.agents/skills/meta-skill-loop/scripts/msl init
bash ~/.claude/skills/meta-skill-loop/scripts/msl init
bash ~/.cursor/skills/meta-skill-loop/scripts/msl init
```

Run only the first one whose file exists. If none does, use the folder your tool loaded this skill from: `bash <that folder>/scripts/msl init`.

**Versions work like git.** Changes in a skill folder are *live edits* until `msl keep` makes them the next version (v2, v3, …). `msl discard` throws them away; they're saved, and `msl restore` brings them back. A skill someone else publishes also tracks the published *upstream* versions, and updates are merged into the user's version instead of overwriting it.

## Status: "meta-skill-loop", "status", "which skills have feedback?"

Run `msl status` and summarize it in a few lines: each skill's version (`v3*` means v3 plus live edits), open feedback, and state.
- Every note under the table names the command that deals with it. Offer that command, and run it only when the user agrees.
- Suggest "refine <skill>" when a skill has 2+ open entries.
- If unmanaged skills are listed, offer to add them, once per conversation.
- **Live edits** (`changed`): show `msl diff <name>`, then ask whether to keep or discard them. Before keeping, check `msl feedback list <name>`. If the edits address open entries, confirm with the user and add `--fixes fb-…,fb-…`.
- **`copies-differ`**: the skill is installed in several folders, and two of them were edited differently. Show the difference (`diff -r <one> <other>`), and keep the copy the user picks: `msl keep <name> --from <path> -m "<what changed>"`.

## Add: "add my skills", "manage grill-me"

1. Run `msl add` with no name. It lists installed skills; `new` means not managed yet.
2. Confirm which to add. Suggest the ones the user actually uses, not every skill on disk.
3. Run `msl add <name>` for each (or `msl add <path>` for a specific folder). The skill is not modified. msl reports the kind: `local` (the user's own), `skills-cli` (installed by the `skills` CLI), or `git` (lives in a git repo).
4. The first time, suggest the one-time setup below if the user hasn't done it.

**One-time setup (recommended).** So the agent offers to log feedback when the user corrects a skill, the user adds this line to their tool's own rules: *"When the user corrects how a skill behaved or gives feedback on a skill, offer to log it with the meta-skill-feedback skill."*
- Cursor: Settings > Rules > User Rules.
- Codex: `~/.codex/AGENTS.md`.
- Claude Code: `~/.claude/CLAUDE.md`.

Offer to add it to the Codex or Claude Code file for them. Cursor's user rules are set in its settings UI.

## Versions: "show versions of pr-review", "what changed?", "compare v2 and v4"

- `msl history <name>` lists versions with their date, what changed, the feedback each one fixed, and how much feedback was logged against each. A version that attracts new complaints is a likely regression.
- To compare:
  - `msl diff <name> v2 v4` compares two versions;
  - `msl diff <name> v2` compares v2 with the live folder;
  - `msl diff <name>` shows the live edits;
  - `msl diff <name> --upstream` shows the user's refinements compared with upstream.

## Go back: "pr-review got worse", "undo v4", "go back to v2"

Run `msl history <name>` and confirm with the user which version. Then:
- **Undo one change:** `msl revert <name> v4`. Everything else stays, including later upstream updates. Prefer this when the user blames one change.
- **Go back to a version:** `msl rollback <name> v2`. If it says this also brings back older upstream text, tell the user, and only rerun with `--yes` if they agree.

Either way the result is a new version, and the feedback the undone versions fixed is reopened.

## Updates: "is there an update for grilling?", "update grilling", or an upstream note in status

**Just checking:** `msl update <name> --check` records the latest upstream and shows what it changes. Nothing live changes. Summarize it and ask whether to take it.

**Taking it:** run `msl update <name>`. For a `skills-cli` skill it fetches the latest version first. For a `git` skill, the user pulls in their repo as usual.
- **No refinements:** the update is applied directly as the next version. Report it.
- **Refinements:** msl prepares a merge **without touching the live skill**. Show `msl diff <name> --merge`, which is what the skill would become.
- **Conflicts listed:** edit the files in `~/.meta-skill-loop/skills/<name>/merge/` to resolve each `<<<<<<<`/`>>>>>>>` section by intent (`msl history <name>` and the feedback say why each refinement exists). Show the result.

Then wait for the user's decision:
- **Approve:** `msl update <name> --apply -m "<summary>"`. Add `--fixes fb-…` for feedback that the new upstream fixes.
- **Not now:** `msl update <name> --abort`. Their version stays live.
- **Take upstream as published, dropping the refinements:** `msl update <name> --take-upstream`. The refinements stay in history.

## Stop managing: "remove grill-me from meta-skill-loop"

`msl remove <name>` archives its versions and feedback. The skill itself is untouched.

## Rules

- Never edit a skill without the user's approval. Never move, delete, or rename a skill folder.
- Don't search the disk for skills: `msl add` lists them, and `msl path <name>` gives a managed skill's folder.
- Never edit files in `~/.meta-skill-loop/` by hand. Use `msl`. The one exception is resolving a pending merge in `…/merge/`.
- `~/.meta-skill-loop` holds private work: feedback and copies of conversations. Never copy it anywhere public.
- If `msl` can't write (for example, a sandbox blocks writes outside the project), show the command you would have run and ask the user to allow it or run it themselves.
