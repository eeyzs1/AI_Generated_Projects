import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:rfdictionary/features/llm/data/datasources/python_llm_datasource.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';

part 'model_manager.g.dart';

enum ModelType {
  opusMtEnZh,
  opusMtZhEn,

  marianMtEnDe,
  marianMtEnFr,
  marianMtEnEs,

  m2m100_418m,
}

enum ModelDownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

class ModelState {
  final ModelType type;
  final ModelDownloadStatus downloadStatus;
  final double downloadProgress;
  final int downloadedBytes;
  final int totalBytes;
  final String? downloadError;

  ModelState({
    required this.type,
    this.downloadStatus = ModelDownloadStatus.idle,
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.downloadError,
  });

  ModelState copyWith({
    ModelType? type,
    ModelDownloadStatus? downloadStatus,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    String? downloadError,
  }) {
    return ModelState(
      type: type ?? this.type,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadError: downloadError ?? this.downloadError,
    );
  }
}

class HardwareRequirements {
  final int minimumRamGb;
  final int recommendedRamGb;
  final int minimumStorageMb;
  final bool requiresCuda;

  const HardwareRequirements({
    required this.minimumRamGb,
    required this.recommendedRamGb,
    required this.minimumStorageMb,
    this.requiresCuda = false,
  });
}

extension ModelTypeExtension on ModelType {
  String get displayName {
    switch (this) {
      case ModelType.opusMtEnZh:
        return 'OPUS-MT en\u2192zh (\u82F1\u8BD1\u4E2D)';
      case ModelType.opusMtZhEn:
        return 'OPUS-MT zh\u2192en (\u4E2D\u8BD1\u82F1)';
      case ModelType.marianMtEnDe:
        return 'MarianMT en\u2192de (\u82F1\u8BED\u2192\u5FB7\u8BED)';
      case ModelType.marianMtEnFr:
        return 'MarianMT en\u2192fr (\u82F1\u8BED\u2192\u6CD5\u8BED)';
      case ModelType.marianMtEnEs:
        return 'MarianMT en\u2192es (\u82F1\u8BED\u2192\u897F\u73ED\u7259\u8BED)';
      case ModelType.m2m100_418m:
        return 'M2M-100 418M (\u591A\u8BED\u8A00\u7FFB\u8BD1)';
    }
  }

  String get description {
    switch (this) {
      case ModelType.opusMtEnZh:
      case ModelType.opusMtZhEn:
        return 'Encoder-Decoder \u67B6\u6784\uFF0C\u4E13\u4E3A\u4E2D\u82F1\u4E92\u8BD1\u4F18\u5316\n\u4E13\u4E3A\u957F\u53E5\u548C\u6BB5\u843D\u7FFB\u8BD1\u8BBE\u8BA1';
      case ModelType.marianMtEnDe:
      case ModelType.marianMtEnFr:
      case ModelType.marianMtEnEs:
        return 'MarianNMT \u7FFB\u8BD1\u6A21\u578B\n\u8D28\u91CF\u9AD8\u3001\u901F\u5EA6\u5FEB';
      case ModelType.m2m100_418m:
        return 'Facebook M2M-100 \u591A\u8BED\u8A00\u6A21\u578B\n\u652F\u6301 100+ \u8BED\u8A00\u4E92\u8BD1';
    }
  }

  String get folderName {
    switch (this) {
      case ModelType.opusMtEnZh:
        return 'opus-mt-en-zh';
      case ModelType.opusMtZhEn:
        return 'opus-mt-zh-en';
      case ModelType.marianMtEnDe:
        return 'marianmt-en-de';
      case ModelType.marianMtEnFr:
        return 'marianmt-en-fr';
      case ModelType.marianMtEnEs:
        return 'marianmt-en-es';
      case ModelType.m2m100_418m:
        return 'm2m100-418m';
    }
  }

  String get sizeInfo {
    switch (this) {
      case ModelType.opusMtEnZh:
      case ModelType.opusMtZhEn:
        return '\u7EA6150MB / ~150MB';
      case ModelType.marianMtEnDe:
      case ModelType.marianMtEnFr:
      case ModelType.marianMtEnEs:
        return '\u7EA6250MB / ~250MB';
      case ModelType.m2m100_418m:
        return '\u7EA61.5GB / ~1.5GB';
    }
  }

