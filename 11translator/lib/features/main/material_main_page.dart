import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/features/dictionary/presentation/screens/home_screen.dart';
import 'package:rfdictionary/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:rfdictionary/features/history/presentation/screens/history_screen.dart';
import 'package:rfdictionary/features/settings/presentation/screens/settings_screen.dart';

class MaterialMainPage extends ConsumerStatefulWidget {
  const MaterialMainPage({super.key});

  @override
  ConsumerState<MaterialMainPage> createState() => _MaterialMainPageState();
}

class _MaterialMainPageState extends ConsumerState<MaterialMainPage> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FavoritesScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.book_outlined),
            selectedIcon: const Icon(Icons.book),
            label: l10n.dictionary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.star_outlined),
            selectedIcon: const Icon(Icons.star),
            label: l10n.favorites,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            selectedIcon: const Icon(Icons.history),
            label: l10n.history,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
