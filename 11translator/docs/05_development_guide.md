# 开发指导 — 核心功能实现

## 1. 项目初始化

### 1.1 pubspec.yaml

```yaml
name: youdao_dict
description: "有道词典 Flutter 复刻版"
publish_to: none
version: 1.0.0+1

environment:
  sdk: ^3.4.0

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^14.0.0
  sqflite: ^2.3.3+1
  sqflite_common_ffi: ^2.3.3
  hive_flutter: ^1.1.0
  flutter_tts: ^4.0.2
  shimmer: ^3.0.0
  path_provider: ^2.1.3
  path: ^1.9.0
  shared_preferences: ^2.2.3
  window_manager: ^0.3.9
  dio: ^5.4.0              # 模型下载（断点续传）

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.9
  hive_generator: ^2.0.1
  riverpod_generator: ^2.4.0
```

### 1.2 main.dart

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_notifier.dart';
import 'features/favorites/data/models/favorite_word.dart';
import 'features/history/data/models/history_entry.dart';
import 'features/llm/domain/llm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Hive.initFlutter();
  Hive.registerAdapter(FavoriteWordAdapter());
  Hive.registerAdapter(HistoryEntryAdapter());
  await Hive.openBox<FavoriteWord>('favorites');
  await Hive.openBox<HistoryEntry>('history');

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(400, 600));
    await windowManager.setSize(const Size(900, 700));
    await windowManager.setTitle('有道词典');
    await windowManager.center();
  }

  runApp(const ProviderScope(child: App()));
}

