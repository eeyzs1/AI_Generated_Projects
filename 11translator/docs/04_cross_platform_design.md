# 双端适配设计 — Windows + Android

## 1. 适配策略总览

```
┌─────────────────────────────────────────────────────────┐
│                   共享层（~80%代码）                      │
│  业务逻辑 / 状态管理 / 数据层 / 核心 UI 组件              │
├──────────────────────┬──────────────────────────────────┤
│   Android 适配层     │        Windows 适配层             │
│   (~10%代码)         │        (~10%代码)                 │
│  - 底部导航栏        │  - 侧边导航栏                     │
│  - 软键盘处理        │  - 菜单栏 / 快捷键                │
│  - 滑动删除手势      │  - 右键上下文菜单                 │
│  - 系统返回键        │  - 窗口大小调整                   │
│  - Material 3 风格   │  - 滚动条显示                     │
│  - 系统主题跟随      │  - 用户手动切换主题               │
└──────────────────────┴──────────────────────────────────┘
```

---

## 2. 布局适配

### 2.1 导航结构

**Android（手机竖屏）：**
```
┌─────────────────┐
│    内容区域      │
│                 │
│                 │
├─────────────────┤
│ 词典 收藏 历史  │  ← BottomNavigationBar
└─────────────────┘
```

**Windows（桌面宽屏）：**
```
┌──────┬──────────────────────┐
│ 词典 │                      │
│ 收藏 │      内容区域         │
│ 历史 │                      │
│ 设置 │                      │
└──────┴──────────────────────┘
  ↑ NavigationRail (宽度72dp)
```

**实现方式：**
```dart
class AdaptiveScaffold extends ConsumerStatefulWidget {
  final List<Widget> pages;
  const AdaptiveScaffold({super.key, required this.pages});

  @override
  ConsumerState<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends ConsumerState<AdaptiveScaffold> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.book_outlined), label: '词典'),
    NavigationDestination(icon: Icon(Icons.star_outline), label: '收藏'),
    NavigationDestination(icon: Icon(Icons.history), label: '历史'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformUtils.isDesktop;

    if (isDesktop) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: d.icon,
                      label: Text(d.label),
                    ))
                .toList(),
            labelType: NavigationRailLabelType.all,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.pages[_selectedIndex]),
        ]),
      );
    }

    return Scaffold(
      body: widget.pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: _destinations,
      ),
    );
  }
}
```

### 2.2 词典详情页布局

**Android（单列）：**
```
┌─────────────────┐
│   词头卡片       │
├─────────────────┤
│   Tab 栏        │
├─────────────────┤
│   内容（滚动）   │
└─────────────────┘
```

**Windows（双列，宽度 > 800px）：**
```
┌──────────────┬──────────────────┐
│  词头 + 释义  │   例句 / 详解    │
│  (左列40%)   │   (右列60%)      │
│              │                  │
└──────────────┴──────────────────┘
```

```dart
LayoutBuilder(builder: (context, constraints) {
  if (constraints.maxWidth > 800) {
    return Row(children: [
      SizedBox(
        width: constraints.maxWidth * 0.4,
        child: const DefinitionPanel(),
      ),
      const VerticalDivider(width: 1),
      const Expanded(child: ExamplesPanel()),
    ]);
  }
  return const SingleChildScrollView(child: Column(children: [...]));
})
```

---

## 3. 交互适配

### 3.1 右键 / 长按菜单

```dart
class PlatformContextMenu extends StatelessWidget {
  final Widget child;
  final List<ContextMenuItem> items;

  const PlatformContextMenu({
    super.key,
    required this.child,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isDesktop) {
      return GestureDetector(
        onSecondaryTapUp: (details) =>
            _showDesktopMenu(context, details.globalPosition),
        child: child,
      );
    }
    return GestureDetector(
      onLongPress: () => _showMobileBottomSheet(context),
      child: child,
    );
  }

  void _showDesktopMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: items
          .map((item) => PopupMenuItem(
                value: item.value,
                child: Text(item.label),
              ))
          .toList(),
    );
  }

  void _showMobileBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: items
            .map((item) => ListTile(
                  title: Text(item.label),
                  onTap: () {
                    Navigator.pop(context);
                    item.onTap();
                  },
                ))
            .toList(),
      ),
    );
  }
}
```

