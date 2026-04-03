import '../database/daos/video_bookmark_dao.dart';
import '../models/video_bookmark.dart';

class VideoBookmarkRepository {
  final VideoBookmarkDao _dao;

  VideoBookmarkRepository(this._dao);

  Future<List<VideoBookmark>> getAll() async {
    return await _dao.getAll();
  }

  Future<List<VideoBookmark>> getByVideoPath(String videoPath) async {
    return await _dao.getByVideoPath(videoPath);
  }

  Future<void> addBookmark(VideoBookmark bookmark) async {
    await _dao.insert(bookmark);
  }

  Future<void> deleteBookmark(String id) async {
    await _dao.deleteById(id);
  }

  Future<void> deleteAllBookmarksForVideo(String videoPath) async {
    await _dao.deleteByVideoPath(videoPath);
  }
}