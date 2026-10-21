---
name: adhoc-patch-build
description: Patch one app by hand outside build.sh (merge the stock bundle, sign it, run morphe-cli), with a local .mpp patch bundle or a released one. Use when asked to build an app "with version X", "with all patches", "on local" or "on remote", to try a dev patch bundle, or to test a patch on a specific APK.
compatibility: Requires Java 21 and the jars in temp/ and bin/; runs natively on macOS or Linux, no Docker.
---

# Ad-hoc patch build

An ad-hoc build is three jar calls, so it runs natively; Docker is only for `build.sh` (see `local-build-verify`). Per-app notes are in [references/apps.md](references/apps.md); read the app's section first.

## 1. Get the patch bundle

- **"On remote" means the released bundle.** The build still runs locally. Download the asset of the named tag (prereleases work) and check its sha256 against `gh release view <tag> -R <owner>/<repo>`.
- **A local `.mpp`**: copy the current source file and record its sha256 (`shasum -a 256`) before *every* build. A copy staged earlier is reused by filename alone, so a rebuilt source with the same version builds stale (see "Local bundle in build.sh" below).

## 2. Choose the patches

List them on the bundle you will actually use; the default-enabled set changes between bundle builds:

```bash
java -jar <cli.jar> list-patches --patches <mpp> -f <pkg>
```

**"All patches" means all**, including default-disabled ones. Add `-e "<name>"` for each:

```bash
java -jar <cli.jar> list-patches --patches <mpp> -f <pkg> \
  | awk '/^Name: /{n=substr($0,7)} /^Enabled: false/{print n}'
```

## 3. Build

Use Java 21 (the Morphe CLI fails on 17). On the maintainer's Mac the default `java` is newer, so set `JAVA_HOME` to a JDK 21.

```bash
# a bundle (.apkm/.xapk) needs a merge first; a single .apk skips steps 1–2
java -jar temp/apkeditor.jar merge -i <stock.apkm> -o <stock>-unsigned.apk -clean-meta -f
java -jar bin/apksigner.jar sign --ks ks-p12.keystore --ks-pass pass:123456789 \
  --key-pass pass:123456789 --ks-key-alias andrewliang --out <stock>.apk <stock>-unsigned.apk
java -jar <cli.jar> patch <stock>.apk -o build/<App>/<name>.apk -p <mpp> \
  --keystore=ks.keystore --keystore-entry-password=123456789 --keystore-password=123456789 \
  --signer=andrewliang --keystore-entry-alias=andrewliang -t <tmpdir> [-e "<name>" …]
```

`<cli.jar>` is the Morphe CLI: `build.sh` caches it as `temp/<cli-owner>-rv/*cli-<ver>.jar`, or download it from the `MorpheApp/morphe-cli` releases. `temp/apkeditor.jar` is fetched by the first bundle merge of any `build.sh` run.

**Done when:** the log has one `Applied:` line per patch you meant to apply, and none for a patch you did not. Report the bundle sha256 and the output path.

## Local bundle in `build.sh`

`get_prebuilts` has no local-path option. To make `build.sh` use a local bundle, copy it to `temp/<patches-source-owner-lowercased>-rv/patches-<ver>.mpp` and pin `patches-version = "<ver>"`. The cache matches by filename and version only, never by content, so re-copy the source before every run.
