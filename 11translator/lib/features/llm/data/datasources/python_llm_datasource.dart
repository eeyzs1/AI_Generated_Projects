import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';

class _PendingRequest {
  final String requestId;
  final String responseType;
  final Completer<dynamic> completer;
  late final StreamSubscription<Map<String, dynamic>> subscription;
  Timer? timeoutTimer;

  _PendingRequest({
    required this.requestId,
    required this.responseType,
    required this.completer,
  });
}

class _PendingStreamRequest {
  final String requestId;
  final StreamController<String> responseController;
  final List<String> stopTokens;
  final StringBuffer accumulatedText = StringBuffer();
  bool hasStartedOutput = false;
  late StreamSubscription<Map<String, dynamic>> subscription;
  Timer? timeoutTimer;

  _PendingStreamRequest({
    required this.requestId,
    required this.responseController,
    required this.stopTokens,
  });
}

class PythonLlmDataSource implements LlmDataSource {
  Process? _process;
  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  final Map<String, _PendingRequest> _pendingRequests = {};
  final Map<String, _PendingStreamRequest> _pendingStreamRequests = {};
  bool _isReady = false;
  bool _isDisposed = false;
  int _requestIdCounter = 0;

  String _nextRequestId() {
    _requestIdCounter++;
    return '$_requestIdCounter';
  }

  @override
  Future<void> loadModel(String modelPath) async {
    if (_isDisposed) throw StateError('DataSource is disposed');

    final pythonPath = await _findPython();
    if (pythonPath == null) {
      throw StateError(
        '\u672A\u627E\u5230 Python \u89E3\u91CA\u5668\uFF01\n'
        '\u8BF7\u5B89\u88C5 Python \u5E76\u6DFB\u52A0\u5230\u7CFB\u7EDF PATH',
      );
    }

    final scriptPath = await _findPythonScript();
    if (scriptPath == null) {
      throw StateError('\u672A\u627E\u5230 Python \u540E\u7AEF\u811A\u672C');
    }

    try {
      _process = await Process.start(
        pythonPath,
        [scriptPath, '--model', modelPath],
      );

      _process!.stdout.transform(utf8.decoder).listen((data) {
        _processStdout(data);
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        _processStderr(data);
      });

      _process!.exitCode.then((code) {
        if (!_isDisposed) {}
      });

      await _readyCompleter.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw StateError('Python \u670D\u52A1\u542F\u52A8\u8D85\u65F6\uFF082\u5206\u949F\uFF09');
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
    const scriptName = 'llm_server.py';

    final projectScript =
        path.join(Directory.current.path, 'python_backend', scriptName);
    if (await File(projectScript).exists()) {
      return projectScript;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final appScript =
        path.join(appDir.path, '11translator', 'python_backend', scriptName);
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
        final json = jsonDecode(trimmed) as Map<String, dynamic>;

        if (!_readyCompleter.isCompleted && json['type'] == 'ready') {
          _readyCompleter.complete();
        }

        _messageController.add(json);
      } catch (e) {
        // ignore non-JSON lines
      }
    }
  }

  void _processStderr(String data) {
    if (_isDisposed) return;

    if (!_readyCompleter.isCompleted && data.contains('[READY]')) {
      _readyCompleter.complete();
    }
  }

  void _handleStreamMessage(
    _PendingStreamRequest req,
    String? type,
    Map<String, dynamic> message,
  ) {
    if (type == 'token') {
      final token = message['data'] as String?;
      if (token != null) {
        req.accumulatedText.write(token);
        final currentText = req.accumulatedText.toString();

        bool shouldStop = false;
        for (final stopToken in req.stopTokens) {
          if (currentText.contains(stopToken)) {
            shouldStop = true;
            break;
          }
        }

        if (!shouldStop && req.hasStartedOutput && currentText.contains('###')) {
          shouldStop = true;
        }

        if (!shouldStop) {
          req.hasStartedOutput = true;
          if (!req.responseController.isClosed) {
            req.responseController.add(token);
          }
        } else {
          _completeStreamRequest(req.requestId);
        }
      }
    } else if (type == 'done') {
      _completeStreamRequest(req.requestId);
    } else if (type == 'error') {
      final error = message['data'] as String?;
      if (!req.responseController.isClosed) {
        req.responseController.addError(StateError(error ?? 'Unknown error'));
      }
      _completeStreamRequest(req.requestId);
    }
  }

  void _handlePendingMessage(
    _PendingRequest req,
    String? type,
    Map<String, dynamic> message,
  ) {
    if (type == req.responseType) {
      req.timeoutTimer?.cancel();
      req.completer.complete(message);
      req.subscription.cancel();
      _pendingRequests.remove(req.requestId);
    } else if (type == 'error') {
      req.timeoutTimer?.cancel();
      req.completer.completeError(
        StateError(message['data']?.toString() ?? 'Unknown error'),
      );
      req.subscription.cancel();
      _pendingRequests.remove(req.requestId);
    }
  }

  void _completeStreamRequest(String requestId) {
    final req = _pendingStreamRequests.remove(requestId);
    if (req != null) {
      req.timeoutTimer?.cancel();
      req.subscription.cancel();
      if (!req.responseController.isClosed) {
        req.responseController.close();
      }
    }
  }

