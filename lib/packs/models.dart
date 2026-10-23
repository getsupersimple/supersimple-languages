/// Dart mirrors of the built pack files. The JSON Schemas in the content repo
/// (manifest, unit-pack, unit-text) are the contract; keep these in step.
library;

typedef Json = Map<String, dynamic>;

Map<String, String> _strings(Object? value) =>
    (value as Map).map((k, v) => MapEntry(k as String, v as String));

/// Picks [preferred] if present, otherwise any available script.
String pickScript(Map<String, String> text, String preferred) =>
    text[preferred] ?? text.values.first;

/// Picks the learner's language, falling back to English, then anything.
String resolveLocalized(Map<String, String> text, String language) =>
    text[language] ?? text['en'] ?? text.values.first;

class FileRef {
  const FileRef({required this.path, required this.sha256, required this.size});

  factory FileRef.fromJson(Json json) => FileRef(
        path: json['path'] as String,
        sha256: json['sha256'] as String,
        size: json['size'] as int,
      );

  final String path;
  final String sha256;
  final int size;
}

class UnitInfo {
  const UnitInfo({
    required this.id,
    required this.title,
    required this.concepts,
    required this.target,
    required this.text,
  });

  factory UnitInfo.fromJson(Json json) => UnitInfo(
        id: json['id'] as String,
        title: _strings(json['title']),
        concepts: json['concepts'] as int,
        target: FileRef.fromJson(json['target'] as Json),
        text: (json['text'] as Map).map(
          (k, v) => MapEntry(k as String, FileRef.fromJson(v as Json)),
        ),
      );

  final String id;
  final Map<String, String> title;
  final int concepts;
  final FileRef target;
  final Map<String, FileRef> text;
}

class CourseInfo {
  const CourseInfo({
    required this.id,
    required this.version,
    required this.minAppVersion,
    required this.kind,
    required this.targetLanguage,
    required this.title,
    required this.sources,
    required this.units,
  });

  factory CourseInfo.fromJson(Json json) => CourseInfo(
        id: json['id'] as String,
        version: json['version'] as String,
        minAppVersion: json['min_app_version'] as String,
        kind: json['kind'] as String,
        targetLanguage: json['target_language'] as String,
        title: _strings(json['title']),
        sources: (json['sources'] as List).cast<String>(),
        units: (json['units'] as List)
            .map((u) => UnitInfo.fromJson(u as Json))
            .toList(),
      );

  final String id;

  /// Pack version, independent of the app version.
  final String version;

  /// Oldest app that can run this course.
  final String minAppVersion;
  final String kind;
  final String targetLanguage;
  final Map<String, String> title;
  final List<String> sources;
  final List<UnitInfo> units;
}

class Manifest {
  const Manifest({
    required this.contentVersion,
    required this.channel,
    required this.minAppVersion,
    required this.courses,
  });

  factory Manifest.fromJson(Json json) {
    if (json['schema_version'] != 1) {
      throw FormatException('Unsupported manifest schema ${json['schema_version']}');
    }
    return Manifest(
      contentVersion: json['content_version'] as String,
      channel: json['channel'] as String,
      minAppVersion: json['min_app_version'] as String,
      courses: (json['courses'] as List)
          .map((c) => CourseInfo.fromJson(c as Json))
          .toList(),
    );
  }

  final String contentVersion;
  final String channel;
  final String minAppVersion;
  final List<CourseInfo> courses;

  /// Every language some course can be learned from, sorted.
  List<String> get sourceLanguages => ({for (final c in courses) ...c.sources}).toList()..sort();
}

class Recording {
  const Recording({
    required this.id,
    required this.file,
    required this.sha256,
    required this.durationMs,
    required this.voiceId,
    required this.gender,
  });

  factory Recording.fromJson(Json json) => Recording(
        id: json['id'] as String,
        file: json['file'] as String,
        sha256: json['sha256'] as String,
        durationMs: json['duration_ms'] as int,
        voiceId: (json['voice'] as Json)['voice_id'] as String,
        gender: (json['voice'] as Json)['gender'] as String,
      );

  final String id;
  final String file;
  final String sha256;
  final int durationMs;
  final String voiceId;
  final String gender;
}

class Token {
  const Token({required this.surface, required this.lemma, required this.grammar});

  factory Token.fromJson(Json json) => Token(
        surface: _strings(json['surface']),
        lemma: json['lemma'] as String,
        grammar: (json['grammar'] as Map).cast<String, dynamic>(),
      );

  final Map<String, String> surface;
  final String lemma;
  final Map<String, dynamic> grammar;
}

class TargetPhrase {
  const TargetPhrase({
    required this.concept,
    required this.variant,
    required this.text,
    required this.tokens,
    required this.audio,
  });

  factory TargetPhrase.fromJson(Json json) => TargetPhrase(
        concept: json['concept'] as String,
        variant: json['variant'] as String?,
        text: _strings(json['text']),
        tokens: (json['tokens'] as List).map((t) => Token.fromJson(t as Json)).toList(),
        audio: (json['audio'] as List).map((r) => Recording.fromJson(r as Json)).toList(),
      );

