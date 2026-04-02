# 功能架构设计 — 有道词典 Flutter 复刻版

## 1. 整体架构

采用 **Clean Architecture + Riverpod** 状态管理，分层清晰，便于双端适配。

```
┌─────────────────────────────────────────────────────┐
│                  Presentation Layer                  │
│  Screens / Widgets / Providers (Riverpod)            │
├─────────────────────────────────────────────────────┤
│                   Domain Layer                       │
│  Use Cases / Entities / Repository Interfaces        │
├─────────────────────────────────────────────────────┤
│                    Data Layer                        │
│  Repositories / Data Sources / Models                │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ SQLite词典DB │  │ Hive本地存储 │  │ TTS引擎   │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
│  ┌──────────────────────────────────────────────┐   │
│  │         本地 LLM (llama.cpp)                 │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## 2. 目录结构

```
lib/
├── main.dart
├── app.dart                          # MaterialApp 配置
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   └── app_strings.dart
│   ├── theme/
│   │   └── app_theme.dart
│   ├── router/
│   │   └── app_router.dart           # go_router 路由配置
│   ├── utils/
│   │   ├── platform_utils.dart       # 平台判断工具
│   │   └── debouncer.dart
│   └── di/
│       └── providers.dart            # 全局 Riverpod providers
│
├── features/
│   ├── dictionary/                   # 词典查询功能
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── dictionary_local_datasource.dart
│   │   │   │   └── llm_datasource.dart
│   │   │   ├── models/
│   │   │   │   ├── word_entry_model.dart
│   │   │   │   └── definition_model.dart
│   │   │   └── repositories/
│   │   │       └── dictionary_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── word_entry.dart
│   │   │   │   ├── definition.dart
│   │   │   │   └── example_sentence.dart
│   │   │   ├── repositories/
│   │   │   │   └── dictionary_repository.dart
│   │   │   └── usecases/
│   │   │       ├── search_word.dart
│   │   │       ├── get_suggestions.dart
│   │   │       └── get_word_detail.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── search_provider.dart
│   │       │   └── word_detail_provider.dart
│   │       ├── screens/
│   │       │   ├── home_screen.dart
│   │       │   └── word_detail_screen.dart
│   │       └── widgets/
│   │           ├── search_bar_widget.dart
│   │           ├── suggestion_list.dart
│   │           ├── word_header_card.dart
│   │           ├── definition_section.dart
│   │           ├── example_card.dart
│   │           └── pronunciation_button.dart
│   │
│   ├── favorites/                    # 收藏功能
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── favorites_local_datasource.dart
│   │   │   └── repositories/
│   │   │       └── favorites_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── favorite_word.dart
│   │   │   ├── repositories/
│   │   │   │   └── favorites_repository.dart
│   │   │   └── usecases/
│   │   │       ├── add_favorite.dart
│   │   │       ├── remove_favorite.dart
│   │   │       ├── get_favorites.dart
│   │   │       └── is_favorite.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── favorites_provider.dart
│   │       └── screens/
│   │           └── favorites_screen.dart
│   │
│   ├── history/                      # 历史记录功能
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── history_local_datasource.dart
│   │   │   └── repositories/
│   │   │       └── history_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── history_entry.dart
│   │   │   ├── repositories/
│   │   │   │   └── history_repository.dart
│   │   │   └── usecases/
│   │   │       ├── add_history.dart
│   │   │       ├── get_history.dart
│   │   │       └── clear_history.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── history_provider.dart
│   │       └── screens/
│   │           └── history_screen.dart
│   │
│   ├── tts/                          # 文字转语音
│   │   ├── data/
│   │   │   └── tts_service.dart
│   │   └── domain/
│   │       └── tts_repository.dart
│   │
│   ├── llm/                          # 本地 LLM（新增独立模块）
│   │   ├── data/
│   │   │   ├── android_llm_datasource.dart
│   │   │   ├── windows_llm_datasource.dart
│   │   │   └── model_downloader.dart
│   │   ├── domain/
│   │   │   ├── llm_datasource.dart   # 抽象接口
│   │   │   └── llm_service.dart      # Riverpod Notifier
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── llm_provider.dart
│   │       └── screens/
│   │           └── model_download_screen.dart
│   │
│   ├── settings/                     # 设置页（新增）
│   │   └── presentation/
│   │       └── screens/
│   │           └── settings_screen.dart
│   │
│   └── daily_word/                   # 每日一词
│       ├── data/
│       │   └── daily_word_datasource.dart
│       └── presentation/
│           └── widgets/
│               └── daily_word_card.dart
│
└── shared/
    └── widgets/
        ├── adaptive_scaffold.dart
        ├── empty_state_widget.dart
        ├── loading_shimmer.dart
        └── platform_context_menu.dart
