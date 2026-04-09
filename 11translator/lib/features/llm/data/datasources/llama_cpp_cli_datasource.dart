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
        '\u672A\u627E\u5230 llama.cpp \u547D\u4EE4\u884C\u7A0B\u5E8F\uFF01\n'
        '\u8BF7\u4ECE https://github.com/ggml-org/llama.cpp/releases \u4E0B\u8F7D\uFF0C\n'
        '\u6216\u4F7F\u7528 winget install llama.cpp \u5B89\u88C5',
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
      } catch (_) {
        continue;
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

              bool shouldStop = false;
              for (final stopToken in stopTokens) {
                if (currentText.contains(stopToken)) {
                  shouldStop = true;
                  break;
                }
              }

              if (!shouldStop && hasStartedOutput && currentText.contains('###')) {
                shouldStop = true;
              }

              if (!shouldStop) {
                hasStartedOutput = true;
                controller.add(data);
              } else {
                controller.close();
                return;
              }
            }
          }, onDone: () => controller.close(),);

      process.stderr
          .transform(utf8.decoder)
          .listen((data) {
          });

      yield* controller.stream;

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        throw StateError('llama.cpp \u6267\u884C\u5931\u8D25\uFF0C\u9000\u51FA\u4EE3\u7801\uFF1A$exitCode');
      }
    } catch (e) {
      yield '\u672C\u5730 LLM \u63A8\u7406\u9700\u8981 llama.cpp \u547D\u4EE4\u884C\u7A0B\u5E8F\n';
      yield '\u8BF7\u4ECE https://github.com/ggml-org/llama.cpp/releases \u4E0B\u8F7D\n';
      yield '\u9519\u8BEF\u8BE6\u60C5: $e';
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
