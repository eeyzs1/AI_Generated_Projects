import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'package:fvp/fvp.dart' as fvp;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 fvp 库
  fvp.registerWith();

  runApp(const ProviderScope(child: RFPlayerApp()));
}