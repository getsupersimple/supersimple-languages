# Supersimple Languages

A free, open-source, offline language-learning app. See `../docs/design.md` for the design decisions. Content (phrases, audio, schema, build tools) lives in the separate `supersimple-languages-content` repo.

Bundle ID: `co.powerup.supersimple.languages` (to be confirmed against the other Supersimple apps before the first store upload). iOS 15+; Android.

## Run

```bash
flutter pub get
flutter test
flutter run
```

## Dev pack

The app currently reads a pack bundled in `assets/dev_pack/`, standing in for the download. Rebuild it from the content repo after content changes:

```bash
(cd ../supersimple-languages-content && .venv/bin/python tools/build.py --channel dev --out ../supersimple-languages/assets/dev_pack)
```

## Structure

```
lib/
  packs/       models for the built pack files, PackSource (where bytes come from), PackStore (verified install + offline read)
  exercises/   exercise generation from pack data (nothing is authored in packs)
  ui/          home (units) and lesson screens
  l10n/        ARB files; UI strings only, never hardcode text
  theme/       placeholder theme; platform system font on purpose
```

- **Offline by construction.** `PackStore` checks every download against the manifest's sha256 before writing, swaps a unit in as a whole, and reads only from disk.
- **UI language follows the system language.** Course content follows the course's source language, so exercise instructions (UI strings) and prompts (content) can differ.
- **Localization:** add `lib/l10n/app_<code>.arb`; `flutter gen-l10n` regenerates the Dart.

## Built so far

Verified pack install and offline load; lessons with an introduction step and six exercise types (listen and choose, translate to and from Serbian, build the sentence, match pairs, type what you hear); audio playback with a voice picked per exercise; a lemma sheet (tap a word to see its dictionary form, meaning and grammar, and hear the lemma); English and French UI; tests for all of it.

Audio uses `just_audio`. The dev pack's audio is placeholder tones (see the content repo's `tools/dev_placeholder_audio.py`), so playback has been tested with a fake player only, not heard on a device. The official codec is AAC (`.m4a`); see the content repo README.

## Not built yet

Network pack source, course picker (FROM -> TO), settings (UI language override, script), progress/XP/streaks (SQLite), Practice mode and spaced repetition, reminders, crash reporting, and the Android build (untested).
