---
name: meta-skill-loop
description: Manage agent skills, their versions, and their feedback. Use when the user says "meta-skill-loop" or "msl", asks which skills they have or which have open feedback, wants to add (manage) existing skills, see a skill's versions or history, compare versions, roll a skill back, keep or undo edits to a skill, update a skill from its upstream source, or stop managing a skill. For logging feedback use meta-skill-feedback; for improving a skill from feedback use meta-skill-refine.
---

# meta-skill-loop

meta-skill-loop helps people improve their skills over time: it collects feedback on any skill and keeps a version history of each one. Skills stay exactly where their tool loads them (`~/.cursor/skills`, `~/.agents/skills`, `~/.claude/skills`, a repo's `.cursor/skills`, …). meta-skill-loop **never edits a skill except to apply a change the user approved**. Its own data (feedback and versions) lives in `~/.meta-skill-loop/`.

All bookkeeping goes through one script, `msl`. Run it as `~/.meta-skill-loop/bin/msl`. If that file doesn't exist, run `scripts/msl init` from this skill's folder once.

**How versions work.** Each managed skill has a version history, like git:
- **Live edits:** changes in the skill folder that aren't a version yet. They come from refine, a skill-creator tool, or a hand edit.
- **Keep:** `msl keep` turns the live edits into the next version (v2, v3, …). **Undo:** `msl undo` discards them. They're saved, so `msl redo` brings them back.
- **Upstream:** a skill someone else publishes (installed with the `skills` CLI, living in a git repo, or one of meta-skill-loop's own skills) also tracks the published versions. Updates are merged into the user's version instead of overwriting it.

## What the user can ask for

### Status: "meta-skill-loop", "status", "which skills have feedback?"

Run `~/.meta-skill-loop/bin/msl status` and summarize it in a few lines. It shows each skill's version (`v3*` means v3 plus live edits), open feedback, and state, and it prints a note for anything needing attention:
- **Open feedback:** name the skills with the most; suggest "refine <skill>" when one has 2+ open entries.
- **TRIAGE > 0:** automatically observed candidates to confirm or dismiss (see Triage below).
- **`changed`:** live edits that aren't a version yet. Show `msl diff <name>`; ask whether to keep them (`msl keep <name> -m "<what changed>"`) or undo them (`msl undo <name>`).
- **`upstream-update`:** someone ran the skill's installer or `git pull`, and a new upstream version replaced the user's version in the folder. The user's version is safe. Offer to review the update (see Updates).
- **`upstream-live`:** an older upstream version was put back (for example, a reinstall), so the user's refinements aren't live. `msl update <name>` restores them.
- **`copies-differ`:** the skill is installed in several tool folders and they no longer match. `msl keep <name> -m "sync copies"` copies the primary one over the others.
- **`missing`:** the folder is gone. Offer `msl remove <name>`.
- **Unmanaged skills:** if any exist, mention how many and offer to add them.

### Add: "add my skills", "manage grill-me"

1. Run `msl scan` to list installed skills. `new` means not managed yet.
2. Confirm which to add. Suggest the ones the user actually uses, not every skill on disk.
3. For each one, run `msl add <name>` (or `msl add <path>` for a specific folder). The skill file is not modified. `msl` detects where it comes from and says so:
   - `local`: the user's own folder.
   - `skills-cli`: installed by the `skills` CLI.
   - `git`: lives in a git repo.
   - `framework`: one of meta-skill-loop's own skills.
4. Show `msl status` at the end.
5. The first time, suggest the one-line setup below if the user hasn't done it.

**One-time setup (recommended).** So the agent offers to log feedback when the user corrects a skill, the user adds this line to their tool's own rules: *"When the user corrects how a skill behaved or gives feedback on a skill, offer to log it with the meta-skill-feedback skill."*
- Cursor: Settings > Rules > User Rules.
- Codex: `~/.codex/AGENTS.md`.
- Claude Code: `~/.claude/CLAUDE.md`.

Offer to add it to the Codex or Claude Code file for them. Cursor's user rules are set in its settings UI.

### Versions: "show versions of pr-review", "what changed?", "compare v2 and v4"

- `msl history <name>` lists versions with their date and what changed. It also shows which feedback each version fixed, which upstream it's based on, and how much feedback was logged against each version. A version that attracts new complaints is a likely regression.
- To compare:
  - `msl diff <name> v2 v4` compares two versions;
  - `msl diff <name> v2` compares v2 with the live folder;
  - `msl diff <name>` shows the live edits;
  - `msl diff <name> --upstream` shows the user's refinements compared with upstream.

### Roll back: "pr-review got worse, go back", "undo v4"

1. Run `msl history <name>` and confirm with the user which version.
2. Pick the right kind:
   - **Undo just one change:** `msl rollback <name> v4 --only`. Everything else stays, including later upstream updates. Prefer this when the user blames one change.
   - **Go back to a version entirely:** `msl rollback <name> v2`. If it says this also brings back older upstream text, tell the user, and only rerun with `--yes` if they agree.
3. A rollback is itself a new version. The feedback that the undone versions fixed is reopened.

### Updates: "update grilling", or when status shows `upstream-update`

1. Run `msl update <name>`:
   - For a `skills-cli` skill it fetches the latest version first.
   - For a `git` skill the user pulls in their repo as usual, and msl picks up what arrived.
   - msl records the new upstream version and keeps the user's version live.
2. Depending on the result:
   - **The user had no refinements:** the update is applied directly as the next version. Report it.
   - **The user has refinements:** msl prepares a merge **without touching the live skill**. Show:
     - `msl diff <name> --merge`: what the skill would become;
     - `msl diff <name> --upstream`: the refinements being carried over.
   - **Conflicts are listed:** edit the files in `~/.meta-skill-loop/skills/<name>/merge/` to resolve each `<<<<<<<`/`>>>>>>>` section by intent. `msl history <name>` and the feedback say why each refinement exists. Show the result.
3. Wait for the user's decision:
   - **Approve:** `msl update <name> --apply -m "<summary>"`. Add `--resolved fb-…` for feedback that the new upstream already fixes.
   - **Not now:** `msl update <name> --abort`. Their version stays live, and status notes the unmerged upstream.
   - **Take upstream as published and drop the refinements:** `msl update <name> --take-upstream`. The refinements stay in history.

### Stop managing: "remove grill-me from meta-skill-loop"

`msl remove <name>` archives its versions and feedback. The skill itself is untouched.

### Triage automatically observed feedback

Entries with `origin: observed` start as `candidate`. For each one (`msl feedback list <name>`), show it and ask the user:
- **keep:** `msl feedback mark <id> open`;
- **dismiss:** `msl feedback mark <id> declined -m "<why>"`.

## Rules

- Never edit a skill without the user's approval. Never move, delete, or rename a skill folder.
- Never edit files in `~/.meta-skill-loop/` by hand. Use `msl`. The one exception is resolving a pending merge in `…/merge/`.
- `~/.meta-skill-loop` may contain private work evidence. Never copy it anywhere public.
- If `msl` can't write (for example, a sandbox blocks writes outside the project), show the command you would have run and ask the user to allow it or run it themselves.
