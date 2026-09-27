---
name: meta-skill-refine
description: Improve a skill from its logged feedback. Use when the user says "refine <skill>", "improve <skill> from feedback", "apply the feedback to <skill>", "tune <skill>", or asks to work through open feedback. Reviews the feedback, proposes the smallest edit, and applies it only after the user approves.
---

# meta-skill-refine

Turn a skill's accumulated feedback into a small, approved edit, and keep a record of why each change was made.

Run `msl` as `~/.meta-skill-loop/bin/msl`.

## Steps

1. **Load everything.** Run `msl show <name>`. It prints the skill's metadata, its `state`, the current `live_hash`, the open feedback, and the change log. Then read the live skill: `msl path <name>` gives the folder; read its `SKILL.md` and any files it references that the feedback touches.

   - If `state` is not `clean`, stop and resolve that first (see the meta-skill-loop skill).
   - If there are `candidate` entries, triage them first: keep (`msl mark <id> open`) or dismiss (`msl mark <id> declined -m "<why>"`).

2. **Group the feedback into themes.** For each theme, list the entry ids, the severity, and how strong the evidence is. Flag entries whose `skill_hash` differs from `live_hash`: they were logged against an older version and may already be fixed. Present this as a short summary:

   ```
   pr-review · 4 open entries
   1. Too many style nits, correctness buried (fb-0012, fb-0015, fb-0019): strong, 3 entries
   2. Doesn't run the tests before reviewing (fb-0021): single entry
   ```

   A single entry is a data point, not a pattern. Propose a change for it only if it's severity `wrong` or the user asks.

3. **Propose the smallest edit per theme.** Show a diff or before/after of exactly the lines you'd change. Prefer to:
   - sharpen an existing instruction over adding a new section;
   - state the desired behavior ("Report correctness issues first; list style only when asked") rather than the complaint;
   - keep the skill's voice and structure;
   - avoid anything that only fits one project unless the skill is project-specific.

   Don't rewrite the skill. If the feedback points to a skill that is fundamentally wrong for the job, say so and let the user decide.

4. **Apply only after approval.** Edit the files in the skill's folder (`msl path <name>`), in place. Then record the change:

   ```sh
   ~/.meta-skill-loop/bin/msl commit pr-review -m "report correctness first; style only on request" --fixes fb-0012,fb-0015,fb-0019
   ```

   This snapshots the new version, copies it to any other installed copies, logs the change with the feedback ids it addresses, and marks those entries `applied`.

   For feedback the user decides not to act on: `msl mark <id> declined -m "<reason>"`.

5. **Close out.** Summarize what changed and what's still open. Then:
   - If the skill's ownership is `upstream` (see `msl show`), tell the user this edit lives only on their machine: a future update of the skill may overwrite it, and status will then show `reverted`. If the change would help everyone, suggest sending it to the skill's source (the `source:` field) as a PR or issue, with the evidence summarized and anything private removed.
   - If the skill is the user's own, nothing else is needed.

## Rules

- Never apply an edit the user hasn't approved.
- One theme per `msl commit`, so each change maps cleanly to its feedback.
- Keep private evidence private: don't paste raw feedback into anything that leaves the machine.
