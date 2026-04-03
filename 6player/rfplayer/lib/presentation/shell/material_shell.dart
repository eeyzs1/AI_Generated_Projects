import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_localizations.dart';

class MaterialShell extends StatelessWidget {
  final Widget child;

  const MaterialShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getCurrentIndex(context),
        onTap: (index) => _navigateTo(context, index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: localizations.appName,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: localizations.history,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.folder),
            label: localizations.fileBrowser,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bookmark),
            label: '书签',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: localizations.settings,
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