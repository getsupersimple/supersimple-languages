/// How a language is shown to learners: its own name, and a flag.
///
/// A flag stands for a country, not a language, so the name always goes with it.
class LanguageInfo {
  const LanguageInfo(this.name, this.flag);

  final String name;
  final String flag;
}

const _languages = {
  'en': LanguageInfo('English', '🇬🇧'),
  'fr': LanguageInfo('Français', '🇫🇷'),
  'sr': LanguageInfo('Srpski', '🇷🇸'),
};

LanguageInfo languageInfo(String code) => _languages[code] ?? LanguageInfo(code, '🏳️');
