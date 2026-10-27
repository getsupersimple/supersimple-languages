import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:languages/app.dart';
import 'package:languages/audio/audio.dart';
import 'package:languages/audio/sounds.dart';
import 'package:languages/exercises/exercise.dart';
import 'package:languages/packs/models.dart';
import 'package:languages/packs/pack_source.dart';
import 'package:languages/packs/pack_store.dart';
import 'package:languages/settings/settings.dart';
import 'package:languages/ui/lesson_parts.dart';
import 'package:languages/ui/lesson_screen.dart';

import 'support.dart';

// Real file IO does not progress under fake async. Anything that starts IO
// (building the app, tapping a unit) runs inside runAsync and then gets real time.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> pumpApp(WidgetTester tester, AppServices services) async {
  await tester.runAsync(
    () => tester.pumpWidget(SupersimpleApp(services: services)),
  );
  await settle(tester);
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() => tester.tap(finder));
  await settle(tester);
}

Future<void> next(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 400));

void main() {
  late Directory tmp;
  late FakeAudioPlayer player;
  late AppServices services;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('app_test');
    player = FakeAudioPlayer();
    services = AppServices(
      source: DirectoryPackSource(Directory('test/fixtures/placeholder_pack')),
      store: PackStore(tmp),
      audio: player,
    );
  });

  tearDown(() async {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearLocalesTestValue();
    await tmp.delete(recursive: true);
  });

  group('home', () {
    Future<void> openSerbian(WidgetTester tester) =>
        tapAndSettle(tester, find.text('Srpski'));

    testWidgets('starts on the languages to learn, as flags', (tester) async {
      await pumpApp(tester, services);

      expect(find.text('Supersimple Languages'), findsOneWidget);
      expect(find.text('What do you want to learn?'), findsOneWidget);
      expect(find.text('🇷🇸'), findsOneWidget);
      expect(find.text('Srpski'), findsOneWidget);
      expect(find.textContaining('Your language: English'), findsOneWidget);
    });

    testWidgets('a language opens its course units', (tester) async {
      await pumpApp(tester, services);
      await openSerbian(tester);

      expect(find.text('Serbian for Tourists'), findsOneWidget);
      expect(find.text('Greetings and basics'), findsOneWidget);
      expect(find.textContaining('4 phrases'), findsOneWidget);
      expect(find.textContaining('Tap to download'), findsNWidgets(2));
    });

    testWidgets('the UI follows the system language', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      await pumpApp(tester, services);

      expect(find.text('Que voulez-vous apprendre ?'), findsOneWidget);
      expect(find.text('Apprendre'), findsOneWidget);
      await openSerbian(tester);
      expect(find.text('Unités'), findsOneWidget);
      expect(find.textContaining('Touchez pour télécharger'), findsNWidgets(2));
      // Course content follows the learner's source language, not the UI: the
      // test pack has no French text, so the title falls back to English.
      expect(find.text('Serbian for Tourists'), findsOneWidget);
    });

    testWidgets(
      'the settings tab shows the source language and saves a choice',
      (tester) async {
        await pumpApp(tester, services);
        await tapAndSettle(tester, find.text('Settings'));

        expect(find.text('I speak'), findsOneWidget);
        final menu = tester.widget<DropdownMenu<String>>(
          find.byType(DropdownMenu<String>),
        );
        expect(menu.initialSelection, 'en');
        expect(menu.dropdownMenuEntries.map((e) => e.value), ['en']);
        expect(services.settings.sourceLanguage, isNull);

        // Opening the menu lists every source language, with its flag.
        await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
        await tester.pumpAndSettle();
        expect(find.text('🇬🇧'), findsWidgets);
        expect(find.text('English'), findsWidgets);
      },
    );

    testWidgets('tapping a unit downloads it and opens its lesson', (
      tester,
    ) async {
      await pumpApp(tester, services);
      await openSerbian(tester);
      await tapAndSettle(tester, find.text('Food and getting around'));
      expect(find.text('New phrase'), findsOneWidget);
      expect(find.byType(LessonScreen), findsOneWidget);
      // The first card plays its phrase.
      expect(player.played, isNotEmpty);
      expect(player.played.first, endsWith('.m4a'));
    });
  });

  group('settings', () {
    test(
      'the source language is the choice, else the UI language, else English',
      () {
        expect(resolveSourceLanguage('fr', ['en', 'fr'], 'en'), 'fr');
        expect(resolveSourceLanguage(null, ['en', 'fr'], 'fr'), 'fr');
        expect(resolveSourceLanguage(null, ['en', 'fr'], 'de'), 'en');
        expect(resolveSourceLanguage('fr', ['en'], 'en'), 'en');
        expect(resolveSourceLanguage(null, ['sr'], 'de'), 'sr');
      },
    );

    test('a chosen source language survives a restart', () async {
      final file = File('${tmp.path}/settings.json');
      final settings = await AppSettings.load(file);
      expect(settings.sourceLanguage, isNull);
      await settings.setSourceLanguage('fr');
      expect((await AppSettings.load(file)).sourceLanguage, 'fr');
    });

    test('an unreadable settings file means defaults', () async {
      final file = File('${tmp.path}/settings.json')
        ..writeAsStringSync('not json');
      expect((await AppSettings.load(file)).sourceLanguage, isNull);
    });
  });

  group('lesson', () {
    late UnitContent greetings;
    late UnitContent food;
    late LessonAudio audio;
    late FakeSoundPlayer sounds;

    setUp(() async {
      greetings = await loadDevUnit(tmp, 'greetings-and-basics');
      food = await loadDevUnit(tmp, 'food-and-getting-around');
      audio = LessonAudio(player: player, pathFor: (r) => 'audio/${r.file}');
      sounds = FakeSoundPlayer();
    });

    Future<void> pumpLesson(
      WidgetTester tester,
      UnitContent content,
      LessonPlan plan, {
      Locale? locale,
    }) async {
      if (locale != null) tester.platformDispatcher.localesTestValue = [locale];
      await tester.pumpWidget(
        testApp(
          LessonScreen(
            content: content,
            audio: audio,
            sounds: sounds,
            plan: plan,
          ),
        ),
      );
      await tester.pump();
    }

    LessonPlan only(Exercise exercise) =>
        LessonPlan(intro: const [], exercises: [exercise]);

    T pick<T extends Exercise>(UnitContent unit, bool Function(T) test) =>
        generateLesson(
          unit,
          random: Random(1),
          maxExercises: 100,
        ).exercises.whereType<T>().firstWhere(test);

    testWidgets(
      'a whole generated lesson can be completed, covering every exercise type',
      (tester) async {
        final plan = generateLesson(
          greetings,
          random: Random(4),
          maxExercises: 10,
        );
        await pumpLesson(tester, greetings, plan);
        final seen = <String>{};

        for (final card in plan.intro) {
          expect(find.text('New phrase'), findsOneWidget);
          expect(
            tester.widget<Text>(find.byKey(const Key('prompt'))).data,
            card.target,
          );
          await tester.tap(find.text('Got it'));
          await next(tester);
        }

        for (final e in plan.exercises) {
          switch (e) {
            case ChoiceExercise():
              seen.add('choice:${e.kind.name}');
              await tester.tap(find.text(e.answer));
              await tester.pump();
              await tester.tap(find.text('Check'));
              await tester.pump();
            case BuildSentenceExercise():
              seen.add('build');
              for (final tile in e.answer) {
                final i = e.bank.indexWhere((t) => t.text == tile.text);
                await tester.tap(find.byKey(ValueKey('bank-$i')));
                await tester.pump();
              }
              await tester.tap(find.text('Check'));
              await tester.pump();
            case MatchPairsExercise():
              seen.add('match');
              for (final pair in e.pairs) {
                await tester.tap(find.text(pair.target));
                await tester.pump();
                await tester.tap(find.text(pair.gloss));
                await tester.pump();
              }
            case TypeExercise():
              seen.add('type');
              await tester.enterText(
                find.byType(TextField),
                e.answer.toLowerCase(),
              );
              await tester.pump();
              await tester.tap(find.text('Check'));
              await tester.pump();
          }
          expect(find.text('Correct!'), findsOneWidget, reason: 'after $e');
          await tester.tap(find.text('Continue'));
          await next(tester);
        }

        expect(find.text('Lesson complete!'), findsOneWidget);
        final n = plan.exercises.length;
        expect(find.text('You got $n of $n right.'), findsOneWidget);
        expect(seen.length, greaterThanOrEqualTo(5), reason: 'saw $seen');
        expect(player.played, isNotEmpty);
      },
    );

    testWidgets(
      'listen and choose plays the clip on its own and never shows the phrase',
      (tester) async {
        final e = pick<ChoiceExercise>(greetings, (c) => c.hidesPrompt);
        await pumpLesson(tester, greetings, only(e));

        expect(find.text('What do you hear?'), findsOneWidget);
        expect(find.byKey(const Key('prompt')), findsNothing);
        expect(
          find.text(e.prompt),
          findsNothing,
          reason: 'the target phrase must not be shown',
        );
        expect(player.played, hasLength(1));
        expect(
          player.played.single,
          contains(chooseRecording(e.audio, e.voiceId)!.file),
        );

        await tester.tap(find.byTooltip('Play audio'));
        expect(player.played, hasLength(2));
      },
    );

    testWidgets('a wrong choice is marked and the right answer is shown', (
      tester,
    ) async {
      final e = pick<ChoiceExercise>(
        greetings,
        (c) => c.kind == ExerciseKind.translateToTarget,
      );
      await pumpLesson(tester, greetings, only(e));
      final wrong = e.options.firstWhere((o) => !e.isCorrect(o));

      await tester.tap(find.text(wrong));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();

      expect(find.text('Not quite'), findsOneWidget);
      expect(find.text('Correct answer: ${e.answer}'), findsNothing);

      final before = player.played.length;
      await tester.tap(find.text('Show answer'));
      await tester.pump();
      expect(find.text('Correct answer: ${e.answer}'), findsOneWidget);
      expect(
        player.played.length,
        before + 1,
        reason: 'the target phrase is read aloud',
      );
      await tester.tap(find.text('Continue'));
      await next(tester);
      expect(find.text('You got 0 of 1 right.'), findsOneWidget);
    });

    testWidgets('after a wrong choice another option can be picked', (
      tester,
    ) async {
      final e = pick<ChoiceExercise>(
        greetings,
        (c) => c.kind == ExerciseKind.translateToTarget,
      );
      await pumpLesson(tester, greetings, only(e));
      final wrong = e.options.firstWhere((o) => !e.isCorrect(o));

      await tester.tap(find.text(wrong));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Not quite'), findsOneWidget);

      await tester.tap(find.text(e.answer));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Correct!'), findsOneWidget);
    });

    testWidgets(
      'choosing the meaning of a target phrase speaks the phrase only after a correct check',
      (tester) async {
        final e = pick<ChoiceExercise>(
          greetings,
          (c) => c.kind == ExerciseKind.translateFromTarget,
        );
        await pumpLesson(tester, greetings, only(e));
        expect(player.played, isEmpty, reason: 'nothing plays before checking');

        await tester.tap(
          find.text(e.options.firstWhere((o) => !e.isCorrect(o))),
        );
        await tester.pump();
        await tester.tap(find.text('Check'));
        await tester.pump();
        expect(
          player.played,
          isEmpty,
          reason: 'a wrong answer does not speak the phrase',
        );

        await tester.pumpWidget(const SizedBox());
        player.played.clear();
        await pumpLesson(tester, greetings, only(e));
        await tester.tap(find.text(e.answer));
        await tester.pump();
        expect(
          player.played,
          isEmpty,
          reason: 'selecting does not speak it either',
        );
        await tester.tap(find.text('Check'));
        await tester.pump();
        expect(
          player.played,
          isEmpty,
          reason: 'the phrase waits for the chime',
        );
        await tester.pump(chimeLead);
        expect(player.played, hasLength(1));
        expect(
          player.played.single,
          contains(chooseRecording(e.audio, e.voiceId)!.file),
        );
      },
    );

    testWidgets(
      'listen and choose speaks the phrase again after a correct check',
      (tester) async {
        final e = pick<ChoiceExercise>(greetings, (c) => c.hidesPrompt);
        await pumpLesson(tester, greetings, only(e));
        expect(
          player.played,
          hasLength(1),
          reason: 'plays on its own at the start',
        );

        await tester.tap(
          find.text(e.options.firstWhere((o) => !e.isCorrect(o))),
        );
        await tester.pump();
        await tester.tap(find.text('Check'));
        await tester.pump();
        expect(
          player.played,
          hasLength(1),
          reason: 'a wrong answer does not repeat it',
        );

        await tester.pumpWidget(const SizedBox());
        player.played.clear();
        await pumpLesson(tester, greetings, only(e));
        await tester.tap(find.text(e.answer));
        await tester.pump();
        await tester.tap(find.text('Check'));
        await tester.pump();
        expect(
          player.played,
          hasLength(1),
          reason: 'the repeat waits for the chime',
        );
        await tester.pump(chimeLead);
        expect(
          player.played,
          hasLength(2),
          reason: 'once at the start, once on the correct check',
        );
        expect(
          player.played.last,
          contains(chooseRecording(e.audio, e.voiceId)!.file),
        );
      },
    );

    testWidgets(
      'choosing the target phrase for an English prompt speaks it after a correct check',
      (tester) async {
        final e = pick<ChoiceExercise>(
          greetings,
          (c) => c.kind == ExerciseKind.translateToTarget,
        );
        await pumpLesson(tester, greetings, only(e));
        expect(player.played, isEmpty);

        await tester.tap(
          find.text(e.options.firstWhere((o) => !e.isCorrect(o))),
        );
        await tester.pump();
        await tester.tap(find.text('Check'));
        await tester.pump();
        expect(
          player.played,
          hasLength(1),
          reason: 'tapping an option reads it; checking a wrong one adds nothing',
        );

        await tester.pumpWidget(const SizedBox());
        player.played.clear();
        await pumpLesson(tester, greetings, only(e));
        await tester.tap(find.text(e.answer));
        await tester.pump();
        expect(player.played, hasLength(1), reason: 'tapping reads it');
        await tester.tap(find.text('Check'));
        await tester.pump();
        expect(
          player.played,
          hasLength(1),
          reason: 'the phrase waits for the chime',
        );
        await tester.pump(chimeLead);
        expect(player.played, hasLength(2));
        expect(
          player.played.last,
          contains(chooseRecording(e.optionAudio[e.answer]!, e.voiceId)!.file),
        );
      },
    );

    testWidgets(
      'the chime plays on a correct check and never on a wrong one, for every exercise type',
      (tester) async {
        Future<void> check() async {
          await tester.tap(find.text('Check'));
          await tester.pump();
        }

        Future<void> restart(Exercise e) async {
          await tester.pumpWidget(const SizedBox());
          sounds.played.clear();
          await pumpLesson(tester, greetings, only(e));
        }

        // Multiple choice, English or Serbian options.
        for (final kind in ExerciseKind.values) {
          final e = pick<ChoiceExercise>(greetings, (c) => c.kind == kind);
          await restart(e);
          await tester.tap(
            find.text(e.options.firstWhere((o) => !e.isCorrect(o))),
          );
          await tester.pump();
          await check();
          expect(sounds.played, isEmpty, reason: '$kind wrong');

          await restart(e);
          await tester.tap(find.text(e.answer));
          await tester.pump();
          expect(sounds.played, isEmpty, reason: '$kind selecting is silent');
          await check();
          expect(sounds.played, [Sound.correct], reason: '$kind correct');
        }

        // Build the sentence.
        final build = pick<BuildSentenceExercise>(
          greetings,
          (b) => b.answer.length == 3,
        );
        await restart(build);
        await tester.tap(find.byKey(const ValueKey('bank-0')));
        await tester.pump();
        await check();
        expect(sounds.played, isEmpty, reason: 'build wrong');
        await restart(build);
        for (final tile in build.answer) {
          await tester.tap(
            find.byKey(
              ValueKey(
                'bank-${build.bank.indexWhere((t) => t.text == tile.text)}',
              ),
            ),
          );
          await tester.pump();
        }
        await check();
        expect(sounds.played, [Sound.correct], reason: 'build correct');

        // Type what you hear.
        final type = pick<TypeExercise>(greetings, (_) => true);
        await restart(type);
        await tester.enterText(find.byType(TextField), 'completely wrong');
        await tester.pump();
        await check();
        expect(sounds.played, isEmpty, reason: 'type wrong');
        await restart(type);
        await tester.enterText(find.byType(TextField), type.answer);
        await tester.pump();
        await check();
        expect(sounds.played, [Sound.correct], reason: 'type correct');

        // Match pairs: the chime comes when every pair is matched without a mistake.
        final match = pick<MatchPairsExercise>(greetings, (_) => true);
        await restart(match);
        for (final pair in match.pairs) {
          await tester.tap(find.text(pair.target));
          await tester.pump();
          expect(
            sounds.played,
            isEmpty,
            reason: 'match: not before the last pair',
          );
          await tester.tap(find.text(pair.gloss));
          await tester.pump();
        }
        expect(sounds.played, [Sound.correct], reason: 'match correct');
      },
    );

    testWidgets('continuing before the delay ends cancels the pending phrase', (
      tester,
    ) async {
      final e = pick<ChoiceExercise>(
        greetings,
        (c) => c.kind == ExerciseKind.translateFromTarget,
      );
      await pumpLesson(tester, greetings, only(e));
      await tester.tap(find.text(e.answer));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await next(tester);
      await tester.pump(chimeLead * 2);
      expect(player.played, isEmpty);
    });

    testWidgets('the ring plays once when the unit is finished, not before', (
      tester,
    ) async {
      final e = pick<ChoiceExercise>(
        greetings,
        (c) => c.kind == ExerciseKind.translateFromTarget,
      );
      await pumpLesson(tester, greetings, only(e));
      await tester.tap(find.text(e.answer));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(sounds.played, [
        Sound.correct,
      ], reason: 'no ring before continuing');

      await tester.tap(find.text('Continue'));
      await next(tester);
      expect(find.text('Lesson complete!'), findsOneWidget);
      expect(sounds.played, [Sound.correct, Sound.unitComplete]);
    });

    testWidgets(
      'every tile press in the build exercise speaks the word as written, placing or removing',
      (tester) async {
        final e = pick<BuildSentenceExercise>(
          food,
          (b) => b.answer.length == 3,
        );
        await pumpLesson(tester, food, only(e));
        player.played.clear();

        final index = e.bank.indexWhere((t) => t.text == e.answer.first.text);
        final spoken = chooseRecording(e.bank[index].audio, e.voiceId)!.file;
        await tester.tap(find.byKey(ValueKey('bank-$index')));
        await tester.pump();
        expect(player.played, hasLength(1), reason: 'placing a tile speaks it');
        expect(player.played.last, contains(spoken));

        await tester.tap(find.byKey(ValueKey('answer-$index')));
        await tester.pump();
        expect(
          player.played,
          hasLength(2),
          reason: 'taking it back speaks it again',
        );
        expect(player.played.last, contains(spoken));
      },
    );

    testWidgets(
      'a word speaks its own form, not the dictionary form ("sam", not "biti")',
      (tester) async {
        final tired = greetings.pack.phrases.firstWhere(
          (p) => p.concept == 'i-am-tired',
        );
        final sam = tired.tokens.firstWhere(
          (t) => t.surface['Latn']!.toLowerCase() == 'sam',
        );
        final biti = greetings.pack.lemmas[sam.lemma]!;
        expect(biti.audioFor(sam.surface).first.file, contains('biti-sam'));
        expect(
          biti.audioFor(biti.text).first.file,
          isNot(contains('biti-sam')),
          reason: 'the lemma keeps its own clip',
        );
        expect(
          biti.audioFor(biti.text).first.file,
          contains('biti-placeholder'),
        );
      },
    );

    testWidgets('holding a tile shows its explanation until release', (
      tester,
    ) async {
      final e = pick<BuildSentenceExercise>(food, (b) => b.answer.length == 3);
      await pumpLesson(tester, food, only(e));
      final tile = find.byKey(
        ValueKey(
          'bank-${e.bank.indexWhere((t) => t.text == e.answer.first.text)}',
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(tile));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LemmaDetails), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(LemmaDetails), findsNothing);
    });

    testWidgets('dragging a placed tile reorders it, growing while held', (
      tester,
    ) async {
      final e = pick<BuildSentenceExercise>(food, (b) => b.answer.length == 3);
      await pumpLesson(tester, food, only(e));
      final idx = [
        for (final t in e.answer) e.bank.indexWhere((x) => x.text == t.text),
      ];
      for (final i in idx) {
        await tester.tap(find.byKey(ValueKey('bank-$i')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      double left(int i) =>
          tester.getTopLeft(find.byKey(ValueKey('answer-$i'))).dx;
      expect(left(idx[0]), lessThan(left(idx[2])));

      final first = find.byKey(ValueKey('answer-${idx[0]}'));
      double shownWidth() =>
          tester.getBottomRight(first).dx - tester.getTopLeft(first).dx;
      final restWidth = shownWidth();
      final gesture = await tester.startGesture(tester.getCenter(first));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(shownWidth(), greaterThan(restWidth), reason: 'held tile grows');
      await gesture.moveTo(
        tester.getCenter(find.byKey(ValueKey('answer-${idx[2]}'))) +
            const Offset(40, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        left(idx[0]),
        greaterThan(left(idx[2])),
        reason: 'dragged tile now sits after the last one',
      );
      expect(shownWidth(), closeTo(restWidth, 0.5));
    });

    testWidgets(
      'building in the wrong order is wrong; tiles can be removed again',
      (tester) async {
        final e = pick<BuildSentenceExercise>(
          food,
          (b) => b.answer.length == 3,
        );
        await pumpLesson(tester, food, only(e));

        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Check'))
              .onPressed,
          isNull,
        );

        final order = e.answer.reversed.toList();
        for (final tile in order) {
          await tester.tap(
            find.byKey(
              ValueKey('bank-${e.bank.indexWhere((t) => t.text == tile.text)}'),
            ),
          );
          await tester.pumpAndSettle();
        }
        // Take the first placed tile back, then put it in again at the end: still the wrong order.
        final first = e.bank.indexWhere((t) => t.text == order.first.text);
        await tester.tap(find.byKey(ValueKey('answer-$first')));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('bank-$first')), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('bank-$first')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Check'));
        await tester.pumpAndSettle();
        expect(find.text('Not quite'), findsOneWidget);
        expect(find.text('Correct answer: ${e.answerText}'), findsNothing);

        // Try again: the tiles can be changed and checked once more.
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('Check'), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('answer-$first')));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('bank-$first')), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('bank-$first')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Check'));
        await tester.pumpAndSettle();

        // Or give up and see the answer.
        await tester.tap(find.text('Show answer'));
        await tester.pumpAndSettle();
        expect(find.text('Correct answer: ${e.answerText}'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
      },
    );

    testWidgets(
      'match pairs shows a wrong match in red without failing the exercise',
      (tester) async {
        final e = pick<MatchPairsExercise>(greetings, (_) => true);
        await pumpLesson(tester, greetings, only(e));

        final a = e.pairs[0], b = e.pairs[1];
        await tester.tap(find.text(a.target));
        await tester.pump();
        expect(
          player.played,
          isNotEmpty,
          reason: 'tapping a word plays its lemma clip',
        );
        await tester.tap(find.text(b.gloss));
        await tester.pump();
        for (final pair in e.pairs) {
          await tester.tap(find.text(pair.target));
          await tester.pump();
          await tester.tap(find.text(pair.gloss));
          await tester.pump();
        }
        expect(find.text('Correct!'), findsOneWidget);
        expect(find.text('Not quite'), findsNothing);
        await tester.tap(find.text('Continue'));
        await next(tester);
        expect(find.text('You got 1 of 1 right.'), findsOneWidget);
      },
    );

    testWidgets('typing a wrong phrase shows the answer', (tester) async {
      final e = pick<TypeExercise>(greetings, (_) => true);
      await pumpLesson(tester, greetings, only(e));
      expect(player.played, hasLength(1), reason: 'plays on its own');

      await tester.enterText(find.byType(TextField), 'completely wrong');
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Not quite'), findsOneWidget);
      expect(find.text('Correct answer: ${e.answer}'), findsNothing);

      await tester.tap(find.text('Show answer'));
      await tester.pump();
      expect(find.text('Correct answer: ${e.answer}'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('a nearly right phrase says Close! and can be retried', (
      tester,
    ) async {
      final e = pick<TypeExercise>(greetings, (_) => true);
      await pumpLesson(tester, greetings, only(e));

      await tester.enterText(find.byType(TextField), '${e.answer}x');
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Close!'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), e.answer);
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Correct!'), findsOneWidget);
    });

    testWidgets(
      'tapping a word opens the lemma sheet and plays the lemma, not the form',
      (tester) async {
        final coffee = food.pack.phrases.firstWhere(
          (p) => p.concept == 'one-coffee-please',
        );
        final card = IntroCard(
          target: 'Jednu kafu, molim',
          source: 'One coffee, please',
          tiles: [
            for (final t in coffee.tokens)
              Tile(
                text: t.surface['Latn']!,
                lemma: t.lemma,
                grammar: t.grammar,
                audio: food.pack.lemmas[t.lemma]!.audioFor(t.surface),
              ),
          ],
          audio: coffee.audio,
          voiceId: 'placeholder-f',
        );
        await pumpLesson(
          tester,
          food,
          LessonPlan(
            intro: [card],
            exercises: [generateLesson(food).exercises.first],
          ),
        );
        player.played.clear();

        await tester.tap(find.widgetWithText(ActionChip, 'kafu'));
        await tester.pumpAndSettle();
        expect(
          player.played,
          hasLength(1),
          reason: 'pressing the tile speaks the word as written',
        );
        expect(player.played.single, contains('kafa-kafu-placeholder-f'));
        player.played.clear();

        expect(
          find.text('kafa'),
          findsOneWidget,
          reason: 'the dictionary form',
        );
        expect(find.text('coffee'), findsOneWidget);
        expect(find.text('"kafu" is a form of "kafa"'), findsOneWidget);
        expect(
          find.text('noun · accusative · singular · feminine'),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Play audio').last);
        expect(player.played, hasLength(1));
        expect(player.played.single, contains('kafa-placeholder-f'));

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('coffee'), findsNothing);
      },
    );

    testWidgets('the lemma sheet is localized', (tester) async {
      final tired = greetings.pack.phrases.firstWhere(
        (p) => p.concept == 'i-am-tired' && p.variant == 'f',
      );
      final card = IntroCard(
        target: 'Umorna sam',
        source: "I'm tired",
        tiles: [
          for (final t in tired.tokens)
            Tile(text: t.surface['Latn']!, lemma: t.lemma, grammar: t.grammar),
        ],
        audio: tired.audio,
      );
      await pumpLesson(
        tester,
        greetings,
        LessonPlan(
          intro: [card],
          exercises: [generateLesson(greetings).exercises.first],
        ),
        locale: const Locale('fr'),
      );
      expect(find.text('Nouvelle phrase'), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, 'Umorna'));
      await tester.pumpAndSettle();
      expect(
        find.text('adjectif · nominatif · singulier · féminin'),
        findsOneWidget,
      );
      expect(
        find.text('« Umorna » est une forme de « umoran »'),
        findsOneWidget,
      );
    });

    testWidgets('leaving a lesson stops the audio', (tester) async {
      await pumpLesson(
        tester,
        greetings,
        generateLesson(greetings, random: Random(1)),
      );
      await tester.pumpWidget(testApp(const SizedBox()));
      expect(player.stops, greaterThan(0));
    });
  });
}
