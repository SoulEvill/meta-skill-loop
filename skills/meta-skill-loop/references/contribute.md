# Send a change upstream

Offer the user's refinements of a skill back to its source, as an issue or a pull request. Do this only because the user asked. Nothing is posted until the user approves the exact text. Run `msl` as SKILL.md says.

## Steps

1. **Check there's something to send.**
   - `msl status <name>`: the kind must be `skills-cli`; only those have a known source. For any other skill, show `msl diff <name> v1` so the user can share the change their own way, and stop.
   - `msl update <name> --check`. If upstream has changed, take the update first (Updates, in SKILL.md), or the patch would undo the author's newer changes.
   - `msl diff <name> --upstream`. Its header names the source repo and the skill's folder in it; the rest is the user's changes as a patch. If there's no change, there's nothing to send.

2. **Issue or pull request.** Recommend an issue unless the user asked for a PR: it needs no fork, and many authors prefer to make the change themselves. A PR needs the GitHub CLI (`gh auth status` succeeds).

3. **Draft it, and show it.**
   - **Title:** the problem, in one line.
   - **Body:** what went wrong, in your own words from the feedback (`msl feedback list <name> --all`); the change and why it helps; the patch in a `diff` block. If the patch has binary files (`GIT binary patch`), prefer a PR, or have the user attach those files to the issue.
   - Never paste feedback entries or conversation copies, and leave out anything private: names, paths, company or customer details. The repository may be public.
   - Show the exact title and body. Post only after the user approves them.

4. **Post it.** `<owner>/<repo>` comes from the source URL in the diff header.
   - **Issue, with `gh`:** `gh issue create --repo <owner>/<repo> --title "<title>" --body-file <file>`.
   - **Issue, without `gh`:** give the user a link to open and submit: `https://github.com/<owner>/<repo>/issues/new?title=<title>&body=<body>`, both URL-encoded. If the link would be over about 6,000 characters, leave the patch out of the link and give it to the user to paste.
   - **Pull request,** in a temporary folder:
     1. `gh repo fork <owner>/<repo> --clone`, and go into the clone. If the user already has a fork, this reuses it, and its branches may carry unrelated commits.
     2. So start from upstream, not from the fork: `base="$(gh repo view <owner>/<repo> --json defaultBranchRef -q .defaultBranchRef.name)"`, `git fetch upstream "$base"`, `git switch -c <short-branch-name> "upstream/$base"`.
     3. Save the patch to a file and apply it with the command from the diff header (`git apply --directory=<folder> <file>`). If it doesn't apply, stop and offer an issue instead.
     4. Commit with the title as the message. Before pushing, check that the PR would carry exactly this change: `git log --oneline "upstream/$base"..HEAD` shows only your commit, and `git diff --stat "upstream/$base"..HEAD` touches only the skill's folder. If not, stop and tell the user.
     5. `git push -u origin <short-branch-name>`, then `gh pr create --repo <owner>/<repo> --base "$base" --head "$(gh api user -q .login):<short-branch-name>" --title "<title>" --body-file <file>`.
   - **Source not on GitHub:** give the user the patch and the source URL.

5. **Report the link.** The user's skill and their meta-skill-loop history don't change. If the author later publishes the change, `msl update` merges it cleanly, since both sides already agree.
