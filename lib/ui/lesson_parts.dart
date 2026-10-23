import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../audio/sounds.dart';
import '../exercises/exercise.dart';
import '../l10n/app_localizations.dart';
import '../packs/models.dart';
import 'grammar.dart';

/// What every exercise view needs besides its own exercise.
class LessonContext {
  const LessonContext({
    required this.content,
    required this.audio,
    this.sounds = const SilentSoundPlayer(),
    required this.script,
  });

  final UnitContent content;
  final LessonAudio audio;
  final SoundPlayer sounds;
  final String script;
}

/// The bottom area shared by exercises: Check, then feedback and Continue.
class CheckBar extends StatelessWidget {
  const CheckBar({
    super.key,
    required this.canCheck,
    required this.checked,
    required this.correct,
    required this.correctAnswer,
    required this.onCheck,
    required this.onContinue,
  });

  final bool canCheck;
  final bool checked;
  final bool correct;
  final String? correctAnswer;
  final VoidCallback onCheck;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (!checked) {
      return FilledButton(onPressed: canCheck ? onCheck : null, child: Text(l10n.checkButton));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          correct ? l10n.correctFeedback : l10n.incorrectFeedback,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: correct ? scheme.primary : scheme.error,
                fontWeight: FontWeight.w800,
              ),
        ),
        if (!correct && correctAnswer != null) Text(l10n.correctAnswerWas(correctAnswer!)),
        const SizedBox(height: 12),
        FilledButton(onPressed: onContinue, child: Text(l10n.continueButton)),
      ],
    );
  }
}

/// A round speaker button. [onPressed] plays the clip.
class SpeakerButton extends StatelessWidget {
  const SpeakerButton({super.key, required this.onPressed, this.size = 56});

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      iconSize: size * 0.55,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      tooltip: AppLocalizations.of(context).playAudio,
      onPressed: onPressed,
      icon: const Icon(Icons.volume_up),
    );
  }
}

enum OptionState { idle, selected, right, wrong }

class OptionCard extends StatelessWidget {
  const OptionCard({super.key, required this.label, required this.state, required this.onTap});

  final String label;
  final OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (border, fill) = switch (state) {
      OptionState.idle => (scheme.outlineVariant, Colors.transparent),
      OptionState.selected => (scheme.primary, scheme.primaryContainer),
      OptionState.right => (scheme.primary, scheme.primaryContainer),
      OptionState.wrong => (scheme.error, scheme.errorContainer),
    };
    return Semantics(
      button: true,
      selected: state == OptionState.selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      ),
    );
  }
}

/// Calls [onStart] once, after the first frame (used to auto-play audio).
mixin AutoStart<T extends StatefulWidget> on State<T> {
  void onStart();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onStart();
    });
  }
}

/// Speaks a tile's word as written in the phrase ("sam"), not its dictionary
/// form ("biti"). Falls back to the lemma when the form has no recording.
void speakTile(LessonContext lesson, Tile tile, {String? voiceId}) {
  final audio = tile.audio.isNotEmpty ? tile.audio : lesson.content.pack.lemmas[tile.lemma]?.audio ?? const <Recording>[];
  lesson.audio.play(audio, voiceId: voiceId);
}

/// Bottom sheet describing a word: its dictionary form, meaning and grammar.
///
/// Only lemmas have standalone audio, so an inflected form ("kafu") opens this
/// sheet and plays the lemma's clip ("kafa") instead of being voiced itself.
Future<void> showLemmaSheet(
  BuildContext context, {
  required LessonContext lesson,
  required String lemmaId,
  required String form,
  required Map<String, dynamic> grammar,
  String? voiceId,
}) {
  final lemma = lesson.content.pack.lemmas[lemmaId];
  if (lemma == null) return Future.value();
  final gloss = lesson.content.text.glosses[lemmaId];
  final lemmaText = pickScript(lemma.text, lesson.script);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final textTheme = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(lemmaText, style: textTheme.headlineMedium)),
                  if (lemma.audio.isNotEmpty)
                    SpeakerButton(onPressed: () => lesson.audio.play(lemma.audio, voiceId: voiceId)),
                ],
              ),
              if (gloss != null) ...[
                const SizedBox(height: 4),
                Text(gloss.gloss, style: textTheme.titleMedium),
                if (gloss.note != null) Text(gloss.note!),
              ],
              const SizedBox(height: 12),
              if (form != lemmaText) Text(l10n.lemmaFormOf(form, lemmaText)),
              Text(describeGrammar(l10n, grammar), style: textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.closeButton),
              ),
            ],
          ),
        ),
      );
    },
  );
}
