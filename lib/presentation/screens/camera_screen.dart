import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/camera_aspect_ratio.dart';

/// Result of a successful in-app capture: the temporary file [path] of the
/// cropped photo and the [aspectRatio] (width/height) the frame used.
class CapturedPhoto {
  final String path;
  final double aspectRatio;

  const CapturedPhoto({required this.path, required this.aspectRatio});
}

/// Default camera frame ratio (210 / 297, an A4 sheet in portrait).
const double a4DefaultRatio = 210 / 297;

/// Opens the in-app camera and returns the captured (ratio-cropped) photo, or
/// `null` if the user cancels.
Future<CapturedPhoto?> showCameraScreen(
  BuildContext context, {
  double? initialRatio = a4DefaultRatio,
}) {
  return Navigator.of(context).push<CapturedPhoto>(
    MaterialPageRoute(
      builder: (_) =>
          CameraScreen(initialRatio: initialRatio ?? a4DefaultRatio),
      fullscreenDialog: true,
    ),
  );
}

class CameraScreen extends StatefulWidget {
  final double initialRatio;

  const CameraScreen({super.key, this.initialRatio = a4DefaultRatio});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  CameraDescription? _camera;
  List<CameraDescription> _cameras = [];

  CameraAspectRatio _ratio = CameraAspectRatio.a4;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    final initial = CameraAspectRatio.values
        .where((r) => (r.value - widget.initialRatio).abs() < 0.001)
        .toList();
    if (initial.isNotEmpty) _ratio = initial.first;
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _error = null;
      _permissionDenied = false;
    });

    // The camera plugin fails with an access-denied error when the runtime
    // permission has not been granted, so request it explicitly first.
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _permissionDenied = true;
        _error = permission.isPermanentlyDenied
            ? 'Camera access was permanently denied. '
                  'Enable it in the app settings to take photos.'
            : 'Camera access is needed to take photos.';
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _error = 'No camera available on this device.';
        });
        return;
      }
      _camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      // Try progressively lower resolutions in case a device rejects a preset.
      for (final preset in [
        ResolutionPreset.high,
        ResolutionPreset.medium,
        ResolutionPreset.low,
      ]) {
        final controller = CameraController(
          _camera!,
          preset,
          enableAudio: false,
        );
        _controller = controller;
        try {
          await controller.initialize();
          break;
        } catch (e) {
          await controller.dispose();
          _controller = null;
          if (preset == ResolutionPreset.low) rethrow;
        }
      }
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        final message = e.toString();
        final isAccessDenied =
            message.contains('CameraAccessDenied') ||
            message.contains('access'); // lenient — covers denied/restricted
        _error = isAccessDenied
            ? 'Camera access is needed to take photos.'
            : 'Failed to start camera: $message';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final ratio = _ratio.value;
      final xfile = await controller.takePicture();
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}${Platform.pathSeparator}kipt_cam_${DateTime.now().millisecondsSinceEpoch}.jpg';
      // The preview shows the sensor upright, so its on-screen box is the
      // reported preview size with width/height swapped (portrait phone).
      final previewSize = controller.value.previewSize;
      final cropped = await PhotoRatioUtils.cropImageToPreviewFrame(
        inputPath: xfile.path,
        outputPath: outputPath,
        targetRatio: ratio,
        previewWidth: previewSize?.height ?? ratio,
        previewHeight: previewSize?.width ?? 1,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(CapturedPhoto(path: cropped, aspectRatio: ratio));
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreview(),
            if (_error != null) _buildError(),
            if (_initializing) const _CameraLoading(),
            _buildTopBar(),
            if (!_initializing && _error == null) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    final previewSize = controller.value.previewSize;
    // The sensor image rotated upright (portrait phone) has its short side as
    // the on-screen width. Cover-fill the whole screen, cropping the overflow.
    final boxWidth = previewSize?.height ?? 1;
    final boxHeight = previewSize?.width ?? 1;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: boxWidth,
          height: boxHeight,
          child: CameraPreview(
            controller,
            child: _RatioFrameOverlay(
              ratio: _ratio.value,
              boxWidth: boxWidth,
              boxHeight: boxHeight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _permissionDenied
                  ? Icons.no_photography_rounded
                  : Icons.error_outline_rounded,
              size: 56,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (_permissionDenied)
                  FilledButton.icon(
                    onPressed: () async {
                      final status = await openAppSettings();
                      if (status) _initCamera();
                    },
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Open Settings'),
                  )
                else ...[
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Close'),
                  ),
                  FilledButton.icon(
                    onPressed: _initCamera,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 28,
              ),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Frame: ${_ratio.label}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final r in CameraAspectRatio.values) ...[
                  _RatioChip(
                    label: r.label,
                    selected: r == _ratio,
                    onTap: _capturing
                        ? null
                        : () => setState(() => _ratio = r),
                  ),
                  if (r != CameraAspectRatio.values.last)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _capturing ? null : _capture,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _capturing ? Colors.white38 : Colors.white,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: _capturing
                  ? const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.black,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RatioFrameOverlay extends StatelessWidget {
  /// Target crop ratio (width/height) the frame represents.
  final double ratio;

  /// The upright preview box inside the camera widget. The overlay is placed
  /// as the camera's `child`, so it shares the exact coordinate space of the
  /// live preview and the captured crop.
  final double boxWidth;
  final double boxHeight;

  const _RatioFrameOverlay({
    required this.ratio,
    required this.boxWidth,
    required this.boxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final frameSize = fitAspectRatioBox(
      ratio: ratio,
      maxWidth: boxWidth,
      maxHeight: boxHeight,
    );
    final frame = Rect.fromCenter(
      center: Offset(boxWidth / 2, boxHeight / 2),
      width: frameSize.width,
      height: frameSize.height,
    );
    return IgnorePointer(
      child: CustomPaint(painter: _FrameMaskPainter(frame: frame)),
    );
  }
}

class _FrameMaskPainter extends CustomPainter {
  final Rect frame;

  const _FrameMaskPainter({required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(frame, const Radius.circular(20));

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;

    // Rule-of-thirds guides inside the frame.
    final guidePaint = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 1; i <= 2; i++) {
      final dx = frame.left + frame.width * i / 3;
      canvas.drawLine(
        Offset(dx, frame.top),
        Offset(dx, frame.bottom),
        guidePaint,
      );
      final dy = frame.top + frame.height * i / 3;
      canvas.drawLine(
        Offset(frame.left, dy),
        Offset(frame.right, dy),
        guidePaint,
      );
    }

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _FrameMaskPainter oldDelegate) =>
      oldDelegate.frame != frame;
}

class _RatioChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _RatioChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.black38,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.white : Colors.white38,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CameraLoading extends StatelessWidget {
  const _CameraLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('Starting camera…', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
