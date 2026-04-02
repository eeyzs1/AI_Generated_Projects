# 本地 LLM 集成指南

## 1. 为什么需要本地 LLM

词典数据库（ECDICT）覆盖单词查询，但以下场景需要 LLM：
- 句子/短语翻译（非单词）
- 词义辨析（如 big vs large vs great）
- 语境相关例句生成
- 超出词典范围的新词/网络用语

**核心约束：纯本地，不调用任何远程 API。**

---

## 2. 模型选型

### 2.1 推荐模型对比

| 模型 | 量化 | 大小 | RAM占用 | 中英翻译质量 | 适用平台 |
|------|------|------|---------|------------|---------|
| Qwen2.5-0.5B-Instruct | Q4_K_M | ~400MB | ~600MB | ★★★☆☆ | Android 低端机 |
| Qwen2.5-1.5B-Instruct | Q4_K_M | ~900MB | ~1.2GB | ★★★★☆ | Android 中高端（默认） |
| Qwen2.5-3B-Instruct | Q4_K_M | ~1.8GB | ~2.5GB | ★★★★★ | Windows（默认） |
| Phi-3.5-mini-instruct | Q4_K_M | ~2.2GB | ~3GB | ★★★★☆ | Windows 备选 |

**推荐策略（已确定）：**
- Android：首次启动检测可用 RAM，自动选择 0.5B（RAM < 2GB）或 1.5B（RAM >= 2GB）
- Windows：默认使用 3B，用户可在设置中切换

### 2.2 模型下载来源

```
Hugging Face (GGUF 格式):
- Qwen2.5-0.5B: Qwen/Qwen2.5-0.5B-Instruct-GGUF
- Qwen2.5-1.5B: Qwen/Qwen2.5-1.5B-Instruct-GGUF
- Qwen2.5-3B:   Qwen/Qwen2.5-3B-Instruct-GGUF
- Phi-3.5-mini: microsoft/Phi-3.5-mini-instruct-gguf
```

---

## 3. 集成方案

### 3.1 Android — flutter_llama_cpp

```yaml
# pubspec.yaml
dependencies:
  flutter_llama_cpp: ^0.1.0  # 社区包，封装 llama.cpp JNI
```

```dart
// lib/features/llm/data/android_llm_datasource.dart
import 'package:flutter_llama_cpp/flutter_llama_cpp.dart';

class AndroidLlmDataSource implements LlmDataSource {
  LlamaModel? _model;
  LlamaContext? _context;

  @override
  Future<void> loadModel(String modelPath) async {
    _model = await LlamaModel.load(modelPath);
    _context = await _model!.createContext(
      contextSize: 2048,
      threads: _getOptimalThreads(),
      gpuLayers: 0,
    );
  }

  int _getOptimalThreads() {
    final cores = Platform.numberOfProcessors;
    return (cores / 2).ceil().clamp(2, 4);
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) async* {
    if (_context == null) throw StateError('Model not loaded');
    final p = params ?? InferenceParams.defaults;
    final formattedPrompt = _buildQwenPrompt(prompt);
    await for (final token in _context!.generate(
      formattedPrompt,
      temperature: p.temperature,
      topP: p.topP,
      topK: p.topK,
      maxTokens: p.maxTokens,
      repeatPenalty: p.repeatPenalty,
    )) {
      yield token;
    }
  }

  @override
  Future<void> releaseContext() async {
    await _context?.dispose();
    _context = null;
  }

  @override
  Future<void> restoreContext() async {
    if (_model != null && _context == null) {
      _context = await _model!.createContext(
        contextSize: 2048,
        threads: _getOptimalThreads(),
        gpuLayers: 0,
      );
    }
  }

  @override
  Future<void> dispose() async {
    await _context?.dispose();
    await _model?.dispose();
  }
}
```

### 3.2 Windows — llama_cpp_dart

```yaml
# pubspec.yaml（Windows 条件依赖）
dependencies:
  llama_cpp_dart: ^0.1.0  # dart:ffi 封装，提供 llama.dll
```

