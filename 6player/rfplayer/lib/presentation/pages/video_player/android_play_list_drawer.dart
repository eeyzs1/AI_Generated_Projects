import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../presentation/providers/play_queue_provider.dart';
import 'play_list_item.dart';

class AndroidPlayListDrawer extends ConsumerStatefulWidget {
  final bool isVisible;
  final VoidCallback onClose;

  const AndroidPlayListDrawer({
    super.key,
    required this.isVisible,
    required this.onClose,
  });

  @override
  ConsumerState<AndroidPlayListDrawer> createState() => _AndroidPlayListDrawerState();
}

class _AndroidPlayListDrawerState extends ConsumerState<AndroidPlayListDrawer> {
  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(playQueueProvider);
    final playQueueNotifier = ref.read(playQueueProvider.notifier);

    if (!widget.isVisible) return Container();

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 5,
            blurRadius: 10,
          ),
        ],
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        children: [
          // 抽屉标题
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
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          // 播放队列列表
          Expanded(
            child: ListView.builder(
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final item = queue[index];
                return PlayListItem(
                  key: ValueKey(item.id),
                  item: item,
                  index: index,
                  isPlaying: item.isPlaying,
                  onTap: () => playQueueNotifier.playItem(item.id),
                  onDelete: () => playQueueNotifier.removeFromQueue(item.id),
                );
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