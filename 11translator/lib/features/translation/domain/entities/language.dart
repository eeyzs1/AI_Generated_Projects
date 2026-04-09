enum Language {
  english,
  chinese,
  japanese,
  korean,
  french,
  german,
  spanish,
  russian,
}

extension LanguageExtension on Language {
  String get displayName {
    return switch (this) {
      Language.english => 'English',
      Language.chinese => '中文',
      Language.japanese => '日本語',
      Language.korean => '한국어',
      Language.french => 'Français',
      Language.german => 'Deutsch',
      Language.spanish => 'Español',
      Language.russian => 'Русский',
    };
  }

  String get code {
    return switch (this) {
      Language.english => 'en',
      Language.chinese => 'zh',
      Language.japanese => 'ja',
      Language.korean => 'ko',
      Language.french => 'fr',
      Language.german => 'de',
      Language.spanish => 'es',
      Language.russian => 'ru',
    };
  }

  String get nativeName => displayName;
}
