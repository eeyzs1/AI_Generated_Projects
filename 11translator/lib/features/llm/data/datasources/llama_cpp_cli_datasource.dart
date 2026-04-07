import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';

class LlamaCppCliDataSource implements LlmDataSource {
  String? _modelPath;
  String? _llamaCliPath;

  @override
  Future<void> loadModel(String modelPath) async {
    _modelPath = modelPath;
    _llamaCliPath = await _findLlamaCli();
    
    if (_llamaCliPath == null) {
      throw StateError(
        '未找到 llama.cpp 命令行程序！\n'
        '请从 https://github.com/ggml-org/llama.cpp/releases 下载，\n'
        '或使用 winget install llama.cpp 安装。',
      );
    }
  }

  Future<String?> _findLlamaCli() async {
    final possibleNames = [
      'llama-cli.exe',
      'main.exe',
      'server.exe',
    ];

    final appDir = await getApplicationDocumentsDirectory();
    for (final name in possibleNames) {
      final exePath = path.join(appDir.path, 'llama.cpp', name);
      if (await File(exePath).exists()) {
        return exePath;
      }
    }

    for (final name in possibleNames) {
      final exePath = path.join(Directory.current.path, name);
      if (await File(exePath).exists()) {
        return exePath;
      }
    }

    for (final name in possibleNames) {
      try {
        final result = await Process.run('where', [name]);
        if (result.exitCode == 0) {
          final lines = LineSplitter.split(result.stdout.toString());
          if (lines.isNotEmpty) {
            return lines.first.trim();
          }
        }
      } catch (e) {
        // 忽略错误
      }
    }

    return null;
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) async* {
    if (_modelPath == null || _llamaCliPath == null) {
      throw StateError('Model not loaded');
    }

    final effectiveParams = params ?? InferenceParams.defaults;
    final stopTokens = effectiveParams.stop ?? [];
    
    final args = [
      '-m', _modelPath!,
      '-p', prompt,
      '-n', effectiveParams.maxTokens.toString(),
      '-t', '4',
      '-c', '2048',
      '--temp', effectiveParams.temperature.toString(),
      '--top-p', effectiveParams.topP.toString(),
      '--top-k', effectiveParams.topK.toString(),
      '--repeat-penalty', effectiveParams.repeatPenalty.toString(),
    ];

    try {
      final process = await Process.start(
        _llamaCliPath!,
        args,
      );

      final controller = StreamController<String>();
      final StringBuffer accumulatedText = StringBuffer();
      bool hasStartedOutput = false;

      process.stdout
          .transform(utf8.decoder)
          .listen((data) {
            if (data.trim().isNotEmpty) {
              accumulatedText.write(data);
              final currentText = accumulatedText.toString();
              
              // 一旦检测到任何停止符，立即停止
              bool shouldStop = false;
              for (final stopToken in stopTokens) {
                if (currentText.contains(stopToken)) {
                  shouldStop = true;
                  break;
                }
              }
              
              // 额外的严格检测：只要有输出后，只要看到 ### 就立即停止
              if (!shouldStop && hasStartedOutput && currentText.contains('###')) {
                shouldStop = true;
              }
              
              // 如果不停止才添加 token
              if (!shouldStop) {
                hasStartedOutput = true;
                controller.add(data);
              } else {
                controller.close();
                return;
              }
            }
          }, onDone: () => controller.close());

      process.stderr
          .transform(utf8.decoder)
          .listen((data) {
            // 可以在这里处理错误输出
          });

      yield* controller.stream;
      
      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        throw StateError('llama.cpp 执行失败，退出代码: $exitCode');
      }
    } catch (e) {
      yield '本地 LLM 推理需要 llama.cpp 命令行程序\n';
      yield '请从 https://github.com/ggml-org/llama.cpp/releases 下载\n';
      yield '错误详情: $e';
    }
  }

  @override
  Future<void> releaseContext() async {}

  @override
  Future<void> restoreContext() async {}

  @override
  Future<void> dispose() async {
    _modelPath = null;
    _llamaCliPath = null;
  }
}
