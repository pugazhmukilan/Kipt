import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const _cameraTeal = Color(0xFF68CEC3);

class CapturedPhoto {
  final String path;
  final double aspectRatio;

  const CapturedPhoto({required this.path, required this.aspectRatio});
}

const double a4DefaultRatio = 210 / 297;

Future<CapturedPhoto?> showCameraScreen(
  BuildContext context, {
  double? initialRatio = a4DefaultRatio,
}) {
  return Navigator.of(context).push<CapturedPhoto>(
    MaterialPageRoute(
      builder: (_) => const CameraScreen(),
      fullscreenDialog: true,
    ),
  );
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, double initialRatio = a4DefaultRatio});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _error = null;
      _permissionDenied = false;
    });
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _permissionDenied = true;
        _error = permission.isPermanentlyDenied
            ? 'Camera access was permanently denied. Enable it in app settings.'
            : 'Camera access is needed to take photos.';
      });
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera available on this device.');
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      for (final preset in [
        ResolutionPreset.high,
        ResolutionPreset.medium,
        ResolutionPreset.low,
      ]) {
        final controller = CameraController(camera, preset, enableAudio: false);
        _controller = controller;
        try {
          await controller.initialize();
          break;
        } catch (_) {
          await controller.dispose();
          _controller = null;
          if (preset == ResolutionPreset.low) rethrow;
        }
      }
      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Failed to start camera: $e';
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
      final file = await controller.takePicture();
      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;
      final acceptedPath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => PhotoReviewScreen(
            inputPath: file.path,
            tempDirectory: tempDir.path,
          ),
          fullscreenDialog: true,
        ),
      );
      if (!mounted) return;
      setState(() => _capturing = false);
      if (acceptedPath != null) {
        Navigator.of(
          context,
        ).pop(CapturedPhoto(path: acceptedPath, aspectRatio: 0));
      }
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
    return CameraPreview(controller);
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            _GlassIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close camera',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 14),
            const Text(
              'Take a photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const _CameraHint(
              icon: Icons.crop_free_rounded,
              text: 'Crop after capture',
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
      child: Container(
        padding: const EdgeInsets.only(top: 34, bottom: 26),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC000000)],
          ),
        ),
        child: Center(
          child: GestureDetector(
            onTap: _capturing ? null : _capture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _capturing ? Colors.white54 : Colors.white,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: _capturing
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.black54,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.black87,
                      size: 28,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _permissionDenied
                    ? Icons.no_photography_rounded
                    : Icons.error_outline_rounded,
                size: 42,
                color: _cameraTeal,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_permissionDenied)
              FilledButton.icon(
                onPressed: () async {
                  final opened = await openAppSettings();
                  if (opened) _initCamera();
                },
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Open Settings'),
              )
            else
              FilledButton.icon(
                onPressed: _initCamera,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

class PhotoReviewScreen extends StatefulWidget {
  final String inputPath;
  final String tempDirectory;

  const PhotoReviewScreen({
    super.key,
    required this.inputPath,
    required this.tempDirectory,
  });

  @override
  State<PhotoReviewScreen> createState() => _PhotoReviewScreenState();
}

class _PhotoReviewScreenState extends State<PhotoReviewScreen> {
  Rect _crop = const Rect.fromLTRB(0.06, 0.06, 0.94, 0.94);
  bool _saving = false;

  Future<void> _accept() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final decoded = img.decodeImage(
        await File(widget.inputPath).readAsBytes(),
      );
      if (decoded == null) {
        throw StateError('The captured image could not be read.');
      }
      final image = img.bakeOrientation(decoded);
      final outputPath =
          '${widget.tempDirectory}${Platform.pathSeparator}kipt_cam_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final x = (_crop.left * image.width).round().clamp(0, image.width - 1);
      final y = (_crop.top * image.height).round().clamp(0, image.height - 1);
      final cropped = img.copyCrop(
        image,
        x: x,
        y: y,
        width: (_crop.width * image.width).round().clamp(1, image.width - x),
        height: (_crop.height * image.height).round().clamp(
          1,
          image.height - y,
        ),
      );
      await File(outputPath).writeAsBytes(img.encodeJpg(cropped, quality: 90));
      if (mounted) {
        Navigator.of(context).pop(outputPath);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to crop photo: $e')));
    }
  }

  void _moveHandle(String handle, Offset delta, Size size) {
    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;
    var left = _crop.left;
    var top = _crop.top;
    var right = _crop.right;
    var bottom = _crop.bottom;
    if (handle.contains('l')) left += dx;
    if (handle.contains('r')) right += dx;
    if (handle.contains('t')) top += dy;
    if (handle.contains('b')) bottom += dy;
    final next = Rect.fromLTRB(left, top, right, bottom);
    if (next.width < 0.12 || next.height < 0.12) return;
    setState(() {
      _crop = Rect.fromLTRB(
        next.left.clamp(0.0, 0.88),
        next.top.clamp(0.0, 0.88),
        next.right.clamp(0.12, 1.0),
        next.bottom.clamp(0.12, 1.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Crop',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _accept,
                    style: TextButton.styleFrom(
                      foregroundColor: _cameraTeal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _cameraTeal,
                            ),
                          )
                        : const Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(widget.inputPath), fit: BoxFit.contain),
                    CustomPaint(painter: _CropPainter(_crop)),
                    ..._handles(constraints.biggest),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MinimalReviewAction(
                    icon: Icons.close_rounded,
                    label: 'Retake',
                    color: Colors.white,
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  _MinimalReviewAction(
                    icon: Icons.check_rounded,
                    label: 'Use photo',
                    color: _cameraTeal,
                    onPressed: _saving ? null : _accept,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _handles(Size size) {
    final points = {
      'lt': Offset(_crop.left * size.width, _crop.top * size.height),
      'rt': Offset(_crop.right * size.width, _crop.top * size.height),
      'lb': Offset(_crop.left * size.width, _crop.bottom * size.height),
      'rb': Offset(_crop.right * size.width, _crop.bottom * size.height),
    };
    return [
      for (final item in points.entries)
        Positioned(
          left: item.value.dx - 22,
          top: item.value.dy - 22,
          child: GestureDetector(
            onPanUpdate: (details) =>
                _moveHandle(item.key, details.delta, size),
            child: CustomPaint(
              size: const Size(38, 38),
              painter: _CropHandlePainter(),
            ),
          ),
        ),
    ];
  }
}

class _CropPainter extends CustomPainter {
  final Rect crop;
  const _CropPainter(this.crop);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawRect(rect, Paint()..blendMode = BlendMode.clear);
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) =>
      oldDelegate.crop != crop;
}

class _ReviewButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  const _ReviewButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.foregroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foregroundColor,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _MinimalReviewAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _MinimalReviewAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 25),
          color: color,
          tooltip: label,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            minimumSize: const Size(52, 52),
            shape: const CircleBorder(),
          ),
        ),
        const SizedBox(height: 7),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        minimumSize: const Size(44, 44),
      ),
    );
  }
}

class _CameraHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CameraHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 15),
            const SizedBox(width: 5),
            const Text(
              'Crop after capture',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropHandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    const length = 13.0;
    canvas.drawLine(Offset(3, 3), const Offset(3 + length, 3), paint);
    canvas.drawLine(Offset(3, 3), const Offset(3, 3 + length), paint);
    canvas.drawLine(
      Offset(size.width - 3, 3),
      Offset(size.width - 3 - length, 3),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 3, 3),
      Offset(size.width - 3, 3 + length),
      paint,
    );
    canvas.drawLine(
      Offset(3, size.height - 3),
      Offset(3 + length, size.height - 3),
      paint,
    );
    canvas.drawLine(
      Offset(3, size.height - 3),
      Offset(3, size.height - 3 - length),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 3, size.height - 3),
      Offset(size.width - 3 - length, size.height - 3),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 3, size.height - 3),
      Offset(size.width - 3, size.height - 3 - length),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