  final String concept;
  final String? variant;
  final Map<String, String> text;
  final List<Token> tokens;
  final List<Recording> audio;
}

/// An inflected form of a lemma that has its own recording ("sam" of "biti").
class LemmaForm {
  const LemmaForm({required this.text, required this.audio});

  factory LemmaForm.fromJson(Json json) => LemmaForm(
        text: _strings(json['text']),
        audio: (json['audio'] as List).map((r) => Recording.fromJson(r as Json)).toList(),
      );

  final Map<String, String> text;
  final List<Recording> audio;
}

class Lemma {
  const Lemma({
    required this.id,
    required this.text,
    required this.pos,
    required this.audio,
    this.forms = const [],
  });

  factory Lemma.fromJson(Json json) => Lemma(
        id: json['id'] as String,
        text: _strings(json['text']),
        pos: json['pos'] as String,
        audio: (json['audio'] as List).map((r) => Recording.fromJson(r as Json)).toList(),
        forms: [for (final f in (json['forms'] as List? ?? const [])) LemmaForm.fromJson(f as Json)],
      );

  final String id;
  final Map<String, String> text;
  final String pos;
  final List<Recording> audio;
  final List<LemmaForm> forms;

  /// The recordings of a word spelled [surface] as it appears in a phrase: the
  /// lemma's own for the dictionary form, the form's otherwise. Falls back to
  /// the lemma's audio when that form has none.
  List<Recording> audioFor(Map<String, String> surface) {
    if (_sameWord(text, surface)) return audio;
    for (final form in forms) {
      if (_sameWord(form.text, surface) && form.audio.isNotEmpty) return form.audio;
    }
    return audio;
  }
}

bool _sameWord(Map<String, String> a, Map<String, String> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key]?.toLowerCase() == e.value.toLowerCase());

class UnitPack {
  const UnitPack({
    required this.course,
    required this.unitId,
    required this.targetLanguage,
    required this.phrases,
    required this.lemmas,
  });

  factory UnitPack.fromJson(Json json) {
    if (json['schema_version'] != 1) {
      throw FormatException('Unsupported unit schema ${json['schema_version']}');
    }
    return UnitPack(
      course: json['course'] as String,
      unitId: (json['unit'] as Json)['id'] as String,
      targetLanguage: json['target_language'] as String,
      phrases: (json['phrases'] as List)
          .map((p) => TargetPhrase.fromJson(p as Json))
          .toList(),
      lemmas: {
        for (final l in json['lemmas'] as List)
          (l as Json)['id'] as String: Lemma.fromJson(l),
      },
    );
  }

  final String course;
  final String unitId;
  final String targetLanguage;
  final List<TargetPhrase> phrases;
  final Map<String, Lemma> lemmas;
}

class SourcePhrase {
  const SourcePhrase({required this.concept, required this.variant, required this.text});

  factory SourcePhrase.fromJson(Json json) => SourcePhrase(
        concept: json['concept'] as String,
        variant: json['variant'] as String?,
        text: _strings(json['text']),
      );

  final String concept;
  final String? variant;
  final Map<String, String> text;
}

class Gloss {
  const Gloss({required this.lemma, required this.gloss, this.note});

  factory Gloss.fromJson(Json json) => Gloss(
        lemma: json['lemma'] as String,
        gloss: json['gloss'] as String,
        note: json['note'] as String?,
      );

  final String lemma;
  final String gloss;
  final String? note;
}

/// The source-language side of one unit (what the learner reads in their language).
class UnitText {
  const UnitText({required this.language, required this.phrases, required this.glosses});

  factory UnitText.fromJson(Json json) {
    if (json['schema_version'] != 1) {
      throw FormatException('Unsupported unit text schema ${json['schema_version']}');
    }
    return UnitText(
      language: json['language'] as String,
      phrases: (json['phrases'] as List)
          .map((p) => SourcePhrase.fromJson(p as Json))
          .toList(),
      glosses: {
        for (final g in json['glosses'] as List)
          (g as Json)['lemma'] as String: Gloss.fromJson(g),
      },
    );
  }

  final String language;
  final List<SourcePhrase> phrases;
  final Map<String, Gloss> glosses;
}

/// A unit ready to use: target side plus the learner's source language.
class UnitContent {
  const UnitContent({required this.pack, required this.text});

  final UnitPack pack;
  final UnitText text;

  /// The source text for [phrase]. An entry for the exact variant wins; an
  /// entry without a variant applies to all variants.
  Map<String, String>? sourceTextFor(TargetPhrase phrase) {
    SourcePhrase? fallback;
    for (final s in text.phrases) {
      if (s.concept != phrase.concept) continue;
      if (s.variant == phrase.variant) return s.text;
      if (s.variant == null) fallback = s;
    }
    return fallback?.text;
  }
}
