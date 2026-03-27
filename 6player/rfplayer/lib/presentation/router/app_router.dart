import 'package:go_router/go_router.dart';
import '../shell/main_shell.dart';
import '../pages/home/home_page.dart';
import '../pages/history/history_page.dart';
import '../pages/file_browser/file_browser_page.dart';
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
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      ],
    ),
    GoRoute(path: '/video-player', builder: (_, state) => VideoPlayerPage(path: state.extra as String)),
    GoRoute(path: '/image-viewer', builder: (_, state) => ImageViewerPage(path: state.extra as String)),
  ],
);