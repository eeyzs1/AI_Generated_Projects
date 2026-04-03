import 'dart:async';
import 'package:llama_cpp/llama_cpp.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';

class LlamaCppDataSource implements LlmDataSource {
  LlamaCpp? _llama;

  @override
  Future<void> loadModel(String modelPath) async {
    _llama = await LlamaCpp.load(modelPath, verbose: true);
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) async* {
    if (_llama == null) {
      throw StateError('Model not loaded');
    }

    await for (final text in _llama!.answer(prompt)) {
      yield text;
    }
  }

  @override
  Future<void> releaseContext() async {
    // llama_cpp 目前不需要显式释放上下文
  }

  @override
  Future<void> restoreContext() async {
    // llama_cpp 目前不需要显式恢复上下文
  }

  @override
  Future<void> dispose() async {
    await _llama?.dispose();
    _llama = null;
  }
}
