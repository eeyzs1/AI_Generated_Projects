import 'dart:async';
import 'package:llamafu/llamafu.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';

class LlamafuDataSource implements LlmDataSource {
  Llamafu? _llamafu;

  @override
  Future<void> loadModel(String modelPath) async {
    _llamafu = await Llamafu.init(
      modelPath: modelPath,
      threads: 4,
      contextSize: 2048,
    );
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) async* {
    if (_llamafu == null) {
      throw StateError('Model not loaded');
    }

    final effectiveParams = params ?? InferenceParams.defaults;

    final result = await _llamafu!.complete(
      prompt: prompt,
      maxTokens: effectiveParams.maxTokens,
      temperature: effectiveParams.temperature,
      topK: effectiveParams.topK,
      repeatPenalty: effectiveParams.repeatPenalty,
    );

    yield result;
  }

  @override
  Future<void> releaseContext() async {
    // llamafu 目前不需要显式释放上下文
  }

  @override
  Future<void> restoreContext() async {
    // llamafu 目前不需要显式恢复上下文
  }

  @override
  Future<void> dispose() async {
    _llamafu?.close();
    _llamafu = null;
  }
}