```

---

## 3. 核心功能模块

### 3.1 词典数据库模块

**数据来源：** 使用开源 ECDICT 词典（CSV 转 SQLite），包含约 330 万词条。

**数据库 Schema：**

```sql
-- 主词条表
CREATE TABLE words (
    id          INTEGER PRIMARY KEY,
    word        TEXT NOT NULL,
    phonetic    TEXT,
    definition  TEXT,           -- 英文释义（\n分隔）
    translation TEXT,           -- 中文释义（\n分隔）
    pos         TEXT,           -- 词性 n./v./adj.
    collins     INTEGER,        -- Collins 星级 0-5
    oxford      INTEGER,        -- 是否牛津核心词
    tag         TEXT,           -- 标签 zk/gk/ielts/toefl
    bnc         INTEGER,        -- BNC 词频
    frq         INTEGER,        -- 当代英语词频
    exchange    TEXT,           -- 词形变化 p:past/d:done...
    detail      TEXT,           -- 详细释义 JSON
    audio       TEXT            -- 音频文件路径（可选）
);

-- 前缀索引（加速补全）
CREATE INDEX idx_word_prefix ON words(word COLLATE NOCASE);

-- 例句表
CREATE TABLE examples (
    id          INTEGER PRIMARY KEY,
    word_id     INTEGER REFERENCES words(id),
    english     TEXT NOT NULL,
    chinese     TEXT,
    source      TEXT
);
```

**查询性能目标：**
- 精确查询：< 10ms
- 前缀补全（8条）：< 30ms
- 模糊搜索：< 100ms

**数据库打包策略（方案A，已确定）：**

将 `dictionary.db` 放入 `assets/`，随 APK/EXE 分发。首次启动时从 assets 复制到应用私有目录，并显示进度条。

```
assets/dictionary.db（压缩后约 80MB）
  → 首次启动解压到 getApplicationDocumentsDirectory()/dictionary.db
  → 后续直接读取，不再复制
  → 复制进度通过 Stream<double> 暴露给 Splash 页面
```

**数据库损坏恢复：**
- 启动时校验数据库完整性（`PRAGMA integrity_check`）
- 校验失败时删除损坏文件并重新从 assets 复制

### 3.2 本地 LLM 模块

**用途：** 提供超出词典数据库范围的增强功能：
- 短语/句子翻译
- 词义辨析
- 语境例句生成

**推荐模型（已确定）：**

| 模型 | 量化 | 大小 | RAM占用 | 适用场景 |
|------|------|------|---------|----------|
| Qwen2.5-0.5B-Instruct | Q4_K_M | ~400MB | ~600MB | Android 低端机 |
| Qwen2.5-1.5B-Instruct | Q4_K_M | ~900MB | ~1.2GB | Android 中高端（默认） |
| Qwen2.5-3B-Instruct | Q4_K_M | ~1.8GB | ~2.5GB | Windows（默认） |
| Phi-3.5-mini-instruct | Q4_K_M | ~2.2GB | ~3GB | Windows 备选 |

**模型分发策略（方案B，已确定）：**

首次使用 AI 功能时触发下载流程，支持断点续传。不内置模型（避免 APK 过大）。同时支持方案C（用户手动导入 GGUF 文件）作为高级选项。

**集成方案：**
- Android：`flutter_llama_cpp` 插件（JNI 调用 llama.cpp）
- Windows：`llama_cpp_dart` 包（dart:ffi 调用 llama.dll）

**模型存储路径：**
```
Android: getApplicationSupportDirectory()/models/
Windows: getApplicationSupportDirectory()/models/
         (实际路径: %APPDATA%\YoudaoDict\models\)
```

### 3.3 TTS 发音模块

**方案：** `flutter_tts` 包，调用系统 TTS 引擎

```
Android: Google TTS / 系统内置 TTS
Windows: Windows Speech API (SAPI)
```

**发音配置：**
```dart
tts.setLanguage("en-GB");  // 英式
tts.setLanguage("en-US");  // 美式
tts.setSpeechRate(0.8);    // 稍慢，便于学习
```

**错误处理：**
- Android：启动时检测 TTS 引擎，未安装时发音按钮置灰并提示安装
- 播放失败时通过 `onError` 回调更新按钮状态，支持重试

### 3.4 收藏与历史模块

**存储方案：** Hive（NoSQL，纯 Dart，无需 FFI）

```dart
@HiveType(typeId: 0)
class FavoriteWord {
  @HiveField(0) String word;
  @HiveField(1) String briefDefinition;
  @HiveField(2) DateTime addedAt;
}

@HiveType(typeId: 1)
class HistoryEntry {
  @HiveField(0) String word;
  @HiveField(1) DateTime lastSearchedAt;
  @HiveField(2) int searchCount;
}
```

**容量限制：**
- 历史记录：最多 500 条，超出自动删除最旧的
- 收藏：无上限

### 3.5 设置模块（新增）

**持久化：** `shared_preferences`

**存储的设置项：**
```dart
// 主题模式（Windows 用户可切换，Android 固定跟随系统）
const String kThemeMode = 'theme_mode'; // 'light' | 'dark' | 'system'

