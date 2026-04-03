import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/core/utils/platform_utils.dart';
import 'package:rfdictionary/presentation/shell/material_shell.dart';
import 'package:rfdictionary/presentation/shell/fluent_shell.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    UIStyle effectiveStyle = settings.uiStyle;
    if (effectiveStyle == UIStyle.adaptive) {
      effectiveStyle = PlatformUtils.isWindows ? UIStyle.fluent : UIStyle.material3;
    }

    if (effectiveStyle == UIStyle.fluent) {
      return const FluentShell();
    }

    return const MaterialShell();
  }
}
