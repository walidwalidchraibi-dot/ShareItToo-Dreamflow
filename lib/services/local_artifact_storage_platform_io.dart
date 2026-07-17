import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import 'local_artifact_storage_platform_stub.dart';

Future<PlatformImageSaveResult> saveImageToGallery({
  required String sourcePath,
  required String targetFileName,
  required String album,
}) async {
  try {
    final needsAlbumAccess = Platform.isIOS;
    final hasAccess = await Gal.hasAccess(toAlbum: needsAlbumAccess);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: needsAlbumAccess);
      if (!granted) {
        return const PlatformImageSaveResult(
          success: false,
          permissionDenied: true,
          message: 'Zugriff auf die Galerie wurde nicht erlaubt.',
        );
      }
    }

    final tempDir = await getTemporaryDirectory();
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final normalizedName = targetFileName.endsWith('.$ext') ? targetFileName : '$targetFileName.$ext';
    final tempFile = File('${tempDir.path}/$normalizedName');
    await tempFile.parent.create(recursive: true);
    await File(sourcePath).copy(tempFile.path);
    await Gal.putImage(tempFile.path, album: album);
    return PlatformImageSaveResult(success: true, storedPath: '$album/$normalizedName');
  } on GalException catch (e) {
    return PlatformImageSaveResult(
      success: false,
      permissionDenied: e.type == GalExceptionType.accessDenied,
      message: e.type.message,
    );
  } catch (e) {
    return PlatformImageSaveResult(success: false, message: e.toString());
  }
}

Future<String> savePdfToDocuments({
  required Uint8List bytes,
  required String targetFileName,
  required String directoryName,
}) async {
  final baseDir = await getApplicationDocumentsDirectory();
  final targetDir = Directory('${baseDir.path}/$directoryName');
  await targetDir.create(recursive: true);
  final file = File('${targetDir.path}/$targetFileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
