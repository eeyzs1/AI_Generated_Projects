import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfplayer/presentation/providers/play_queue_provider.dart';
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

    if (!widget.isVisible) {
      return Container();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 5,
            blurRadius: 10,
          ),
        ],
      ),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 抽屉标题
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '播放列表',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // 播放队列列表
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: Text('播放列表为空'),
                  )
                : ListView.builder(
                    itemCount: queue.length,
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      return PlayListItem(
                        key: ValueKey(item.id),
                        item: item,
                        index: index,
                        isCurrentPlaying: item.isCurrentPlaying,
                        hasPlayed: item.hasPlayed,
                        onTap: () async {
                          // 播放选中的视频
                          await playQueueNotifier.playItem(item.id);
                        },
                        onDelete: () async {
                          await playQueueNotifier.removeFromQueue(item.id);
                        },
                      );
                    },
                  ),
          ),

          // 控制按钮
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await playQueueNotifier.playPrevious();
                  },
                  child: const Text('上一个'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await playQueueNotifier.playNext();
                  },
                  child: const Text('下一个'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await playQueueNotifier.clearQueue();
                  },
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