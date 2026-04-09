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
  String? _selectedSource;
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
      debugPrint('Error checking sources: $e');
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

    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
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
                content: Text('\u4E0B\u8F7D\u6210\u529F\uFF01\u4F7F\u7528\u6E90: ${result['source']}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('\u4E0B\u8F7D\u5931\u8D25: ${result['error']}'),
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
            content: Text('\u4E0B\u8F7D\u51FA\u9519: $e'),
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

  Widget _buildSourceOption(String value, String label, String description) {
    final isAvailable = _sourceAvailability?[value] ?? false;

    return RadioGroup<String>(
      groupValue: _selectedSource,
      onChanged: _isDownloading
          ? (_) {}
          : (value) {
              setState(() {
                _selectedSource = value;
              });
            },
      child: RadioListTile<String>(
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
                  isAvailable ? '\u53EF\u7528 / OK' : '\u4E0D\u53EF\u7528 / Down',
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
      ),
    );
  }

  Widget _buildHardwareRequirements(HardwareRequirements req) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u786C\u4EF6\u8981\u6C42 / Hardware Requirements',
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
                  '\u5185\u5B58 / RAM',
                  '\u6700\u4F4E ${req.minimumRamGb}GB / \u63A8\u8350 ${req.recommendedRamGb}GB',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRequirementItem(
                  Icons.storage,
                  '\u5B58\u50A8 / Storage',
                  '\u9700\u8981 ${req.minimumStorageMb}MB',
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
            tooltip: '\u5237\u65B0 / Refresh',
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\u7FFB\u8BD1\u6A21\u578B / Translation Models',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...ModelType.values.map((type) {
                        final isDownloaded = downloadedModels[type] ?? false;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RadioGroup<ModelType>(
                                groupValue: modelState.type,
                                onChanged: _isDownloading
                                    ? (_) {}
                                    : (value) {
                                        if (value != null) {
                                          modelManager.selectModel(value);
                                        }
                                      },
                                child: RadioListTile<ModelType>(
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
                                ),
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

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '\u4E0B\u8F7D\u6E90 / Download Source',
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
                        '\u81EA\u52A8\u68C0\u6D4B / Auto Detect',
                        '\u81EA\u52A8\u9009\u62E9\u6700\u4F73\u4E0B\u8F7D\u6E90',
                      ),
                      _buildSourceOption(
                        'huggingface',
                        'Hugging Face',
                        '\u5B98\u65B9\u6E90\uFF08\u53EF\u80FD\u9700\u8981\u4EE3\u7406\uFF09',
                      ),
                      _buildSourceOption(
                        'modelscope',
                        'ModelScope\uFF08\u963F\u91CC\uFF09',
                        '\u963F\u91CC\u4E91\u6A21\u578B\u5E93\uFF08\u56FD\u5185\u63A8\u8350\uFF09',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

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

              if (_isDownloading)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\u6B63\u5728\u4E0B\u8F7D / Downloading...',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        const Text(
                          '\u8BF7\u8010\u5FC3\u7B49\u5F85\n\u8BF7\u67E5\u770B\u63A7\u5236\u53F0\u83B7\u53D6\u8BE6\u7EC6\u4FE1\u606F',
                        ),
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
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: RadioGroup<ModelType>(
                                    groupValue: modelState.type,
                                    onChanged: _isDownloading
                                        ? (_) {}
                                        : (value) {
                                            if (value != null) {
                                              modelManager.selectModel(value);
                                            }
                                          },
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
                                    ),
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
                        '\u67B6\u6784\u8BF4\u660E / Architecture Overview\n\n'
                        '\u2022 Encoder-Decoder \u67B6\u6784\u6A21\u578B\uFF0C\u4E13\u4E3A\u957F\u53E5\u7FFB\u8BD1\u4F18\u5316\n\n'
                        '\u7FFB\u8BD1\u6D41\u7A0B / Translation Flow:\n'
                        '1. \u5355\u8BCD/\u77ED\u8BED \u2192 StarDict \u8BCD\u5178\n'
                        '2. \u957F\u53E5/\u6BB5\u843D \u2192 Encoder-Decoder \u6A21\u578B\n'
                        '3. \u8BCD\u5178\u672A\u627E\u5230 \u2192 Encoder-Decoder \u6A21\u578B\u5151\u5E95',
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