  void _sendRequest(Map<String, dynamic> request) {
    if (_process == null || !_isReady || _isDisposed) {
      throw StateError('Model not loaded');
    }
    final requestJson = jsonEncode(request);
    _process!.stdin.writeln(requestJson);
    _process!.stdin.flush();
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) {
    if (_isDisposed) return Stream.error(StateError('DataSource is disposed'));
    if (_process == null || !_isReady) {
      return Stream.error(StateError('Model not loaded'));
    }

    final effectiveParams = params ?? InferenceParams.defaults;
    final stopTokens = effectiveParams.stop ?? [];
    final requestId = _nextRequestId();

    final request = <String, dynamic>{
      'requestId': requestId,
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

    final streamReq = _PendingStreamRequest(
      requestId: requestId,
      responseController: StreamController<String>(),
      stopTokens: stopTokens,
    );

    _pendingStreamRequests[requestId] = streamReq;

    streamReq.subscription = _messageController.stream.listen(
      (message) {
        final msgRequestId = message['requestId'] as String?;
        if (msgRequestId == requestId) {
          _handleStreamMessage(streamReq, message['type'] as String?, message);
        }
      },
      onError: (error) {
        if (!streamReq.responseController.isClosed) {
          streamReq.responseController.addError(error);
        }
        _completeStreamRequest(requestId);
      },
      onDone: () {
        _completeStreamRequest(requestId);
      },
    );

    streamReq.timeoutTimer = Timer(const Duration(minutes: 5), () {
      if (_pendingStreamRequests.containsKey(requestId)) {
        if (!streamReq.responseController.isClosed) {
          streamReq.responseController
              .addError(TimeoutException('Generate timeout'));
        }
        _completeStreamRequest(requestId);
      }
    });

    try {
      _sendRequest(request);
    } catch (e) {
      _completeStreamRequest(requestId);
      return Stream.error(e);
    }

    return streamReq.responseController.stream;
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

    for (final req in _pendingRequests.values.toList()) {
      req.timeoutTimer?.cancel();
      req.subscription.cancel();
      if (!req.completer.isCompleted) {
        req.completer.completeError(StateError('Disposed'));
      }
    }
    _pendingRequests.clear();

    for (final req in _pendingStreamRequests.values.toList()) {
      req.timeoutTimer?.cancel();
      req.subscription.cancel();
      if (!req.responseController.isClosed) {
        req.responseController.close();
      }
    }
    _pendingStreamRequests.clear();

    if (_process != null) {
      try {
        _process!.stdin.writeln(jsonEncode({'action': 'exit'}));
        await _process!.stdin.flush();
      } catch (e) {
        // ignore
      }

      await Future.delayed(const Duration(milliseconds: 500));
      _process!.kill();
      _process = null;
    }

    _isReady = false;
    await _messageController.close();
  }

  // ========== Dictionary ==========

  Future<Map<String, dynamic>?> _sendRequestWithId(
    Map<String, dynamic> request,
    String responseType, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_isDisposed) return null;
    if (_process == null || !_isReady) {
      return null;
    }

    final requestId = _nextRequestId();
    request['requestId'] = requestId;

    final completer = Completer<Map<String, dynamic>?>();
    final pending = _PendingRequest(
      requestId: requestId,
      responseType: responseType,
      completer: completer,
    );
    _pendingRequests[requestId] = pending;

    pending.subscription = _messageController.stream.listen(
      (message) {
        final msgRequestId = message['requestId'] as String?;
        if (msgRequestId == requestId) {
          _handlePendingMessage(pending, message['type'] as String?, message);
        }
      },
      onError: (error) {
        pending.timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
        pending.subscription.cancel();
        _pendingRequests.remove(requestId);
      },
      onDone: () {
        pending.timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        _pendingRequests.remove(requestId);
      },
    );

    pending.timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      pending.subscription.cancel();
      _pendingRequests.remove(requestId);
    });

    _sendRequest(request);

    return completer.future;
  }

  Future<String?> extractDictionary(String archivePath, String outputDir) async {
    final request = <String, dynamic>{
      'action': 'extract_dictionary',
      'archivePath': archivePath,
      'outputDir': outputDir,
    };

    final result = await _sendRequestWithId(request, 'extract_result');
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

    final result = await _sendRequestWithId(request, 'load_result');
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

    final result = await _sendRequestWithId(request, 'lookup_result');
    if (result != null && result['type'] == 'lookup_result') {
      return result['data'] as Map<String, dynamic>;
    }
    return null;
  }

  // ========== OPUS-MT ==========

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

    final result =
        await _sendRequestWithId(request, 'translate_result', timeout: const Duration(seconds: 60));
    if (result != null && result['type'] == 'translate_result') {
      final data = result['data'] as Map<String, dynamic>;
      if (data['success'] == true) {
        return data['text'] as String?;
      } else {
        throw StateError(data['error'] ?? 'Translation failed');
      }
    }
    throw TimeoutException('OPUS-MT translation timeout');
  }

  // ========== Model Download ==========

  Future<Map<String, bool>> checkDownloadSources() async {
    if (_isDisposed) return {};
    if (_process == null || !_isReady) {
      throw StateError('Server not ready');
    }

    final request = <String, dynamic>{
      'action': 'check_sources',
    };

    final result =
        await _sendRequestWithId(request, 'sources_result', timeout: const Duration(seconds: 15));
    if (result != null && result['type'] == 'sources_result') {
      final data = result['data'] as Map<String, dynamic>;
      return data.cast<String, bool>();
    }
    return {};
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

    final result = await _sendRequestWithId(
      request,
      'download_result',
      timeout: const Duration(minutes: 10),
    );
    if (result != null && result['type'] == 'download_result') {
      return result['data'] as Map<String, dynamic>;
    }
    return {'success': false, 'error': 'Download timeout'};
  }
}
