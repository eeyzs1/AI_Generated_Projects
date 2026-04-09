import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
import '../../core/localization/app_localizations.dart';

class MaterialShell extends ConsumerWidget {
  final Widget child;

  const MaterialShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    final currentIndex = _getCurrentIndex(GoRouterState.of(context).uri.path);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => _navigateTo(context, index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: localizations.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: localizations.files,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: localizations.history,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_outline),
            selectedIcon: const Icon(Icons.bookmark),
            label: localizations.bookmarks,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: localizations.settings,
          ),
        ],
      ),
    );
  }

  int _getCurrentIndex(String path) {
    if (path.startsWith(AppRoutes.history)) return 2;
    if (path.startsWith(AppRoutes.files)) return 1;
    if (path.startsWith(AppRoutes.bookmark)) return 3;
    if (path.startsWith(AppRoutes.settings)) return 4;
    return 0;
  }

  void _navigateTo(BuildContext context, int index) {
    final routes = [
      AppRoutes.home,
      AppRoutes.files,
      AppRoutes.history,
      AppRoutes.bookmark,
      AppRoutes.settings,
    ];
    if (GoRouterState.of(context).uri.path != routes[index]) {
      context.go(routes[index]);
    }
  }
}
