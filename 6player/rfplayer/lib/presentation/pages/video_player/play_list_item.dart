import 'package:flutter/material.dart';
import '../../../data/models/play_queue.dart';

class PlayListItem extends StatelessWidget {
  final PlayQueueItem item;
  final int index;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PlayListItem({
    super.key,
    required this.item,
    required this.index,
    required this.isPlaying,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.queue_music,
        color: isPlaying ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        item.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
          color: item.isInvalid ? Colors.grey : null,
          decoration: item.isInvalid ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        '${index + 1}',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaying)
            Icon(
              Icons.playing_circle_outlined,
              color: Theme.of(context).primaryColor,
            ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: onDelete,
          ),
        ],
      ),
      onTap: onTap,
      tileColor: isPlaying
          ? Theme.of(context).primaryColor.withOpacity(0.1)
          : null,
      selected: isPlaying,
      selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.2),
    );
  }
}