### 3.2 滑动删除（仅 Android）

```dart
Widget _buildHistoryItem(HistoryEntry entry) {
  if (PlatformUtils.isAndroid) {
    return Dismissible(
      key: Key(entry.word),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteEntry(entry),
      child: _buildListTile(entry),
    );
  }
  return _buildListTile(entry);
}
```

### 3.3 键盘快捷键（仅 Windows）

所有 Intent 均注册完整的 Actions 处理器：

```dart
class KeyboardShortcutsWrapper extends ConsumerWidget {
  final Widget child;
  const KeyboardShortcutsWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!PlatformUtils.isDesktop) return child;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
            const SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.f3):
            const SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD):
            const ToggleFavoriteIntent(),
        LogicalKeySet(LogicalKeyboardKey.f5):
            const PlayPronunciationIntent(),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.f5):
            const PlayPronunciationBritishIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape):
            const ClearSearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma):
            const OpenSettingsIntent(),
      },
      child: Actions(
        actions: {
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (_) {
              ref.read(searchFocusProvider).requestFocus();
              return null;
            },
          ),
          ToggleFavoriteIntent: CallbackAction<ToggleFavoriteIntent>(
            onInvoke: (_) {
              final word = ref.read(currentWordProvider);
              if (word != null) {
                ref.read(favoritesRepositoryProvider).toggleFavorite(word);
              }
              return null;
            },
          ),
          PlayPronunciationIntent: CallbackAction<PlayPronunciationIntent>(
            onInvoke: (_) {
              final word = ref.read(currentWordProvider);
              if (word != null) {
                ref.read(ttsServiceProvider).speak(word,
                    accent: TtsAccent.american);
              }
              return null;
            },
          ),
          PlayPronunciationBritishIntent:
              CallbackAction<PlayPronunciationBritishIntent>(
            onInvoke: (_) {
              final word = ref.read(currentWordProvider);
              if (word != null) {
                ref.read(ttsServiceProvider).speak(word,
                    accent: TtsAccent.british);
              }
              return null;
            },
          ),
          ClearSearchIntent: CallbackAction<ClearSearchIntent>(
            onInvoke: (_) {
              ref.read(searchQueryProvider.notifier).clear();
              return null;
            },
          ),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) {
              GoRouter.of(context).push('/settings');
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}
```

### 3.4 滚动条

```dart
ScrollbarTheme(
  data: ScrollbarThemeData(
    thumbVisibility: MaterialStateProperty.all(PlatformUtils.isDesktop),
    trackVisibility: MaterialStateProperty.all(PlatformUtils.isDesktop),
  ),
  child: child,
)
```

---

## 4. SQLite 适配

```dart
// lib/core/di/database_init.dart
Future<void> initDatabase() async {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Android 使用默认 sqflite，无需额外配置
}
```

**SQLite 缓存配置（性能优化）：**
```dart
Future<Database> openDictDatabase(String path) async {
  return openDatabase(
    path,
    readOnly: true,
    onOpen: (db) async {
      final cacheSize = PlatformUtils.isDesktop ? 32768 : 4096; // KB
      await db.execute('PRAGMA cache_size = $cacheSize');
      await db.execute('PRAGMA journal_mode = WAL');
    },
  );
}
```

---

## 5. TTS 适配

