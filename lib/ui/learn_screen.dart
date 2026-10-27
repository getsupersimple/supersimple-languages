import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/app_localizations.dart';
import '../packs/models.dart';
import '../settings/settings.dart';
import 'course_screen.dart';
import 'languages.dart';

/// The first screen: a flag for every language the learner can study from their own.
class LearnScreen extends StatelessWidget {
  const LearnScreen({
    super.key,
    required this.services,
    required this.manifest,
  });

  final AppServices services;
  final Manifest manifest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uiLanguage = Localizations.localeOf(context).languageCode;
    return ListenableBuilder(
      listenable: services.settings,
      builder: (context, _) {
        final source = resolveSourceLanguage(
          services.settings.sourceLanguage,
          manifest.sourceLanguages,
          uiLanguage,
        );
        final courses = [
          for (final c in manifest.courses)
            if (c.sources.contains(source)) c,
        ];
        return Scaffold(
          appBar: AppBar(title: Text(l10n.appTitle)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.learnHeading,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(l10n.learnFilterNote(languageInfo(source).name)),
              const SizedBox(height: 16),
              if (courses.isEmpty)
                Text(l10n.noCourses)
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final course in courses)
                      _LanguageCard(
                        course: course,
                        sourceLanguage: source,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CourseScreen(
                              services: services,
                              course: course,
                              sourceLanguage: source,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.course,
    required this.sourceLanguage,
    required this.onTap,
  });

  final CourseInfo course;
  final String sourceLanguage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = languageInfo(course.targetLanguage);
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(
              children: [
                Text(info.flag, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(
                  info.name,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Always two lines tall, so every card is the same height
                // however long the title is and however large the text scale.
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Visibility(
                      visible: false,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Text(
                        '\n',
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                      ),
                    ),
                    Text(
                      resolveLocalized(course.title, sourceLanguage),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
