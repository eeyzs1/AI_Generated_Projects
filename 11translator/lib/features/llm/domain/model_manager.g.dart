part of 'model_manager.dart';

typedef ModelManagerRef = Ref;

abstract class _$ModelManager extends Notifier<ModelState> {
}

final modelManagerProvider = NotifierProvider<ModelManager, ModelState>(
  ModelManager.new,
  name: r'modelManager',
  dependencies: const [],
);
