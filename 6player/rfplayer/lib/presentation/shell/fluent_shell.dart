import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

class FluentShell extends StatelessWidget {
  final Widget child;

  const FluentShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      pane: NavigationPane(
        selected: _getCurrentIndex(context),
        onChanged: (index) => _navigateTo(context, index),
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('首页'),
            body: child,
          ),
          PaneItem(
            icon: const Icon(FluentIcons.history),
            title: const Text('历史'),
            body: child,
          ),
          PaneItem(
            icon: const Icon(FluentIcons.folder),
            title: const Text('文件'),
            body: child,
          ),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('设置'),
            body: child,
          ),
        ],
      ),
    );
  }

  int _getCurrentIndex(BuildContext context) {
    final state = GoRouterState.of(context);
    final location = state.uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/files')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _navigateTo(BuildContext context, int index) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/home');
        break;
      case 1:
        GoRouter.of(context).go('/history');
        break;
      case 2:
        GoRouter.of(context).go('/files');
        break;
      case 3:
        GoRouter.of(context).go('/settings');
        break;
    }
  }
}