```dart
// lib/features/llm/data/windows_llm_datasource.dart
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class WindowsLlmDataSource implements LlmDataSource {
  LlamaModel? _model;
  LlamaContext? _context;

  @override
  Future<void> loadModel(String modelPath) async {
    // llama_cpp_dart 自动加载同目录下的 llama.dll
    _model = LlamaModel.fromFile(modelPath);
    _context = LlamaContext.create(
      model: _model!,
      contextSize: 4096,
      threads: 8,
      batchSize: 512,
    );
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) async* {
    if (_context == null) throw StateError('Model not loaded');
    final p = params ?? InferenceParams.defaults;
    final formattedPrompt = _buildPrompt(prompt);

    final sampler = LlamaSampler(
      temperature: p.temperature,
      topP: p.topP,
      topK: p.topK,
      repeatPenalty: p.repeatPenalty,
    );

    _context!.setPrompt(formattedPrompt);
    int tokenCount = 0;
    while (tokenCount < p.maxTokens) {
      final token = _context!.sampleNext(sampler);
      if (token == _model!.eosToken) break;
      yield _model!.tokenToString(token);
      tokenCount++;
    }
  }

  String _buildPrompt(String userMessage) {
    // 根据模型类型选择模板
    if (_isPhiModel()) return _buildPhiPrompt(userMessage);
    return _buildQwenPrompt(userMessage);
  }

  bool _isPhiModel() {
    return _model?.modelPath.contains('phi') ?? false;
  }

  @override
  Future<void> releaseContext() async {
    _context?.dispose();
    _context = null;
  }

  @override
  Future<void> restoreContext() async {
    if (_model != null && _context == null) {
      _context = LlamaContext.create(
        model: _model!,
        contextSize: 4096,
        threads: 8,
        batchSize: 512,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _context?.dispose();
    _model?.dispose();
  }
}
```

---

## 4. Prompt 模板

### Qwen2.5 Chat 模板

```dart
String _buildQwenPrompt(String userMessage) {
  return '<|im_start|>system\n'
      '你是一个英汉词典助手，提供简洁准确的翻译和释义。<|im_end|>\n'
      '<|im_start|>user\n$userMessage<|im_end|>\n'
      '<|im_start|>assistant\n';
}
```

### Phi-3.5-mini 模板

```dart
String _buildPhiPrompt(String userMessage) {
  return '<|system|>\n'
      '你是一个英汉词典助手，提供简洁准确的翻译和释义。<|end|>\n'
      '<|user|>\n$userMessage<|end|>\n'
      '<|assistant|>\n';
}
```

---

## 5. LLM 服务封装

```dart
// lib/features/llm/domain/llm_service.dart
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'llm_service.g.dart';

enum LlmStatus { notLoaded, loading, ready, error }

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
      _datasource = createLlmDataSource();
      await _datasource!.loadModel(modelPath);
      state = LlmStatus.ready;
    } catch (e) {
      state = LlmStatus.error;
      rethrow;
    }
  }

  Future<void> retry() async {
    if (_modelPath != null) await initialize(_modelPath!);
  }

  // Android 后台时释放上下文节省内存
  Future<void> releaseContext() async {
    await _datasource?.releaseContext();
  }

  // 恢复前台时重建上下文
  Future<void> restoreContext() async {
    await _datasource?.restoreContext();
  }

  // 翻译句子/短语
  Stream<String> translate(String text, {String targetLang = 'zh'}) {
    if (state != LlmStatus.ready) {
      return Stream.error(StateError('LLM not ready'));
    }
    final prompt = targetLang == 'zh'
        ? '将以下英文翻译成中文，只输出译文，不要解释：\n$text'
        : '将以下中文翻译成英文，只输出译文，不要解释：\n$text';
    return _datasource!.generate(prompt,
        params: InferenceParams(maxTokens: 256));
  }

  // 词义辨析
  Stream<String> distinguish(List<String> words) {
    if (state != LlmStatus.ready) {
      return Stream.error(StateError('LLM not ready'));
    }
    final wordList = words.join('、');
    final prompt = '简要辨析以下词语的区别（100字以内）：$wordList';
    return _datasource!.generate(prompt,
        params: InferenceParams(maxTokens: 200));
  }

  // 生成例句
  Stream<String> generateExample(String word) {
    if (state != LlmStatus.ready) {
      return Stream.error(StateError('LLM not ready'));
    }
    final prompt = '用英文单词"$word"造一个自然的例句，并给出中文翻译。格式：\n英文：...\n中文：...';
    return _datasource!.generate(prompt,
        params: InferenceParams(maxTokens: 128));
  }
}
```

