import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'model_manager.g.dart';

enum ModelType {
  qwen25_05b,
  qwen25_15b,
}

extension ModelTypeExtension on ModelType {
  String get displayName {
    switch (this) {
      case ModelType.qwen25_05b:
        return 'Qwen2.5-0.5B (轻量)';
      case ModelType.qwen25_15b:
        return 'Qwen2.5-1.5B (推荐)';
    }
  }

  String get assetPath {
    switch (this) {
      case ModelType.qwen25_05b:
        return 'assets/qwen2.5-0.5b-instruct-q4_k_m.gguf';
      case ModelType.qwen25_15b:
        return 'assets/qwen2.5-1.5b-instruct-q4_k_m.gguf';
    }
  }

  String get fileName {
    switch (this) {
      case ModelType.qwen25_05b:
        return 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
      case ModelType.qwen25_15b:
        return 'qwen2.5-1.5b-instruct-q4_k_m.gguf';
    }
  }

  String get sizeInfo {
    switch (this) {
      case ModelType.qwen25_05b:
        return '约 400MB';
      case ModelType.qwen25_15b:
        return '约 900MB';
    }
  }
}

@riverpod
class ModelManager extends _$ModelManager {
  static const String _kSelectedModelKey = 'selected_model';
  
  @override
  ModelType build() {
    return ModelType.qwen25_05b;
  }

  Future<void> loadSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_kSelectedModelKey);
    if (index != null && index >= 0 && index < ModelType.values.length) {
      state = ModelType.values[index];
    }
  }

  Future<void> selectModel(ModelType model) async {
    state = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSelectedModelKey, model.index);
  }

  Future<String> getModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelPath = path.join(dir.path, state.fileName);
    
    // 如果文件不存在，从 assets 复制
    if (!File(modelPath).existsSync()) {
      await _copyModelFromAssets(modelPath);
    }
    
    return modelPath;
  }

  Future<void> _copyModelFromAssets(String destinationPath) async {
    final data = await rootBundle.load(state.assetPath);
    final bytes = data.buffer.asUint8List();
    await File(destinationPath).writeAsBytes(bytes);
  }
}
