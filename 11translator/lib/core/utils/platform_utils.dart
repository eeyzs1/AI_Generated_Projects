import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isDesktop => !kIsWeb && Platform.isWindows;
  static bool get isMobile => !kIsWeb && Platform.isAndroid;

  static EdgeInsets get contentPadding => isDesktop
      ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
      : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  static double get listItemHeight => isDesktop ? 56.0 : 64.0;

  static int get optimalLlmThreadCount {
    if (isDesktop) return 8;
    final cores = Platform.numberOfProcessors;
    return (cores / 2).ceil().clamp(2, 4);
  }
}
