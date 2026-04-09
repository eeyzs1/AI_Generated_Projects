import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'en_us.dart';
import 'zh_cn.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  Map<String, String> get localizedStrings {
    if (locale.languageCode == 'zh') {
      return zhCN;
    } else {
      return enUS;
    }
  }

  // App 通用
  String get appName => localizedStrings['appName']!;
  String get home => localizedStrings['home']!;
  String get files => localizedStrings['files']!;
  String get recentPlays => localizedStrings['recentPlays']!;
  String get bookmarks => localizedStrings['bookmarks']!;
  String get noRecentPlays => localizedStrings['noRecentPlays']!;
  String get noBookmarks => localizedStrings['noBookmarks']!;
  String get loadingFailed => localizedStrings['loadingFailed']!;

  // 设置页面
  String get settings => localizedStrings['settings']!;
  String get appearance => localizedStrings['appearance']!;
  String get uiStyle => localizedStrings['uiStyle']!;
  String get themeMode => localizedStrings['themeMode']!;
  String get language => localizedStrings['language']!;
  String get playback => localizedStrings['playback']!;
  String get rememberPlaybackPosition => localizedStrings['rememberPlaybackPosition']!;
  String get about => localizedStrings['about']!;
  String get version => localizedStrings['version']!;
  String get freeMediaPlayer => localizedStrings['freeMediaPlayer']!;

  // UI 风格选项
  String get material3 => localizedStrings['material3']!;
  String get fluent => localizedStrings['fluent']!;
  String get adaptive => localizedStrings['adaptive']!;

  // 主题模式选项
  String get system => localizedStrings['system']!;
  String get light => localizedStrings['light']!;
  String get dark => localizedStrings['dark']!;

  // 语言选项
  String get systemLanguage => localizedStrings['systemLanguage']!;
  String get chinese => localizedStrings['chinese']!;
  String get english => localizedStrings['english']!;

  // 确认对话框
  String get confirm => localizedStrings['confirm']!;
  String get cancel => localizedStrings['cancel']!;
  String get confirmDelete => localizedStrings['confirmDelete']!;
  String get sureToDelete => localizedStrings['sureToDelete']!;
  String get success => localizedStrings['success']!;
  String get bookmarkAdded => localizedStrings['bookmarkAdded']!;
  String get ok => localizedStrings['ok']!;

  // 视频播放器
  String get videoPlayer => localizedStrings['videoPlayer']!;
  String get playbackSpeed => localizedStrings['playbackSpeed']!;
  String get volume => localizedStrings['volume']!;
  String get fullscreen => localizedStrings['fullscreen']!;
  String get selectSubtitleFile => localizedStrings['selectSubtitleFile']!;
  String get subtitleAdded => localizedStrings['subtitleAdded']!;
  String get addSubtitleFailed => localizedStrings['addSubtitleFailed']!;
  String get subtitleSettings => localizedStrings['subtitleSettings']!;
  String get selectSubtitle => localizedStrings['selectSubtitle']!;
  String get externalSubtitle => localizedStrings['externalSubtitle']!;
  String get embeddedSubtitle => localizedStrings['embeddedSubtitle']!;
  String get turnOnSubtitle => localizedStrings['turnOnSubtitle']!;
  String get turnOffSubtitle => localizedStrings['turnOffSubtitle']!;
  String get deleteSubtitleFile => localizedStrings['deleteSubtitleFile']!;
  String get deleteAllSubtitleFiles => localizedStrings['deleteAllSubtitleFiles']!;
  String get hideSubtitle => localizedStrings['hideSubtitle']!;

  // 图片查看器
  String get imageViewer => localizedStrings['imageViewer']!;
  String get imageInfo => localizedStrings['imageInfo']!;
  String get dimensions => localizedStrings['dimensions']!;
  String get size => localizedStrings['size']!;
  String get modifiedTime => localizedStrings['modifiedTime']!;

  // 文件浏览器
  String get fileBrowser => localizedStrings['fileBrowser']!;
  String get addBookmark => localizedStrings['addBookmark']!;
  String get showHiddenFiles => localizedStrings['showHiddenFiles']!;
  String get defaultDirectory => localizedStrings['defaultDirectory']!;
  String get auto => localizedStrings['auto']!;

  // 历史记录
  String get history => localizedStrings['history']!;
  String get clearAll => localizedStrings['clearAll']!;
  String get sureToClearAll => localizedStrings['sureToClearAll']!;

  // 功能选择
  String get playVideo => localizedStrings['playVideo']!;
  String get viewImage => localizedStrings['viewImage']!;
  
  // 播放列表
  String get playList => localizedStrings['playList']!;
  String get playListEmpty => localizedStrings['playListEmpty']!;
  String get previous => localizedStrings['previous']!;
  String get next => localizedStrings['next']!;
  String get clear => localizedStrings['clear']!;
  
  // 文件浏览器
  String get openFile => localizedStrings['openFile']!;
  String get noRecentFiles => localizedStrings['noRecentFiles']!;
  
  // 历史记录对话框
  String get clearHistory => localizedStrings['clearHistory']!;
  String get sureToClearHistory => localizedStrings['sureToClearHistory']!;
  String get historyCleared => localizedStrings['historyCleared']!;
  String get deleted => localizedStrings['deleted']!;
  
  // 功能卡片描述
  String get playVideoDesc => localizedStrings['playVideoDesc']!;
  String get viewImageDesc => localizedStrings['viewImageDesc']!;
  
  // 书签页面
  String get imageBookmarks => localizedStrings['imageBookmarks']!;
  String get videoBookmarks => localizedStrings['videoBookmarks']!;
  String get bookmarksCount => localizedStrings['bookmarksCount']!;
  String get clearAllBookmarks => localizedStrings['clearAllBookmarks']!;
  String get sureToClearAllBookmarks => localizedStrings['sureToClearAllBookmarks']!;
  String get allBookmarksCleared => localizedStrings['allBookmarksCleared']!;
  String get bookmarkDeleted => localizedStrings['bookmarkDeleted']!;
  
  // 图片查看器
  String get flipHorizontal => localizedStrings['flipHorizontal']!;
  String get flipVertical => localizedStrings['flipVertical']!;
  String get fileName => localizedStrings['fileName']!;
  String get filePath => localizedStrings['filePath']!;
  String get pixels => localizedStrings['pixels']!;
  String get format => localizedStrings['format']!;
  String get fileSize => localizedStrings['fileSize']!;
  String get removeBookmark => localizedStrings['removeBookmark']!;
  String get bookmarkRemoved => localizedStrings['bookmarkRemoved']!;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) {
    return false;
  }
}