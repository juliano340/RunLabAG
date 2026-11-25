# RunLabAG

[Português (Brasil)](README.md) · **English**

RunLabAG is a Flutter app for run tracking and personal performance. It combines GPS tracking, workout history, personal records, and analytics in a personal dashboard, with data stored locally on the device.

## Features

- GPS tracking with pace-colored routes and visual smoothing;
- Standard and instant run start;
- Manual pause, auto-pause, and automatic resume;
- Manual workout creation and editing;
- Route drawing by taps or freehand strokes;
- Workout history with navigation between activities;
- Personal records and monitored distances;
- Weekly, monthly, and period comparison analytics;
- Workout sharing with multiple layouts;
- Local data backup and restore.

## Tech stack

- Flutter and Dart
- Provider for state management
- sqflite for local persistence
- Google Maps and geolocator
- google_mobile_ads
- Firebase Analytics and Crashlytics
- lucide_icons
- Bundled Outfit, Space Grotesk, and Inter fonts

## Project structure

```text
lib/
├── app/
│   └── composition_root.dart
├── core/
│   ├── data/repositories/
│   ├── domain/models/
│   ├── domain/repositories/
│   ├── domain/services/
│   ├── services/
│   └── widgets/
└── features/
    ├── run/
    │   ├── application/
    │   ├── data/
    │   └── domain/
    ├── history/
    ├── dashboard/
    ├── analytics/
    ├── profile/
    ├── onboarding/
    └── strength_training/
```

## Architecture

- `app/composition_root.dart` builds the dependency graph once;
- `RunSessionController` owns GPS, timer, auto-pause, splits, and persistence,
  while `ActiveRunScreen` handles only UI, maps, and navigation;
- Repositories are consumed through domain interfaces, with sqflite
  implementations and cache decorators in the data layer;
- Screens use narrow repositories; `DatabaseService` remains as compatibility;
- `BackupStore` isolates the v4 backup schema, including pace zones, plans,
  sessions, and the exercise dictionary;
- `ReadModelCache` shares summaries, profile, records, and statistics across
  tabs, with single-flight behavior and scope-based invalidation;
- `DataChangeHub` notifies only the tabs that depend on the changed data;
- `LatestRequest` prevents stale loads from overwriting newer results.
- Run updates are split into a 1-second tick, structural state, and route changes;
- `LivePaceTrace` accumulates the pace-colored route incrementally and
  reconciles with the full analysis at kilometer marks, pauses, and finish;
- Run confirmation stores the workout, pace zones, and draft cleanup in a
  single transaction.

## Requirements

- Flutter SDK 3.41 or newer
- Android Studio or VS Code
- Android device or emulator

## Setup

1. Install dependencies:

   ```bash
   flutter pub get
   ```

2. Configure the Google Maps key in `android/local.properties`:

   ```properties
   MAPS_API_KEY=your_key_here
   ```

3. To enable Firebase services, add your
   `android/app/google-services.json` file. This file is not versioned.

4. To generate signed release builds, create `android/key.properties` with
   your keystore details. This file is not versioned.

## Running

```bash
flutter run
```

On Android, the app requests the location, notification, and storage
permissions required for tracking and automatic backup.

## Release build

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

The arm64 APK is generated at:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Tests

```bash
flutter test
flutter analyze
```

## Data and backup

Workouts and profile data are stored locally with sqflite. When automatic
backup is enabled and storage permission has been granted, backup files are
saved to:

```text
/Download/RunLab/
```

Backups can be restored from the profile screen.
