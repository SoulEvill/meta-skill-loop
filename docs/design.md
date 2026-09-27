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

## 5. Data model (v1.1)

```
~/.meta-skill-loop/                  local only; can hold private evidence, so never push it publicly
  workspace.yaml                     id: k3x9 (random, created once), used in feedback ids
  bin/msl
  skills/<name>/
    skill.yaml                       name, kind (local|skills-cli|git|framework), source, added, paths (primary first)
    git/                             the skill's version history (git dir; its working tree is the live skill folder)
    feedback/fb-k3x9-007.md          one file per entry
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
- Every commit on `mine` is a version and is tagged `v1`, `v2`, …. Commit trailers record why: `Fixes: fb-…`, `Upstream-Rev: <rev>`, `Reverts: vN`, `Rollback-To: vN`, `Resolved-Upstream: fb-…`.
- Uncommitted edits in the live folder are "live edits". Each `msl` call that sees them saves them with `git stash`, so nothing unversioned can be lost. `undo` discards them and `redo` re-applies the latest saved ones.

**Feedback entry.**

```markdown
---
id: fb-k3x9-007
skill: pr-review
version: v3                   # or v3+edits: the version the feedback was about
at: 2026-09-28T14:02Z
tool: cursor
project: payments-api
origin: explicit              # explicit | observed
confidence: high              # high | medium | low
severity: annoying            # nit | annoying | wrong
status: open                  # candidate | open | applied | declined | resolved-upstream
resolution: v4                # set when applied/declined/reopened
---
- asked / observed / expected / user said / evidence
```

One file per entry means no append races between concurrent sessions, and easy deduplication. `msl feedback add` is the **single writer**: it assigns ids, stamps the version and time, and validates fields, whether the caller is the feedback skill today or an observer later.

**Who else writes the folder** (decided at `add`) determines how an upstream update is recognized:

| kind | Other writer | New upstream recognized by |
|---|---|---|
| `local` | nobody | never: every change is yours |
| `skills-cli` | `npx skills update` | lock-file revision not yet recorded on `upstream` |
| `git` | `git pull`, teammates | the last commit touching the folder isn't recorded yet |
| `framework` | `install.sh` | install records the new version itself |

**States:**

| State | Meaning |
|---|---|
| `clean` | the live folder is the current version |
| `changed` | live edits (yours, a creator tool's, a hand edit), saved automatically |
| `upstream-update` | an installer or pull put a **new** upstream version in place; yours is safe on `mine` |
| `upstream-live` | an already-known upstream version was put back (e.g. a reinstall); your refinements aren't live |
| `copies-differ` | the same skill in several tool folders no longer matches |
| `missing` | folder gone |

## 6. Flows

- **Add.** Find every installed copy with that name; the first is primary, the others are mirrors kept in sync. Detect the kind. Create the git dir and commit the folder as `v1` (with `Upstream-Rev` and an `upstream` branch if it has one). **The skill file is not modified.**
- **Capture.** Identify the skill, add it if needed, write asked/observed/expected/user-said/evidence (trimmed, with no secrets), then `msl feedback add`. It never edits the skill. The agent offers capture after a correction because of one line the user adds once to their tool's own rules (installer prints it). meta-skill-loop no longer inserts anything into skills.
- **Refine.** Status must be clean. The agent reads the open feedback, writes a brief (themes, then desired behavior), and proposes the smallest edit. A skill-creator tool can draft it. After approval, the edit is applied to the live folder. Then either keep it (`msl keep --fixes …` makes the next version and marks entries applied) or try it first (saved automatically; later keep, or `undo`/`redo`).
- **History and rollback.** `msl history` lists versions with fixes, the upstream revision, and feedback counted per version. `msl rollback <v>` restores that version as a new version and reopens the feedback that the undone versions fixed. It warns (and needs `--yes`) when that crosses an upstream merge. `--only` reverts a single version.
- **Update.** `msl update <name>`:
  1. Bring in the new upstream. For `skills-cli`, it runs `npx skills update`. For `git`, the user pulls as usual.
  2. Record it on `upstream`, then put `mine` back in the live folder, so the user's version stays live.
  3. If there are no refinements, fast-forward as the next version. Otherwise merge in a temporary worktree (`merge/`) for review: `msl diff --merge` and `--upstream`. The agent resolves conflicts by intent, then `--apply`, `--abort`, or `--take-upstream`.
  If an installer runs directly instead, status shows `upstream-update` and the same flow picks it up.

## 7. Decisions and accepted limits (2026-09-28)

- **Skills stay in place (no central store).** Considered: moving skills into the workspace and deploying copies. Rejected: two copies of everything, a deploy step, edits made in the tool's own UI getting overwritten, and it couldn't cover skills in team repos. Review-before-update is achieved instead through `msl update`.
- **meta-skill-loop never edits a skill except to apply an approved change.** The v1 "nudge" line was removed in favor of one line in the tool's own rules.
- **Accepted limits:**
  - Merging prose is fuzzy: the LLM proposes and the human validates.
  - A live edit applies to every session at once.
  - Change detection happens at `msl` calls, not when a skill is used; that isn't possible portably.
  - Installers run outside `msl update` put upstream live until reconciled.
  - A moved skill folder must be re-added.
- **Designed for, not built:**
  - A team feedback layer: an opt-in shared repo, explicit sharing, and views merging local and team entries. Feedback ids are already unique across workspaces for this.
  - Syncing several machines.
  - A richer review UI than the chat diff.

## 8. Roadmap

- **v1:** capture, add/scan, status, refine with approval.
- **v1.1 (current):** per-skill git versions, keep/undo/redo, history, rollback, review-gated `update`, unique feedback ids, no edits to skills except approved ones.
- **v2:** `contribute`: a refinement becomes a PR (or issue) to the skill's source, with redacted evidence.
- **v3, learn automatically:** observers write `origin: observed` candidates for triage, measured against the explicit entries.

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
