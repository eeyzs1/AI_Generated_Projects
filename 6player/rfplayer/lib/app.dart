import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart';
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
    final locale = _resolveLocale(settings.language);

    if (effectiveStyle == UIStyle.fluent) {
      return fluent.FluentApp.router(
        routerConfig: appRouter,
        theme: fluent.FluentThemeData.light(),
        darkTheme: fluent.FluentThemeData.dark(),
        themeMode: _toFluentThemeMode(settings.themeMode),
        locale: locale,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('zh', 'CN'),
        ],
      );
    }

    return material.MaterialApp.router(
      routerConfig: appRouter,
      theme: ref.watch(materialLightThemeProvider),
      darkTheme: ref.watch(materialDarkThemeProvider),
      themeMode: _toMaterialThemeMode(settings.themeMode),
      locale: locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('zh', 'CN'),
      ],
    );
  }

  Locale _resolveLocale(AppLanguage language) {
    switch (language) {
      case AppLanguage.zhCn:
        return const Locale('zh', 'CN');
      case AppLanguage.enUs:
        return const Locale('en', 'US');
      case AppLanguage.system:
        return Locale(Platform.localeName.split('_')[0]);
    }
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
        return material.ThemeMode.system;
    }
  }

  fluent.ThemeMode _toFluentThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return fluent.ThemeMode.light;
      case ThemeMode.dark:
        return fluent.ThemeMode.dark;
      case ThemeMode.system:
        return fluent.ThemeMode.system;
    }
  }
}