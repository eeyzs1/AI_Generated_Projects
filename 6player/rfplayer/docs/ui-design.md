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

***

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

***

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

***

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

***

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

***

## 视频播放页（VideoPlayerPage）

**职责**：全屏视频播放，支持手势控制，自动保存播放进度，集成播放队列功能。

### Widget 树

**Windows 端**：

```
VideoPlayerPage (ConsumerWidget)
└── Scaffold(backgroundColor: black)
    └── Row
        ├── Expanded
        │   └── Stack
        │       ├── Video(controller: videoController)  ← fvp_video，填满屏幕
        │       └── PlayerOverlay
        │           └── GestureDetector
        │               ├── onTap → toggleControlsVisibility()
        │               ├── onHorizontalDragUpdate → seekPreview()
        │               ├── onVerticalDragUpdate (左半屏) → adjustBrightness()
        │               └── onVerticalDragUpdate (右半屏) → adjustVolume()
        │               └── AnimatedOpacity(opacity: controlsVisible ? 1.0 : 0.0)
        │                   └── Column
        │                       ├── TopBar
        │                       │   ├── BackButton → router.pop() + savePosition()
        │                       │   └── Text(currentFileName)
        │                       ├── Spacer
        │                       └── BottomControls
        │                           ├── ProgressBar
        │                           │   ├── Slider(value: position/duration)
        │                           │   ├── Text(currentPosition)
        │                           │   └── Text(totalDuration)
        │                           └── ControlRow
        │                               ├── IconButton(skip_previous)
        │                               ├── IconButton(play_arrow / pause)
        │                               ├── IconButton(skip_next)
        │                               ├── VolumeButton
        │                               ├── SpeedControl
        │                               │   ├── DropdownButton(固定档位)
        │                               │   ├── Slider(0.25-4.0, 0.01精度)
        │                               │   └── TextField(1.00x)
        │                               ├── SubtitleButton
        │                               │   └── SubtitleControls
        │                               │       ├── 加载外部字幕文件
        │                               │       ├── 字幕选择下拉菜单
        │                               │       ├── 显示/隐藏控制
        │                               └── AppBarVisibilityButton
        └── WindowsPlayListPanel (宽度 300px)
            ├── PanelHeader
            │   ├── Text("播放列表")
            │   └── IconButton(clear) → 清空队列
            ├── Expanded
            │   └── ReorderableListView.builder
            │       └── PlayListItem × N
            │           ├── Icon(item.isCurrentPlaying ? play_arrow : item.hasPlayed ? check : queue_music)
            │           ├── Text(item.displayName, maxLines: 1, style: TextStyle(
            │           │   fontWeight: item.isCurrentPlaying ? FontWeight.bold : FontWeight.normal,
            │           │   color: item.hasPlayed ? Colors.grey : Colors.black,
            │           │   backgroundColor: item.isCurrentPlaying ? Colors.blue[100] : null,
            │           ))
            │           ├── IconButton(delete) → 移除项
            │           └── onTap → 播放该项
            └── ControlButtons
                ├── ElevatedButton(上一个)
                ├── ElevatedButton(下一个)
                └── ElevatedButton(清空)
```

**Android 端**：