// App 改为 ConsumerStatefulWidget 以注册 AppLifecycleObserver
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android 后台时释放 LLM 上下文节省内存
    if (state == AppLifecycleState.paused) {
      ref.read(llmServiceProvider.notifier).releaseContext();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(llmServiceProvider.notifier).restoreContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: '有道词典',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,  // Android 固定 system，Windows 用户可切换
      routerConfig: appRouter,
    );
  }
}
```

> `ThemeModeNotifier` 在 Android 上固定返回 `ThemeMode.system`，在 Windows 上默认 `ThemeMode.light`，用户可在设置中切换。

---

## 2. 主题配置

```dart
// lib/core/theme/app_theme.dart
class AppTheme {
  static const _primaryColor = Color(0xFFE8002D);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      primary: _primaryColor,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: const Color(0xFFFFF0F0),
      iconTheme: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return const IconThemeData(color: _primaryColor);
        }
        return const IconThemeData(color: Color(0xFF999999));
      }),
    ),
    cardTheme: CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF4D6A),  // 暗色下用亮变体保证对比度
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardTheme: CardTheme(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
```

---

## 3. 词典数据库实现

### 3.1 数据库初始化（含进度流）

```dart
// lib/features/dictionary/data/datasources/dictionary_local_datasource.dart
class DictionaryLocalDataSource {
  Database? _db;

  Future<Database> get db async {
    _db ??= await _openDatabase();
    return _db!;
  }

  /// 首次运行时从 assets 复制数据库，返回进度流 [0.0, 1.0]
  /// Splash 页面监听此流显示进度条
  static Stream<double> initDatabaseIfNeeded() async* {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, 'dictionary.db');

    if (File(dbPath).existsSync()) {
      final db = await openDatabase(dbPath, readOnly: true);
      final result = await db.rawQuery('PRAGMA integrity_check');
      await db.close();
      if (result.first.values.first == 'ok') {
        yield 1.0;
        return;
      }
      await File(dbPath).delete(); // 损坏则重新复制
    }

    yield 0.0;
    final data = await rootBundle.load('assets/dictionary.db');
    final bytes = data.buffer.asUint8List();
    final total = bytes.length;
    final sink = File(dbPath).openWrite();
    const chunkSize = 65536; // 64KB
    int written = 0;
    while (written < total) {
      final end = (written + chunkSize).clamp(0, total);
      sink.add(bytes.sublist(written, end));
      written = end;
      yield written / total;
    }
    await sink.flush();
    await sink.close();
    yield 1.0;
  }

  Future<Database> _openDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, 'dictionary.db');
    final db = await openDatabase(dbPath, readOnly: true);
    final cacheSize = Platform.isWindows ? 32768 : 4096;
    await db.execute('PRAGMA cache_size = $cacheSize');
    await db.execute('PRAGMA journal_mode = WAL');
    return db;
  }

  Future<WordEntryModel?> getWord(String word) async {
    final database = await db;
    final results = await database.query(
      'words',
      where: 'word = ?',
      whereArgs: [word.toLowerCase()],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return WordEntryModel.fromMap(results.first);
  }

  Future<List<String>> getSuggestions(String prefix) async {
    if (prefix.isEmpty) return [];
    final database = await db;
    final results = await database.query(
      'words',
      columns: ['word'],
      where: 'word LIKE ?',
      whereArgs: ['${prefix.toLowerCase()}%'],
      orderBy: 'frq DESC, bnc DESC',
      limit: 8,
    );
    return results.map((r) => r['word'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getExamples(int wordId) async {
    final database = await db;
    return database.query(
      'examples',
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 10,
    );
  }
}
```

### 3.2 WordEntry 实体

```dart
class WordEntry {
  final String word;
  final String? phonetic;
  final List<Definition> definitions;
  final List<ExampleSentence> examples;
  final Map<String, String> exchanges;

  const WordEntry({
    required this.word,
    this.phonetic,
    required this.definitions,
    required this.examples,
    required this.exchanges,
  });
}

class Definition {
  final String partOfSpeech;
  final String chinese;
  final String? english;

  const Definition({
    required this.partOfSpeech,
    required this.chinese,
    this.english,
  });
}

class ExampleSentence {
  final String english;
  final String? chinese;
  const ExampleSentence({required this.english, this.chinese});
}
```

---

## 4. 搜索功能实现

```dart
@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void update(String query) => state = query;
  void clear() => state = '';
}

@riverpod
Future<List<String>> suggestions(SuggestionsRef ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  await Future.delayed(const Duration(milliseconds: 300));
  return ref.read(getSuggestionsUseCaseProvider).call(query);
}

@riverpod
Future<WordEntry?> wordDetail(WordDetailRef ref, String word) async {
  return ref.read(searchWordUseCaseProvider).call(word);
}
```

---

## 5. 发音功能实现

```dart
enum TtsAccent { british, american }

@riverpod
TtsService ttsService(TtsServiceRef ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
}

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isAvailable = false;

  bool get isAvailable => _isAvailable;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (Platform.isAndroid) {
      final engines = await _tts.getEngines;
      _isAvailable = engines.isNotEmpty;
      if (!_isAvailable) return;
    } else {
      _isAvailable = true; // Windows SAPI 通常已内置
    }

    await _tts.setSpeechRate(0.8);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text, {TtsAccent accent = TtsAccent.american}) async {
    await init();
    if (!_isAvailable) throw StateError('TTS not available');
    final lang = accent == TtsAccent.british ? 'en-GB' : 'en-US';
    await _tts.setLanguage(lang);
    final result = await _tts.speak(text);
    if (result != 1) throw Exception('TTS speak failed');
  }

  Future<void> stop() => _tts.stop();
  void dispose() => _tts.stop();
}
```

### 发音按钮组件

```dart
class PronunciationButton extends ConsumerStatefulWidget {
  final String word;
  final TtsAccent accent;

  const PronunciationButton({super.key, required this.word, required this.accent});

  @override
  ConsumerState<PronunciationButton> createState() => _PronunciationButtonState();
}

class _PronunciationButtonState extends ConsumerState<PronunciationButton> {
  bool _isPlaying = false;
  bool _hasError = false;

