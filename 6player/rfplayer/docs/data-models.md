# RFPlayer — 数据模型设计

## 概述

RFPlayer 使用 Drift (SQLite) 作为本地数据库，存储四类核心数据：
- **PlayHistory**：播放历史（含续播位置、缩略图）
- **Bookmark**：用户自定义目录书签
- **PlayQueue**：播放队列（支持自动连播）
- **AppSettings**：应用设置（存储于 SharedPreferences，非数据库）

---

## 数据模型详细定义

### 1. MediaType 枚举

```dart
// lib/data/models/play_history.dart
enum MediaType {
  video,
  image,
}
```

### 2. PlayHistory（持久化到 Drift）

```dart
// lib/data/models/play_history.dart
class PlayHistory {
  final String id;                  // UUID v4 或时间戳
  final String path;                // 文件绝对路径
  final String displayName;         // 显示名称（文件名）
  final String extension;           // 扩展名
  final MediaType type;             // video | image
  final String? thumbnailPath;      // 本地缓存缩略图路径
  final Duration? lastPosition;     // 上次播放/查看位置（视频续播用）
  final Duration? totalDuration;    // 视频总时长（图片为 null）
  final DateTime lastPlayedAt;      // 最后一次打开时间
  final int playCount;              // 累计打开次数

  // 播放进度 0.0 ~ 1.0
  double get progress {
    if (lastPosition == null || totalDuration == null) return 0.0;
    if (totalDuration!.inMilliseconds == 0) return 0.0;
    return (lastPosition!.inMilliseconds / totalDuration!.inMilliseconds).clamp(0.0, 1.0);
  }

  // 是否已看完（进度 > 95%）
  bool get isCompleted => progress > 0.95;

  // 格式化进度字符串，如 "12:34 / 1:23:45"
  String get progressString;
}
```

### 3. Bookmark（持久化到 Drift）

```dart
// lib/data/models/bookmark.dart
class Bookmark {
  final String id;              // UUID v4
  final String path;            // 目录绝对路径
  final String displayName;     // 用户自定义显示名称（默认为目录名）
  final DateTime createdAt;     // 创建时间
  final int sortOrder;          // 排序权重（支持拖拽排序）
}
```

### 4. PlayQueue（持久化到 Drift）

```dart
// lib/data/models/play_queue.dart
class PlayQueueItem {
  final String id;              // UUID v4
  final String path;            // 视频绝对路径
  final String displayName;     // 视频名称（文件名）
  final int sortOrder;          // 排序序号
  final DateTime addedAt;       // 添加时间
  final bool isCurrentPlaying;  // 是否正在播放
  final bool hasPlayed;         // 是否已播放完成
  final double playProgress;    // 播放进度（0.0-1.0）
  final bool isInvalid;         // 路径是否无效（文件不存在）

  // 资源类型标记（预留扩展）
  String get resourceType => 'video';
}
```

### 5. AppSettings（SharedPreferences，非数据库）

```dart
// lib/data/models/app_settings.dart

enum ThemeMode { system, light, dark }

enum UIStyle {
  material3,  // 强制 Material 3
  fluent,     // 强制 Fluent Design
  adaptive,   // 自动：Android → Material 3，Windows → Fluent
}

enum AppLanguage {
  system,     // 跟随系统
  zh_CN,      // 简体中文
  en_US,      // 英语
}

class AppSettings {
  final ThemeMode themeMode;              // 亮/暗/跟随系统
  final UIStyle uiStyle;                  // UI 风格
  final AppLanguage language;             // 应用语言
  final bool rememberPlaybackPosition;    // 是否记住播放位置（续播开关）
  final int historyMaxItems;              // 历史记录最大条数，默认 100
  final String? defaultOpenPath;          // 文件浏览器默认打开目录
  final bool showHiddenFiles;             // 是否显示隐藏文件，默认 false
  final double defaultPlaybackSpeed;      // 默认播放速率，默认 1.0

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.uiStyle = UIStyle.adaptive,
    this.language = AppLanguage.system,
    this.rememberPlaybackPosition = true,
    this.historyMaxItems = 100,
    this.defaultOpenPath,
    this.showHiddenFiles = false,
    this.defaultPlaybackSpeed = 1.0,
  });
}
```

---

## 数据库 Schema（Drift Tables）

### play_history 表

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | TEXT | PRIMARY KEY | UUID v4 |
| path | TEXT | NOT NULL, UNIQUE | 文件绝对路径 |
| display_name | TEXT | NOT NULL | 显示名称 |
| extension | TEXT | NOT NULL | 文件扩展名 |
| type | INTEGER | NOT NULL | 0=video, 1=image |
| thumbnail_path | TEXT | NULLABLE | 缩略图本地路径 |
| last_position_ms | INTEGER | NULLABLE | 续播位置（毫秒） |
| total_duration_ms | INTEGER | NULLABLE | 总时长（毫秒） |
| last_played_at | INTEGER | NOT NULL | Unix 时间戳（毫秒） |
| play_count | INTEGER | NOT NULL, DEFAULT 1 | 累计打开次数 |

**索引：**
- `idx_history_last_played_at` ON `last_played_at DESC`（历史列表排序）
- `idx_history_path` ON `path`（upsert 查找）
- `idx_history_type` ON `type`（按类型筛选）

