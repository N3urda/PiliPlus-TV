# PiliPlus TV test version

This fork is an Android TV video-only prototype based on [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus). It retains the upstream GPL-3.0 license and uses its network, account and playback modules.

## Included in v0.1.1

- Android TV launcher entry, landscape UI and D-pad focus navigation.
- Recommended and popular videos, video-only search, video detail and episode selection.
- Bilibili HD QR sign-in, using the existing account store.
- Existing PiliPlus video player with TV remote controls: Select/Enter toggles playback, Left/Right seek, Up/Down show controls, media next/previous switch episodes, Back returns.
- TV defaults to a clear video picture without danmaku; users can turn it on in player settings. The first video takes focus when feeds load, and refreshing feeds keeps existing cards visible while loading.

The TV home screen does not expose live streams, comics, articles, social feeds or downloads. Search is limited to videos.

## Install

Download `PiliPlus-TV-v0.1.1-test.apk` from the Android TV test APK workflow artifact or the tagged test release. Install with `adb install PiliPlus-TV-v0.1.1-test.apk`, or sideload it from a USB drive. The package ID is `com.n3urda.piliplustv`, so it can coexist with the upstream mobile app. The test APK uses a temporary debug signing key; uninstall an earlier test build if Android reports a signature mismatch. Uninstalling removes this app's data.

## TV behavior

Use the remote direction keys to move between cards and actions, then press Select to open. Search uses the TV system keyboard. On the video screen, Select pauses or resumes and the arrow keys seek or reveal controls. The app asks Bilibili for the same streams as PiliPlus; available quality and whether an account can play a video depend on Bilibili permissions and current service responses.

This is an early test build. Please report the TV brand/model, Android version, the affected video BV number and the exact remote action if playback or focus fails.
