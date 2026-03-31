import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/thumbnail_provider.dart';
import '../../../data/models/play_history.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_localizations.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.history),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              _showClearHistoryDialog(context);
            },
          ),
        ],
      ),
      body: _buildHistoryList(),
    );
  }

  Widget _buildHistoryList() {
    final historyRepository = ref.watch(historyRepositoryProvider);
    return FutureBuilder<List<PlayHistory>>(
      key: ValueKey(_refreshKey),
      future: historyRepository.getHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final localizations = AppLocalizations.of(context)!;
          return Center(child: Text(localizations.loadingFailed));
        }
        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          final localizations = AppLocalizations.of(context)!;
          return Center(child: Text(localizations.noRecentPlays));
        }
        return ListView.builder(
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return Consumer(
              builder: (context, ref, child) {
                final thumbnail = ref.watch(thumbnailGeneratorProvider(item.path));
                return ListTile(
                  leading: thumbnail.when(
                    data: (path) {
                      if (path != null) {
                        return Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                          ),
                          child: Image.file(
                            File(path),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                item.type == MediaType.video ? Icons.video_library : Icons.image,
                                size: 40,
                              );
                            },
                          ),
                        );
                      } else {
                        return Icon(
                          item.type == MediaType.video ? Icons.video_library : Icons.image,
                          size: 40,
                        );
                      }
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (error, stackTrace) {
                      return Icon(
                        item.type == MediaType.video ? Icons.video_library : Icons.image,
                        size: 40,
                      );
                    },
                  ),
                  title: Text(item.displayName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.path),
                      Text(item.progressString),
                      Text(
                        '最后播放: ${item.lastPlayedAt.toString().substring(0, 19)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      await ref.read(historyRepositoryProvider).deleteById(item.id);
                      setState(() {
                        _refreshKey++;
                      });
                    },
                  ),
                  onTap: () {
                    if (item.type == MediaType.video) {
                      GoRouter.of(context).push('/video-player', extra: item.path);
                    } else {
                      GoRouter.of(context).push('/image-viewer', extra: item.path);
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.clearAll),
        content: Text(localizations.sureToClearAll),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(historyRepositoryProvider).deleteAll();
              Navigator.of(context).pop();
              setState(() {
                _refreshKey++;
              });
            },
            child: Text(localizations.confirm),
          ),
        ],
      ),
    );
  }
}