import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:flutter/foundation.dart';
import '../../../data/models/play_history.dart' as ph;
import '../../../data/models/subtitle_track.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

class MyVideoPlayerController {
  late final VideoPlayerController videoController;
  final String path;
  final String? fileName;
  final dynamic _historyRepo;
  final dynamic _playQueueService;
  final dynamic _playQueueNotifier;
  final dynamic _thumbnailService;
  final void Function() _onStateChanged;
  Timer? _positionTimer;
  VoidCallback? _videoControllerListener;
  bool _disposed = false;

  final List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack? _activeSubtitleTrack;
  SubtitleTrack? _lastSelectedSubtitleTrack;
  bool _subtitleEnabled = true;
  bool _hasActiveExternalSubtitle = false;
  int _nextExternalSubtitleId = 1000;

  MyVideoPlayerController(
    this.path, {
    this.fileName,
    required dynamic historyRepo,
    required dynamic playQueueService,
    required dynamic playQueueNotifier,
    required dynamic thumbnailService,
    required void Function() onStateChanged,
  }) : _historyRepo = historyRepo,
       _playQueueService = playQueueService,
       _playQueueNotifier = playQueueNotifier,
       _thumbnailService = thumbnailService,
       _onStateChanged = onStateChanged {
    videoController = VideoPlayerController.file(File(path));
  }

  void _notifySubtitleStateChanged() {
    if (!_disposed) {
      _onStateChanged();
    }
  }

  Future<void> initialize() async {
    if (_disposed) return;

    try {
      await videoController.initialize();

      if (_disposed) return;

      try {
        videoController.setProperty('subtitle', '1');
        videoController.setProperty('cc', '1');
      } catch (e) {
        debugPrint('[MyVideoPlayerController] Error setting subtitle properties: $e');
      }
    } catch (e) {
      debugPrint('[MyVideoPlayerController] Error initializing videoController: $e');
      rethrow;
    }

    if (_disposed) return;

    var history = await _historyRepo.getByPath(path);

    if (_disposed) return;

    if (history == null) {
      final currentDisplayName = p.basename(path);
      final allHistory = await _historyRepo.getHistory(limit: 1000, offset: 0);
      if (_disposed) return;
      for (final h in allHistory) {
        if (h.displayName == currentDisplayName) {
          history = h;
          break;
        }
      }
    }

    if (_disposed) return;

    final duration = videoController.value.duration;

    if (history == null) {
      String extension;
      if (fileName != null) {
        final ext = p.extension(fileName!).toLowerCase();
        extension = ext.length > 1 ? ext.substring(1) : ext;
      } else {
        final ext = p.extension(path).toLowerCase();
        extension = ext.length > 1 ? ext.substring(1) : ext;
      }
      history = ph.PlayHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: path,
        displayName: fileName ?? p.basename(path),
        extension: extension,
        type: ph.MediaType.video,
        lastPosition: Duration.zero,
        totalDuration: duration != Duration.zero ? duration : null,
        lastPlayedAt: DateTime.now(),
        playCount: 1,
      );
      await _historyRepo.upsert(history);
      if (!_disposed) _generateThumbnailAsync();
    } else {
      final updatedHistory = ph.PlayHistory(
        id: history.id,
        path: history.path,
        displayName: history.displayName,
        extension: history.extension,
        type: history.type,
        lastPosition: history.lastPosition,
        totalDuration: duration != Duration.zero ? duration : history.totalDuration,
        lastPlayedAt: DateTime.now(),
        playCount: history.playCount + 1,
        thumbnailPath: history.thumbnailPath,
      );
      await _historyRepo.upsert(updatedHistory);

      if (history.thumbnailPath == null && !_disposed) {
        _generateThumbnailAsync();
      }

      if (!_disposed && updatedHistory.lastPosition != null && updatedHistory.lastPosition!.inMilliseconds > 0) {
        await videoController.seekTo(updatedHistory.lastPosition!);
      }
    }

    if (_disposed) return;

    _videoControllerListener = () {
      if (_disposed) return;

      final currentDuration = videoController.value.duration;
      if (currentDuration != Duration.zero) {
        _updateCurrentDuration(currentDuration);
      }

      if (videoController.value.position >= videoController.value.duration &&
          videoController.value.duration != Duration.zero &&
          videoController.value.isPlaying) {
        _handleVideoComplete();
      }

      _onStateChanged();
    };
    videoController.addListener(_videoControllerListener!);

