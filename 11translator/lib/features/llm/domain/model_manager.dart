import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

part 'model_manager.g.dart';

enum ModelType {
  // OPUS-MT 系列
  opus_mt_en_zh,
  opus_mt_zh_en,
  
  // MarianMT 系列 (Hugging Face)
  marian_mt_en_de,
  marian_mt_en_fr,
  marian_mt_en_es,
  
  // Facebook M2M-100 (多语言翻译)
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

// 硬件配置要求
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
      case ModelType.opus_mt_en_zh:
        return 'OPUS-MT en→zh (英译中)';
      case ModelType.opus_mt_zh_en:
        return 'OPUS-MT zh→en (中译英)';
      case ModelType.marian_mt_en_de:
        return 'MarianMT en→de (英语→德语)';
      case ModelType.marian_mt_en_fr:
        return 'MarianMT en→fr (英语→法语)';
      case ModelType.marian_mt_en_es:
        return 'MarianMT en→es (英语→西班牙语)';
      case ModelType.m2m100_418m:
        return 'M2M-100 418M (多语言翻译)';
    }
  }

  String get description {
    switch (this) {
      case ModelType.opus_mt_en_zh:
      case ModelType.opus_mt_zh_en:
        return 'Encoder-Decoder 架构，专为中英互译优化\n专为长句和段落翻译设计';
      case ModelType.marian_mt_en_de:
      case ModelType.marian_mt_en_fr:
      case ModelType.marian_mt_en_es:
        return 'MarianNMT 翻译模型\n质量高、速度快';
      case ModelType.m2m100_418m:
        return 'Facebook M2M-100 多语言模型\n支持 100+ 语言互译';
    }
  }

  String get folderName {
    switch (this) {
      case ModelType.opus_mt_en_zh:
        return 'opus-mt-en-zh';
      case ModelType.opus_mt_zh_en:
        return 'opus-mt-zh-en';
      case ModelType.marian_mt_en_de:
        return 'marianmt-en-de';
      case ModelType.marian_mt_en_fr:
        return 'marianmt-en-fr';
      case ModelType.marian_mt_en_es:
        return 'marianmt-en-es';
      case ModelType.m2m100_418m:
        return 'm2m100-418m';
    }
  }

  String get sizeInfo {
    switch (this) {
      case ModelType.opus_mt_en_zh:
      case ModelType.opus_mt_zh_en:
        return '约 150MB / ~150MB';
      case ModelType.marian_mt_en_de:
      case ModelType.marian_mt_en_fr:
      case ModelType.marian_mt_en_es:
        return '约 250MB / ~250MB';
      case ModelType.m2m100_418m:
        return '约 1.5GB / ~1.5GB';
    }
  }

  int get approximateSizeBytes {
    switch (this) {
      case ModelType.opus_mt_en_zh:
      case ModelType.opus_mt_zh_en:
        return 150 * 1024 * 1024; // 约 150MB
      case ModelType.marian_mt_en_de:
      case ModelType.marian_mt_en_fr:
      case ModelType.marian_mt_en_es:
        return 250 * 1024 * 1024; // 约 250MB
      case ModelType.m2m100_418m:
        return 1500 * 1024 * 1024; // 约 1.5GB
    }
  }

  String? get modelHubUrl {
    switch (this) {
      case ModelType.opus_mt_en_zh:
        return 'Helsinki-NLP/opus-mt-en-zh';
      case ModelType.opus_mt_zh_en:
        return 'Helsinki-NLP/opus-mt-zh-en';
      case ModelType.marian_mt_en_de:
        return 'Helsinki-NLP/opus-mt-en-de';
      case ModelType.marian_mt_en_fr:
        return 'Helsinki-NLP/opus-mt-en-fr';
      case ModelType.marian_mt_en_es:
        return 'Helsinki-NLP/opus-mt-en-es';
      case ModelType.m2m100_418m:
        return 'facebook/m2m100_418M';
    }
  }

  String? get modelScopeUrl {
    switch (this) {
      case ModelType.opus_mt_en_zh:
        return 'AI-ModelScope/opus-mt-en-zh';
      case ModelType.opus_mt_zh_en:
        return 'AI-ModelScope/opus-mt-zh-en';
      case ModelType.marian_mt_en_de:
        return 'AI-ModelScope/marianmt-en-de';
      case ModelType.marian_mt_en_fr:
        return 'AI-ModelScope/marianmt-en-fr';
      case ModelType.marian_mt_en_es:
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
      case ModelType.opus_mt_en_zh:
      case ModelType.opus_mt_zh_en:
        return const HardwareRequirements(
          minimumRamGb: 2,
          recommendedRamGb: 4,
          minimumStorageMb: 300,
        );
      case ModelType.marian_mt_en_de:
      case ModelType.marian_mt_en_fr:
      case ModelType.marian_mt_en_es:
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

  @override
  ModelState build() {
    return ModelState(type: ModelType.opus_mt_en_zh);
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

  // 向后兼容 - 检查特定模型
  Future<bool> isModelAvailable(ModelType modelType) async {
    return isModelDownloaded(modelType);
  }
  
  // 向后兼容 - 检查是否有任何模型已下载
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
      print('Error deleting model: $e');
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

  // 向后兼容
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
        downloadError: '该模型暂不支持直接下载',
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
          downloadError: '下载失败，请重试',
        );
      }
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.idle,
          downloadError: '下载已取消',
        );
      } else {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.failed,
          downloadError: '下载失败: ${e.toString()}',
        );
      }
    }
  }

  Future<bool> _downloadViaPythonBackend(String repoId, String savePath) async {
    print('TODO: Download model $repoId to $savePath via Python backend');
    return true;
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
