# meta-skill-loop: design

Status: v1 · 2026-09-27

## 1. Problem

People accumulate agent skills: their own, their team's, public ones. Skills misbehave in small ways, such as asking too many questions or burying the important finding under nits. The fix is usually a one-line tweak, but the feedback is given in the moment and then lost. Nothing collects it per skill, keeps the evidence, or turns it into an improvement later. And most people use more than one agent tool.

## 2. What meta-skill-loop is (and isn't)

It is a **management layer for the feedback loop around skills**:

1. **Add**: enroll skills you already have, wherever they live.
2. **Capture**: mid-use, "feedback on this skill" writes a structured entry with evidence.
3. **Refine**: later, turn accumulated feedback into the smallest approved edit, with a record of why.
4. **Status**: see every managed skill, its open feedback, and anything that needs attention.

It is **not** a skill authoring tool (use Cursor `/create-skill`, Anthropic's `skill-creator`, or an editor), **not** an installer or package manager (use the [`skills` CLI](https://github.com/vercel-labs/skills) or copy folders), and **not** a place to host skills. It holds only its own data.

## 3. How it fits with sharing skills and personal hubs

| Layer | Job | Where it lives |
|---|---|---|
| **meta-skill-loop** | feedback, refine, status, (v2) update-merge and contribute | this public repo + `~/.meta-skill-loop/` per user |
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

```
~/.meta-skill-loop/                 local git repo: history and undo; never push publicly
  bin/msl
  skills/<name>/
    skill.yaml                      name, ownership (own|upstream), source, added, paths (primary first)
    feedback/fb-0007.md             one file per entry
    changes.md                      ch-0001…: every change, with the feedback ids it addresses
    base/                           upstream version last taken (pristine)
    current/                        intended version: base + your refinements
  archive/                          data of skills you stopped managing
```

**Feedback entry.**

```markdown
---
id: fb-0007
skill: pr-review
skill_hash: 3f9a1c0b2d4e      # version the feedback was about
at: 2026-09-28T14:02Z
tool: cursor
project: payments-api
origin: explicit              # explicit | observed
confidence: high              # high | medium | low
severity: annoying            # nit | annoying | wrong
status: open                  # candidate | open | applied | declined | resolved-upstream
resolution: ch-0003           # set when applied/declined
---
- asked / observed / expected / user said / evidence
```

One file per entry means no append races between concurrent sessions, and easy deduplication. `msl log` is the **single writer**: it assigns ids, stamps hashes and times, and validates fields, whether the caller is the feedback skill today or an observer later.

**State** compares *live* (on disk) with *current* and *base*:

| live = current | live = base | state | meaning |
|---|---|---|---|
| yes | – | `clean` (or `copies-differ` if other installed copies don't match) | |
| no | yes | `reverted` | an update/reinstall overwrote your refinements |
| no | no | `changed` | edited outside msl, or a new upstream version landed |
| – | – | `missing` | folder gone |

## 6. Flows

- **Add.** Find every installed copy with that name. Detect the source from `~/.agents/.skill-lock.json` (which makes it `upstream`), otherwise `own`. Snapshot `base`, insert the nudge line, snapshot `current`, and log `ch-0001`.
- **Nudge.** One line after the frontmatter: *"If the user gives feedback on how this skill behaved, log it with the `meta-skill-feedback` skill."* It's the portable stand-in for a hook. Capture also works without it, because the feedback skill triggers on its own description.
- **Capture.** Identify the skill, add it if needed, write asked/observed/expected/user-said/evidence (trimmed, with no secrets), then `msl log`. It never edits the skill.
- **Refine.** `msl show`, then group feedback into themes (flagging entries whose `skill_hash` is stale), propose the smallest diff, and wait for approval. Edit in place, then `msl commit --fixes …`, which snapshots `current`, propagates to other copies, logs the change, and marks entries `applied`.
- **Updates (v1).** Reinstalling or `skills update` overwrites in place, so status shows `reverted` and the change log says what to re-apply. `install.sh` refuses to overwrite a refined meta-skill-loop skill.

## 7. Next: versioning and the update lifecycle (agreed 2026-09-28, not built yet)

This replaces the v1 data model in §5 (`base/`, `current/`, `changes.md`) once built.

**One git repo per managed skill, two branches (the classic "vendor branch" pattern).**

```
~/.meta-skill-loop/skills/grilling/git/       git dir, kept in the workspace
    working tree = the live skill folder       (e.g. ~/.claude/skills/grilling; nothing is moved)

  upstream:  U1 (abc123) ───────────── U2 (def456)     pristine published versions only
               \                         \
  mine:         v1 ── v2 ── v3 ─────────── v4 (merge)   what the tools load = upstream + your refinements
```

- The live folder always holds `mine`. Changes are never applied to upstream, and there is nothing to re-point. `upstream` exists only for skills someone else publishes.
- The git dir lives outside the skill folder, so tools never see a `.git`, and installers can overwrite files without destroying history.
- Feedback stays as plain files next to the git dir. The workspace-wide git repo goes away.

| Need | Git feature |
|---|---|
| a change being tried (uncommitted) | working-tree changes |
| a version (v1, v2, …) | commit on `mine`, tag `vN` |
| why a version exists | commit trailers: `Fixes: fb-k3x9-001` |
| protect a trial from being overwritten | `git stash` (refine stores the trial as a stash entry) |
| undo a trial | `git restore` |
| undo one change / go back to a version | `git revert vN` / check out vN's files and commit |
| upstream released something new | new commit on `upstream`, trailer `Upstream-Rev: <rev>` |
| reconcile | `git merge upstream` into `mine`, done in a temporary worktree so the live skill never holds conflict markers |
| history | `git log` on `mine` |

**Commands.** Users speak; agents call `msl`.

| Say | `msl` | Version? |
|---|---|---|
| "feedback on X: …" | `feedback` (renamed from `log`) | no |
| "status" | `status` | no |
| "what changed?" | `diff` | no |
| "keep it" | `commit -m … --fixes …` | yes |
| "undo that" | `restore` | no |
| "show versions" | `history` (with feedback counted per version, to spot regressions) | no |
| "undo v2" / "go back to v1" | `rollback` (revert one version, or restore one; reopens the feedback those versions fixed; warns when crossing an upstream merge) | yes |
| "update X" | `update`: runs the installer into a scratch dir, records it on `upstream`, merges, shows the diff, applies only after approval | yes |

**Who else writes the folder** (decides how an upstream update is detected):

| Skill lives in | Other writer | Detection |
|---|---|---|
| a plain folder you made | nobody | no upstream; any change is yours (uncommitted until "keep it") |
| a folder installed by the `skills` CLI | `npx skills update` | lock-file revision differs from the last `Upstream-Rev` |
| a git repo (work repo, pack repo) | `git pull`, teammates | the last commit touching the folder changed. Your own repo: refinements also become commits there. A team repo: treated as upstream, and good changes go back as PRs. |
| anything else (plugins, downloads) | unknown | ask the user |

**Updates.** An installer run directly (`npx skills update`, `git pull`) replaces the live files at once, so the new upstream version is what runs until reconciled. Your versions stay safe on `mine`. meta-skill-loop can't intercept this, since there are no cross-tool hooks. It detects the change on the next `msl` call of any kind, then offers to reconcile, restore your version, or take upstream. The recommended path is `meta-skill-loop update X`, which reviews the update before anything goes live.

**Feedback ids:** `fb-<workspace id>-<seq>`, e.g. `fb-k3x9-001`. The workspace id is random and created once. Ids stay ordered locally and unique across workspaces.

**Designed for, not built:**
- A team feedback layer: an opt-in shared repo, explicit sharing, and views that merge local and team entries.
- Syncing several machines.
- A richer review UI than the chat diff.

**Known limits, accepted:**
- Merging prose is fuzzy: the LLM proposes and the human validates.
- Trying a change affects every session at once.
- Change detection happens at `msl` calls, not when a skill is used.
- Copies in several tool folders are mirrored from the primary copy.
- A moved skill folder must be re-pointed.

**Open question:** keep skills in place (A, recommended) or move them into a central store and deploy copies (B)? See `docs/handoff.md`.

## 8. Roadmap

- **v1 (built):** everything in §1–6.
- **v1.1:** §7: per-skill git versioning, the review-gated `update`, rollback, the new ids.
- **v2:** `contribute`: a refinement becomes a redacted PR to the skill's source.
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