---

## 6. 推理参数

```dart
class InferenceParams {
  final double temperature;
  final double topP;
  final int topK;
  final int maxTokens;
  final double repeatPenalty;

  const InferenceParams({
    this.temperature = 0.1,   // 低温度，输出更确定
    this.topP = 0.9,
    this.topK = 40,
    this.maxTokens = 256,
    this.repeatPenalty = 1.1,
  });

  static const defaults = InferenceParams();
}
```

---

## 7. 降级策略

当 LLM 不可用时，应用仍可正常使用词典核心功能：

```
用户查词
  │
  ├── SQLite 词典查询 ──▶ 显示词典结果（始终可用）
  │
  └── LLM 增强查询
        ├── LLM 就绪 ──▶ 显示增强释义/翻译
        └── LLM 未就绪 ──▶ 显示"加载 AI 功能"按钮（不影响主流程）
```

LLM 超时处理（15s）：
```dart
Stream<String> translateWithTimeout(String text) {
  return translate(text).timeout(
    const Duration(seconds: 15),
    onTimeout: (sink) {
      sink.addError(TimeoutException('LLM timeout'));
      sink.close();
    },
  );
}
```

---

## 8. 模型文件分发（已确定方案）

### 方案B（默认）：首次使用时下载

首次点击 AI 功能时触发下载流程，支持断点续传。

```dart
// lib/features/llm/data/model_downloader.dart
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class ModelDownloader {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  bool _isPaused = false;

  /// 下载模型，返回进度流
  Stream<DownloadProgress> download(
    String url,
    String savePath, {
    String? expectedMd5,
  }) async* {
    _cancelToken = CancelToken();
    final tempPath = '$savePath.tmp';

    // 检查断点续传
    int startByte = 0;
    if (File(tempPath).existsSync()) {
      startByte = await File(tempPath).length();
    }

    try {
      await _dio.download(
        url,
        tempPath,
        cancelToken: _cancelToken,
        deleteOnError: false,
        options: Options(
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
          responseType: ResponseType.stream,
        ),
        onReceiveProgress: (received, total) {
          // 进度通过 StreamController 传递
        },
      );

      // 验证 MD5
      if (expectedMd5 != null) {
        final bytes = await File(tempPath).readAsBytes();
        final md5 = md5Hash(bytes);
        if (md5 != expectedMd5) {
          await File(tempPath).delete();
          throw Exception('MD5 verification failed');
        }
      }

      // 重命名为最终文件
      await File(tempPath).rename(savePath);
      yield DownloadProgress(1.0, isComplete: true);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        yield DownloadProgress.paused();
      } else {
        rethrow;
      }
    }
  }

  void pause() {
    _isPaused = true;
    _cancelToken?.cancel('paused');
  }

  void cancel() {
    _cancelToken?.cancel('cancelled');
    // 删除临时文件
  }

  String md5Hash(List<int> bytes) {
    return md5.convert(bytes).toString();
  }
}

class DownloadProgress {
  final double progress; // 0.0 - 1.0
  final bool isComplete;
  final bool isPaused;

  const DownloadProgress(this.progress,
      {this.isComplete = false, this.isPaused = false});

  factory DownloadProgress.paused() =>
      const DownloadProgress(0, isPaused: true);
}
```

### 方案C（次选）：用户手动导入 GGUF 文件

```dart
// 打开系统文件选择器
Future<void> importModelFromFile(BuildContext context, WidgetRef ref) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['gguf'],
  );

  if (result == null || result.files.isEmpty) return;

  final sourcePath = result.files.first.path!;
  final modelsDir = await AppPaths.getModelsDir();
  final fileName = result.files.first.name;
  final destPath = '$modelsDir/$fileName';

  // 显示复制进度
  await File(sourcePath).copy(destPath);

  // 激活模型
  await ref.read(llmServiceProvider.notifier).initialize(destPath);
}
```

### 方案A（不推荐）

将模型打包进 APK/EXE 会导致安装包过大（+400MB~2.2GB），不适合分发。

---

## 9. 内存管理

