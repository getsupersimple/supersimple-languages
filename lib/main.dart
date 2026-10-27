import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'audio/audio.dart';
import 'audio/sounds.dart';
import 'packs/pack_source.dart';
import 'packs/pack_store.dart';
import 'settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final support = await getApplicationSupportDirectory();
  final sounds = JustAudioSoundPlayer()..preload();
  runApp(
    SupersimpleApp(
      services: AppServices(
        // The bundled dev pack stands in for the download until the network source exists.
        source: AssetPackSource('assets/dev_pack'),
        store: PackStore(support),
        audio: JustAudioPlayerService(),
        sounds: sounds,
        settings: await AppSettings.load(File('${support.path}/settings.json')),
      ),
    ),
  );
}
