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
| **Facebook** | De-Vanced | module + clone APK | pinned `490.0.0.63.82`; clone `app.devanced.facebook.katana` (see [permission conflict](#meta-app-clones-duplicate-permission)) |
| **Google Photos** | De-Vanced | non-root APK + module | clone `app.devanced.google.android.apps.photos`; APK uses microG/GmsCore |

> **One entry → module + clone APK.** Each app is a single config entry. For Reddit/Instagram/Facebook, `clone = true` makes the build emit a root **module** (original package, mounts over the stock app) **and** a renamed **clone APK** — `app.<patch>.<pkg>` (e.g. `app.piko.instagram.android`) — that installs *alongside* the official app without root. It's the same single-entry pattern YouTube/YT Music get from the microG patch (their non-root APK is auto-renamed). Twitter is module-only (Piko ships no rename patch for it).
>
> Twitter and Instagram use [Piko](https://github.com/crimera/piko), Facebook and Google Photos use [De-Vanced](https://github.com/RookieEnough/De-Vanced) — all via the [Morphe CLI](https://github.com/MorpheApp/morphe-cli). Twitter is pinned to `11.81.0-release.0` (newer versions need the separate Piko-Shim bundle); Instagram (`430.0.0.53.80`) and Facebook (`490.0.0.63.82`) are pinned, arm64-v8a, and mirrored from a self-hosted archive.org item. Google Photos, unlike the pinned Meta apps, tracks `auto` versions from apkmirror/uptodown and is not integrity-protected. Downloaded stock APKs are signature-verified against each app's official signing certificate (`sig.txt`). Instagram and Facebook are **experimental** — integrity-protected (pairip) apps whose patched builds may not run on all setups.

For non-root YouTube, YT Music, and Google Photos APKs, install [MicroG / GmsCore](https://github.com/ReVanced/GmsCore/releases).

## Customizing the build

* Edit [`config.toml`](./config.toml) to include/exclude patches or add/remove apps. You can generate a config with [rvmm-config-gen](https://j-hc.github.io/rvmm-config-gen/).
* See [`CONFIG.md`](./CONFIG.md) for all available options.
* Run the [Build workflow](../../actions/workflows/build.yml) (or wait for the daily CI run) and grab the outputs from [releases](../../releases).

### Config notes (`config.toml`)

The config is kept comment-free; here's what the non-obvious settings mean:

* **`clone = true`** (Reddit, Instagram, Facebook) — with `build-mode = "both"`, the build emits a root **module** (original package, mounts over the stock app) **and** a renamed **clone APK** (`app.<patch>.<pkg>`, e.g. `app.piko.instagram.android`) that installs alongside the official app without root. Same single-entry pattern YouTube/YT Music get from microG. Twitter has **no** clone — Piko ships no rename patch for it, so it's module-only.
* **Pinned `version =` (not `auto`)** — Twitter `11.81.0-release.0`, Instagram `430.0.0.53.80`, Facebook `490.0.0.63.82` are held at the exact builds their patches support; **don't switch these to `auto`**. Their stock APKs are mirrored on a self-hosted archive.org item because apkmirror/uptodown don't reliably serve those builds.
* **Twitter `excluded-patches = "'Block redirecting to X Lite'"`** — that Piko v3.6.0 patch's fingerprint doesn't match the pinned `11.81.0` (pre-Piko-Shim) build, so it's excluded to let the build succeed.
* **`enable-module-update`** — set `false` to stop the modules from receiving in-app updates.

#### CI notifications

CI posts to two Telegram destinations (both via the `TG_TOKEN` bot secret): successful release announcements go to the public channel set by the `TG_CHAT` repo variable, while a **daily status heartbeat** (built / skipped / failed) and **build-failure alerts** go to a private admin chat set by the **`TG_CHAT_ADMIN`** repo variable. The send logic is shared in [`.github/scripts/tg-notify.sh`](./.github/scripts/tg-notify.sh); if a destination variable is unset, that notification is silently skipped. To get the numeric `TG_CHAT_ADMIN` id for a private channel, add the bot as an admin, post a message, and read `chat.id` from `https://api.telegram.org/bot<TG_TOKEN>/getUpdates`.

#### Meta-app clones: duplicate-permission conflict

The Facebook **clone APK** may fail to install alongside the official app with `INSTALL_FAILED_DUPLICATE_PERMISSION`. Renaming the package (`Change package name` patch, even with `updatePermissions`/`updateProviders`) does **not** rename the *company-prefixed* custom permissions Meta apps declare — e.g. `com.facebook.permission.prod.FB_APP_COMMUNICATION` and `com.facebook.receiver.permission.ACCESS`. The clone re-declares those exact permission names, so if any other Meta app that owns them (official **Facebook** or **Messenger** — both known) is installed, Android rejects the clone.

Known affected: stock **Facebook** and **Messenger** share these permissions; other Meta apps (Instagram, Threads, etc.) may declare their own overlapping permissions and hit the same conflict. Workarounds: uninstall the conflicting official Meta app first, or use the root **module** (original package, no permission rename needed) instead of the clone. A manual fix is to rewrite the `com.facebook.*` permission strings to `app.facebook.*` in `AndroidManifest.xml` and re-sign — the build does **not** do this automatically.

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

## Disclaimer

These builds are provided **as-is, with no warranty**, for personal and educational use. The apps are modified (re-signed, patched) and are **not** official releases — installing or running them is **entirely at your own risk**. They may break, fail to update, behave unexpectedly, or violate the original apps' terms of service, and some (e.g. integrity-protected apps) may not run at all. You are responsible for complying with applicable laws and each app's terms. The maintainer is not liable for any damage, data loss, account action, or other consequences arising from their use.

## Credits

This project is a fork of [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module). All credit for the builder, module template, and helper tooling goes to [j-hc](https://github.com/j-hc). Patches are provided by [ReVanced](https://github.com/ReVanced), [Morphe](https://github.com/MorpheApp), [Piko (crimera)](https://github.com/crimera/piko), and [De-Vanced (RookieEnough)](https://github.com/RookieEnough/De-Vanced).
