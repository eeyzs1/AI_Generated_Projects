# RFPlayer — UI 设计文档

## 导航结构

RFPlayer 使用 Bottom Navigation Bar（Android）/ NavigationView（Windows）作为主导航，
包含 4 个固定 Tab，视频播放页和图片查看页作为独立全屏路由叠加在 Shell 之上。

```
MainShell (ShellRoute)
├── Tab 1: HomePage        /home
├── Tab 2: HistoryPage     /history
├── Tab 3: FileBrowserPage /files
└── Tab 4: SettingsPage    /settings

独立全屏路由（不在 Shell 内）：
├── VideoPlayerPage        /video-player?path=...
└── ImageViewerPage        /image-viewer?path=...&dir=...
```

---

## Tab 1 — 功能选择页（HomePage）

**职责**：提供快速入口，用户可直接选择功能类型打开文件。

### Widget 树

```
HomePage (ConsumerWidget)
└── Scaffold / ScaffoldPage (adaptive)
    └── CustomScrollView
        ├── SliverAppBar
        │   └── Text("RFPlayer")
        └── SliverPadding
            └── SliverGrid (2列)
                ├── FeatureCard
                │   ├── Icon(video_library)
                │   ├── Text("播放视频")
                │   └── onTap → FilePicker.pickFiles(type: video)
                │             → router.push('/video-player', extra: path)
                └── FeatureCard
                    ├── Icon(photo_library)
                    ├── Text("查看图片")
                    └── onTap → FilePicker.pickFiles(type: image)
                              → router.push('/image-viewer', extra: path)
```

### FeatureCard 设计

```
FeatureCard
├── Card (Material 3 ElevatedCard / Fluent Card)
│   └── InkWell (onTap)
│       └── Column
│           ├── Icon (48px, primary color)
│           ├── SizedBox(height: 12)
│           ├── Text(label, style: titleMedium)
│           └── Text(description, style: bodySmall, color: secondary)
```

**扩展性**：未来新增功能（格式转换等）只需向 Grid 添加新的 FeatureCard，无需修改页面结构。

### Provider 依赖

```dart
// 仅需 settingsProvider 获取 UIStyle 决定卡片风格
final settings = ref.watch(settingsProvider);
```

---

## Tab 2 — 播放历史页（HistoryPage）

**职责**：展示最近打开的媒体文件，支持续播和删除。

### Widget 树

```
HistoryPage (ConsumerWidget)
└── Scaffold
    ├── AppBar
    │   ├── Text("最近播放")
    │   └── IconButton(delete_sweep) → 清空全部确认对话框
    └── body: AsyncValue<List<PlayHistory>> switch
        ├── loading → LoadingIndicator
        ├── error   → ErrorView
        └── data    → CustomScrollView
            ├── SliverAppBar (搜索栏，可折叠)
            └── SliverList
                └── HistoryListItem(history) × N
```

### HistoryListItem 设计

```
HistoryListItem
└── ListTile (height: 80)
    ├── leading: ThumbnailWidget(72×72)
    │   ├── 有缩略图 → CachedImage(thumbnailPath)
    │   └── 无缩略图 → Icon(video_file / image) + 灰色背景
    ├── title: Text(history.displayName, maxLines: 1, overflow: ellipsis)
    ├── subtitle: Column
    │   ├── Text(formatDateTime(history.lastPlayedAt), style: caption)
    │   └── LinearProgressIndicator(value: history.progress)
    │       // 仅视频显示进度条
    ├── trailing: Column
    │   ├── Text(history.progressString)  // "12:34 / 1:23:45"
    │   └── IconButton(more_vert) → 底部菜单（删除/分享）
    └── onTap → ResumePlaybackUseCase(history)
              → router.push('/video-player' or '/image-viewer')
```

### 状态管理

```dart
// historyProvider
@riverpod
class HistoryNotifier extends _$HistoryNotifier {
  @override
  Future<List<PlayHistory>> build() => ref.read(historyRepositoryProvider).getHistory();

  Future<void> delete(String id) async { ... }
  Future<void> clearAll() async { ... }
}
```