    loadEmbeddedSubtitles();

    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      updatePlaybackPosition();
    });
  }

  Future<void> _updateCurrentDuration(Duration duration) async {
    if (_disposed) return;

    try {
      var history = await _historyRepo.getByPath(path);
      if (_disposed) return;

      if (history != null) {
        final updatedHistory = ph.PlayHistory(
          id: history.id,
          path: history.path,
          displayName: history.displayName,
          extension: history.extension,
          type: history.type,
          lastPosition: history.lastPosition,
          totalDuration: duration,
          lastPlayedAt: history.lastPlayedAt,
          playCount: history.playCount,
        );

        if (!_disposed) {
          await _historyRepo.upsert(updatedHistory);
        }
      }
    } catch (e) {
      if (!_disposed) debugPrint('Error updating current duration: $e');
    }
  }

  Future<void> updatePlaybackPosition() async {
    if (_disposed) return;

    try {
      final position = videoController.value.position;
      final duration = videoController.value.duration;

      if (!_disposed) {
        try {
          await _historyRepo.updatePosition(path, position);
        } catch (e) {
          if (!_disposed) debugPrint('Error updating history position: $e');
        }
      }

      if (duration != Duration.zero && !_disposed) {
        try {
          final progress = position.inMilliseconds / duration.inMilliseconds;
          if (!_disposed) {
            final currentPlaying = await _playQueueService.getCurrentPlaying();
            if (!_disposed && currentPlaying != null && currentPlaying.path == path) {
              await _playQueueService.updatePlayProgress(currentPlaying.id, progress);
            }
          }
        } catch (e) {
          if (!_disposed) debugPrint('Error updating play queue progress: $e');
        }
      }
    } catch (e) {
      if (!_disposed) debugPrint('Error updating playback position: $e');
    }
  }

  void play() {
    if (!_disposed) {
      videoController.play();
    }
  }

  void pause() {
    if (!_disposed) {
      videoController.pause();
    }
  }

  void seek(Duration position) {
    videoController.seekTo(position);
  }

  void setVolume(double volume) {
    videoController.setVolume(volume);
  }

  double get volume => videoController.value.volume;

  void setPlaybackSpeed(double speed) {
    videoController.setPlaybackSpeed(speed);
  }

  double get playbackSpeed => videoController.value.playbackSpeed;

  Duration get duration => videoController.value.duration;
  Duration get position => videoController.value.position;
  bool get isPlaying => videoController.value.isPlaying;

  List<SubtitleTrack> get subtitleTracks => _subtitleTracks;
  SubtitleTrack? get activeSubtitleTrack => _activeSubtitleTrack;
  bool get subtitleEnabled => _subtitleEnabled;

  Future<void> loadSubtitle(String subtitlePath) async {
    if (_disposed) return;
    try {
      final id = _nextExternalSubtitleId++;
      final name = p.basename(subtitlePath);
      final track = SubtitleTrack(
        id: id,
        name: name,
        type: SubtitleTrackType.external,
        path: subtitlePath,
      );

      _subtitleTracks.add(track);
      await selectSubtitleTrack(track);
    } catch (e) {
      if (!_disposed) debugPrint('Error loading subtitle: $e');
      rethrow;
    }
  }

  Future<void> loadEmbeddedSubtitles() async {
    if (_disposed) return;
    try {
      try {
        videoController.setProperty('subtitle', '1');
        videoController.setProperty('cc', '1');
      } catch (e) {
        debugPrint('loadEmbeddedSubtitles: Error setting subtitle properties: $e');
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (_disposed) return;

      final mediaInfo = videoController.getMediaInfo();

      if (mediaInfo == null || mediaInfo.subtitle == null || mediaInfo.subtitle!.isEmpty) {
        return;
      }

      for (int i = 0; i < mediaInfo.subtitle!.length; i++) {
        final subtitleStream = mediaInfo.subtitle![i];

        String trackName;
        String? trackLanguage;

        final metadata = subtitleStream.metadata;
        if (metadata['language'] != null) {
          final langCode = metadata['language']!;
          trackLanguage = langCode;
          trackName = _getLanguageNameFromCode(langCode);
        } else if (metadata['title'] != null) {
          trackName = metadata['title']!;
        } else {
          trackName = 'Subtitle ${i + 1}';
        }

        final track = SubtitleTrack(
          id: i,
          name: trackName,
          language: trackLanguage,
          type: SubtitleTrackType.embedded,
        );

        _subtitleTracks.add(track);
      }

      _activeSubtitleTrack = _subtitleTracks.first;
      _lastSelectedSubtitleTrack = _subtitleTracks.first;
      _subtitleEnabled = true;

      videoController.setSubtitleTracks([0]);
      _notifySubtitleStateChanged();
    } catch (e) {
      if (!_disposed) debugPrint('Error loading embedded subtitles: $e');
    }
  }

  String _getLanguageNameFromCode(String langCode) {
    final langMap = {
      'zh': '中文', 'chi': '中文', 'zho': '中文', 'cn': '中文',
      'en': 'English', 'eng': 'English',
      'ja': '日本語', 'jpn': '日本語',
      'ko': '한국어', 'kor': '한국어',
      'es': 'Español', 'spa': 'Español',
      'fr': 'Français', 'fre': 'Français',
      'de': 'Deutsch', 'ger': 'Deutsch',
      'ru': 'Русский', 'rus': 'Русский',
      'ar': 'العربية', 'ara': 'العربية',
      'pt': 'Português', 'por': 'Português',
      'it': 'Italiano', 'ita': 'Italiano',
    };
    return langMap[langCode.toLowerCase()] ?? 'Subtitle';
  }

  Future<void> selectSubtitleTrack(SubtitleTrack? track) async {
    if (_disposed) return;
    if (track == null) {
      _lastSelectedSubtitleTrack = _activeSubtitleTrack;
      _subtitleEnabled = false;
      try {
        videoController.setSubtitleTracks([]);
      } catch (e) {
        debugPrint('[CONTROLLER] Error in setSubtitleTracks([]): $e');
      }
    } else {
      if (track.type == SubtitleTrackType.external) {
        try {
          videoController.setExternalSubtitle(track.path!);
          _hasActiveExternalSubtitle = true;

          await Future.delayed(const Duration(milliseconds: 300));
          if (_disposed) return;

          final embeddedCount = _subtitleTracks.where((t) => t.type == SubtitleTrackType.embedded).length;
          videoController.setSubtitleTracks([embeddedCount]);

          _activeSubtitleTrack = track;
          _lastSelectedSubtitleTrack = track;
          _subtitleEnabled = true;
        } catch (e) {
          debugPrint('[CONTROLLER] Error in setExternalSubtitle: $e');
          _activeSubtitleTrack = track;
          _lastSelectedSubtitleTrack = track;
          _subtitleEnabled = true;
        }
      } else {
        try {
          if (_hasActiveExternalSubtitle) {
            videoController.setExternalSubtitle('');
            _hasActiveExternalSubtitle = false;
          }
          videoController.setSubtitleTracks([track.id]);
          _activeSubtitleTrack = track;
          _lastSelectedSubtitleTrack = track;
          _subtitleEnabled = true;
        } catch (e) {
          debugPrint('[CONTROLLER] Error in embedded subtitle selection: $e');
          _activeSubtitleTrack = track;
          _lastSelectedSubtitleTrack = track;
          _subtitleEnabled = true;
        }
      }
    }
    _notifySubtitleStateChanged();
  }

  void removeSubtitleTrack(SubtitleTrack track) {
    if (_disposed) return;
    if (track.type == SubtitleTrackType.external) {
      _subtitleTracks.remove(track);

      if (_activeSubtitleTrack == track) {
        if (_hasActiveExternalSubtitle) {
          try {
            videoController.setExternalSubtitle('');
          } catch (e) {
            debugPrint('Error clearing external subtitle: $e');
          }
          _hasActiveExternalSubtitle = false;
        }

        final firstEmbedded = _subtitleTracks.firstWhere(
          (t) => t.type == SubtitleTrackType.embedded,
          orElse: () => _subtitleTracks.first,
        );

        _activeSubtitleTrack = firstEmbedded;
        _subtitleEnabled = true;
        videoController.setSubtitleTracks([firstEmbedded.id]);
      }
      _notifySubtitleStateChanged();
    }
  }

  void removeAllSubtitleTracks() {
    if (_disposed) return;
    final externalTracks = _subtitleTracks.where((t) => t.type == SubtitleTrackType.external).toList();

    if (externalTracks.isEmpty) return;

    final wasExternalActive = _activeSubtitleTrack?.type == SubtitleTrackType.external;

    _subtitleTracks.removeWhere((t) => t.type == SubtitleTrackType.external);

    if (_hasActiveExternalSubtitle) {
      try {
        videoController.setExternalSubtitle('');
      } catch (e) {
        debugPrint('Error clearing external subtitle: $e');
      }
      _hasActiveExternalSubtitle = false;
    }

    if (wasExternalActive) {
      final firstEmbedded = _subtitleTracks.firstWhere(
        (t) => t.type == SubtitleTrackType.embedded,
        orElse: () => _subtitleTracks.first,
      );
      _activeSubtitleTrack = firstEmbedded;
      _subtitleEnabled = true;
      videoController.setSubtitleTracks([firstEmbedded.id]);
    }

    _notifySubtitleStateChanged();
  }

  Future<void> toggleSubtitle() async {
    if (_disposed) return;
    if (!_subtitleEnabled) {
      SubtitleTrack? trackToUse;

      if (_activeSubtitleTrack != null && _subtitleTracks.contains(_activeSubtitleTrack)) {
        trackToUse = _activeSubtitleTrack;
      } else if (_lastSelectedSubtitleTrack != null && _subtitleTracks.contains(_lastSelectedSubtitleTrack)) {
        trackToUse = _lastSelectedSubtitleTrack;
      } else if (_subtitleTracks.isNotEmpty) {
        trackToUse = _subtitleTracks.first;
      }

      if (trackToUse != null) {
        try {
          if (trackToUse.type == SubtitleTrackType.external) {
            videoController.setExternalSubtitle(trackToUse.path!);
            _hasActiveExternalSubtitle = true;

            await Future.delayed(const Duration(milliseconds: 300));
            if (_disposed) return;

            final embeddedCount = _subtitleTracks.where((t) => t.type == SubtitleTrackType.embedded).length;
            videoController.setSubtitleTracks([embeddedCount]);
          } else {
            if (_hasActiveExternalSubtitle) {
              videoController.setExternalSubtitle('');
              _hasActiveExternalSubtitle = false;
            }
            videoController.setSubtitleTracks([trackToUse.id]);
          }
          _subtitleEnabled = true;
          _activeSubtitleTrack = trackToUse;
        } catch (e) {
          debugPrint('Error toggling on subtitle: $e');
          _subtitleEnabled = true;
          _activeSubtitleTrack = trackToUse;
        }
      }
    } else {
      _lastSelectedSubtitleTrack = _activeSubtitleTrack;
      _subtitleEnabled = false;

      if (_hasActiveExternalSubtitle) {
        try {
          videoController.setExternalSubtitle('');
        } catch (e) {
          debugPrint('Error clearing external subtitle: $e');
        }
        _hasActiveExternalSubtitle = false;
      }

      try {
        videoController.setSubtitleTracks([]);
      } catch (e) {
        debugPrint('Error toggling off subtitle: $e');
      }
    }
    _notifySubtitleStateChanged();
  }

  Future<void> clearCurrentSubtitle() async {
    if (_disposed) return;
    _lastSelectedSubtitleTrack = _activeSubtitleTrack;
    _subtitleEnabled = false;

    try {
      videoController.setSubtitleTracks([]);
    } catch (e) {
      debugPrint('Error clearing current subtitle: $e');
    }

    if (_hasActiveExternalSubtitle) {
      try {
        videoController.setExternalSubtitle('');
      } catch (e) {
        debugPrint('Error clearing external subtitle: $e');
      }
      _hasActiveExternalSubtitle = false;
    }
    _notifySubtitleStateChanged();
  }

  void clearSubtitle() {
    if (_disposed) return;
    _subtitleTracks.removeWhere((t) => t.type == SubtitleTrackType.external);
    _activeSubtitleTrack = null;
    _subtitleEnabled = false;

    if (_hasActiveExternalSubtitle) {
      try {
        videoController.setExternalSubtitle('');
      } catch (e) {
        debugPrint('Error clearing external subtitle: $e');
      }
      _hasActiveExternalSubtitle = false;
    }

    try {
      videoController.setSubtitleTracks([]);
    } catch (e) {
      debugPrint('Error clearing subtitles: $e');
    }
    _notifySubtitleStateChanged();
  }

  Future<void> _generateThumbnailAsync() async {
    if (_disposed) return;

    try {
      final thumbPath = await _thumbnailService.generateThumbnail(
        path,
        type: ph.MediaType.video,
      );

      if (thumbPath != null && !_disposed) {
        var history = await _historyRepo.getByPath(path);
        if (!_disposed && history != null) {
          final updatedHistory = ph.PlayHistory(
            id: history.id,
            path: history.path,
            displayName: history.displayName,
            extension: history.extension,
            type: history.type,
            lastPosition: history.lastPosition,
            totalDuration: history.totalDuration,
            lastPlayedAt: history.lastPlayedAt,
            playCount: history.playCount,
            thumbnailPath: thumbPath,
          );
          await _historyRepo.upsert(updatedHistory);
        }
      }
    } catch (e) {
      if (!_disposed) debugPrint('Thumbnail generation failed: $e');
    }
  }

  Future<void> _handleVideoComplete() async {
    if (_disposed) return;
    await _playQueueNotifier.playNext();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _positionTimer?.cancel();
    _positionTimer = null;

    if (_videoControllerListener != null) {
      videoController.removeListener(_videoControllerListener!);
      _videoControllerListener = null;
    }

    try {
      videoController.setVolume(0);
    } catch (_) {}

    try {
      videoController.pause();
    } catch (_) {}

    try {
      videoController.dispose();
    } catch (_) {}
  }
}