### bookmarks 表

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | TEXT | PRIMARY KEY | UUID v4 |
| path | TEXT | NOT NULL, UNIQUE | 目录绝对路径 |
| display_name | TEXT | NOT NULL | 显示名称 |
| created_at | INTEGER | NOT NULL | Unix 时间戳（毫秒） |
| sort_order | INTEGER | NOT NULL, DEFAULT 0 | 排序权重 |

**索引：**
- `idx_bookmarks_sort_order` ON `sort_order`（书签排序）

### play_queue 表

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | TEXT | PRIMARY KEY | UUID v4 |
| path | TEXT | NOT NULL | 视频绝对路径 |
| display_name | TEXT | NOT NULL | 视频名称 |
| sort_order | INTEGER | NOT NULL | 排序序号 |
| added_at | INTEGER | NOT NULL | Unix 时间戳（毫秒） |
| is_current_playing | INTEGER | NOT NULL, DEFAULT 0 | 是否正在播放（0/1） |
| has_played | INTEGER | NOT NULL, DEFAULT 0 | 是否已播放完成（0/1） |
| play_progress | REAL | NOT NULL, DEFAULT 0.0 | 播放进度（0.0-1.0） |
| is_invalid | INTEGER | NOT NULL, DEFAULT 0 | 路径是否无效（0/1） |

**索引：**
- `idx_play_queue_sort_order` ON `sort_order`（队列排序）
- `idx_play_queue_current_playing` ON `is_current_playing`（查找当前播放项）

---

## 数据验证

- **路径验证**：确保文件路径有效且存在
- **类型验证**：确保媒体类型正确
- **范围验证**：确保播放进度在 0.0-1.0 之间
- **非空验证**：确保必要字段不为空

## 数据清理策略

- **历史记录清理**：超过 `historyMaxItems` 时删除最旧的记录
- **无效记录清理**：定期清理路径无效的记录
- **缩略图清理**：当缩略图文件不存在时清理对应记录
- **播放队列清理**：应用启动时清理无效路径的队列项

## 索引优化

- **复合索引**：为常用查询组合创建复合索引
- **覆盖索引**：创建覆盖索引减少回表操作
- **索引维护**：定期重建索引保持性能

---

## DAO 接口设计

### HistoryDao

```dart
abstract class HistoryDao {
  // 查询历史记录（按最后打开时间倒序，支持分页）
  Future<List<PlayHistory>> getHistory({int limit = 50, int offset = 0});

  // 查询单条记录（按路径）
  Future<PlayHistory?> getByPath(String path);

  // 插入或更新（path 唯一，存在则更新 lastPosition/lastPlayedAt/playCount）
  Future<void> upsert(PlayHistory history);

  // 更新播放位置（仅更新 lastPosition，不更新 lastPlayedAt）
  Future<void> updatePosition(String path, Duration position);

  // 删除单条
  Future<void> deleteById(String id);

  // 清空全部
  Future<void> deleteAll();

  // 监听历史记录变化（Stream，用于实时更新 UI）
  Stream<List<PlayHistory>> watchHistory({int limit = 50});
}
```

### BookmarkDao

```dart
abstract class BookmarkDao {
  // 查询全部书签（按 sortOrder 升序）
  Future<List<Bookmark>> getAll();

  // 插入书签
  Future<void> insert(Bookmark bookmark);

  // 删除书签
  Future<void> deleteById(String id);

  // 更新排序（批量更新 sortOrder）
  Future<void> reorder(List<String> orderedIds);

  // 监听书签变化
  Stream<List<Bookmark>> watchAll();
}

### PlayQueueDao

```dart
abstract class PlayQueueDao {
  // 查询全部播放队列项（按 sortOrder 升序）
  Future<List<PlayQueueItem>> getAll();

  // 插入队列项
  Future<void> insert(PlayQueueItem item);

  // 删除队列项
  Future<void> deleteById(String id);

  // 清空队列
  Future<void> deleteAll();

  // 全局重置所有播放状态
  Future<void> resetAllCurrentPlaying();

  // 设置当前播放项
  Future<void> setCurrentPlaying(String id);

  // 标记为已播放
  Future<void> markAsPlayed(String id);

  // 更新播放进度
  Future<void> updatePlayProgress(String id, double progress);

  // 更新排序（批量更新 sortOrder）
  Future<void> reorder(List<String> orderedIds);

  // 获取下一个播放项（按 sortOrder 查找）
  Future<PlayQueueItem?> getNextItem(int currentSortOrder);

  // 获取当前正在播放的项
  Future<PlayQueueItem?> getCurrentPlaying();

  // 监听队列变化
  Stream<List<PlayQueueItem>> watchAll();
}
```

---

## 数据流：打开媒体文件

```
用户点击文件
    │
    ▼
OpenMediaUseCase.execute(path)
    │
    ├─► PlayerService.open(path)
    │       └─► fvp Player.open(Media(path))
    │
    ├─► HistoryRepository.upsert(PlayHistory)
    │       └─► HistoryDao.upsert()  →  SQLite
    │
    └─► ThumbnailService.generateAsync(path)
            └─► Isolate 后台截帧
                └─► HistoryRepository.updateThumbnail(path, thumbPath)
```

## 数据流：续播

```
用户点击历史记录
    │
    ▼
ResumePlaybackUseCase.execute(history)
    │
    ├─► 检查 settings.rememberPlaybackPosition
    │
    ├─► PlayerService.open(history.path)
    │
    └─► PlayerService.seekTo(history.lastPosition)  ← 仅当 rememberPosition=true
```