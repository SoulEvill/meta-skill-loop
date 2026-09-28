---
name: meta-skill-refine
description: Improve a skill from its logged feedback. Use when the user says "refine <skill>", "improve <skill> from feedback", "apply the feedback to <skill>", "tune <skill>", or asks to work through open feedback. Turns the feedback into a brief, makes the smallest edit the user approves, and records it as a new version.
---

# meta-skill-refine

Turn a skill's accumulated feedback into a small, approved change, and record it as a new version tied to the feedback it fixes.

Run `msl` as `~/.meta-skill-loop/bin/msl`. The first time, that file won't exist yet: set it up by running `scripts/msl init` in the `meta-skill-loop` skill's folder, which is installed next to this skill's folder (`../meta-skill-loop/scripts/msl init`), then continue.

## Steps

1. **Check the skill.** Run `msl status <name>`.
   - It should be `clean`.
   - If it's `changed`, ask whether to keep or undo those edits first.
   - If it shows an upstream note, handle the update first (see the meta-skill-loop skill).

2. **Read the feedback.** Run `msl feedback list <name>`.
   - Triage `candidate` entries first: keep (`msl feedback mark <id> open`) or dismiss (`msl feedback mark <id> declined -m "<why>"`).
   - Compare each entry's `version` with the current version in `msl status`. Entries logged against an older version may already be fixed.
   - Read the live skill: its folder is `msl path <name>`.

3. **Write a brief.** Group the open feedback into themes. For each theme, give the entry ids, the severity, how strong the evidence is, and the **desired behavior** in one or two sentences. For example:

   ```
   pr-review · v3 · 4 open entries
   1. Correctness buried under style nits (fb-k3x9-012, -015, -019): strong
      → Report correctness issues first; list style only when asked.
   2. Doesn't run the tests before reviewing (fb-k3x9-021): single entry
   ```

   A single entry is a data point, not a pattern. Propose a change for it only if it's severity `wrong` or the user asks.

4. **Propose the smallest edit per theme.** Show a diff, or before and after, of exactly what would change. Keep the skill's voice and structure. Sharpen existing instructions rather than adding sections, and never rewrite the whole skill.
   - If the user has a skill-authoring skill (for example, a skill creator), you may hand it the brief and let it draft the edit. Either way, show the proposal before changing anything.
   - If the feedback suggests the skill is fundamentally wrong for the job, say so and let the user decide.

5. **Apply only after approval.** Edit the files in the skill's folder. Then run `msl diff <name>` to confirm the change. It's now a live edit, not yet a version. Ask the user:
   - **Keep it now:** `msl keep <name> -m "<what changed>" --fixes fb-…,fb-…`. This creates the next version and marks those entries applied. Use one keep per theme, so each version maps cleanly to its feedback.
   - **Try it first:** leave it live. It's saved automatically. Later, "keep it" or "undo that" (`msl undo <name>`; `msl redo <name>` brings it back).

   For feedback the user decides not to act on, run `msl feedback mark <id> declined -m "<reason>"`.

6. **Close out.** Summarize what changed and what's still open.
   - If the skill has an upstream (kind `skills-cli` or `git` in `msl status`), mention two things. Future upstream updates will be merged with this change for their review rather than overwriting it. And if the change would help everyone, it's worth sending to the skill's source as a PR or issue, with the evidence summarized and anything private removed.

## Rules

- Never change a skill before the user approves the proposed edit.
- Don't paste raw feedback into anything that leaves the machine.
- If the user regrets a change after keeping it, `msl rollback <name> <vN> --only` undoes just that version and reopens its feedback.
