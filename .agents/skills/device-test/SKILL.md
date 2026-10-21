---
name: device-test
description: Install a patched APK on a connected Android phone over adb and inspect what is really running (activity, launch intent, installed package and build). Use for a bug that only shows on the device, to prove which build is installed, or to find which activity a tap opens.
compatibility: Requires adb and a phone connected over USB with debugging enabled.
---

# Device test

`adb` is often not on PATH here. Find it (`command -v adb`, then a `platform-tools/adb` directory) or ask the user for the path. Confirm the phone with `adb devices`.

## Install and prove the build

```bash
adb install -r <apk>
adb shell pm path <pkg>                    # path of the installed base.apk
adb shell sha256sum <path from pm path>    # compare with: shasum -a 256 <apk>
adb shell dumpsys package <pkg> | grep -E "versionName|versionCode|signatures"
```

A module install mounts over the stock apk, so `pm path` names the stock path, while the hash shows the patched file once the mount is active.

## See what is running

- `adb shell dumpsys activity activities`: the resumed activity **and its launch intent**. This is how to find a URL or extra that a tap passed.
- `adb shell dumpsys window | grep mCurrentFocus`: the window that has focus.
- `adb logcat`: start capturing *before* you reproduce. `logcat -c` erases the history that would name the activity, so save the log first if you need it.

## Limits

- Activities that are not exported answer `am start -n` with `SecurityException`, so you cannot reproduce a tap that way. Ask the user to tap.
- Driving the UI with `input tap` scrolls through the user's private feeds. Ask the user to do the taps, and read the result with `dumpsys`.

**Done when:** the hash proves which build is installed, and `dumpsys` output (not a guess) explains the behaviour.
