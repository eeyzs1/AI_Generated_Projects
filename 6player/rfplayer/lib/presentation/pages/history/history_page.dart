import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../../data/models/play_history.dart';
import 'package:go_router/go_router.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('最近播放'),
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
          return const Center(child: Text('加载失败'));
        }
        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return const Center(child: Text('暂无播放历史'));
        }
        return ListView.builder(
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return ListTile(
              leading: Icon(
                item.type == MediaType.video ? Icons.video_library : Icons.image,
                size: 40,
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
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定要清空所有播放历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(historyRepositoryProvider).deleteAll();
              Navigator.of(context).pop();
              setState(() {
                _refreshKey++;
              });
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}