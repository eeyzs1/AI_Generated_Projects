import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/core/utils/platform_utils.dart';
import 'package:rfdictionary/features/main/presentation/screens/init_screen.dart';

fluent.AccentColor _toFluentAccentColor(Color color) {
  return fluent.AccentColor.swatch({
    'darkest': color.withOpacity(0.2),
    'darker': color.withOpacity(0.4),
    'dark': color.withOpacity(0.6),
    'normal': color,
    'light': color.withOpacity(0.8),
    'lighter': color.withOpacity(0.6),
    'lightest': color.withOpacity(0.4),
  });
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.watch(settingsProvider.notifier);

    UIStyle effectiveStyle = settings.uiStyle;
    if (effectiveStyle == UIStyle.adaptive) {
      effectiveStyle = PlatformUtils.isWindows ? UIStyle.fluent : UIStyle.material3;
    }

    final bool isFluent = effectiveStyle == UIStyle.fluent;
    final seedColor = settings.seedColor;

    if (isFluent) {
      final fluentAccentColor = _toFluentAccentColor(seedColor);
      return fluent.FluentApp(
        title: 'RFDictionary',
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('zh'),
        ],
        locale: settingsNotifier.effectiveLocale,
        theme: fluent.FluentThemeData(
          accentColor: fluentAccentColor,
        ),
        darkTheme: fluent.FluentThemeData(
          brightness: Brightness.dark,
          accentColor: fluentAccentColor,
        ),
        themeMode: switch (settingsNotifier.effectiveThemeMode) {
          ThemeMode.system => fluent.ThemeMode.system,
          ThemeMode.light => fluent.ThemeMode.light,
          ThemeMode.dark => fluent.ThemeMode.dark,
        },
        home: const InitScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp(
      title: 'RFDictionary',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
      locale: settingsNotifier.effectiveLocale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: settingsNotifier.effectiveThemeMode,
      home: const InitScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
