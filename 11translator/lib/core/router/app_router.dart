import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/core/utils/platform_utils.dart';
import 'package:rfdictionary/features/dictionary/presentation/screens/dictionary_manager_screen.dart';
import 'package:rfdictionary/features/dictionary/presentation/screens/home_screen.dart';
import 'package:rfdictionary/features/dictionary/presentation/screens/word_detail_screen.dart';
import 'package:rfdictionary/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:rfdictionary/features/history/presentation/screens/history_screen.dart';
import 'package:rfdictionary/features/llm/presentation/screens/model_download_screen.dart';
import 'package:rfdictionary/features/settings/presentation/screens/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

typedef NavDest = ({IconData icon, IconData selectedIcon, String labelKey, String route});

const List<NavDest> _destinations = [
  (icon: Icons.book_outlined, selectedIcon: Icons.book, labelKey: 'dictionary', route: '/'),
  (icon: Icons.star_outlined, selectedIcon: Icons.star, labelKey: 'favorites', route: '/favorites'),
  (icon: Icons.history, selectedIcon: Icons.history, labelKey: 'history', route: '/history'),
  (icon: Icons.settings_outlined, selectedIcon: Icons.settings, labelKey: 'settings', route: '/settings'),
];

String _getLabel(BuildContext context, String labelKey) {
  final l10n = AppLocalizations.of(context);
  return switch (labelKey) {
    'dictionary' => l10n.dictionary,
    'favorites' => l10n.favorites,
    'history' => l10n.history,
    'settings' => l10n.settings,
    _ => labelKey,
  };
}

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return _ScaffoldWithNavigation(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'word/:word',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) => MaterialPage(
                child: WordDetailScreen(
                  word: state.pathParameters['word']!,
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'model-download',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) => const MaterialPage(
                child: ModelDownloadScreen(),
              ),
            ),
            GoRoute(
              path: 'dictionary-manager',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) => const MaterialPage(
                child: DictionaryManagerScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _ScaffoldWithNavigation extends ConsumerStatefulWidget {
  final Widget child;
  const _ScaffoldWithNavigation({required this.child});

  @override
  ConsumerState<_ScaffoldWithNavigation> createState() => _ScaffoldWithNavigationState();
}

class _ScaffoldWithNavigationState extends ConsumerState<_ScaffoldWithNavigation> {
  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _destinations.length; i++) {
      if (location == _destinations[i].route) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final isDesktop = PlatformUtils.isDesktop;

    if (isDesktop) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) {
              context.go(_destinations[i].route);
            },
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(_getLabel(context, d.labelKey)),
                    ),)
                .toList(),
            labelType: NavigationRailLabelType.all,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          context.go(_destinations[i].route);
        },
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: _getLabel(context, d.labelKey),
                ),)
            .toList(),
      ),
    );
  }
}
