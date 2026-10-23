import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Learner preferences kept on the device. Backed by a small JSON file; with no
/// file (tests) the values live in memory only.
class AppSettings extends ChangeNotifier {
  AppSettings({this.file, String? initialSourceLanguage}) : _sourceLanguage = initialSourceLanguage;

  /// Reads [file] if it exists. A missing or unreadable file means defaults.
  static Future<AppSettings> load(File file) async {
    String? source;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      source = json['source_language'] as String?;
    } catch (_) {}
    return AppSettings(file: file, initialSourceLanguage: source);
  }

  /// Where the settings are saved; null keeps them in memory only.
  final File? file;
  String? _sourceLanguage;

  /// The language the learner speaks (the FROM side of a course), or null until
  /// they choose one; the app then follows the system language.
  String? get sourceLanguage => _sourceLanguage;

  Future<void> setSourceLanguage(String language) async {
    if (language == _sourceLanguage) return;
    _sourceLanguage = language;
    notifyListeners();
    final target = file;
    if (target != null) {
      await target.writeAsString(jsonEncode({'source_language': language}));
    }
  }
}

/// The source language to use: the learner's choice if a course supports it,
/// else the UI language if one does, else English, else any.
String resolveSourceLanguage(String? chosen, Iterable<String> available, String uiLanguage) {
  final options = available.toList();
  for (final candidate in [chosen, uiLanguage, 'en']) {
    if (candidate != null && options.contains(candidate)) return candidate;
  }
  return options.isEmpty ? 'en' : options.first;
}
