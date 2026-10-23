# Supersimple Languages — Design Document

Status: agreed in a design interview, before any code. This is the source of truth for v1 decisions.

## 1. Mission

Supersimple Languages is a free, open-source language-learning app for languages that Duolingo does not cover. It is not trying to compete on revenue. It exists to offer a completely free alternative with none of the business practices the project objects to.

It is part of the Supersimple suite (Habits, Units, Dice, Languages). The suite's rule: each app works exactly for what it claims to do and nothing more.

- **Store name:** "Supersimple Languages" (the suite name makes it discoverable; "Languages" alone is too generic to search or trademark). Add a store subtitle such as "Offline phrases for travelers".
- **Repos:** `supersimple-languages` (app) and `supersimple-languages-content` (content).
- **Bundle ID:** chosen once and never changed, following the suite pattern (for example `co.powerup.supersimple.languages`, to be confirmed against the other suite apps).
- **Branding:** code is under an open-source license. The name and logo are reserved by a separate trademark policy. The mascot and visual style are original, not derived from Duolingo's owl, green, or type.

### Permanent non-goals

Documented in the README and `CONTRIBUTING.md`:

- Accounts, cloud sync, or any server the learner depends on
- Ads, subscriptions, in-app purchases, or lives/hearts that gate progress
- Social features: friends, leagues, leaderboards
- An AI chat tutor or any live LLM call at runtime
- Tracking beyond opt-in crash reports
- Anything unrelated to learning a language

Gamification stays, as a means to the goal: streaks, XP, a unit map, and animations.

## 2. v1 scope

- **One course:** English → Serbian, Tourist.
- **Content:** 4 units (greetings and politeness, restaurants and cafés, directions, emergencies and health), about 60 phrases and 100–150 lemmas. All reviewed by a native speaker, all with ElevenLabs audio.
- **App features:**
  - All seven exercise types
  - Unit path with unlocking, and test-out
  - Practice mode with spaced repetition
  - XP and streaks with animations
  - Lemma popup
  - Daily reminder
  - Pack download and updates
  - UI localization infrastructure, with English plus French as the first extra UI language
  - Opt-in crash reports
- **Left out of v1:** sideloading UI, home-screen widgets and icon switching, the Cyrillic "read the signs" unit, multiple voices, other source languages' course content, speaking exercises.
- **Release path:** TestFlight → App Store → Google Play (once Android testers exist). Development and testing start on Apple devices.

Later course tiers per language: Tourist, Beginner, Intermediate, Advanced, Fluent. The data model supports many courses per language from day one.

## 3. App

- **Framework:** Flutter (strong animation and predictable performance matter for the gamified UI), iOS and Android.
- **Local-only.** Progress is stored on the device (SQLite). Export and import of a backup file is supported.
- **Progression (hybrid):**
  - A fixed path of units. Each lesson has about 10 exercises (3–5 minutes). Completing a unit unlocks the next, and learners can test out of a unit.
  - A Practice mode that uses on-device spaced repetition (Leitner-style or FSRS) to resurface items due for review.
  - XP and streaks are earned from either.
- **Progress is keyed by stable IDs** (concept and lemma IDs), never by position or text.

### Exercise types (engine-generated from pack data)

1. Listen and choose the meaning (Serbian audio → English)
2. Translate to Serbian (English → pick the Serbian)
3. Translate from Serbian (Serbian text → pick the English)
4. Build the sentence (word tiles)
5. Match pairs
6. Type what you hear
7. Flashcard introduction

The engine generates exercises. Packs do not contain authored exercises. No speaking exercises.

### Tiles and inflected forms

Lemmas have standalone audio, and so does every inflected form a phrase uses (stored as `forms` on its lemma). Pressing a word tile speaks that word as written in the phrase ("sam", not "biti"), in the exercise's voice. In the introduction card, pressing a tile also opens a popup with the lemma ("kafa"), its gloss and a grammar note; the speaker in the popup plays the lemma's own audio. A form without a recording falls back to the lemma's audio. A token whose spelling equals the lemma text needs no form.

### Voices

The system picks a random voice per generated word exercise (learners do not choose). The voice stays constant within a single exercise.

### Gamification

XP, daily streak (with a gentle freeze), a unit map, a mascot, and celebratory animations. No hearts, leagues, or friends.

### Reminders

One opt-in daily reminder at a learner-set time, offered after the first completed lesson. An evening "streak about to end" nudge sends only if the learner hasn't practiced that day. Local notifications only.

### Fonts

The platform system font is used (SF on iOS, Roboto on Android). No bundled font. Each new script is tested on a real device when added.

### Defaults assumed

- Accessibility basics: screen-reader labels, dynamic text size, reduced-motion respect.
- A privacy policy page stating that no data is collected.
- Unit and widget tests for the exercise engine and pack validation.

