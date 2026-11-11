# 🎬 If My Life Was a Movie

**Latest Version: `v1.1.0`** · [Download APK](https://github.com/zakialmahdi/ifmylifewasamovie-app/releases) · [Changelog](CHANGELOG.md)

*If My Life Was a Movie* is a song-based mood journal designed with an intimate, hand-drawn sketch aesthetic. Turn your days into scenes, your memories into cinema, and score every moment with the soundtrack of your life.

---

## 📸 App Preview

| Home Timeline | Song Search | Calendar View | The Cast (Friends) |
| :---: | :---: | :---: | :---: |
| <img width="220" alt="Screenshot_20261111-035355" src="https://github.com/user-attachments/assets/edbf669d-2be1-48f9-9af1-239e64f6ba28" /> | <img width="220" alt="Screenshot_20261111-035454 (1)" src="https://github.com/user-attachments/assets/c04fb3e2-34ed-43e2-8271-3e45d4821df3" /> | <img width="220" alt="Screenshot_20261111-035410" src="https://github.com/user-attachments/assets/7f92ea2f-5d9b-4b03-8826-db645846943a" /> | <img width="220" alt="Screenshot_20261111-035402" src="https://github.com/user-attachments/assets/2530abd0-853c-48e0-aea1-476f3901a98f" /> |

---

## 🆕 What's New in v1.1.0

* 🎨 **Calendar Feeling / Song Cover Toggle**: Switch day circles on the Calendar page between mood hatch swatches and circular song album covers.
* 📖 **First-Session Storyboard Onboarding**: Streamlined 4-slide visual guide for newly registered users with a direct YouTube Music setup step (and clear notes on playback limits if skipped, plus replay in Settings).
* 🔄 **Splash Screen App Update Check**: Automatically checks active releases in Supabase (`public.app_releases`) when the splash screen opens and prompts users when a new build is ready.
* 🎬 **Demo Mode Update Popup Preview**: Added a **Preview update popup** button under **Settings → More** in Demo Mode so anyone exploring the demo reel can inspect the update alert on demand.
* 📱 **Layout Polish**: Improved narrow-screen button wrapping in dialog cards and invite-ticket rows in Settings.

---

## ✨ Features

* 🎬 **Scene-Based Journaling (Home)**: Frame daily reflections, feelings, and captured photos as scenes in your personal movie timeline.
* 🎵 **Soundtrack Search & In-App Playback**: Search tracks via YouTube Music integration, pair a soundtrack with every scene, preview clips, and stream playback right inside the app.
* 📅 **Calendar History**: Scrub chronologically through past scenes and switch between **feeling** swatches and **song** album covers.
* 👥 **The Cast (Friends)**: Add co-stars via invite ticket codes, browse shared daily scenes, and discover the songs scoring your friends' lives.
* ✏️ **Hand-Drawn Sketch Aesthetic**: Custom paper-and-ink UI featuring switchable sketch paper styles (`plain`, `lined`, `grid`), tactile borders, and expressive typography.
* 🔒 **Privacy Lock**: Protect personal journal entries behind a 4-digit PIN passcode gate.
* ⏰ **Daily Prompts & Reminders**: Customizable daily local notifications and optional mood prompts before saving today's scene.
* ☁️ **Supabase Cloud Sync & Demo Reel Mode**: Sign in with email or Google OAuth for cloud persistence, or jump straight into an offline Demo Reel from the sign-in screen.

---

## 🚧 Coming Soon

* 📆 **Calendar Widget**: Home screen widget to keep your monthly scene feelings and song album covers visible at a glance.
* 📖 **Zine Export**: Printable, fold-out movie booklet generator compiling your monthly or seasonal scenes.

---

## 📥 Download & Install

### Android (`.apk`)
1. Download **`ifmylifewasamovie-v1.1.0.apk`** from the **Assets** section on the [Releases Page](https://github.com/zakialmahdi/ifmylifewasamovie-app/releases).
2. Open the `.apk` file on your Android device.
3. If prompted, allow installation from unknown sources for your browser or file manager.

*(iOS and Web builds are planned for future testing phases.)*

---

## 🛠️ Built With

* **Framework**: Flutter & Dart (`sdk: ^3.13.7`)
* **Backend & Updates**: Supabase (`supabase_flutter`) for Auth, database sync, storage, and `public.app_releases` version checks
* **Navigation & Audio**: `go_router`, `just_audio`, `youtube_explode_dart`, and `flutter_inappwebview` (YouTube session bridge)
* **Utilities**: `flutter_local_notifications`, `package_info_plus`, `image_picker`, `google_fonts`

---

## 🧪 Beta Notes & Feedback

* YouTube playback, metadata lookups, and launch update checks require an active internet connection.
* Connecting your YouTube session during onboarding (or later under **Settings → Connect YouTube session**) improves full-track streaming reliability.
* Found a bug or want to suggest a scene idea? Open an issue on [GitHub Issues](https://github.com/zakialmahdi/ifmylifewasamovie-app/issues) or use the in-app **Suggest a feature / feedback** option in Settings.

For the full version history across `v1.0.0-beta` and `v1.1.0`, see [CHANGELOG.md](CHANGELOG.md).

Thank you for being part of the first audience — built by lone developer `zakialmahdi` 🍿
