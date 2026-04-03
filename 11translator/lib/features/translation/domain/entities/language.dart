enum Language {
  english,
  chinese,
}

extension LanguageExtension on Language {
  String get displayName {
    return switch (this) {
      Language.english => 'English',
      Language.chinese => '中文',
    };
  }

  String get code {
    return switch (this) {
      Language.english => 'en',
      Language.chinese => 'zh',
    };
  }
}