## 4. Languages, courses, and localization

- A **course** is a FROM → TO pair (for example English → Serbian, French → Serbian). FROM is the language the learner speaks and supplies prompts, glosses, hints, and translations. TO is the language being learned and supplies the practiced text and audio. A learner can have several courses, each with its own progress.
- A course is only offered if its pack exists: the TO language has audio, and the FROM language has a text layer for the same concepts. The picker lists only existing pairs.
- **UI language** is independent of the course. It follows the system language by default, with a settings override, and covers menus, buttons, exercise instructions, feedback, and notifications. Exercise instructions follow the UI language, while content (prompts, glosses, hints) follows the course's FROM language.
- The system locale only provides defaults: the initial UI language, and the pre-selected FROM for a new course.
- **Localization is built in from the first commit:** `gen_l10n` with ARB files, ICU plurals and gender, RTL support, locale-aware formatting, and no text baked into images or animations. Fallback is English when a UI string is missing.

## 5. Content model

### Concepts

- A **concept** is a language-neutral item with a stable key (for example `where-is-the-bathroom`). A key never changes meaning and is never reused. A typo fix in the gloss keeps the key. A change of meaning creates a new concept, and the old one is retired (progress on retired concepts is preserved).
- Each concept has an English **gloss** and notes (register, speaker-gender/number variants, country-specific tag). The gloss is a reference for translators, not a translation source. Each language is translated from the concept, never from another language's version, so errors do not chain.
- Variants (masculine/feminine speaker, formal/informal) are children of the same concept key.
- Tourist content depends on destination. A concept set per course includes a country-specific tag for entries such as "Do you accept dinars?".

### Text layers and audio

- Text is stored per language per concept. Any (FROM, TO) pair is possible once both languages have a layer for the same concepts.
- Audio is stored per language as a **list of recordings** per text item. Each recording carries voice metadata (gender, voice ID, accent/region, speed) and its generator. v1 uses a single ElevenLabs voice per language (Serbian: the Voice Library voice "Jovana", id `g8TYYIFt2Qo27yGQmTYq`).
- Serbian is written Latin-first. Cyrillic is stored for every item, generated deterministically from the Latin (one-to-one mapping) and reviewed. A setting toggles display. The Cyrillic "read the signs" unit is later.
- Serbian uses Ekavian pronunciation and the formal "Vi" register by default (confirmed by the native reviewer).

### Tokens, lemmas, and words

- Every token in a phrase links to a **lemma** (dictionary form) with a grammar tag and a context gloss. Uninflected words are their own lemma.
- Only lemmas get standalone audio, generated once and reviewed. Inflected forms are heard only inside sentence recordings.
- Vocabulary exercises, flashcards, the word list, and spaced repetition operate on lemmas.
- Possible later upgrade: cut per-token audio from sentence recordings by forced alignment, without a schema change.

### Review state

Every item records `reviewed`, reviewer, and date. Nothing unreviewed is published.

## 6. Content pipeline

1. **Concepts:** an LLM proposes concepts per situation, each with a gloss, register, variants, and tags. The owner curates.
2. **Target text:** an LLM writes the target-language text. A deterministic script produces Cyrillic from Latin. The LLM tokenizes, lemmatizes, tags grammar, and writes glosses.
3. **Automated checks:** schema validation, duplicate detection, and a second LLM pass that flags suspicious items for the reviewer (it flags, the reviewer decides).
4. **Native review** in a small review web page: audio player, edit fields, Approve / Fix / Reject. Decisions are written back into the data.
5. **Audio:** ElevenLabs generates sentence and lemma clips for approved text only.
6. **Build:** CI validates, checks audio is in the official format (AAC) and rejects oversized files, and publishes packs.

Prompts are versioned in the content repo. Every item records the model, prompt version, and date, and human edits are tracked. Generated data is committed, so builds never depend on rerunning an LLM. Anyone can regenerate with their own keys. Pipeline scripts are in Python, with a JSON Schema as the contract with the app.

## 7. Audio licensing

- Official audio uses ElevenLabs voices on a paid plan, generated in one stretch, with the terms read and a copy and an invoice kept on file. Serbian uses the Voice Library voice "Jovana" (chosen over the stock voices because it is a native Serbian voice); the Voice Library addendum applies to it and has not been checked yet.
- The terms (checked during design) allow commercial use on paid plans, give output rights to the user, and require no attribution. They are silent on redistribution of output in a public repo, and the Voice Library has a separate addendum. To be safe, email ElevenLabs to confirm in writing that redistribution in an open repo is allowed.
- Code, text content, and audio are licensed separately so the audio can be replaced if needed.
- **Human recordings** (community voices) are out of scope for official v1 packs. They live in unofficial, sideloaded packs not hosted or endorsed by the project. When the project first accepts a human recording, add the consent text (CC0, irrevocable for copies already made, voice is personal data) and a `REMOVAL.md` process (remove from `main` and future packs, rewrite history when feasible). Consider a short legal check for EU/Serbian privacy rules, since a CC0 waiver covers copyright but not necessarily personal-data rights.

