/// How a language is shown to learners: its own name, and a flag.
///
/// A flag stands for a country, not a language, so the name always goes with it.
class LanguageInfo {
  const LanguageInfo(this.name, this.flag);

  final String name;
  final String flag;
}

const _languages = {
  'de': LanguageInfo('Deutsch', '🇩🇪'),
  'en': LanguageInfo('English', '🇬🇧'),
  'fr': LanguageInfo('Français', '🇫🇷'),
  'ja': LanguageInfo('日本語', '🇯🇵'),
  'sr': LanguageInfo('Srpski', '🇷🇸'),
  'sv': LanguageInfo('Svenska', '🇸🇪'),
  'ur': LanguageInfo('اردو', '🇵🇰'),
};

LanguageInfo languageInfo(String code) =>
    _languages[code] ?? LanguageInfo(code, '🏳️');