  int get approximateSizeBytes {
    switch (this) {
      case ModelType.opusMtEnZh:
      case ModelType.opusMtZhEn:
        return 150 * 1024 * 1024;
      case ModelType.marianMtEnDe:
      case ModelType.marianMtEnFr:
      case ModelType.marianMtEnEs:
        return 250 * 1024 * 1024;
      case ModelType.m2m100_418m:
        return 1500 * 1024 * 1024;
    }
  }

  String? get modelHubUrl {
    switch (this) {
      case ModelType.opusMtEnZh:
        return 'Helsinki-NLP/opus-mt-en-zh';
      case ModelType.opusMtZhEn:
        return 'Helsinki-NLP/opus-mt-zh-en';
      case ModelType.marianMtEnDe:
        return 'Helsinki-NLP/opus-mt-en-de';
      case ModelType.marianMtEnFr:
        return 'Helsinki-NLP/opus-mt-en-fr';
      case ModelType.marianMtEnEs:
        return 'Helsinki-NLP/opus-mt-en-es';
      case ModelType.m2m100_418m:
        return 'facebook/m2m100_418M';
    }
  }

  String? get modelScopeUrl {
    switch (this) {
      case ModelType.opusMtEnZh:
        return 'AI-ModelScope/opus-mt-en-zh';
      case ModelType.opusMtZhEn:
        return 'AI-ModelScope/opus-mt-zh-en';
      case ModelType.marianMtEnDe:
        return 'AI-ModelScope/marianmt-en-de';
      case ModelType.marianMtEnFr:
        return 'AI-ModelScope/marianmt-en-fr';
      case ModelType.marianMtEnEs:
        return 'AI-ModelScope/marianmt-en-es';
      case ModelType.m2m100_418m:
        return 'AI-ModelScope/m2m100-418m';
    }
  }

  List<String> get requiredFiles {
    if (this == ModelType.m2m100_418m) {
      return [
        'config.json',
        'pytorch_model.bin',
        'tokenizer.json',
        'vocab.json',
      ];
    }
    return [
      'config.json',
      'pytorch_model.bin',
      'source.spm',
      'target.spm',
      'vocab.json',
    ];
  }

  HardwareRequirements get hardwareRequirements {
    switch (this) {
      case ModelType.opusMtEnZh:
      case ModelType.opusMtZhEn:
        return const HardwareRequirements(
          minimumRamGb: 2,
          recommendedRamGb: 4,
          minimumStorageMb: 300,
        );
      case ModelType.marianMtEnDe:
      case ModelType.marianMtEnFr:
      case ModelType.marianMtEnEs:
        return const HardwareRequirements(
          minimumRamGb: 3,
          recommendedRamGb: 6,
          minimumStorageMb: 500,
        );
      case ModelType.m2m100_418m:
        return const HardwareRequirements(
          minimumRamGb: 6,
          recommendedRamGb: 12,
          minimumStorageMb: 3000,
        );
    }
  }
}

@Riverpod(keepAlive: true)
class ModelManager extends _$ModelManager {
  static const String _kSelectedModelKey = 'selected_model';
  static const String _kModelsPathKey = 'models_path';

  CancelToken? _cancelToken;
  Ref get _ref => ref;

  @override
  ModelState build() {
    return ModelState(type: ModelType.opusMtEnZh);
  }

