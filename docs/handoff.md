# Handoff

Rewritten at the end of every working session, so the next session (human or agent, local or cloud) can pick up. It's a snapshot, not a history. For the design, see [design.md](design.md). The code is the source of truth.

_Last updated: 2026-09-28, after cross-tool testing._

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

## Cross-tool testing (2026-09-28)

**`skills` CLI (real).**
- `npx skills add <this repo>` finds all 3 skills and installs them for Cursor, Codex and Claude Code: `~/.agents/skills` plus `~/.claude/skills`.
- `msl` keeps its executable bit.
- Bootstrapping works with no `install.sh`: `scripts/msl init` runs from the installed hub skill.

**Claude Code (real, headless, default permissions, Bash limited to `msl`).**
- Skill discovery: all 3 skills listed.
- Triggering: 5/5 correct. "feedback on X", "status", "versions", and "is there an update" each picked the right skill, and an unrelated coding prompt picked none.
- The feedback entry was written, tagged `tool: claude-code`.
- Refine proposed first, then applied after approval, then `keep` made v2 with `Fixes:`.
- The one-line rule in `~/.claude/CLAUDE.md` changed behavior: with it, the agent offered to log feedback after a natural correction; without it, it didn't.

**Codex.**
- The CLI installs, and skills install into `~/.agents/skills`.
- No model run was possible: the environment's OpenAI key has no quota.
- Still to verify on a real machine: triggering, and the `writable_roots` setting.

**Cursor.**
- The `cursor-agent` CLI installs.
- It requires login or `CURSOR_API_KEY`, and none was available, so there were no runs.

## Open: packaging (proposal given to the user, not yet decided)

- Make `npx skills add SoulEvill/meta-skill-loop` the primary install. Any of the three skills bootstraps the workspace on first use.
- Replace the copied `~/.meta-skill-loop/bin/msl` with a shim that runs the installed hub skill's `scripts/msl`. Today a `skills update` leaves the copied `msl` stale.
- Drop the `framework` kind and most of `install.sh`: our own skills become ordinary `skills-cli` skills.
- Version with semver git tags and GitHub Releases.

## Decided (details in design.md §5–7)

- Skills stay in place; there's no central store. meta-skill-loop never edits a skill except to apply an approved change.
- Versions are git commits on `mine`. They're created only by keep, a rollback, or a taken or merged update.
- Updates: run directly by an installer, they go live immediately and are detected on the next `msl` call. Run through `msl update`, they're reviewed first.
- Refine can hand its brief to the user's skill-creator. meta-skill-loop is the container for feedback and versions.
- Team feedback layer and multi-machine sync: designed for, not built.
- Docs live in `docs/`. The Wiki was rejected because cloud sessions can't push to wikis (anthropics/claude-code#86787).

## Later
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
