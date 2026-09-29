# Handoff

Rewritten at the end of every working session, so the next session (human or agent, local or cloud) can pick up. It's a snapshot, not a history: git log has the history. For the design, see [design.md](design.md). The code is the source of truth.

_Last updated: 2026-09-29, in the "native by default" PR: 0.3.0 checked against agentskills.io, not yet tagged._

## Where things stand

- **0.3.0 is on `main`** (PRs #4 and #5: one skill, explicit capture, send upstream), never tagged. The "native by default" PR finishes it; tag `v0.3.0` after it merges.
- **Install:** `npx skills@latest add SoulEvill/meta-skill-loop --skill meta-skill-loop --agent cursor claude-code codex -g`, like the other Wendao skills. The skills CLI keeps one real folder in `~/.agents/skills` and links Claude Code's to it: meta-skill-loop's one-folder model.
- **Native by default** (design.md §7, decided with the user): the skill follows agentskills.io.
  - The agent runs `scripts/msl` from the skill's folder by path; no launcher, no setup step.
  - Users can invoke it with `/meta-skill-loop` (Cursor, Claude Code) or `$meta-skill-loop` (Codex), or plain words.
  - Portable frontmatter only (`name`, `description`, `license`, `compatibility`); Gotchas in `SKILL.md`; a refine checklist.
  - `msl feedback add` starts managing the skill itself.
  - Triggering is measured with the guide's eval format (`tests/agent/triggers.sh`).
- **One skill:** `SKILL.md` routes to `references/feedback.md`, `refine.md`, and `contribute.md`. Leftover 0.2 skills (`meta-skill-feedback`, `meta-skill-refine`) get a note in `msl add` and `msl status` naming how to remove each installation.
- **Capture is explicit:** feedback is logged only when the user asks; the agent doesn't log or offer on its own. Automatic capture is a later opt-in (design.md §8, phase 2).
- **Send upstream:** "send this upstream" offers a skills-cli skill's changes to its source as a GitHub issue (default) or a PR (on request, via `gh`), after the user approves the exact text. msl stays offline.
- **Stays its own repo**, separate from wendao-skills (a tool with code, tests, and releases vs. prose skills).
- **The core model** (design.md §5): one real folder per skill (other tool folders link to it; `msl link` fixes a stray copy, keeping it aside); two kinds, `skills-cli` and `local`; four states, `clean`, `changed`, `upstream`, `missing`; one workspace lock.
- **Formats** (settled): feedback entries (title, version, tool, conversation copy, severity `P0`–`P3`/`nit`, status `open`/`applied`/`declined`, `fixed_in`; free-form body), `workspace.yaml` (`format: 1`, a 6-character id), `skill.yaml` (`path`, `links`, source).
- **Tests:**
  - `tests/run.sh` (bash 5 and 3.2, a space in `$HOME`, `TZ=UTC`), skills lint (spec fields, YAML that parses), and a real `skills` CLI install. CI runs these on Ubuntu and macOS.
  - `tests/agent/run.sh claude-code`: explicit feedback, `/meta-skill-loop`, status, versions, feedback with no skill named, a plain correction (no log, no offer, skill not loaded), refine end to end, and a send-upstream draft.
  - `tests/agent/triggers.sh`: 20 labeled prompts, 3 runs each. See the PR for the latest rates.
  - From a Claude Code cloud session, every child `claude` run reports the parent's session id, so agent tests check content, not ids, and their conversation copies aren't representative.

## Decided

- Skills stay in place; meta-skill-loop never edits a skill except to apply an approved change. Replacing a separate copy with a link happens only with the user's approval.
- Versions are git commits on `mine`, created only by keep, revert, rollback, or a taken or merged update.
- Which feedback a version fixed lives only in the feedback files (`fixed_in`).
- Conversations are copied only when identified for certain (Claude Code's session id, or `--session FILE`); copies are kept whole.
- Stay on bash; the CLI and data formats are the contract, so a later port would be invisible to users.
- "Publish" (a shared remote with its own CI) is dropped: send upstream plus a team's own skills repo covers it. Evals of skill output built from feedback: later, not designed yet.
- Docs live in `docs/`; the Wiki was rejected because cloud sessions can't push to wikis.

## Not verified yet

- Real Cursor and Codex runs (no keys here): triggering, running `scripts/msl` by path, `/meta-skill-loop` and `$meta-skill-loop`, approval prompts, Codex's `writable_roots`, and how Codex identifies the current conversation. The trigger eval only drives Claude Code so far.
- Real-agent runs of revert, rollback, and update.
- When the skills CLI can't reach a source it still reports success, so `msl update --check` can say "up to date" against the last upstream seen (design.md §7).
- Windows: WSL or Git Bash only.

## Next steps

1. Merge the "native by default" PR, then tag `v0.3.0` on `main` (the release workflow checks it matches `MSL_VERSION`).
2. The user configures repo protection from `docs/maintaining.md`.
3. The user uses it in Cursor for a week on real skills: `/meta-skill-loop`, log feedback, refine, keep, update. Count how often feedback actually gets logged; that decides whether automatic capture (phase 2) is worth building.
4. Add Cursor and Codex to the trigger eval once there are keys (or from that week's observations).
5. Retire the 0.2 leftover notes a release or two after 0.3.0.
6. Link meta-skill-loop from the wendao-skills README once that repo is public.
