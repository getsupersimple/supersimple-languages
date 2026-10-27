import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../audio/sounds.dart';
import '../exercises/exercise.dart';
import '../l10n/app_localizations.dart';
import '../packs/models.dart';
import 'grammar.dart';

/// Whether [texts] are written right to left (Arabic script, Hebrew), judged by
/// their first letters.
bool isRtlText(Iterable<String> texts) {
  final rtl = RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]');
  return texts.any(rtl.hasMatch);
}

/// What every exercise view needs besides its own exercise.
class LessonContext {
  LessonContext({
    required this.content,
    required this.audio,
    this.sounds = const SilentSoundPlayer(),
    required this.script,
  });

  final UnitContent content;
  final LessonAudio audio;
  final SoundPlayer sounds;
  final String script;

  /// Shown text -> romanised reading, for every text of the unit that has one
  /// (Japanese). Empty for languages written in the Latin script.
  late final Map<String, String> readings = _readingsOf(content, script);

  String? readingFor(String text) => readings[text];

  /// [text] with its reading in brackets, for places that take one string.
  String withReading(String text, [String? reading]) {
    final r = reading ?? readings[text];
    return r == null ? text : '$text ($r)';
  }

  /// A phrase's tiles as one string, reading included.
  String tilesWithReading(List<Tile> tiles) {
    final text = tiles.map((t) => t.text).join(' ');
    final readings = tiles.map((t) => readingFor(t.text));
    if (readings.every((r) => r == null)) return text;
    return withReading(
      text,
      [for (final t in tiles) readingFor(t.text) ?? t.text].join(' '),
    );
  }
}

Map<String, String> _readingsOf(UnitContent content, String script) {
  final out = <String, String>{};
  void add(Map<String, String> text) {
    final reading = readingOf(text);
    if (reading != null) out[pickScript(text, script)] = reading;
  }

  for (final p in content.pack.phrases) {
    add(p.text);
    for (final t in p.tokens) {
      add(t.surface);
    }
  }
  for (final l in content.pack.lemmas.values) {
    add(l.text);
    for (final f in l.forms) {
      add(f.text);
    }
  }
  for (final s in content.text.phrases) {
    add(s.text);
  }
  return out;
}

/// Text with its romanised reading underneath, when it has one (Japanese).
/// Plain [Text] otherwise.
class ScriptText extends StatelessWidget {
  const ScriptText(
    this.text, {
    super.key,
    required this.lesson,
    this.style,
    this.textKey,
  });

  final String text;
  final LessonContext lesson;
  final TextStyle? style;

  /// Key of the main text, for finding it in tests.
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final reading = lesson.readingFor(text);
    final base = style ?? DefaultTextStyle.of(context).style;
    final main = Text(text, key: textKey, style: style);
    if (reading == null) return main;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        main,
        Text(
          reading,
          style: base.copyWith(
            fontSize: (base.fontSize ?? 14) * 0.7,
            fontWeight: FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The bottom area shared by exercises: Check, then feedback and Continue.
///
/// When [onSkip] is set, Show answer sits beside Check and Try again, so the
/// learner can give up without attempting an answer.
class CheckBar extends StatelessWidget {
  const CheckBar({
    super.key,
    required this.canCheck,
    required this.checked,
    required this.correct,
    required this.correctAnswer,
    required this.onCheck,
    required this.onContinue,
    this.close = false,
    this.revealed = false,
    this.onRetry,
    this.onSkip,
  });

  final bool canCheck;
  final bool checked;
  final bool correct;
  final String? correctAnswer;
  final VoidCallback onCheck;
  final VoidCallback onContinue;

  /// A wrong answer that was nearly right.
  final bool close;

  /// The learner gave up and was shown the answer; not a failure to scold.
  final bool revealed;

  /// When both are set, a wrong answer offers another try or showing the answer
  /// instead of going straight to Continue.
  final VoidCallback? onRetry;
  final VoidCallback? onSkip;

  /// Show answer in the neutral colour, next to the accent button.
  Widget _withSkip(BuildContext context, Widget primary) {
    if (onSkip == null) return primary;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: onSkip,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.surface,
              foregroundColor: scheme.onSurface,
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: Text(AppLocalizations.of(context).showAnswerButton),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: primary),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (!checked) {
      return _withSkip(
        context,
        FilledButton(
          onPressed: canCheck ? onCheck : null,
          child: Text(l10n.checkButton),
        ),
      );
    }
    if (!correct && onRetry != null && onSkip != null) {
      return _FeedbackBackdrop(
        color: close ? scheme.tertiaryContainer : scheme.errorContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              close ? l10n.closeFeedback : l10n.incorrectFeedback,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: close ? scheme.tertiary : scheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _withSkip(
              context,
              FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
            ),
          ],
        ),
      );
    }
    final success = correct || revealed;
    return _FeedbackBackdrop(
      color: success ? scheme.primaryContainer : scheme.errorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            correct
                ? l10n.correctFeedback
                : revealed
                ? l10n.answerFeedback
                : l10n.incorrectFeedback,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: success ? scheme.primary : scheme.error,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!correct && correctAnswer != null)
            Text(l10n.correctAnswerWas(correctAnswer!)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onContinue, child: Text(l10n.continueButton)),
        ],
      ),
    );
  }
}

