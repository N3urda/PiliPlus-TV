# Android TV Video MVP Implementation Plan

> **For agentic workers:** Execute this plan inline in this session. The user requested direct implementation and a testable APK. Track the steps below; verify each working slice before moving on.

**Goal:** Deliver a separately installable Android TV build that can launch from the TV home screen and complete recommendation/search → video detail → playback with a D-pad, plus QR sign-in.

**Architecture:** Keep PiliPlus's HTTP, account, video models, and media-kit playback. Add a TV-only Flutter shell selected by a compile-time flag, with a small set of focusable screens. Adapt the existing video route for TV remote semantics and preserve the mobile route for upstream reuse. Package the fork under its own Android application ID.

**Tech Stack:** Flutter 3.47.5, Dart, Android Gradle, GetX, media-kit, existing PiliPlus HTTP and account modules.

---

### Task 1: Establish the TV build and baseline

**Files:** `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, Android resources, `lib/main.dart`, `lib/tv/tv_mode.dart`.

- [ ] Prepare the pinned Flutter SDK and Android SDK; run the existing test suite and a baseline Android build.
- [ ] Add an independent TV application ID, label, launcher banner, Leanback entry, no-touch declaration, and landscape behavior.
- [ ] Add a compile-time TV flag; initialize TV playback defaults before the app widget is created.
- [ ] Add a manifest/build verification script or test that checks the TV package identity and required entries, then run it.

### Task 2: Remote control and TV shell

**Files:** `lib/tv/widgets/tv_focusable.dart`, `lib/tv/pages/home.dart`, `lib/tv/router.dart`, `lib/main.dart`, `test/tv/`.

- [ ] Write a failing widget test for focused card visibility and D-pad selection.
- [ ] Implement a focusable TV card and a landscape home screen with recommendation and hot-video rows using existing HTTP methods.
- [ ] Implement deterministic initial focus, scrolling into view, loading/error/retry states, and back navigation.
- [ ] Run widget tests and static analysis for touched files.

### Task 3: Video discovery and QR login

**Files:** `lib/tv/pages/search.dart`, `lib/tv/pages/login.dart`, `lib/tv/pages/home.dart`, `test/tv/`.

- [ ] Write failing tests for TV search submission/results and QR expiry/retry behavior where these can be tested without network access.
- [ ] Implement video-only search through the existing search API, using the TV's system input method.
- [ ] Implement a focusable QR sign-in page using the existing login and account services.
- [ ] Run focused tests and static analysis.

### Task 4: TV video detail and playback

**Files:** `lib/tv/pages/video_detail.dart`, `lib/pages/video/widgets/player_focus.dart`, `lib/pages/video/view.dart`, `test/tv/`.

- [ ] Write failing tests for TV remote mapping: center play/pause, left/right seek, up/down controls, back dismiss/return.
- [ ] Implement a TV video detail page with title, cover, uploader, and episode list; reuse the existing video route/player for playback.
- [ ] Give the player TV-specific remote controls and visible playback affordances while retaining non-TV keyboard behavior.
- [ ] Run focused tests, static analysis, and the full test suite.

### Task 5: Build and device acceptance

**Files:** `.github/workflows/` TV build workflow, `README.md`, release artifact.

- [ ] Build a signed or clearly marked test APK for ARM TV devices; inspect package ID, banner, launcher category, and supported ABIs.
- [ ] Install and exercise the APK in a TV emulator and, if available, real TV hardware: launch, focus navigation, search, QR display, video playback, seeking, episodes, back, and relaunch.
- [ ] Document exact install path, tested hardware/runtime, remaining limitations, and upstream attribution.
- [ ] Commit and push the verified branch; attach the APK as a GitHub Actions artifact or release asset so the user can install it.
