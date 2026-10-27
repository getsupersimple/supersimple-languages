import 'dart:io';

import 'package:flutter/material.dart';
import 'package:languages/audio/audio.dart';
import 'package:languages/audio/sounds.dart';
import 'package:languages/l10n/app_localizations.dart';
import 'package:languages/packs/models.dart';
import 'package:languages/packs/pack_source.dart';
import 'package:languages/packs/pack_store.dart';

/// Records what would have been played.
class FakeAudioPlayer implements AudioPlayerService {
  final List<String> played = [];
  int stops = 0;

  @override
  Future<void> playFile(String path) async => played.add(path);

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async {}
}

/// Records the feedback sounds that would have been played.
class FakeSoundPlayer implements SoundPlayer {
  final List<Sound> played = [];

  @override
  Future<void> play(Sound sound) async => played.add(sound);

  @override
  Future<void> dispose() async {}
}

/// Installs the bundled dev pack into [tmp] and loads one unit.
Future<UnitContent> loadDevUnit(
  Directory tmp,
  String unitId, {
  String sourceLanguage = 'en',
}) async {
  final source = DirectoryPackSource(
    Directory('test/fixtures/placeholder_pack'),
  );
  final store = PackStore(tmp);
  final course = (await loadManifest(source)).courses.first;
  final unit = course.units.firstWhere((u) => u.id == unitId);
  await store.installUnit(
    source: source,
    course: course,
    unit: unit,
    sourceLanguage: sourceLanguage,
  );
  return store.loadUnit(course, unit, sourceLanguage);
}

/// Wraps [child] in a localized MaterialApp.
Widget testApp(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);
