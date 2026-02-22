# Tempus Mobile (Phase 0)

This repo includes the authoritative `lib/` source for the Flutter app.

Because the build environment may differ per machine, the platform folders
(`android/`, `ios/`, etc.) should be generated with `flutter create` and then
the `lib/` folder from this repo should be used as-is.

## Quick start

From `mobile/`:

1) Generate project (once)
- `flutter create tempus_app`

2) Replace `tempus_app/lib/` with this repo's `mobile/tempus_app/lib/`

3) Add dependencies in `pubspec.yaml` (this repo includes one)

4) Configure API base URL in `lib/config/env.dart`

5) Run
- `flutter run`
