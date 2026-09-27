# Handoff

Rewritten at the end of every working session, so the next session (human or agent, local or cloud) can pick up. It's a snapshot, not a history. For the design, see [design.md](design.md). The code is the source of truth.

_Last updated: 2026-09-28, end of the v1.1 build session._

## Where things stand

- **v1.1 is built** on branch `claude/inspiring-ritchie-n204ga`, not merged to `main` yet. 99 end-to-end tests, run in CI on Ubuntu and on macOS bash 3.2.
  - Each managed skill has its own git repo in the workspace, whose working tree is the live skill folder. It has two branches: `upstream` (as published) and `mine` (what runs).
  - Commands: `keep`, `undo`/`redo`, `history`, `rollback` (to a version, or `--only` one), and review-gated `update` (`--check`, `--apply`, `--abort`, `--take-upstream`).
  - `diff` variants: between versions, `--upstream`, `--incoming`, `--merge`, `--saved`.
  - Feedback ids look like `fb-<workspace id>-NNN` and record the version they were about.
  - `add` no longer edits skills. The installer prints one rule for the tool's own settings instead.
- **Tested end to end with real skills.** The installs used the `skills` CLI: `mattpocock/skills` grilling, plus a local skill. Three simulated Cursor sessions acted as the agent, and a real `npx skills add`/`update` ran against the workspace. What worked:
  - Add with the kind detected, and skill files byte-identical afterwards.
  - The user rule alone produced the offer to log feedback.
  - The feedback entry recorded the version it was about.
  - Refine: brief, approved edit, "try it first".
  - A real reinstall wiped the trial; status reported it, and redo recovered it.
  - Keep made v2, and history showed it.
  - `update` fetched with the real CLI and reported it up to date.
  - meta-skill-loop's own update through `install.sh` applied directly.
- **Bugs this testing found, all fixed:**
  - the index was left staged after an autosave, so `redo` silently did nothing;
  - status notes were joined on one line;
  - a second framework update was wrongly sent to review;
  - rollback only reopened feedback that was linked at keep time;
  - there was no read-only update check;
  - there was no preview of saved edits.
- **Still untested in real Cursor or Codex:**
  - skills triggering from their descriptions alone;
  - Cursor's approval prompt for writes to `~/.meta-skill-loop`;
  - Codex's writable-roots setting.

## Decided (details in design.md §5–7)

- Skills stay in place; there's no central store. meta-skill-loop never edits a skill except to apply an approved change.
- Versions are git commits on `mine`. They're created only by keep, a rollback, or a taken or merged update.
- Updates: run directly by an installer, they go live immediately and are detected on the next `msl` call. Run through `msl update`, they're reviewed first.
- Refine can hand its brief to the user's skill-creator. meta-skill-loop is the container for feedback and versions.
- Team feedback layer and multi-machine sync: designed for, not built.
- Docs live in `docs/`. The Wiki was rejected because cloud sessions can't push to wikis (anthropics/claude-code#86787).

## Open questions

None blocking. Candidates for later:
- `contribute` (v2): a refinement becomes a PR to the skill's source.
- Automatic observers (v3).

## Next steps

1. The user tries v1.1 in Cursor on their own skills: install, add, feedback, refine, keep, update.
2. Fix what that turns up, then open the PR from the branch to `main`.
3. Then plan v2 (`contribute`).

## Notes for the next agent

- In this cloud environment, headless `claude -p` with permission checks skipped is blocked. Simulate Cursor with role-playing subagents instead: give them the skill list and the user's rule, and relay user turns one at a time.
- Bash 3.2 can be built from source for local testing; see `AGENTS.md` for the compatibility rules.
- Two tests failed only because two edits touched adjacent lines, which git merge correctly treats as a conflict. Keep test edits on separate lines.
