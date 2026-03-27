import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'material_shell.dart';
import 'fluent_shell.dart';
import '../providers/settings_provider.dart';
import '../../data/models/app_settings.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final effectiveStyle = _resolveStyle(settings.uiStyle);

    if (effectiveStyle == UIStyle.fluent) {
      return FluentShell(child: child);
    }

    return MaterialShell(child: child);
  }

  UIStyle _resolveStyle(UIStyle style) {
    if (style != UIStyle.adaptive) return style;
    return Platform.isWindows ? UIStyle.fluent : UIStyle.material3;
  }
}