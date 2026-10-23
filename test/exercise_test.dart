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

  group('gendered phrases are only voiced by a voice of that gender', () {
    const gender = {'placeholder-m': 'male', 'placeholder-f': 'female'};

    // "Umoran sam" is the male speaker's phrase, "Umorna sam" the female speaker's.
    String? speakerOf(String text) => switch (text) {
          'Umoran sam' => 'male',
          'Umorna sam' => 'female',
          _ => null,
        };

    void expectSpeaker(String speaker, List<Recording> audio, String? voiceId, String where) {
      expect(audio, isNotEmpty, reason: where);
      expect(audio.map((r) => r.gender).toSet(), {speaker}, reason: '$where: recordings');
      expect(gender[voiceId], speaker, reason: '$where: voice');
      expect(chooseRecording(audio, voiceId)!.gender, speaker, reason: '$where: played');
    }

    test('the fixture voices both genders for every phrase, so the rule is what filters', () {
      for (final p in greetings.pack.phrases.where((p) => p.variant != null)) {
        expect(p.audio.map((r) => r.gender).toSet(), {'male', 'female'}, reason: '${p.concept}.${p.variant}');
      }
    });

    test('listen, type, build, intro and the translated-from-Serbian choices', () {
      var checked = 0;
      for (var seed = 0; seed < 40; seed++) {
        final lesson = plan(seed, max: 100);
        for (final card in lesson.intro) {
          final speaker = speakerOf(card.target);
          if (speaker == null) continue;
          expectSpeaker(speaker, card.audio, card.voiceId, 'intro ${card.target}');
          for (final tile in card.tiles) {
            expect(chooseRecording(tile.audio, card.voiceId)!.gender, speaker, reason: 'intro tile ${tile.text}');
          }
          checked++;
        }
        for (final e in lesson.exercises) {
          switch (e) {
            case TypeExercise():
              final speaker = speakerOf(e.answer);
              if (speaker == null) continue;
              expectSpeaker(speaker, e.audio, e.voiceId, 'type ${e.answer}');
              checked++;
            case BuildSentenceExercise():
              final speaker = speakerOf(e.answerText);
              if (speaker == null) continue;
              expectSpeaker(speaker, e.audio, e.voiceId, 'build ${e.answerText}');
              for (final tile in e.bank) {
                expect(chooseRecording(tile.audio, e.voiceId)!.gender, speaker, reason: 'tile ${tile.text}');
              }
              checked++;
            case ChoiceExercise() when e.kind != ExerciseKind.translateToTarget:
              final speaker = speakerOf(e.prompt) ?? (e.hidesPrompt ? speakerOf(e.answer) : null);
              if (e.kind == ExerciseKind.translateFromTarget && speaker != null) {
                expectSpeaker(speaker, e.audio, e.voiceId, 'choice ${e.prompt}');
                checked++;
              }
            case ChoiceExercise():
              // English prompt, Serbian options: each option is heard in its own speaker's voice.
              for (final option in e.options) {
                final speaker = speakerOf(option);
                if (speaker == null) continue;
                expect(e.optionAudio[option]!.map((r) => r.gender).toSet(), {speaker}, reason: 'option $option');
                checked++;
              }
            case MatchPairsExercise():
              break;
          }
        }
      }
      expect(checked, greaterThan(10), reason: 'the gendered phrases were actually exercised');
    });

    test('other phrases still get both voices at random', () {
      final voices = <String?>{};
      for (var seed = 0; seed < 40; seed++) {
        for (final e in plan(seed).exercises.whereType<TypeExercise>().where((e) => speakerOf(e.answer) == null)) {
          voices.add(e.voiceId);
        }
      }
      expect(voices, {'placeholder-f', 'placeholder-m'});
    });
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

    test('lets an English keyboard type French letters and hyphens', () {
      expect(normalizeAnswer('Où sont les toilettes ?'), normalizeAnswer('ou sont les toilettes'));
      expect(normalizeAnswer('Parlez-vous anglais ?'), normalizeAnswer('parlez vous anglais'));
      expect(normalizeAnswer('Je suis fatiguée'), normalizeAnswer('je suis fatiguee'));
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
