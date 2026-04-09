import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rfdictionary/features/dictionary/domain/dictionary_manager.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';

class DictionaryManagerScreen extends ConsumerStatefulWidget {
  const DictionaryManagerScreen({super.key});

  @override
  ConsumerState<DictionaryManagerScreen> createState() => _DictionaryManagerScreenState();
}

class _DictionaryManagerScreenState extends ConsumerState<DictionaryManagerScreen> {
  @override
  void initState() {
    super.initState();
    _loadDictionaryStatus();
  }

  Future<void> _loadDictionaryStatus() async {
    final manager = ref.read(dictionaryManagerProvider.notifier);
    await manager.getDictionaryPath();
    await manager.isDictionaryAvailable();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startDownload() async {
    final l10n = AppLocalizations.of(context);
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.downloadDictionary,
    );

    final manager = ref.read(dictionaryManagerProvider.notifier);
    await manager.startDownload(customDirectory: selectedDirectory);
  }

  void _cancelDownload() {
    final manager = ref.read(dictionaryManagerProvider.notifier);
    manager.cancelDownload();
  }

  void _resetDownload() {
    final manager = ref.read(dictionaryManagerProvider.notifier);
    manager.resetDownload();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Set<LanguagePair> _getAvailableLanguagePairs(Set<DictionaryType> selectedDictionaries) {
    final pairs = <LanguagePair>{};
    for (final dict in selectedDictionaries) {
      final pair = dict.languagePair;
      if (pair != null) {
        pairs.add(pair);
      }
    }
    return pairs;
  }

  Future<Map<DictionaryType, bool>> _getDownloadedDictionaries(DictionaryManager manager) async {
    final downloaded = <DictionaryType, bool>{};
    for (final type in DictionaryType.values) {
      final path = await _getDictionaryPathForType(type);
      downloaded[type] = path != null && File(path).existsSync();
    }
    return downloaded;
  }

  Future<String?> _getDictionaryPathForType(DictionaryType type) async {
    final dir = await getApplicationDocumentsDirectory();
    final defaultPath = path.join(dir.path, type.fileName);
    if (File(defaultPath).existsSync()) {
      return defaultPath;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dictState = ref.watch(dictionaryManagerProvider);
    final manager = ref.read(dictionaryManagerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dictionaryManagement),
      ),
      body: FutureBuilder<Map<DictionaryType, bool>>(
        future: _getDownloadedDictionaries(manager),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final downloadedDicts = snapshot.data!;
          final downloadedDictTypes = DictionaryType.values.where((type) => downloadedDicts[type] ?? false).toList();

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
                        l10n.selectDictionary,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ...DictionaryType.values.map((type) {
                        final isDownloaded = downloadedDicts[type] ?? false;
                        return RadioGroup<DictionaryType>(
                          groupValue: dictState.type,
                          onChanged: dictState.downloadStatus == DownloadStatus.downloading
                              ? (_) {}
                              : (value) {
                                  if (value != null) {
                                    manager.selectDictionary(value).then((_) => _loadDictionaryStatus());
                                  }
                                },
                          child: RadioListTile<DictionaryType>(
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
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (dictState.downloadStatus != DownloadStatus.idle)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.downloadStatus,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),

                        if (dictState.downloadStatus == DownloadStatus.downloading) ...[
                          LinearProgressIndicator(
                            value: dictState.downloadProgress,
                            minHeight: 8,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(dictState.downloadProgress * 100).toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_formatBytes(dictState.downloadedBytes)} / ${_formatBytes(dictState.totalBytes)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _cancelDownload,
                              icon: const Icon(Icons.cancel),
                              label: Text(l10n.cancelDownload),
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.error,
                                foregroundColor: Theme.of(context).colorScheme.onError,
                              ),
                            ),
                          ),
                        ] else if (dictState.downloadStatus == DownloadStatus.completed) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.downloadCompleted,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      '${l10n.fileSize}: ${_formatBytes(dictState.totalBytes)}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    _resetDownload();
                                    await _loadDictionaryStatus();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l10n.reset),
                                ),
                              ),
                            ],
                          ),
                        ] else if (dictState.downloadStatus == DownloadStatus.failed) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.error,
                                color: Theme.of(context).colorScheme.error,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.downloadFailed,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                    if (dictState.downloadError != null)
                                      Text(
                                        dictState.downloadError!,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _startDownload,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l10n.retry),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _resetDownload,
                                  icon: const Icon(Icons.clear),
                                  label: Text(l10n.clear),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              if (dictState.downloadStatus == DownloadStatus.idle)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.downloadDictionary,
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
                            onPressed: dictState.type.downloadUrl == null || (downloadedDicts[dictState.type] ?? false)
                                ? null
                                : _startDownload,
                            icon: const Icon(Icons.download),
                            label: Text(l10n.startDownload),
                          ),
                        ),
                        if (dictState.type.downloadUrl == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.pleaseSelectDictionary,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (downloadedDicts[dictState.type] ?? false)
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

              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Installed Dictionaries / \u9009\u62E9\u5DF2\u5B89\u88C5\u7684\u8BCD\u5178',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\u9009\u62E9\u8981\u4F7F\u7528\u7684\u8BCD\u5178\uFF08\u53EF\u591A\u9009\uFF09',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (downloadedDictTypes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            l10n.pleaseSelectDictionary,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      else
                        ...downloadedDictTypes.map((type) {
                          final isSelected = dictState.selectedDictionaries.contains(type);
                          return CheckboxListTile(
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
                            value: isSelected,
                            onChanged: dictState.downloadStatus == DownloadStatus.downloading
                                ? null
                                : (value) async {
                                    await manager.toggleDictionarySelection(type);
                                  },
                          );
                        }),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Available Language Pairs / \u53EF\u7528\u7684\u8BED\u8A00\u5BF9',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      ..._getAvailableLanguagePairs(dictState.selectedDictionaries).map((pair) {
                        return ListTile(
                          leading: const Icon(Icons.translate),
                          title: Text(pair.displayName),
                        );
                      }),
                      if (_getAvailableLanguagePairs(dictState.selectedDictionaries).isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            '\u8BF7\u5148\u9009\u62E9\u8BCD\u5178 / Please select dictionaries first',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
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
                        l10n.usageInstructions,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${l10n.step1SelectDictionary}\n'
                        '${l10n.step2DownloadDictionary}\n'
                        '${l10n.step3SupportedDictionaryFormats}\n\n'
                        '${l10n.dictionaryRecommendations}\n'
                        '${l10n.ecdictDesc}\n'
                        '${l10n.wiktionaryDesc}\n\n'
                        '${l10n.noDictionaryWarning}',
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
}
