import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rfdictionary/features/llm/data/datasources/python_llm_datasource.dart';

part 'llm_service.g.dart';

enum LlmStatus { notLoaded, loading, ready, error }

class InferenceParams {
  final double temperature;
  final double topP;
  final int topK;
  final int maxTokens;
  final double repeatPenalty;

  const InferenceParams({
    this.temperature = 0.1,
    this.topP = 0.9,
    this.topK = 40,
    this.maxTokens = 256,
    this.repeatPenalty = 1.1,
  });

  static const defaults = InferenceParams();
}

abstract class LlmDataSource {
  Future<void> loadModel(String modelPath);
  Stream<String> generate(String prompt, {InferenceParams? params});
  Future<void> releaseContext();
  Future<void> restoreContext();
  Future<void> dispose();
}

class MockLlmDataSource implements LlmDataSource {
  @override
  Future<void> loadModel(String modelPath) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) async* {
    yield '本地 LLM 功能正在开发中...\n';
    yield '提示: $prompt';
  }

  @override
  Future<void> releaseContext() async {}

  @override
  Future<void> restoreContext() async {}

  @override
  Future<void> dispose() async {}
}

@riverpod
class LlmService extends _$LlmService {
  LlmDataSource? _datasource;
  String? _modelPath;

  @override
  LlmStatus build() => LlmStatus.notLoaded;

  Future<void> initialize(String modelPath) async {
    state = LlmStatus.loading;
    _modelPath = modelPath;
    try {
      _datasource = _createLlmDataSource();
      await _datasource!.loadModel(modelPath);
      state = LlmStatus.ready;
    } catch (e) {
      state = LlmStatus.error;
      rethrow;
    }
  }

  LlmDataSource _createLlmDataSource() {
    return PythonLlmDataSource();
  }

  Future<void> retry() async {
    if (_modelPath != null) await initialize(_modelPath!);
  }

  Future<void> releaseContext() async {
    await _datasource?.releaseContext();
  }

  Future<void> restoreContext() async {
    await _datasource?.restoreContext();
  }

  Stream<String> translate(String text, {String targetLang = 'zh'}) {
    if (state != LlmStatus.ready) {
      return Stream.error(StateError('LLM not ready'));
    }
    final prompt = targetLang == 'zh'
        ? '将以下英文翻译成中文，只输出译文，不要解释：\n$text'
        : '将以下中文翻译成英文，只输出译文，不要解释：\n$text';
    return _datasource!.generate(prompt, params: InferenceParams.defaults);
  }

  Stream<String> distinguish(List<String> words) {
    if (state != LlmStatus.ready) {
      return Stream.error(StateError('LLM not ready'));
    }
    final wordList = words.join('、');
    final prompt = '简要辨析以下词语的区别（100字以内）：$wordList';
    return _datasource!.generate(prompt, params: const InferenceParams(maxTokens: 200));
  }

  Stream<String> generateExample(String word) {
    if (state != LlmStatus.ready) {
      return Stream.error(StateError('LLM not ready'));
    }
    final prompt = '用英文单词"$word"造一个自然的例句，并给出中文翻译。格式：\n英文：...\n中文：...';
    return _datasource!.generate(prompt, params: const InferenceParams(maxTokens: 128));
  }
}

final llmModelNameProvider = Provider<String?>((ref) => null);
