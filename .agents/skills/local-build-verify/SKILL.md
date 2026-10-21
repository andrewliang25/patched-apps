---
name: local-build-verify
description: Verify a change to config.toml, build.sh, utils.sh or CI with a local linux/amd64 Docker build before committing, or test one utils.sh function in isolation. Use before every commit that changes build behaviour, when asked to "build locally", "test the config", or to reproduce a build bug.
compatibility: Requires Docker (linux/amd64 emulation on Apple Silicon), git, and network access to GitHub and the APK mirrors.
---

# Local build verify

A change that the build reads is unproven until a real build passes. Commit only after the build in this skill goes green.

The `bin/*-arm64` and `bin/*-arm` helpers are Android/Bionic binaries and the `-x86_64` ones are glibc Linux, so every `build.sh` run goes in a `linux/amd64` Ubuntu container. Ad-hoc patching of one app needs no Docker: use the `adhoc-patch-build` skill.

## 1. Check Docker memory

```bash
docker info | grep "Total Memory"
```

Large apps (Telegram, LINE, any app with a base APK of ~50 MB or more) need **8 GB or more** (an 8 GB setting reports ~7.75 GiB). Below ~4 GB the kernel OOM-kills the patcher JVM right after `INFO: Writing resource APK` (`utils.sh: line 75: … Killed`, no Java error). `java()` in `utils.sh` runs under `env -i`, so the heap cannot be tuned from outside; more VM memory is the only lever. If memory is too low, ask the user to raise Docker Desktop → Settings → Resources → Memory, or to stop other containers.

## 2. Pick the narrowest test

- **One `utils.sh` function changed** → step 3a. This takes minutes and isolates the behaviour.
- **Anything else** (config values, `build.sh`, module packaging) → step 3b.

## 3a. Call one function in isolation

```bash
"$S"/docker-run.sh '
  source utils.sh
  REMOVE_RV_INTEGRATIONS_CHECKS=false   # build.sh sets it; false skips the java/paccer step
  <call the function>'
```

Run it from the repo root, with `S=.agents/skills/local-build-verify/scripts`. It installs `jq curl unzip zip rsync openjdk-21-jre-headless`, copies the repo into `/work` without `build/`, `temp/` and `.git`, and runs your commands from `/work`. Set by hand any global that `build.sh` would set; `TEMP_DIR`/`BIN_DIR` default correctly. It passes `GITHUB_TOKEN` from `gh auth token`, because unauthenticated API lookups hit the rate limit.

Calling a function N times reproduces per-app repetition that one build cannot: `get_prebuilts` runs once per *app table*. To emulate a second build, remove only what `build.sh` removes at start (`temp/changelogs`, `temp/cli-changelog.md`) and keep `temp/<owner>-rv/`.

## 3b. Full build of one app

1. Write a `test-<topic>.toml` at the repo root (the `test*` pattern is gitignored) with the main-table keys from `config.toml` and only the app table under test.
2. Run `"$S"/docker-run.sh './build.sh test-<topic>.toml'`.
3. Read the log for `Applied:` lines and errors, and check the output in `build/`.

To reuse the stock download and split merge between runs, set `WORK_DIR=<host dir>` so `/work` persists; then `temp/` survives.

## 4. Run a control

A pass proves nothing until the pre-fix code fails the same test. Put the old file in the container copy (`git show <commit-before>:utils.sh > utils.sh`) and confirm it reproduces the bug.

**Done when:** the fixed code passes, the control fails, and you can name the log line that shows each result.