`AppLifecycleObserver` 已集成到 `main.dart` 的 `App` 组件中（见开发指导 §1.2）：

```dart
// App._AppState 中已注册
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    ref.read(llmServiceProvider.notifier).releaseContext();
  } else if (state == AppLifecycleState.resumed) {
    ref.read(llmServiceProvider.notifier).restoreContext();
  }
}
```

**内存占用参考：**
- 模型加载后（含权重）：见模型表 RAM 列
- 上下文释放后：仅保留模型权重，节省约 200-400MB
- Windows 无需释放（内存充足）
- 句子/短语翻译（非单词）
- 词义辨析（如 big vs large vs great）
- 语境相关例句生成
- 超出词典范围的新词/网络用语

**核心约束：纯本地，不调用任何远程 API。**

---

## 2. 模型选型

### 2.1 推荐模型对比

| 模型 | 量化 | 大小 | RAM占用 | 中英翻译质量 | 适用平台 |
|------|------|------|---------|------------|---------|
| Qwen2.5-0.5B-Instruct | Q4_K_M | ~400MB | ~600MB | ★★★☆☆ | Android低端 |
| Qwen2.5-1.5B-Instruct | Q4_K_M | ~900MB | ~1.2GB | ★★★★☆ | Android中高端 |
| Qwen2.5-3B-Instruct | Q4_K_M | ~1.8GB | ~2.5GB | ★★★★★ | Windows推荐 |
| Phi-3.5-mini-instruct | Q4_K_M | ~2.2GB | ~3GB | ★★★★☆ | Windows备选 |

**推荐策略：**
- Android：首次启动检测可用 RAM，自动选择 0.5B 或 1.5B
- Windows：默认使用 3B，用户可在设置中切换

### 2.2 模型下载来源

```
Hugging Face (GGUF 格式):
- Qwen2.5-0.5B: Qwen/Qwen2.5-0.5B-Instruct-GGUF
- Qwen2.5-1.5B: Qwen/Qwen2.5-1.5B-Instruct-GGUF
- Qwen2.5-3B:   Qwen/Qwen2.5-3B-Instruct-GGUF
```

---

## 3. 集成方案

### 3.1 Android — flutter_llama_cpp

```yaml
# pubspec.yaml
dependencies:
  flutter_llama_cpp: ^0.1.0  # 社区包，封装 llama.cpp JNI
```

```dart
// lib/features/llm/data/android_llm_datasource.dart
import 'package:flutter_llama_cpp/flutter_llama_cpp.dart';

class AndroidLlmDataSource implements LlmDataSource {
  LlamaModel? _model;
  LlamaContext? _context;

  @override
  Future<void> loadModel(String modelPath) async {
    _model = await LlamaModel.load(modelPath);
    _context = await _model!.createContext(
      contextSize: 2048,
      threads: 4,        // Android 建议 2-4 线程
      gpuLayers: 0,      // 低端机不用 GPU offload
    );
  }

  @override
  Stream<String> generate(String prompt) async* {
    if (_context == null) throw StateError('Model not loaded');
    final formattedPrompt = _buildPrompt(prompt);
    await for (final token in _context!.generate(formattedPrompt)) {
      yield token;
    }
  }

  String _buildPrompt(String userMessage) {
    // Qwen2.5 Chat 模板
    return '<|im_start|>system\n你是一个英汉词典助手，提供简洁准确的翻译和释义。<|im_end|>\n'
        '<|im_start|>user\n$userMessage<|im_end|>\n'
        '<|im_start|>assistant\n';
  }

  @override
  Future<void> dispose() async {
    await _context?.dispose();
    await _model?.dispose();
  }
}
```

### 3.2 Windows — dart:ffi + llama.cpp

```dart
// lib/features/llm/data/windows_llm_datasource.dart
// 建议使用 llama_cpp_dart 社区包简化 FFI 绑定
// 手动 FFI 绑定核心步骤：

class WindowsLlmDataSource implements LlmDataSource {
  late DynamicLibrary _lib;

  @override
  Future<void> loadModel(String modelPath) async {
    // 加载随应用分发的 llama.dll
    _lib = DynamicLibrary.open('llama.dll');
    // 通过 FFI 调用 llama_load_model_from_file
    // 参考 llama_cpp_dart 包的实现
  }

  @override
  Stream<String> generate(String prompt) async* {
    // FFI 调用 llama_decode，逐 token 输出
    yield* _generateTokens(prompt);
  }

  Stream<String> _generateTokens(String prompt) async* {
    // 实现细节参考 llama_cpp_dart 包
  }

  @override
  Future<void> dispose() async {}
}
```

