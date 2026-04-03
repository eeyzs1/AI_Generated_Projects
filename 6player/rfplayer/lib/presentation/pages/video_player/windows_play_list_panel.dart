import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../presentation/providers/play_queue_provider.dart';
import 'play_list_item.dart';

class WindowsPlayListPanel extends ConsumerStatefulWidget {
  const WindowsPlayListPanel({super.key});

  @override
  ConsumerState<WindowsPlayListPanel> createState() => _WindowsPlayListPanelState();
}

class _WindowsPlayListPanelState extends ConsumerState<WindowsPlayListPanel> {
  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(playQueueProvider);
    final playQueueNotifier = ref.read(playQueueProvider.notifier);

    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey[300]!)),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        children: [
          // 面板标题
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('播放列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    playQueueNotifier.clearQueue();
                  },
                ),
              ],
            ),
          ),
          // 播放队列列表
          Expanded(
            child: ReorderableListView.builder(
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final item = queue[index];
                return PlayListItem(
                  key: ValueKey(item.id),
                  item: item,
                  index: index,
                  isPlaying: item.isCurrentPlaying,
                  onTap: () => playQueueNotifier.playItem(item.id),
                  onDelete: () => playQueueNotifier.removeFromQueue(item.id),
                );
              },
              onReorder: (oldIndex, newIndex) {
                playQueueNotifier.reorderQueue(oldIndex, newIndex);
              },
            ),
          ),
          // 控制按钮
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => playQueueNotifier.playPrevious(),
                  child: const Text('上一个'),
                ),
                ElevatedButton(
                  onPressed: () => playQueueNotifier.playNext(),
                  child: const Text('下一个'),
                ),
                ElevatedButton(
                  onPressed: () => playQueueNotifier.clearQueue(),
                  child: const Text('清空'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}