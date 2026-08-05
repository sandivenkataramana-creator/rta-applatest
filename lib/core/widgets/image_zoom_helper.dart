import 'package:flutter/material.dart';
import 'network_image_helper.dart';

void showZoomedImageDialog(BuildContext context, String imageUrl) {
  final String effectiveUrl = imageUrl.trim();

  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ZoomableImageViewer(imageUrl: effectiveUrl);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _ZoomableImageViewer extends StatefulWidget {
  final String imageUrl;
  const _ZoomableImageViewer({required this.imageUrl});

  @override
  State<_ZoomableImageViewer> createState() => _ZoomableImageViewerState();
}

class _ZoomableImageViewerState extends State<_ZoomableImageViewer> {
  late TransformationController _transformationController;
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_doubleTapDetails == null) return;
    final position = _doubleTapDetails!.localPosition;

    if (_isZoomed) {
      _transformationController.value = Matrix4.identity();
      setState(() => _isZoomed = false);
    } else {
      final double scale = 2.5;
      final double x = -position.dx * (scale - 1);
      final double y = -position.dy * (scale - 1);
      _transformationController.value = Matrix4(
        scale, 0, 0, 0,
        0, scale, 0, 0,
        0, 0, 1, 0,
        x, y, 0, 1,
      );
      setState(() => _isZoomed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: Stack(
          children: [
            // Center Zoomable Image
            Center(
              child: GestureDetector(
                onDoubleTapDown: _handleDoubleTapDown,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 0.8,
                  maxScale: 6.0,
                  boundaryMargin: const EdgeInsets.all(80),
                  clipBehavior: Clip.none,
                  child: _buildImageWidget(widget.imageUrl),
                ),
              ),
            ),

            // Top Close (X) Button
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: CircleAvatar(
                  backgroundColor: Colors.white24,
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),

            // Bottom Zoom Instruction Pill
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Pinch or double-tap to zoom',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String url) {
    final clean = url.trim();
    if (clean.isEmpty || clean == 'assets/images/background_traffic.png') {
      return Container(
        width: 320,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hide_image_outlined, size: 48, color: Colors.white54),
              SizedBox(height: 12),
              Text(
                '(image not found)',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
    if (clean.startsWith('assets/')) {
      return Image.asset(clean, fit: BoxFit.contain);
    }
    return buildPlatformNetImage(clean, fit: BoxFit.contain);
  }
}
