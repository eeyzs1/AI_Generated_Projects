import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
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
            title: Text(localizations.bookmarks),
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
    if (location.startsWith(AppRoutes.home)) return 0;
    if (location.startsWith(AppRoutes.history)) return 1;
    if (location.startsWith(AppRoutes.files)) return 2;
    if (location.startsWith(AppRoutes.bookmark)) return 3;
    if (location.startsWith(AppRoutes.settings)) return 4;
    return 0;
  }

  void _navigateTo(BuildContext context, int index) {
    final routes = [
      AppRoutes.home,
      AppRoutes.history,
      AppRoutes.files,
      AppRoutes.bookmark,
      AppRoutes.settings,
    ];
    GoRouter.of(context).go(routes[index]);
  }
}
