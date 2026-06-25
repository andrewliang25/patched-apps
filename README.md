# Patched Apps

[![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/andrewspatchedapps)
[![CI](https://github.com/andrewliang25/patched-apps/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/andrewliang25/patched-apps/actions/workflows/ci.yml)

A personal Morphe / Piko / De-Vanced builder that produces non-root APKs and Magisk/KernelSU modules, updated automatically via CI. Built on top of [**j-hc/revanced-magisk-module**](https://github.com/j-hc/revanced-magisk-module) — the build engine, module template, and tooling are j-hc's work; this repo just customizes [`config.toml`](./config.toml) for the apps below.

**Grab the [latest release](https://github.com/andrewliang25/patched-apps/releases).**

## Apps

| App | Patches | Major features | Output | Notes |
| --- | --- | --- | --- | --- |
| <div align="center"><img src="assets/icons/youtube.svg" width="28"><br><b>YouTube</b></div> | Morphe | Ad-free video, SponsorBlock, background playback, Return YouTube Dislike, custom themes | non-root APK + module | APK renamed (MicroG-RE) |
| <div align="center"><img src="assets/icons/ytmusic.svg" width="28"><br><b>YT Music</b></div> | Morphe | Ad-free, background playback, exclusive-audio mode, minimized playback | non-root APK + module | arm64-v8a; APK renamed (MicroG-RE) |
| <div align="center"><img src="assets/icons/googlephotos.svg" width="28"><br><b>Google Photos</b></div> | De-Vanced | Unlimited original-quality backup, removes the device/account model lock | non-root APK + module | APK renamed to `app.devanced.google.android.apps.photos` (uses MicroG-RE) |
| <div align="center"><img src="assets/icons/instagram.svg" width="28"><br><b>Instagram</b></div> | Piko | Block ads/sponsored posts, download photos/videos/reels, hide story "seen", disable typing & read receipts | non-root APK + module | pinned `430.0.0.53.80`; APK renamed to `app.piko.instagram.android` — **experimental** |
| <div align="center"><img src="assets/icons/facebook.svg" width="28"><br><b>Facebook</b></div> | De-Vanced | Block ads/sponsored posts, cleaner feed | non-root APK + module | pinned `490.0.0.63.82`; APK renamed to `app.devanced.facebook.katana` — **experimental** (see [permission conflict](#meta-app-clones-duplicate-permission-conflict)) |
| <div align="center"><img src="assets/icons/threads.svg" width="28"><br><b>Threads</b></div> | De-Vanced | Block ads, hide suggested threads | non-root APK + module | arm64-v8a; APK renamed to `app.devanced.instagram.barcelona` |
| <div align="center"><img src="assets/icons/reddit.svg" width="28"><br><b>Reddit</b></div> | Morphe | Block ads, sanitize share links, hide recommendations/premium prompts, custom branding | non-root APK + module | non-root APK renamed to `app.morphe.reddit.frontpage` |
| <div align="center"><img src="assets/icons/twitter.svg" width="28"><br><b>Twitter / X</b></div> | Piko | Hide ads/promoted tweets, download media, restore chronological timeline, hide view counts | module | pinned `11.81.0-release.0`; module-only (Piko ships no rename patch) |
| <div align="center"><img src="assets/icons/telegram.svg" width="28"><br><b>Telegram</b></div> | Paresh-Patches | Ghost mode (no read receipts), anti-delete/anti-edit, save restricted media | non-root APK + module | targets the standalone/website build `org.telegram.messenger.web`; not renamed (Paresh ships no rename patch) — already coexists with the Play Store build `org.telegram.messenger` |

Each app is a single config entry that emits two output types:

* **non-root APK** — install directly, no root. Most apps' APKs are package-renamed (a `app.<patch>.<pkg>` "clone", or the MicroG-RE variant for Google apps) so they install *alongside* the official app rather than replacing it.
* **module** — Magisk/KernelSU module that mounts the patched APK over the stock app. Keeps the original package, so it needs root and the stock app installed.

> **Experimental:** Instagram and Facebook are integrity-protected (pairip) apps; their patched builds may not run on all setups.

## Installing

* **Non-root YouTube, YT Music, and Google Photos APKs** need [MicroG-RE](https://github.com/MorpheApp/MicroG-RE/releases) installed.
* **All KernelSU/Magisk modules:** add the target app to the Zygisk **DenyList** (or the mount won't apply), and use [**zygisk-detach**](https://github.com/j-hc/zygisk-detach) to detach them from the Play Store to prevent being updated.

### Meta-app clones: duplicate-permission conflict

Meta clone APKs may fail to install alongside the official app with `INSTALL_FAILED_DUPLICATE_PERMISSION`.

Known affected (each pair shares the same custom permissions, so only **one** of the two can be installed at a time):

* **Facebook** + **Messenger** — stock and patched both declare the same `com.facebook.*` permissions; you can keep only one across the Facebook/Messenger family.
* **Threads** — stock and patched Threads conflict on Threads' own shared permissions; you can keep only one.

Workarounds: uninstall the conflicting official Meta app first, or use the root **module** (original package, no permission rename needed) instead of the clone.

### Instagram Piko module: Piko settings won't open

On the Instagram **module** (original package, mounted over the stock app), the Piko settings screen cannot be opened — see [crimera/piko#882](https://github.com/crimera/piko/issues/882). Recommended workaround: use the **clone APK** (`app.piko.instagram.android`) instead, where the settings open normally.

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

## Customizing the build

* Edit [`config.toml`](./config.toml) to include/exclude patches or add/remove apps. You can generate a config with [rvmm-config-gen](https://j-hc.github.io/rvmm-config-gen/).
* See [`CONFIG.md`](./CONFIG.md) for all available options.
* Run the [Build workflow](../../actions/workflows/build.yml) (or wait for the daily CI run) and grab the outputs from [releases](../../releases).

Twitter and Instagram use [Piko](https://github.com/crimera/piko); Facebook, Threads, and Google Photos use [De-Vanced](https://github.com/RookieEnough/De-Vanced); Telegram uses [Paresh-Patches](https://gitlab.com/Paresh-Maheshwari/paresh-patches) — all driven by the [Morphe CLI](https://github.com/MorpheApp/morphe-cli). Downloaded stock APKs are signature-verified against each app's official signing certificate (`sig.txt`).

### Config notes

The config is kept comment-free; here's what the non-obvious settings mean:

* **`clone = true`** (Reddit, Instagram, Facebook, Threads, Photos) — with `build-mode = "both"`, the apk-mode output is package-renamed to `app.<patch>.<pkg>` (e.g. `app.piko.instagram.android`) so the **non-root APK** installs alongside the official app, while the **module** keeps the original package to mount over the stock app. (The clone APK *is* that renamed non-root APK — not a separate artifact.) Same single-entry pattern YouTube/YT Music get from MicroG-RE. Twitter is module-only — Piko ships no rename patch, so it can't produce a coexisting APK.
* **Pinned `version =` (not `auto`)** — Twitter `11.81.0-release.0`, Instagram `430.0.0.53.80`, Facebook `490.0.0.63.82` are held at the exact builds their patches support; **don't switch these to `auto`**. Their stock APKs are mirrored on a self-hosted archive.org item because apkmirror/uptodown don't reliably serve those builds.
* **Twitter `excluded-patches = "'Block redirecting to X Lite'"`** — that Piko v3.6.0 patch's fingerprint doesn't match the pinned `11.81.0` (pre-Piko-Shim) build, so it's excluded to let the build succeed.
* **`enable-module-update`** — set `false` to stop the modules from receiving in-app updates.

### CI notifications

CI posts to two Telegram destinations (both via the `TG_TOKEN` bot secret): successful release announcements go to the public channel set by the `TG_CHAT` repo variable, while a **daily status heartbeat** (built / skipped / failed) and **build-failure alerts** go to a private admin chat set by the **`TG_CHAT_ADMIN`** repo variable. The send logic is shared in [`.github/scripts/tg-notify.sh`](./.github/scripts/tg-notify.sh); if a destination variable is unset, that notification is silently skipped. To get the numeric `TG_CHAT_ADMIN` id for a private channel, add the bot as an admin, post a message, and read `chat.id` from `https://api.telegram.org/bot<TG_TOKEN>/getUpdates`.

## Disclaimer

These builds are provided **as-is, with no warranty**, for personal and educational use. The apps are modified (re-signed, patched) and are **not** official releases — installing or running them is **entirely at your own risk**. They may break, fail to update, behave unexpectedly, or violate the original apps' terms of service, and some (e.g. integrity-protected apps) may not run at all. You are responsible for complying with applicable laws and each app's terms. The maintainer is not liable for any damage, data loss, account action, or other consequences arising from their use.

## Credits

This project is a fork of [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module). All credit for the builder, module template, and helper tooling goes to [j-hc](https://github.com/j-hc). Patches are provided by [ReVanced](https://github.com/ReVanced), [Morphe](https://github.com/MorpheApp), [Piko (crimera)](https://github.com/crimera/piko), [De-Vanced (RookieEnough)](https://github.com/RookieEnough/De-Vanced), and [Paresh-Patches (Paresh-Maheshwari)](https://gitlab.com/Paresh-Maheshwari/paresh-patches).
