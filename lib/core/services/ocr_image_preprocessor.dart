import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Shared utility for normalizing images prior to OCR.
/// - Flattens transparent PNG/RGBA onto a solid white background (avoids black background decode artifacts).
/// - Upscales small images (< 500px) so isolated single digits and small text are recognizable.
/// - Adds 40px solid white border padding so text detectors do not clip edge-touching numbers.
class OcrImagePreprocessor {
  static Future<File> normalizeForOcr(File file) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      if (!['png', 'jpg', 'jpeg', 'webp', 'bmp'].contains(ext)) {
        return file;
      }

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return file;

      final bool hasAlpha = decoded.hasAlpha;
      final bool isTooSmall = decoded.width < 500 || decoded.height < 500;

      if (!hasAlpha && !isTooSmall) {
        return file;
      }

      int targetW = decoded.width;
      int targetH = decoded.height;
      if (isTooSmall) {
        final minDim = targetW < targetH ? targetW : targetH;
        final scale = (500.0 / minDim).clamp(1.0, 4.0);
        targetW = (targetW * scale).round();
        targetH = (targetH * scale).round();
      }

      final resized = (targetW != decoded.width || targetH != decoded.height)
          ? img.copyResize(decoded, width: targetW, height: targetH, interpolation: img.Interpolation.linear)
          : decoded;

      const padding = 40;
      final canvasW = resized.width + (padding * 2);
      final canvasH = resized.height + (padding * 2);
      final canvas = img.Image(width: canvasW, height: canvasH, numChannels: 3);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(canvas, resized, dstX: padding, dstY: padding);

      final jpgBytes = img.encodeJpg(canvas, quality: 95);
      final tempPath = '${Directory.systemTemp.path}/norm_${DateTime.now().millisecondsSinceEpoch}_${file.hashCode.abs()}.jpg';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(jpgBytes);
      return tempFile;
    } catch (e) {
      debugPrint('OcrImagePreprocessor error: $e, falling back to original');
      return file;
    }
  }
}
