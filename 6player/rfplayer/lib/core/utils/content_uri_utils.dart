class ContentUriUtils {
  static bool isContentUri(String path) {
    return path.startsWith('content://');
  }
}