## 8. Repositories and distribution

- **`supersimple-languages`** — the Flutter app.
- **`supersimple-languages-content`** — pack text and metadata, AAC audio in Git, JSON Schema, generation and review tools, laid out as `languages/<code>/…`. Contributors use sparse checkout and partial clones to fetch only one language. Split per-language repos only if the repo passes about 1 GB.
- **Hosting:** GitHub Releases as the archival source of truth, and Cloudflare R2 behind one stable base URL as the delivery layer. CI publishes built packs to both on a tagged content release.
- **Packs** are downloaded on demand and usable fully offline. Nothing is preloaded. The app downloads per unit (not one big zip). A manifest lists versions and per-unit checksums, and the app verifies checksums after download.
- **Updates are atomic:** download to a temp location, verify, then swap. Fixes apply silently between lessons (never mid-lesson), new units are announced and downloaded on request, and a setting restricts updates to Wi-Fi or turns them off. Retired items keep their progress.

### Versioning

Packs are developed at a different cadence from the app, so they are versioned separately. Three axes:

- **Schema version** (`schema_version`): the file formats. The app declares which it can read and refuses others.
- **Pack version, per course** (`version`, semver): patch = fixes to existing content; minor = new units or phrases (concept keys and progress untouched); major = anything that can affect existing progress (retired concepts, restructured units), which the app can warn about before applying.
- **App compatibility** (`min_app_version`, per course, defaulting to the build's value): the app lists only courses it can run and shows "update the app" for the rest.

Downloads are still driven by file hashes, not version comparison, so a forgotten version bump cannot strand a fix. The version is for people and compatibility: "update available" labels, a changelog, support questions. The app records the installed version of each course. Each course is released independently as a git tag (for example `sr-tourist-1.4.2`). A planned build rule: refuse to publish changed content under an unchanged version.

## 9. Sideloading (designed for, no UI in v1)

The pack format already supports it:

- Self-contained single-file packs (zip) with manifest, text, audio, and checksums.
- Data only, never code. Import validates against the schema and enforces size limits.
- Namespaced pack IDs and a clear "unofficial" label, so a sideloaded pack cannot impersonate or overwrite an official one.
- **Full packs:** a whole new language, including languages without TTS support.
- **Overlay packs:** extra recordings or translations attached to an official pack's concept IDs.
- Schema version and minimum app version fields.

The import UI (file picker, "open with") is a later release.

## 10. Analytics and feedback

- Opt-in crash and pack-download-failure reports only, off by default, with no personal data and no usage tracking.
- An in-app "Report a problem with this phrase" button opens a prefilled GitHub issue (concept ID, language, exercise type).

## 11. Open items to settle before or during build

- Confirm the bundle ID against the other suite apps.
- Trademark search for the final store title and the mascot design.
- Written confirmation from ElevenLabs about redistributing outputs in an open repo.
- Content-repo and app license choices (code permissive, text content share-alike or similar).
- Which French UI strings reviewer is available (the owner).
- Pick the spaced-repetition algorithm (Leitner vs FSRS) and the on-device database package.
- ~~Audio codec~~ **Decided: AAC.** The official format is AAC-LC, mono, 44.1 kHz, about 32 kbps, in an `.m4a` container (`tools/encode_audio.py` produces it). Ogg Opus does not play in AVPlayer on iOS (Opus there needs iOS 17+ and an MP4 container, per Apple's forums; not verified on a device), and AAC plays on every iOS and Android version the app supports. The long-term goal is a fully open standard (Opus) once the iOS floor allows. That switch is a re-encode plus a rebuild, but only from the original masters: **keep the original ElevenLabs downloads and contributed recordings outside Git** (a backup bucket or drive; `--keep-masters`), never re-encode from AAC. Roughly 10 KB per 3-second clip.

## 12. Suggested build order

1. Content schema (JSON Schema) and a tiny sample pack (a few concepts, lemmas, Latin/Cyrillic text, placeholder audio).
2. Pack validator and build script in the content repo.
3. Flutter app skeleton: localization, pack download and storage, exercise engine against the sample pack.
4. Review web page and the LLM and ElevenLabs pipeline stages.
5. Gamification, Practice mode, reminders, and animations.
6. Full Serbian Tourist v1 content, native review, TestFlight.
