import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import '../shell/main_shell.dart';
import '../pages/home/home_page.dart';
import '../pages/history/history_page.dart';
import '../pages/file_browser/file_browser_page.dart';
import '../pages/bookmark/bookmark_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/video_player/video_player_page.dart';
import '../pages/image_viewer/image_viewer_page.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
        GoRoute(path: '/files', builder: (_, _) => const FileBrowserPage()),
        GoRoute(path: '/bookmark', builder: (_, _) => const BookmarkPage()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      ],
    ),
    GoRoute(
      path: '/video-player',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          if (extra.containsKey('position')) {
            // 从书签页面传递过来的数据
            final path = extra['path'] as String;
            final position = extra['position'] as Duration?;
            return VideoPlayerPage(path: path, initialPosition: position);
          } else {
            // 从文件选择器传递过来的数据（包含 path 和 name）
            final path = extra['path'] as String;
            final name = extra['name'] as String?;
            return VideoPlayerPage(path: path, fileName: name);
          }
        } else {
          // 从其他页面传递过来的数据（直接传递路径字符串）
          return VideoPlayerPage(path: extra as String);
        }
      },
    ),
    GoRoute(
      path: '/image-viewer',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          final path = extra['path'] as String;
          final name = extra['name'] as String?;
          final bytes = extra['bytes'] as Uint8List?;
          return ImageViewerPage(path: path, fileName: name, bytes: bytes);
        } else {
          return ImageViewerPage(path: extra as String);
        }
      },
    ),
  ],
);