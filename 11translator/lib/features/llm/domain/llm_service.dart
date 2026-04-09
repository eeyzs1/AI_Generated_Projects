import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final List<String>? stop;

  const InferenceParams({
    this.temperature = 0.0,
    this.topP = 1.0,
    this.topK = 1,
    this.maxTokens = 256,
    this.repeatPenalty = 1.05,
    this.stop,
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

final llmDataSourceProvider = Provider<LlmDataSource>((ref) {
  return PythonLlmDataSource();
});

@riverpod
class LlmService extends _$LlmService {
  LlmDataSource? _datasource;
  String? _modelPath;
  bool _isReady = false;

  @override
  LlmStatus build() => LlmStatus.notLoaded;

  Future<void> initialize(String modelPath, {LlmDataSource? dataSource}) async {
    state = LlmStatus.loading;
    _isReady = false;
    _modelPath = modelPath;
    try {
      _datasource = dataSource ?? PythonLlmDataSource();
      await _datasource!.loadModel(modelPath);
      _isReady = true;
      state = LlmStatus.ready;
    } catch (e) {
      _isReady = false;
      state = LlmStatus.error;
      rethrow;
    }
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

  bool _isWordOrPhrase(String text) {
    final cleaned = text.trim();
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.length <= 3 && cleaned.length <= 50;
  }

  Stream<String> translate(String text, {String targetLang = 'zh'}) {
    if (!_isReady || _datasource == null) {
      return Stream.error(StateError('LLM not ready'));
    }

    final isWordOrPhrase = _isWordOrPhrase(text);

    String prompt;
    int maxTokens;

    if (isWordOrPhrase) {
      if (targetLang == 'zh') {
        prompt = '\u7FFB\u8BD1\u4E3A\u4E2D\u6587\uFF1A$text';
      } else {
        prompt = '\u7FFB\u8BD1\u4E3A\u82F1\u6587\uFF1A$text';
      }
      maxTokens = 100;
    } else {
      if (targetLang == 'zh') {
        prompt = '\u8BF7\u5C06\u4EE5\u4E0B\u5185\u5BB9\u7FFB\u8BD1\u6210\u4E2D\u6587\uFF0C\u53EA\u8F93\u51FA\u7FFB\u8BD1\u7ED3\u679C\uFF1A$text';
      } else {
        prompt = '\u8BF7\u5C06\u4EE5\u4E0B\u5185\u5BB9\u7FFB\u8BD1\u6210\u82F1\u6587\uFF0C\u53EA\u8F93\u51FA\u7FFB\u8BD1\u7ED3\u679C\uFF1A$text';
      }
      maxTokens = 256;
    }

    return _datasource!.generate(
      prompt,
      params: InferenceParams(
        maxTokens: maxTokens,
        temperature: 0.3,
        topP: 0.9,
        topK: 40,
        repeatPenalty: 1.05,
        stop: [
          '<|im_end|>',
        ],
      ),
    );
  }

  bool isWordOrPhrase(String text) {
    return _isWordOrPhrase(text);
  }

  Stream<String> distinguish(List<String> words) {
    if (!_isReady || _datasource == null) {
      return Stream.error(StateError('LLM not ready'));
    }
    final wordList = words.join('\u3001');
    final prompt = '\u7B80\u8981\u8FA8\u6790\u4EE5\u4E0B\u8BCD\u8BED\u7684\u533A\u522B\uFF08200\u5B57\u4EE5\u5185\uFF09\uFF1A$wordList';
    return _datasource!.generate(prompt, params: const InferenceParams(maxTokens: 200));
  }

  Stream<String> generateExample(String word) {
    if (!_isReady || _datasource == null) {
      return Stream.error(StateError('LLM not ready'));
    }
    final prompt = '\u7528\u82F1\u6587\u5355\u8BCD"$word"\u9020\u4E00\u4E2A\u81EA\u7136\u7684\u4F8B\u53E5\uFF0C\u5E76\u7ED9\u51FA\u4E2D\u6587\u7FFB\u8BD1\u3002\u683C\u5F0F\uFF1A\n\u82F1\u6587\uFF1A...\n\u4E2D\u6587\uFF1A...';
    return _datasource!.generate(prompt, params: const InferenceParams(maxTokens: 128));
  }

  LlmDataSource? get dataSource => _datasource;
}

final llmModelNameProvider = Provider<String?>((ref) => null);