---

## Tab 3 — 文件浏览器页（FileBrowserPage）

**职责**：浏览文件系统，支持书签快速跳转，点击媒体文件直接打开。

### Widget 树

```
FileBrowserPage (ConsumerWidget)
└── Scaffold
    ├── AppBar
    │   ├── BreadcrumbBar (当前路径面包屑)
    │   └── IconButton(bookmark_add) → 添加当前目录为书签
    └── body: Column
        ├── BookmarkPanel (高度 56，横向滚动)
        │   └── ListView.horizontal
        │       └── BookmarkChip(bookmark) × N
        │           ├── Icon(folder_special)
        │           ├── Text(bookmark.displayName)
        │           ├── onTap → fileBrowserNotifier.navigateTo(bookmark.path)
        │           └── onLongPress → 删除确认
        └── Expanded
            └── AsyncValue<FileBrowserState> switch
                ├── loading → LoadingIndicator
                ├── error   → ErrorView
                └── data    → ListView
                    └── FileListItem(entry) × N
```

### FileListItem 设计

```
FileListItem
└── ListTile
    ├── leading: Icon
    │   ├── 目录    → folder (amber)
    │   ├── 视频    → video_file (blue)
    │   ├── 图片    → image (green)
    │   └── 其他    → insert_drive_file (grey)
    ├── title: Text(entry.name)
    ├── subtitle: Text(fileSize + modifiedDate)  // 仅文件显示
    └── onTap:
        ├── 目录 → fileBrowserNotifier.navigateTo(entry.path)
        ├── 视频 → OpenMediaUseCase → router.push('/video-player')
        └── 图片 → OpenMediaUseCase → router.push('/image-viewer')
```

### BreadcrumbBar 设计

```
BreadcrumbBar
└── SingleChildScrollView (horizontal)
    └── Row
        └── [path.split('/').map((segment, index) =>
              Row(
                BreadcrumbSegment(segment, onTap: navigateTo(path[:index]))
                Icon(chevron_right)  // 最后一段不显示
              )
            )]
```

### FileBrowserState

```dart
class FileBrowserState {
  final String currentPath;
  final List<FileSystemEntity> entries;  // 目录在前，文件在后，各自按名称排序
  final bool isLoading;
  final String? error;
}
```

---

## Tab 4 — 设置页（SettingsPage）

**职责**：管理应用设置，所有修改实时生效并持久化。

### Widget 树

```
SettingsPage (ConsumerWidget)
└── Scaffold / ScaffoldPage
    ├── AppBar: Text("设置")
    └── ListView
        ├── SettingsSection("外观")
        │   ├── ThemeSelector
        │   │   └── SegmentedButton (system / light / dark)
        │   ├── UIStyleSelector
        │   │   └── SegmentedButton (Material 3 / Fluent / 自适应)
        │   └── LanguageSelector
        │       └── SegmentedButton (跟随系统 / 简体中文 / English)
        ├── SettingsSection("播放")
        │   ├── SwitchListTile("记住播放位置", rememberPlaybackPosition)
        │   └── ListTile("历史记录数量", trailing: Text("${historyMaxItems}条"))
        │       → onTap: 数字选择对话框
        └── SettingsSection("文件")
            ├── SwitchListTile("显示隐藏文件", showHiddenFiles)
            └── ListTile("默认目录", trailing: Text(defaultOpenPath ?? "自动"))
                → onTap: FilePicker.getDirectoryPath()
```

---

## 视频播放页（VideoPlayerPage）

**职责**：全屏视频播放，支持手势控制，自动保存播放进度。

### Widget 树

