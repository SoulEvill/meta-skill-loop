# Handoff

Rewritten at the end of every working session, so the next session (human or agent, local or cloud) can pick up. It's a snapshot, not a history. For the design, see [design.md](design.md). The code is the source of truth.

_Last updated: 2026-09-28, after packaging and CI._

## Where things stand

- **v1.1 is built** on branch `claude/inspiring-ritchie-n204ga`, not merged to `main` yet. 97 end-to-end tests plus the skills lint and a real `skills` CLI install, all in CI on Ubuntu and macOS (bash 3.2).
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

## Packaging and CI (done, 2026-09-28; see design.md §7a and maintaining.md)

- **Install:** `npx skills add SoulEvill/meta-skill-loop -g --copy` is the primary install. `install.sh` is a copy-only fallback.
- **First use:** any of the three skills sets up the workspace itself.
- **`~/.meta-skill-loop/bin/msl`** is a launcher into the installed skill, so there's no stale copy after an update.
- **The `framework` kind is removed.** meta-skill-loop's own skills are ordinary managed skills.
- **CI** runs on every push and PR: `lint` (shellcheck plus the skills lint), `test` (Ubuntu and macOS bash 3.2), and `package` (a real `skills` CLI install on Ubuntu and macOS).
- **`release`** runs on `v*` tags. It checks the tag is on `main` and equals `MSL_VERSION` (now 0.2.0), reruns every test, and creates a GitHub Release.
- **`agent-tests`** is manual and owner-only, with keys in the `agent-tests` environment. Claude Code is verified end to end here; Cursor and Codex paths are experimental.
- **Repository protection is clicked in GitHub settings** (checklist in `docs/maintaining.md`). It can't be set from a session.
- **`npx skills add SoulEvill/meta-skill-loop` only works once this branch is merged to `main`**, because main has only the README and license today.

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

1. The user configures repo protection from `docs/maintaining.md`: the `main` ruleset, the `v*` tag ruleset, Actions settings, and optionally the `agent-tests` environment and keys.
2. The user tries it in Cursor: install from this branch or a local clone, then add, feedback, refine, keep, update.
3. Open the PR from this branch to `main`, merge when CI is green, then tag `v0.2.0` so `npx skills add SoulEvill/meta-skill-loop` works for everyone.
4. Then v2 (`contribute`).
