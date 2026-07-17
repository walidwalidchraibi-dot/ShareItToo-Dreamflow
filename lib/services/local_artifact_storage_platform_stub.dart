import 'dart:typed_data';

class PlatformImageSaveResult {
  final bool success;
  final bool permissionDenied;
  final String? storedPath;
  final String? message;

  const PlatformImageSaveResult({
    required this.success,
    this.permissionDenied = false,
    this.storedPath,
    this.message,
  });
}

Future<PlatformImageSaveResult> saveImageToGallery({
  required String sourcePath,
  required String targetFileName,
  required String album,
}) async {
  return const PlatformImageSaveResult(
    success: false,
    message: 'Galeriespeicherung wird auf dieser Plattform nicht unterstützt.',
  );
}

Future<String> savePdfToDocuments({
  required Uint8List bytes,
  required String targetFileName,
  required String directoryName,
}) async {
  throw UnsupportedError('Lokale PDF-Speicherung wird auf dieser Plattform nicht unterstützt.');
}
