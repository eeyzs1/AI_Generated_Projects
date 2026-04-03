import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rfdictionary/core/utils/platform_utils.dart';

class AdaptiveScaffold extends ConsumerStatefulWidget {
  final List<Widget> pages;
  const AdaptiveScaffold({super.key, required this.pages});

  @override
  ConsumerState<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends ConsumerState<AdaptiveScaffold> {
  int _selectedIndex = 0;

  static const _destinations = [
    (icon: Icons.book_outlined, selectedIcon: Icons.book, label: '词典', route: '/'),
    (icon: Icons.star_outline, selectedIcon: Icons.star, label: '收藏', route: '/favorites'),
    (icon: Icons.history, selectedIcon: Icons.history, label: '历史', route: '/history'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: '设置', route: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformUtils.isDesktop;

    if (isDesktop) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) {
              setState(() => _selectedIndex = i);
              context.go(_destinations[i].route);
            },
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ))
                .toList(),
            labelType: NavigationRailLabelType.all,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.pages[_selectedIndex]),
        ]),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: widget.pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          setState(() => _selectedIndex = i);
          context.go(_destinations[i].route);
        },
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}
