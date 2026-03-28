# RFPlayer — 架构设计文档

## 项目概述

RFPlayer 是一个基于 Flutter 的跨平台媒体播放器，支持 Android 和 Windows 11。
核心能力：全格式视频播放、图片查看、文件系统导航、播放历史管理。

---

## 技术栈

| 类别 | 选型 | 版本 | 理由 |
|------|------|------|------|
| 视频播放 | media_kit + media_kit_video | ^1.1.11 | 基于 libmpv，全格式，硬件加速，支持播放速率控制和变速不变调 |
| 图片查看 | extended_image | ^8.3.0 | 手势流畅，缓存完善，比 photo_view 更活跃维护 |
| 状态管理 | flutter_riverpod | ^2.5.1 | 编译时安全，依赖注入清晰，易测试 |
| 本地数据库 | drift (SQLite) | ^2.18.0 | 类型安全，支持迁移，跨平台稳定 |
| 路由 | go_router | ^14.2.7 | 声明式路由，支持深链接，与 Riverpod 集成好 |
| Windows UI | fluent_ui | ^4.8.6 | 官方 Fluent Design 实现，与 Material 3 可并存 |
| 文件选择 | file_picker | ^8.1.2 | 跨平台统一 API，支持目录选择 |
| 路径工具 | path_provider + path | ^2.1.3 / ^1.9.0 | 标准路径获取 |
| 权限 | permission_handler | ^11.3.1 | 统一权限请求 API |
| 轻量存储 | shared_preferences | ^2.3.2 | 存储 AppSettings |
| 图片缓存 | flutter_cache_manager | ^3.4.1 | 缩略图本地缓存 |
| 国际化 | flutter_localizations | ^3.16.0 | 官方国际化支持，支持多语言 |
| 代码生成 | freezed + riverpod_generator + drift_dev | — | 减少样板代码 |

---

## 架构分层

```
┌──────────────────────────────────────────────────┐
│                Presentation Layer                 │
│   Pages  ←→  Providers (Riverpod)  ←→  Widgets   │
├──────────────────────────────────────────────────┤
│                  Domain Layer                     │
│        UseCases  →  Services  →  Logic            │
├──────────────────────────────────────────────────┤
│                   Data Layer                      │
│    Repositories  →  DAOs  →  Drift / Prefs        │
├──────────────────────────────────────────────────┤
│                 Platform Layer                    │
│         Android-specific / Windows-specific       │
└──────────────────────────────────────────────────┘
```

**各层职责：**
- **Presentation**：UI 渲染、用户交互、Riverpod Provider 状态订阅
- **Domain**：业务规则、用例编排、跨层服务（播放器、缩略图、权限）
- **Data**：数据持久化、数据库操作、设置读写
- **Platform**：平台差异封装（权限策略、文件系统访问方式）

---

## 项目目录结构

