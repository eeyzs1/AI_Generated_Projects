import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../providers/file_browser_provider.dart';

class BookmarkPanel extends ConsumerWidget {
  const BookmarkPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: bookmarks.length,
        itemBuilder: (context, index) {
          final bookmark = bookmarks[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                ref.read(fileBrowserProvider.notifier).navigateTo(bookmark.path);
              },
              onLongPress: () {
                _showDeleteDialog(context, ref, bookmark.id);
              },
              child: Chip(
                label: Row(
                  children: [
                    const Icon(Icons.folder_special, size: 16),
                    const SizedBox(width: 4),
                    Text(bookmark.displayName),
                  ],
                ),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                onDeleted: () {
                  _showDeleteDialog(context, ref, bookmark.id);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书签'),
        content: const Text('确定要删除这个书签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(bookmarkProvider.notifier).deleteBookmark(id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}