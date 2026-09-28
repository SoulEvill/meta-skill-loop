# Refine a skill

Turn a skill's accumulated feedback into a small, approved change, and record it as a new version tied to the feedback it fixes. Run `msl` as SKILL.md says.

## Steps

1. **Check the skill.** Run `msl status <name>`. It should be `clean`.
   - If it has live edits (`changed`), ask whether to keep or discard them first.
   - If a note mentions upstream, handle the update first (Updates, in SKILL.md).

2. **Read the feedback.** Run `msl feedback list <name>` for the open entries.
   - Compare each entry's `version` with the current version in `msl status`. Entries logged against an older version may already be fixed.
   - An entry's `session` is a copy of the whole conversation it came from. Read it only when the entry itself isn't enough.
   - Read the live skill: its folder is `msl path <name>`.

3. **Write a brief.** Group the open feedback into themes. For each theme, give the entry ids, the severity, how strong the evidence is, and the **desired behavior** in one or two sentences. For example:

   ```
   pr-review · v3 · 4 open entries
   1. Correctness buried under style nits (fb-k3x9a2-012, -015, -019, P2): strong
      → Report correctness issues first; list style only when asked.
   2. Doesn't run the tests before reviewing (fb-k3x9a2-021, P3): single entry
   ```

   A single entry is a data point, not a pattern. Propose a change for it only if it's `P0` or `P1`, or the user asks. If no theme qualifies, show the brief and ask which to act on.

4. **Propose the smallest edit per theme.** Show a diff, or before and after, of exactly what would change. Keep the skill's voice and structure. Sharpen existing instructions rather than adding sections, and never rewrite the whole skill.
   - If the user has a skill-authoring skill (for example, a skill creator), you may hand it the brief and let it draft the edit. Either way, show the proposal before changing anything.
   - If the feedback suggests the skill is fundamentally wrong for the job, say so and let the user decide.

5. **Apply only after approval, one theme at a time.** Edit the files in the skill's folder for one theme. Then run `msl diff <name>` to confirm the change. It's now a live edit, not yet a version. Ask the user:
   - **Keep it now:** `msl keep <name> -m "<what changed>" --fixes fb-…,fb-…`. This creates the next version and marks those entries applied. `keep` takes every live edit, so keep one theme before applying the next; each version then maps cleanly to its feedback.
   - **Try it first:** leave it live. Later, "keep it" or "discard it" (`msl discard <name>`; `msl restore <name>` brings it back).

   For feedback the user decides not to act on, run `msl feedback mark <id> declined`.

6. **Close out.** Summarize what changed and what's still open.
   - If the skill has an upstream (kind `skills-cli` in `msl status`), mention two things. Future upstream updates will be merged with this change for their review rather than overwriting it. And if the change would help everyone, it's worth sending to the skill's source as a PR or issue, with the evidence summarized and anything private removed.

## Rules

- Never change a skill before the user approves the proposed edit.
- Don't paste raw feedback or conversation copies into anything that leaves the machine.
- If the user regrets a change after keeping it, `msl revert <name> <vN>` undoes just that version and reopens its feedback.
