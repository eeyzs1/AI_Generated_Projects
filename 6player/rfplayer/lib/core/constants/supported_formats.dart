const Set<String> videoFormats = {
  'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', '3gp', 'm4v',
  'mpg', 'mpeg', 'rmvb', 'ts', 'vob', 'ogv',
};

const Set<String> imageFormats = {
  'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'tif', 'ico',
};

const Set<String> subtitleFormats = {
  'srt', 'ass', 'ssa', 'vtt', 'sub', 'dfxp',
};

bool isVideoFile(String path) {
  final ext = _getExtension(path);
  return videoFormats.contains(ext);
}

bool isImageFile(String path) {
  final ext = _getExtension(path);
  return imageFormats.contains(ext);
}

bool isSubtitleFile(String path) {
  final ext = _getExtension(path);
  return subtitleFormats.contains(ext);
}

String _getExtension(String path) {
  final dotIndex = path.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex >= path.length - 1) return '';
  return path.substring(dotIndex + 1).toLowerCase();
}
