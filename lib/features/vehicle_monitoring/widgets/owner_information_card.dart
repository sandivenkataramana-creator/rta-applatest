import 'package:flutter/material.dart';

/// Card widget that displays Owner Information for a monitored vehicle.
class OwnerInformationCard extends StatelessWidget {
  final String? ownerName;
  final String? phone;
  final String? address;
  final String? district;
  final String? color;

  const OwnerInformationCard({
    super.key,
    this.ownerName,
    this.phone,
    this.address,
    this.district,
    this.color = '-',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OWNER INFORMATION',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F3260),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow('Name', ownerName),
            _buildDetailRow('Phone', phone),
            _buildDetailRow('Address', address),
            _buildDetailRow('District', district),
            _buildDetailRow('Color', color ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value.trim().isEmpty) ? 'N/A' : value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