---

## 4. LLM 服务封装

```dart
// lib/features/llm/domain/llm_service.dart
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'llm_service.g.dart';

enum LlmStatus { notLoaded, loading, ready, error }

@riverpod
class LlmService extends _$LlmService {
  LlmDataSource? _datasource;

  @override
  LlmStatus build() => LlmStatus.notLoaded;

  Future<void> initialize(String modelPath) async {
    state = LlmStatus.loading;
    try {
      _datasource = Platform.isAndroid
          ? AndroidLlmDataSource()
          : WindowsLlmDataSource();
      await _datasource!.loadModel(modelPath);
      state = LlmStatus.ready;
    } catch (e) {
      state = LlmStatus.error;
      rethrow;
    }
  }

  // 翻译句子/短语
  Stream<String> translate(String text, {String targetLang = 'zh'}) {
    if (state != LlmStatus.ready) {
      return Stream.error(StateError('LLM not ready'));
    }
    final prompt = targetLang == 'zh'
        ? '将以下英文翻译成中文，只输出译文，不要解释：\n$text'
        : '将以下中文翻译成英文，只输出译文，不要解释：\n$text';
    return _datasource!.generate(prompt);
  }

  // 词义辨析
  Stream<String> distinguish(List<String> words) {
    if (state != LlmStatus.ready) {
      return Stream.error(StateError('LLM not ready'));
    }
    final wordList = words.join('、');
    final prompt = '简要辨析以下词语的区别（100字以内）：$wordList';
    return _datasource!.generate(prompt);
  }

  // 生成例句
  Stream<String> generateExample(String word) {
    if (state != LlmStatus.ready) {
      return Stream.error(StateError('LLM not ready'));
    }
    final prompt = '用英文单词"$word"造一个自然的例句，并给出中文翻译。格式：\n英文：...\n中文：...';
    return _datasource!.generate(prompt);
  }
}
```

---

## 5. 推理参数调优

```dart
// 词典场景不需要创意，降低 temperature 提高准确性
const inferenceParams = {
  'temperature': 0.1,    // 低温度，输出更确定
  'top_p': 0.9,
  'top_k': 40,
  'max_tokens': 256,     // 翻译/释义不需要长输出
  'repeat_penalty': 1.1,
};
```

---

## 6. 降级策略

当 LLM 不可用时，应用仍可正常使用词典核心功能：

```
用户查词
  │
  ├── SQLite 词典查询 ──▶ 显示词典结果（始终可用）
  │
  └── LLM 增强查询
        ├── LLM 就绪 ──▶ 显示增强释义/翻译
        └── LLM 未就绪 ──▶ 显示"加载 AI 功能"按钮（不影响主流程）
```

---

## 7. 模型文件分发

### 方案A：应用内置（小模型）
- 0.5B 模型（~400MB）可随 APK 分发
- Android APK 体积限制：Google Play 允许 AAB + 扩展文件

### 方案B：首次启动下载（推荐）
```dart
// 应用首次启动时提示用户下载模型
// 支持断点续传，显示下载进度
class ModelDownloader {
  Future<void> downloadModel(
    String url,
    String savePath, {
    void Function(double progress)? onProgress,
  }) async {
    // 使用 dio 包实现断点续传
    // 下载完成后验证 MD5
  }
}
```

### 方案C：用户手动导入
- 提供"从文件导入模型"功能
- 用户自行下载 GGUF 文件后导入
- 适合高级用户和离线场景

---

## 8. 内存管理

```dart
// 后台时释放 LLM 上下文节省内存
class AppLifecycleObserver extends WidgetsBindingObserver {
  final WidgetRef ref;
  AppLifecycleObserver(this.ref);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Android 后台：释放上下文
      ref.read(llmServiceProvider.notifier).releaseContext();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(llmServiceProvider.notifier).restoreContext();
    }
  }
}
```
