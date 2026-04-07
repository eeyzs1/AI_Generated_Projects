import 'package:flutter/material.dart';
import 'package:rfplayer/data/models/play_queue.dart';

class PlayListItem extends StatelessWidget {
  final PlayQueueItem item;
  final int index;
  final bool isCurrentPlaying;
  final bool hasPlayed;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PlayListItem({
    super.key,
    required this.item,
    required this.index,
    required this.isCurrentPlaying,
    required this.hasPlayed,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 待播状态：默认字体+常规底色，无特殊标记
    // 正在播放：主题色高亮底色+前置▶️播放图标+字体加粗
    // 已播完成：灰色弱化字体+✅已播标记

    bool isDisabled = item.isInvalid;
    
    return Container(
      decoration: BoxDecoration(
        color: isCurrentPlaying ? Colors.blue.withValues(alpha: 0.2) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrentPlaying ? Colors.blue : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: isCurrentPlaying
              ? const Icon(Icons.play_arrow, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isCurrentPlaying ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.displayName,
                style: TextStyle(
                  fontWeight: isCurrentPlaying ? FontWeight.bold : FontWeight.normal,
                  color: isDisabled
                      ? Colors.grey
                      : hasPlayed
                          ? Colors.grey
                          : isCurrentPlaying
                              ? Colors.blue
                              : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasPlayed && !isCurrentPlaying)
              const Icon(Icons.check, color: Colors.green, size: 16),
          ],
        ),
        subtitle: Text(
          item.path,
          style: TextStyle(
            fontSize: 12,
            color: isDisabled ? Colors.grey : Colors.grey,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
        onTap: isDisabled ? null : onTap,
      ),
    );
  }
}