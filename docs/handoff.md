# Handoff

Rewritten at the end of every working session, so the next session (human or agent, local or cloud) can pick up. It's a snapshot, not a history: git log has the history. For the design, see [design.md](design.md). The code is the source of truth.

_Last updated: 2026-09-28, after the foundation review._

## Where things stand

- **v1.1 is built** on branch `claude/inspiring-ritchie-n204ga`, not merged to `main` yet (`main` has only the README and license, so `npx skills add SoulEvill/meta-skill-loop` works only after the merge).
- **Foundation review done** before any user has data. It fixed the data formats and the CLI names:
  - **Feedback format** (design.md §5): title, version, tool, conversation copy, severity `P0`–`P3`/`nit`, status `open`/`applied`/`declined`, `fixed_in`; free-form body. `origin`, `confidence`, `project`, `resolution`, and the `candidate`/`resolved-upstream` statuses were removed.
  - **Workspace:** a `format: 1` field, 6-character ids, `sessions/` for conversation copies. Skill source is `source_url` + `source_path`.
  - **CLI:** `discard`/`restore` (were undo/redo), `revert` (was `rollback --only`), `add` with no name lists skills (replaced `scan`), `update --check` shows what's coming (replaced `diff --incoming`), `--fixes` on both keep and update. Removed: `add-path`, `import-upstream`, `update --ff-only`, the legacy-workspace check.
  - **`install.sh` removed.** The only install is `npx skills add`; without Node, copy the folders.
  - **Bug fixed:** an edit made in a second installed copy (for example Claude Code's `~/.claude/skills`) was overwritten by `keep`. Now any edited copy becomes the live edit; copies edited differently are a conflict resolved with `keep --from`.
- **Tests:** `tests/run.sh` (139, bash 5 and 3.2, always with a space in `$HOME`), skills lint, a real `skills` CLI install, and a real Claude Code agent test. CI runs the first three on Ubuntu and macOS.
- **Tested with real Claude Code before the review** (journeys: first use, hand edit, new skill, team `git pull`, regression and rollback, deleted skill; real upstream update and self-update). Rerun the agent test after skill-text changes.

## Decided

- Skills stay in place; meta-skill-loop never edits a skill except to apply an approved change.
- Versions are git commits on `mine`, created only by keep, revert, rollback, or a taken/merged update.
- Which feedback a version fixed lives only in the feedback files (`fixed_in`).
- Conversation copies are kept whole; trim later if size becomes a problem.
- Teams: individual workspaces for now. Next is `publish` (design.md §8, v2), not a team repo.
- Evals / golden dataset: later, not designed yet.
- Docs live in `docs/`; the Wiki was rejected because cloud sessions can't push to wikis.

## Not verified yet

- Real Cursor and Codex runs (no keys here). In particular: Cursor triggering from descriptions, Cursor's approval prompts, Codex's `writable_roots`, and where Codex keeps its conversation files (msl assumes `~/.codex/sessions/**/rollout-*.jsonl`).
- Windows: WSL or Git Bash only.

## Next steps

1. The user tries it in Cursor: `npx skills add "SoulEvill/meta-skill-loop#claude/inspiring-ritchie-n204ga" -g --copy`, then add, feedback, refine, keep, update.
2. The user configures repo protection from `docs/maintaining.md`.
3. Open the PR from this branch to `main`, merge when CI is green, tag `v0.2.0`.
4. Then v2 (`publish`).
