import 'package:flutter/material.dart';

import '../app.dart';
import '../audio/audio.dart';
import '../l10n/app_localizations.dart';
import '../packs/models.dart';
import 'lesson_screen.dart';

/// The units of one course, for a learner who speaks [sourceLanguage].
class CourseScreen extends StatelessWidget {
  const CourseScreen({
    super.key,
    required this.services,
    required this.course,
    required this.sourceLanguage,
  });

  final AppServices services;
  final CourseInfo course;
  final String sourceLanguage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(resolveLocalized(course.title, sourceLanguage)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.unitsHeading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final unit in course.units)
            _UnitCard(
              services: services,
              course: course,
              unit: unit,
              sourceLanguage: sourceLanguage,
            ),
        ],
      ),
    );
  }
}

class _UnitCard extends StatefulWidget {
  const _UnitCard({
    required this.services,
    required this.course,
    required this.unit,
    required this.sourceLanguage,
  });

  final AppServices services;
  final CourseInfo course;
  final UnitInfo unit;
  final String sourceLanguage;

  @override
  State<_UnitCard> createState() => _UnitCardState();
}

class _UnitCardState extends State<_UnitCard> {
  bool? _installed;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final installed = await widget.services.store.isInstalled(
      widget.course,
      widget.unit,
      widget.sourceLanguage,
    );
    // An install that finished while this check was running is newer than this result.
    if (mounted && _installed == null) setState(() => _installed = installed);
  }

  Future<void> _open() async {
    if (_busy) return;
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      if (_installed != true) {
        await widget.services.store.installUnit(
          source: widget.services.source,
          course: widget.course,
          unit: widget.unit,
          sourceLanguage: widget.sourceLanguage,
        );
      }
      final content = await widget.services.store.loadUnit(
        widget.course,
        widget.unit,
        widget.sourceLanguage,
      );
      if (!mounted) return;
      setState(() => _installed = true);
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => LessonScreen(
            sounds: widget.services.sounds,
            content: content,
            // Writing is too hard for tourist learners; later course kinds keep it.
            allowTyping: widget.course.kind != 'tourist',
            audio: LessonAudio(
              player: widget.services.audio,
              pathFor: (r) => widget.services.store.audioPath(
                widget.course,
                widget.unit,
                r,
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _failed
        ? l10n.loadError
        : _busy
        ? l10n.unitDownloading
        : _installed == true
        ? l10n.unitReady
        : l10n.unitNotDownloaded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resolveLocalized(
                          widget.unit.title,
                          widget.sourceLanguage,
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.unitPhraseCount(widget.unit.concepts)} · $status',
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