  Future<void> _play() async {
    final tts = ref.read(ttsServiceProvider);
    if (!tts.isAvailable) return;

    setState(() { _isPlaying = true; _hasError = false; });
    try {
      await tts.speak(widget.word, accent: widget.accent);
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
        if (Platform.isAndroid) HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) setState(() => _hasError = false);
      }
    } finally {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tts = ref.watch(ttsServiceProvider);
    final label = widget.accent == TtsAccent.british ? '英' : '美';
    final isDisabled = !tts.isAvailable;

    return Tooltip(
      message: isDisabled ? '发音暂不可用' : '',
      child: GestureDetector(
        onTap: (isDisabled || _isPlaying) ? null : _play,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDisabled ? const Color(0xFFEEEEEE) : const Color(0xFFFFF0F0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isPlaying)
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFE8002D)),
                )
              else if (_hasError)
                const Icon(Icons.error_outline, size: 14, color: Color(0xFFFF5252))
              else
                Icon(Icons.volume_up, size: 14,
                    color: isDisabled
                        ? const Color(0xFF999999)
                        : const Color(0xFFE8002D)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(
                fontSize: 12,
                color: isDisabled
                    ? const Color(0xFF999999)
                    : const Color(0xFFE8002D),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 6. 收藏功能实现

```dart
@HiveType(typeId: 0)
class FavoriteWord extends HiveObject {
  @HiveField(0) late String word;
  @HiveField(1) late String briefDefinition;
  @HiveField(2) late DateTime addedAt;
}

class FavoritesRepositoryImpl implements FavoritesRepository {
  final Box<FavoriteWord> _box = Hive.box('favorites');

  @override
  Stream<List<FavoriteWord>> watchFavorites() {
    return _box.watch().map((_) => _getSorted()).startWith(_getSorted());
  }

  List<FavoriteWord> _getSorted() {
    return _box.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  @override
  Future<void> addFavorite(String word, String briefDef) async {
    final fav = FavoriteWord()
      ..word = word
      ..briefDefinition = briefDef
      ..addedAt = DateTime.now();
    await _box.put(word, fav);
  }

  @override
  Future<void> removeFavorite(String word) => _box.delete(word);

  @override
  bool isFavorite(String word) => _box.containsKey(word);
}
```

---

## 7. 历史记录实现

```dart
@HiveType(typeId: 1)
class HistoryEntry extends HiveObject {
  @HiveField(0) late String word;
  @HiveField(1) late DateTime lastSearchedAt;
  @HiveField(2) late int searchCount;
}

class HistoryRepositoryImpl implements HistoryRepository {
  static const _maxEntries = 500;
  final Box<HistoryEntry> _box = Hive.box('history');

  @override
  Future<void> addEntry(String word) async {
    final existing = _box.get(word);
    if (existing != null) {
      existing.lastSearchedAt = DateTime.now();
      existing.searchCount++;
      await existing.save();
    } else {
      if (_box.length >= _maxEntries) {
        final oldest = _box.values.reduce(
          (a, b) => a.lastSearchedAt.isBefore(b.lastSearchedAt) ? a : b,
        );
        await oldest.delete();
      }
      await _box.put(word, HistoryEntry()
        ..word = word
        ..lastSearchedAt = DateTime.now()
        ..searchCount = 1);
    }
  }

  @override
  Stream<List<HistoryEntry>> watchHistory() {
    return _box.watch().map((_) => _getSorted()).startWith(_getSorted());
  }

  List<HistoryEntry> _getSorted() {
    return _box.values.toList()
      ..sort((a, b) => b.lastSearchedAt.compareTo(a.lastSearchedAt));
  }

  @override
  Future<void> deleteEntry(String word) => _box.delete(word);

  @override
  Future<void> clearAll() => _box.clear();
}
```

---

## 8. 设置页实现

```dart
// lib/features/settings/presentation/screens/settings_screen.dart
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final llmStatus = ref.watch(llmServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          if (PlatformUtils.isDesktop) ...[
            const _SectionHeader('外观'),
            ListTile(
              title: const Text('主题模式'),
              trailing: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                  ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
                ],
                selected: {themeMode},
                onSelectionChanged: (modes) =>
                    ref.read(themeModeProvider.notifier).setTheme(modes.first),
              ),
            ),
          ],
          const _SectionHeader('AI 功能'),
          _buildLlmTile(context, ref, llmStatus),
          const _SectionHeader('数据管理'),
          ListTile(
            title: const Text('清除搜索历史'),
            leading: const Icon(Icons.history),
            onTap: () => _confirmClear(context, ref, isHistory: true),
          ),
          ListTile(
            title: const Text('清除所有收藏'),
            leading: const Icon(Icons.star_outline),
            onTap: () => _confirmClear(context, ref, isHistory: false),
          ),
          const _SectionHeader('关于'),
          const ListTile(title: Text('版本'), trailing: Text('1.0.0')),
          const ListTile(
            title: Text('词典'),
            trailing: Text('ECDICT (~330万词条)'),
          ),
        ],
      ),
    );
  }

  Widget _buildLlmTile(BuildContext context, WidgetRef ref, LlmStatus status) {
    return switch (status) {
      LlmStatus.notLoaded => ListTile(
          title: const Text('AI 模型'),
          subtitle: const Text('未安装'),
          trailing: FilledButton(
            onPressed: () => context.push('/model-download'),
            child: const Text('下载'),
          ),
        ),
      LlmStatus.loading => const ListTile(
          title: Text('AI 模型'),
          subtitle: Text('加载中...'),
          trailing: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      LlmStatus.ready => ListTile(
          title: const Text('AI 模型'),
          subtitle: Text(ref.read(llmModelNameProvider) ?? '已就绪'),
          trailing: TextButton(
            onPressed: () => _showModelOptions(context, ref),
            child: const Text('管理'),
          ),
        ),
      LlmStatus.error => ListTile(
          title: const Text('AI 模型'),
          subtitle: const Text('加载失败',
              style: TextStyle(color: Colors.red)),
          trailing: TextButton(
            onPressed: () => ref.read(llmServiceProvider.notifier).retry(),
            child: const Text('重试'),
          ),
        ),
    };
  }
}
```

---

## 9. 数据准备脚本

```python
# tools/import_ecdict.py
import csv, sqlite3, sys

def import_ecdict(csv_path: str, db_path: str):
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL, phonetic TEXT,
        definition TEXT, translation TEXT, pos TEXT,
        collins INTEGER DEFAULT 0, oxford INTEGER DEFAULT 0,
        tag TEXT, bnc INTEGER DEFAULT 0, frq INTEGER DEFAULT 0,
        exchange TEXT, detail TEXT
    )''')
    c.execute('CREATE INDEX IF NOT EXISTS idx_word ON words(word COLLATE NOCASE)')

    with open(csv_path, encoding='utf-8') as f:
        reader = csv.DictReader(f)
        batch = []
        for i, row in enumerate(reader):
            batch.append((
                row.get('word', ''), row.get('phonetic', ''),
                row.get('definition', ''), row.get('translation', ''),
                row.get('pos', ''),
                int(row.get('collins', 0) or 0),
                int(row.get('oxford', 0) or 0),
                row.get('tag', ''),
                int(row.get('bnc', 0) or 0),
                int(row.get('frq', 0) or 0),
                row.get('exchange', ''), row.get('detail', ''),
            ))
            if len(batch) >= 10000:
                c.executemany(
                    'INSERT INTO words VALUES (NULL,?,?,?,?,?,?,?,?,?,?,?,?)',
                    batch)
                batch.clear()
                print(f'Imported {i+1} rows...')
        if batch:
            c.executemany(
                'INSERT INTO words VALUES (NULL,?,?,?,?,?,?,?,?,?,?,?,?)',
                batch)

    conn.commit()
    conn.close()
    print(f'Done! Database saved to {db_path}')

if __name__ == '__main__':
    import_ecdict(sys.argv[1], sys.argv[2])
```

---

## 10. 构建与发布

### Android

```bash
flutter run -d android
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

### Windows

```bash
flutter run -d windows
flutter build windows --release
# 输出: build/windows/x64/runner/Release/
# 需将 llama.dll 复制到输出目录（llama_cpp_dart 提供）
```

### 注意事项

1. `assets/dictionary.db` 需在 `pubspec.yaml` 中声明：
   ```yaml
   flutter:
     assets:
       - assets/dictionary.db
   ```

2. Android `minSdkVersion` 建议设为 21（Android 5.0+）

3. Windows 需要 Visual Studio 2022 + C++ 工作负载

4. Windows 发布时需将 `llama.dll` 复制到 Release 目录

### 1.1 pubspec.yaml

Key changes from original:
- Added `dio: ^5.4.0` for model download with resume support

### 1.2 main.dart

Key changes from original:
- `App` is now `ConsumerStatefulWidget` with `WidgetsBindingObserver`
- `didChangeAppLifecycleState` releases/restores LLM context on pause/resume
- `themeMode` uses `ref.watch(themeModeProvider)` instead of hardcoded value
- Android: ThemeModeNotifier returns ThemeMode.system
- Windows: ThemeModeNotifier defaults to ThemeMode.light, user can switch

