import 'package:flutter/material.dart';

/// Card widget containing bottom action buttons:
/// Previous VCR Reports, Collect, Raise Challan, and Seize Vehicle.
class VehicleActionButtons extends StatelessWidget {
  final VoidCallback onPreviousVcrReports;
  final VoidCallback onCollect;
  final VoidCallback onRaiseChallan;
  final VoidCallback onSeizeVehicle;

  const VehicleActionButtons({
    super.key,
    required this.onPreviousVcrReports,
    required this.onCollect,
    required this.onRaiseChallan,
    required this.onSeizeVehicle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              final reportBtn = OutlinedButton.icon(
                onPressed: onPreviousVcrReports,
                icon: const Icon(Icons.description, size: 16, color: Colors.black87),
                label: const Text(
                  'Previous VCR Reports',
                  style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
              );

              final collectBtn = OutlinedButton(
                onPressed: onCollect,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF28A745)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                child: const Text(
                  'Collect',
                  style: TextStyle(color: Color(0xFF28A745), fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              );

              final raiseBtn = ElevatedButton(
                onPressed: onRaiseChallan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF198754),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                child: const Text(
                  'Raise Challan',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              );

              final seizeBtn = ElevatedButton(
                onPressed: onSeizeVehicle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC3545),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                child: const Text(
                  'Seize Vehicle',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              );

              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 3, child: reportBtn),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: collectBtn),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: raiseBtn),
                        const SizedBox(width: 8),
                        Expanded(child: seizeBtn),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: reportBtn),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: collectBtn),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: raiseBtn),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: seizeBtn),
                ],
              );
            },
          );
  }
}
