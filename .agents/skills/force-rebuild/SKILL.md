---
name: force-rebuild
description: Make the daily CI rebuild every app or specific apps by editing patches-state.json on the update branch. Use when a config change (version pin, dlurl, include-stock, arch) must ship without a patch-bundle bump, or when asked to "force a rebuild" or "rebuild <app>".
compatibility: Requires git, jq and the gh CLI.
---

# Force a rebuild

`ci.yml` rebuilds an app only when its patch-bundle asset differs from the one that `patches-state.json` on the `update` branch records for it. A table missing from the state always rebuilds, in **all** of its build modes. So a rebuild is forced by removing state. `AGENTS.md` ("Forcing a rebuild") explains why.

1. Decide the scope: **specific apps** (remove their keys) or **everything** (remove the file).
2. Branch off `update`: `git fetch origin update && git switch -c chore/force-rebuild-<topic> origin/update`.
3. Edit:
   - Specific apps: `jq 'del(."<App-Table>", ."<Other-Table>")' patches-state.json > tmp && mv tmp patches-state.json`. Use the exact table names from `config.toml`, for example `"Twitter/X-Piko"`.
   - Everything: `git rm patches-state.json`.
4. Check: `git diff`. Only the intended keys (or the file) are gone.
5. Commit (signed, gmail identity), push, and open the PR into `update`:
   `gh pr create -R andrewliang25/patched-apps --base update --head <branch> --body-file <file>`.
   The body names the apps and why they must rebuild. If the rebuild ships a user-facing change (for example a signing-key or package change that forces a reinstall), say so; that note belongs in the public release notes.
6. After the merge, the next daily CI run builds them. To build sooner, trigger **CI** with `gh workflow run ci.yml -R andrewliang25/patched-apps`. Do not run **Build Modules** by hand: it builds the full `config.toml`.

**Done when:** the PR is open and its diff removes exactly the intended state.
