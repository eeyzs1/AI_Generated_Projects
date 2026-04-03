import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_localizations.dart';

class FluentShell extends StatelessWidget {
  final Widget child;

  const FluentShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return NavigationView(
      pane: NavigationPane(
        selected: _getCurrentIndex(context),
        onChanged: (index) => _navigateTo(context, index),
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: Text(localizations.appName),
            body: child,
          ),
          PaneItem(
            icon: const Icon(FluentIcons.history),
            title: Text(localizations.history),
            body: child,
          ),
          PaneItem(
            icon: const Icon(FluentIcons.folder),
            title: Text(localizations.fileBrowser),
            body: child,
          ),
          PaneItem(
            icon: const Icon(FluentIcons.bookmarks),
            title: Text('书签'),
            body: child,
          ),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: Text(localizations.settings),
            body: child,
          ),
        ],
        displayMode: PaneDisplayMode.compact,
      ),
    );
  }

  int _getCurrentIndex(BuildContext context) {
    final state = GoRouterState.of(context);
    final location = state.uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/files')) return 2;
    if (location.startsWith('/bookmark')) return 3;
    if (location.startsWith('/settings')) return 4;
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
        GoRouter.of(context).go('/bookmark');
        break;
      case 4:
        GoRouter.of(context).go('/settings');
        break;
    }
  }
}