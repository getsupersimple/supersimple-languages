import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../exercises/exercise.dart';
import '../l10n/app_localizations.dart';
import '../packs/models.dart';
import 'exercise_views.dart';
import 'lesson_parts.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.content,
    required this.audio,
    this.plan,
    this.script = 'Latn',
  });

  final UnitContent content;
  final LessonAudio audio;

  /// Defaults to a freshly generated lesson; tests pass a fixed plan.
  final LessonPlan? plan;
  final String script;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late final LessonPlan _plan = widget.plan ?? generateLesson(widget.content, script: widget.script);
  late final LessonContext _lesson =
      LessonContext(content: widget.content, audio: widget.audio, script: widget.script);
  int _step = 0;
  int _correct = 0;

  bool get _finished => _step >= _plan.steps;

  @override
  void dispose() {
    widget.audio.stop();
    super.dispose();
  }

  void _advance({bool? correct}) => setState(() {
        if (correct == true) _correct++;
        _step++;
      });

  Widget _stepView() {
    final key = ValueKey(_step);
    if (_step < _plan.intro.length) {
      return IntroView(key: key, card: _plan.intro[_step], lesson: _lesson, onDone: _advance);
    }
    final exercise = _plan.exercises[_step - _plan.intro.length];
    void done(bool correct) => _advance(correct: correct);
    return switch (exercise) {
      ChoiceExercise e => ChoiceView(key: key, exercise: e, lesson: _lesson, onDone: done),
      BuildSentenceExercise e => BuildView(key: key, exercise: e, lesson: _lesson, onDone: done),
      MatchPairsExercise e => MatchView(key: key, exercise: e, lesson: _lesson, onDone: done),
      TypeExercise e => TypeView(key: key, exercise: e, lesson: _lesson, onDone: done),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _plan.steps == 0 || _finished
            ? null
            : TweenAnimationBuilder<double>(
                tween: Tween(end: _step / _plan.steps),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: value, minHeight: 10),
                ),
              ),
      ),
      body: SafeArea(
        child: _plan.exercises.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.lessonNeedsMorePhrases)))
            : _finished
                ? _Complete(correct: _correct, total: _plan.exercises.length)
                : _stepView(),
      ),
    );
  }
}

class _Complete extends StatelessWidget {
  const _Complete({required this.correct, required this.total});

  final int correct;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Icon(Icons.check_circle, size: 120, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(l10n.lessonComplete, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(l10n.lessonScore(correct, total)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.backToUnits),
            ),
          ],
        ),
      ),
    );
  }
}
