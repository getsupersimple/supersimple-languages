import 'dart:math';

import '../packs/models.dart';

/// Exercises are never stored in packs: the engine builds them from pack data,
/// so a new language costs data only.
sealed class Exercise {
  const Exercise();
}

enum ExerciseKind {
  /// Read the target language, pick the meaning in the learner's language.
  translateFromTarget,

  /// Read the learner's language, pick the target-language phrase.
  translateToTarget,

  /// Hear the target language, pick the meaning.
  listenAndChoose,
}

/// Multiple choice.
class ChoiceExercise extends Exercise {
  const ChoiceExercise({
    required this.kind,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.accepted,
    this.audio = const [],
    this.optionAudio = const {},
    this.voiceId,
  });

  final ExerciseKind kind;

  /// The text asked about. For [ExerciseKind.listenAndChoose] it is the target
  /// phrase, kept for identity only and not shown (the learner has to hear it).
  final String prompt;
  final List<String> options;

  /// The answer shown when the learner is wrong.
  final String answer;

  /// Every option that counts as right. Two phrases can share one translation
  /// (for example the masculine and feminine "I'm tired").
  final Set<String> accepted;

  final List<Recording> audio;

  /// For [ExerciseKind.translateToTarget]: the recordings of each target-phrase option.
  final Map<String, List<Recording>> optionAudio;
  final String? voiceId;

  bool get hidesPrompt => kind == ExerciseKind.listenAndChoose;

  bool isCorrect(String choice) => accepted.contains(choice);
}

/// One word tile: the form as written in the phrase, linked to its lemma.
class Tile {
  const Tile({
    required this.text,
    required this.lemma,
    required this.grammar,
    this.audio = const [],
  });

  final String text;
  final String lemma;
  final Map<String, dynamic> grammar;

  /// How the word sounds as written in the phrase (the form's recording, not the lemma's).
  final List<Recording> audio;
}

/// Build the target phrase from word tiles.
class BuildSentenceExercise extends Exercise {
  const BuildSentenceExercise({
    required this.prompt,
    required this.answer,
    required this.bank,
    required this.accepted,
    this.audio = const [],
    this.voiceId,
  });

  /// The phrase in the learner's language.
  final String prompt;

  /// The expected tiles, in order.
  final List<Tile> answer;

  /// Shuffled tiles to choose from: the answer's tiles plus a few distractors.
  final List<Tile> bank;

  /// Every accepted sentence, as space-joined tile text.
  final Set<String> accepted;

  final List<Recording> audio;
  final String? voiceId;

  String get answerText => answer.map((t) => t.text).join(' ');

  bool isCorrect(List<Tile> built) =>
      accepted.contains(built.map((t) => t.text).join(' '));
}

class MatchPair {
  const MatchPair({
    required this.lemma,
    required this.target,
    required this.gloss,
    required this.audio,
  });

  final String lemma;
  final String target;
  final String gloss;
  final List<Recording> audio;
}

/// Match target-language words to their meanings. Works on lemmas.
class MatchPairsExercise extends Exercise {
  const MatchPairsExercise({
    required this.pairs,
    required this.shuffledGlosses,
    this.voiceId,
  });

  final List<MatchPair> pairs;

  /// The meanings in the order shown on the right-hand side.
  final List<String> shuffledGlosses;
  final String? voiceId;
}

/// Type the target phrase after hearing it.
class TypeExercise extends Exercise {
  const TypeExercise({
    required this.answer,
    required this.audio,
    this.voiceId,
    this.display,
  });

  /// What the learner types. Japanese is typed as romaji.
  final String answer;

  /// The answer as shown when wrong, if it differs from [answer] (kanji and kana).
  final String? display;
  String get shown => display ?? answer;
  final List<Recording> audio;
  final String? voiceId;

  bool isCorrect(String typed) =>
      normalizeAnswer(typed) == normalizeAnswer(answer);

  /// A wrong answer within a typo or two of the right one.
  bool isClose(String typed) {
    final a = normalizeAnswer(typed);
    final b = normalizeAnswer(answer);
    return a != b && editDistance(a, b) <= max(1, b.length ~/ 5);
  }
}

