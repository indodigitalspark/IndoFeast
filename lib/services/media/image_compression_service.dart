import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ImageCompressionResult {
  const ImageCompressionResult({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class ImageCompressionService {
  const ImageCompressionService._();

  static Future<ImageCompressionResult> compress({
    required Uint8List bytes,
    required String fileName,
    int maxWidth = 1600,
    int quality = 82,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return ImageCompressionResult(bytes: bytes, fileName: fileName);
    }

    final resized = decoded.width > maxWidth
        ? img.copyResize(decoded, width: maxWidth)
        : decoded;

    final encoded = fileName.toLowerCase().endsWith('.png')
        ? Uint8List.fromList(img.encodePng(resized, level: 6))
        : Uint8List.fromList(img.encodeJpg(resized, quality: quality));

    return ImageCompressionResult(
      bytes: encoded,
      fileName: _normalizedFileName(fileName),
    );
  }

  static String _normalizedFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return fileName;
    }
    return '$fileName.jpg';
  }
}
