import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/core/utils/platform_utils.dart';

enum UIFramework { material, fluent }

UIFramework _getEffectiveFramework(UIStyle style) {
  final effectiveStyle = style == UIStyle.adaptive
      ? (PlatformUtils.isWindows ? UIStyle.fluent : UIStyle.material3)
      : style;
  return effectiveStyle == UIStyle.fluent ? UIFramework.fluent : UIFramework.material;
}

class DualPlatformApp extends ConsumerWidget {
  final Widget Function(BuildContext context) materialHomeBuilder;
  final Widget Function(BuildContext context) fluentHomeBuilder;

  const DualPlatformApp({
    super.key,
    required this.materialHomeBuilder,
    required this.fluentHomeBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.watch(settingsProvider.notifier);
    final framework = _getEffectiveFramework(settings.uiStyle);

    if (framework == UIFramework.fluent) {
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
          accentColor: fluent.Colors.blue,
        ),
        darkTheme: fluent.FluentThemeData(
          brightness: Brightness.dark,
          accentColor: fluent.Colors.blue,
        ),
        themeMode: switch (settingsNotifier.effectiveThemeMode) {
          ThemeMode.system => fluent.ThemeMode.system,
          ThemeMode.light => fluent.ThemeMode.light,
          ThemeMode.dark => fluent.ThemeMode.dark,
        },
        home: Consumer(
          builder: (context, ref, _) => fluentHomeBuilder(context),
        ),
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
      home: Consumer(
        builder: (context, ref, _) => materialHomeBuilder(context),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
