import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../exercises/exercise.dart';
import '../l10n/app_localizations.dart';
import '../packs/models.dart';
import 'lesson_parts.dart';
import 'mascot.dart';
import 'reorder_wrap.dart';
import 'slide_to_place.dart';

/// Every exercise view takes its exercise and reports back through `onDone`
/// (whether the learner got it right) when the learner presses Continue.

// --- multiple choice ------------------------------------------------------

class ChoiceView extends StatefulWidget {
  const ChoiceView({
    super.key,
    required this.exercise,
    required this.lesson,
    required this.onDone,
  });

  final ChoiceExercise exercise;
  final LessonContext lesson;
  final ValueChanged<bool> onDone;

  @override
  State<ChoiceView> createState() => _ChoiceViewState();
}

class _ChoiceViewState extends State<ChoiceView> with AutoStart, ChimeLead {
  String? _selected;
  bool _checked = false;

  /// Options already tried and wrong; they stay red and cannot be picked again.
  final Set<String> _wrong = {};

  /// The learner gave up and was shown the answer.
  bool _revealed = false;

  final int _variant = newVariant();

  ChoiceExercise get _e => widget.exercise;

  bool get _locked => _revealed || (_checked && _selectedCorrect);
  bool get _selectedCorrect => _selected != null && _e.isCorrect(_selected!);

  void _play() => widget.lesson.audio.play(_e.audio, voiceId: _e.voiceId);

  @override
  void onStart() {
    if (_e.hidesPrompt) _play();
  }