```
VideoPlayerPage (ConsumerWidget)
└── Scaffold(backgroundColor: black)
    ├── AppBar (可隐藏)
    │   ├── BackButton
    │   ├── Text(currentFileName)
    │   └── IconButton(playlist_play) → 切换播放列表抽屉
    └── Stack
        ├── Video(controller: videoController)  ← fvp_video，填满屏幕
        ├── PlayerOverlay
        │   └── GestureDetector
        │       ├── onTap → toggleControlsVisibility()
        │       ├── onHorizontalDragUpdate → seekPreview()
        │       ├── onVerticalDragUpdate (左半屏) → adjustBrightness()
        │       └── onVerticalDragUpdate (右半屏) → adjustVolume()
        │       └── AnimatedOpacity(opacity: controlsVisible ? 1.0 : 0.0)
        │           └── Column
        │               ├── Spacer
        │               └── BottomControls
        │                   ├── ProgressBar
        │                   │   ├── Slider(value: position/duration)
        │                   │   ├── Text(currentPosition)
        │                   │   └── Text(totalDuration)
        │                   └── ControlRow
        │                       ├── IconButton(skip_previous)
        │                       ├── IconButton(play_arrow / pause)
        │                       ├── IconButton(skip_next)
        │                       ├── VolumeButton
        │                       ├── SpeedControl
        │                       └── SubtitleButton
        │                           └── SubtitleControls
        │                               ├── 加载外部字幕文件
        │                               ├── 字幕选择下拉菜单
        │                               ├── 显示/隐藏控制
        └── Positioned(bottom: 0)
            └── AndroidPlayListDrawer (高度 60%)
                ├── DrawerHeader
                │   ├── Text("播放列表")
                │   └── IconButton(close) → 关闭抽屉
                ├── Expanded
                │   └── ListView.builder
                │       └── PlayListItem × N
                │           ├── Icon(item.isCurrentPlaying ? play_arrow : item.hasPlayed ? check : queue_music)
                │           ├── Text(item.displayName, maxLines: 1, style: TextStyle(
                │           │   fontWeight: item.isCurrentPlaying ? FontWeight.bold : FontWeight.normal,
                │           │   color: item.hasPlayed ? Colors.grey : Colors.black,
                │           │   backgroundColor: item.isCurrentPlaying ? Colors.blue[100] : null,
                │           ))
                │           ├── IconButton(delete) → 移除项
                │           └── onTap → 播放该项
                └── ControlButtons
                    ├── ElevatedButton(上一个)
                    ├── ElevatedButton(下一个)
                    └── ElevatedButton(清空)
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

***

## 图片查看页（ImageViewerPage）

**职责**：全屏图片查看，支持缩放、滑动切换同目录图片，提供丰富的图片操作功能。

### 功能特性

1. **手势操作**
   - 双击缩放：双击图片在 1x 和 3x 之间切换
   - 捏合缩放：支持 0.5x - 5x 自由缩放
   - 拖拽平移：缩放后可拖拽查看图片细节
   - 滑动切换：左右滑动切换同目录图片
2. **UI 控制**
   - 点击切换 UI 显隐：点击非按钮区域显示/隐藏工具栏
   - 工具栏 3 秒无操作自动隐藏
   - 显示当前图片索引和总数
3. **图片操作**
   - 顺时针旋转 90°
   - 逆时针旋转 90°
   - 水平翻转
   - 垂直翻转
   - 重置所有变换
4. **文件操作**
   - 添加书签
   - 查看图片信息（尺寸、大小、修改时间）
   - 删除图片（带确认对话框）
   - 分享图片
5. **浏览模式**
   - 支持同目录图片自动加载
   - 循环浏览（到最后一张后回到第一张）
   - 图片预加载（前后各预加载 2 张）

### Widget 树

```
ImageViewerPage (ConsumerStatefulWidget)
└── Scaffold(backgroundColor: black)
    └── Stack
        ├── PageView.builder (同目录图片列表)
        │   └── ExtendedImage.file(
        │         path,
        │         mode: ExtendedImageMode.gesture,
        │         initGestureConfigHandler: (state) => GestureConfig(
        │           minScale: 0.5,
        │           maxScale: 5.0,
        │           initialScale: 1.0,
        │           inPageView: true,
        │         ),
        │         onDoubleTap: (state) => handleDoubleTap(state),
        │       )
        ├── AnimatedOpacity (TopBar，点击切换显隐)
        │   └── AppBar(
        │         backgroundColor: Colors.black.withOpacity(0.7),
        │         leading: BackButton(onPressed: () => Navigator.pop()),
        │         title: Text("${currentIndex + 1} / ${totalCount} - ${currentFileName}"),
        │         actions: [
        │           IconButton(rotate_left, onPressed: rotateLeft),
        │           IconButton(rotate_right, onPressed: rotateRight),
        │           IconButton(flip, onPressed: showFlipMenu),
        │           IconButton(info, onPressed: showImageInfo),
        │           IconButton(more_vert, onPressed: showMoreMenu),
        │         ],
        │       )
        ├── AnimatedOpacity (BottomBar，点击切换显隐)
        │   └── Container(
        │         color: Colors.black.withOpacity(0.7),
        │         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        │         child: Row(
        │           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        │           children: [
        │             IconButton(Icons.rotate_left, onPressed: rotateLeft),
        │             IconButton(Icons.rotate_right, onPressed: rotateRight),
        │             IconButton(Icons.flip, onPressed: showFlipMenu),
        │             IconButton(Icons.zoom_in, onPressed: zoomIn),
        │             IconButton(Icons.zoom_out, onPressed: zoomOut),
        │             IconButton(Icons.fit_screen, onPressed: resetTransform),
        │           ],
        │         ),
        │       )
        ├── Positioned (左侧切换按钮)
        │   └── IconButton(
        │         icon: Icons.chevron_left,
        │         onPressed: canGoPrevious ? goToPrevious : null,
        │       )
        ├── Positioned (右侧切换按钮)
        │   └── IconButton(
        │         icon: Icons.chevron_right,
        │         onPressed: canGoNext ? goToNext : null,
        │       )
        └── ImageInfoOverlay (底部弹出面板，显示图片详细信息)
