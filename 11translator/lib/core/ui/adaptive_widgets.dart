import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:rfdictionary/core/localization/app_localizations.dart';

UIStyle _getEffectiveStyle(UIStyle style) {
  if (style == UIStyle.adaptive) {
    return UIStyle.fluent;
  }
  return style;
}

class AdaptiveScaffold extends ConsumerWidget {
  final Widget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const AdaptiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final effectiveStyle = _getEffectiveStyle(settings.uiStyle);

    if (effectiveStyle == UIStyle.fluent) {
      return fluent.FluentPage(
        content: fluent.ScaffoldPage(
          header: appBar != null
              ? fluent.PageHeader(
                  leading: appBar,
                )
              : null,
          content: body,
          bottomBar: bottomNavigationBar,
        ),
      );
    }

    return Scaffold(
      appBar: appBar as PreferredSizeWidget?,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class AdaptiveAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;

  const AdaptiveAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final effectiveStyle = _getEffectiveStyle(settings.uiStyle);

    if (effectiveStyle == UIStyle.fluent) {
      return fluent.Row(
        children: [
          if (leading != null) leading!,
          if (title != null)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  child: title!,
                ),
              ),
            ),
          if (actions != null) ...actions!,
        ],
      );
    }

    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class AdaptiveButton extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isFilled;

  const AdaptiveButton({
    super.key,
    required this.child,
    this.onPressed,
    this.isFilled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final effectiveStyle = _getEffectiveStyle(settings.uiStyle);

    if (effectiveStyle == UIStyle.fluent) {
      return isFilled
          ? fluent.FilledButton(
              onPressed: onPressed,
              child: child,
            )
          : fluent.Button(
              onPressed: onPressed,
              child: child,
            );
    }

    return isFilled
        ? FilledButton(
            onPressed: onPressed,
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            child: child,
          );
  }
}

class AdaptiveIconButton extends ConsumerWidget {
  final Icon icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const AdaptiveIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final effectiveStyle = _getEffectiveStyle(settings.uiStyle);

    if (effectiveStyle == UIStyle.fluent) {
      return fluent.IconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
      );
    }

    return IconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

class AdaptiveTextField extends ConsumerWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const AdaptiveTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final effectiveStyle = _getEffectiveStyle(settings.uiStyle);

    if (effectiveStyle == UIStyle.fluent) {
      return fluent.TextBox(
        controller: controller,
        focusNode: focusNode,
        placeholder: hintText,
        prefix: prefixIcon,
        suffix: suffixIcon,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      );
    }

    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class AdaptiveNavigationBar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<({IconData icon, IconData selectedIcon, String label})> destinations;

  const AdaptiveNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final effectiveStyle = _getEffectiveStyle(settings.uiStyle);
    final l10n = AppLocalizations.of(context);

    if (effectiveStyle == UIStyle.fluent) {
      return fluent.NavigationView(
        pane: fluent.NavigationPane(
          selected: selectedIndex,
          onChanged: onDestinationSelected,
          items: destinations
              .map((d) => fluent.PaneItem(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    title: Text(d.label),
                  ))
              .toList(),
          displayMode: fluent.PaneDisplayMode.compact,
        ),
      );
    }

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations
          .map((d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ))
          .toList(),
    );
  }
}

class AdaptiveCard extends ConsumerWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final effectiveStyle = _getEffectiveStyle(settings.uiStyle);

    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    if (effectiveStyle == UIStyle.fluent) {
      return fluent.Padding(
        padding: const EdgeInsets.all(4),
        child: fluent.Button(
          onPressed: onTap,
          style: fluent.ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
          ),
          child: content,
        ),
      );
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        child: content,
      ),
    );
  }
}
