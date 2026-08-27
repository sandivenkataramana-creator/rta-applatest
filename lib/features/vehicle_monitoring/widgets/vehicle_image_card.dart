import 'package:flutter/material.dart';
import '../../../core/widgets/image_zoom_helper.dart';
import '../../../core/widgets/network_image_helper.dart';

class VehicleImageCard extends StatelessWidget {
  final String imageUrl;
  final String cameraId;
  final String location;
  final double? imageHeight;
  final BoxFit imageFit;
  final VoidCallback? onTap;

  const VehicleImageCard({
    super.key,
    required this.imageUrl,
    required this.cameraId,
    required this.location,
    this.imageHeight = 260,
    this.imageFit = BoxFit.cover,
    this.onTap,
  });

  Widget _buildImageWidget(BuildContext context) {
    final clean = imageUrl.trim();
    final VoidCallback handleTap = onTap ??
        () {
          if (clean.isNotEmpty) {
            showZoomedImageDialog(context, clean);
          }
        };

    if (clean.isEmpty) {
      return GestureDetector(
        onTap: handleTap,
        child: Container(
          height: imageHeight ?? 200,
          color: const Color(0xFF0F3260),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_car, size: 48, color: Colors.white70),
                SizedBox(height: 8),
                Text(
                  'Telangana ANPR Capture',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (clean.startsWith('assets/')) {
      return GestureDetector(
        onTap: handleTap,
        child: Image.asset(clean, height: imageHeight, fit: imageFit),
      );
    }
    return buildPlatformNetImage(
      clean,
      height: imageHeight,
      fit: imageFit,
      onTap: handleTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImageWidget(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cameraId,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
