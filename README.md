# Patched Apps

[![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/andrewspatchedapps)
[![CI](https://github.com/andrewliang25/patched-apps/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/andrewliang25/patched-apps/actions/workflows/ci.yml)

A personal Morphe / Piko builder that produces non-root APKs and Magisk/KernelSU modules, updated automatically via CI.

Built on top of [**j-hc/revanced-magisk-module**](https://github.com/j-hc/revanced-magisk-module) — the build engine, module template, and tooling are j-hc's work; this repo just customizes [`config.toml`](./config.toml) for the apps below.

Get the [latest release](https://github.com/andrewliang25/patched-apps/releases).

Use [**zygisk-detach**](https://github.com/j-hc/zygisk-detach) to detach YouTube and YT Music from the Play Store if you are using the Magisk modules.

## Apps built

| App | Patches | Output | Notes |
| --- | --- | --- | --- |
| **YouTube** | Morphe | APK + module | rebranded "Morphe" |
| **YT Music** | Morphe | APK + module | rebranded "Morphe" |
| **Reddit** | Morphe | APK + module | rebranded "Morphe" |
| **Twitter / X** | Piko | module | pinned `11.81.0-release.0` (last pre-Piko-Shim version) |
| **Instagram** | Piko | APK (arm64-v8a) | pinned `430.0.0.53.80` |

> Twitter and Instagram use the [Piko](https://github.com/crimera/piko) patches via the [Morphe CLI](https://github.com/MorpheApp/morphe-cli). Twitter is pinned to `11.81.0-release.0` because newer versions (11.88+) require the separate Piko-Shim bundle, which a single-bundle build cannot supply. Instagram is pinned to `430.0.0.53.80` (arm64-v8a, the version Piko v3.6.0 supports) and mirrored from a self-hosted archive.org item, since apkmirror/uptodown don't reliably serve that build. Downloaded stock APKs are signature-verified against each app's official signing certificate (`sig.txt`).

For non-root YouTube and YT Music APKs, install [MicroG / GmsCore](https://github.com/ReVanced/GmsCore/releases).

## Customizing the build

* Edit [`config.toml`](./config.toml) to include/exclude patches or add/remove apps. You can generate a config with [rvmm-config-gen](https://j-hc.github.io/rvmm-config-gen/).
* See [`CONFIG.md`](./CONFIG.md) for all available options.
* Run the [Build workflow](../../actions/workflows/build.yml) (or wait for the daily CI run) and grab the outputs from [releases](../../releases).

## Building locally

### On Termux
```console
bash <(curl -sSf https://raw.githubusercontent.com/andrewliang25/patched-apps/main/build-termux.sh)
```

### On Linux
```console
$ git clone https://github.com/andrewliang25/patched-apps --depth 1
$ cd patched-apps
$ ./build.sh
```

## If you are having trouble with the classic mount method of the modules
such as,
- **"Reflash needed"** error after reboots
- **"Suspicious mount detected"** warnings from root detector apps

You can consider using [rvmm-zygisk-mount](https://github.com/j-hc/rvmm-zygisk-mount).

## Credits

This project is a fork of [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module). All credit for the builder, module template, and helper tooling goes to [j-hc](https://github.com/j-hc). Patches are provided by [ReVanced](https://github.com/ReVanced), [Morphe](https://github.com/MorpheApp), and [Piko (crimera)](https://github.com/crimera/piko).
