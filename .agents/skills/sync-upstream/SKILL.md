---
name: sync-upstream
description: Merge upstream j-hc/revanced-magisk-module into this fork's main as its own PR. Use before starting new fork work, or when asked to "sync upstream", "merge upstream" or "pull in j-hc changes".
compatibility: Requires git with an `upstream` remote and the gh CLI.
---

# Sync upstream

Do the sync as its own PR before any fork change, so the merge base stays current and a later sync shows only new upstream work.

1. Check for new work: `git fetch upstream && git log --oneline origin/main..upstream/main`. If it prints nothing, stop: main is already synced.
2. Delete the upstream release tags that the fetch brought in: `git tag | grep -E '^202[0-9]{5}$' | xargs git tag -d`.
3. Branch: `git switch -c chore/merge-upstream-<YYYY-MM-DD> origin/main`.
4. Merge: `git merge upstream/main`. `config.toml` always conflicts, because the app set has fully diverged. Keep ours: `git checkout --ours config.toml`. Never take values from upstream's `config.toml`.
5. Resolve the other conflicts on their merits. Fork-specific behaviour is documented in `AGENTS.md`; keep it.
6. Read `git diff origin/main --stat`. An upstream commit that touched only its own `config.toml` imports nothing, so an empty diff is a valid result. In that case, report it and do not open a PR.
7. If the merge changed anything the build reads, run the `local-build-verify` skill.
8. Commit (signed, gmail identity), push, and open the PR:
   `gh pr create -R andrewliang25/patched-apps --base main --head <branch> --title "Merge upstream j-hc/revanced-magisk-module (<date>)" --body-file <file>`.
   The body lists the upstream commits that brought changes, and how each conflict was resolved.

**Done when:** the PR is open, or step 1 or step 6 showed that there is nothing to sync.
