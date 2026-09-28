# Maintaining meta-skill-loop

How releases, CI, and repository protection work. Reference material: if it disagrees with the workflows in `.github/`, the workflows win.

## How a change reaches users

1. **Work on a branch, open a PR to `main`.** CI runs on every push and PR:
   - `lint`: shellcheck, plus `tests/lint-skills.sh` (skills stay portable).
   - `test`: the end-to-end suite on Ubuntu and on macOS's bash 3.2.
   - `package`: a real `npx skills add` of the repo, for Cursor, Codex, and Claude Code, on Ubuntu and macOS.
2. **Merge to `main`** once CI is green and you've reviewed it.
3. **Release:** bump `MSL_VERSION` in `skills/meta-skill-loop/scripts/msl` (semver), merge that, then tag the merge commit and push the tag:
   ```sh
   git tag v0.2.0 && git push origin v0.2.0
   ```
   The `release` workflow refuses a tag that isn't on `main` or doesn't match `MSL_VERSION`. It reruns all tests and publishes a GitHub Release with generated notes.

Users install from `main` with the README's command (`npx skills@latest add SoulEvill/meta-skill-loop --skill '*' --agent cursor claude-code codex -g`) or pin a tag (`SoulEvill/meta-skill-loop#v0.2.0`), and update with `npx skills@latest update -g`.

## Real-agent tests (manual)

`tests/agent/run.sh <agent>` installs the package and a fixture skill in a throwaway home, drives a real agent with plain-language prompts, and checks the results on disk (feedback written, skill untouched, status and versions, no action on unrelated prompts).
- Claude Code has been verified.
- Cursor and Codex use the same checks but are marked experimental until they've been run with keys.

To run it from GitHub:
1. Settings → Environments → **New environment** `agent-tests`. Optionally add yourself under **Required reviewers**, so every run waits for your approval.
2. In that environment, add the secrets you have: `ANTHROPIC_API_KEY`, `CURSOR_API_KEY`, `OPENAI_API_KEY`.
3. Actions → **agent-tests** → **Run workflow**, then choose the agent.

The workflow only runs when started by the repository owner, and fork PRs can never trigger it or read its secrets. Each run costs a handful of model calls.

## Repository protection (settings to click once)

Public repo means anyone can read, fork, and open PRs, but only people you add can push. These settings make sure nothing reaches `main` or a release without you.

**Settings → Rules → Rulesets → New branch ruleset** named `main`:
- **Enforcement status:** Active.
- **Target branches:** include the default branch.
- **Bypass list:** leave it empty, so the rules apply to you too. Or add yourself if you want an emergency override.
- **Restrict deletions** and **Block force pushes.**
- **Require a pull request before merging.** Set 0 required approvals if you work alone, or 1 or more once there are other maintainers. Turn on **Require review from Code Owners** (`.github/CODEOWNERS` names you).
- **Require status checks to pass:** add `lint`, `test (ubuntu-latest, bash)`, `test (macos-latest, /bin/bash)`, `package (ubuntu-latest)`, and `package (macos-latest)`. They appear after the first CI run on a PR.

**Settings → Rules → Rulesets → New tag ruleset** named `releases`:
- **Target tags:** `v*`.
- **Restrict creations, updates, and deletions.**
- **Bypass list:** only you. Only you can publish a release.

**Settings → Actions → General:**
- **Fork pull request workflows from outside collaborators:** "Require approval for all external contributors". CI on a stranger's PR then waits until you click Approve and run.
- **Workflow permissions:** "Read repository contents and packages permissions" (the default read-only token), and leave "Allow GitHub Actions to create and approve pull requests" off. The release workflow asks for write access itself.

**Settings → Code security:** turn on Dependabot alerts and **Private vulnerability reporting**. `.github/dependabot.yml` keeps the Actions versions current.

Why the workflows are safe on a public repo:
- CI uses `pull_request`, never `pull_request_target`, so code from forks runs with a read-only token and no secrets.
- Only `release` can write, and only on a protected tag.
- Only `agent-tests` sees API keys; it's manual and owner-only.

## Adding a distribution channel later

The repo layout is already what plugin marketplaces expect: a folder of standard skills.
- Adding Claude Code, Cursor, or Codex marketplace support means adding that channel's small manifest at the repo root, pointing at `skills/`.
- Add a CI job that validates the manifest.
- The skills, `msl`, and the tests stay as they are.
