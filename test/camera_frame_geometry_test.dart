import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:warranty_vault/core/utils/camera_aspect_ratio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fitAspectRatioBox', () {
    test('never throws for fractional or degenerate sizes', () {
      expect(() => fitAspectRatioBox(
          ratio: 0.707, maxWidth: 0.82, maxHeight: 1.0), returnsNormally);
      expect(() => fitAspectRatioBox(ratio: 0, maxWidth: 0, maxHeight: 0),
          returnsNormally);
      final s = fitAspectRatioBox(ratio: 0.707, maxWidth: 0.82, maxHeight: 1.0);
      expect(s.width, lessThanOrEqualTo(0.82));
      expect(s.height, lessThanOrEqualTo(1.0));
      expect(s.width / s.height, closeTo(0.707, 0.001));
    });
  });

  group('cropImageToPreviewFrame', () {
    // Portrait preview box (sensor reported 1080x1920 -> swapped on screen).
    const previewWidth = 1080.0;
    const previewHeight = 1920.0;
    const target = 210 / 297;

    void expectSavedRatio(File file, double ratio) {
      final decoded = img.decodeImage(file.readAsBytesSync());
      expect(decoded, isNotNull);
      expect(decoded!.width / decoded.height, closeTo(ratio, 0.02));
    }

    test('portrait sensor capture keeps the framed region', () async {
      const sensor = Size(2268, 4032); // portrait-oriented raw
      final srcPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}ps_src.png';
      final outPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}ps_out.jpg';
      try {
        File(srcPath).writeAsBytesSync(img.encodePng(
            img.Image(width: sensor.width.toInt(), height: sensor.height.toInt())));
        final result = await PhotoRatioUtils.cropImageToPreviewFrame(
          inputPath: srcPath,
          outputPath: outPath,
          targetRatio: target,
          previewWidth: previewWidth,
          previewHeight: previewHeight,
        );
        expectSavedRatio(File(result), target);
      } finally {
        for (final p in [srcPath, outPath]) {
          final f = File(p);
          if (f.existsSync()) f.deleteSync();
        }
      }
    });

    test('landscape sensor capture is rotated upright to match the frame',
        () async {
      const sensor = Size(4032, 2268); // landscape-oriented raw
      final srcPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}ps_src2.png';
      final outPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}ps_out2.jpg';
      try {
        File(srcPath).writeAsBytesSync(img.encodePng(
            img.Image(width: sensor.width.toInt(), height: sensor.height.toInt())));
        final result = await PhotoRatioUtils.cropImageToPreviewFrame(
          inputPath: srcPath,
          outputPath: outPath,
          targetRatio: target,
          previewWidth: previewWidth,
          previewHeight: previewHeight,
        );
        expectSavedRatio(File(result), target);
      } finally {
        for (final p in [srcPath, outPath]) {
          final f = File(p);
          if (f.existsSync()) f.deleteSync();
        }
      }
    });
  });
}