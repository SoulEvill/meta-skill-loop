# Handoff

Rewritten at the end of every working session, so the next session (human or agent, local or cloud) can pick up. It's a snapshot, not a history: git log has the history. For the design, see [design.md](design.md). The code is the source of truth.

_Last updated: 2026-09-28, after simplifying the core following the first independent review._

## Where things stand

- **v0.2.0 is on PR #1** (`claude/inspiring-ritchie-n204ga` → `main`); `main` has only the README and license, so `npx skills add SoulEvill/meta-skill-loop` works only after the merge.
- **The core model** (design.md §5):
  - one real folder per skill; other tool folders link to it (`msl link`, with approval; copies are set aside, never deleted);
  - two kinds: `skills-cli` (installed by the `skills` CLI; reviewed upstream updates) and `local` (everything else, including skills inside a git repo);
  - four states: `clean`, `changed`, `upstream`, `missing`;
  - one workspace lock: one msl command at a time.
- **Formats** (settled before release): feedback entries (title, version, tool, conversation copy, severity `P0`–`P3`/`nit`, status `open`/`applied`/`declined`, `fixed_in`; free-form body), `workspace.yaml` with `format: 1` and a 6-character id, `skill.yaml` with `path` and `links`.
- **Tests:** `tests/run.sh` (165, bash 5 and 3.2, always with a space in `$HOME`, `TZ=UTC`), skills lint, a real `skills` CLI install, and a real Claude Code agent test. CI runs the first three on Ubuntu and macOS.

## Why the core changed (after review round 1)

The independent review found 11 issues; all were fixed with regression tests (see the PR threads). Looking across every bug found so far, most came from two features: msl syncing several physical copies of a skill between tool folders (4 bugs, 2 of them data loss), and a `git` kind that ran msl's version control on top of the user's own git repo (3 bugs). Rather than keep hardening them, both were removed:
- copies became links to one folder (the layout the `skills` CLI itself produces on update), so msl never copies files between folders;
- skills inside a git repo became ordinary `local` skills: git owns pulls and merges; what a pull brings shows up as live edits.
The per-skill locks and workspace-wide id reservation added during the review were replaced by one workspace lock.

## Decided

- Skills stay in place; meta-skill-loop never edits a skill except to apply an approved change. Replacing a separate copy with a link happens only with the user's approval.
- Versions are git commits on `mine`, created only by keep, revert, rollback, or a taken/merged update.
- Which feedback a version fixed lives only in the feedback files (`fixed_in`).
- Conversations are copied only when identified for certain (Claude Code's session id, or `--session FILE`); copies are kept whole.
- Stay on bash for now; the CLI and data formats are the contract, so a later port (Node) would be invisible to users.
- Teams: individual workspaces for now. Next is `publish` (design.md §8, v2), not a team repo. Evals / golden dataset: later, not designed yet.
- Docs live in `docs/`; the Wiki was rejected because cloud sessions can't push to wikis.

## Not verified yet

- Real Cursor and Codex runs (no keys here): triggering from descriptions, Cursor's approval prompts, Codex's `writable_roots`, and how Codex identifies the current conversation.
- That Cursor loads a skill through a link in `~/.claude/skills` or `~/.cursor/skills` isn't needed: the real folder is in `~/.agents/skills`, which Cursor reads directly.
- Windows: WSL or Git Bash only.

## Next steps

1. The reviewer re-reviews PR #1 after the simplification.
2. The user tries it in Cursor: `npx skills add "SoulEvill/meta-skill-loop#claude/inspiring-ritchie-n204ga" -g --copy`, then add (and link), feedback, refine, keep, update.
3. The user configures repo protection from `docs/maintaining.md`.
4. Merge PR #1 when CI is green and the review passes; tag `v0.2.0`.
5. Then v2 (`publish`).
