# Log feedback

Capture one piece of feedback about a skill as an entry, then get back to what the user was doing. Do this only because the user asked. Capturing never changes the skill: improving it is a separate step (`refine.md`). Run `msl` as SKILL.md says.

## Steps

1. **Identify the skill and the problem.** Usually the user names the skill. If not, it's the skill you used earlier in this conversation, and you name it when you confirm.
   - If more than one skill was involved, or none obviously was, ask which one. Never guess. Use the skill's `name` from its frontmatter.
   - If the user hasn't said what went wrong, in this request or just before it, ask in one line. Don't build the entry from earlier turns on your own.
   - If that skill only hands off to another skill (for example, "use the grilling skill"), log the feedback on the skill whose instructions actually produced the behavior.

2. **Make sure it's managed.** Run `msl status <name>`. If it isn't managed, run `msl add <name>` and tell the user in one line that it's now managed. The skill itself is not modified. If `msl add` finds no skill by that name (a typo, or not installed), run `msl add` with no name and ask the user which one they meant.

3. **Write the entry.**
   - **Title:** one line naming the problem, e.g. "Buries the real bug under style nits".
   - **Severity:**

     | Level | Meaning |
     |---|---|
     | `P0` | harmful: destroyed, overwrote, or leaked something, or ran something it shouldn't have |
     | `P1` | wrong result the user had to catch |
     | `P2` | worked, but badly; cost the user time (the default) |
     | `P3` | minor friction |
     | `nit` | wording, format, taste |

   - **Body:** free-form Markdown. Use these sections where they apply, and add anything else the user wants recorded:
     - `## Asked`: what the user asked for when the skill ran (quote briefly)
     - `## Observed`: what the skill made you do that was wrong or unwanted; be concrete
     - `## Expected`: what the user wanted instead
     - `## User said`: the user's own words, verbatim
     - `## Evidence`: the smallest excerpt that shows the problem (a few lines of output, a file:line, the instruction in the skill that caused it)

   In Claude Code, msl saves a copy of the whole conversation with the entry by itself. In Cursor, Codex, or any other tool, if the skill ran in this conversation, add a `## Conversation` section with the last few exchanges, trimmed (or, if you know the file your tool keeps this conversation in, pass it with `--session <file>`).

   Leave out secrets, credentials, tokens, customer data, and anything the user wouldn't want stored. When unsure, summarize instead of quoting.

4. **Log it.** Pipe the body to `msl feedback add` with the title, severity, and `--tool` (the agent you're running in: `cursor`, `codex`, `claude-code`, or another name):

   ```sh
   ~/.meta-skill-loop/bin/msl feedback add pr-review -t "Buries the real bug under style nits" --severity P2 --tool cursor <<'EOF'
   ## Asked
   "review PR 482"

   ## Observed
   Listed 30 style nits and missed the unhandled retry error.

   ## Expected
   Correctness issues first; style only if asked.

   ## User said
   "stop with the nits, what's actually broken?"

   ## Evidence
   retry.go:88 swallows the error.
   EOF
   ```

   msl records which version of the skill the feedback is about. If it's about an earlier version (for example, a change the user just undid), add `--version vN`.

5. **Confirm and continue.** Report the entry id and the skill in one line ("Logged fb-k3x9a2-012 for pr-review."). If the user also wants the current task redone the right way, do it now. The feedback is recorded either way.

## Notes

- Log one entry per distinct problem. If the user gives several unrelated complaints, log several entries.
- If the same problem was already logged (`msl feedback list <name>`), log it anyway, since the user asked and a repeat shows a pattern, and mention the earlier entry's id.
- If writing is blocked (a sandbox, or a permission prompt the user declines), show the full `msl feedback add …` command so the user can run it.
- Don't fix the skill here, even if the fix looks obvious. Suggest "refine <skill>" instead.
- Log only what the user asked you to log, and don't suggest logging anything else.
