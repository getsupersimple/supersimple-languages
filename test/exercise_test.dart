import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:languages/audio/audio.dart';
import 'package:languages/exercises/exercise.dart';
import 'package:languages/packs/models.dart';

import 'support.dart';

TargetPhrase _silent(TargetPhrase p) =>
    TargetPhrase(concept: p.concept, variant: p.variant, text: p.text, tokens: p.tokens, audio: const []);

void main() {
  late Directory tmp;
  late UnitContent greetings;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('exercise_test');
    greetings = await loadDevUnit(tmp, 'greetings-and-basics');
  });

  tearDown(() => tmp.delete(recursive: true));

  LessonPlan plan(int seed, {int max = 100, String script = 'Latn', UnitContent? unit}) =>
      generateLesson(unit ?? greetings, random: Random(seed), maxExercises: max, script: script);

  group('every exercise can be answered', () {
    test('choice', () {
      for (var seed = 0; seed < 20; seed++) {
        for (final e in plan(seed).exercises.whereType<ChoiceExercise>()) {
          expect(e.options.length, inInclusiveRange(2, 4));
          expect(e.options.toSet().length, e.options.length, reason: 'options are distinct');
          expect(e.options, contains(e.answer));
          expect(e.options.where(e.isCorrect), hasLength(1), reason: '${e.prompt} -> ${e.options}');
        }
      }
    });

    test('build the sentence', () {
      for (var seed = 0; seed < 20; seed++) {
        for (final e in plan(seed).exercises.whereType<BuildSentenceExercise>()) {
          expect(e.isCorrect(e.answer), isTrue);
          expect(e.answer.length, greaterThanOrEqualTo(2));
          final texts = e.bank.map((t) => t.text).toList();
          expect(texts.toSet().length, texts.length, reason: 'bank tiles are distinct');
          for (final t in e.answer) {
            expect(texts, contains(t.text));
          }
          expect(e.bank.length, greaterThan(e.answer.length), reason: 'has distractors');
        }
      }
    });

    test('match pairs', () {
      final matches = plan(1).exercises.whereType<MatchPairsExercise>().toList();
      expect(matches, hasLength(1));
      final m = matches.single;
      expect(m.pairs.length, inInclusiveRange(3, 5));
      expect(m.shuffledGlosses.toSet(), m.pairs.map((p) => p.gloss).toSet());
      expect(m.pairs.map((p) => p.lemma).toSet().length, m.pairs.length);
    });

    test('type what you hear', () {
      final types = plan(1).exercises.whereType<TypeExercise>().toList();
      expect(types, hasLength(1));
      expect(types.single.audio, isNotEmpty);
      expect(types.single.isCorrect(types.single.answer), isTrue);
    });
  });

  test('a big lesson mixes all exercise types', () {
    final kinds = {
      for (final e in plan(2).exercises)
        describeKind(e),
    };
    expect(kinds, {
      'choice:listenAndChoose',
      'choice:translateFromTarget',
      'choice:translateToTarget',
      'build',
      'match',
      'type',
    });
  });

  test('a capped lesson still mixes types (round-robin, not one type first)', () {
    final lesson = plan(3, max: 6);
    expect(lesson.exercises, hasLength(6));
    expect(lesson.exercises.map(describeKind).toSet().length, greaterThanOrEqualTo(5));
  });

  test('introduction cards cover the unit\'s phrases', () {
    final lesson = plan(1);
    expect(lesson.intro, hasLength(5)); // 3 phrases + masculine and feminine "I'm tired"
    expect(lesson.intro.first.tiles, isNotEmpty);
    expect(lesson.intro.every((c) => c.audio.isNotEmpty), isTrue);
    expect(lesson.steps, lesson.intro.length + lesson.exercises.length);
    expect(generateLesson(greetings, random: Random(1), maxIntro: 2).intro, hasLength(2));
  });

  test('the masculine and feminine "I\'m tired" are one question that accepts both', () {
    final lesson = plan(3);
    final choice = lesson.exercises.whereType<ChoiceExercise>().where((e) => e.prompt == "I'm tired").toList();
    expect(choice, hasLength(1));
    expect(choice.single.accepted, {'Umoran sam', 'Umorna sam'});

    final build = lesson.exercises.whereType<BuildSentenceExercise>().where((e) => e.prompt == "I'm tired").toList();
    for (final e in build) {
      expect(e.accepted, {'Umoran sam', 'Umorna sam'});
    }
  });

  test('voices: one per exercise, varied across the lesson, and the chosen one is played', () {
    final voices = <String?>{};
    for (var seed = 0; seed < 10; seed++) {
      for (final e in plan(seed).exercises.whereType<ChoiceExercise>().where((e) => e.hidesPrompt)) {
        expect(e.voiceId, anyOf('placeholder-f', 'placeholder-m'));
        voices.add(e.voiceId);
        final recording = chooseRecording(e.audio, e.voiceId)!;
        expect(recording.voiceId, e.voiceId);
      }
    }
    expect(voices, {'placeholder-f', 'placeholder-m'});
  });

  test('chooseRecording falls back to the first recording', () {
    final recordings = greetings.pack.phrases.first.audio;
    expect(chooseRecording(recordings, 'nobody'), same(recordings.first));
    expect(chooseRecording(recordings, null), same(recordings.first));
    expect(chooseRecording(const [], 'x'), isNull);
  });

  test('without audio there are no listen or type exercises', () {
    final silent = UnitContent(
      pack: UnitPack(
        course: greetings.pack.course,
        unitId: greetings.pack.unitId,
        targetLanguage: greetings.pack.targetLanguage,
        phrases: greetings.pack.phrases.map(_silent).toList(),
        lemmas: greetings.pack.lemmas,
      ),
      text: greetings.text,
    );
    final kinds = plan(1, unit: silent).exercises.map(describeKind).toSet();
    expect(kinds, isNot(contains('choice:listenAndChoose')));
    expect(kinds, isNot(contains('type')));
    expect(kinds, contains('build'));
  });

  test('the script setting switches the displayed script', () {
    final cyrillic = RegExp(r'^[Ѐ-ӿ ,?!]+$');
    final lesson = plan(2, script: 'Cyrl');
    for (final e in lesson.exercises) {
      switch (e) {
        case ChoiceExercise(kind: ExerciseKind.translateToTarget):
          expect(e.answer, matches(cyrillic));
        case BuildSentenceExercise():
          expect(e.answerText, matches(cyrillic));
        case TypeExercise():
          expect(e.answer, matches(cyrillic));
        case MatchPairsExercise():
          expect(e.pairs.map((p) => p.target), everyElement(matches(cyrillic)));
        default:
      }
    }
  });

  test('the same seed gives the same lesson', () {
    String describe(LessonPlan l) => [
          ...l.intro.map((c) => c.target),
          ...l.exercises.map((e) => switch (e) {
                ChoiceExercise c => '${c.prompt}:${c.options.join(",")}:${c.voiceId}',
                BuildSentenceExercise b => '${b.prompt}:${b.bank.map((t) => t.text).join(",")}',
                MatchPairsExercise m => m.shuffledGlosses.join(','),
                TypeExercise t => '${t.answer}:${t.voiceId}',
              }),
        ].join('|');
    expect(describe(plan(7)), describe(plan(7)));
    expect(describe(plan(7)), isNot(describe(plan(8))));
  });

  group('normalizeAnswer', () {
    test('ignores case, punctuation and spacing', () {
      expect(normalizeAnswer('  Gde  je toalet? '), normalizeAnswer('gde je toalet'));
      expect(normalizeAnswer('Jednu kafu, molim'), 'jednu kafu molim');
    });

    test('lets an English keyboard type Serbian letters', () {
      expect(normalizeAnswer('Dobro veče'), normalizeAnswer('dobro vece'));
      expect(normalizeAnswer('Ćao, šta ima'), normalizeAnswer('cao sta ima'));
      expect(normalizeAnswer('Đurđevdan'), normalizeAnswer('djurdjevdan'));
    });

    test('keeps Cyrillic letters', () {
      expect(normalizeAnswer('Добар дан!'), 'добар дан');
    });

    test('still tells different phrases apart', () {
      expect(normalizeAnswer('Umoran sam'), isNot(normalizeAnswer('Umorna sam')));
    });
  });
}

String describeKind(Exercise e) => switch (e) {
      ChoiceExercise c => 'choice:${c.kind.name}',
      BuildSentenceExercise _ => 'build',
      MatchPairsExercise _ => 'match',
      TypeExercise _ => 'type',
    };
