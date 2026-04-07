import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'presentation/providers/play_queue_provider.dart';
import 'presentation/providers/history_provider.dart';
import 'presentation/providers/permission_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 fvp 库
  fvp.registerWith();

  runApp(const ProviderScope(child: AppInitializer()));
}

class AppInitializer extends ConsumerStatefulWidget {
  const AppInitializer({super.key});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 清理播放队列中的无效记录
      final playQueueNotifier = ref.read(playQueueProvider.notifier);
      await playQueueNotifier.cleanupInvalidItems();

      // 清理历史记录中的无效记录
      final historyActions = ref.read(historyActionsProvider);
      await historyActions.cleanupInvalidRecords();
      
      // 等待权限 provider 初始化并检查状态
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 如果之前没有请求过权限，现在请求
      final permissionState = ref.read(permissionProvider);
      if (!permissionState.hasRequestedBefore && 
          permissionState.storagePermission == PermissionStatus.notDetermined) {
        debugPrint('[AppInitializer] 首次启动，请求存储权限...');
        final permissionNotifier = ref.read(permissionProvider.notifier);
        await permissionNotifier.requestStoragePermission();
      }
    } catch (e) {
      debugPrint('Error initializing app: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    return const RFPlayerApp();
  }
}