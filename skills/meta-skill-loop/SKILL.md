---
name: meta-skill-loop
description: Manage agent skills and their feedback loop. Use when the user says "meta-skill-loop", "msl", asks which skills they have or which have open feedback, wants to add (enroll) existing skills so feedback can be collected on them, check a skill's status or history, or stop managing a skill. For logging feedback use meta-skill-feedback; for improving a skill from feedback use meta-skill-refine.
---

# meta-skill-loop

meta-skill-loop is a light management layer over the skills the user already has. Skills stay where their tool loads them (`~/.cursor/skills`, `~/.agents/skills`, `~/.claude/skills`, a repo's `.cursor/skills`, …). meta-skill-loop only keeps its own data in `~/.meta-skill-loop/`: which skills are managed, where they live, feedback entries, snapshots, and a change log.

All bookkeeping goes through one script, `msl`. Run it as `~/.meta-skill-loop/bin/msl`. If that file doesn't exist, run `scripts/msl init` from this skill's folder once; it creates the workspace and installs itself there.

## What the user can ask for

### Status: "meta-skill-loop", "status", "which skills have feedback?"

Run `~/.meta-skill-loop/bin/msl status` and summarize it in a few lines:
- Skills with open feedback: name the top ones and suggest `refine <skill>` when a skill has 2+ open entries.
- Skills with TRIAGE > 0: these are automatically observed candidates to confirm or dismiss.
- Any state other than `clean` (handle it as below, after the user agrees):
  - `reverted`: an update or reinstall put back the same upstream version and wiped the user's changes (their refinements and usually the nudge line). `msl diff <name>` shows exactly what's missing: lines marked `-` are the ones to restore. `msl show <name>` explains why each change exists. Restore them in the skill folder, then `msl nudge <name>` for the nudge line, then `msl commit <name> -m "re-applied after update"` (no `--base`: upstream didn't change).
  - `changed`: the skill differs from what meta-skill-loop recorded. Run `msl diff <name>` and ask the user which it is:
    - **Their own edit** (or a creator tool's): keep it with `msl commit <name> -m "<what changed>"`.
    - **A new upstream version**: do these in order.
      1. Save the user's refinements first: `msl diff <name> --refinements`. Keep that output; it's the only copy you'll need.
      2. Record the new upstream as the base: `msl commit <name> --base -m "took upstream update"`.
      3. Re-apply each refinement from step 1 to the new text, by intent: `msl show <name>` says why each change was made, so adapt the wording if upstream changed it. Drop any refinement the new upstream already covers, and mark its feedback `msl mark <id> resolved-upstream`.
      4. `msl nudge <name>`, then `msl commit <name> -m "re-applied refinements on new upstream"`.
  - `copies-differ`: the skill is installed in several tool folders and they no longer match. The first path is the primary copy; `msl commit` copies it to the others.
  - `missing`: the folder is gone. Offer `msl remove <name>`.
- If unmanaged skills exist, mention how many and offer to add them.

### Add: "add my skills", "add grill-me", "manage this skill"

1. Run `msl scan` to list installed skills; `new` means not managed yet.
2. Confirm which to add. Suggest all `new` skills the user actually uses, not every skill on disk.
3. For each: `msl add <name>` (or `msl add <path>` for a specific folder).
   - Ownership is detected automatically. A skill installed with the `skills` CLI is `upstream` (its source is recorded); anything else is `own`. Tell the user which was chosen. If it's wrong, fix it with `msl set <name> ownership own|upstream` (and `msl set <name> source <url>`).
   - `own` means refinements edit the skill directly. `upstream` means someone else publishes it: refinements still edit it in place, but a future update may overwrite them (status will show `reverted`), so suggest sending good changes back to the source.
   - `add` inserts one line after the skill's frontmatter asking the agent to offer feedback logging. Use `--no-nudge` if the user doesn't want that.
4. Show `msl status` at the end.

### Details: "show me grill-me", "what changed in pr-review?"

`msl show <name>` prints metadata, open feedback, and the change log (`--all` includes applied and declined feedback). Summarize; don't dump it unless asked.

### Stop managing: "remove grill-me from meta-skill-loop"

`msl remove <name>` removes the nudge line and archives the data. The skill itself is left in place.

### Triage automatically observed feedback

Entries with `origin: observed` start as `candidate`. For each one, show it and ask: keep (`msl mark <id> open`) or dismiss (`msl mark <id> declined -m "<why>"`).

## Rules

- Never move, delete, or rename a skill folder. meta-skill-loop manages skills in place.
- Never edit files in `~/.meta-skill-loop/` by hand; use `msl` so ids, hashes, and history stay consistent.
- `~/.meta-skill-loop` may contain private work evidence. Never copy it into a public place.
- If `msl` can't write (for example, a sandbox blocks writes outside the project), show the command you would have run and ask the user to allow it or run it themselves.
