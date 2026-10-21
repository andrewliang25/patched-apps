---
name: check-mirror
description: Check whether the archive.org mirror already carries the stock APK that an app's build needs. Use when asked whether a mirror upload is ready, whether CI can build an app now, or why an `auto` app was skipped as not downloadable.
compatibility: Requires curl and network access to archive.org.
---

# Check the mirror

The listing is the whole check. The build verifies the signature itself, so do not download the APK.

1. From `config.toml`, take the app's `archive-dlurl`, `arch`, and target version. For `version = "auto"`, the target is the top version that the bundle supports: run `list-versions` on the bundle, or read it from the `auto` skip warning.
2. Read the folder listing: `curl -sL <archive-dlurl>/`.
3. Match the file that `dl_archive` looks for, `<pkg>-<version>-<arch>.apk[m]`, with `<pkg>-<version>-all.apk[m]` as the only fallback.
4. Report the matching filename, or the closest names that exist when nothing matches. The user starts CI.

**Done when:** you have named the exact file that matches, or shown that none does.
