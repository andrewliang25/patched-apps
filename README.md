# Patched Apps

[![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/andrewspatchedapps)
[![CI](https://github.com/andrewliang25/patched-apps/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/andrewliang25/patched-apps/actions/workflows/ci.yml)

A personal builder for Morphe patches. It makes non-root APKs and Magisk/KernelSU modules, and CI updates them daily. It is built on [**j-hc/revanced-magisk-module**](https://github.com/j-hc/revanced-magisk-module).

**Get the [latest release](https://github.com/andrewliang25/patched-apps/releases).**

Every APK and module in a release carries a [GitHub build provenance attestation](https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds). To make sure that CI of this repo built a file, run:

```
gh attestation verify <file> --repo andrewliang25/patched-apps
```

Contributors: [sign your commits](CONTRIBUTING.md#signing-your-commits) so that they show as **Verified**.

## Apps

| App | Patches | Main features | non-root APK | module | Notes |
| --- | --- | --- | :-: | :-: | --- |
| <div align="center"><img src="assets/icons/youtube.svg" width="28"><br><b>YouTube</b></div> | Morphe | No video ads, SponsorBlock, background playback, Return YouTube Dislike, custom themes | ✅ | ✅ | The APK is renamed and needs MicroG-RE |
| <div align="center"><img src="assets/icons/ytmusic.svg" width="28"><br><b>YT Music</b></div> | Morphe | No ads, background playback, exclusive-audio mode, minimized playback | ✅ | ✅ | arm64-v8a. The APK is renamed and needs MicroG-RE |
| <div align="center"><img src="assets/icons/googlephotos.svg" width="28"><br><b>Google Photos</b></div> | De-Vanced | Unlimited backup at original quality, no device or account model lock | ✅ | ✅ | The APK is renamed to `app.devanced.google.android.apps.photos` and needs MicroG-RE |
| <div align="center"><img src="assets/icons/instagram.svg" width="28"><br><b>Instagram</b></div> | Piko | Block ads and sponsored posts, download photos, videos and reels, hide story "seen", turn off typing and read receipts | ✅ | ❌ | The APK is renamed to `app.piko.instagram.android`. **Experimental**, and APK only, see [Instagram: APK only](#instagram-apk-only) |
| <div align="center"><img src="assets/icons/facebook.svg" width="28"><br><b>Facebook</b></div> | De-Vanced | Block ads and sponsored posts, cleaner feed | ✅ | ✅ | arm64-v8a. It follows the build that De-Vanced supports, `490.0.0.63.82`. The APK is renamed to `app.devanced.facebook.katana`. **Experimental**, see the [permission conflict](#meta-app-clones-duplicate-permission-conflict) |
| <div align="center"><img src="assets/icons/messenger.svg" width="28"><br><b>Messenger</b></div> | De-Vanced | Remove Meta AI, hide the Facebook tab, hide inbox subtabs, turn off the typing indicator | ✅ | ✅ | arm64-v8a. It follows the build that De-Vanced supports, `563.0.0.47.86`. The APK is renamed to `app.devanced.facebook.orca`. **Experimental**, see the [permission conflict](#meta-app-clones-duplicate-permission-conflict). `Hide inbox ads` is excluded |
| <div align="center"><img src="assets/icons/threads.svg" width="28"><br><b>Threads</b></div> | Chiggi | Hide ads, remove the AD_ID (advertising ID) permission | ✅ | ✅ | arm64-v8a. The APK is renamed to `app.chiggi.instagram.barcelona`. **Experimental**, see the [permission conflict](#meta-app-clones-duplicate-permission-conflict) |
| <div align="center"><img src="assets/icons/reddit.svg" width="28"><br><b>Reddit</b></div> | Morphe | Block ads, clean share links, hide recommendations and premium prompts, custom branding | ✅ | ✅ | The APK is not renamed and keeps `com.reddit.frontpage`, so uninstall the official app before you install it. See [Reddit: not renamed](#reddit-not-renamed) |
| <div align="center"><img src="assets/icons/twitter.svg" width="28"><br><b>Twitter / X</b></div> | Piko | Hide ads and promoted tweets, download media, restore the chronological timeline, hide view counts | ✅ | ✅ | Not cloned. The APK and the module both use `com.twitter.android`. Uninstall the app that has this package before you install one of them |
| <div align="center"><img src="assets/icons/telegram.svg" width="28"><br><b>Telegram</b></div> | Rushi | Remove ads, unlock Premium, keep deleted and disappearing messages, save restricted media, hide the typing indicator, faster downloads | ✅ | ✅ | arm64-v8a. It targets the Play Store build `org.telegram.messenger`. The stock APK is self-hosted on archive.org and pinned to build 12.10.0 (versionCode 70242). It is not renamed, so the non-root APK **replaces** the official app. Uninstall that app first. The APK also needs MicroG-RE |
| <div align="center"><img src="assets/icons/line.svg" width="28"><br><b>LINE</b></div> | Andrew | Hide ads and banners, remove the VOOM, Wallet and LINE TODAY tabs, hide Home modules, keep chats unread (no read receipts), open links outside the app | ✅ | ✅ | arm64-v8a. The stock APK is self-hosted on archive.org. It is not renamed and shares `jp.naver.line.android` with the Play Store build. Uninstall the official app before you install the non-root APK |

Each app is one config entry, and it makes two output types:

* **non-root APK** — install it without root. Most APKs get a new package name, either an `app.<patch>.<pkg>` clone or the MicroG-RE variant for Google apps. Thus they install beside the official app instead of replacing it.
* **module** — a Magisk/KernelSU module that mounts the patched APK over the stock app. It keeps the original package, so it needs root and the stock app. Instagram ships as an APK only.

> **Experimental:** Instagram and Facebook use pairip integrity protection. Their patched builds can fail to run on some devices.

## Installation

* The non-root YouTube, YT Music and Google Photos APKs need [MicroG-RE](https://github.com/MorpheApp/MicroG-RE/releases).
* For every KernelSU/Magisk module, add the target app to the Zygisk **DenyList**, or the mount does not apply. Then use [**zygisk-detach**](https://github.com/j-hc/zygisk-detach) to detach the app from the Play Store, so that the Play Store cannot update it.

### Meta app clones: duplicate permission conflict

`INSTALL_FAILED_DUPLICATE_PERMISSION` occurs when an app declares a custom `<permission>` whose name an installed app already owns, and the two apps have **different signing certificates**. Apps that share permission names and have the **same** signing key install together.

Meta apps declare shared family permissions across Facebook and Messenger, for example `com.facebook.permission.prod.FB_APP_COMMUNICATION`. The rename patch keeps those `com.facebook.*` permission **names**. Thus the conflict is between a clone and the official Meta app, not between two clones:

* **The clones install together.** This repo signs Facebook (`app.devanced.facebook.katana`) and Messenger (`app.devanced.facebook.orca`) with one key, so they share a signature.
* **A clone conflicts with the official app.** The Play Store Facebook and Messenger own `com.facebook.*` under the certificate of Meta. A clone signed by this repo declares the same names under a different certificate, which gives `INSTALL_FAILED_DUPLICATE_PERMISSION`. You cannot install a Meta-signed member and a repo-signed member of the `com.facebook.*` family at the same time. Any number of repo-signed members is permitted.
* **Threads** behaves the same way. The repo-signed Threads clone conflicts with the official Threads on the shared permissions of Threads.

There are two workarounds. Uninstall the official Meta app first, or use the root **module**, which keeps the original package and needs no permission rename.

### Instagram: APK only

Instagram ships the clone APK `app.piko.instagram.android` only. On a module, which keeps the original package, the Piko settings screen does not open. See [crimera/piko#882](https://github.com/crimera/piko/issues/882).

### Reddit: not renamed

The non-root Reddit APK keeps `com.reddit.frontpage`, so it does not install beside the official Reddit app. This repo signs the APK with a throwaway key, and Android refuses to install it over the official app. Uninstall the official Reddit app first. An uninstall erases the app data.

## Local builds

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

## Changes to the build

* Edit [`config.toml`](./config.toml) to include or exclude patches, and to add or remove apps. You can also make a config with [rvmm-config-gen](https://j-hc.github.io/rvmm-config-gen/).
* Read [`CONFIG.md`](./CONFIG.md) for all options.
* Start the [Build workflow](../../actions/workflows/build.yml), or wait for the daily CI run. Then get the outputs from the [releases](../../releases).

Twitter and Instagram use [Piko](https://github.com/crimera/piko). Facebook, Messenger and Google Photos use [De-Vanced](https://github.com/RookieEnough/De-Vanced). Threads uses [Chiggi](https://github.com/durgesh0505/chiggi_morphe_patches). Telegram uses [the morphe-patches of rushiranpise](https://github.com/rushiranpise/morphe-patches), and LINE uses [the morphe-patches of Andrew](https://github.com/andrewliang25/morphe-patches). The [Morphe CLI](https://github.com/MorpheApp/morphe-cli) drives all of them. Each stock APK is verified against the official signing certificate of the app, which `sig.txt` holds.

### Config notes

The config holds short notes only. The settings that follow need more explanation:

* **`clone = true`** (Facebook, Messenger, Threads, Photos, Reddit) — with `build-mode = "both"`, the non-root APK gets the package name `app.<patch>.<pkg>` and installs beside the official app. The module keeps the original package, so that it can mount over stock. Three tables differ. Instagram has `clone = true` but ships an APK only, see [Instagram: APK only](#instagram-apk-only). Reddit has `clone = true`, but the build does not rename it, see [Reddit: not renamed](#reddit-not-renamed). Twitter ships both outputs and is not cloned, because the `Clone` patch of Piko does not cover `com.twitter.android`.
* **Self-hosted stock APKs (archive.org)** — Facebook, Messenger, Twitter, Instagram, Threads and LINE are mirrored on a self-hosted archive.org item, because the public sources do not serve their builds. They use `auto`. If the mirror has no newer version, they fall back to the second source of the app.
* **`enable-module-update`** — set it to `false` to stop in-app updates of the modules.

### CI notifications

CI posts to two Telegram destinations with the bot secret `TG_TOKEN`. Release announcements go to the public channel that the repo variable `TG_CHAT` sets. The daily status message (built, skipped or failed) and the build-failure alerts go to a private admin chat that the repo variable **`TG_CHAT_ADMIN`** sets. [`.github/scripts/tg-notify.sh`](./.github/scripts/tg-notify.sh) holds the shared send logic. If a destination variable is empty, the script skips that notification.

To get the numeric id for `TG_CHAT_ADMIN`, do these steps:

1. Add the bot to the private channel as an admin.
2. Post a message in the channel.
3. Read `chat.id` from `https://api.telegram.org/bot<TG_TOKEN>/getUpdates`.

## Disclaimer

These builds come **as-is, with no warranty**, for personal and educational use. The apps are modified, that is patched and re-signed, and they are **not** official releases. You install and run them **at your own risk**. They can break, fail to update, behave in an unexpected way, or go against the terms of service of the original app. Some apps, for example apps with integrity protection, can fail to run. You are responsible for the applicable laws and for the terms of each app. The maintainer is not liable for damage, data loss, account action, or other results of their use.

## Credits

This project is a fork of [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module). All credit for the builder, the module template and the helper tooling goes to [j-hc](https://github.com/j-hc). The patches come from [ReVanced](https://github.com/ReVanced), [Morphe](https://github.com/MorpheApp), [Piko (crimera)](https://github.com/crimera/piko), [De-Vanced (RookieEnough)](https://github.com/RookieEnough/De-Vanced), [Chiggi (durgesh0505)](https://github.com/durgesh0505/chiggi_morphe_patches) and [the morphe-patches of rushiranpise](https://github.com/rushiranpise/morphe-patches).
