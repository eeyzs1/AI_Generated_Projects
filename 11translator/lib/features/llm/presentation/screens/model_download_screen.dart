import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rfdictionary/features/llm/domain/model_manager.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';
import 'package:rfdictionary/features/llm/data/datasources/python_llm_datasource.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';

class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  String? _selectedSource; // 'auto', 'huggingface', 'modelscope'
  Map<String, bool>? _sourceAvailability;
  bool _isCheckingSources = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _selectedSource = 'auto';
    _checkSources();
  }

  Future<void> _checkSources() async {
    setState(() {
      _isCheckingSources = true;
    });

    try {
      final llmService = ref.read(llmServiceProvider.notifier);
      final dataSource = llmService.dataSource;
      
      if (dataSource is PythonLlmDataSource) {
        final sources = await dataSource.checkDownloadSources();
        setState(() {
          _sourceAvailability = sources;
        });
      }
    } catch (e) {
      print('Error checking sources: $e');
    } finally {
      setState(() {
        _isCheckingSources = false;
      });
    }
  }

  Future<void> _startDownload() async {
    final l10n = AppLocalizations.of(context);
    final modelManager = ref.read(modelManagerProvider.notifier);
    final modelState = ref.read(modelManagerProvider);
    
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.downloadModel,
    );

    setState(() {
      _isDownloading = true;
    });

    try {
      String savePath;
      
      if (selectedDirectory != null && Directory(selectedDirectory).existsSync()) {
        savePath = path.join(selectedDirectory, modelState.type.folderName);
      } else {
        final modelsDir = await modelManager.getModelsDirectory();
        savePath = path.join(modelsDir.path, modelState.type.folderName);
      }
      
      final saveDir = Directory(savePath);
      if (await saveDir.exists()) {
        await saveDir.delete(recursive: true);
      }
      await saveDir.create(recursive: true);

      final llmService = ref.read(llmServiceProvider.notifier);
      final dataSource = llmService.dataSource;
      
      if (dataSource is PythonLlmDataSource) {
        String? source;
        bool autoDetect = true;
        
        if (_selectedSource != 'auto') {
          source = _selectedSource;
          autoDetect = false;
        }
        
        final result = await dataSource.downloadModel(
          modelType: modelState.type.name,
          savePath: savePath,
          source: source,
          autoDetect: autoDetect,
        );
        
        if (result['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('下载成功！使用源: ${result['source']}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('下载失败: ${result['error']}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载出错: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildSourceOption(String value, String label, String description) {
    final isAvailable = _sourceAvailability?[value] ?? false;
    final isSelected = _selectedSource == value;
    
    return RadioListTile<String>(
      title: Row(
        children: [
          Text(label),
          const SizedBox(width: 8),
          if (_sourceAvailability != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isAvailable ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isAvailable ? '可用 / OK' : '不可用 / Down',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(description),
      value: value,
      groupValue: _selectedSource,
      onChanged: _isDownloading
          ? null
          : (value) {
              setState(() {
                _selectedSource = value;
              });
            },
    );
  }

  Widget _buildHardwareRequirements(HardwareRequirements req) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '硬件要求 / Hardware Requirements',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRequirementItem(
                  Icons.memory,
                  '内存 / RAM',
                  '最低 ${req.minimumRamGb}GB / 推荐 ${req.recommendedRamGb}GB',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRequirementItem(
                  Icons.storage,
                  '存储 / Storage',
                  '需要 ${req.minimumStorageMb}MB',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final modelState = ref.watch(modelManagerProvider);
    final modelManager = ref.read(modelManagerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiModel),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isCheckingSources ? null : _checkSources,
            tooltip: '刷新 / Refresh',
          ),
        ],
      ),
      body: FutureBuilder<Map<ModelType, bool>>(
        future: _getDownloadedModels(modelManager),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final downloadedModels = snapshot.data!;
          final downloadedModelTypes = ModelType.values.where((type) => downloadedModels[type] ?? false).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 模型选择
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '翻译模型 / Translation Models',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...ModelType.values.map((type) {
                        final isSelected = type == modelState.type;
                        final isDownloaded = downloadedModels[type] ?? false;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RadioListTile<ModelType>(
                                title: Text(type.displayName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(type.description),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${l10n.fileSize}: ${type.sizeInfo}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.secondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isDownloaded)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              l10n.installed,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                value: type,
                                groupValue: modelState.type,
                                onChanged: _isDownloading
                                    ? null
                                    : (value) async {
                                        if (value != null) {
                                          await modelManager.selectModel(value);
                                        }
                                      },
                              ),
                              _buildHardwareRequirements(type.hardwareRequirements),
                              if (type != ModelType.values.last)
                                const Divider(height: 24),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 下载源选择
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '下载源 / Download Source',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_isCheckingSources)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSourceOption(
                        'auto',
                        '自动检测 / Auto Detect',
                        '自动选择最佳下载源',
                      ),
                      _buildSourceOption(
                        'huggingface',
                        'Hugging Face',
                        '官方源（可能需要代理）',
                      ),
                      _buildSourceOption(
                        'modelscope',
                        'ModelScope（阿里）',
                        '阿里云模型库（国内推荐）',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 下载按钮
              if (!_isDownloading)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.downloadModel,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.downloadingInBackground,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: (downloadedModels[modelState.type] ?? false)
                                ? null
                                : _startDownload,
                            icon: const Icon(Icons.download),
                            label: Text(l10n.startDownload),
                          ),
                        ),
                        if (downloadedModels[modelState.type] ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.modelAlreadyInstalled,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              
              // 下载中状态
              if (_isDownloading)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '正在下载 / Downloading...',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        const Text(
                          '请耐心等待\n请查看控制台获取详细信息',
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // 已安装模型列表
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.selectModel,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (downloadedModelTypes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            l10n.pleaseSelectModel,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      else
                        ...downloadedModelTypes.map((type) {
                          final isSelected = type == modelState.type;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<ModelType>(
                                    title: Text(type.displayName),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(type.description),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${l10n.fileSize}: ${type.sizeInfo}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.secondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    value: type,
                                    groupValue: modelState.type,
                                    onChanged: _isDownloading
                                        ? null
                                        : (value) async {
                                            if (value != null) {
                                              await modelManager.selectModel(value);
                                            }
                                          },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: _isDownloading
                                      ? null
                                      : () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text(l10n.deleteModel),
                                              content: Text('${l10n.deleteModelConfirm} ${type.displayName}?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: Text(l10n.cancel),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                          
                                          if (confirm == true) {
                                            await modelManager.deleteModel(type);
                                            await Future.delayed(const Duration(milliseconds: 100));
                                            if (mounted) {
                                              setState(() {});
                                            }
                                          }
                                        },
                                  tooltip: l10n.delete,
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.usageInstructions,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '架构说明 / Architecture Overview\n\n'
                        '• Encoder-Decoder 架构模型，专为长句翻译优化\n\n'
                        '翻译流程 / Translation Flow:\n'
                        '1. 单词/短语 → StarDict 词典\n'
                        '2. 长句/段落 → Encoder-Decoder 模型\n'
                        '3. 词典未找到 → Encoder-Decoder 模型兜底',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<ModelType, bool>> _getDownloadedModels(ModelManager manager) async {
    final downloaded = <ModelType, bool>{};
    for (final type in ModelType.values) {
      downloaded[type] = await manager.isModelDownloaded(type);
    }
    return downloaded;
  }
}
