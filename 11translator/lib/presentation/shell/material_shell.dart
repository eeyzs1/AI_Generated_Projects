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
    final l10n = AppLocalizations.of(context);

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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.translate_outlined),
            selectedIcon: const Icon(Icons.translate),
            label: '翻译',
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
