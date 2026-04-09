import 'dart:async';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';

class LlamaCppDataSource implements LlmDataSource {
  @override
  Future<void> loadModel(String modelPath) async {
    throw UnsupportedError(
      'llama_cpp package is not installed. '
      'Add it to pubspec.yaml to use this datasource.',
    );
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) async* {
    throw UnsupportedError(
      'llama_cpp package is not installed. '
      'Add it to pubspec.yaml to use this datasource.',
    );
  }

  @override
  Future<void> releaseContext() async {}

  @override
  Future<void> restoreContext() async {}

  @override
  Future<void> dispose() async {}
}
