# RFPlayer — 实施计划（7 个 Phase）

## 总览

| Phase | 内容 | 预计工时 | 验收标准 |
|-------|------|----------|----------|
| 1 | 项目初始化 + 基础架构 | 2-3 天 | App 启动，4 Tab 可切换，主题可切换 |
| 2 | 文件浏览器 Tab | 3-4 天 | 可浏览文件系统，书签增删正常 |
| 3 | 视频播放器 | 4-5 天 | 主流格式播放，控制栏交互流畅 |
| 4 | 图片查看器 | 2-3 天 | 图片正常显示，手势流畅 |
| 5 | 播放历史 Tab | 3-4 天 | 历史记录含缩略图，续播正常 |
| 6 | 功能选择 Tab + 设置页 | 2-3 天 | 从 Tab 1 可打开文件，设置持久化 |
| 7 | 跨平台适配 & 测试 | 3-5 天 | 两平台无明显 Bug，可发布 |

---

## Phase 1 — 项目初始化 + 基础架构

**目标**：可运行的空壳 App，路由/主题/状态管理就位，所有 Tab 可切换。

### 任务清单

#### 1.1 依赖配置
- 更新 `pubspec.yaml`，添加全部依赖（参见 architecture.md 依赖清单）
- 运行 `flutter pub get`
- 配置 `analysis_options.yaml`（启用 flutter_lints）

#### 1.2 核心常量
- 创建 `lib/core/constants/app_constants.dart`
  ```dart
  class AppConstants {
    static const String dbFileName = 'rfplayer.db';
    static const String thumbnailCacheDir = 'thumbnails';
    static const int defaultHistoryLimit = 100;
  }
  ```
- 创建 `lib/core/constants/supported_formats.dart`
  ```dart
  const videoFormats = ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'ts', 'rmvb'];
  const imageFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'];
  ```

#### 1.3 扩展方法
- 创建 `lib/core/extensions/string_extensions.dart`
  - `isVideoFile()`, `isImageFile()`, `fileExtension`
- 创建 `lib/core/extensions/duration_extensions.dart`
  - `toHHMMSS()`, `toProgressString(Duration total)`

#### 1.4 AppSettings 模型 + Repository
- 创建 `lib/data/models/app_settings.dart`（ThemeMode, UIStyle, AppSettings）
- 创建 `lib/data/repositories/settings_repository.dart`
  - 使用 SharedPreferences 读写 AppSettings
  - 提供 `load()` 和 `save(AppSettings)` 方法

#### 1.5 Drift 数据库初始化
- 创建 `lib/data/database/tables/play_history_table.dart`
- 创建 `lib/data/database/tables/bookmarks_table.dart`
- 创建 `lib/data/database/daos/history_dao.dart`（空实现）
- 创建 `lib/data/database/daos/bookmark_dao.dart`（空实现）
- 创建 `lib/data/database/app_database.dart`（@DriftDatabase 注解）
- 运行 `dart run build_runner build` 生成 `.g.dart` 文件

#### 1.6 Riverpod Providers
- 创建 `lib/presentation/providers/settings_provider.dart`
  ```dart
  @riverpod
  class SettingsNotifier extends _$SettingsNotifier {
    @override
    AppSettings build() => ref.read(settingsRepositoryProvider).load();
    Future<void> update(AppSettings settings) async { ... }
  }
  ```
- 创建数据库 Provider：`appDatabaseProvider`（单例）

#### 1.7 主题配置
- 创建 `lib/presentation/theme/app_theme.dart`（Material 3 light/dark ThemeData）
- 创建 `lib/presentation/theme/fluent_theme.dart`（FluentThemeData light/dark）

#### 1.8 路由配置
- 创建 `lib/presentation/router/app_router.dart`
  ```dart
  final appRouter = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomePage()),
          GoRoute(path: '/history', builder: (_, __) => const HistoryPage()),
          GoRoute(path: '/files', builder: (_, __) => const FileBrowserPage()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        ],
      ),
      GoRoute(path: '/video-player', builder: (_, state) => VideoPlayerPage(path: state.extra as String)),
      GoRoute(path: '/image-viewer', builder: (_, state) => ImageViewerPage(path: state.extra as String)),
    ],
  );
  ```

