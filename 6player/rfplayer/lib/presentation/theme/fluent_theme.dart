import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _fluentLightTheme = FluentThemeData(
  brightness: Brightness.light,
  accentColor: AccentColor('blue', {
    'darkest': Color(0xFF0D47A1),
    'darker': Color(0xFF1565C0),
    'dark': Color(0xFF1976D2),
    'normal': Color(0xFF2196F3),
    'light': Color(0xFF42A5F5),
    'lighter': Color(0xFF64B5F6),
    'lightest': Color(0xFF90CAF9),
  }),
);

final _fluentDarkTheme = FluentThemeData(
  brightness: Brightness.dark,
  accentColor: AccentColor('blue', {
    'darkest': Color(0xFF0D47A1),
    'darker': Color(0xFF1565C0),
    'dark': Color(0xFF1976D2),
    'normal': Color(0xFF2196F3),
    'light': Color(0xFF42A5F5),
    'lighter': Color(0xFF64B5F6),
    'lightest': Color(0xFF90CAF9),
  }),
);

final fluentLightThemeProvider = Provider((ref) => _fluentLightTheme);
final fluentDarkThemeProvider = Provider((ref) => _fluentDarkTheme);