// 已安装的模型路径
const String kModelPath = 'llm_model_path';

// 模型大小偏好
const String kModelSize = 'llm_model_size'; // '0.5b' | '1.5b' | '3b'
```

---

## 4. 状态管理设计（Riverpod）

```dart
// 搜索状态
final searchQueryProvider = StateProvider<String>((ref) => '');

final suggestionsProvider = FutureProvider.family<List<String>, String>(
  (ref, query) => ref.read(dictionaryRepositoryProvider).getSuggestions(query),
);

final wordDetailProvider = FutureProvider.family<WordEntry?, String>(
  (ref, word) => ref.read(dictionaryRepositoryProvider).getWordDetail(word),
);

// 收藏状态（Stream，实时更新）
final favoritesProvider = StreamProvider<List<FavoriteWord>>(
  (ref) => ref.read(favoritesRepositoryProvider).watchFavorites(),
);

final isFavoriteProvider = Provider.family<bool, String>((ref, word) {
  final favorites = ref.watch(favoritesProvider).valueOrNull ?? [];
  return favorites.any((f) => f.word == word);
});

// 历史记录
final historyProvider = StreamProvider<List<HistoryEntry>>(
  (ref) => ref.read(historyRepositoryProvider).watchHistory(),
);

// LLM 状态
final llmServiceProvider = NotifierProvider<LlmService, LlmStatus>(
  LlmService.new,
);

// 主题模式（Windows 可切换）
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
```

---

## 5. 路由设计（go_router）

```dart
final router = GoRouter(routes: [
  GoRoute(
    path: '/',
    builder: (_, __) => const HomeScreen(),
    routes: [
      GoRoute(
        path: 'word/:word',
        builder: (_, state) => WordDetailScreen(
          word: state.pathParameters['word']!,
        ),
      ),
    ],
  ),
  GoRoute(path: '/favorites',      builder: (_, __) => const FavoritesScreen()),
  GoRoute(path: '/history',        builder: (_, __) => const HistoryScreen()),
  GoRoute(path: '/settings',       builder: (_, __) => const SettingsScreen()),
  GoRoute(path: '/model-download', builder: (_, __) => const ModelDownloadScreen()),
]);
```

---

## 6. 数据流图

```
用户输入
    │
    ▼
SearchProvider (Riverpod)
    │
    ├──▶ getSuggestions() ──▶ DictionaryLocalDataSource ──▶ SQLite
    │                                                         │
    │                                                    前缀匹配
    │                                                         │
    │◀──────────────────────────────────────────────── 补全列表
    │
    ├──▶ searchWord() ──▶ DictionaryRepository
    │                           │
    │                    ┌──────┴──────┐
    │                    │             │
    │               SQLite查询    LLM增强（可选，降级安全）
    │                    │             │
    │                    └──────┬──────┘
    │                           │
    │◀──────────────────── WordEntry
    │
    ├──▶ addHistory() ──▶ HistoryRepository ──▶ Hive
    │
    └──▶ WordDetailScreen 渲染
```

---

## 7. 依赖包清单

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 状态管理
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # 路由
  go_router: ^14.0.0

  # 本地数据库
  sqflite: ^2.3.3+1
  sqflite_common_ffi: ^2.3.3
  hive_flutter: ^1.1.0

  # TTS
  flutter_tts: ^4.0.2

  # UI 组件
  shimmer: ^3.0.0

  # 工具
  path_provider: ^2.1.3
  path: ^1.9.0
  shared_preferences: ^2.2.3

  # 窗口管理（Windows）
  window_manager: ^0.3.9

  # 网络（模型下载）
  dio: ^5.4.0

  # LLM（平台条件引入）
  # Android: flutter_llama_cpp（在 pubspec 中条件配置）
  # Windows: llama_cpp_dart

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.9
  hive_generator: ^2.0.1
  riverpod_generator: ^2.4.0
```

---

## 8. 词典数据准备

### ECDICT 数据导入流程

```bash
# 1. 下载 ECDICT
git clone https://github.com/skywind3000/ECDICT.git

# 2. 转换 CSV → SQLite
python tools/import_ecdict.py \
  --input ECDICT/stardict.csv \
  --output assets/dictionary.db

# 3. 压缩（可选，首次启动解压）
# 原始约 200MB，压缩后约 80MB
```

### 数据库完整性校验

```dart
// 启动时执行
Future<bool> verifyDatabase(Database db) async {
  final result = await db.rawQuery('PRAGMA integrity_check');
  return result.first.values.first == 'ok';
}
```
