import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/features/translation/presentation/screens/translation_screen.dart';
import 'package:rfdictionary/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:rfdictionary/features/history/presentation/screens/history_screen.dart';
import 'package:rfdictionary/features/settings/presentation/screens/settings_screen.dart';

class MaterialShell extends ConsumerWidget {
  const MaterialShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.watch(settingsProvider.notifier);

    final List<Widget> screens = [
      const TranslationScreen(),
      const FavoritesScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: settings.currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: settings.currentIndex,
        onDestinationSelected: (index) {
          settingsNotifier.setCurrentIndex(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.translate_outlined),
            selectedIcon: Icon(Icons.translate),
            label: '\u7FFB\u8BD1',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outlined),
            selectedIcon: Icon(Icons.star),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
