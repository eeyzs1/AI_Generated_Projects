import '../database/daos/image_bookmark_dao.dart';
import '../models/image_bookmark.dart';

class ImageBookmarkRepository {
  final ImageBookmarkDao _dao;

  ImageBookmarkRepository(this._dao);

  Future<List<ImageBookmark>> getAll() async {
    return await _dao.getAll();
  }

  Future<ImageBookmark?> getByImagePath(String imagePath) async {
    return await _dao.getByImagePath(imagePath);
  }

  Future<void> addBookmark(String imagePath, String imageName) async {
    final existing = await getByImagePath(imagePath);
    if (existing != null) return;

    final bookmark = ImageBookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imagePath: imagePath,
      imageName: imageName,
      createdAt: DateTime.now(),
    );
    await _dao.insert(bookmark);
  }

  Future<void> deleteBookmark(String id) async {
    await _dao.deleteById(id);
  }

  Future<void> deleteByImagePath(String imagePath) async {
    await _dao.deleteByImagePath(imagePath);
  }
}
