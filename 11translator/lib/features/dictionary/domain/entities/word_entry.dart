class WordEntry {
  final String word;
  final String? phonetic;
  final List<Definition> definitions;
  final List<ExampleSentence> examples;
  final Map<String, String> exchanges;

  const WordEntry({
    required this.word,
    this.phonetic,
    required this.definitions,
    required this.examples,
    required this.exchanges,
  });
}

class Definition {
  final String partOfSpeech;
  final String chinese;
  final String? english;

  const Definition({
    required this.partOfSpeech,
    required this.chinese,
    this.english,
  });
}

class ExampleSentence {
  final String english;
  final String? chinese;

  const ExampleSentence({required this.english, this.chinese});
}
