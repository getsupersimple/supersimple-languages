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
  const Tile({required this.text, required this.lemma, required this.grammar, this.audio = const []});

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

  bool isCorrect(List<Tile> built) => accepted.contains(built.map((t) => t.text).join(' '));
}

class MatchPair {
  const MatchPair({required this.lemma, required this.target, required this.gloss, required this.audio});

  final String lemma;
  final String target;
  final String gloss;
  final List<Recording> audio;
}

/// Match target-language words to their meanings. Works on lemmas.
class MatchPairsExercise extends Exercise {
  const MatchPairsExercise({required this.pairs, required this.shuffledGlosses, this.voiceId});

  final List<MatchPair> pairs;

  /// The meanings in the order shown on the right-hand side.
  final List<String> shuffledGlosses;
  final String? voiceId;
}

/// Type the target phrase after hearing it.
class TypeExercise extends Exercise {
  const TypeExercise({required this.answer, required this.audio, this.voiceId});

  final String answer;
  final List<Recording> audio;
  final String? voiceId;

  bool isCorrect(String typed) => normalizeAnswer(typed) == normalizeAnswer(answer);
}

/// Shows a phrase before it is tested. Not scored.
class IntroCard {
  const IntroCard({
    required this.target,
    required this.source,
    required this.tiles,
    required this.audio,
    this.voiceId,
  });

  final String target;
  final String source;
  final List<Tile> tiles;
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
  'č': 'c', 'ć': 'c', 'š': 's', 'ž': 'z', 'đ': 'dj',
};

/// Typing check: case, punctuation, spacing and accents are ignored, so a
/// learner on an English keyboard can type "Gde je toalet" or "umoran sam".
String normalizeAnswer(String text) {
  final folded = text.toLowerCase().split('').map((c) => _folds[c] ?? c).join();
  return folded.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').trim().split(RegExp(r'\s+')).join(' ');
}

class _Pair {
  const _Pair(this.phrase, this.target, this.source);

  final TargetPhrase phrase;
  final String target;
  final String source;
}