/// Levenshtein distance between [a] and [b].
int editDistance(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List<int>.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      cur[j] = min(
        min(prev[j] + 1, cur[j - 1] + 1),
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Shows a phrase before it is tested. Not scored.
class IntroCard {
  const IntroCard({
    required this.target,
    required this.source,
    required this.tiles,
    required this.audio,
    this.voiceId,
    this.concept = '',
  });

  final String target;
  final String source;
  final List<Tile> tiles;

  /// The phrase's concept id, which tells what it means whatever the language.
  final String concept;
  final List<Recording> audio;
  final String? voiceId;
}

class LessonPlan {
  const LessonPlan({required this.intro, required this.exercises});

  /// Phrases shown first, unscored.
  final List<IntroCard> intro;
  final List<Exercise> exercises;

  int get steps => intro.length + exercises.length;
}

const _folds = {
  'č': 'c',
  'ć': 'c',
  'š': 's',
  'ž': 'z',
  'đ': 'dj',
  'à': 'a',
  'â': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'ô': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'œ': 'oe',
  'ā': 'a',
  'ī': 'i',
  'ū': 'u',
  'ē': 'e',
  'ō': 'o',
};

/// Typing check: case, punctuation, spacing and accents are ignored, so a
/// learner on an English keyboard can type "Gde je toalet" or "umoran sam".
/// A hyphen separates words ("Parlez-vous" is typed "parlez vous").
String normalizeAnswer(String text) {
  final folded = text
      .toLowerCase()
      .replaceAll('-', ' ')
      .split('')
      .map((c) => _folds[c] ?? c)
      .join();
  return folded
      .replaceAll(_punctuation, '')
      .trim()
      .split(_whitespace)
      .join(' ');
}

final _punctuation = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
final _whitespace = RegExp(r'\s+');

/// Concept variants that name the speaker's gender, and the voice gender they need.
const _variantSpeaker = {'m': 'male', 'f': 'female'};

/// The recordings a phrase may be heard in. A phrase for a gendered speaker
/// ("Umoran sam" / "Umorna sam") is only ever voiced by a voice of that gender.
List<Recording> _spokenAudio(TargetPhrase phrase) {
  final speaker = _variantSpeaker[phrase.variant];
  if (speaker == null) return phrase.audio;
  return [
    for (final r in phrase.audio)
      if (r.gender == speaker) r,
  ];
}

class _Pair {
  _Pair(this.phrase, this.target, this.source) : audio = _spokenAudio(phrase);

  final TargetPhrase phrase;
  final String target;
  final String source;

  /// [phrase] audio limited to the voices allowed for its speaker.
  final List<Recording> audio;
}

/// Builds a lesson from one unit.
///
/// [script] picks the script shown for each text (Latin by default). Pass a
/// seeded [random] for repeatable output in tests. Voices are picked here, once
/// per exercise, so a lesson mixes speakers without changing voice mid-question.
/// Every phrase of the unit is introduced unless [maxIntro] caps it.
/// Set [allowTyping] false to leave out the type-what-you-hear exercise
/// (tourist courses, whose learners are not ready to write).
LessonPlan generateLesson(
  UnitContent unit, {
  String script = 'Latn',
  Random? random,
  int optionCount = 4,
  int maxExercises = 10,
  int? maxIntro,
  bool allowTyping = true,
}) {
  final rng = random ?? Random();
  final pairs = <_Pair>[];
  for (final phrase in unit.pack.phrases) {
    final source = unit.sourceTextFor(phrase);
    if (source == null) continue;
    pairs.add(
      _Pair(
        phrase,
        pickScript(phrase.text, script),
        pickScript(source, script),
      ),
    );
  }

  final voices = ({
    for (final p in unit.pack.phrases)
      for (final r in p.audio) r.voiceId,
    for (final l in unit.pack.lemmas.values)
      for (final r in l.audio) r.voiceId,
  }).toList()..sort();
  String? pickVoice() =>
      voices.isEmpty ? null : voices[rng.nextInt(voices.length)];

  /// A random voice for the pair's phrase; for a gendered phrase, one of that gender.
  /// Tiles and the phrase share it, so the whole question has one speaker.
  String? voiceFor(_Pair pair) {
    if (pair.audio.isEmpty) return null;
    if (!_variantSpeaker.containsKey(pair.phrase.variant)) return pickVoice();
    final allowed = ({for (final r in pair.audio) r.voiceId}).toList()..sort();
    return allowed[rng.nextInt(allowed.length)];
  }

  Tile tileOf(Token t) => Tile(
    text: pickScript(t.surface, script),
    lemma: t.lemma,
    grammar: t.grammar,
    audio: unit.pack.lemmas[t.lemma]?.audioFor(t.surface) ?? const [],
  );
  final tiles = {
    for (final p in pairs) p: p.phrase.tokens.map(tileOf).toList(),
  };

  // --- multiple choice ---------------------------------------------------
  ChoiceExercise? choice(ExerciseKind kind, _Pair pair) {
    if (kind == ExerciseKind.listenAndChoose && pair.audio.isEmpty) return null;
    final answerIsSource = kind != ExerciseKind.translateToTarget;
    String prompt(_Pair p) => answerIsSource ? p.target : p.source;
    String answer(_Pair p) => answerIsSource ? p.source : p.target;

    final accepted = {
      for (final p in pairs)
        if (prompt(p) == prompt(pair)) answer(p),
    };
    final distractors = ({
      for (final p in pairs)
        if (!accepted.contains(answer(p))) answer(p),
    }).toList()..shuffle(rng);
    if (distractors.isEmpty) return null;

    final options = [answer(pair), ...distractors.take(optionCount - 1)]
      ..shuffle(rng);
    final optionAudio = kind == ExerciseKind.translateToTarget
        ? {
            for (final p in pairs)
              if (options.contains(p.target)) p.target: p.audio,
          }
        : const <String, List<Recording>>{};
    final heard = kind == ExerciseKind.translateToTarget
        ? optionAudio.values.any((a) => a.isNotEmpty)
        : pair.audio.isNotEmpty;
    return ChoiceExercise(
      kind: kind,
      prompt: prompt(pair),
      options: options,
      answer: answer(pair),
      accepted: accepted,
      // Heard on its own for listen-and-choose; after a correct check for translate-from-target.
      audio: kind == ExerciseKind.translateToTarget ? const [] : pair.audio,
      optionAudio: optionAudio,
      voiceId: !heard
          ? null
          : kind == ExerciseKind.translateToTarget
          ? pickVoice()
          : voiceFor(pair),
    );
  }

  List<Exercise> choicePool(ExerciseKind kind) {
    final seen = <String>{};
    final out = <Exercise>[];
    for (final pair in pairs) {
      final e = choice(kind, pair);
      // One question per prompt: "I'm tired" has two valid target phrases but is asked once.
      if (e != null && seen.add(e.prompt)) out.add(e);
    }
    return out..shuffle(rng);
  }

  // --- build the sentence ------------------------------------------------
  final allTiles = [for (final p in pairs) ...tiles[p]!];
  final buildPool = <Exercise>[];
  final builtPrompts = <String>{};
  for (final pair in pairs) {
    if (pair.phrase.tokens.length < 2 || !builtPrompts.add(pair.source))
      continue;
    final answerTiles = tiles[pair]!;
    final accepted = {
      for (final p in pairs)
        if (p.source == pair.source)
          p.phrase.tokens.map((t) => pickScript(t.surface, script)).join(' '),
    };
    final taken = answerTiles.map((t) => t.text).toSet();
    final extras = <Tile>[];
    for (final t in (allTiles.toList()..shuffle(rng))) {
      if (extras.length == 2) break;
      if (taken.add(t.text)) extras.add(t);
    }
    buildPool.add(
      BuildSentenceExercise(
        prompt: pair.source,
        answer: answerTiles,
        bank: [...answerTiles, ...extras]..shuffle(rng),
        accepted: accepted,
        audio: pair.audio,
        voiceId: voiceFor(pair),
      ),
    );
  }
  buildPool.shuffle(rng);

  // --- match pairs (lemmas) ----------------------------------------------
  Exercise? match;
  final matchable = <MatchPair>[];
  final glossSeen = <String>{};
  for (final pair in pairs) {
    for (final token in pair.phrase.tokens) {
      final lemma = unit.pack.lemmas[token.lemma];
      final gloss = unit.text.glosses[token.lemma];
      if (lemma == null || gloss == null || !glossSeen.add(gloss.gloss))
        continue;
      matchable.add(
        MatchPair(
          lemma: lemma.id,
          target: pickScript(lemma.text, script),
          gloss: gloss.gloss,
          audio: lemma.audio,
        ),
      );
    }
  }
  if (matchable.length >= 3) {
    matchable.shuffle(rng);
    final chosen = matchable.take(5).toList();
    match = MatchPairsExercise(
      pairs: chosen,
      shuffledGlosses: chosen.map((p) => p.gloss).toList()..shuffle(rng),
      voiceId: pickVoice(),
    );
  }

  // --- type what you hear ------------------------------------------------
  final typeable = [
    for (final pair in pairs)
      if (allowTyping && pair.audio.isNotEmpty) pair,
  ]..shuffle(rng);
  final type = typeable.isEmpty
      ? null
      : TypeExercise(
          answer:
              readingOf(typeable.first.phrase.text) ?? typeable.first.target,
          display: typeable.first.target,
          audio: typeable.first.audio,
          voiceId: voiceFor(typeable.first),
        );

  // --- assemble: round-robin so a lesson mixes types ---------------------
  final pools = <List<Exercise>>[
    choicePool(ExerciseKind.listenAndChoose),
    choicePool(ExerciseKind.translateFromTarget),
    buildPool,
    choicePool(ExerciseKind.translateToTarget),
    [?match],
    [?type],
  ];
  final exercises = <Exercise>[];
  var round = 0;
  while (exercises.length < maxExercises &&
      pools.any((p) => round < p.length)) {
    for (final pool in pools) {
      if (round < pool.length && exercises.length < maxExercises)
        exercises.add(pool[round]);
    }
    round++;
  }
  exercises.shuffle(rng);

  final intro = [
    for (final pair in pairs.take(maxIntro ?? pairs.length))
      IntroCard(
        target: pair.target,
        source: pair.source,
        tiles: tiles[pair]!,
        audio: pair.audio,
        voiceId: voiceFor(pair),
        concept: pair.phrase.concept,
      ),
  ];
  return LessonPlan(intro: intro, exercises: exercises);
}