  Future<void> loadSavedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_kSelectedModelKey);
    if (index != null && index >= 0 && index < ModelType.values.length) {
      state = state.copyWith(type: ModelType.values[index]);
    }
  }

  Future<void> selectModel(ModelType model) async {
    state = state.copyWith(type: model);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSelectedModelKey, model.index);
  }

  Future<void> setModelsPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModelsPathKey, path);
  }

  Future<String?> getSavedModelsPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kModelsPathKey);
  }

  Future<Directory> getModelsDirectory() async {
    final savedPath = await getSavedModelsPath();
    if (savedPath != null && Directory(savedPath).existsSync()) {
      return Directory(savedPath);
    }

    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(dir.path, 'models', 'translation'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<bool> isModelDownloaded(ModelType modelType) async {
    final modelsDir = await getModelsDirectory();
    final modelDir = Directory(path.join(modelsDir.path, modelType.folderName));

    if (!await modelDir.exists()) {
      return false;
    }

    for (final file in modelType.requiredFiles) {
      final filePath = File(path.join(modelDir.path, file));
      if (!await filePath.exists()) {
        return false;
      }
    }

    return true;
  }

  Future<bool> isModelAvailable(ModelType modelType) async {
    return isModelDownloaded(modelType);
  }

  Future<bool> isAnyModelDownloaded() async {
    for (final type in ModelType.values) {
      if (await isModelDownloaded(type)) {
        return true;
      }
    }
    return false;
  }

  Future<void> deleteModel(ModelType modelType) async {
    final modelsDir = await getModelsDirectory();
    final modelDir = Directory(path.join(modelsDir.path, modelType.folderName));

    try {
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
      }

      if (state.type == modelType) {
        ModelType? newSelectedModel;

        for (final type in ModelType.values) {
          if (type != modelType) {
            final isDownloaded = await isModelDownloaded(type);
            if (isDownloaded) {
              newSelectedModel = type;
              break;
            }
          }
        }

        if (newSelectedModel != null) {
          await selectModel(newSelectedModel);
        } else {
          await selectModel(ModelType.values.first);
        }
      }
    } catch (e) {
      debugPrint('Error deleting model: $e');
    }
  }

  Future<String?> getValidModelPath(ModelType modelType) async {
    final modelsDir = await getModelsDirectory();
    final modelDir = Directory(path.join(modelsDir.path, modelType.folderName));

    if (await modelDir.exists()) {
      return modelDir.path;
    }

    return null;
  }

  Future<String?> getModelPath(ModelType modelType) async {
    return getValidModelPath(modelType);
  }

  Future<void> startDownload({String? customDirectory}) async {
    if (state.downloadStatus == ModelDownloadStatus.downloading) {
      return;
    }

    if (state.type.modelHubUrl == null) {
      state = state.copyWith(
        downloadStatus: ModelDownloadStatus.failed,
        downloadError: '\u8BE5\u6A21\u578B\u6682\u4E0D\u652F\u6301\u76F4\u63A5\u4E0B\u8F7D',
      );
      return;
    }

    state = state.copyWith(
      downloadStatus: ModelDownloadStatus.downloading,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: state.type.approximateSizeBytes,
      downloadError: null,
    );
    _cancelToken = CancelToken();

    try {
      String savePath;

      if (customDirectory != null && Directory(customDirectory).existsSync()) {
        savePath = path.join(customDirectory, state.type.folderName);
      } else {
        final modelsDir = await getModelsDirectory();
        savePath = path.join(modelsDir.path, state.type.folderName);
      }

      final saveDir = Directory(savePath);
      if (await saveDir.exists()) {
        await saveDir.delete(recursive: true);
      }
      await saveDir.create(recursive: true);

      final success = await _downloadViaPythonBackend(
        state.type.modelHubUrl!,
        savePath,
      );

      if (success) {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.completed,
          downloadProgress: 1.0,
        );
      } else {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.failed,
          downloadError: '\u4E0B\u8F7D\u5931\u8D25\uFF0C\u8BF7\u91CD\u8BD5',
        );
      }
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.idle,
          downloadError: '\u4E0B\u8F7D\u5DF2\u53D6\u6D88',
        );
      } else {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.failed,
          downloadError: '\u4E0B\u8F7D\u5931\u8D25: ${e.toString()}',
        );
      }
    }
  }

  Future<bool> _downloadViaPythonBackend(String repoId, String savePath) async {
    try {
      final llmDataSource = _ref.read(llmDataSourceProvider);
      if (llmDataSource is PythonLlmDataSource) {
        final result = await llmDataSource.downloadModel(
          modelType: state.type.name,
          savePath: savePath,
          autoDetect: true,
        );
        return result['success'] == true;
      }

      final hubUrl = state.type.modelHubUrl;
      if (hubUrl == null) return false;

      final dio = Dio();
      final tempPath = '$savePath.tmp';

      if (File(tempPath).existsSync()) {
        await File(tempPath).delete();
      }

      await dio.download(
        'https://huggingface.co/$hubUrl/resolve/main/config.json',
        path.join(savePath, 'config.json'),
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(
              downloadProgress: received / total * 0.1,
              downloadedBytes: received,
            );
          }
        },
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }

  void resetDownload() {
    state = state.copyWith(
      downloadStatus: ModelDownloadStatus.idle,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: 0,
      downloadError: null,
    );
  }
}
