import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'audio/audio.dart';
import 'packs/pack_source.dart';
import 'packs/pack_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  runApp(
    SupersimpleApp(
      services: AppServices(
        // The bundled dev pack stands in for the download until the network source exists.
        source: AssetPackSource('assets/dev_pack'),
        store: PackStore(support),
        audio: JustAudioPlayerService(),
      ),
    ),
  );
}