#### 1.9 导航外壳
- 创建 `lib/presentation/shell/material_shell.dart`（BottomNavigationBar，4 个 Tab）
- 创建 `lib/presentation/shell/fluent_shell.dart`（NavigationView + NavigationPane）
- 创建 `lib/presentation/shell/main_shell.dart`（根据 UIStyle 选择）

#### 1.10 占位页面
- 为 6 个页面创建最简占位实现（仅显示页面名称的 Scaffold）

#### 1.11 国际化支持
- 创建 `lib/core/localization/app_localizations.dart`
- 创建 `lib/core/localization/zh_CN.dart`（中文语言包）
- 创建 `lib/core/localization/en_US.dart`（英语语言包）
- 更新 `app.dart` 以支持国际化

#### 1.12 入口文件
- 更新 `lib/main.dart`
  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    fvp.registerWith();
    final db = AppDatabase();
    final historyRepository = HistoryRepository(db);
    final bookmarkRepository = BookmarkRepository(db);
    await historyRepository.cleanupInvalidRecords();
    await bookmarkRepository.cleanupInvalidRecords();
    runApp(const ProviderScope(child: RFPlayerApp()));
  }
  ```
- 创建 `lib/app.dart`（Material/Fluent 切换逻辑，参见 ui-design.md）

### 验收标准
- [ ] App 在 Android 模拟器和 Windows 上成功启动
- [ ] 4 个 Tab 可正常切换
- [ ] 设置页可切换 UI 风格（Material 3 / Fluent / 自适应），切换后立即生效
- [ ] 设置页可切换亮/暗主题
- [ ] 设置页可切换语言（跟随系统 / 简体中文 / English），切换后立即生效

---

## Phase 2 — 文件浏览器 Tab

**目标**：可浏览文件系统，支持书签快速跳转，点击媒体文件可跳转到播放页。

### 任务清单

#### 2.1 权限服务
- 创建 `lib/domain/services/permission_service.dart`（抽象类）
- 创建 `lib/platform/android/android_permission_handler.dart`
  - Android API 33+：`Permission.videos + Permission.photos`
  - Android API 29-32：`Permission.storage`
- 创建 `lib/platform/windows/windows_file_access.dart`（直接返回 true）
- 工厂方法：`PermissionService.create()` 根据平台返回对应实现

#### 2.2 平台工具
- 创建 `lib/core/utils/platform_utils.dart`
  - `getDefaultMediaDirectory()`：Android 返回外部存储，Windows 返回用户文档目录
  - `getUserHomeDirectory()`

#### 2.3 书签数据层
- 完善 `lib/data/database/daos/bookmark_dao.dart`（实现 CRUD + watchAll）
- 创建 `lib/data/models/bookmark.dart`
- 创建 `lib/data/repositories/bookmark_repository.dart`

#### 2.4 文件浏览器状态管理
- 创建 `lib/presentation/providers/file_browser_provider.dart`
  ```dart
  class FileBrowserState {
    final String currentPath;
    final List<FileSystemEntity> entries;
    final bool isLoading;
    final String? error;
  }

  @riverpod
  class FileBrowserNotifier extends _$FileBrowserNotifier {
    Future<void> navigateTo(String path) async { ... }
    Future<void> refresh() async { ... }
    // 目录在前，文件在后，各自按名称排序
    // 根据 showHiddenFiles 设置过滤隐藏文件
  }
  ```
- 创建 `lib/presentation/providers/bookmark_provider.dart`

#### 2.5 UI 组件
- 实现 `lib/presentation/pages/file_browser/widgets/breadcrumb_bar.dart`
- 实现 `lib/presentation/pages/file_browser/widgets/bookmark_panel.dart`
  - 横向滚动，长按弹出删除确认
- 实现 `lib/presentation/pages/file_browser/widgets/file_list_item.dart`
  - 根据文件类型显示不同图标和颜色
- 实现 `lib/presentation/pages/file_browser/file_browser_page.dart`

#### 2.6 文件工具
- 创建 `lib/core/utils/file_utils.dart`
  - `formatFileSize(int bytes)` → "1.2 MB"
  - `getFileIcon(String extension)` → IconData
  - `sortEntries(List<FileSystemEntity>)` → 目录在前，文件在后

### 验收标准
- [ ] 启动后默认打开用户媒体目录
- [ ] 可浏览子目录，面包屑正确更新
- [ ] 可添加当前目录为书签，书签面板显示
- [ ] 长按书签可删除
- [ ] 点击视频/图片文件跳转到对应播放页（占位页面）
- [ ] Android 权限请求流程正常（API 33+ 和旧版本）
- [ ] 隐藏文件根据设置显示/隐藏

---

## Phase 3 — 视频播放器

**目标**：全格式视频播放，含手势控制，自动保存播放进度。

### 任务清单

#### 3.1 视频播放器控制器
- 创建 `lib/presentation/pages/video_player/video_player_controller.dart`
  ```dart
  class MyVideoPlayerController {
    late final VideoPlayerController videoController;
    final String path;
    final WidgetRef ref;
    Timer? _positionTimer;
    bool _disposed = false;

    MyVideoPlayerController(this.path, this.ref) {
      videoController = VideoPlayerController.file(File(path));
    }

    Future<void> initialize() async {
      await videoController.initialize();

      final historyRepo = ref.read(historyRepositoryProvider);
      var history = await historyRepo.getByPath(path);

      if (history == null) {
        final extension = p.extension(path).substring(1).toLowerCase();
        history = ph.PlayHistory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          path: path,
          displayName: p.basename(path),
          extension: extension,
          type: ph.MediaType.video,
          lastPosition: Duration.zero,
          totalDuration: Duration.zero,
          lastPlayedAt: DateTime.now(),
          playCount: 1,
        );
        await historyRepo.upsert(history);
      } else {
        final extension = p.extension(path).substring(1).toLowerCase();
        final updatedHistory = ph.PlayHistory(
          id: history.id,
          path: history.path,
          displayName: history.displayName,
          extension: history.extension,
          type: history.type,
          lastPosition: history.lastPosition,
          totalDuration: Duration.zero,
          lastPlayedAt: DateTime.now(),
          playCount: history.playCount + 1,
        );
        await historyRepo.upsert(updatedHistory);

        if (updatedHistory.lastPosition != null && updatedHistory.lastPosition!.inMilliseconds > 0) {
          await videoController.seekTo(updatedHistory.lastPosition!);
        }
      }

      videoController.play();

      // 每1秒更新一次播放位置
      _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        updatePlaybackPosition();
      });
    }

    Future<void> updatePlaybackPosition() async {
      if (_disposed) return;
      final position = videoController.value.position;
      final historyRepo = ref.read(historyRepositoryProvider);
      await historyRepo.updatePosition(path, position);
    }

    void play() {
      videoController.play();
    }

    void pause() {
      videoController.pause();
    }

    void seek(Duration position) {
      videoController.seekTo(position);
    }

    void setVolume(double volume) {
      videoController.setVolume(volume);
    }

    double get volume {
      return videoController.value.volume;
    }

    void setPlaybackSpeed(double speed) {
      videoController.setPlaybackSpeed(speed);
    }

    double get playbackSpeed {
      return videoController.value.playbackSpeed;
    }

    Duration get duration {
      return videoController.value.duration;
    }

    Duration get position {
      return videoController.value.position;
    }

    bool get isPlaying {
      return videoController.value.isPlaying;
    }

    VideoPlayerController get controller {
      return videoController;
    }

    void dispose() {
      _disposed = true;
      _positionTimer?.cancel();
      videoController.dispose();
    }
  }
  ```

#### 3.4 UI 组件
- 实现 `lib/presentation/pages/video_player/widgets/progress_bar.dart`
  - Slider + 当前时间 + 总时长
  - 拖拽时显示预览时间
- 实现 `lib/presentation/pages/video_player/widgets/player_controls.dart`
  - 播放/暂停、上一个/下一个、音量、全屏切换
- 实现 `lib/presentation/pages/video_player/widgets/player_overlay.dart`
  - GestureDetector：点击切换控制栏显隐，滑动 seek/音量/亮度
  - 3 秒无操作自动隐藏控制栏
- 实现 `lib/presentation/pages/video_player/video_player_page.dart`

#### 3.5 进度自动保存
- 每 5 秒保存一次播放位置到 HistoryRepository
- 退出页面时立即保存

#### 3.6 播放速率控制
- 实现 SpeedControl 组件，包含固定档位选择、无级滑块和手动输入框
- 支持 0.25x ~ 4.0x 范围的速率调节，精度 0.01x
- 实现三种控制方式的实时双向同步
- 支持任意速率下的变速不变调
- 记忆用户上一次设置的播放速率，全局应用

#### 3.7 Windows 键盘快捷键
- Space：播放/暂停
- 左/右方向键：快退/快进 10 秒
- 上/下方向键：音量 +/-10%
- Esc：在AppBar隐藏的情况下，点击显示AppBar
- +：增加播放速率 0.1x
- -：减少播放速率 0.1x
- 0：重置播放速率为 1.0x

### 验收标准
- [ ] MP4/MKV/AVI/MOV/H.265 等格式正常播放
- [ ] 播放/暂停/进度条/音量控制正常
- [ ] 手势控制（滑动 seek/音量）响应正确
- [ ] 3 秒无操作控制栏自动隐藏
- [ ] 退出时自动保存播放位置
- [ ] AppBar显示/隐藏功能正常
- [ ] 点击屏幕显示AppBar功能正常
- [ ] Esc键显示AppBar功能正常
- [ ] 播放速率控制功能正常
  - [ ] Windows 固定档位（0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 1.75x, 2.0x, 2.25x, 2.5x, 2.75x, 3.0x, 3.25x, 3.5x, 3.75x, 4.0x）切换正常
  - [ ] Android固定档位（0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 1.75x, 2.0x, 2.25x, 2.5x, 2.75x, 3.0x）切换正常
  - [ ] 无级滑块（0.25x-4.0x, 0.01x精度）调节正常
  - [ ] 手动输入框支持任意合法速率输入
  - [ ] 三种控制方式实时双向同步
  - [ ] 任意速率下变速不变调
  - [ ] 全局记忆用户播放速率设置
- [ ] Windows 键盘快捷键正常工作
  - [ ] +：增加播放速率 0.1x
  - [ ] -：减少播放速率 0.1x
  - [ ] 0：重置播放速率为 1.0x

---

## Phase 4 — 图片查看器

**目标**：支持缩放/滑动的图片查看，可切换同目录图片。

### 任务清单

#### 4.1 图片查看器状态
- 创建 `lib/presentation/providers/image_viewer_provider.dart`
  - 当前图片路径、同目录图片列表、当前索引

#### 4.2 UI 组件
- 实现 `lib/presentation/pages/image_viewer/widgets/image_gesture_wrapper.dart`
  - ExtendedImage.file + GestureConfig（minScale: 0.9, maxScale: 3.0）
  - 双击放大/还原
- 实现 `lib/presentation/pages/image_viewer/widgets/image_info_overlay.dart`
  - 文件名、尺寸、大小、修改时间
- 实现 `lib/presentation/pages/image_viewer/image_viewer_page.dart`
  - PageView.builder（同目录图片列表）
  - 顶部：返回按钮 + 计数（1/10）+ 信息按钮
  - 底部：文件名

#### 4.3 写入查看历史
- 复用 `OpenMediaUseCase`，图片的 `lastPosition` 始终为 null

### 验收标准
- [ ] JPG/PNG/WebP/GIF 正常显示
- [ ] 双指缩放、双击放大/还原流畅
- [ ] 左右滑动切换同目录图片
- [ ] 图片信息面板显示正确
- [ ] 查看记录写入历史

---

## Phase 5 — 播放历史 Tab

**目标**：历史记录展示含缩略图和进度，支持续播。

### 任务清单

#### 5.1 缩略图服务
- 创建 `lib/domain/services/thumbnail_service.dart`
  - 视频：使用 fvp 截取第 1 秒帧，保存为 JPEG
  - 图片：直接复制/缩放原图
  - 使用 `compute()` 在 Isolate 中执行，不阻塞 UI
  - LRU 缓存：最多缓存 200 张，超出删除最旧的
  - 缓存目录：`getApplicationCacheDirectory()/thumbnails/`

#### 5.2 完善历史数据层
- 完善 `lib/data/database/daos/history_dao.dart`（实现所有方法）
- 创建 `lib/data/models/play_history.dart`
- 创建 `lib/data/repositories/history_repository.dart`

#### 5.3 历史记录状态管理
- 完善 `lib/presentation/providers/history_provider.dart`
  - 使用 `watchHistory()` Stream 实时更新
  - 支持删除单条和清空全部

#### 5.4 UI 组件
- 实现 `lib/presentation/pages/history/widgets/thumbnail_widget.dart`
  - 有缩略图：CachedNetworkImage（本地路径）
  - 无缩略图：根据类型显示占位图标
  - 文件已删除：灰色遮罩 + 删除线
- 实现 `lib/presentation/pages/history/widgets/history_list_item.dart`
- 实现 `lib/presentation/pages/history/history_page.dart`
  - 支持下拉刷新
  - 右上角清空按钮（带确认对话框）

#### 5.5 续播用例
- 创建 `lib/domain/usecases/resume_playback_usecase.dart`
  ```dart
  Future<void> execute(PlayHistory history) async {
    final settings = ref.read(settingsProvider);
    final resumeFrom = settings.rememberPlaybackPosition
        ? history.lastPosition
        : null;
    await openMediaUseCase.execute(history.path, resumeFrom: resumeFrom);
  }
  ```

### 验收标准
- [ ] 历史记录按最后打开时间倒序排列
- [ ] 视频显示缩略图（首帧）和进度条
- [ ] 图片显示缩略图（无进度条）
- [ ] 点击历史记录可续播（根据设置决定是否从上次位置开始）
- [ ] 文件已删除时灰显并提示
- [ ] 可删除单条记录和清空全部

---

## Phase 6 — 功能选择 Tab + 设置页

**目标**：完善 Tab 1 和 Tab 4，所有设置项可交互并持久化。

### 任务清单

#### 6.1 完善 HomePage
- 实现 `lib/presentation/pages/home/widgets/feature_card.dart`
- 实现 `lib/presentation/pages/home/home_page.dart`
  - 视频卡片：`FilePicker.pickFiles(type: FileType.video)` → 跳转播放页
  - 图片卡片：`FilePicker.pickFiles(type: FileType.image)` → 跳转查看页

#### 6.2 完善 SettingsPage
- 实现所有设置项的交互（ThemeMode, UIStyle, rememberPosition, historyMaxItems, showHiddenFiles, defaultOpenPath）
- 每次修改立即调用 `settingsNotifier.update(newSettings)`
- 实现"关于"入口（版本号、开源许可）

#### 6.3 设置持久化验证
- 确认 App 重启后设置保持不变
- 确认主题切换无需重启

### 验收标准
- [ ] 从 Tab 1 点击功能卡片可通过系统文件选择器打开文件
- [ ] 所有设置项可交互
- [ ] 设置在 App 重启后保持
- [ ] 主题切换实时生效

---

## Phase 7 — 跨平台适配 & 测试

**目标**：两个平台体验一致，无明显 Bug，可正式发布。

### 任务清单

#### 7.1 Android 专项
- 测试 API 29 / 30 / 33 / 34 权限流程
- 处理 Back 键：视频全屏时按 Back 退出全屏（而非退出 App）
- 测试横竖屏切换（视频播放页锁定横屏）
- 测试 Android 分区存储路径访问

#### 7.2 Windows 专项
- 测试窗口缩放：最小宽度 800px，响应式布局
- 验证键盘快捷键（Space/方向键/F/Esc）
- 测试 Fluent UI 主题在不同 Windows 主题下的表现
- 测试 MSIX 打包和安装

#### 7.3 性能测试
- 大目录（1000+ 文件）浏览：列表滚动流畅，加载 < 3 秒
- 缩略图生成：不阻塞 UI，懒加载正常
- 长时间播放（2 小时）：无内存泄漏
- 冷启动时间 < 2 秒

#### 7.4 边界情况处理
- 文件路径包含中文/特殊字符
- 文件在播放过程中被删除
- 存储空间不足时缩略图缓存处理
- 网络驱动器/外接存储设备（Windows）

#### 7.5 打包发布
- Android：`flutter build apk --release` / `flutter build appbundle`
- Windows：`flutter build windows --release` + MSIX 打包

### 验收标准
- [ ] Android API 29-34 权限流程全部正常
- [ ] Windows 窗口缩放无布局错乱
- [ ] 1000 文件目录浏览流畅
- [ ] 2 小时播放无内存泄漏
- [ ] 中文路径文件正常播放
- [ ] APK 和 Windows 安装包可正常安装运行