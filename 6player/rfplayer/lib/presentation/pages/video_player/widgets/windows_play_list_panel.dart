import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfplayer/presentation/providers/play_queue_provider.dart';
import 'package:rfplayer/data/models/play_queue.dart';
import 'package:rfplayer/core/localization/app_localizations.dart';
import 'play_list_item.dart';

class WindowsPlayListPanel extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateBack;

  const WindowsPlayListPanel({super.key, this.onNavigateBack});

  @override
  ConsumerState<WindowsPlayListPanel> createState() => _WindowsPlayListPanelState();
}

class _WindowsPlayListPanelState extends ConsumerState<WindowsPlayListPanel> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final queue = ref.watch(playQueueProvider);
    final playQueueNotifier = ref.read(playQueueProvider.notifier);

    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.withOpacity(0.2))),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 面板标题
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.playList,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () async {
                    await playQueueNotifier.clearQueue();
                  },
                ),
              ],
            ),
          ),

          // 播放队列列表
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: Text(loc.playListEmpty),
                  )
                : ReorderableListView.builder(
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
                          final shouldNavigateBack = await playQueueNotifier.removeFromQueueWithHandling(item.id);
                          if (shouldNavigateBack && widget.onNavigateBack != null) {
                            widget.onNavigateBack!();
                          }
                        },
                      );
                    },
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      await playQueueNotifier.reorderQueue(oldIndex, newIndex);
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
                  child: Text(loc.previous),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await playQueueNotifier.playNext();
                  },
                  child: Text(loc.next),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await playQueueNotifier.clearQueue();
                  },
                  child: Text(loc.clear),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}