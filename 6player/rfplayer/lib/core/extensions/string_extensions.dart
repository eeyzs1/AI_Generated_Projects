import '../constants/supported_formats.dart';

extension StringExtensions on String {
  bool get isVideoFile => fileExtension.isVideoExtension;
  
  bool get isImageFile => fileExtension.isImageExtension;
  
  String get fileExtension {
    final lastDotIndex = lastIndexOf('.');
    if (lastDotIndex == -1) return '';
    return substring(lastDotIndex + 1).toLowerCase();
  }
}

extension StringExtensionChecks on String {
  bool get isVideoExtension => videoFormats.contains(this);
  bool get isImageExtension => imageFormats.contains(this);
}