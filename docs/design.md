# meta-skill-loop: design

Status: release 0.3.0 (phase 1.1) · 2026-09-28. Roadmap phases are named "phase" so they don't clash with skill versions (v1, v2, …) or release numbers (0.3.0).

## 1. Problem

People accumulate agent skills: their own, their team's, public ones. Skills misbehave in small ways, such as asking too many questions or burying the important finding under nits. The fix is usually a one-line tweak, but the feedback is given in the moment and then lost. Nothing collects it per skill, keeps the evidence, or turns it into an improvement later. And most people use more than one agent tool.

## 2. What meta-skill-loop is (and isn't)

It is a **management layer for the feedback loop around skills**:

1. **Add**: enroll skills you already have, wherever they live.
2. **Capture**: when the user asks ("log feedback on this skill"), write a structured entry with evidence.
3. **Refine**: later, turn accumulated feedback into the smallest approved edit, with a record of why.
4. **Version**: every kept change is a version you can compare or roll back; upstream updates are merged with your changes for review instead of overwriting them.
5. **Status**: see every managed skill, its version, its open feedback, and anything that needs attention.

It is **not** a skill authoring tool (use Cursor `/create-skill`, Anthropic's `skill-creator`, or an editor), **not** an installer or package manager (use the [`skills` CLI](https://github.com/vercel-labs/skills) or copy folders), and **not** a place to host skills. It holds only its own data.

## 3. How it fits with sharing skills and personal hubs

| Layer | Job | Where it lives |
|---|---|---|
| **meta-skill-loop** | feedback, refine, versions, reviewed updates, status; (phase 2) contribute | this public repo + `~/.meta-skill-loop/` per user |
| **Packs** | share skills: one git repo per *audience* (team, personal, public), not one per skill | their own repos; installed per skill with `npx skills add <repo> --skill <name> -g` |
| **Hub** (optional) | a personal "menu" skill that lists the skills you care about, grouped your way, and routes to them | a skill in your own pack; can show `msl status` as a health column |

meta-skill-loop never needs to know what a skill does, which pack it came from, or whether a hub exists. It only knows where a skill lives, where it came from, and what feedback it has.

## 4. Constraints that shaped it (verified 2026-09)

| | Cursor | Codex | Claude Code |
|---|---|---|---|
| User skill folders | `~/.agents/skills`, `~/.cursor/skills` (+ reads `~/.claude/skills`, `~/.codex/skills`) | `~/.agents/skills` | `~/.claude/skills` |
| Nested discovery | recursive | per directory | one level only |
| Symlinked skills | unreliable (known issue) | followed | followed |
| Shared frontmatter | `name`, `description` | `name`, `description` | `name`, `description` |

Hence:
- Skills are **managed in place**, never moved. A skill installed for several tools is one real folder (preferably in `~/.agents/skills`, read by Cursor and Codex); other tool folders link to it, which is the layout the `skills` CLI itself produces on update. meta-skill-loop itself is installed that way too (the skills CLI's default).
- Metadata lives outside `SKILL.md`.
- Nothing depends on hooks or Claude-only features (`!command` injection, `${CLAUDE_SKILL_DIR}`).
- Everything mechanical is in one bash 3.2 script, and the agent only does judgment.

## 5. Data model

The workspace format is versioned (`format:` in `workspace.yaml`), so a later release can upgrade old data. Rule for every file msl writes: fields it doesn't know are left alone, and a missing field has a default. New features only add fields.

```
~/.meta-skill-loop/                  local only; holds private work, so never push it publicly
  workspace.yaml                     format: 1, id: k3x9a2 (random, created once; used in feedback ids), created
  bin/msl                            a launcher that runs scripts/msl from the installed meta-skill-loop skill
  sessions/                          copies of the conversations feedback was logged in
  lock/                              only while an msl command runs (one at a time)
  skills/<name>/
    skill.yaml                       name, kind (local|skills-cli), source_url, source_path, added, path, links
    git/                             the skill's version history (git dir; its working tree is the skill's folder)
    feedback/fb-k3x9a2-007.md        one file per entry
    merge/                           only while an upstream merge waits for review (a temporary git worktree)
  archive/                           data of skills you stopped managing, and copies set aside by msl link
```

**One git repo per skill, two branches** (the classic "vendor branch" pattern):

```
  upstream:  U1 (abc123) ───────────── U2 (def456)      pristine published versions only (not for local skills)
               \                         \
  mine:         v1 ── v2 ── v3 ─────────── v4 (merge)    what the tools load = upstream + your refinements
```

- The git dir sits in the workspace with `core.worktree` pointing at the live folder, so the folder **is** the working tree of `mine`. There's nothing to re-point, tools never see a `.git`, and installers can overwrite files without destroying history.
- **What msl versions** is defined once (`stage` in `msl`): every file in the folder except dotfiles and dot-folders, whatever the folder's own `.gitignore` says. Every snapshot, version, and merge uses that one definition.
- Every commit on `mine` is a version and is tagged `v1`, `v2`, …. The subject says what changed; an `Upstream-Rev: <rev>` trailer records which upstream a version is based on.
- Changes in the live folder that aren't a version yet are "live edits". Each `msl` call that sees them saves them with `git stash`, so nothing unversioned can be lost. `discard` throws them away and `restore` re-applies the latest saved ones.
- **One folder.** `path` is the skill's one real folder. `links` are its other install locations (in other tools' folders), each of which should be a link to it. `add` records them; `msl link` replaces a separate copy with a link, moving the copy into `archive/copies/`. `status` flags a location that became a separate copy again (say, a reinstall with `--copy`). msl never copies files between folders.
- **Safety.** One msl command at a time for the whole workspace (a `lock/` folder holding the pid, cleared if that process is gone), so parallel sessions can't interleave and feedback ids stay unique. A pending update is applied only if the version and the folder are unchanged since the merge was prepared. A version is claimed only after git has recorded it. `--fixes` accepts only feedback on the skill being changed.

**Feedback entry.** Header fields are what msl reads and filters on; the body is free-form for people and agents.

```markdown
---
id: fb-k3x9a2-007             # workspace id + sequence: unique across people
skill: pr-review
title: Buries the real bug under style nits
version: v3                   # the version it was about (v3+edits: live edits being tried)
at: 2026-09-28T14:02Z
tool: cursor                  # cursor | codex | claude-code | …
session: ~/.meta-skill-loop/sessions/5f1c….jsonl   # copy of the conversation, when the tool keeps one
severity: P2                  # P0 | P1 | P2 | P3 | nit
status: open                  # open | applied | declined
fixed_in: v4                  # set by msl when applied; rollback reads it to reopen
---
## Asked
## Observed
## Expected
## User said
## Evidence
## Conversation               (only where no conversation file exists, e.g. Cursor)
…anything else the user wants recorded
```

| Severity | Meaning |
|---|---|
| `P0` | harmful: destroyed, overwrote, or leaked something, or ran something it shouldn't have |
| `P1` | wrong result the user had to catch |
| `P2` | worked, but badly; cost the user time (default) |
| `P3` | minor friction |
| `nit` | wording, format, taste |

- One file per entry means no append races between concurrent sessions, easy deduplication, and sharing later by copying files. `msl feedback add` is the **single writer**: it assigns ids, stamps the version and time, and validates fields.
- **Which feedback a version fixed** lives only in the entries (`fixed_in`). History, rollback, and revert read it from there, so linking an entry after the fact (`feedback mark <id> applied --fixed-in v4`) works the same as `keep --fixes`.
- **Conversations.** Tools delete old conversations (Claude Code after 30 days by default), so msl copies the file into `sessions/` (named by a hash of where it came from plus its file name) and points to the copy. Only a conversation msl can identify for certain is copied: in Claude Code, the file named by `CLAUDE_CODE_SESSION_ID`; anywhere, a file passed with `--session`. Guessing ("the newest conversation file") could attach an unrelated chat, so without an identity the agent writes the relevant exchanges into the entry instead (Cursor keeps chats in its own database; Codex's current-session identity isn't verified yet). A later feedback entry from the same conversation refreshes the same copy.

**Who else writes the folder** (decided at `add`) determines how an upstream update is recognized:

| kind | Other writer | New upstream recognized by |
|---|---|---|
| `skills-cli` | `npx skills update` | the lock-file revision differs from the last one msl saw (msl notes every revision it sees, even one that changed only a dotfile), or the folder holds a known upstream version |
| `local` | you, a skill creator, `git pull` (for a skill inside a git repo) | never: every change is a live edit to keep or discard |

A skill inside a git repo is `local` on purpose: git owns that folder's history, merges and pulls. Running a second version control over the same files (an earlier design) caused most of the bugs found in review.

**States:**

| State | Meaning |
|---|---|
| `clean` | the live folder is the current version |
| `changed` | live edits (yours, a creator tool's, a hand edit, a pull), saved automatically |
| `upstream` | an installer (update or reinstall) replaced your version in the folder; yours is safe on `mine`, and `msl update` takes it from there |
| `missing` | the folder is gone |

## 6. Flows

- **Add.** Find every install location with that name. The one real folder is the path given, else the one in `~/.agents/skills`, else the first found. Links to it and identical separate copies are recorded as `links` (the agent offers `msl link` for the copies); a different skill that shares the name is left alone. Detect the kind. Create the git dir and commit the folder as `v1` (with `Upstream-Rev` and an `upstream` branch if it has one). **The skill file is not modified.**
- **Capture.** Only when the user asks for it ("log feedback on pr-review", "feedback on grill-me: …"). The agent never logs feedback, or suggests it, on its own; automatic capture is a later opt-in (§8). Identify the skill, add it if needed, write a title, a severity, and a free-form body (asked/observed/expected/user said/evidence, trimmed, with no secrets), then `msl feedback add`, which also saves a copy of the conversation. It never edits the skill.
- **Refine.** Status must be clean. The agent reads the open feedback, writes a brief (themes, then desired behavior), and proposes the smallest edit. A skill-creator tool can draft it. After approval, the edit is applied to the live folder. Then either keep it (`msl keep --fixes …` makes the next version and marks entries applied in it) or try it first (saved automatically; later keep, or `discard`/`restore`).
- **History, revert, rollback.** `msl history` lists versions with the feedback each fixed, the upstream revision, and feedback counted per version. `msl revert <vN>` undoes one version and keeps the rest. `msl rollback <vN>` restores that version's content. Both create a new version and reopen the feedback the undone versions fixed (`fixed_in`). Rollback warns (and needs `--yes`) when it crosses an upstream merge.
- **Update.** `msl update <name>`:
  1. Bring in the new upstream: run `npx skills update` (only `skills-cli` skills have an upstream).
  2. Record it on `upstream`, then put `mine` back in the live folder, so the user's version stays live.
  3. If there are no refinements, fast-forward as the next version. Otherwise merge in a temporary worktree (`merge/`) for review: `msl diff --merge` and `--upstream`. The agent resolves conflicts by intent, then `--apply`, `--abort`, or `--take-upstream`.
  If an installer runs directly instead, status shows `upstream` and the same flow picks it up. `--check` stops after step 2: it reports and shows what upstream changed.
- **Lost live edits.** If an update or reinstall overwrites edits that were being tried out (not kept yet), status says so: they're in the stash. `msl diff --saved` previews them, and `msl restore` brings them back. The index is always left on `mine`, so a later `restore` applies cleanly.

## 7. Decisions and accepted limits (2026-09-28)

- **Skills stay in place (no central store).** Considered: moving skills into the workspace and deploying copies. Rejected: two copies of everything, a deploy step, edits made in the tool's own UI getting overwritten, and it couldn't cover skills in team repos. Review-before-update is achieved instead through `msl update`.
- **meta-skill-loop never edits a skill except to apply an approved change.** The phase-1 "nudge" line inside skills was removed.
- **Capture is explicit (0.3).** Feedback is logged only when the user asks. Considered: the agent offering to log whenever the user corrects a skill, triggered by the skill's description (it worked in 3 of 3 Claude Code runs), a line in each tool's own rules, hooks, or a line inside each managed skill. Rejected for now: unasked-for offers are noise, rules and hooks are per tool and outside a skill's scope, and editing skills breaks "skills stay untouched". The real-agent test checks that a plain correction neither logs nor suggests logging.
- **One skill (0.3).** meta-skill-loop is one skill: `SKILL.md` is the entry point and routes to `references/feedback.md` and `references/refine.md`, the shape of Anthropic's skill-creator. One thing to install, update, and remove, one description, one first-use block. Until 0.2 it was three skills (`meta-skill-loop`, `meta-skill-feedback`, `meta-skill-refine`). Neither a reinstall nor `npx skills update -g -y` removes them (the CLI asks only in a terminal), and their old descriptions still offer to log feedback unasked, so `msl` leaves them out of its lists and `msl status` shows the command to remove them. The README also tells upgraders to remove the rules line 0.2 suggested.
- **Accepted limits:**
  - Merging prose is fuzzy: the LLM proposes and the human validates.
  - A live edit applies to every session at once.
  - Change detection happens at `msl` calls, not when a skill is used; that isn't possible portably.
  - Installers run outside `msl update` put upstream live until reconciled.
  - A moved skill folder must be re-added.
  - Conversation copies can be large (megabytes for a long session); they're kept whole for now and can be trimmed later.
  - In a skill that lives in a git repo, the user's refinements are uncommitted changes in that repo, so `git pull` may ask to commit or stash first. For a team skill, send the change to the repo.
- **Designed for, not built:**
  - Publishing feedback and versions to a remote (§8, phase 2). Feedback ids are unique across workspaces for this.
  - Syncing several machines: each skill's history can be pushed to one private remote under its own branch names, with no change to the local layout.
  - A richer review UI than the chat diff.

## 7a. Distribution and releases

- **One package format.** This repo is a standard Agent Skills package: `skills/<name>/SKILL.md`. The only install is `npx skills@latest add SoulEvill/meta-skill-loop --skill meta-skill-loop --agent cursor claude-code codex -g`, the same form as the other Wendao skills: the CLI keeps one real folder in `~/.agents/skills` and links Claude Code's to it. Team and personal skill repos use the same format, so everything installs, updates, and gets managed the same way. meta-skill-loop itself is an ordinary skill: there's no special kind.
- **Self-contained skill.** `msl` ships inside the skill (`scripts/msl`). First use sets up the workspace (`scripts/msl init` from the installed skill). `~/.meta-skill-loop/bin/msl` is a launcher into the installed skill, so updating the skill updates `msl`, with no stale copy.
- **Later channels are thin wrappers.** Plugin marketplaces (Claude Code, Cursor, Codex) all accept a folder of skills, so each would be a small manifest at the repo root pointing at `skills/`. Nothing about the layout has to change.
- **Versions.** Semver in `MSL_VERSION`. A release is a tag `vX.Y.Z` on a commit already on `main`; the release workflow checks that, reruns every test, and publishes a GitHub Release with generated notes. `main` is always the latest release, and users can pin a tag.
- **Tests.**
  - Unit/e2e (`tests/run.sh`, bash 5 and macOS bash 3.2).
  - Skills lint (`tests/lint-skills.sh`).
  - A real `skills` CLI install (`tests/package.sh`).
  - All three run in CI on every push and PR.
  - Real-agent tests (`tests/agent/run.sh`) check outcomes on disk, so one script covers Claude Code, Cursor, and Codex. They're started manually by the owner, with keys stored in a protected environment.

## 8. Roadmap

- **Phase 1:** capture, add, status, refine with approval.
- **Phase 1.1 (current, releases 0.2–0.3):** per-skill git versions, keep/discard/restore, history, revert and rollback, review-gated `update`, unique feedback ids, conversation copies, no edits to skills except approved ones. The data format is versioned from here on.
- **Phase 2, publish:** `msl publish <skill>` sends a folder (the skill's latest version, the feedback entries the user approves after reviewing and redacting each section, and a small metadata file) to a remote named in `workspace.yaml`: a git repo, a synced folder, later other systems. The remote runs its own CI to aggregate everyone's feedback and publish an improved skill, which people install with the `skills` CLI and receive through `msl update`. Sending a refinement to the skill's own source as a PR is the same step with a different destination. Already in place for it: unique ids, `source_url`/`source_path`, one file per entry, a sectioned body.
- **Phase 3, learn automatically (opt-in, off by default):** a setting to capture feedback without being asked, for all skills or chosen ones (for example, offering to log when the user corrects a skill). The setting will live in `workspace.yaml` (`capture: explicit`, the meaning when it's absent, so today's workspaces need no migration) and per skill in `skill.yaml`. A skill's description is fixed text and can't read a setting, so the mechanism is still to choose: a hook per tool (deterministic, but tool-specific and outside the Agent Skills standard), or a broader description plus a check of the setting before offering. Observers log candidates (`origin: observed`, `confidence`, a `candidate` status; old entries count as explicit), measured against the explicit entries.
- **Later, not designed yet:** a golden dataset and evals built from feedback (what was asked, what we want, what we don't).

## 9. Prior art (2026-09)

| Project | Overlap | Gap |
|---|---|---|
| [Task Observer](https://github.com/rebelytics/one-skill-to-rule-them-all) | observes sessions, logs corrections, proposes skill improvements | Claude-centric; no source tracking, update merge, or contribution back |
| [claude-reflect](https://github.com/BayramAnnakov/claude-reflect) | captures corrections via hooks; `/reflect` applies them | Claude only; writes to CLAUDE.md, not per skill |
| [claude-reflect-system](https://github.com/haddock-development/claude-reflect-system), [singularity-claude](https://github.com/Shmayro/singularity-claude) | edit skills in place from corrections or scores | Claude only; no upstream story |
| [retro-skill](https://github.com/netresearch/retro-skill) | PRs learnings to the skill's source repo | Claude only; no per-skill store or merge |
| [Hermes Agent](https://github.com/nousresearch/hermes-agent) | self-editing skills with a hash lock | locally edited skills skip updates forever; merge only proposed |
| [`skills` CLI](https://github.com/vercel-labs/skills), openskills, skillkit | install/update across many agents | update overwrites local edits |
| [Anthropic skill-creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md) | eval → feedback → improve loop | authoring time, not in-use feedback |

Capture and in-place refinement are well covered, mostly for Claude Code only. Keeping refinements mergeable across upstream updates, and sending evidence-backed changes back to the source, are essentially unaddressed. That's where meta-skill-loop aims to be useful, across all three tools.
