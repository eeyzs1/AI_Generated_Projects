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

@riverpod
class LlmService extends _$LlmService {
  LlmDataSource? _datasource;
  String? _modelPath;
  bool _isReady = false;

  @override
  LlmStatus build() => LlmStatus.notLoaded;

  Future<void> initialize(String modelPath) async {
    state = LlmStatus.loading;
    _isReady = false;
    _modelPath = modelPath;
    try {
      _datasource = _createLlmDataSource();
      await _datasource!.loadModel(modelPath);
      _isReady = true;
      state = LlmStatus.ready;
    } catch (e) {
      _isReady = false;
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
        prompt = '翻译为中文：$text';
      } else {
        prompt = '翻译为英文：$text';
      }
      maxTokens = 100;
    } else {
      if (targetLang == 'zh') {
        prompt = '请将以下内容翻译成中文，只输出翻译结果：$text';
      } else {
        prompt = '请将以下内容翻译成英文，只输出翻译结果：$text';
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
    final wordList = words.join('、');
    final prompt = '简要辨析以下词语的区别（100字以内）：$wordList';
    return _datasource!.generate(prompt, params: const InferenceParams(maxTokens: 200));
  }

  Stream<String> generateExample(String word) {
    if (!_isReady || _datasource == null) {
      return Stream.error(StateError('LLM not ready'));
    }
    final prompt = '用英文单词"$word"造一个自然的例句，并给出中文翻译。格式：\n英文：...\n中文：...';
    return _datasource!.generate(prompt, params: const InferenceParams(maxTokens: 128));
  }

  LlmDataSource? get dataSource => _datasource;
}

final llmModelNameProvider = Provider<String?>((ref) => null);
