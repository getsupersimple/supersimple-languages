import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/app_localizations.dart';
import '../packs/models.dart';
import '../packs/pack_source.dart';
import 'learn_screen.dart';
import 'settings_screen.dart';

/// The app's shell: loads the catalog once and shows the Learn and Settings tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Manifest> _manifest = loadManifest(widget.services.source);
  int _tab = 0;

  void _reload() => setState(() => _manifest = loadManifest(widget.services.source));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<Manifest>(
      future: _manifest,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.appTitle)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.loadError),
                  const SizedBox(height: 12),
                  FilledButton.tonal(onPressed: _reload, child: Text(l10n.retry)),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.appTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final manifest = snapshot.data!;
        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              LearnScreen(services: widget.services, manifest: manifest),
              SettingsScreen(services: widget.services, manifest: manifest),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(icon: const Icon(Icons.school_outlined), selectedIcon: const Icon(Icons.school), label: l10n.tabLearn),
              NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: l10n.tabSettings),
            ],
          ),
        );
      },
    );
  }
}
