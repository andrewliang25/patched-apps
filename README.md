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
| **YouTube** | Morphe | non-root APK + module | APK renamed (microG) |
| **YT Music** | Morphe | non-root APK + module | arm64-v8a; APK renamed (microG) |
| **Reddit** | Morphe | module + clone APK | clone: `app.morphe.reddit.frontpage` |
| **Twitter / X** | Piko | module | pinned `11.81.0-release.0`; no clone (Piko ships no rename patch) |
| **Instagram** | Piko | module + clone APK | pinned `430.0.0.53.80`; clone `app.piko.instagram.android` |
| **Facebook** | De-Vanced | module + clone APK | pinned `490.0.0.63.82`; clone `app.devanced.facebook.katana` |

> **One entry → module + clone APK.** Each app is a single config entry. For Reddit/Instagram/Facebook, `clone = true` makes the build emit a root **module** (original package, mounts over the stock app) **and** a renamed **clone APK** — `app.<patch>.<pkg>` (e.g. `app.piko.instagram.android`) — that installs *alongside* the official app without root. It's the same single-entry pattern YouTube/YT Music get from the microG patch (their non-root APK is auto-renamed). Twitter is module-only (Piko ships no rename patch for it).
>
> Twitter and Instagram use [Piko](https://github.com/crimera/piko), Facebook uses [De-Vanced](https://github.com/RookieEnough/De-Vanced) — all via the [Morphe CLI](https://github.com/MorpheApp/morphe-cli). Twitter is pinned to `11.81.0-release.0` (newer versions need the separate Piko-Shim bundle); Instagram (`430.0.0.53.80`) and Facebook (`490.0.0.63.82`) are pinned, arm64-v8a, and mirrored from a self-hosted archive.org item. Downloaded stock APKs are signature-verified against each app's official signing certificate (`sig.txt`). Instagram and Facebook are **experimental** — integrity-protected (pairip) apps whose patched builds may not run on all setups.

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
