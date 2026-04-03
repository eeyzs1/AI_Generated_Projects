import 'dart:async';
import 'package:nobodywho/nobodywho.dart' as nobodywho;
import 'package:rfdictionary/features/llm/domain/llm_service.dart';

class NobodyWhoDataSource implements LlmDataSource {
  nobodywho.Chat? _chat;

  @override
  Future<void> loadModel(String modelPath) async {
    await nobodywho.NobodyWho.init();
    _chat = await nobodywho.Chat.fromPath(modelPath: modelPath);
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) async* {
    if (_chat == null) {
      throw StateError('Model not loaded');
    }

    final response = _chat!.ask(prompt);
    await for (final token in response) {
      yield token;
    }
  }

  @override
  Future<void> releaseContext() async {
    // nobodywho 不需要显式释放上下文
  }

  @override
  Future<void> restoreContext() async {
    // nobodywho 不需要显式恢复上下文
  }

  @override
  Future<void> dispose() async {
    _chat = null;
  }
}