  OptionState _stateOf(String option) {
    if (_locked && _e.isCorrect(option)) return OptionState.right;
    if (_wrong.contains(option)) return OptionState.wrong;
    return option == _selected && !_locked
        ? OptionState.selected
        : OptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final correct = _checked && _selectedCorrect;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MascotPrompt(
            pose: feedbackPose(
              idle: _e.hidesPrompt ? Pose.focused : Pose.thinking,
              checked: _checked,
              correct: correct,
              revealed: _revealed,
              variant: _variant,
            ),
            text: _e.hidesPrompt
                ? l10n.listenInstruction
                : l10n.translateInstruction,
          ),
          const SizedBox(height: 16),
          if (_e.hidesPrompt)
            Align(
              alignment: Alignment.centerLeft,
              child: SpeakerButton(size: 88, onPressed: _play),
            )
          else
            ScriptText(
              _e.prompt,
              lesson: widget.lesson,
              textKey: const Key('prompt'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                for (final option in _e.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OptionCard(
                      lesson: widget.lesson,
                      label: option,
                      state: _stateOf(option),
                      onTap: () {
                        // Target-language options are read out when tapped,
                        // also once they can no longer be picked.
                        if (_e.kind == ExerciseKind.translateToTarget) {
                          widget.lesson.audio.play(
                            _e.optionAudio[option] ?? const <Recording>[],
                            voiceId: _e.voiceId,
                          );
                        }
                        if (_locked || _wrong.contains(option)) return;
                        setState(() {
                          _selected = option;
                          _checked = false;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          CheckBar(
            canCheck: _selected != null && !_wrong.contains(_selected),
            checked: _checked || _revealed,
            correct: correct,
            correctAnswer: widget.lesson.withReading(_e.answer),
            revealed: _revealed,
            onRetry: _revealed
                ? null
                : () => setState(() {
                    _checked = false;
                    _selected = null;
                  }),
            onSkip: _revealed
                ? null
                : () {
                    setState(() {
                      _revealed = true;
                      _checked = true;
                    });
                    // Say the target phrase, as a correct answer would.
                    if (_e.kind == ExerciseKind.translateToTarget) {
                      widget.lesson.audio.play(
                        _e.optionAudio[_e.answer] ?? const <Recording>[],
                        voiceId: _e.voiceId,
                      );
                    } else {
                      _play();
                    }
                  },
            onCheck: () {
              setState(() {
                _checked = true;
                if (!_selectedCorrect) _wrong.add(_selected!);
              });
              // A correct answer is confirmed by saying the target phrase: the prompt when the
              // options are English, the chosen option when they are Serbian.
              if (_selectedCorrect) {
                widget.lesson.sounds.play(Sound.correct);
                if (_e.kind == ExerciseKind.translateToTarget) {
                  final audio =
                      _e.optionAudio[_selected] ?? const <Recording>[];
                  speakAfterChime(
                    () => widget.lesson.audio.play(audio, voiceId: _e.voiceId),
                  );
                } else {
                  speakAfterChime(_play);
                }
              }
            },
            onContinue: () => widget.onDone(correct),
          ),
        ],
      ),
    );
  }
}

// --- build the sentence ---------------------------------------------------

class BuildView extends StatefulWidget {
  const BuildView({
    super.key,
    required this.exercise,
    required this.lesson,
    required this.onDone,
  });

  final BuildSentenceExercise exercise;
  final LessonContext lesson;
  final ValueChanged<bool> onDone;

  @override
  State<BuildView> createState() => _BuildViewState();
}

class _BuildViewState extends State<BuildView> with ChimeLead {
  /// Indices into the bank, in the order the learner placed them.
  final List<int> _placed = [];
  bool _checked = false;

  /// The learner gave up and was shown the answer.
  bool _revealed = false;

  final int _variant = newVariant();

  BuildSentenceExercise get _e => widget.exercise;

  /// No more edits: the answer is right or has been shown.
  bool get _locked => _revealed || (_checked && _e.isCorrect(_built));

  /// Right-to-left languages build the phrase from the right.
  late final TextDirection _direction =
      isRtlText([for (final t in _e.answer) t.text])
      ? TextDirection.rtl
      : TextDirection.ltr;

  /// One key per tile, so a tile keeps its state (and can slide) when it moves
  /// between the answer and the bank.
  late final List<GlobalKey> _tileKeys = [
    for (var i = 0; i < _e.bank.length; i++) GlobalKey(),
  ];

  List<Tile> get _built => [for (final i in _placed) _e.bank[i]];

  /// The explanation shown while a tile is held, if any.
  LemmaPeek? _peek;

  void _info(Tile tile) => showLemmaSheet(
    context,
    lesson: widget.lesson,
    lemmaId: tile.lemma,
    form: tile.text,
    grammar: tile.grammar,
    voiceId: _e.voiceId,
  );

  void _showWhileHeld(Tile tile) {
    _hideHeld();
    _peek = showLemmaPeek(
      context,
      lesson: widget.lesson,
      lemmaId: tile.lemma,
      form: tile.text,
      grammar: tile.grammar,
      voiceId: _e.voiceId,
    );
  }

  void _hideHeld({bool immediately = false}) {
    _peek?.hide(immediately: immediately);
    _peek = null;
  }

  @override
  void dispose() {
    _hideHeld(immediately: true);
    super.dispose();
  }

  /// Shows the answer by sliding the tiles into place: wrong words leave the
  /// phrase, the rest shuffle into order, then missing words slide in one by one.
  Future<void> _revealAnswer() async {
    setState(() {
      _revealed = true;
      _checked = true;
    });
    widget.lesson.audio.play(_e.audio, voiceId: _e.voiceId);

    // Pair each answer word with a tile, preferring tiles already in the phrase.
    final target = <int>[];
    for (final want in _e.answer) {
      bool fits(int i) => _e.bank[i].text == want.text && !target.contains(i);
      target.add(
        _placed.firstWhere(fits, orElse: () => -1) >= 0
            ? _placed.firstWhere(fits)
            : List.generate(_e.bank.length, (i) => i).firstWhere(fits),
      );
    }

    Future<void> step(int millis, VoidCallback change) async {
      if (!mounted) return;
      setState(change);
      await Future<void>.delayed(Duration(milliseconds: millis));
    }

    await step(0, () => _placed.removeWhere((i) => !target.contains(i)));
    if (!mounted) return;
    final kept = [
      for (final i in target)
        if (_placed.contains(i)) i,
    ];
    final reordered = !_sameSequence(kept, _placed);
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (reordered) {
      await step(
        0,
        () => _placed
          ..clear()
          ..addAll(kept),
      );
      await Future<void>.delayed(const Duration(milliseconds: 420));
    }
    for (var k = 0; k < target.length; k++) {
      if (_placed.contains(target[k])) continue;
      await step(170, () => _placed.insert(k, target[k]));
    }
  }

  bool _sameSequence(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _tile(int bankIndex, {required bool placed}) {
    final tile = _e.bank[bankIndex];
    return SlideToPlace(
      key: _tileKeys[bankIndex],
      zone: placed,
      // Tiles in the answer are moved by the reorder wrap itself.
      followLayout: !placed,
      child: Listener(
        // The explanation hides when the finger lifts, however the press ends.
        onPointerUp: (_) => _hideHeld(),
        onPointerCancel: (_) => _hideHeld(),
        child: GestureDetector(
          // Holding a word explains it until release; after checking, a tap does.
          onLongPressStart: (_) => _showWhileHeld(tile),
          child: ActionChip(
            key: ValueKey('${placed ? 'answer' : 'bank'}-$bankIndex'),
            label: ScriptText(
              tile.text,
              lesson: widget.lesson,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onPressed: () {
              speakTile(widget.lesson, tile, voiceId: _e.voiceId);
              if (_locked) {
                _info(tile);
              } else {
                setState(() {
                  _checked = false;
                  placed ? _placed.remove(bankIndex) : _placed.add(bankIndex);
                });
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final correct = !_revealed && _checked && _e.isCorrect(_built);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MascotPrompt(
            pose: feedbackPose(
              idle: Pose.running,
              checked: _checked,
              correct: correct,
              revealed: _revealed,
              variant: _variant,
            ),
            text: l10n.buildInstruction,
          ),
          const SizedBox(height: 16),
          ScriptText(
            _e.prompt,
            lesson: widget.lesson,
            textKey: const Key('prompt'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          Container(
            key: const Key('answer-area'),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: scheme.outlineVariant, width: 2),
              ),
            ),
            child: Directionality(
              textDirection: _direction,
              child: ReorderWrap(
                ids: _placed,
                enabled: !_locked,
                itemBuilder: (i) => _tile(i, placed: true),
                onReorder: (order) => setState(() {
                  _checked = false;
                  _placed
                    ..clear()
                    ..addAll(order);
                }),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Directionality(
            textDirection: _direction,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _e.bank.length; i++)
                  if (!_placed.contains(i)) _tile(i, placed: false),
              ],
            ),
          ),
          if (_locked) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (_e.audio.isNotEmpty) ...[
                  SpeakerButton(
                    onPressed: () =>
                        widget.lesson.audio.play(_e.audio, voiceId: _e.voiceId),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    l10n.tapWordHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          CheckBar(
            canCheck: _placed.isNotEmpty,
            checked: _checked,
            correct: correct,
            correctAnswer: widget.lesson.tilesWithReading(_e.answer),
            revealed: _revealed,
            onRetry: _revealed ? null : () => setState(() => _checked = false),
            onSkip: _revealed ? null : _revealAnswer,
            onCheck: () {
              setState(() => _checked = true);
              if (_e.isCorrect(_built)) {
                widget.lesson.sounds.play(Sound.correct);
                speakAfterChime(
                  () => widget.lesson.audio.play(_e.audio, voiceId: _e.voiceId),
                );
              }
            },
            onContinue: () => widget.onDone(correct),
          ),
        ],
      ),
    );
  }
}

// --- match pairs ------------------------------------------------------------

class MatchView extends StatefulWidget {
  const MatchView({
    super.key,
    required this.exercise,
    required this.lesson,
    required this.onDone,
  });

  final MatchPairsExercise exercise;
  final LessonContext lesson;
  final ValueChanged<bool> onDone;

  @override
  State<MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<MatchView> {
  int? _left;
  int? _wrongRight;
  final Set<int> _matched = {};

  /// The learner gave up and was shown every pair.
  bool _revealed = false;

  MatchPairsExercise get _e => widget.exercise;
  bool get _done => _matched.length == _e.pairs.length;

  void _tapLeft(int i) {
    // A matched word can still be read out; it just is not selected again.
    if (_matched.contains(i) || _done) {
      widget.lesson.audio.play(_e.pairs[i].audio, voiceId: _e.voiceId);
      return;
    }
    setState(() {
      _left = i;
      _wrongRight = null;
    });
    widget.lesson.audio.play(_e.pairs[i].audio, voiceId: _e.voiceId);
  }

  void _tapRight(int j) {
    final left = _left;
    if (left == null || _done) return;
    final gloss = _e.shuffledGlosses[j];
    setState(() {
      if (_e.pairs[left].gloss == gloss) {
        _matched.add(left);
        _left = null;
        _wrongRight = null;
      } else {
        _wrongRight = j;
      }
    });
    // A wrong tap only flashes red; finishing every pair is a correct answer.
    if (_done) widget.lesson.sounds.play(Sound.correct);
  }

  bool _rightMatched(int j) =>
      _matched.any((i) => _e.pairs[i].gloss == _e.shuffledGlosses[j]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MascotPrompt(
            pose: _done
                ? Pose.excited
                : _wrongRight != null
                ? Pose.confused
                : Pose.alert,
            text: l10n.matchInstruction,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < _e.pairs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: OptionCard(
                                lesson: widget.lesson,
                                label: _e.pairs[i].target,
                                state: _matched.contains(i)
                                    ? OptionState.right
                                    : _left == i
                                    ? OptionState.selected
                                    : OptionState.idle,
                                onTap: () => _tapLeft(i),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OptionCard(
                                label: _e.shuffledGlosses[i],
                                state: _rightMatched(i)
                                    ? OptionState.right
                                    : _wrongRight == i
                                    ? OptionState.wrong
                                    : OptionState.idle,
                                onTap: _rightMatched(i)
                                    ? null
                                    : () => _tapRight(i),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          CheckBar(
            canCheck: false,
            checked: _done,
            correct: !_revealed,
            revealed: _revealed,
            correctAnswer: null,
            onCheck: () {},
            onSkip: _done
                ? null
                : () => setState(() {
                    _revealed = true;
                    _left = null;
                    _wrongRight = null;
                    _matched.addAll(List.generate(_e.pairs.length, (i) => i));
                  }),
            onContinue: () => widget.onDone(!_revealed),
          ),
        ],
      ),
    );
  }
}

// --- type what you hear -------------------------------------------------------

class TypeView extends StatefulWidget {
  const TypeView({
    super.key,
    required this.exercise,
    required this.lesson,
    required this.onDone,
  });

  final TypeExercise exercise;
  final LessonContext lesson;
  final ValueChanged<bool> onDone;

  @override
  State<TypeView> createState() => _TypeViewState();
}

class _TypeViewState extends State<TypeView> with AutoStart {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _checked = false;
  bool _revealed = false;

  final int _variant = newVariant();

  TypeExercise get _e => widget.exercise;

  void _play() => widget.lesson.audio.play(_e.audio, voiceId: _e.voiceId);

  @override
  void onStart() => _play();

  /// A wrong answer keeps the keyboard up so the learner can fix it at once.
  void _check() {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _checked = true);
    if (_e.isCorrect(_controller.text)) {
      widget.lesson.sounds.play(Sound.correct);
      _focus.unfocus();
    } else {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final correct = !_revealed && _checked && _e.isCorrect(_controller.text);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MascotPrompt(
            pose: feedbackPose(
              idle: Pose.grumpy,
              checked: _checked,
              correct: correct,
              close: _e.isClose(_controller.text),
              revealed: _revealed,
              variant: _variant,
            ),
            text: l10n.typeInstruction,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: SpeakerButton(size: 88, onPressed: _play),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            focusNode: _focus,
            readOnly: _checked && correct || _revealed,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l10n.typeHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            style: Theme.of(context).textTheme.titleLarge,
            onChanged: (_) => setState(() => _checked = false),
            onSubmitted: (_) => _check(),
          ),
          const Spacer(),
          CheckBar(
            canCheck: _controller.text.trim().isNotEmpty,
            checked: _checked || _revealed,
            correct: correct,
            correctAnswer: widget.lesson.withReading(
              _e.shown,
              _e.answer == _e.shown ? null : _e.answer,
            ),
            close: _e.isClose(_controller.text),
            revealed: _revealed,
            onRetry: _revealed
                ? null
                : () => setState(() {
                    _checked = false;
                    _controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _controller.text.length,
                    );
                    _focus.requestFocus();
                  }),
            onSkip: _revealed
                ? null
                : () {
                    setState(() => _revealed = true);
                    _focus.unfocus();
                    _play();
                  },
            onCheck: _check,
            onContinue: () => widget.onDone(correct),
          ),
        ],
      ),
    );
  }
}

// --- introduction card ----------------------------------------------------------

class IntroView extends StatefulWidget {
  const IntroView({
    super.key,
    required this.card,
    required this.lesson,
    required this.onDone,
    this.pose = Pose.wave,
  });

  final IntroCard card;

  /// The mascot's mood for this card.
  final Pose pose;
  final LessonContext lesson;
  final VoidCallback onDone;

  @override
  State<IntroView> createState() => _IntroViewState();
}

class _IntroViewState extends State<IntroView> with AutoStart {
  IntroCard get _c => widget.card;

  void _play() => widget.lesson.audio.play(_c.audio, voiceId: _c.voiceId);

  @override
  void onStart() => _play();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MascotPrompt(pose: widget.pose, text: l10n.introInstruction),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ScriptText(
                  _c.target,
                  lesson: widget.lesson,
                  textKey: const Key('prompt'),
                  style: textTheme.headlineMedium,
                ),
              ),
              if (_c.audio.isNotEmpty) SpeakerButton(onPressed: _play),
            ],
          ),
          const SizedBox(height: 8),
          ScriptText(
            _c.source,
            lesson: widget.lesson,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tile in _c.tiles)
                ActionChip(
                  label: ScriptText(
                    tile.text,
                    lesson: widget.lesson,
                    style: textTheme.titleMedium,
                  ),
                  onPressed: () {
                    speakTile(widget.lesson, tile, voiceId: _c.voiceId);
                    showLemmaSheet(
                      context,
                      lesson: widget.lesson,
                      lemmaId: tile.lemma,
                      form: tile.text,
                      grammar: tile.grammar,
                      voiceId: _c.voiceId,
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.tapWordHint, style: textTheme.bodySmall),
          const Spacer(),
          FilledButton(onPressed: widget.onDone, child: Text(l10n.gotIt)),
        ],
      ),
    );
  }
}
