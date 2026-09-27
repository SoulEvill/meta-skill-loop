# meta-skill-loop

**A feedback loop for your agent skills.** Log feedback on any skill while you use it, keep it with evidence, and later turn it into small, approved improvements. It works the same in **Cursor, Codex, and Claude Code**.

```
use a skill ──► "feedback on pr-review: too many style nits"
                      │  meta-skill-feedback writes a structured entry with evidence
                      ▼
          ~/.meta-skill-loop/skills/pr-review/feedback/fb-0012.md
                      │  …entries accumulate…
                      ▼
"refine pr-review" ──► themes → smallest diff → you approve → applied in place, change logged
```

- **Manages skills where they already live.** Nothing is moved or symlinked. Add the skills you already have in `~/.cursor/skills`, `~/.agents/skills`, `~/.claude/skills`, or a repo's `.cursor/skills`.
- **Holds only its own data.** Which skills are managed, feedback entries, snapshots, and a change log live in `~/.meta-skill-loop/`, a local git repo, so every refinement can be seen and undone.
- **Portable by construction.** It uses plain `SKILL.md` skills (only `name` and `description` frontmatter) and one bash script (`msl`, bash 3.2+, git). No hooks, plugins, or tool-specific features.
- **Explicit first.** v1 captures feedback when you ask. The entry format already distinguishes `explicit` from `observed` entries, so automatic learning can plug in later without changing anything else.

## Install

```sh
git clone https://github.com/SoulEvill/meta-skill-loop
meta-skill-loop/install.sh            # Cursor + Codex (~/.agents/skills)
meta-skill-loop/install.sh --claude   # also Claude Code (~/.claude/skills)
```

The installer copies three skills into your tools' skill folders, creates `~/.meta-skill-loop/`, and installs `msl` there. Re-run it to update. It won't overwrite a meta-skill-loop skill you've refined.

**Codex:** its sandbox blocks writes outside your project by default. To let skills log feedback, add the workspace to `~/.codex/config.toml`:

```toml
[sandbox_workspace_write]
writable_roots = ["/Users/you/.meta-skill-loop"]
```

## Use it

Talk to your agent:

| Say | What happens |
|---|---|
| "meta-skill-loop add" | lists skills you have that aren't managed yet, and adds the ones you pick |
| "feedback on grill-me: it asks way too many questions" | logs an entry with what you asked, what happened, what you expected, and evidence |
| "meta-skill-loop status" | managed skills, open feedback, and anything needing attention |
| "refine grill-me" | groups the feedback into themes, proposes the smallest edit, applies it after you approve |

Adding a skill inserts one line after its frontmatter that asks the agent to offer logging when you correct it. Capture works without that line too (`--no-nudge` skips it).

### The skills

| Skill | Job |
|---|---|
| `meta-skill-loop` | status, add/scan, details, remove, triage |
| `meta-skill-feedback` | capture one piece of feedback with evidence; never edits the skill |
| `meta-skill-refine` | feedback → proposed edit → your approval → applied and recorded |

### `msl` (what the skills call; you can too)

```
msl status [name]            msl scan               msl add <name|path> [--own|--upstream]
msl log <name> < body        msl show <name>        msl commit <name> -m <summary> --fixes fb-0001
msl mark <fb-id> <status>    msl path <name>        msl set <name> ownership|source <value>
msl diff <name> [--refinements]                     msl nudge <name>       msl remove <name>
```

## How it thinks about skills

- **Ownership.** `own` skills are yours and are refined directly. `upstream` skills are published elsewhere, for example installed with the [`skills` CLI](https://github.com/vercel-labs/skills), whose lock file meta-skill-loop reads to record the source. They're still refined in place, but an update can overwrite your changes. Status then shows `reverted`, and the change log says what to re-apply. Merging automatically across updates is v2.
- **State.** Each skill has three versions: *base* (the last upstream you took), *current* (base plus your refinements), and *live* (on disk). Comparing them gives `clean`, `changed`, `reverted`, `copies-differ`, or `missing`.
- **Feedback entries** are one file each, with frontmatter: `skill_hash` (which version it was about), `tool`, `project`, `origin` (explicit/observed), `confidence`, `severity` (nit/annoying/wrong), and `status` (candidate/open/applied/declined/resolved-upstream).
- **Privacy.** Feedback can contain work details. The workspace is local; never push it anywhere public.

## Roadmap

- **v1 (now):** install for Cursor/Codex/Claude Code; add/scan; explicit feedback; status; refine with approval.
- **v2:** survive updates: three-way merge of your refinements onto a new upstream version; `contribute` a refinement back to the skill's source as a PR with redacted evidence.
- **v3:** learn automatically: observers that write `observed` candidates (session review, correction detection, tool hooks where available), plus triage.

See [docs/design.md](docs/design.md) for the full design and prior art.

## Develop

```sh
tests/run.sh                          # end-to-end, in a throwaway $HOME
TEST_BASH=/bin/bash tests/run.sh      # on macOS: check bash 3.2 compatibility
shellcheck install.sh tests/run.sh skills/meta-skill-loop/scripts/msl
```

MIT licensed.
