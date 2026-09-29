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
   - **Body:** what went wrong, in your own words from the feedback (`msl feedback list <name> --all`); the change and why it helps; the patch in a `diff` block.
   - Never paste feedback entries or conversation copies, and leave out anything private: names, paths, company or customer details. The repository may be public.
   - Show the exact title and body. Post only after the user approves them.

4. **Post it.** `<owner>/<repo>` comes from the source URL in the diff header.
   - **Issue, with `gh`:** `gh issue create --repo <owner>/<repo> --title "<title>" --body-file <file>`.
   - **Issue, without `gh`:** give the user a link to open and submit: `https://github.com/<owner>/<repo>/issues/new?title=<title>&body=<body>`, both URL-encoded. If the link would be over about 6,000 characters, leave the patch out of the link and give it to the user to paste.
   - **Pull request:** in a temporary folder, `gh repo fork <owner>/<repo> --clone`, then in the clone `git switch -c <short-branch-name>`, save the patch to a file, and apply it with the command from the diff header (`git apply --directory=<folder> <file>`). Commit with the title as the message, `git push -u origin <branch>`, and `gh pr create --repo <owner>/<repo> --title "<title>" --body-file <file>`. If the patch doesn't apply, stop and offer an issue instead.
   - **Source not on GitHub:** give the user the patch and the source URL.

5. **Report the link.** The user's skill and their meta-skill-loop history don't change. If the author later publishes the change, `msl update` merges it cleanly, since both sides already agree.
