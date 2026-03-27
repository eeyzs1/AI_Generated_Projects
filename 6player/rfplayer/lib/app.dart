import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'presentation/providers/settings_provider.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/router/app_router.dart';
import 'data/models/app_settings.dart';
import 'dart:io';

class RFPlayerApp extends ConsumerWidget {
  const RFPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final effectiveStyle = _resolveStyle(settings.uiStyle);

    if (effectiveStyle == UIStyle.fluent) {
      return fluent.FluentApp.router(
        routerConfig: appRouter,
        theme: fluent.FluentThemeData.light(),
        darkTheme: fluent.FluentThemeData.dark(),
      );
    }

    return material.MaterialApp.router(
      routerConfig: appRouter,
      theme: ref.watch(materialLightThemeProvider),
      darkTheme: ref.watch(materialDarkThemeProvider),
      themeMode: _toMaterialThemeMode(settings.themeMode),
    );
  }

  UIStyle _resolveStyle(UIStyle style) {
    if (style != UIStyle.adaptive) return style;
    return Platform.isWindows ? UIStyle.fluent : UIStyle.material3;
  }

  material.ThemeMode _toMaterialThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return material.ThemeMode.light;
      case ThemeMode.dark:
        return material.ThemeMode.dark;
      case ThemeMode.system:
      default:
        return material.ThemeMode.system;
    }
  }
}