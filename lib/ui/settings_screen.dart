import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/app_localizations.dart';
import '../packs/models.dart';
import '../settings/settings.dart';
import 'languages.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
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
        final selected = resolveSourceLanguage(
          services.settings.sourceLanguage,
          manifest.sourceLanguages,
          uiLanguage,
        );
        return Scaffold(
          appBar: AppBar(title: Text(l10n.tabSettings)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.sourceLanguageHeading,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(l10n.sourceLanguageHelp),
              const SizedBox(height: 12),
              // A dropdown: there will be many languages. The field is not editable, so a tap
              // opens the whole list (a text filter would start out filtered to the current choice).
              DropdownMenu<String>(
                key: ValueKey(selected),
                width: MediaQuery.sizeOf(context).width - 32,
                initialSelection: selected,
                requestFocusOnTap: false,
                leadingIcon: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    languageInfo(selected).flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                dropdownMenuEntries: [
                  for (final code in manifest.sourceLanguages)
                    DropdownMenuEntry(
                      value: code,
                      label: languageInfo(code).name,
                      leadingIcon: Text(
                        languageInfo(code).flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                ],
                onSelected: (value) {
                  if (value != null) services.settings.setSourceLanguage(value);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
