import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'models.dart';
import 'pack_source.dart';

class PackIntegrityException implements Exception {
  PackIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'PackIntegrityException: $message';
}

/// Installs units on the device and reads them back for offline use.
///
/// Layout under [root]:
///
/// ```text
/// packs/COURSE/UNIT/target/           extracted unit zip (unit.json + audio)
/// packs/COURSE/UNIT/target.sha256     hash of the installed zip
/// packs/COURSE/UNIT/text.LANG.json    source-language text and glosses
/// packs/COURSE/UNIT/text.LANG.sha256  hash of the installed text file
/// ```
///
/// Every download is checked against the manifest's sha256 before anything is
/// written, and the target folder is swapped in as a whole, so a failed or
/// corrupted download never replaces a working install.
class PackStore {
  PackStore(this.root);

  final Directory root;

  Directory _unitDir(String course, String unit) =>
      Directory('${root.path}/packs/$course/$unit');

  String _lang(String language) => language.toLowerCase();

  /// True when the installed files are exactly the ones the manifest lists.
  Future<bool> isInstalled(
    CourseInfo course,
    UnitInfo unit,
    String sourceLanguage,
  ) async {
    final dir = _unitDir(course.id, unit.id);
    final textRef = unit.text[sourceLanguage];
    if (textRef == null) return false;
    return await _read(File('${dir.path}/target.sha256')) ==
            unit.target.sha256 &&
        await _read(File('${dir.path}/text.${_lang(sourceLanguage)}.sha256')) ==
            textRef.sha256 &&
        await File('${dir.path}/target/unit.json').exists() &&
        await File('${dir.path}/text.${_lang(sourceLanguage)}.json').exists();
  }

  Future<void> installUnit({
    required PackSource source,
    required CourseInfo course,
    required UnitInfo unit,
    required String sourceLanguage,
  }) async {
    final textRef = unit.text[sourceLanguage];
    if (textRef == null) {
      throw ArgumentError(
        '${course.id} has no "$sourceLanguage" text for ${unit.id}',
      );
    }
    final zipBytes = await source.fetch(unit.target.path);
    _verify(unit.target, zipBytes);
    final textBytes = await source.fetch(textRef.path);
    _verify(textRef, textBytes);

    final dir = _unitDir(course.id, unit.id);
    await dir.create(recursive: true);

    final staging = Directory('${dir.path}/target.staging');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create();
    for (final entry in ZipDecoder().decodeBytes(zipBytes)) {
      if (!entry.isFile) continue;
      if (_unsafe(entry.name)) {
        await staging.delete(recursive: true);
        throw PackIntegrityException('unsafe path in zip: ${entry.name}');
      }
      final file = File('${staging.path}/${entry.name}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.content);
    }
    if (!await File('${staging.path}/unit.json').exists()) {
      await staging.delete(recursive: true);
      throw PackIntegrityException('${unit.id}: zip has no unit.json');
    }

    final target = Directory('${dir.path}/target');
    final old = Directory('${dir.path}/target.old');
    if (await old.exists()) await old.delete(recursive: true);
    if (await target.exists()) await target.rename(old.path);
    await staging.rename(target.path);
    if (await old.exists()) await old.delete(recursive: true);
    await File('${dir.path}/target.sha256').writeAsString(unit.target.sha256);

    final lang = _lang(sourceLanguage);
    final tmp = File('${dir.path}/text.$lang.json.tmp');
    await tmp.writeAsBytes(textBytes);
    await tmp.rename('${dir.path}/text.$lang.json');
    await File('${dir.path}/text.$lang.sha256').writeAsString(textRef.sha256);
  }

  Future<UnitContent> loadUnit(
    CourseInfo course,
    UnitInfo unit,
    String sourceLanguage,
  ) async {
    final dir = _unitDir(course.id, unit.id);
    final pack = UnitPack.fromJson(
      jsonDecode(await File('${dir.path}/target/unit.json').readAsString())
          as Json,
    );
    final text = UnitText.fromJson(
      jsonDecode(
            await File(
              '${dir.path}/text.${_lang(sourceLanguage)}.json',
            ).readAsString(),
          )
          as Json,
    );
    return UnitContent(pack: pack, text: text);
  }

  /// Absolute path of an audio file of an installed unit.
  String audioPath(CourseInfo course, UnitInfo unit, Recording recording) =>
      '${_unitDir(course.id, unit.id).path}/target/${recording.file}';

  void _verify(FileRef ref, Uint8List bytes) {
    if (bytes.length != ref.size) {
      throw PackIntegrityException(
        '${ref.path}: ${bytes.length} bytes, expected ${ref.size}',
      );
    }
    if (sha256.convert(bytes).toString() != ref.sha256) {
      throw PackIntegrityException(
        '${ref.path}: checksum does not match the manifest',
      );
    }
  }

  bool _unsafe(String name) =>
      name.isEmpty ||
      name.startsWith('/') ||
      name.contains('\\') ||
      name.split('/').contains('..');

  Future<String?> _read(File file) async =>
      await file.exists() ? (await file.readAsString()).trim() : null;
}
