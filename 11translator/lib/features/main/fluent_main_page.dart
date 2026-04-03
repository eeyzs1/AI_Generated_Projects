import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/features/dictionary/presentation/screens/home_screen.dart';
import 'package:rfdictionary/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:rfdictionary/features/history/presentation/screens/history_screen.dart';
import 'package:rfdictionary/features/settings/presentation/screens/settings_screen.dart';

class FluentMainPage extends ConsumerStatefulWidget {
  const FluentMainPage({super.key});

  @override
  ConsumerState<FluentMainPage> createState() => _FluentMainPageState();
}

class _FluentMainPageState extends ConsumerState<FluentMainPage> {
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

    return fluent.NavigationView(
      pane: fluent.NavigationPane(
        selected: _currentIndex,
        onChanged: (index) {
          setState(() => _currentIndex = index);
        },
        items: [
          fluent.PaneItem(
            icon: const Icon(Icons.book_outlined),
            title: Text(l10n.dictionary),
          ),
          fluent.PaneItem(
            icon: const Icon(Icons.star_outlined),
            title: Text(l10n.favorites),
          ),
          fluent.PaneItem(
            icon: const Icon(Icons.history),
            title: Text(l10n.history),
          ),
          fluent.PaneItem(
            icon: const Icon(Icons.settings_outlined),
            title: Text(l10n.settings),
          ),
        ],
        displayMode: fluent.PaneDisplayMode.compact,
      ),
      content: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}
