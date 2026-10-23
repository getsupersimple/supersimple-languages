import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../app.dart';
import '../audio/audio.dart';
import '../packs/models.dart';
import '../packs/pack_source.dart';
import 'lesson_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Manifest> _manifest = loadManifest(widget.services.source);

  void _reload() => setState(() => _manifest = loadManifest(widget.services.source));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: FutureBuilder<Manifest>(
        future: _manifest,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.loadError),
                  const SizedBox(height: 12),
                  FilledButton.tonal(onPressed: _reload, child: Text(l10n.retry)),
                ],
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // One course for now. The FROM -> TO course picker comes later; the
          // source language defaults to the UI language when the course has it.
          final course = snapshot.data!.courses.first;
          final source = course.sources.contains(language) ? language : course.sources.first;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(resolveLocalized(course.title, language),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(l10n.unitsHeading, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final unit in course.units)
                _UnitCard(
                  services: widget.services,
                  course: course,
                  unit: unit,
                  sourceLanguage: source,
                ),
            ],
          );
        },
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
    final installed = await widget.services.store
        .isInstalled(widget.course, widget.unit, widget.sourceLanguage);
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
      final content = await widget.services.store
          .loadUnit(widget.course, widget.unit, widget.sourceLanguage);
      if (!mounted) return;
      setState(() => _installed = true);
      await navigator.push(MaterialPageRoute<void>(
        builder: (_) => LessonScreen(
          sounds: widget.services.sounds,
          content: content,
          audio: LessonAudio(
            player: widget.services.audio,
            pathFor: (r) => widget.services.store.audioPath(widget.course, widget.unit, r),
          ),
        ),
      ));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
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
                      Text(resolveLocalized(widget.unit.title, language),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('${l10n.unitPhraseCount(widget.unit.concepts)} · $status'),
                    ],
                  ),
                ),
                if (_busy)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
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
