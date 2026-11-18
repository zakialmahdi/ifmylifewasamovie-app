# Changelog

All notable changes to **If My Life Was a Movie** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.4] - 2026-11-18

### Added
- **Journal Cheers Perspective & Co-Star Identification**: Scenes in the user's personal journal now display received cheers and who cheered, with a tap-to-view dialog listing all friends who cheered, calendar day heart indicators, and home page cheer counters.
- **Realtime Cheer Notifications**: Instant in-app banner and system push notifications when a friend cheers on the user's scene, identifying who cheered by name and handle with direct navigation to the scene.
- **Realtime Cheer Replication**: Added full row replication and publication on `public.scene_cheers` in Supabase Realtime.
- **Pattern Swatch Selection on Scene Editor**: Adding or updating journal scenes from the Calendar page now features the full horizontal calendar pattern swatch selector, matching the Home page experience.
- **Friend Feel Viewing on Friends Page**: View connected friends' exact feeling badges on the Today's Moods card and shared scene details, plus a `song | feeling` toggle on the shared calendar with friend feeling legends.
- **Custom Feelings Persistence**: Custom feelings and pattern swatches are saved to and restored from user profiles in Supabase (`profiles.custom_moods`).

### Fixed
- **Database Scene Persistence**: Resolved Postgres trigger permission denials (`private.set_updated_at`) on scene updates and upserts.
- **Hatch Check Constraints**: Expanded database constraints on `scenes` and `profiles` to support all 11 pattern hatch styles with legacy compatibility fallbacks.
- **Foreign Key Integrity**: Automatically provisions/verifies user profile rows before scene inserts to prevent foreign key errors.
- **Per-User Feeling Isolation**: Prevented friends' custom feelings from polluting the logged-in user's personal Home page chips, Scene Editor, and Calendar legend.
- **Narrow-Screen Action Wrapping**: Responsive `Wrap` layout for scene editor bottom actions to prevent overflow when deleting or updating on smaller screens.
- **Dynamic Calendar Day Circles**: Enlarged calendar circle indicators to 34px across both personal and shared calendars for enhanced touch targets and legibility.

## [1.1.0] - 2026-11-11

### Added
- **Calendar Feeling / Song Cover Toggle**: Switch day circles on the Calendar page between mood hatch swatches and circular song album covers.
- **Splash Screen App Update Check**: Checks active releases in Supabase (`public.app_releases`) on splash screen open and prompts users when a newer version is available.
- **Demo Mode Update Popup Preview**: Added a **Preview update popup** button under Settings -> More in Demo Mode to inspect the release update alert on demand.
- **First-Session Storyboard Onboarding**: 4-slide visual walkthrough with a direct YouTube Music setup step and skip note for newly registered users.

### Coming Soon
- **Calendar Widget**: Home screen widget to keep your monthly scene feelings and song album covers visible at a glance.
- **Zine Export**: Printable, fold-out movie booklet generator compiling your monthly/seasonal scenes.

## [1.0.0-beta] - 2026-11-10

### Added
- **Hand-Drawn Sketch Aesthetic**: Custom paper-and-ink styling with tactile textures, hand-drawn borders, and sketch typography.
- **Scene-Based Journaling (Home)**: Frame daily reflections, memories, and photos as scenes in your personal movie timeline.
- **Soundtrack Search & Playback**: Search tracks with YouTube Music integration and stream playback directly in-app.
- **Calendar History**: Chronological calendar navigation to scrub through past scenes and emotional arcs.
- **The Cast (Friends)**: Connect with friends, explore their shared scenes, and discover the music scoring their lives.
- **Privacy Lock**: PIN/passcode gate to safeguard personal journal entries.
- **Daily Prompts & Reminders**: Local notifications prompting daily mood logging and song selection.
- **Supabase Authentication**: Secure cloud sync with email and Google OAuth support.
- **Storyboard Onboarding Carousel**: Interactive 4-slide guide introducing the app and offering an upfront YouTube Session Bridge setup with a skip option.

### In Progress / Coming Soon
- **Zine Export**: Printable, fold-out movie booklet generator compiling your monthly/seasonal scenes.
