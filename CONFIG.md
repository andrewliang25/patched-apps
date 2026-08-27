# Config

To add another app, write this:
```toml
[Some-App]
apkmirror-dlurl = "https://www.apkmirror.com/apk/inc/app"
# or uptodown-dlurl = "https://app.en.uptodown.com/android"
```

> [!WARNING]
> If a patch name contains a single quote, write that quote two times, for example 'Hide ''Get Music Premium'''.

## More about other options:

The example that follows sets every key and shows every default value.  
**All keys are optional**, except the download urls. A key that you do not set keeps its default value.  

```toml
parallel-jobs = 1                    # cores to use for parallel patching. Default: $(nproc)
compression-level = 9                # compression level of the module zip
remove-rv-integrations-checks = true # remove the checks from the revanced integrations
dpi = "nodpi anydpi 120-640dpi"      # dpi packages to search, in order. Default: "nodpi anydpi"

patches-source = "revanced/revanced-patches" # where to get the patches bundle. Default: "revanced/revanced-patches"
cli-source = "ReVanced/revanced-cli"             # where to get the cli. Default: "ReVanced/revanced-cli"
# You can also set an option like cli-source for one app.
rv-brand = "ReVanced Extended" # a different brand name than 'ReVanced'. Default: "ReVanced"

patches-version = "v2.160.0" # 'latest', 'dev', or a version number. Default: "latest"
cli-version = "v5.0.0"       # 'latest', 'dev', or a version number. Default: "latest"

# Optional. One more patch bundle, applied with patches-source in the same patch run, through
# an extra '-p' flag. Use it for a shim bundle that must go on top of a primary bundle. Like
# patches-source, it supports 'gitlab:' and GitHub. The daily update check also watches its
# release, so a new version of this bundle starts a rebuild on its own. No app sets this key at
# present. Twitter dropped inotia00/x-shim after Piko stopped needing it.
extra-patches-source = "gitlab:owner/shim-patches" # Default: not set
extra-patches-version = "latest"                   # 'latest', 'dev', or a version number. Default: "latest"

[Some-App]
app-name = "SomeApp" # the release name. Default: the table name, which is 'Some-App' here.
enabled = true       # build this app or not. Default: true
build-mode = "apk"   # 'both', 'apk' or 'module'. Default: apk
# Fork-specific. With build-mode = "both", also make an APK with a new package name. The
# apk-mode output becomes app.<brand>.<pkg>, where <brand> is rv-brand in lowercase with all
# non-alphanumeric characters removed. That APK installs beside the official app. The module
# keeps the original package, so that it can mount over the stock app. Default: false
clone = false

# 'auto' takes the highest version that all included patches support.
# 'experimental' works like 'auto', but it also counts the experimental patches (CLI -x).
# 'latest' takes the latest stable version, with no test of patch support.
version = "auto"     # 'auto', 'experimental', 'latest' or a version number such as '17.40.41'. Default: auto

# Optional arguments for the cli. You can set patch options with them.
# The config supports strings on more than one line.
patcher-args = """\
  -OdarkThemeBackgroundColor=#FF0F0F0F \
  -Oanother-option=value \
  """

# A list of patches to exclude, separated by spaces. Default: ""
excluded-patches = """\
  'Some Patch' \
  'Some Other Patch' \
  """

included-patches = "'Some Patch'"                          # non-default patches to include, separated by spaces. Default: ""

# Fork-specific. Patch overrides for one build mode, applied on top of included-patches and
# excluded-patches in a single build-mode = "both" table. They work like the GmsCore behavior of
# YouTube, but for any patch. Use them to give the apk build and the module build different patch
# sets from one table. Default: ""
apk-included-patches = "'Some Patch'"                      # include in the apk (non-root) build only
apk-excluded-patches = "'Some Patch'"                      # exclude in the apk (non-root) build only
module-included-patches = "'Some Patch'"                   # include in the module (root) build only
module-excluded-patches = "'Some Patch'"                   # exclude in the module (root) build only
include-stock = "merged"                                   # 'merged', 'split', 'auto' or 'disable'. Default: merged
                                                           #   'auto' keeps the original app signature where the source permits it:
                                                           #   the original signed splits for a bundle (.apkm) source, and the
                                                           #   unchanged single apk for all other sources.
                                                           #   CAUTION (modules only, non-root APKs are not affected): a change of an
                                                           #   existing module from 'merged' (re-signed with ks.keystore) to 'split' or
                                                           #   'auto' changes the signing key. Android then refuses the update, and the
                                                           #   user must uninstall the app first. An uninstall erases the app data.
exclusive-patches = false                                  # exclude all patches by default. Default: false

apkmirror-dlurl = "https://www.apkmirror.com/apk/inc/app"
uptodown-dlurl = "https://spotify.en.uptodown.com/android"
# A direct download url. It must point to an apk file with the name format of this example.
direct-dlurl = "https://website/com.google.android.youtube-20.40.45-all.apk"
# A self-hosted archive.org source, for an app that apkmirror or uptodown does not serve
# reliably. Point it at an archive.org folder whose path ends with the package name. The folder
# holds files named <pkg>-<version>-<arch>.apk or .apkm. The build merges an .apkm bundle.
archive-dlurl = "https://archive.org/download/my-apks/apks/com.google.android.youtube"

module-prop-name = "some-app-module"                       # the module prop name
dpi = "360-480dpi"                                         # selects the apk variant on apkmirror. Default: nodpi
arch = "arm64-v8a"                                         # 'arm64-v8a', 'arm-v7a', 'all' or 'both'. 'both' downloads arm64-v8a and arm-v7a. Default: all
```
