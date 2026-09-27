---
name: meta-skill-feedback
description: Log feedback about how a skill behaved, with evidence, so it can be improved later. Use when the user says "feedback on <skill>", "log feedback", "that skill should…", "next time don't…", "remember this for the skill", or corrects how a skill just behaved and agrees to log it. Works for any skill, managed or not.
---

# meta-skill-feedback

Capture one piece of feedback about a skill as a structured entry, then get back to what the user was doing. Capturing never changes the skill; improving it is a separate, deliberate step (meta-skill-refine).

Run `msl` as `~/.meta-skill-loop/bin/msl`. If it's missing, tell the user meta-skill-loop isn't installed and show them the feedback entry you would have logged, so nothing is lost.

## Steps

1. **Identify the skill.** Usually it's the skill you used earlier in this conversation. If more than one skill was involved, or none obviously was, ask which one. Use the skill's `name` from its frontmatter.

2. **Make sure it's managed.** Run `msl status <name>`. If it isn't listed, run `msl add <name>` and tell the user in one line that it's now managed.

3. **Write the entry.** Use short bullet points and only the facts that will help someone improve the skill later:
   - `asked:` what the user asked for when the skill ran (quote briefly)
   - `observed:` what the skill made you do that was wrong or unwanted; be concrete
   - `expected:` what the user wanted instead
   - `user said:` the user's own words, verbatim, if they gave feedback in words
   - `evidence:` the smallest excerpt that shows the problem (a few lines of output, a file:line, a command). Trim it.

   Leave out secrets, credentials, tokens, customer data, and anything the user wouldn't want stored. When unsure, summarize instead of quoting.

4. **Log it.** Pipe the bullets to `msl log` and set the flags:
   - `--severity`: `nit` (cosmetic), `annoying` (worked but badly), or `wrong` (incorrect result or harmful action)
   - `--tool`: the agent you're running in: `cursor`, `codex`, `claude-code`, or another name
   - `--project`: only if the current folder name isn't a good project name

   ```sh
   ~/.meta-skill-loop/bin/msl log pr-review --severity annoying --tool cursor <<'EOF'
   - asked: "review PR 482"
   - observed: listed 30 style nits and missed the unhandled retry error
   - expected: correctness issues first; style only if asked
   - user said: "stop with the nits, what's actually broken?"
   - evidence: review opened with 12 naming comments; retry.go:88 swallows the error
   EOF
   ```

5. **Confirm and continue.** In one line, report the entry id and the skill ("Logged fb-0012 for pr-review."). If the user also wants the current task redone the right way, do it now. The feedback is recorded either way.

## Notes

- One entry per distinct problem. If the user gives several unrelated complaints, log several entries.
- If the same problem was already logged (`msl show <name>` lists open entries), say so. Only log it again if there's new evidence, since repeated entries show a pattern.
- If writing is blocked (a sandbox, or a permission prompt the user declines), show the full `msl log …` command so the user can run it.
- Don't fix the skill here, even if the fix looks obvious. Suggest `refine <skill>` instead.
