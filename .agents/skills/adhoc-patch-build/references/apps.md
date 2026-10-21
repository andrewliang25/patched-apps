# Per-app notes for ad-hoc builds

## LINE (`jp.naver.line.android`)

- Bundle: `andrewliang25/morphe-patches`.
- "Build all patches" always includes the default-disabled patches. Earlier dev builds were each followed by "include the disabled one too".
- Patch names have the form `[Category] Name` since v3.0.0. Take them from `list-patches`, never from an older config.
- Reference size: 26.14.0 (123 MB apkm → 208 MB merged) took ~34 s to merge and ~72 s to patch.

## Instagram (`com.instagram.android`)

- Copy `arch` from `config.toml`. Do not assume a value. On the archive.org mirror, `arch` selects **which `.apkm` variant is downloaded** (`dl_archive` matches `<version>-<arch>` and falls back to `-all` only), and different variants of one version string can be different builds.
- A fingerprint failure (for example `ExperimentsGetMobileConfigSpecifier` on `Add settings`) usually means the wrong variant. Try the other mirrored variant before you blame the bundle.
- Check the **version code**, not only the version string. apkmirror ships two builds titled `Instagram 439.0.0.37.89 (arm64-v8a) (480dpi)`: 384510796 (205 MB, 7 splits) and 384510827 (123 MB, 2 splits). The bundle targets 384510827. A re-upload can swap the file behind a path, so re-check after any re-upload.
