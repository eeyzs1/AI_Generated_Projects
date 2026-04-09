part of 'dictionary_manager.dart';

typedef DictionaryManagerRef = Ref;

abstract class _$DictionaryManager extends Notifier<DictionaryState> {
}

final dictionaryManagerProvider = NotifierProvider<DictionaryManager, DictionaryState>(
  DictionaryManager.new,
  name: r'dictionaryManager',
  dependencies: const [],
);