```

### ImageViewerState

```dart
class ImageViewerState {
  final String currentPath;
  final String currentFileName;
  final int currentIndex;
  final int totalCount;
  final List<String> imagePaths;  // 同目录所有图片路径
  final bool isUIVisible;
  final double rotation;  // 旋转角度（0, 90, 180, 270）
  final bool isFlippedHorizontal;
  final bool isFlippedVertical;
  final double currentScale;
  final ImageInfo? imageInfo;  // 图片详细信息
}

class ImageInfo {
  final String fileName;
  final String filePath;
  final int width;
  final int height;
  final int fileSize;
  final DateTime modifiedAt;
  final String format;  // 图片格式（JPEG, PNG, etc.）
}
```

### 手势操作说明

| 手势   | 操作              |
| ---- | --------------- |
| 单击   | 显示/隐藏 UI 工具栏    |
| 双击   | 缩放切换（1x ↔ 3x）   |
| 捏合   | 自由缩放（0.5x - 5x） |
| 拖拽   | 平移查看（缩放后）       |
| 左右滑动 | 切换图片            |

### 底部操作栏按钮

| 图标            | 功能    | 说明        |
| ------------- | ----- | --------- |
| rotate\_left  | 逆时针旋转 | 每次旋转 90°  |
| rotate\_right | 顺时针旋转 | 每次旋转 90°  |
| flip          | 翻转菜单  | 水平/垂直翻转   |
| zoom\_in      | 放大    | 每次放大 0.5x |
| zoom\_out     | 缩小    | 每次缩小 0.5x |
| fit\_screen   | 重置    | 重置所有变换    |

### 更多菜单（more\_vert）

- 添加书签
- 查看详细信息
- 删除图片
- 分享图片
- 设置为壁纸（Android）

### ImageInfoOverlay

```
ImageInfoOverlay (底部弹出面板)
└── Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("文件名: ${fileName}"),
        Text("路径: ${filePath}"),
        Text("尺寸: ${width} × ${height} 像素"),
        Text("大小: ${formatFileSize(fileSize)}"),
        Text("格式: ${format}"),
        Text("修改时间: ${formatDateTime(modifiedAt)}"),
      ],
    )
```

***

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

***

## 无障碍设计

- **屏幕阅读器支持**：为所有 UI 元素添加语义标签
- **键盘导航**：确保所有功能可通过键盘访问
- **颜色对比度**：符合 WCAG 2.1 AA 级标准
- **字体大小**：支持系统字体大小设置
- **高对比度模式**：适配系统高对比度设置

## 响应式设计

- **断点设计**：
  - 小屏幕（< 600px）：单列布局，简化控制界面
  - 中屏幕（600px - 1024px）：双列布局，适当显示更多信息
  - 大屏幕（> 1024px）：多列布局，完整功能展示
- **窗口缩放**：Windows 端支持窗口大小调整，最小宽度 800px
- **设备旋转**：Android 端支持横竖屏切换，视频播放页锁定横屏

## 动画效果

- **页面切换**：平滑的淡入淡出过渡
- **控制栏**：3 秒无操作自动隐藏，点击屏幕显示
- **播放状态**：播放/暂停按钮的平滑过渡动画
- **进度条**：播放进度的平滑更新动画
- **列表滚动**：流畅的滚动效果，支持快速滚动
- **抽屉/面板**：平滑的滑入滑出动画

## 深色模式规范

- **背景色**：使用深灰色而非纯黑色，减少视觉疲劳
- **文本色**：使用浅灰色而非纯白色，提高可读性
- **强调色**：保持与浅色模式一致的品牌色彩
- **图标**：使用适合深色背景的图标样式
- **对比度**：确保文本与背景的对比度符合无障碍标准
- **系统集成**：跟随系统深色模式设置，支持手动切换