/// A tinted panel behind the feedback that reaches past the page padding to the
/// screen edges, and fades to transparent at its top.
class _FeedbackBackdrop extends StatelessWidget {
  const _FeedbackBackdrop({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The page's safe area sits between this and the screen's bottom edge.
    final below = MediaQuery.viewPaddingOf(context).bottom;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -16,
          right: -16,
          top: -48,
          bottom: -16 - below,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0), color],
                  stops: const [0, 0.3],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A round speaker button. [onPressed] plays the clip; the button shows sound
/// waves for a moment so the tap visibly did something.
class SpeakerButton extends StatefulWidget {
  const SpeakerButton({super.key, required this.onPressed, this.size = 56});

  final VoidCallback onPressed;
  final double size;

  @override
  State<SpeakerButton> createState() => _SpeakerButtonState();
}

class _SpeakerButtonState extends State<SpeakerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void dispose() {
    _playing.dispose();
    super.dispose();
  }

  void _press() {
    widget.onPressed();
    if (!MediaQuery.of(context).disableAnimations) _playing.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final size = widget.size;
    return AnimatedBuilder(
      animation: _playing,
      builder: (context, child) {
        final t = _playing.value;
        final running = _playing.isAnimating;
        // Two rings spread out and fade, one after the other.
        final rings = <Widget>[
          if (running)
            for (final lag in const [0.0, 0.5])
              () {
                final phase = ((t * 2 + lag) % 1.0);
                final fade = 1 - Curves.easeIn.transform(t);
                return IgnorePointer(
                  child: Transform.scale(
                    scale: 1 + 0.45 * Curves.easeOut.transform(phase),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(
                            alpha: 0.45 * (1 - phase) * fade,
                          ),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                );
              }(),
        ];
        // The cone's waves build up and repeat while the rings spread.
        final waves = running
            ? const [
                Icons.volume_mute,
                Icons.volume_down,
                Icons.volume_up,
              ][(t * 9).floor() % 3]
            : Icons.volume_up;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            ...rings,
            Transform.scale(
              scale: running ? 1 + 0.06 * (1 - (t * 6 % 1)) : 1,
              child: IconButton.filledTonal(
                iconSize: size * 0.55,
                constraints: BoxConstraints.tightFor(width: size, height: size),
                tooltip: AppLocalizations.of(context).playAudio,
                onPressed: _press,
                icon: Icon(waves),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum OptionState { idle, selected, right, wrong }

class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.lesson,
  });

  final String label;

  /// Adds the reading under [label] where it has one (Japanese).
  final LessonContext? lesson;
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: lesson == null
                  ? Text(label, style: Theme.of(context).textTheme.titleMedium)
                  : ScriptText(
                      label,
                      lesson: lesson!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Starts speech a moment after the correct-answer chime, and cancels it if the
/// learner leaves the step first.
mixin ChimeLead<T extends StatefulWidget> on State<T> {
  Timer? _speech;

  void speakAfterChime(VoidCallback speak) {
    _speech?.cancel();
    _speech = Timer(chimeLead, speak);
  }

  @override
  void dispose() {
    _speech?.cancel();
    super.dispose();
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
  final audio = tile.audio.isNotEmpty
      ? tile.audio
      : lesson.content.pack.lemmas[tile.lemma]?.audio ?? const <Recording>[];
  lesson.audio.play(audio, voiceId: voiceId);
}

/// Bottom sheet describing a word: its dictionary form, meaning and grammar.
///
/// The speaker plays the dictionary form's clip ("kafa"); tapping a tile plays
/// the form as written ("kafu") through [speakTile].
Future<void> showLemmaSheet(
  BuildContext context, {
  required LessonContext lesson,
  required String lemmaId,
  required String form,
  required Map<String, dynamic> grammar,
  String? voiceId,
}) {
  if (lesson.content.pack.lemmas[lemmaId] == null) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: LemmaDetails(
        lesson: lesson,
        lemmaId: lemmaId,
        form: form,
        grammar: grammar,
        voiceId: voiceId,
        onClose: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

/// A card describing a word, shown over the page for as long as the learner
/// holds it. An overlay rather than a route, because pushing a route cancels
/// the finger's touch and the card could not know when it lifts. Returns null
/// when the word has no lemma entry; call `hide()` on the result to dismiss it.
///
/// The card slides up from the bottom, rises a touch too far and settles back,
/// and slides away again when hidden. Its speaker can be tapped with a second
/// finger.
LemmaPeek? showLemmaPeek(
  BuildContext context, {
  required LessonContext lesson,
  required String lemmaId,
  required String form,
  required Map<String, dynamic> grammar,
  String? voiceId,
}) {
  if (lesson.content.pack.lemmas[lemmaId] == null) return null;
  final key = GlobalKey<_PeekCardState>();
  final entry = OverlayEntry(
    builder: (context) => Align(
      alignment: Alignment.bottomCenter,
      child: _PeekCard(
        key: key,
        child: LemmaDetails(
          lesson: lesson,
          lemmaId: lemmaId,
          form: form,
          grammar: grammar,
          voiceId: voiceId,
        ),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  return LemmaPeek._(entry, key);
}

/// Handle on a card shown by [showLemmaPeek].
class LemmaPeek {
  LemmaPeek._(this._entry, this._card);

  final OverlayEntry _entry;
  final GlobalKey<_PeekCardState> _card;
  bool _gone = false;

  /// Slides the card away, or removes it at once with [immediately].
  void hide({bool immediately = false}) {
    if (_gone) return;
    final card = _card.currentState;
    if (immediately || card == null) {
      _remove();
    } else {
      _gone = true;
      card.slideOut(() {
        _gone = false;
        _remove();
      });
    }
  }

  void _remove() {
    if (_gone) return;
    _gone = true;
    _entry.remove();
    _entry.dispose();
  }
}

class _PeekCard extends StatefulWidget {
  const _PeekCard({super.key, required this.child});

  final Widget child;

  @override
  State<_PeekCard> createState() => _PeekCardState();
}

class _PeekCardState extends State<_PeekCard>
    with SingleTickerProviderStateMixin {
  /// Height shares: in from below, a little past the resting place, then back.
  static final _enter = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: -0.025,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 72,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -0.025,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 28,
    ),
  ]);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  )..forward();

  bool _leaving = false;
  double _leaveFrom = 0;

  double get _offset {
    if (!_leaving) return _enter.transform(_controller.value);
    final t = Curves.easeInCubic.transform(_controller.value);
    return _leaveFrom + (1.1 - _leaveFrom) * t;
  }

  void slideOut(VoidCallback done) {
    if (_leaving) return;
    _leaveFrom = _offset;
    _leaving = true;
    _controller.duration = const Duration(milliseconds: 220);
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) done();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          FractionalTranslation(translation: Offset(0, _offset), child: child),
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: SizedBox(width: double.infinity, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// The body of the word explanation: the dictionary form with its speaker,
/// the meaning, and the grammar. [onClose] adds a Close button.
class LemmaDetails extends StatelessWidget {
  const LemmaDetails({
    super.key,
    required this.lesson,
    required this.lemmaId,
    required this.form,
    required this.grammar,
    this.voiceId,
    this.onClose,
  });

  final LessonContext lesson;
  final String lemmaId;
  final String form;
  final Map<String, dynamic> grammar;
  final String? voiceId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final lemma = lesson.content.pack.lemmas[lemmaId];
    if (lemma == null) return const SizedBox.shrink();
    final gloss = lesson.content.text.glosses[lemmaId];
    final lemmaText = pickScript(lemma.text, lesson.script);
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ScriptText(
                  lemmaText,
                  lesson: lesson,
                  style: textTheme.headlineMedium,
                ),
              ),
              if (lemma.audio.isNotEmpty)
                SpeakerButton(
                  onPressed: () =>
                      lesson.audio.play(lemma.audio, voiceId: voiceId),
                ),
            ],
          ),
          if (gloss != null) ...[
            const SizedBox(height: 4),
            Text(gloss.gloss, style: textTheme.titleMedium),
            if (gloss.note != null) Text(gloss.note!),
          ],
          const SizedBox(height: 12),
          if (form != lemmaText)
            Text(
              l10n.lemmaFormOf(
                lesson.withReading(form),
                lesson.withReading(lemmaText),
              ),
            ),
          Text(describeGrammar(l10n, grammar), style: textTheme.bodyMedium),
          if (onClose != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onClose,
              child: Text(l10n.closeButton),
            ),
          ],
        ],
      ),
    );
  }
}
