# Tempus Vista (Tempus Victa) — Recovered Working Directory

This ZIP is a **sanitized, single working Flutter/Android project directory** assembled from the provided archive.

## What I fixed immediately (so it compiles)
### 1) Dart type-split / duplicate class bug (TempusNavItem mismatch)
You had **mixed import styles**:
- `import '../../ui/tempus_nav.dart';` (relative)
- `import 'package:mobile/ui/tempus_nav.dart';` (package)

In Dart these become **two different libraries**, so `TempusNavItem` existed as two *distinct* runtime types and caused:
`List<TempusNavItem/*1*/>` not assignable to `List<TempusNavItem/*2*/>`.

✅ Fix: **standardized all internal imports to `package:mobile/...`** (no more relative `../` imports).

### 2) Removed build/cache junk
Removed from the recovered zip:
- `android/.gradle/` (huge cache; never belongs in source control)
- common local build/cache folders if present (`build/`, `.dart_tool/`, etc.)

### 3) “Open every permission” (AndroidManifest)
Added a broad set of Android permissions (mic, contacts, calendar, location, media, etc.) to `android/app/src/main/AndroidManifest.xml`.

> NOTE: Runtime permission prompts are still required on modern Android.  
> Also, Google Play policy would restrict some permissions—**but you explicitly said this is personal-only**.

## What is intentionally NOT changed
- **Nav bar NOT in RootShell** stays enforced (RootShell swaps pages only).
- Existing feature modules remain in place (Bridge, Signals, Corkboard, Ready Room, Recycle, etc.).

## How to run
```powershell
cd C:\Projects\tempus_victa   # or wherever you unzip this
flutter clean
flutter pub get
flutter run
```

### Impeller / software rendering note
If you ever run with `--enable-software-rendering`, Flutter can crash if Impeller is enabled.
Fix: **do not use software rendering**, or explicitly disable Impeller for that run.

## Next build priorities (from your notes)
1) **Unify DB + Provider layer** (single canonical DB surface + schema + repos)
2) **Universal Input Bar** everywhere (text + mic + send) -> outputs `CapturedInput`
3) **Bridge “ADHD dump”**: press=record, release=stop -> transcribe -> create Inbox Task immediately
4) **Timestamps enforced at insert/update layer** (capturedAtUtc / createdAtUtc / modifiedAtUtc / source)

