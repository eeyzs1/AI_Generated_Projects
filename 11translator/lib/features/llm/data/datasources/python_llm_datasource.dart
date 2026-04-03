import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';

class PythonLlmDataSource implements LlmDataSource {
  Process? _process;
  String? _modelPath;
  final StreamController<String> _outputController = StreamController.broadcast();
  bool _isReady = false;

  @override
  Future<void> loadModel(String modelPath) async {
    _modelPath = modelPath;
    
    // 找到 Python 解释器
    final pythonPath = await _findPython();
    if (pythonPath == null) {
      throw StateError(
        '未找到 Python 解释器！\n'
        '请安装 Python 并添加到系统 PATH。',
      );
    }

    // 找到 Python 后端脚本
    final scriptPath = await _findPythonScript();
    if (scriptPath == null) {
      throw StateError('未找到 Python 后端脚本！');
    }

    // 启动 Python 进程
    try {
      _process = await Process.start(
        pythonPath,
        [scriptPath, '--model', modelPath],
      );

      // 监听 stdout
      _process!.stdout
          .transform(utf8.decoder)
          .listen((data) {
            _processOutput(data);
          });

      // 监听 stderr（日志输出）
      _process!.stderr
          .transform(utf8.decoder)
          .listen((data) {
            // 可以在这里处理日志
            print('[Python LLM] $data');
          });

      // 等待 Python 服务就绪
      await _waitForReady();
      
    } catch (e) {
      await dispose();
      rethrow;
    }
  }

  Future<String?> _findPython() async {
    // 尝试常见的 Python 命令
    final possibleNames = ['python', 'python3', 'py'];
    
    for (final name in possibleNames) {
      try {
        final result = await Process.run(name, ['--version']);
        if (result.exitCode == 0) {
          return name;
        }
      } catch (e) {
        // 继续尝试下一个
      }
    }
    
    return null;
  }

  Future<String?> _findPythonScript() async {
    final scriptName = 'llm_server.py';
    
    // 尝试项目目录
    final projectScript = path.join(Directory.current.path, 'python_backend', scriptName);
    if (await File(projectScript).exists()) {
      return projectScript;
    }
    
    // 尝试应用文档目录
    final appDir = await getApplicationDocumentsDirectory();
    final appScript = path.join(appDir.path, '11translator', 'python_backend', scriptName);
    if (await File(appScript).exists()) {
      return appScript;
    }
    
    return null;
  }

  Future<void> _waitForReady() async {
    final completer = Completer<void>();
    bool readyReceived = false;
    
    Timer? timeout;
    
    void checkReady() {
      if (readyReceived) return;
      
      // 监听 stderr 输出中的 [READY] 信号
      // （我们已经在 loadModel 中打印了 stderr）
    }
    
    // 设置超时
    timeout = Timer(const Duration(seconds: 60), () {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Python 服务启动超时'));
      }
    });
    
    // 简单轮询检查（暂时方案）
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      // 实际上我们需要更好的方式来检测就绪
      // 暂时返回 false 退出循环
      return false;
    });
    
    // 简单等待一会儿，让 Python 加载模型
    await Future.delayed(const Duration(seconds: 5));
    _isReady = true;
    
    timeout?.cancel();
  }

  void _processOutput(String data) {
    final lines = LineSplitter.split(data);
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      try {
        final json = jsonDecode(line);
        final type = json['type'] as String?;
        
        if (type == 'token') {
          final token = json['data'] as String?;
          if (token != null) {
            _outputController.add(token);
          }
        } else if (type == 'done') {
          // 生成完成
        } else if (type == 'error') {
          final error = json['data'] as String?;
          _outputController.addError(StateError(error ?? 'Unknown error'));
        }
      } catch (e) {
        // 忽略非 JSON 行
      }
    }
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) async* {
    if (_process == null || !_isReady) {
      throw StateError('Model not loaded');
    }

    final effectiveParams = params ?? InferenceParams.defaults;
    
    final request = jsonEncode({
      'action': 'generate',
      'prompt': prompt,
      'params': {
        'maxTokens': effectiveParams.maxTokens,
        'temperature': effectiveParams.temperature,
        'topP': effectiveParams.topP,
        'topK': effectiveParams.topK,
        'repeatPenalty': effectiveParams.repeatPenalty,
      },
    });

    // 发送请求到 Python 进程
    _process!.stdin.writeln(request);
    await _process!.stdin.flush();

    // 监听输出流
    final completer = Completer<void>();
    final subscription = _outputController.stream.listen(
      (token) {
        yield token;
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    try {
      await completer.future;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> releaseContext() async {
    // Python 端不需要显式释放上下文
  }

  @override
  Future<void> restoreContext() async {
    // Python 端不需要显式恢复上下文
  }

  @override
  Future<void> dispose() async {
    if (_process != null) {
      try {
        // 发送退出命令
        _process!.stdin.writeln(jsonEncode({'action': 'exit'}));
        await _process!.stdin.flush();
      } catch (e) {
        // 忽略错误
      }
      
      // 等待进程退出
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 强制杀死进程
      _process!.kill();
      _process = null;
    }
    
    _isReady = false;
    await _outputController.close();
  }
}
