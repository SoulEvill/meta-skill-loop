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

## 7. Roadmap

- **v1:** everything above.
- **v2, survive updates:** `msl update <name>` runs a three-way merge (`git merge-file current base new`). Conflicts are resolved by *intent*, using `changes.md` and the feedback ids, and local changes the new upstream already covers are dropped (`resolved-upstream`). `contribute` turns a refinement into a PR to the skill's own source, with redacted evidence.
- **v3, learn automatically:** observers (session review à la Task Observer, correction detection à la claude-reflect, tool hooks where available) call `msl log --origin observed`, which creates `candidate` entries you triage. v1's explicit entries serve as ground truth for measuring observer precision.

## 8. Prior art (2026-09)

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
