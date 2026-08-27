# Patched Apps

[![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/andrewspatchedapps)
[![CI](https://github.com/andrewliang25/patched-apps/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/andrewliang25/patched-apps/actions/workflows/ci.yml)

A personal Morphe patches builder that produces non-root APKs and Magisk/KernelSU modules, updated automatically via CI. Built on top of [**j-hc/revanced-magisk-module**](https://github.com/j-hc/revanced-magisk-module) — the build engine, module template, and tooling are j-hc's work.

**Grab the [latest release](https://github.com/andrewliang25/patched-apps/releases).**

Every release APK/module is published with [GitHub build provenance attestations](https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds) — confirm a file was built by this repo's CI with:

```
gh attestation verify <file> --repo andrewliang25/patched-apps
```

Contributors: please [sign your commits](CONTRIBUTING.md#signing-your-commits) so they show as **Verified**.

## Apps

| App | Patches | Major features | non-root APK | module | Notes |
| --- | --- | --- | :-: | :-: | --- |
| <div align="center"><img src="assets/icons/youtube.svg" width="28"><br><b>YouTube</b></div> | Morphe | Ad-free video, SponsorBlock, background playback, Return YouTube Dislike, custom themes | ✅ | ✅ | APK renamed (MicroG-RE) |
| <div align="center"><img src="assets/icons/ytmusic.svg" width="28"><br><b>YT Music</b></div> | Morphe | Ad-free, background playback, exclusive-audio mode, minimized playback | ✅ | ✅ | arm64-v8a; APK renamed (MicroG-RE) |
| <div align="center"><img src="assets/icons/googlephotos.svg" width="28"><br><b>Google Photos</b></div> | De-Vanced | Unlimited original-quality backup, removes the device/account model lock | ✅ | ✅ | APK renamed to `app.devanced.google.android.apps.photos` (uses MicroG-RE) |
| <div align="center"><img src="assets/icons/instagram.svg" width="28"><br><b>Instagram</b></div> | Piko | Block ads/sponsored posts, download photos/videos/reels, hide story "seen", disable typing & read receipts | ✅ | ❌ | APK renamed to `app.piko.instagram.android` — **experimental** (APK-only; the mounted module is dropped, see [Piko-settings bug](#instagram-piko-module-piko-settings-wont-open)) |
| <div align="center"><img src="assets/icons/facebook.svg" width="28"><br><b>Facebook</b></div> | De-Vanced | Block ads/sponsored posts, cleaner feed | ✅ | ✅ | arm64-v8a; tracks De-Vanced's supported build (currently `490.0.0.63.82`); APK renamed to `app.devanced.facebook.katana` — **experimental** (see [permission conflict](#meta-app-clones-duplicate-permission-conflict)) |
| <div align="center"><img src="assets/icons/messenger.svg" width="28"><br><b>Messenger</b></div> | De-Vanced | Remove Meta AI, hide the Facebook tab, hide inbox subtabs, disable typing indicator | ✅ | ✅ | arm64-v8a; tracks De-Vanced's supported build (currently `563.0.0.47.86`); APK renamed to `app.devanced.facebook.orca` — **experimental** (see [permission conflict](#meta-app-clones-duplicate-permission-conflict)); `Hide inbox ads` excluded (fingerprint gone from current builds) |
| <div align="center"><img src="assets/icons/threads.svg" width="28"><br><b>Threads</b></div> | Chiggi | Hide ads, remove the AD_ID (advertising ID) permission | ✅ | ✅ | arm64-v8a; APK renamed to `app.chiggi.instagram.barcelona` — **experimental** (see [permission conflict](#meta-app-clones-duplicate-permission-conflict)). Moved off De-Vanced, which [dropped Threads](#threads-moved-from-de-vanced-to-chiggi) |
| <div align="center"><img src="assets/icons/reddit.svg" width="28"><br><b>Reddit</b></div> | Morphe | Block ads, sanitize share links, hide recommendations/premium prompts, custom branding | ✅ | ✅ | non-root APK renamed to `app.morphe.reddit.frontpage` |
| <div align="center"><img src="assets/icons/twitter.svg" width="28"><br><b>Twitter / X</b></div> | Piko | Hide ads/promoted tweets, download media, restore chronological timeline, hide view counts | ✅ | ✅ | not cloned — both outputs keep `com.twitter.android`, so uninstall the official X app first for the non-root APK. The [module is back](#twitter--x-module-re-enabled) after being dropped over runtime issues |
| <div align="center"><img src="assets/icons/telegram.svg" width="28"><br><b>Telegram</b></div> | Rushi | Remove ads, unlock Premium, anti-delete/anti-disappearing messages, save restricted media, hide typing indicator, download speed boost | ✅ | ✅ | arm64-v8a; targets the Play Store build `org.telegram.messenger`, self-hosted stock (archive.org) pinned to the 12.10.0 build the bundle's fingerprints target (versionCode 70242); not renamed (the bundle ships no rename patch) — the non-root APK **replaces** the official app, so uninstall it first (it also uses MicroG-RE). Moved off Paresh-Patches / the standalone `org.telegram.messenger.web` build |
| <div align="center"><img src="assets/icons/line.svg" width="28"><br><b>LINE</b></div> | Andrew | Hide ads/banners, remove VOOM & Wallet / LINE TODAY tabs, hide Home modules, keep chats unread (no read receipts), open links externally | ✅ | ✅ | arm64-v8a; self-hosted stock (archive.org); not renamed — shares `jp.naver.line.android` with the Play Store build (uninstall the official app first for the non-root APK) |

Each app is a single config entry that emits two output types:

* **non-root APK** — install directly, no root. Most apps' APKs are package-renamed (a `app.<patch>.<pkg>` "clone", or the MicroG-RE variant for Google apps) so they install *alongside* the official app rather than replacing it.
* **module** — Magisk/KernelSU module that mounts the patched APK over the stock app. Keeps the original package, so it needs root and the stock app installed. (Instagram ships as APK-only — its module was dropped.)

> **Experimental:** Instagram and Facebook are integrity-protected (pairip) apps; their patched builds may not run on all setups.

## Installing

* **Non-root YouTube, YT Music, and Google Photos APKs** need [MicroG-RE](https://github.com/MorpheApp/MicroG-RE/releases) installed.
* **All KernelSU/Magisk modules:** add the target app to the Zygisk **DenyList** (or the mount won't apply), and use [**zygisk-detach**](https://github.com/j-hc/zygisk-detach) to detach them from the Play Store to prevent being updated.

### Meta-app clones: duplicate-permission conflict

`INSTALL_FAILED_DUPLICATE_PERMISSION` fires when an app defines a custom `<permission>` whose name is already owned by an installed app **signed with a different certificate**. It's the *signature mismatch* that's rejected — apps that share permission names but are signed with the **same** key install side by side.

Meta apps declare shared family permissions (e.g. `com.facebook.permission.prod.FB_APP_COMMUNICATION`) across the Facebook/Messenger family, and the package-rename patch leaves those `com.facebook.*` permission **names** intact. So the conflict is **clone vs. the official Meta app**, not clone vs. clone:

* **Our clones coexist with each other.** Facebook (`app.devanced.facebook.katana`) and Messenger (`app.devanced.facebook.orca`) are both signed with this repo's key, so they share a signature and install together fine.
* **A clone conflicts with the official app.** The Play-Store Facebook/Messenger owns `com.facebook.*` under Meta's certificate; a repo-signed clone declares the same names under a different certificate → `INSTALL_FAILED_DUPLICATE_PERMISSION`. You can't have a Meta-signed member *and* a repo-signed member of the `com.facebook.*` family installed at once — but any number of repo-signed members is fine.
* **Threads** — same story: the repo-signed Threads clone conflicts with the official (Meta-signed) Threads on Threads' own shared permissions.

Workarounds: uninstall the conflicting official Meta app first, or use the root **module** (original package, no permission rename needed) instead of the clone.

### Instagram Piko module: Piko settings won't open

The Instagram **module** has been dropped. On the mounted original-package build the Piko settings screen could not be opened — see [crimera/piko#882](https://github.com/crimera/piko/issues/882) — so Instagram now ships **only** the clone APK (`app.piko.instagram.android`), where the settings open normally.

### Threads: moved from De-Vanced to Chiggi

Threads now builds from [Chiggi](https://github.com/durgesh0505/chiggi_morphe_patches) instead of De-Vanced. For existing installs:

* **The clone APK changed package**, `app.devanced.instagram.barcelona` → `app.chiggi.instagram.barcelona`. Android treats it as a different app, so it installs alongside the old clone rather than upgrading it — uninstall the old one.
* **The module is republished under a new name** (`threads-chiggi-*`), so Magisk/KernelSU sees a new module rather than an update to the old `threads-devanced-*` one.
* **The patch set is smaller**: Hide ads and Remove AD_ID permission.

### Twitter / X: x-shim dropped

Twitter/X is now patched with **Piko alone**. Piko's README states that starting `12.5.0-release.0` you no longer need to apply x-shim alongside it — X login and XChat work without it — so the second patch bundle was removed.

* **The release asset was renamed**, `twitter-piko-xshim-*` → `twitter-piko-*`. Update any download scripts that match on the old name.
* **No reinstall needed.** The package (`com.twitter.android`) and the signing key are unchanged, so the new APK installs over the old one as a normal upgrade.

### Twitter / X: module re-enabled

Twitter/X ships a **Magisk/KernelSU module** again, alongside the non-root APK. The runtime issues that got the mounted build dropped no longer reproduce on current Piko builds. (Instagram's module stays dropped — its [Piko-settings bug](#instagram-piko-module-piko-settings-wont-open) is unchanged.)

* **The module keeps `com.twitter.android`** and mounts over stock X, so it needs root, stock X installed, and X on the Zygisk DenyList.
* **Switching from the non-root APK? Uninstall it first.** Twitter isn't cloned, so both outputs use the same package — and the APK is signed with this repo's throwaway key, so Android refuses to install stock X over it (signature mismatch). Uninstalling clears app data.
* **Stock ships as the original signed splits** (`include-stock = "auto"` resolves to `split` for X's `.apkm` source), keeping X's genuine signature intact for its server-side checks.

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

Twitter and Instagram use [Piko](https://github.com/crimera/piko); Facebook, Messenger, and Google Photos use [De-Vanced](https://github.com/RookieEnough/De-Vanced); Threads uses [Chiggi](https://github.com/durgesh0505/chiggi_morphe_patches) (De-Vanced [dropped it](#threads-moved-from-de-vanced-to-chiggi)); Telegram uses [rushiranpise's morphe-patches](https://github.com/rushiranpise/morphe-patches); LINE uses [Andrew's morphe-patches](https://github.com/andrewliang25/morphe-patches) — all driven by the [Morphe CLI](https://github.com/MorpheApp/morphe-cli). Downloaded stock APKs are signature-verified against each app's official signing certificate (`sig.txt`).

### Config notes

The config carries only brief inline notes; here's what the non-obvious settings mean:

* **`clone = true`** (Reddit, Facebook, Messenger, Threads, Photos) — with `build-mode = "both"`, the non-root APK is package-renamed to `app.<patch>.<pkg>` so it installs alongside the official app, while the module keeps the original package to mount over stock. Instagram is `clone = true` but APK-only ([Piko-settings bug](#instagram-piko-module-piko-settings-wont-open)); Twitter ships both outputs but is not cloned (Piko's `Clone` patch does not cover `com.twitter.android`).
* **Self-hosted stock APKs (archive.org)** — Facebook, Messenger, Twitter, Instagram, Threads, and LINE are mirrored on a self-hosted archive.org item because apkmirror 403s (and uptodown doesn't reliably serve) their builds. They track `auto`, falling back to each app's secondary source if a newer resolved version isn't mirrored yet.
* **`enable-module-update`** — set `false` to stop the modules from receiving in-app updates.

### CI notifications

CI posts to two Telegram destinations (both via the `TG_TOKEN` bot secret): successful release announcements go to the public channel set by the `TG_CHAT` repo variable, while a **daily status heartbeat** (built / skipped / failed) and **build-failure alerts** go to a private admin chat set by the **`TG_CHAT_ADMIN`** repo variable. The send logic is shared in [`.github/scripts/tg-notify.sh`](./.github/scripts/tg-notify.sh); if a destination variable is unset, that notification is silently skipped. To get the numeric `TG_CHAT_ADMIN` id for a private channel, add the bot as an admin, post a message, and read `chat.id` from `https://api.telegram.org/bot<TG_TOKEN>/getUpdates`.

## Disclaimer

These builds are provided **as-is, with no warranty**, for personal and educational use. The apps are modified (re-signed, patched) and are **not** official releases — installing or running them is **entirely at your own risk**. They may break, fail to update, behave unexpectedly, or violate the original apps' terms of service, and some (e.g. integrity-protected apps) may not run at all. You are responsible for complying with applicable laws and each app's terms. The maintainer is not liable for any damage, data loss, account action, or other consequences arising from their use.

## Credits

This project is a fork of [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module). All credit for the builder, module template, and helper tooling goes to [j-hc](https://github.com/j-hc). Patches are provided by [ReVanced](https://github.com/ReVanced), [Morphe](https://github.com/MorpheApp), [Piko (crimera)](https://github.com/crimera/piko), [De-Vanced (RookieEnough)](https://github.com/RookieEnough/De-Vanced), [Chiggi (durgesh0505)](https://github.com/durgesh0505/chiggi_morphe_patches), and [rushiranpise's morphe-patches](https://github.com/rushiranpise/morphe-patches).
