import 'package:collection/collection.dart';

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

  WordEntry copyWith({
    String? word,
    String? phonetic,
    List<Definition>? definitions,
    List<ExampleSentence>? examples,
    Map<String, String>? exchanges,
  }) {
    return WordEntry(
      word: word ?? this.word,
      phonetic: phonetic ?? this.phonetic,
      definitions: definitions ?? this.definitions,
      examples: examples ?? this.examples,
      exchanges: exchanges ?? this.exchanges,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WordEntry &&
        other.word == word &&
        other.phonetic == phonetic &&
        const DeepCollectionEquality().equals(other.definitions, definitions) &&
        const DeepCollectionEquality().equals(other.examples, examples) &&
        const DeepCollectionEquality().equals(other.exchanges, exchanges);
  }

  @override
  int get hashCode => Object.hash(
        word,
        phonetic,
        Object.hashAll(definitions),
        Object.hashAll(examples),
        Object.hashAll(exchanges.values),
      );
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

  Definition copyWith({
    String? partOfSpeech,
    String? chinese,
    String? english,
  }) {
    return Definition(
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      chinese: chinese ?? this.chinese,
      english: english ?? this.english,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Definition &&
        other.partOfSpeech == partOfSpeech &&
        other.chinese == chinese &&
        other.english == english;
  }

  @override
  int get hashCode => Object.hash(partOfSpeech, chinese, english);
}

class ExampleSentence {
  final String english;
  final String? chinese;

  const ExampleSentence({required this.english, this.chinese});

  ExampleSentence copyWith({
    String? english,
    String? chinese,
  }) {
    return ExampleSentence(
      english: english ?? this.english,
      chinese: chinese ?? this.chinese,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExampleSentence &&
        other.english == english &&
        other.chinese == chinese;
  }

  @override
  int get hashCode => Object.hash(english, chinese);
}
