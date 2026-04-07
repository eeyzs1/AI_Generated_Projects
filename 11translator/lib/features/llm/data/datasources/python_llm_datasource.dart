import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';

class PythonLlmDataSource implements LlmDataSource {
  Process? _process;
  String? _modelPath;
  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  bool _isReady = false;
  bool _isDisposed = false;

  @override
  Future<void> loadModel(String modelPath) async {
    if (_isDisposed) throw StateError('DataSource is disposed');
    
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
            _processStdout(data);
          });

      // 监听 stderr（日志输出）
      _process!.stderr
          .transform(utf8.decoder)
          .listen((data) {
            print('[Python LLM] $data');
            _processStderr(data);
          });

      // 监听进程退出
      _process!.exitCode.then((code) {
        if (!_isDisposed) {
          print('[Python LLM] 进程退出，代码: $code');
        }
      });

      // 等待 Python 服务就绪
      await _readyCompleter.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw StateError('Python 服务启动超时（2分钟）');
        },
      );
      
      _isReady = true;
      
    } catch (e) {
      await dispose();
      rethrow;
    }
  }

  Future<String?> _findPython() async {
    final possibleNames = ['python', 'python3', 'py'];
    
    for (final name in possibleNames) {
      try {
        final result = await Process.run(name, ['--version']);
        if (result.exitCode == 0) {
          return name;
        }
      } catch (e) {
        continue;
      }
    }
    
    return null;
  }

  Future<String?> _findPythonScript() async {
    final scriptName = 'llm_server.py';
    
    final projectScript = path.join(Directory.current.path, 'python_backend', scriptName);
    if (await File(projectScript).exists()) {
      return projectScript;
    }
    
    final appDir = await getApplicationDocumentsDirectory();
    final appScript = path.join(appDir.path, '11translator', 'python_backend', scriptName);
    if (await File(appScript).exists()) {
      return appScript;
    }
    
    return null;
  }

  void _processStdout(String data) {
    if (_isDisposed) return;
    
    final lines = LineSplitter.split(data);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      try {
        final json = jsonDecode(trimmed);
        
        // 检查是否是 READY 信号
        if (!_readyCompleter.isCompleted && json['type'] == 'ready') {
          _readyCompleter.complete();
        }
        
        _messageController.add(json);
      } catch (e) {
        // 忽略非 JSON 行
      }
    }
  }

  void _processStderr(String data) {
    if (_isDisposed) return;
    
    // 检查 READY 信号
    if (!_readyCompleter.isCompleted && data.contains('[READY]')) {
      _readyCompleter.complete();
    }
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) {
    if (_isDisposed) return Stream.error(StateError('DataSource is disposed'));
    if (_process == null || !_isReady) {
      return Stream.error(StateError('Model not loaded'));
    }

    final effectiveParams = params ?? InferenceParams.defaults;
    final stopTokens = effectiveParams.stop ?? [];
    
    final requestJson = <String, dynamic>{
      'action': 'generate',
      'prompt': prompt,
      'params': {
        'maxTokens': effectiveParams.maxTokens,
        'temperature': effectiveParams.temperature,
        'topP': effectiveParams.topP,
        'topK': effectiveParams.topK,
        'repeatPenalty': effectiveParams.repeatPenalty,
      },
    };
    
    final request = jsonEncode(requestJson);

    // 发送请求
    _process!.stdin.writeln(request);
    _process!.stdin.flush();

    // 创建一个新的流控制器来处理这次请求
    final responseController = StreamController<String>();
    final StringBuffer accumulatedText = StringBuffer();
    bool hasStartedOutput = false;
    
    late StreamSubscription<Map<String, dynamic>> subscription;
    
    subscription = _messageController.stream.listen(
      (message) {
        final type = message['type'] as String?;
        
        if (type == 'token') {
          final token = message['data'] as String?;
          if (token != null) {
            accumulatedText.write(token);
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
              responseController.add(token);
            } else {
              responseController.close();
              subscription.cancel();
              return;
            }
          }
        } else if (type == 'done') {
          responseController.close();
          subscription.cancel();
        } else if (type == 'error') {
          final error = message['data'] as String?;
          responseController.addError(StateError(error ?? 'Unknown error'));
          responseController.close();
          subscription.cancel();
        }
      },
      onError: (error) {
        responseController.addError(error);
        responseController.close();
      },
      onDone: () {
        if (!responseController.isClosed) {
          responseController.close();
        }
      },
    );

    return responseController.stream;
  }

  @override
  Future<void> releaseContext() async {}

  @override
  Future<void> restoreContext() async {}

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.completeError(StateError('Disposed'));
    }
    
    if (_process != null) {
      try {
        _process!.stdin.writeln(jsonEncode({'action': 'exit'}));
        await _process!.stdin.flush();
      } catch (e) {
        // 忽略
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      _process!.kill();
      _process = null;
    }
    
    _isReady = false;
    await _messageController.close();
  }

  // ========== 字典功能 ==========
  
  Future<Map<String, dynamic>?> _sendDictionaryRequest(Map<String, dynamic> request) async {
    if (_isDisposed) return null;
    if (_process == null || !_isReady) {
      return null;
    }

    final requestJson = jsonEncode(request);
    _process!.stdin.writeln(requestJson);
    _process!.stdin.flush();

    final completer = Completer<Map<String, dynamic>?>();
    late StreamSubscription<Map<String, dynamic>> subscription;

    subscription = _messageController.stream.listen(
      (message) {
        final type = message['type'] as String?;
        if (type == 'extract_result' || 
            type == 'load_result' || 
            type == 'lookup_result' ||
            type == 'error') {
          completer.complete(message);
          subscription.cancel();
        }
      },
      onError: (error) {
        completer.completeError(error);
        subscription.cancel();
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    // 超时 30 秒
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        subscription.cancel();
        return null;
      },
    );
  }

  Future<String?> extractDictionary(String archivePath, String outputDir) async {
    final request = <String, dynamic>{
      'action': 'extract_dictionary',
      'archivePath': archivePath,
      'outputDir': outputDir,
    };

    final result = await _sendDictionaryRequest(request);
    if (result != null && result['type'] == 'extract_result') {
      final data = result['data'] as Map<String, dynamic>;
      if (data['success'] == true) {
        return data['ifoPath'] as String?;
      }
    }
    return null;
  }

  Future<bool> loadDictionary(String dictPath) async {
    final request = <String, dynamic>{
      'action': 'load_dictionary',
      'dictPath': dictPath,
    };

    final result = await _sendDictionaryRequest(request);
    if (result != null && result['type'] == 'load_result') {
      final data = result['data'] as Map<String, dynamic>;
      return data['success'] == true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> lookupWord(String dictPath, String word) async {
    final request = <String, dynamic>{
      'action': 'lookup_word',
      'dictPath': dictPath,
      'word': word,
    };

    final result = await _sendDictionaryRequest(request);
    if (result != null && result['type'] == 'lookup_result') {
      return result['data'] as Map<String, dynamic>;
    }
    return null;
  }

  // ========== OPUS-MT 翻译功能 ==========

  Future<String?> translateWithOpusMt(
    String text, {
    String sourceLang = 'en',
    String targetLang = 'zh',
  }) async {
    if (_isDisposed) return null;
    if (_process == null || !_isReady) {
      throw StateError('Model not loaded');
    }

    final request = <String, dynamic>{
      'action': 'translate_opus_mt',
      'text': text,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
    };

    final requestJson = jsonEncode(request);
    _process!.stdin.writeln(requestJson);
    _process!.stdin.flush();

    final completer = Completer<String?>();
    late StreamSubscription<Map<String, dynamic>> subscription;

    subscription = _messageController.stream.listen(
      (message) {
        final type = message['type'] as String?;
        if (type == 'translate_result') {
          final data = message['data'] as Map<String, dynamic>;
          if (data['success'] == true) {
            completer.complete(data['text'] as String?);
          } else {
            completer.completeError(StateError(data['error'] ?? 'Translation failed'));
          }
          subscription.cancel();
        } else if (type == 'error') {
          final error = message['data'] as String?;
          completer.completeError(StateError(error ?? 'Unknown error'));
          subscription.cancel();
        }
      },
      onError: (error) {
        completer.completeError(error);
        subscription.cancel();
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        subscription.cancel();
        throw TimeoutException('OPUS-MT translation timeout');
      },
    );
  }

  // ========== 模型下载功能 ==========

  Future<Map<String, bool>> checkDownloadSources() async {
    if (_isDisposed) return {};
    if (_process == null || !_isReady) {
      throw StateError('Server not ready');
    }

    final request = <String, dynamic>{
      'action': 'check_sources',
    };

    final requestJson = jsonEncode(request);
    _process!.stdin.writeln(requestJson);
    _process!.stdin.flush();

    final completer = Completer<Map<String, bool>>();
    late StreamSubscription<Map<String, dynamic>> subscription;

    subscription = _messageController.stream.listen(
      (message) {
        final type = message['type'] as String?;
        if (type == 'sources_result') {
          final data = message['data'] as Map<String, dynamic>;
          completer.complete(data.cast<String, bool>());
          subscription.cancel();
        } else if (type == 'error') {
          completer.completeError(StateError(message['data'] ?? 'Unknown error'));
          subscription.cancel();
        }
      },
      onError: (error) {
        completer.completeError(error);
        subscription.cancel();
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete({});
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        subscription.cancel();
        return {};
      },
    );
  }

  Future<Map<String, dynamic>> downloadModel({
    required String modelType,
    required String savePath,
    String? source,
    bool autoDetect = true,
  }) async {
    if (_isDisposed) return {'success': false, 'error': 'Disposed'};
    if (_process == null || !_isReady) {
      throw StateError('Server not ready');
    }

    final request = <String, dynamic>{
      'action': 'download_model',
      'modelType': modelType,
      'savePath': savePath,
      if (source != null) 'source': source,
      'autoDetect': autoDetect,
    };

    final requestJson = jsonEncode(request);
    _process!.stdin.writeln(requestJson);
    _process!.stdin.flush();

    final completer = Completer<Map<String, dynamic>>();
    late StreamSubscription<Map<String, dynamic>> subscription;

    subscription = _messageController.stream.listen(
      (message) {
        final type = message['type'] as String?;
        if (type == 'download_result') {
          final data = message['data'] as Map<String, dynamic>;
          completer.complete(data);
          subscription.cancel();
        } else if (type == 'error') {
          completer.complete({'success': false, 'error': message['data']});
          subscription.cancel();
        }
      },
      onError: (error) {
        completer.complete({'success': false, 'error': error.toString()});
        subscription.cancel();
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete({'success': false, 'error': 'Timeout'});
        }
      },
    );

    return completer.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () {
        subscription.cancel();
        return {'success': false, 'error': 'Download timeout'};
      },
    );
  }
}
