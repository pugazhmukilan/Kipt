import 'dart:io';
import 'dart:ui';

import 'package:image/image.dart' as img;

/// Preset aspect ratios offered in the in-app camera. [value] is width/height
/// (a value < 1 means the subject is taller than wide, e.g. an A4 sheet held
/// in portrait).
enum CameraAspectRatio {
  square(label: '1:1', value: 1.0),
  portrait3x4(label: '3:4', value: 3 / 4),
  a4(label: 'A4', value: 210 / 297),
  landscape16x9(label: '16:9', value: 16 / 9);

  final String label;
  final double value;

  const CameraAspectRatio({required this.label, required this.value});

  bool get isLandscape => value >= 1;
}

/// Helpers for cropping photos to a chosen aspect ratio and reading the
/// stored width/height ratio of an image file.
class PhotoRatioUtils {
  /// Decodes the image at [path] and returns its width/height ratio, or `null`
  /// when the file cannot be decoded as an image.
  static Future<double?> readImageAspectRatio(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.height == 0) return null;
      return decoded.width / decoded.height;
    } catch (_) {
      return null;
    }
  }

  /// Center-crops the image at [inputPath] to [ratio] (width/height),
  /// downscaling so the longest side is at most [maxDimension], and writes a
  /// JPEG to [outputPath].
  ///
  /// Images already within 2% of the target ratio are simply re-encoded.
  /// Returns the output path.
  static Future<String> cropImageToRatio({
    required String inputPath,
    required double ratio,
    required String outputPath,
    int maxDimension = 2048,
    int quality = 90,
  }) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return inputPath;

      var image = decoded;
      // Scale down oversize captures before cropping.
      final scale =
          (maxDimension /
                  (image.width > image.height ? image.width : image.height))
              .clamp(0.0, 1.0);
      if (scale < 1) {
        image = img.copyResize(
          image,
          width: (image.width * scale).round(),
          height: (image.height * scale).round(),
        );
      }

      final w = image.width;
      final h = image.height;
      final currentRatio = w / h;

      if ((currentRatio - ratio).abs() > 0.02 && ratio > 0) {
        double cropW;
        double cropH;
        if (currentRatio > ratio) {
          // Too wide — crop the sides.
          cropH = h.toDouble();
          cropW = h * ratio;
        } else {
          // Too tall — crop the top/bottom.
          cropW = w.toDouble();
          cropH = w / ratio;
        }
        final x = ((w - cropW) / 2).round().clamp(0, w);
        final y = ((h - cropH) / 2).round().clamp(0, h);
        image = img.copyCrop(
          image,
          x: x,
          y: y,
          width: cropW.round().clamp(1, w - x),
          height: cropH.round().clamp(1, h - y),
        );
      }

      await File(
        outputPath,
      ).writeAsBytes(img.encodeJpg(image, quality: quality));
      return outputPath;
    } catch (_) {
      return inputPath;
    }
  }

  /// Crops the image at [inputPath] to the exact region the on-screen frame
  /// covers, so the saved photo matches the live preview WYSIWYG.
  ///
  /// [previewWidth]/[previewHeight] describe the on-screen preview box in the
  /// same units the frame overlay uses (pass the *displayed* dimensions, i.e.
  /// `previewSize` with width/height swapped for a portrait phone). The raw
  /// sensor image is center-cropped to the frame and, when the capture is
  /// stored in sensor (landscape) orientation, rotated upright. Writes a JPEG
  /// to [outputPath] and returns it.
  static Future<String> cropImageToPreviewFrame({
    required String inputPath,
    required String outputPath,
    required double targetRatio,
    required double previewWidth,
    required double previewHeight,
    int maxDimension = 2048,
    int quality = 90,
  }) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return inputPath;

      // Camera files may keep the sensor orientation in EXIF metadata. Apply
      // that orientation before mapping the frame to pixels.
      var image = img.bakeOrientation(decoded);
      if (previewHeight > previewWidth && image.width > image.height) {
        image = img.copyRotate(image, angle: 90);
      }

      if (targetRatio > 0) {
        final currentRatio = image.width / image.height;
        if ((currentRatio - targetRatio).abs() > 0.02) {
          final cropW = currentRatio > targetRatio
              ? (image.height * targetRatio).round()
              : image.width;
          final cropH = currentRatio > targetRatio
              ? image.height
              : (image.width / targetRatio).round();
          final x = ((image.width - cropW) / 2).round();
          final y = ((image.height - cropH) / 2).round();
          image = img.copyCrop(
            image,
            x: x,
            y: y,
            width: cropW,
            height: cropH,
          );
        }
      }

      // Scale down oversize results.
      final scale =
          (maxDimension /
                  (image.width > image.height ? image.width : image.height))
              .clamp(0.0, 1.0);
      if (scale < 1) {
        image = img.copyResize(
          image,
          width: (image.width * scale).round(),
          height: (image.height * scale).round(),
        );
      }

      await File(
        outputPath,
      ).writeAsBytes(img.encodeJpg(image, quality: quality));
      return outputPath;
    } catch (_) {
      return inputPath;
    }
  }
}

/// Fits a box of the given [ratio] (width/height) inside a [maxWidth] x
/// [maxHeight] area, centering it. Returns the fitted [Size].
Size fitAspectRatioBox({
  required double ratio,
  required double maxWidth,
  required double maxHeight,
}) {
  if (ratio <= 0 || maxWidth <= 0 || maxHeight <= 0) {
    return Size(maxWidth.clamp(0.0, double.infinity),
        maxHeight.clamp(0.0, double.infinity));
  }
  double w = maxWidth;
  double h = maxWidth / ratio;

  if (h > maxHeight) {
    h = maxHeight;
    w = maxHeight * ratio;
  }
  if (w > maxWidth) {
    w = maxWidth;
    h = maxWidth / ratio;
  }
  return Size(w, h);
}
