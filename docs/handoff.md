# Handoff

Rewritten at the end of every working session, so the next session (human or agent, local or cloud) can pick up. It's a snapshot, not a history. For the design, see [design.md](design.md). The code is the source of truth.

_Last updated: 2026-09-28, at the end of the design and v1 session._

## Where things stand

- **v1 is built** on branch `claude/inspiring-ritchie-n204ga`, not merged to `main` yet. CI is green on Ubuntu and on macOS bash 3.2, with 56 end-to-end tests.
  - `msl`: scan, add, log, status, show, diff, nudge, commit, mark, set, remove.
  - Three skills: `meta-skill-loop`, `meta-skill-feedback`, `meta-skill-refine`.
  - `install.sh`, which copies skills into `~/.agents/skills` (Cursor and Codex), plus `--claude`.
- **It was tested end to end with real skills** installed by the `skills` CLI (`mattpocock/skills`: grill-me, grilling, code-review), plus one local skill. Simulated Cursor agents drove the test.
  - It worked: adding skills (ownership detected from the lock file); unprompted capture after a natural correction; a refine proposing and then applying after approval; the refined skill behaving differently in a fresh session; a reinstall detected as `reverted`, then recovered.
  - It found a gap: there was no way to get the exact text of a lost change. That was fixed with `msl diff` and `msl nudge`.
- **Not yet tested in real Cursor or Codex:**
  - whether skills trigger from their descriptions alone;
  - Cursor's approval prompt when a skill writes to `~/.meta-skill-loop`;
  - Codex's writable-roots setting.

## Decided (details in design.md §7)

- **Framework and workspace are separate.** The public repo holds code only. Each user's data lives in their own local `~/.meta-skill-loop`. Nothing is pushed anywhere automatically, and never to a skill's maintainer.
- **Versioning:** one git repo per managed skill, with branches `upstream` (pristine) and `mine` (what runs). The live folder is the working tree.
  - Versions `v1…` are created only on "keep it" (commit).
  - Trials are protected with `git stash`.
  - Rollback either reverts one version or restores one.
  - Reconciling is a merge in a temporary worktree: the LLM proposes and the human approves.
- **Command renames:** `log` becomes `feedback`, and versions are named `vN` instead of `ch-NNNN`.
- **Feedback ids:** `fb-<workspace id>-<seq>`.
- **Updates:** an installer run directly makes upstream live immediately. It's detected on the next `msl` call, which offers reconcile / restore mine / take upstream. The recommended path is `meta-skill-loop update X`, which reviews before going live.
- **Accepted limits:**
  - merging prose is fuzzy;
  - a trial affects every session at once;
  - there's no detection when a skill is used, because that isn't possible portably.
- **Team feedback layer:** designed for (opt-in shared repo), not built.
- **Docs** live in `docs/` in this repo: `design.md`, and this `handoff.md`. GitHub Wiki was rejected because cloud sessions can't push to wikis ([anthropics/claude-code#86787](https://github.com/anthropics/claude-code/issues/86787), closed as not planned).

## Open question for the user

Keep skills **in place** (A, recommended) or **move them into a central store** and deploy copies to tool folders (B)?
- B's review-before-update benefit is available in A through `meta-skill-loop update`.
- B adds a second copy of every skill, a deploy step, and an "edited the wrong copy, it got overwritten" failure mode.
- B can't move skills that live in team repos.

## Next steps (once A or B is confirmed)

1. Build design.md §7 (v1.1):
   - per-skill git repos and a migration from the v1 layout (`base/`, `current/`, `changes.md`);
   - `feedback`, `commit`, `restore`, `history`, `rollback`, `update`;
   - stash-protected trials;
   - automatic update detection on every `msl` call;
   - the new ids.
2. Update the three skills' instructions for the new flow. Rerun the real-skill test with a real `npx skills update`.
3. The user tries it in Cursor. Then open the PR from the branch to `main`.

## Notes for the next agent

- In this cloud environment, running a headless `claude -p` with permission checks skipped is blocked. Use role-playing subagents to simulate Cursor instead.
- Bash 3.2 can be built locally for testing; see `AGENTS.md` for the compatibility rules.