```dart
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isAvailable = false;

  Future<void> init() async {
    if (Platform.isAndroid) {
      final engines = await _tts.getEngines;
      _isAvailable = engines.isNotEmpty;
      if (!_isAvailable) return; // 发音按钮将置灰
    } else {
      _isAvailable = true; // Windows SAPI 通常已内置
    }

    await _tts.setSpeechRate(0.8);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setErrorHandler((message) {
      // 通过 Riverpod 通知 UI 更新按钮状态
    });
  }

  bool get isAvailable => _isAvailable;

  Future<void> speak(String text, {TtsAccent accent = TtsAccent.american}) async {
    if (!_isAvailable) throw StateError('TTS not available');
    await _tts.setLanguage(
        accent == TtsAccent.british ? 'en-GB' : 'en-US');
    await _tts.speak(text);
  }
}
```

---

## 6. 本地 LLM 适配

| 平台 | 方案 | 说明 |
|------|------|------|
| Android | `flutter_llama_cpp` 插件 | JNI 调用 llama.cpp |
| Windows | `llama_cpp_dart` 包 | dart:ffi 调用 llama.dll |

```dart
// 抽象接口，屏蔽平台差异
abstract class LlmDataSource {
  Future<void> loadModel(String modelPath);
  Stream<String> generate(String prompt, {InferenceParams? params});
  Future<void> releaseContext();
  Future<void> dispose();
}

// 工厂方法
LlmDataSource createLlmDataSource() {
  if (Platform.isAndroid) return AndroidLlmDataSource();
  if (Platform.isWindows) return WindowsLlmDataSource();
  throw UnsupportedError('Platform not supported');
}
```

---

## 7. 文件路径适配

```dart
class AppPaths {
  static Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return path.join(dir.path, 'dictionary.db');
  }

  static Future<String> getModelsDir() async {
    final dir = await getApplicationSupportDirectory();
    final modelsDir = Directory(path.join(dir.path, 'models'));
    if (!modelsDir.existsSync()) await modelsDir.create(recursive: true);
    return modelsDir.path;
  }

  static Future<String> getHiveDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return path.join(dir.path, 'hive');
  }
}
```

---

## 8. 窗口管理（Windows）

```dart
Future<void> initWindowManager() async {
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(400, 600));
  await windowManager.setSize(const Size(900, 700));
  await windowManager.setTitle('有道词典');
  await windowManager.center();
  await windowManager.show();
}
```

---

## 9. 主题适配

Android 固定跟随系统深色模式，Windows 支持用户手动切换（默认浅色）。

```dart
// lib/core/theme/theme_mode_notifier.dart
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs)
      : super(PlatformUtils.isAndroid
            ? ThemeMode.system
            : _loadSavedTheme(_prefs));

  static ThemeMode _loadSavedTheme(SharedPreferences prefs) {
    final saved = prefs.getString('theme_mode') ?? 'light';
    return switch (saved) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  // 仅 Windows 可调用
  Future<void> setTheme(ThemeMode mode) async {
    if (PlatformUtils.isAndroid) return;
    state = mode;
    await _prefs.setString('theme_mode', mode.name);
  }
}
```

在 `App` 中使用：
```dart
themeMode: ref.watch(themeModeProvider),
```

---

## 10. 平台工具类

```dart
// lib/core/utils/platform_utils.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  static bool get isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static EdgeInsets get contentPadding => isDesktop
      ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
      : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  static double get listItemHeight => isDesktop ? 56.0 : 64.0;
}
```

---

## 11. 性能适配

| 优化项 | Android | Windows |
|--------|---------|---------|
| 图片缓存 | 限制 50MB | 限制 200MB |
| LLM 线程数 | 2-4 线程（按 CPU 核数） | 8-16 线程 |
| SQLite 缓存 | 4MB page cache | 32MB page cache |
| 列表虚拟化 | ListView.builder | ListView.builder |
| 动画帧率 | 60fps | 60fps（可选 120fps） |

**LLM 线程数自动检测：**
```dart
int getOptimalThreadCount() {
  if (PlatformUtils.isDesktop) return 8;
  // Android：使用物理核心数的一半，最少2个
  final cores = Platform.numberOfProcessors;
  return (cores / 2).ceil().clamp(2, 4);
}
```
