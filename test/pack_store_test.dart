import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:languages/packs/models.dart';
import 'package:languages/packs/pack_source.dart';
import 'package:languages/packs/pack_store.dart';

/// Returns the real pack, except [corrupt] paths come back with one byte flipped.
class _FlakySource implements PackSource {
  _FlakySource(this.inner, {this.corrupt = const {}});

  final PackSource inner;
  final Set<String> corrupt;

  @override
  Future<Uint8List> fetch(String relativePath) async {
    final bytes = Uint8List.fromList(await inner.fetch(relativePath));
    if (corrupt.contains(relativePath)) bytes[bytes.length ~/ 2] ^= 0xFF;
    return bytes;
  }
}

class _MemorySource implements PackSource {
  _MemorySource(this.files);

  final Map<String, Uint8List> files;

  @override
  Future<Uint8List> fetch(String relativePath) async => files[relativePath]!;
}

void main() {
  late Directory tmp;
  late PackSource source;
  late PackStore store;
  late Manifest manifest;
  late CourseInfo course;
  late UnitInfo unit;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pack_store_test');
    source = DirectoryPackSource(Directory('test/fixtures/placeholder_pack'));
    store = PackStore(tmp);
    manifest = await loadManifest(source);
    course = manifest.courses.first;
    unit = course.units.first;
  });

  tearDown(() => tmp.delete(recursive: true));

  test('manifest parses', () {
    expect(manifest.courses, hasLength(1));
    expect(course.id, 'tourist-sr');
    expect(course.targetLanguage, 'sr');
    expect(course.sources, ['en']);
    expect(course.units.map((u) => u.id), ['greetings-and-basics', 'food-and-getting-around']);
  });

  test('installs a unit and reads it back', () async {
    expect(await store.isInstalled(course, unit, 'en'), isFalse);
    await store.installUnit(source: source, course: course, unit: unit, sourceLanguage: 'en');
    expect(await store.isInstalled(course, unit, 'en'), isTrue);

    final content = await store.loadUnit(course, unit, 'en');
    expect(content.pack.phrases.map((p) => p.concept), contains('good-day'));
    expect(content.pack.lemmas.keys, contains('sr:dobar'));
    expect(content.text.glosses['sr:dobar']!.gloss, 'good');

    final good = content.pack.phrases.firstWhere((p) => p.concept == 'good-day');
    expect(pickScript(good.text, 'Latn'), 'Dobar dan');
    expect(pickScript(good.text, 'Cyrl'), 'Добар дан');
    expect(pickScript(content.sourceTextFor(good)!, 'Latn'), 'Good day');
  });

  test('a source entry without a variant applies to every variant', () async {
    await store.installUnit(source: source, course: course, unit: unit, sourceLanguage: 'en');
    final content = await store.loadUnit(course, unit, 'en');
    final tired = content.pack.phrases.where((p) => p.concept == 'i-am-tired').toList();
    expect(tired.map((p) => p.variant), ['m', 'f']);
    expect(tired.map((p) => pickScript(content.sourceTextFor(p)!, 'Latn')), ["I'm tired", "I'm tired"]);
  });

  test('a corrupted download is rejected', () async {
    final flaky = _FlakySource(source, corrupt: {unit.target.path});
    await expectLater(
      store.installUnit(source: flaky, course: course, unit: unit, sourceLanguage: 'en'),
      throwsA(isA<PackIntegrityException>()),
    );
    expect(await store.isInstalled(course, unit, 'en'), isFalse);
  });

  test('a failed update leaves the working install untouched', () async {
    await store.installUnit(source: source, course: course, unit: unit, sourceLanguage: 'en');
    final flaky = _FlakySource(source, corrupt: {unit.text['en']!.path});
    await expectLater(
      store.installUnit(source: flaky, course: course, unit: unit, sourceLanguage: 'en'),
      throwsA(isA<PackIntegrityException>()),
    );
    expect(await store.isInstalled(course, unit, 'en'), isTrue);
    expect((await store.loadUnit(course, unit, 'en')).pack.phrases, isNotEmpty);
  });

  test('a changed hash in the manifest makes the unit stale', () async {
    await store.installUnit(source: source, course: course, unit: unit, sourceLanguage: 'en');
    final updated = UnitInfo(
      id: unit.id,
      title: unit.title,
      concepts: unit.concepts,
      target: FileRef(path: unit.target.path, sha256: 'a' * 64, size: unit.target.size),
      text: unit.text,
    );
    expect(await store.isInstalled(course, updated, 'en'), isFalse);
  });

  test('a zip entry that escapes the unit folder is rejected', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('unit.json', Uint8List.fromList('{}'.codeUnits)))
      ..addFile(ArchiveFile.bytes('../evil.txt', Uint8List.fromList('x'.codeUnits)));
    final zip = Uint8List.fromList(ZipEncoder().encode(archive));
    final text = Uint8List.fromList('{}'.codeUnits);
    FileRef ref(String path, Uint8List bytes) =>
        FileRef(path: path, sha256: sha256.convert(bytes).toString(), size: bytes.length);

    final evil = UnitInfo(
      id: 'evil',
      title: const {'en': 'Evil'},
      concepts: 1,
      target: ref('evil.zip', zip),
      text: {'en': ref('evil.en.json', text)},
    );
    await expectLater(
      store.installUnit(
        source: _MemorySource({'evil.zip': zip, 'evil.en.json': text}),
        course: course,
        unit: evil,
        sourceLanguage: 'en',
      ),
      throwsA(isA<PackIntegrityException>()),
    );
    expect(File('${tmp.path}/packs/${course.id}/evil.txt').existsSync(), isFalse);
    expect(File('${tmp.path}/packs/${course.id}/evil/target/../evil.txt').existsSync(), isFalse);
  });
}
