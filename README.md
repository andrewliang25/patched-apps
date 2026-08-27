# Patched Apps

[![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/andrewspatchedapps)
[![CI](https://github.com/andrewliang25/patched-apps/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/andrewliang25/patched-apps/actions/workflows/ci.yml)

A personal builder for Morphe patches. It makes non-root APKs and Magisk/KernelSU modules, and CI updates them daily. It is built on [**j-hc/revanced-magisk-module**](https://github.com/j-hc/revanced-magisk-module). The build engine, the module template and the tooling are the work of j-hc.

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
| <div align="center"><img src="assets/icons/instagram.svg" width="28"><br><b>Instagram</b></div> | Piko | Block ads and sponsored posts, download photos, videos and reels, hide story "seen", turn off typing and read receipts | ✅ | ❌ | The APK is renamed to `app.piko.instagram.android`. **Experimental**, and APK only. The module is dropped, see the [Piko settings bug](#instagram-module-piko-settings-do-not-open) |
| <div align="center"><img src="assets/icons/facebook.svg" width="28"><br><b>Facebook</b></div> | De-Vanced | Block ads and sponsored posts, cleaner feed | ✅ | ✅ | arm64-v8a. It follows the build that De-Vanced supports, at present `490.0.0.63.82`. The APK is renamed to `app.devanced.facebook.katana`. **Experimental**, see the [permission conflict](#meta-app-clones-duplicate-permission-conflict) |
| <div align="center"><img src="assets/icons/messenger.svg" width="28"><br><b>Messenger</b></div> | De-Vanced | Remove Meta AI, hide the Facebook tab, hide inbox subtabs, turn off the typing indicator | ✅ | ✅ | arm64-v8a. It follows the build that De-Vanced supports, at present `563.0.0.47.86`. The APK is renamed to `app.devanced.facebook.orca`. **Experimental**, see the [permission conflict](#meta-app-clones-duplicate-permission-conflict). `Hide inbox ads` is excluded, because its fingerprint is gone from current builds |
| <div align="center"><img src="assets/icons/threads.svg" width="28"><br><b>Threads</b></div> | Chiggi | Hide ads, remove the AD_ID (advertising ID) permission | ✅ | ✅ | arm64-v8a. The APK is renamed to `app.chiggi.instagram.barcelona`. **Experimental**, see the [permission conflict](#meta-app-clones-duplicate-permission-conflict). It [moved off De-Vanced](#threads-moved-from-de-vanced-to-chiggi), which dropped Threads |
| <div align="center"><img src="assets/icons/reddit.svg" width="28"><br><b>Reddit</b></div> | Morphe | Block ads, clean share links, hide recommendations and premium prompts, custom branding | ✅ | ✅ | Not renamed at present, see [the Reddit clone note](#reddit-the-clone-is-not-active). The APK keeps `com.reddit.frontpage`, so uninstall the official app before you install it |
| <div align="center"><img src="assets/icons/twitter.svg" width="28"><br><b>Twitter / X</b></div> | Piko | Hide ads and promoted tweets, download media, restore the chronological timeline, hide view counts | ✅ | ✅ | Not cloned. Both outputs keep `com.twitter.android`, so uninstall the official X app before you install the non-root APK. The [module is back](#twitter--x-module-re-enabled) after runtime problems dropped it |
| <div align="center"><img src="assets/icons/telegram.svg" width="28"><br><b>Telegram</b></div> | Rushi | Remove ads, unlock Premium, keep deleted and disappearing messages, save restricted media, hide the typing indicator, faster downloads | ✅ | ✅ | arm64-v8a. It targets the Play Store build `org.telegram.messenger`. The stock APK is self-hosted on archive.org and pinned to build 12.10.0 (versionCode 70242), which the fingerprints of the bundle target. It is not renamed, because the bundle has no rename patch. Thus the non-root APK **replaces** the official app. Uninstall that app first. The APK also needs MicroG-RE. It moved off Paresh-Patches and the `org.telegram.messenger.web` build |
| <div align="center"><img src="assets/icons/line.svg" width="28"><br><b>LINE</b></div> | Andrew | Hide ads and banners, remove the VOOM, Wallet and LINE TODAY tabs, hide Home modules, keep chats unread (no read receipts), open links outside the app | ✅ | ✅ | arm64-v8a. The stock APK is self-hosted on archive.org. It is not renamed and shares `jp.naver.line.android` with the Play Store build. Uninstall the official app before you install the non-root APK |

Each app is one config entry, and it makes two output types:

* **non-root APK** — install it without root. Most APKs get a new package name, either an `app.<patch>.<pkg>` clone or the MicroG-RE variant for Google apps. Thus they install beside the official app instead of replacing it.
* **module** — a Magisk/KernelSU module that mounts the patched APK over the stock app. It keeps the original package, so it needs root and the stock app. Instagram ships as an APK only, because its module is dropped.

> **Experimental:** Instagram and Facebook use pairip integrity protection. Their patched builds can fail to run on some devices.

## Installation

* The non-root YouTube, YT Music and Google Photos APKs need [MicroG-RE](https://github.com/MorpheApp/MicroG-RE/releases).
* For every KernelSU/Magisk module, add the target app to the Zygisk **DenyList**, or the mount does not apply. Then use [**zygisk-detach**](https://github.com/j-hc/zygisk-detach) to detach the app from the Play Store, so that the Play Store cannot update it.

### Meta app clones: duplicate permission conflict

`INSTALL_FAILED_DUPLICATE_PERMISSION` occurs when an app declares a custom `<permission>` whose name an installed app already owns, and the two apps have **different signing certificates**. Android rejects the *signature mismatch*. Apps that share permission names and have the **same** signing key install together.

Meta apps declare shared family permissions, for example `com.facebook.permission.prod.FB_APP_COMMUNICATION`, across Facebook and Messenger. The rename patch keeps those `com.facebook.*` permission **names**. Thus the conflict is between a clone and the official Meta app, not between two clones:

* **The clones install together.** This repo signs Facebook (`app.devanced.facebook.katana`) and Messenger (`app.devanced.facebook.orca`) with one key, so they share a signature.
* **A clone conflicts with the official app.** The Play Store Facebook and Messenger own `com.facebook.*` under the certificate of Meta. A clone signed by this repo declares the same names under a different certificate, which gives `INSTALL_FAILED_DUPLICATE_PERMISSION`. You cannot install a Meta-signed member and a repo-signed member of the `com.facebook.*` family at the same time. Any number of repo-signed members is permitted.
* **Threads** behaves the same way. The repo-signed Threads clone conflicts with the official Threads on the shared permissions of Threads.

There are two workarounds. Uninstall the official Meta app first, or use the root **module**, which keeps the original package and needs no permission rename.

### Instagram module: Piko settings do not open

The Instagram **module** is dropped. On the mounted build with the original package, the Piko settings screen did not open. See [crimera/piko#882](https://github.com/crimera/piko/issues/882). Instagram now ships the clone APK (`app.piko.instagram.android`) only, where the settings open correctly.

### Threads: moved from De-Vanced to Chiggi

Threads now builds from [Chiggi](https://github.com/durgesh0505/chiggi_morphe_patches) instead of De-Vanced. For an existing install:

* **The clone APK has a new package**, `app.devanced.instagram.barcelona` became `app.chiggi.instagram.barcelona`. Android sees a different app, so the new APK installs beside the old clone. Uninstall the old one.
* **The module has a new name** (`threads-chiggi-*`). Magisk and KernelSU see a new module, not an update of `threads-devanced-*`.
* **The patch set is smaller**: Hide ads, and Remove AD_ID permission.

### Reddit: the clone is not active

The Reddit table sets `clone = true`, but the build does not rename the package at present. Morphe renamed its rename patch to `Clone app`. The clone detector looks for a patch named `Clone` or `Change package name` only, so it finds none and skips the rename.

* **The non-root APK keeps `com.reddit.frontpage`.** It does not install beside the official Reddit app.
* **Uninstall the official Reddit app first.** This repo signs the APK with a throwaway key, so Android refuses to install it over the official app. An uninstall erases the app data.
* **A fix comes in its own release.** The fix gives the APK the package name `app.morphe.reddit.frontpage`, which makes a second uninstall necessary. Thus it waits for a release of its own.

### Twitter / X: x-shim removed

Twitter/X is now patched with **Piko alone**. The README of Piko states that from `12.5.0-release.0` you no longer need x-shim with it, because X login and XChat work without it. Thus the second patch bundle is removed.

* **The release asset has a new name**, `twitter-piko-xshim-*` became `twitter-piko-*`. Update any download script that matches the old name.
* **No reinstall is necessary.** The package (`com.twitter.android`) and the signing key are unchanged, so the new APK installs over the old one as a normal upgrade.

### Twitter / X: module re-enabled

Twitter/X ships a **Magisk/KernelSU module** again, together with the non-root APK. The runtime problems that dropped the mounted build no longer occur on current Piko builds. The Instagram module stays dropped, because its [Piko settings bug](#instagram-module-piko-settings-do-not-open) is unchanged.

* **The module keeps `com.twitter.android`** and mounts over stock X. It needs root, the stock X app, and X on the Zygisk DenyList.
* **If you switch from the non-root APK, uninstall it first.** Twitter is not cloned, so both outputs use one package. The APK is signed with the throwaway key of this repo, so Android refuses to install stock X over it. An uninstall erases the app data.
* **Stock ships as the original signed splits.** For the `.apkm` source of X, `include-stock = "auto"` resolves to `split`. This keeps the original signature, which the server-side checks of X need.

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

Twitter and Instagram use [Piko](https://github.com/crimera/piko). Facebook, Messenger and Google Photos use [De-Vanced](https://github.com/RookieEnough/De-Vanced). Threads uses [Chiggi](https://github.com/durgesh0505/chiggi_morphe_patches), because De-Vanced [dropped it](#threads-moved-from-de-vanced-to-chiggi). Telegram uses [the morphe-patches of rushiranpise](https://github.com/rushiranpise/morphe-patches), and LINE uses [the morphe-patches of Andrew](https://github.com/andrewliang25/morphe-patches). The [Morphe CLI](https://github.com/MorpheApp/morphe-cli) drives all of them. Each stock APK is verified against the official signing certificate of the app, which `sig.txt` holds.

### Config notes

The config holds short notes only. The settings that follow need more explanation:

* **`clone = true`** (Facebook, Messenger, Threads, Photos, Reddit) — with `build-mode = "both"`, the non-root APK gets the package name `app.<patch>.<pkg>` and installs beside the official app. The module keeps the original package, so that it can mount over stock. Three tables differ. Instagram has `clone = true` but ships an APK only, see the [Piko settings bug](#instagram-module-piko-settings-do-not-open). Reddit has `clone = true`, but the rename does not happen at present, see [the Reddit clone note](#reddit-the-clone-is-not-active). Twitter ships both outputs and is not cloned, because the `Clone` patch of Piko does not cover `com.twitter.android`.
* **Self-hosted stock APKs (archive.org)** — Facebook, Messenger, Twitter, Instagram, Threads and LINE are mirrored on a self-hosted archive.org item. apkmirror returns 403 for them, and uptodown does not serve their builds reliably. They use `auto`. If the mirror has no newer version, they fall back to the second source of the app.
* **`enable-module-update`** — set it to `false` to stop in-app updates of the modules.

### CI notifications

CI posts to two Telegram destinations with the bot secret `TG_TOKEN`. Release announcements go to the public channel that the repo variable `TG_CHAT` sets. A **daily status message** (built, skipped or failed) and **build-failure alerts** go to a private admin chat that the repo variable **`TG_CHAT_ADMIN`** sets. [`.github/scripts/tg-notify.sh`](./.github/scripts/tg-notify.sh) holds the shared send logic. If a destination variable is empty, the script skips that notification.

To get the numeric id for `TG_CHAT_ADMIN`, do these steps:

1. Add the bot to the private channel as an admin.
2. Post a message in the channel.
3. Read `chat.id` from `https://api.telegram.org/bot<TG_TOKEN>/getUpdates`.

## Disclaimer

These builds come **as-is, with no warranty**, for personal and educational use. The apps are modified, that is patched and re-signed, and they are **not** official releases. You install and run them **at your own risk**. They can break, fail to update, behave in an unexpected way, or go against the terms of service of the original app. Some apps, for example apps with integrity protection, can fail to run. You are responsible for the applicable laws and for the terms of each app. The maintainer is not liable for damage, data loss, account action, or other results of their use.

## Credits

This project is a fork of [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module). All credit for the builder, the module template and the helper tooling goes to [j-hc](https://github.com/j-hc). The patches come from [ReVanced](https://github.com/ReVanced), [Morphe](https://github.com/MorpheApp), [Piko (crimera)](https://github.com/crimera/piko), [De-Vanced (RookieEnough)](https://github.com/RookieEnough/De-Vanced), [Chiggi (durgesh0505)](https://github.com/durgesh0505/chiggi_morphe_patches) and [the morphe-patches of rushiranpise](https://github.com/rushiranpise/morphe-patches).