/// Builds a lesson from one unit.
///
/// [script] picks the script shown for each text (Latin by default). Pass a
/// seeded [random] for repeatable output in tests. Voices are picked here, once
/// per exercise, so a lesson mixes speakers without changing voice mid-question.
LessonPlan generateLesson(
  UnitContent unit, {
  String script = 'Latn',
  Random? random,
  int optionCount = 4,
  int maxExercises = 10,
  int maxIntro = 5,
}) {
  final rng = random ?? Random();
  final pairs = <_Pair>[];
  for (final phrase in unit.pack.phrases) {
    final source = unit.sourceTextFor(phrase);
    if (source == null) continue;
    pairs.add(_Pair(phrase, pickScript(phrase.text, script), pickScript(source, script)));
  }

  final voices = ({
    for (final p in unit.pack.phrases)
      for (final r in p.audio) r.voiceId,
    for (final l in unit.pack.lemmas.values)
      for (final r in l.audio) r.voiceId,
  }).toList()
    ..sort();
  String? pickVoice() => voices.isEmpty ? null : voices[rng.nextInt(voices.length)];

  Tile tileOf(Token t) => Tile(
        text: pickScript(t.surface, script),
        lemma: t.lemma,
        grammar: t.grammar,
        audio: unit.pack.lemmas[t.lemma]?.audioFor(t.surface) ?? const [],
      );

  // --- multiple choice ---------------------------------------------------
  ChoiceExercise? choice(ExerciseKind kind, _Pair pair) {
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
    }).toList()
      ..shuffle(rng);
    if (distractors.isEmpty) return null;
    if (kind == ExerciseKind.listenAndChoose && pair.phrase.audio.isEmpty) return null;

    final options = [answer(pair), ...distractors.take(optionCount - 1)]..shuffle(rng);
    final optionAudio = kind == ExerciseKind.translateToTarget
        ? {for (final p in pairs) if (options.contains(p.target)) p.target: p.phrase.audio}
        : const <String, List<Recording>>{};
    final heard = kind == ExerciseKind.translateToTarget
        ? optionAudio.values.any((a) => a.isNotEmpty)
        : pair.phrase.audio.isNotEmpty;
    return ChoiceExercise(
      kind: kind,
      prompt: prompt(pair),
      options: options,
      answer: answer(pair),
      accepted: accepted,
      // Heard on its own for listen-and-choose; after a correct check for translate-from-target.
      audio: kind == ExerciseKind.translateToTarget ? const [] : pair.phrase.audio,
      optionAudio: optionAudio,
      voiceId: heard ? pickVoice() : null,
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
  final allTiles = [for (final p in pairs) ...p.phrase.tokens.map(tileOf)];
  final buildPool = <Exercise>[];
  final builtPrompts = <String>{};
  for (final pair in pairs) {
    if (pair.phrase.tokens.length < 2 || !builtPrompts.add(pair.source)) continue;
    final answerTiles = pair.phrase.tokens.map(tileOf).toList();
    final accepted = {
      for (final p in pairs)
        if (p.source == pair.source) p.phrase.tokens.map((t) => pickScript(t.surface, script)).join(' '),
    };
    final taken = answerTiles.map((t) => t.text).toSet();
    final extras = <Tile>[];
    for (final t in (allTiles.toList()..shuffle(rng))) {
      if (extras.length == 2) break;
      if (taken.add(t.text)) extras.add(t);
    }
    buildPool.add(BuildSentenceExercise(
      prompt: pair.source,
      answer: answerTiles,
      bank: [...answerTiles, ...extras]..shuffle(rng),
      accepted: accepted,
      audio: pair.phrase.audio,
      voiceId: pair.phrase.audio.isEmpty ? null : pickVoice(),
    ));
  }
  buildPool.shuffle(rng);

  // --- match pairs (lemmas) ----------------------------------------------
  final matchPool = <Exercise>[];
  final matchable = <MatchPair>[];
  final glossSeen = <String>{};
  for (final pair in pairs) {
    for (final token in pair.phrase.tokens) {
      final lemma = unit.pack.lemmas[token.lemma];
      final gloss = unit.text.glosses[token.lemma];
      if (lemma == null || gloss == null || !glossSeen.add(gloss.gloss)) continue;
      matchable.add(MatchPair(
        lemma: lemma.id,
        target: pickScript(lemma.text, script),
        gloss: gloss.gloss,
        audio: lemma.audio,
      ));
    }
  }
  if (matchable.length >= 3) {
    matchable.shuffle(rng);
    final chosen = matchable.take(5).toList();
    matchPool.add(MatchPairsExercise(
      pairs: chosen,
      shuffledGlosses: chosen.map((p) => p.gloss).toList()..shuffle(rng),
      voiceId: pickVoice(),
    ));
  }

  // --- type what you hear ------------------------------------------------
  final typePool = <Exercise>[
    for (final pair in pairs)
      if (pair.phrase.audio.isNotEmpty)
        TypeExercise(answer: pair.target, audio: pair.phrase.audio, voiceId: pickVoice()),
  ]..shuffle(rng);

  // --- assemble: round-robin so a lesson mixes types ---------------------
  final pools = <List<Exercise>>[
    choicePool(ExerciseKind.listenAndChoose),
    choicePool(ExerciseKind.translateFromTarget),
    buildPool,
    choicePool(ExerciseKind.translateToTarget),
    matchPool.take(1).toList(),
    typePool.take(1).toList(),
  ];
  final exercises = <Exercise>[];
  var round = 0;
  while (exercises.length < maxExercises && pools.any((p) => round < p.length)) {
    for (final pool in pools) {
      if (round < pool.length && exercises.length < maxExercises) exercises.add(pool[round]);
    }
    round++;
  }
  exercises.shuffle(rng);

  final intro = [
    for (final pair in pairs.take(maxIntro))
      IntroCard(
        target: pair.target,
        source: pair.source,
        tiles: pair.phrase.tokens.map(tileOf).toList(),
        audio: pair.phrase.audio,
        voiceId: pair.phrase.audio.isEmpty ? null : pickVoice(),
      ),
  ];
  return LessonPlan(intro: intro, exercises: exercises);
}
