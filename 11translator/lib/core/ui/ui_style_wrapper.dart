import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:rfdictionary/core/localization/app_localizations.dart';

class UIStyleWrapper extends ConsumerWidget {
  final Widget child;

  const UIStyleWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.watch(settingsProvider.notifier);
    
    final l10n = AppLocalizations.of(context);

    UIStyle effectiveStyle = settings.uiStyle;
    if (effectiveStyle == UIStyle.adaptive) {
      effectiveStyle = UIStyle.fluent;
    }

    if (effectiveStyle == UIStyle.fluent) {
      return fluent.FluentApp(
        title: 'RFDictionary',
        localizationsDelegates: [
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
          accentColor: fluent.Colors.red,
        ),
        darkTheme: fluent.FluentThemeData(
          brightness: Brightness.dark,
          accentColor: fluent.Colors.red,
        ),
        themeMode: switch (settingsNotifier.effectiveThemeMode) {
          ThemeMode.system => fluent.ThemeMode.system,
          ThemeMode.light => fluent.ThemeMode.light,
          ThemeMode.dark => fluent.ThemeMode.dark,
        },
        home: child,
      );
    }

    return MaterialApp(
      title: 'RFDictionary',
      localizationsDelegates: [
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
          seedColor: const Color(0xFFE8002D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8002D),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: settingsNotifier.effectiveThemeMode,
      home: child,
    );
  }
}
