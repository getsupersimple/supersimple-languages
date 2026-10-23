import 'package:flutter/material.dart';
import 'audio/audio.dart';
import 'audio/sounds.dart';
import 'l10n/app_localizations.dart';
import 'packs/pack_source.dart';
import 'packs/pack_store.dart';
import 'theme/app_theme.dart';
import 'ui/home_screen.dart';

/// Dependencies the screens need. Passed down explicitly so tests can swap them.
class AppServices {
  const AppServices({
    required this.source,
    required this.store,
    required this.audio,
    this.sounds = const SilentSoundPlayer(),
  });

  final PackSource source;
  final PackStore store;
  final AudioPlayerService audio;
  final SoundPlayer sounds;
}

class SupersimpleApp extends StatelessWidget {
  const SupersimpleApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // No locale set: the UI follows the system language. A settings override comes later.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(services: services),
    );
  }
}
