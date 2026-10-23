import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'models.dart';

/// Where pack files come from. [relativePath] is a path from the manifest
/// ("manifest.json", "courses/tourist-sr/greetings.zip").
///
/// Implementations: [AssetPackSource] (bundled dev pack) and
/// [DirectoryPackSource] (a built dist folder, used by tests). The network
/// source (GitHub Releases / R2 behind one base URL) comes next.
abstract class PackSource {
  Future<Uint8List> fetch(String relativePath);
}

class AssetPackSource implements PackSource {
  AssetPackSource(this.prefix, {AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final String prefix;
  final AssetBundle _bundle;

  @override
  Future<Uint8List> fetch(String relativePath) async {
    final data = await _bundle.load('$prefix/$relativePath');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

class DirectoryPackSource implements PackSource {
  DirectoryPackSource(this.root);

  final Directory root;

  @override
  Future<Uint8List> fetch(String relativePath) =>
      File('${root.path}/$relativePath').readAsBytes();
}

Future<Manifest> loadManifest(PackSource source) async {
  final bytes = await source.fetch('manifest.json');
  return Manifest.fromJson(jsonDecode(utf8.decode(bytes)) as Json);
}
