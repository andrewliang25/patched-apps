# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A fork of [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module): a Bash-based builder that downloads stock Android APKs, applies ReVanced (or compatible: Morphe, Piko) patches via the ReVanced CLI, and packages the result either as non-root APKs or as Magisk/KernelSU modules. It is driven entirely by `config.toml` and runs daily in GitHub Actions.

There is no compiled application source here — the "code" is shell scripts plus prebuilt helper binaries. The patches and CLI themselves are fetched at build time from upstream GitHub releases.

## Commands

```bash
./build.sh                      # build everything enabled in config.toml
./build.sh config.toml          # explicit config (also accepts a .json config)
./build.sh clean                # remove temp/, build/, build.md
./build.sh config.toml --config-update   # print a trimmed config of apps with newer patches available (used by CI to decide whether to build)
```

Requirements: `jq`, OpenJDK 17+, `zip` (build.sh checks these and aborts if missing). On Termux, `build-termux.sh` bootstraps the environment and handles output to `/sdcard/Download`.

There is **no test suite and no linter**. To validate changes, run a build with a single app enabled (set `enabled = false` on the rest in `config.toml`, or `enabled = true` on just one). `NORB=true` skips rebuilding APKs that already exist in `temp/`/`build/` — useful when iterating on module-packaging logic without re-patching.

## Architecture

Three files do all the work:

- **`build.sh`** — entry point. Parses `config.toml`, resolves per-app settings (with main-table defaults), fetches CLI + patches prebuilts once per source, then spawns `build_rv` in the background for each app/arch, throttled to `parallel-jobs`. `arch = "both"` fans out into two builds (arm64-v8a + arm-v7a).
- **`utils.sh`** — the engine. Everything else lives here: TOML parsing, GitHub/HTTP downloads, the four download backends, version resolution, patching, and module packaging. `build.sh` is mostly config plumbing around `utils.sh`'s `build_rv`.
- **`module/`** — the Magisk/KernelSU module template. Copied per-build into `temp/`, filled with `module.prop` + `config`, and zipped. `customize.sh` is the on-device installer (runs at flash time, not build time): it installs the correct stock version, mounts the patched `base.apk` over the real one via bind mount, and handles arch/version checks.

### The build pipeline (`build_rv` in utils.sh)

1. **Resolve package name** by probing download sources for the app.
2. **Resolve version** per `version` mode: `auto` picks the highest version supported by all included patches (parsed from CLI `list-versions` output); `latest`/`beta` take the newest from the download source; a literal version is used as-is.
3. **Download stock APK** by trying each configured `*-dlurl` source in `DL_SRCS` order (`direct`, `archive`, `apkmirror`, `uptodown`). Bundles (`.apkm`/`.xapk`) are merged into a single APK via APKEditor and re-signed.
4. **Verify signature** against `sig.txt` (skips apps not listed there).
5. **Patch** via `patch_apk` → ReVanced CLI, signing with `ks.keystore`.
6. **Package** for each build mode:
   - `apk` (non-root): the microg/gmscore patch is *included*; output goes straight to `build/`.
   - `module` (root): the microg patch is *excluded* (the module mounts over the real app, so it relies on the stock signature); the patched APK plus optional stock APK are zipped with the module template.

### Download backends

Each source implements the same informal interface — `get_<src>_resp`, `get_<src>_pkg_name`, `get_<src>_vers`, and `dl_<src>` — so `build_rv` can iterate over `DL_SRCS` generically. apkmirror/uptodown scrape HTML using the `htmlq` binary; archive/direct parse URLs. Adding a source means adding these four functions and an entry to `DL_SRCS`.

### Prebuilt binaries (`bin/`)

`set_prebuilts` selects arch-specific binaries by `uname -m`: `tq` (TOML→JSON, the `$TOML` parser), `htmlq` (HTML scraping), `aapt2` (Termux/Android only). `paccer.jar` + `dexlib2.jar` strip ReVanced integrations checks from the patches bundle when `remove-rv-integrations-checks = true`. `apksigner.jar` signs APKs. Module installer ships a per-arch `ksu_profile` binary.

## Configuration (`config.toml`)

The main (top-level) table sets defaults; each `[App]` table overrides them. Keys are documented in `CONFIG.md`. Two gotchas:

- Patch names in `excluded-patches`/`included-patches` must be quoted, and a single quote *inside* a patch name is escaped by doubling it (`'Hide ''Get Music Premium'''`).
- `toml_get` returning non-zero means "key absent" — the `|| DEFAULT` idiom throughout `build.sh` depends on this, so it's load-bearing, not sloppy error handling.

