import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../exercises/exercise.dart';
import '../l10n/app_localizations.dart';
import '../packs/models.dart';
import 'lesson_parts.dart';

/// Every exercise view takes its exercise and reports back through `onDone`
/// (whether the learner got it right) when the learner presses Continue.

// --- multiple choice ------------------------------------------------------

class ChoiceView extends StatefulWidget {
  const ChoiceView({super.key, required this.exercise, required this.lesson, required this.onDone});

  final ChoiceExercise exercise;
  final LessonContext lesson;
  final ValueChanged<bool> onDone;

  @override
  State<ChoiceView> createState() => _ChoiceViewState();
}

class _ChoiceViewState extends State<ChoiceView> with AutoStart, ChimeLead {
  String? _selected;
  bool _checked = false;

  ChoiceExercise get _e => widget.exercise;

  void _play() => widget.lesson.audio.play(_e.audio, voiceId: _e.voiceId);

  @override
  void onStart() {
    if (_e.hidesPrompt) _play();
  }

  OptionState _stateOf(String option) {
    if (_checked) {
      if (_e.isCorrect(option)) return OptionState.right;
      return option == _selected ? OptionState.wrong : OptionState.idle;
    }
    return option == _selected ? OptionState.selected : OptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final correct = _selected != null && _e.isCorrect(_selected!);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_e.hidesPrompt ? l10n.listenInstruction : l10n.translateInstruction,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (_e.hidesPrompt)
            Align(alignment: Alignment.centerLeft, child: SpeakerButton(size: 88, onPressed: _play))
          else
            Text(_e.prompt, key: const Key('prompt'), style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                for (final option in _e.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OptionCard(
                      label: option,
                      state: _stateOf(option),
                      onTap: _checked ? null : () => setState(() => _selected = option),
                    ),
                  ),
              ],
            ),
          ),
          CheckBar(
            canCheck: _selected != null,
            checked: _checked,
            correct: correct,
            correctAnswer: _e.answer,
            onCheck: () {
              setState(() => _checked = true);
              // A correct answer is confirmed by saying the target phrase: the prompt when the
              // options are English, the chosen option when they are Serbian.
              if (correct) {
                widget.lesson.sounds.play(Sound.correct);
                if (_e.kind == ExerciseKind.translateToTarget) {
                  final audio = _e.optionAudio[_selected] ?? const <Recording>[];
                  speakAfterChime(() => widget.lesson.audio.play(audio, voiceId: _e.voiceId));
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
  const BuildView({super.key, required this.exercise, required this.lesson, required this.onDone});

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

  BuildSentenceExercise get _e => widget.exercise;

  List<Tile> get _built => [for (final i in _placed) _e.bank[i]];

  void _info(Tile tile) => showLemmaSheet(
        context,
        lesson: widget.lesson,
        lemmaId: tile.lemma,
        form: tile.text,
        grammar: tile.grammar,
        voiceId: _e.voiceId,
      );

  Widget _tile(int bankIndex, {required bool placed}) {
    final tile = _e.bank[bankIndex];
    return GestureDetector(
      // Long press explains a word while building; after checking, a tap does.
      onLongPress: () => _info(tile),
      child: ActionChip(
        key: ValueKey('${placed ? 'answer' : 'bank'}-$bankIndex'),
        label: Text(tile.text, style: Theme.of(context).textTheme.titleMedium),
        onPressed: () {
          speakTile(widget.lesson, tile, voiceId: _e.voiceId);
          if (_checked) {
            _info(tile);
          } else {
            setState(() => placed ? _placed.remove(bankIndex) : _placed.add(bankIndex));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final correct = _checked && _e.isCorrect(_built);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.buildInstruction, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text(_e.prompt, key: const Key('prompt'), style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Container(
            key: const Key('answer-area'),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant, width: 2)),
            ),
            child: Wrap(spacing: 8, runSpacing: 8, children: [for (final i in _placed) _tile(i, placed: true)]),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _e.bank.length; i++)
                if (!_placed.contains(i)) _tile(i, placed: false),
            ],
          ),
          if (_checked) ...[
            const SizedBox(height: 16),
            Text(l10n.tapWordHint, style: Theme.of(context).textTheme.bodySmall),
          ],
          const Spacer(),
          CheckBar(
            canCheck: _placed.isNotEmpty,
            checked: _checked,
            correct: correct,
            correctAnswer: _e.answerText,
            onCheck: () {
              setState(() => _checked = true);
              void speak() => widget.lesson.audio.play(_e.audio, voiceId: _e.voiceId);
              if (_e.isCorrect(_built)) {
                widget.lesson.sounds.play(Sound.correct);
                speakAfterChime(speak);
              } else {
                speak();
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
  const MatchView({super.key, required this.exercise, required this.lesson, required this.onDone});

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
  int _mistakes = 0;

  MatchPairsExercise get _e => widget.exercise;
  bool get _done => _matched.length == _e.pairs.length;

  void _tapLeft(int i) {
    if (_matched.contains(i) || _done) return;
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
        _mistakes++;
        _wrongRight = j;
      }
    });
    // Finishing every pair without a mistake counts as a correct answer.
    if (_done && _mistakes == 0) widget.lesson.sounds.play(Sound.correct);
  }

  bool _rightMatched(int j) =>
      _matched.any((i) => _e.pairs[i].gloss == _e.shuffledGlosses[j]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final correct = _mistakes == 0;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.matchInstruction, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < _e.pairs.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OptionCard(
                              label: _e.pairs[i].target,
                              state: _matched.contains(i)
                                  ? OptionState.right
                                  : _left == i
                                      ? OptionState.selected
                                      : OptionState.idle,
                              onTap: _matched.contains(i) ? null : () => _tapLeft(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        for (var j = 0; j < _e.shuffledGlosses.length; j++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OptionCard(
                              label: _e.shuffledGlosses[j],
                              state: _rightMatched(j)
                                  ? OptionState.right
                                  : _wrongRight == j
                                      ? OptionState.wrong
                                      : OptionState.idle,
                              onTap: _rightMatched(j) ? null : () => _tapRight(j),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          CheckBar(
            canCheck: false,
            checked: _done,
            correct: correct,
            correctAnswer: null,
            onCheck: () {},
            onContinue: () => widget.onDone(correct),
          ),
        ],
      ),
    );
  }
}

// --- type what you hear -------------------------------------------------------

class TypeView extends StatefulWidget {
  const TypeView({super.key, required this.exercise, required this.lesson, required this.onDone});

  final TypeExercise exercise;
  final LessonContext lesson;
  final ValueChanged<bool> onDone;

  @override
  State<TypeView> createState() => _TypeViewState();
}

class _TypeViewState extends State<TypeView> with AutoStart {
  final _controller = TextEditingController();
  bool _checked = false;

  TypeExercise get _e => widget.exercise;

  void _play() => widget.lesson.audio.play(_e.audio, voiceId: _e.voiceId);

  @override
  void onStart() => _play();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final correct = _checked && _e.isCorrect(_controller.text);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.typeInstruction, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerLeft, child: SpeakerButton(size: 88, onPressed: _play)),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            enabled: !_checked,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l10n.typeHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            style: Theme.of(context).textTheme.titleLarge,
            onChanged: (_) => setState(() {}),
          ),
          const Spacer(),
          CheckBar(
            canCheck: _controller.text.trim().isNotEmpty,
            checked: _checked,
            correct: correct,
            correctAnswer: _e.answer,
            onCheck: () {
              setState(() => _checked = true);
              if (_e.isCorrect(_controller.text)) widget.lesson.sounds.play(Sound.correct);
            },
            onContinue: () => widget.onDone(correct),
          ),
        ],
      ),
    );
  }
}

// --- introduction card ----------------------------------------------------------

class IntroView extends StatefulWidget {
  const IntroView({super.key, required this.card, required this.lesson, required this.onDone});

  final IntroCard card;
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
          Text(l10n.introInstruction, style: textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(_c.target, key: const Key('prompt'), style: textTheme.headlineMedium)),
              if (_c.audio.isNotEmpty) SpeakerButton(onPressed: _play),
            ],
          ),
          const SizedBox(height: 8),
          Text(_c.source, style: textTheme.titleMedium),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tile in _c.tiles)
                ActionChip(
                  label: Text(tile.text, style: textTheme.titleMedium),
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
