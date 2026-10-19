# Student Android workspace

This directory is the independent Flutter Android student application. The current package/application ID is `com.campura.one.campura_one_student`. Its entry point is `lib/main.dart`; UI lives in `lib/src/`. Android-only setup is in `android/app/`.

The iOS reference is `../../iOS端-原生Swift/CampuraOne/`. Read its current code and `../../../Server/` before changing data contracts. Do not edit iOS or PHP student endpoints as a side effect of Android UI work. The workspace root `../../../AGENTS.md` also applies.

The first Android milestone uses local, visibly marked demo identity/content. Login, authenticated student profile, official schedules/announcements, and online catalog/search are not connected yet. Fixtures in `lib/src/demo_data.dart` are display data, never evidence of a database or API response. Server JSON uses `{code,message,data}`; follow `JSONMapper.swift` and actual PHP endpoints when connecting the client. Do not hardcode a student ID or production credentials.

`lib/src/home_page.dart` owns the dashboard tiles and the two separate announcement entry points. Markdown important notices open `MarkdownAnnouncementsPage`; daily/emergency short notices open `AnnouncementsPage` in `lib/src/detail_pages.dart`. `lib/src/announcement_feed.dart` implements authenticated notice and AI-summary reads for the future login flow, but the current demo shell has no student Bearer token and must not label local content as AI output. Pass a real token and HTTPS API base URI through `AppShell` when login is ready; never embed a token in source or `--dart-define`.

UI is Material 3 with Android wallpaper dynamic color and light/dark modes. The map uses AMap's official Flutter map plugin with local build and Dart 3 compatibility patches in `third_party/`; read `third_party/PATCHES.md` before changing it. Supply its Android Key through `--dart-define=AMAP_ANDROID_KEY=...` for local builds. The Key must be registered against this app's package name and signing SHA1. Do not commit the Key or a signed configuration file. AMap initializes only after the in-app disclosure and consent; keep that order if editing the map.

Run `flutter pub get`, `flutter test`, and an Android build from this directory. If Flutter analysis crashes due the Chinese parent path, run commands through a temporary ASCII symlink to this directory. Do not change the iOS project or root migration documents while working here unless the task asks for cross-workspace documentation.