```
lib/
├── main.dart                          # 入口：MediaKit.ensureInitialized() + ProviderScope
├── app.dart                           # RFPlayerApp：根据 UIStyle 返回 MaterialApp 或 FluentApp
│
├── core/                              # 跨层共享基础设施（无业务逻辑）
│   ├── constants/
│   │   ├── app_constants.dart         # 路由名、DB 文件名、缓存目录名等全局常量
│   │   └── supported_formats.dart    # 支持的视频/图片扩展名列表
│   ├── extensions/
│   │   ├── string_extensions.dart    # isVideoFile(), isImageFile(), fileExtension
│   │   └── duration_extensions.dart  # toHHMMSS(), toProgressString()
│   ├── localization/
│   │   ├── app_localizations.dart    # 国际化代理类
│   │   ├── en_US.dart                # 英语语言包
│   │   └── zh_CN.dart                # 中文语言包
│   └── utils/
│       ├── platform_utils.dart       # isAndroid(), isWindows(), getDefaultMediaDir()
│       ├── file_utils.dart           # formatFileSize(), getFileIcon()
│       └── thumbnail_utils.dart      # 缩略图路径生成、缓存键计算
│
├── data/                              # 数据层
│   ├── database/
│   │   ├── app_database.dart         # @DriftDatabase 定义，包含所有 Table 和 DAO
│   │   ├── tables/
│   │   │   ├── media_items_table.dart
│   │   │   ├── play_history_table.dart
│   │   │   └── bookmarks_table.dart
│   │   └── daos/
│   │       ├── media_dao.dart        # MediaItem CRUD
│   │       ├── history_dao.dart      # PlayHistory CRUD + upsert
│   │       └── bookmark_dao.dart    # Bookmark CRUD + reorder
│   ├── models/
│   │   ├── media_item.dart           # MediaItem + MediaType enum
│   │   ├── play_history.dart         # PlayHistory + progress getter
│   │   ├── bookmark.dart             # Bookmark
│   │   └── app_settings.dart         # AppSettings + ThemeMode + UIStyle enums
│   └── repositories/
│       ├── history_repository.dart   # 历史记录读写，封装 HistoryDao
│       ├── bookmark_repository.dart  # 书签读写，封装 BookmarkDao
│       └── settings_repository.dart  # SharedPreferences 读写 AppSettings
│
├── domain/                            # 业务逻辑层
│   ├── services/
│   │   ├── player_service.dart        # media_kit Player 单例封装，硬件加速配置
│   │   ├── thumbnail_service.dart     # 视频截帧 + 图片缩略图，Isolate 后台，LRU 缓存
│   │   └── permission_service.dart    # 抽象类 + 平台工厂方法
│   └── usecases/
│       ├── open_media_usecase.dart    # 打开媒体文件：PlayerService.open() + 写历史
│       ├── resume_playback_usecase.dart # 读取 lastPosition，传给 PlayerService
│       └── manage_bookmarks_usecase.dart # 书签增删改
│
├── presentation/                      # UI 层
│   ├── providers/
│   │   ├── player_provider.dart       # PlayerNotifier + PlayerState
│   │   ├── history_provider.dart      # HistoryNotifier + AsyncValue<List<PlayHistory>>
│   │   ├── file_browser_provider.dart # FileBrowserNotifier + FileBrowserState
│   │   ├── bookmark_provider.dart     # BookmarkNotifier + List<Bookmark>
│   │   └── settings_provider.dart    # SettingsNotifier + AppSettings
│   ├── router/
│   │   └── app_router.dart           # GoRouter 配置，ShellRoute + 子路由
│   ├── theme/
│   │   ├── app_theme.dart            # Material 3 ThemeData（light + dark）
│   │   ├── fluent_theme.dart         # FluentThemeData（light + dark）
│   │   └── theme_switcher.dart       # 根据 AppSettings 返回当前有效主题
│   ├── shell/
│   │   ├── main_shell.dart           # 入口：根据 UIStyle 选择 material_shell 或 fluent_shell
│   │   ├── material_shell.dart       # Scaffold + BottomNavigationBar（4 个 Tab）
│   │   └── fluent_shell.dart         # NavigationView + NavigationPane（4 个 Tab）
│   ├── pages/
│   │   ├── home/
│   │   │   ├── home_page.dart        # Tab 1：功能选择卡片网格
│   │   │   └── widgets/
│   │   │       └── feature_card.dart # 单个功能卡片（图标 + 标题 + onTap）
│   │   ├── history/
│   │   │   ├── history_page.dart     # Tab 2：播放历史列表
│   │   │   └── widgets/
│   │   │       ├── history_list_item.dart  # 缩略图 + 进度条 + 时间
│   │   │       └── thumbnail_widget.dart   # 缩略图加载组件（含占位符）
│   │   ├── file_browser/
│   │   │   ├── file_browser_page.dart # Tab 3：文件浏览器
│   │   │   └── widgets/
│   │   │       ├── breadcrumb_bar.dart    # 面包屑路径导航
│   │   │       ├── file_list_item.dart    # 单个文件/目录行
│   │   │       └── bookmark_panel.dart    # 横向书签列表
│   │   ├── settings/
│   │   │   ├── settings_page.dart    # Tab 4：设置页
│   │   │   └── widgets/
│   │   │       ├── settings_section.dart  # 设置分组容器
│   │   │       └── theme_selector.dart    # UI 风格选择器
│   │   ├── video_player/
│   │   │   ├── video_player_page.dart # 全屏视频播放页
│   │   │   └── widgets/
│   │   │       ├── player_controls.dart   # 播放控制栏
│   │   │       ├── progress_bar.dart      # 进度条（含拖拽）
│   │   │       └── player_overlay.dart    # 手势检测 + 控制栏显隐动画
│   │   └── image_viewer/
│   │       ├── image_viewer_page.dart # 图片查看页
│   │       └── widgets/
│   │           ├── image_gesture_wrapper.dart # 缩放/滑动手势
│   │           └── image_info_overlay.dart    # 文件信息浮层
│   └── widgets/                       # 全局复用组件
│       ├── adaptive_scaffold.dart    # 自适应布局容器
│       ├── loading_indicator.dart
│       └── error_view.dart
│
└── platform/                          # 平台特定实现
    ├── android/
    │   └── android_permission_handler.dart  # Android 分版本权限处理
    └── windows/
        └── windows_file_access.dart         # Windows 文件系统默认路径
```

---

## Riverpod Provider 依赖关系

```
appDatabaseProvider (单例)
  └── historyDaoProvider
      └── historyRepositoryProvider
          └── historyProvider (StateNotifierProvider)
              └── HistoryPage (Consumer)

  └── bookmarkDaoProvider
      └── bookmarkRepositoryProvider
          └── bookmarkProvider
              └── FileBrowserPage (Consumer)

settingsRepositoryProvider
  └── settingsProvider
      └── app.dart (Consumer) → 决定 MaterialApp / FluentApp

playerServiceProvider (单例)
  └── playerProvider (StateNotifierProvider<PlayerState>)
      └── VideoPlayerPage (Consumer)

thumbnailServiceProvider
  └── historyProvider (生成缩略图后更新历史记录)
```

---

## 路由结构

```
/ (ShellRoute → MainShell)
├── /home          → HomePage        (Tab 1)
├── /history       → HistoryPage     (Tab 2)
├── /files         → FileBrowserPage (Tab 3)
└── /settings      → SettingsPage    (Tab 4)

/video-player      → VideoPlayerPage (全屏，独立路由，不在 Shell 内)
/image-viewer      → ImageViewerPage (全屏，独立路由，不在 Shell 内)
```

---

## pubspec.yaml 依赖清单

```yaml
dependencies:
  flutter:
    sdk: flutter
  media_kit: ^1.1.11
  media_kit_video: ^1.1.11
  media_kit_libs_video: ^1.0.4
  extended_image: ^8.3.0
  file_picker: ^8.1.2
  path_provider: ^2.1.3
  path: ^1.9.0
  permission_handler: ^11.3.1
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.24
  drift_flutter: ^0.2.1
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^14.2.7
  fluent_ui: ^4.8.6
  shared_preferences: ^2.3.2
  flutter_cache_manager: ^3.4.1
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  uuid: ^4.4.2

dev_dependencies:
  build_runner: ^2.4.11
  drift_dev: ^2.18.0
  freezed: ^2.5.2
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.0
  flutter_lints: ^6.0.0
```