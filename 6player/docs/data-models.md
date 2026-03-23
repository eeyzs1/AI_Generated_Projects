# RFPlayer — 数据模型设计

## 概述

RFPlayer 使用 Drift (SQLite) 作为本地数据库，存储三类核心数据：
- **PlayHistory**：播放历史（含续播位置、缩略图）
- **Bookmark**：用户自定义目录书签
- **AppSettings**：应用设置（存储于 SharedPreferences，非数据库）

---

## 数据模型详细定义

### 1. MediaType 枚举

```dart
// lib/data/models/media_item.dart
enum MediaType {
  video,
  image,
}
```

### 2. MediaItem（内存模型，不持久化）

MediaItem 是从文件系统实时构建的内存对象，不存入数据库。
每次打开文件或浏览目录时动态创建。

```dart
// lib/data/models/media_item.dart
class MediaItem {
  final String id;              // path 的 MD5 hash，用作唯一标识
  final String path;            // 文件绝对路径
  final String name;            // 文件名（含扩展名）
  final String displayName;     // 文件名（不含扩展名）
  final String extension;       // 小写扩展名，如 "mp4"
  final MediaType type;         // video | image
  final int fileSize;           // 字节数
  final DateTime? modifiedAt;   // 文件修改时间
  final String? thumbnailPath;  // 本地缓存缩略图路径（可为 null）
  final Duration? duration;     // 视频时长（图片为 null）

  // 工厂方法：从文件路径构造
  factory MediaItem.fromPath(String filePath);

  // 判断是否为视频
  bool get isVideo => type == MediaType.video;

  // 判断是否为图片
  bool get isImage => type == MediaType.image;
}
```

### 3. PlayHistory（持久化到 Drift）

```dart
// lib/data/models/play_history.dart
class PlayHistory {
  final String id;                  // UUID v4
  final String path;                // 文件绝对路径（冗余存储，防止 MediaItem 被删）
  final String displayName;         // 显示名称（文件名不含扩展名）
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

### 4. Bookmark（持久化到 Drift）

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

### 5. AppSettings（SharedPreferences，非数据库）

```dart
// lib/data/models/app_settings.dart

enum ThemeMode { system, light, dark }

enum UIStyle {
  material3,  // 强制 Material 3
  fluent,     // 强制 Fluent Design
  adaptive,   // 自动：Android → Material 3，Windows → Fluent
}

class AppSettings {
  final ThemeMode themeMode;              // 亮/暗/跟随系统
  final UIStyle uiStyle;                  // UI 风格
  final bool rememberPlaybackPosition;    // 是否记住播放位置（续播开关）
  final int historyMaxItems;              // 历史记录最大条数，默认 100
  final String? defaultOpenPath;          // 文件浏览器默认打开目录
  final bool showHiddenFiles;             // 是否显示隐藏文件，默认 false

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.uiStyle = UIStyle.adaptive,
    this.rememberPlaybackPosition = true,
    this.historyMaxItems = 100,
    this.defaultOpenPath,
    this.showHiddenFiles = false,
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

### bookmarks 表

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | TEXT | PRIMARY KEY | UUID v4 |
| path | TEXT | NOT NULL, UNIQUE | 目录绝对路径 |
| display_name | TEXT | NOT NULL | 显示名称 |
| created_at | INTEGER | NOT NULL | Unix 时间戳（毫秒） |
| sort_order | INTEGER | NOT NULL, DEFAULT 0 | 排序权重 |

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
    │       └─► media_kit Player.open(Media(path))
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
