import 'package:flutter/material.dart';

/// Top header widget displaying Vehicle Registration Number, Category, Type,
/// Capture location/time details, and close action button.
class VehicleHeader extends StatelessWidget {
  final String vehicleNumber;
  final String vehicleCategory;
  final String vehicleType;
  final String cameraName;
  final String detectedAt;
  final VoidCallback onClose;

  const VehicleHeader({
    super.key,
    required this.vehicleNumber,
    required this.vehicleCategory,
    required this.vehicleType,
    required this.cameraName,
    required this.detectedAt,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Vehicle Number Badge (dark blue)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F3260),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(
                            vehicleNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        // Category Badge (grey background)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text(
                            vehicleCategory,
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        // Vehicle Type Badge (light blue background)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(
                            vehicleType,
                            style: const TextStyle(
                              color: Color(0xFF1E88E5),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Captured at $cameraName - $detectedAt',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Close Button
              Container(
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.white),
                  onPressed: onClose,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
