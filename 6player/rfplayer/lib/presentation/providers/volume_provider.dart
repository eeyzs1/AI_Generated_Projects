import 'package:flutter_riverpod/flutter_riverpod.dart';

// 音量状态提供者
final volumeProvider = StateProvider<double>((ref) {
  return 1.0; // 默认音量 100%
});