## CI (`.github/workflows/`)

`ci.yml` runs daily on cron: it checks out `build.md` from the `update` branch and runs `--config-update` to see if any enabled app has newer patches; only then does it call `build.yml`. `build.yml` builds, uploads APKs/modules to a GitHub Release tagged with an incrementing version code, regenerates `*-update.json` files on the `update` branch (these power in-app Magisk module updates), and optionally posts to Telegram. The `update` branch is data, not code — it holds `build.md` (the changelog/state) and the per-module update JSONs.

**Telegram notifications.** All Telegram posts go through `.github/scripts/tg-notify.sh` (curl wrapper; no-ops if `TG_TOKEN`/`TG_CHAT` env is empty). Two destinations, one bot (`TG_TOKEN` secret): the **public** release announcement in `build.yml`'s "Report to Telegram" step posts to `TG_CHAT` (var); the **admin** notifications post to `TG_CHAT_ADMIN` (var). Admin gets a daily heartbeat from `ci.yml`'s `notify` job (`if: always()`, reads `needs.check/build.result` → built/skipped/failed) and a build-failure alert from `build.yml`'s `Report failure to Telegram` step (`if: failure() && !inputs.from_ci`, so CI-triggered failures are reported once by `ci.yml`, not duplicated). Failure messages are minimal — a line plus the Actions run URL.

## Signing keys

`ks.keystore` (patched APKs) and `ks-p12.keystore` (merged stock bundles) use alias `jhc` / password `123456789`. These are committed intentionally — they are throwaway signing keys for self-built APKs, not secrets.

## Maintenance gotchas (learned operationally)

- **Forcing a full rebuild.** `ci.yml` only builds when an enabled app's *patches version* is newer than what `build.md` on the `update` branch records — it ignores config changes (added/removed apps, new version pins). To force a complete rebuild after editing config, delete `build.md` from the `update` branch; CI then takes its "first time building!" path and `build.yml` builds the full `config.toml`.

- **Pinned-version apps drift against newer patches.** A literal `version =` passes `-f` to the CLI, which bypasses the *version-compatibility gate* but NOT per-patch fingerprint matching. A newer patch whose fingerprint isn't in the pinned APK hard-fails the whole build (`PatchException: Failed to match the fingerprint`). Fix by excluding that patch via `excluded-patches` or setting `patcher-args = "--continue-on-error"`. (Twitter pins `11.81.0` and excludes `'Block redirecting to X Lite'` for exactly this reason; Twitter/Instagram are pinned because newer versions need Piko-Shim/pairip a single-bundle build can't handle.)

- **Apps apkmirror/uptodown won't serve (e.g. Instagram).** apkmirror increasingly 403s even from CI runners. Self-host the APK on an archive.org item and use the `archive` backend: files named `<pkg>-<version>-<arch>.apk[m]` inside a folder whose path *ends in the package name*, with `archive-dlurl` pointing at that folder. `.apkm` bundles are merged automatically. archive.org "folders" are just slashes in filenames — set them with `ia upload --remote-name=` / `ia move`, not the web uploader.

- **Signature verification is opt-in.** `check_sig` only verifies an APK if its package is listed in `sig.txt` (`<sha256> <pkg>` per line); unlisted packages are silently accepted. When adding an app, extract its official cert with `apksigner verify --print-certs` and take the value `check_sig` uses (lines starting `Signer`, containing `SHA-256`, `tail -1`), then add it. For multi-signer apps (key rotation, e.g. Instagram) that's the last signer's hash; for bundles, every split must verify to it.

- **Local testing on macOS.** The `bin/*-arm64` / `*-arm` helper binaries are Android/Bionic builds and won't run on macOS or Linux; the `-x86_64` ones are glibc Linux. To run a build locally, use a `linux/amd64` Docker container (`ubuntu`, `apt install jq openjdk-17-jre-headless zip unzip curl`, repo mounted at `/repo`) so `set_prebuilts` selects the working x86_64 binaries.

- **`clone = true` (fork-specific addition).** Non-upstream config option in `build_rv`. For a `build-mode = "both"` app it generalizes the microG hook: in **apk** mode it enables the rename patch (`Clone` if present, else `Change package name`) with `-O packageName=app.<brand>.<pkg-without-com>`, producing a coexisting clone APK; in **module** mode it omits it, keeping the original package for mounting. So one entry yields both a clone APK and an original-package module (Reddit/Instagram/Facebook). The brand = `rv-brand` lowercased, non-alphanumerics stripped (De-Vanced→devanced).
