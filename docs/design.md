# meta-skill-loop: design

Status: v1.1 · 2026-09-28

## 1. Problem

People accumulate agent skills: their own, their team's, public ones. Skills misbehave in small ways, such as asking too many questions or burying the important finding under nits. The fix is usually a one-line tweak, but the feedback is given in the moment and then lost. Nothing collects it per skill, keeps the evidence, or turns it into an improvement later. And most people use more than one agent tool.

## 2. What meta-skill-loop is (and isn't)

It is a **management layer for the feedback loop around skills**:

1. **Add**: enroll skills you already have, wherever they live.
2. **Capture**: mid-use, "feedback on this skill" writes a structured entry with evidence.
3. **Refine**: later, turn accumulated feedback into the smallest approved edit, with a record of why.
4. **Version**: every kept change is a version you can compare or roll back; upstream updates are merged with your changes for review instead of overwriting them.
5. **Status**: see every managed skill, its version, its open feedback, and anything that needs attention.

It is **not** a skill authoring tool (use Cursor `/create-skill`, Anthropic's `skill-creator`, or an editor), **not** an installer or package manager (use the [`skills` CLI](https://github.com/vercel-labs/skills) or copy folders), and **not** a place to host skills. It holds only its own data.

## 3. How it fits with sharing skills and personal hubs

| Layer | Job | Where it lives |
|---|---|---|
| **meta-skill-loop** | feedback, refine, versions, reviewed updates, status; (v2) contribute | this public repo + `~/.meta-skill-loop/` per user |
| **Packs** | share skills: one git repo per *audience* (team, personal, public), not one per skill | their own repos; installed per skill with `npx skills add <repo> --skill <name> --copy -g` |
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
- Skills are **managed in place**, never moved or symlinked, and meta-skill-loop's own skills are installed by **copy**.
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
  skills/<name>/
    skill.yaml                       name, kind (local|skills-cli|git), source_url, source_path, added, paths (primary first)
    git/                             the skill's version history (git dir; its working tree is the live skill folder)
    feedback/fb-k3x9a2-007.md        one file per entry
    merge/                           only while an upstream merge waits for review (a temporary git worktree)
  archive/                           data of skills you stopped managing
```

**One git repo per skill, two branches** (the classic "vendor branch" pattern):

```
  upstream:  U1 (abc123) ───────────── U2 (def456)      pristine published versions only (not for local skills)
               \                         \
  mine:         v1 ── v2 ── v3 ─────────── v4 (merge)    what the tools load = upstream + your refinements
```

- The git dir sits in the workspace with `core.worktree` pointing at the live folder, so the folder **is** the working tree of `mine`. There's nothing to re-point, tools never see a `.git`, and installers can overwrite files without destroying history. Dotfiles are ignored.
- Every commit on `mine` is a version and is tagged `v1`, `v2`, …. The subject says what changed; an `Upstream-Rev: <rev>` trailer records which upstream a version is based on.
- Changes in the live folder that aren't a version yet are "live edits". Each `msl` call that sees them saves them with `git stash`, so nothing unversioned can be lost. `discard` throws them away and `restore` re-applies the latest saved ones.
- **Copies.** A skill installed in several tool folders (the `skills` CLI puts one in `~/.agents/skills` and one in `~/.claude/skills`) is one managed skill with several `paths`. msl keeps them identical. An edit in any one copy is a live edit: that copy becomes the primary (the repo's working tree), and keeping it updates the others. Two copies edited differently are a conflict (`copies-differ`) that the user resolves with `keep --from <path>`.

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
- **Conversations.** Tools delete old conversations (Claude Code after 30 days by default), so msl copies the file into `sessions/` and points to the copy. Claude Code: the file named by `CLAUDE_CODE_SESSION_ID`, else the newest one for the current folder in `~/.claude/projects/`. Codex: the newest `~/.codex/sessions/**/rollout-*.jsonl`. Cursor keeps chats in its own database, so the agent writes the relevant exchanges into the entry instead. A later feedback entry from the same conversation refreshes the same copy.

**Who else writes the folder** (decided at `add`) determines how an upstream update is recognized:

| kind | Other writer | New upstream recognized by |
|---|---|---|
| `local` | nobody | never: every change is yours |
| `skills-cli` | `npx skills update` | lock-file revision not yet recorded on `upstream` |
| `git` | `git pull`, teammates | the last commit touching the folder isn't recorded yet |

**States:**

| State | Meaning |
|---|---|
| `clean` | the live folder is the current version |
| `changed` | live edits (yours, a creator tool's, a hand edit, in any copy), saved automatically |
| `upstream-update` | an installer or pull put a **new** upstream version in place; yours is safe on `mine` |
| `upstream-live` | an already-known upstream version was put back (e.g. a reinstall); your refinements aren't live |
| `copies-differ` | two installed copies were edited differently |
| `missing` | every copy of the folder is gone |

## 6. Flows

- **Add.** Find every installed copy with that name (only identical ones: a different skill that shares the name is left alone); the first is primary, the others are kept in sync. Detect the kind. Create the git dir and commit the folder as `v1` (with `Upstream-Rev` and an `upstream` branch if it has one). **The skill file is not modified.**
- **Capture.** Identify the skill, add it if needed, write a title, a severity, and a free-form body (asked/observed/expected/user said/evidence, trimmed, with no secrets), then `msl feedback add`, which also saves a copy of the conversation. It never edits the skill. The agent offers capture after a correction because of one line the user adds once to their tool's own rules (the README and the hub skill give it). meta-skill-loop no longer inserts anything into skills.
- **Refine.** Status must be clean. The agent reads the open feedback, writes a brief (themes, then desired behavior), and proposes the smallest edit. A skill-creator tool can draft it. After approval, the edit is applied to the live folder. Then either keep it (`msl keep --fixes …` makes the next version and marks entries applied in it) or try it first (saved automatically; later keep, or `discard`/`restore`).
- **History, revert, rollback.** `msl history` lists versions with the feedback each fixed, the upstream revision, and feedback counted per version. `msl revert <vN>` undoes one version and keeps the rest. `msl rollback <vN>` restores that version's content. Both create a new version and reopen the feedback the undone versions fixed (`fixed_in`). Rollback warns (and needs `--yes`) when it crosses an upstream merge.
- **Update.** `msl update <name>`:
  1. Bring in the new upstream. For `skills-cli`, it runs `npx skills update`. For `git`, the user pulls as usual.
  2. Record it on `upstream`, then put `mine` back in the live folder, so the user's version stays live.
  3. If there are no refinements, fast-forward as the next version. Otherwise merge in a temporary worktree (`merge/`) for review: `msl diff --merge` and `--upstream`. The agent resolves conflicts by intent, then `--apply`, `--abort`, or `--take-upstream`.
  If an installer runs directly instead, status shows `upstream-update` and the same flow picks it up. `--check` stops after step 2: it reports and shows what upstream changed.
- **Lost live edits.** If an update or reinstall overwrites edits that were being tried out (not kept yet), status says so: they're in the stash. `msl diff --saved` previews them, and `msl restore` brings them back. The index is always left on `mine`, so a later `restore` applies cleanly.

## 7. Decisions and accepted limits (2026-09-28)

- **Skills stay in place (no central store).** Considered: moving skills into the workspace and deploying copies. Rejected: two copies of everything, a deploy step, edits made in the tool's own UI getting overwritten, and it couldn't cover skills in team repos. Review-before-update is achieved instead through `msl update`.
- **meta-skill-loop never edits a skill except to apply an approved change.** The v1 "nudge" line was removed in favor of one line in the tool's own rules.
- **Accepted limits:**
  - Merging prose is fuzzy: the LLM proposes and the human validates.
  - A live edit applies to every session at once.
  - Change detection happens at `msl` calls, not when a skill is used; that isn't possible portably.
  - Installers run outside `msl update` put upstream live until reconciled.
  - A moved skill folder must be re-added.
  - Conversation copies can be large (megabytes for a long session); they're kept whole for now and can be trimmed later.
  - In a skill that lives in a team git repo, the user's refinements are uncommitted changes in that repo, so `git pull` may ask to commit or stash first.
- **Designed for, not built:**
  - Publishing feedback and versions to a remote (§8, v2). Feedback ids are unique across workspaces for this.
  - Syncing several machines: each skill's history can be pushed to one private remote under its own branch names, with no change to the local layout.
  - A richer review UI than the chat diff.

## 7a. Distribution and releases

- **One package format.** This repo is a standard Agent Skills package: `skills/<name>/SKILL.md`. The only install is `npx skills add SoulEvill/meta-skill-loop -g --copy` (without Node, copying the folders does the same). Team and personal skill repos use the same format, so everything installs, updates, and gets managed the same way. meta-skill-loop's own skills are ordinary managed skills: there's no special kind.
- **Self-contained skills.** `msl` ships inside the `meta-skill-loop` skill. Any of the three skills sets up the workspace on first use (`scripts/msl init` from the installed hub skill). `~/.meta-skill-loop/bin/msl` is a launcher into the installed skill, so updating the skill updates `msl`, with no stale copy.
- **Later channels are thin wrappers.** Plugin marketplaces (Claude Code, Cursor, Codex) all accept a folder of skills, so each would be a small manifest at the repo root pointing at `skills/`. Nothing about the layout has to change.
- **Versions.** Semver in `MSL_VERSION`. A release is a tag `vX.Y.Z` on a commit already on `main`; the release workflow checks that, reruns every test, and publishes a GitHub Release with generated notes. `main` is always the latest release, and users can pin a tag.
- **Tests.**
  - Unit/e2e (`tests/run.sh`, bash 5 and macOS bash 3.2).
  - Skills lint (`tests/lint-skills.sh`).
  - A real `skills` CLI install (`tests/package.sh`).
  - All three run in CI on every push and PR.
  - Real-agent tests (`tests/agent/run.sh`) check outcomes on disk, so one script covers Claude Code, Cursor, and Codex. They're started manually by the owner, with keys stored in a protected environment.

## 8. Roadmap

- **v1:** capture, add, status, refine with approval.
- **v1.1 (current):** per-skill git versions, keep/discard/restore, history, revert and rollback, review-gated `update`, unique feedback ids, conversation copies, no edits to skills except approved ones. The data format is versioned from here on.
- **v2, publish:** `msl publish <skill>` sends a folder (the skill's latest version, the feedback entries the user approves after reviewing and redacting each section, and a small metadata file) to a remote named in `workspace.yaml`: a git repo, a synced folder, later other systems. The remote runs its own CI to aggregate everyone's feedback and publish an improved skill, which people install with the `skills` CLI and receive through `msl update`. Sending a refinement to the skill's own source as a PR is the same step with a different destination. Already in place for it: unique ids, `source_url`/`source_path`, one file per entry, a sectioned body.
- **v3, learn automatically:** observers log candidates (`origin: observed`, `confidence`, a `candidate` status; old entries count as explicit), measured against the explicit entries.
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