```
VideoPlayerPage (ConsumerWidget)
└── Scaffold(backgroundColor: black)
    └── Stack
        ├── Video(controller: videoController)  ← fvp_video，填满屏幕
        └── PlayerOverlay
            └── GestureDetector
                ├── onTap → toggleControlsVisibility()
                ├── onHorizontalDragUpdate → seekPreview()
                ├── onVerticalDragUpdate (左半屏) → adjustBrightness()
                └── onVerticalDragUpdate (右半屏) → adjustVolume()
                └── AnimatedOpacity(opacity: controlsVisible ? 1.0 : 0.0)
                    └── Column
                        ├── TopBar
                        │   ├── BackButton → router.pop() + savePosition()
                        │   └── Text(currentFileName)
                        ├── Spacer
                        └── BottomControls
                            ├── ProgressBar
                            │   ├── Slider(value: position/duration)
                            │   ├── Text(currentPosition)
                            │   └── Text(totalDuration)
                            └── ControlRow
                                ├── IconButton(skip_previous)
                                ├── IconButton(play_arrow / pause)
                                ├── IconButton(skip_next)
                                ├── VolumeButton
                                ├── SpeedControl
                                │   ├── DropdownButton(固定档位)
                                │   ├── Slider(0.25-4.0, 0.01精度)
                                │   └── TextField(1.00x)
                                └── AppBarVisibilityButton
```

### PlayerState

```dart
class PlayerState {
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double volume;          // 0.0 ~ 1.0
  final double playbackSpeed;   // 0.25 ~ 4.0
  final bool isAppBarVisible;
  final String? currentPath;
  final String? errorMessage;
}
```

### 自动保存进度

```dart
// 每 5 秒自动保存一次播放位置
// 退出页面时立即保存
@override
void dispose() {
  _savePositionTimer?.cancel();
  _saveCurrentPosition();
  super.dispose();
}
```

---

## 图片查看页（ImageViewerPage）

**职责**：全屏图片查看，支持缩放、滑动切换同目录图片。

### Widget 树

```
ImageViewerPage (ConsumerWidget)
└── Scaffold(backgroundColor: black)
    └── Stack
        ├── PageView.builder (同目录图片列表)
        │   └── ExtendedImage.file(
        │         path,
        │         mode: ExtendedImageGesturePageViewMode,
        │         initGestureConfigHandler: (state) => GestureConfig(
        │           minScale: 0.9,
        │           maxScale: 3.0,
        │           initialScale: 1.0,
        │           inPageView: true,
        │         )
        │       )
        └── AnimatedOpacity (UI 层，点击切换显隐)
            ├── TopBar
            │   ├── BackButton
            │   ├── Text("${currentIndex + 1} / ${totalCount}")
            │   └── IconButton(info) → ImageInfoOverlay
            └── BottomBar
                └── Text(currentFileName)
```

### ImageInfoOverlay

```
ImageInfoOverlay (底部弹出面板)
└── Column
    ├── Text(fileName)
    ├── Text("尺寸: ${width} × ${height}")
    ├── Text("大小: ${formatFileSize(fileSize)}")
    └── Text("修改时间: ${formatDateTime(modifiedAt)}")
```

---

## 主题切换机制

```dart
// lib/app.dart
class RFPlayerApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final effectiveStyle = _resolveStyle(settings.uiStyle);

    if (effectiveStyle == UIStyle.fluent) {
      return fluent.FluentApp.router(
        routerConfig: appRouter,
        theme: ref.watch(fluentLightThemeProvider),
        darkTheme: ref.watch(fluentDarkThemeProvider),
      );
    }

    return MaterialApp.router(
      routerConfig: appRouter,
      theme: ref.watch(materialLightThemeProvider),
      darkTheme: ref.watch(materialDarkThemeProvider),
      themeMode: settings.themeMode.toMaterialThemeMode(),
    );
  }

  UIStyle _resolveStyle(UIStyle style) {
    if (style != UIStyle.adaptive) return style;
    return Platform.isWindows ? UIStyle.fluent : UIStyle.material3;
  }
}
```

**切换无需重启**：`settingsProvider` 变化 → `app.dart` Consumer 重建 → 整个 Widget 树使用新主题。