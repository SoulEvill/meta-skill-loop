---
name: meta-skill-loop
description: Feedback and version history for agent skills. Use when the user asks to log or record feedback on a skill ("log feedback on pr-review", "feedback on grill-me", "record this for the skill"), to refine or improve a skill from its feedback, to see their skills' status or open feedback, to see a skill's versions or what changed, to undo a change or go back to a version, to keep or discard edits to a skill, to update a skill from upstream, to send a skill change upstream as an issue or pull request, to add or stop managing skills, or says "meta-skill-loop" or "msl". Log feedback only when the user explicitly asks to; don't suggest logging feedback otherwise.
license: MIT
compatibility: Requires bash and git. Node.js (npx) to update skills installed with the skills CLI; the GitHub CLI (gh) to open pull requests upstream.
---

# meta-skill-loop

meta-skill-loop keeps feedback and a version history for the user's skills. Skills stay where their tools load them, and meta-skill-loop **never edits a skill except to apply a change the user approved**. Its data lives in `~/.meta-skill-loop/`.

All bookkeeping goes through `scripts/msl` in this skill's folder (usually `~/.agents/skills/meta-skill-loop/`). In these instructions, `msl <command>` means `bash <this skill's folder>/scripts/msl <command>`; always use that full path, so one approval in the tool covers every call. The first command sets up `~/.meta-skill-loop` by itself. `msl help` lists the commands. Files named `references/…` below are in the same folder.

**Versions work like git.** Changes in a skill folder are *live edits* until `msl keep` makes them the next version (v2, v3, …). `msl discard` throws them away; they're saved, and `msl restore` brings them back. A skill installed with the `skills` CLI also tracks the published *upstream* versions, and updates are merged into the user's version instead of overwriting it.

## Log feedback: "log feedback on pr-review: …", "feedback on grill-me: …", "record this for the skill"

Read `references/feedback.md` and follow it.

## Refine: "refine pr-review", "improve grill-me from its feedback"

Read `references/refine.md` and follow it.

## Send upstream: "send this upstream", "open an issue for pr-review's author", "make a PR with my change"

Read `references/contribute.md` and follow it.

## Status: "meta-skill-loop", "status", "which skills have feedback?"

Run `msl status` and summarize it in a few lines: each skill's version (`v3*` means v3 plus live edits), open feedback, and state.
- Every note under the table names the command that deals with it. Offer that command, and run it only when the user agrees.
- Suggest "refine <skill>" when a skill has 2+ open entries.
- If unmanaged skills are listed, offer to add them, once per conversation.
- **Live edits** (`changed`): show `msl diff <name>`, then ask whether to keep or discard them. Before keeping, check `msl feedback list <name>`. If the edits address open entries, confirm with the user and add `--fixes fb-…,fb-…`.

## Add: "add my skills", "manage grill-me"

1. Run `msl add` with no name. It lists installed skills; `new` means not managed yet.
2. Confirm which to add. Suggest the ones the user actually uses, not every skill on disk.
3. Run `msl add <name>` for each (or `msl add <path>` for a specific folder). The skill is not modified. Pass on any note msl prints; each names the command that deals with it, to run only if the user agrees.

## Versions: "show versions of pr-review", "what changed?", "compare v2 and v4"

- `msl history <name>` lists versions with their date, what changed, the feedback each one fixed, and how much feedback was logged against each. A version that attracts new complaints is a likely regression.
- To compare: `msl diff <name> v2 v4` (two versions), `msl diff <name> v2` (v2 against the live folder), `msl diff <name>` (the live edits), `msl diff <name> --upstream` (the user's changes against upstream).

## Go back: "pr-review got worse", "undo v4", "go back to v2"

Run `msl history <name>` and confirm with the user which version. Then:
- **Undo one change** (the default when the user blames a change): `msl revert <name> v4`. Everything else stays, including later upstream updates.
- **Go back to a version:** `msl rollback <name> v2`. If it says this also brings back older upstream text, tell the user, and only rerun with `--yes` if they agree.

Either way the result is a new version, and the feedback the undone versions fixed is reopened. If the user asks to record why the change was worse, log it as feedback on that version (`--version v4`), so the next refine knows what to avoid.

## Updates: "is there an update for grilling?", "update grilling", or an upstream note in status

**Just checking:** `msl update <name> --check` shows what upstream changed. Nothing live changes. Summarize it and ask whether to take it.

**Taking it:** `msl update <name>` fetches the latest version with the `skills` CLI (only `skills-cli` skills have updates).
- **No refinements:** it's applied directly as the next version. Report it.
- **Refinements:** msl prepares a merge **without touching the live skill**. Show `msl diff <name> --merge`, which is what the skill would become.
- **Conflicts listed:** edit the files in `~/.meta-skill-loop/skills/<name>/merge/` to resolve each `<<<<<<<`/`>>>>>>>` section by intent (`msl history <name>` and the feedback say why each refinement exists). Show the result.

Then wait for the user's decision:
- **Approve:** `msl update <name> --apply -m "<summary>"`. Add `--fixes fb-…` for feedback that the new upstream fixes.
- **Not now:** `msl update <name> --abort`. Their version stays live.
- **Take upstream as published, dropping the refinements:** `msl update <name> --take-upstream`. The refinements stay in history.

## Stop managing: "remove grill-me from meta-skill-loop"

`msl remove <name>` archives its versions and feedback. The skill itself is untouched.

## Gotchas

- Log feedback only when the user asks. A correction on its own ("no, shorter") is not a request to log it, and don't offer.
- Never edit a skill without the user's approval, and never move, delete, or rename a skill folder.
- `msl keep` takes every live edit in the folder at once: keep one change before making the next.
- Edits made outside msl (by hand, by another tool, by a `git pull`) show up as `changed`: live, but not a version until kept.
- Don't run `npx skills update` on a managed skill yourself: `msl update` runs it and merges the user's changes. (If an update was run directly, status shows `upstream`, and `msl update` takes it from there.)
- Don't search the disk for skills: `msl add` lists them, and `msl path <name>` gives a managed skill's folder.
- Don't edit `~/.meta-skill-loop/` by hand; use `msl`. The one exception is a pending merge in `…/merge/`.
- `~/.meta-skill-loop` is private: feedback and copies of conversations. Never paste it or copy it anywhere public.
- If `msl` can't write (a sandbox blocks writes outside the project), show the command you would have run and ask the user to allow it or run it themselves. In Codex, they can allow it once in `~/.codex/config.toml`: `writable_roots = ["<their home>/.meta-skill-loop"]` under `[sandbox_workspace_write]`.
