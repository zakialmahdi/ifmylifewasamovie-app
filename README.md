# 🎬 If My Life Was a Movie

> A song-based mood journal with a conceptual sketch UI.

[![Flutter](https://img.shields.io/badge/Flutter-3.13+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Release](https://img.shields.io/badge/Release-v1.0.0--beta-orange)](https://github.com/zakialmahdi/ifmylifewasamovie-app/releases/tag/v1.0.0-beta)

---

## 📽️ Concept

What if every day was a scene, and your memories formed a movie?

**If My Life Was a Movie** is a cinematic journaling app designed around an intimate, hand-drawn sketch aesthetic. Instead of standard text boxes, your thoughts are captured as film scenes complete with a title, personal reflections, photos, and a handpicked soundtrack powered by YouTube Music.

---

## ✨ Features

- 🎬 **Scene Journaling**: Frame your daily thoughts, reflections, and captured photos as scenes in your personal movie timeline.
- 🎵 **Soundtracks for Life**: Search YouTube Music and attach a soundtrack song to each scene, playable directly inside the app.
- ✏️ **Sketch & Ink Aesthetic**: Custom visual design resembling a physical director's notebook with rough-drawn borders, tactile paper texture, and ink typography.
- 📖 **Zine Generator**: Compile and export your scenes into a stylized, printable movie zine to physically commemorate a month, season, or year.
- 👥 **The Cast (Friends)**: Add friends to share moments and discover what songs score their daily scenes.
- 📅 **Calendar Navigation**: Easily scrub through past scenes and emotional arcs chronologically.
- 🔒 **Privacy Lock**: Protect your private diary and entries with a PIN lock screen.
- ⏰ **Daily Scene Prompts**: Scheduled local notifications reminding you to score today's scene.

---

## 📸 Preview

| Home & Timeline | Scene Editor & Music | Zine Export |
| :---: | :---: | :---: |
| *(Add your screenshot here)* | *(Add your screenshot here)* | *(Add your screenshot here)* |

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.13.7`)
- **Backend & Auth**: [Supabase](https://supabase.com) (PKCE Auth, PostgreSQL, Realtime)
- **Audio & Media**: [`just_audio`](https://pub.dev/packages/just_audio), [`youtube_explode_dart`](https://pub.dev/packages/youtube_explode_dart)
- **Navigation**: [`go_router`](https://pub.dev/packages/go_router)
- **Notifications**: [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications), [`timezone`](https://pub.dev/packages/timezone)

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.13+ recommended)
- Android Studio / Xcode / VS Code
- A configured [Supabase](https://supabase.com) project

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/zakialmahdi/ifmylifewasamovie-app.git
   cd ifmylifewasamovie-app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

4. Build a release APK (Android):
   ```bash
   flutter build apk --release
   ```
   The generated binary will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📦 Releases

Download the latest pre-release APK on the [Releases Page](https://github.com/zakialmahdi/ifmylifewasamovie-app/releases).

---

## 📝 License

Distributed for personal and open testing. See repository for details.
