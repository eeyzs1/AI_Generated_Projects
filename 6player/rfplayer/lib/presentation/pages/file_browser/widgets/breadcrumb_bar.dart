import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/file_browser_provider.dart';

class BreadcrumbBar extends ConsumerWidget {
  const BreadcrumbBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = ref.watch(fileBrowserProvider).currentPath;
    final pathSegments = currentPath.split('\\'); // Windows 路径分隔符

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < pathSegments.length; i++)
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final path = pathSegments.sublist(0, i + 1).join('\\');
                    ref.read(fileBrowserProvider.notifier).navigateTo(path);
                  },
                  child: Text(
                    pathSegments[i],
                    style: TextStyle(
                      color: i == pathSegments.length - 1
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: i == pathSegments.length - 1
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (i < pathSegments.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}