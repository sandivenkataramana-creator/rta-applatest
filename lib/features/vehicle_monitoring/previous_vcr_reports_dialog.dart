import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/utils/pdf_helper.dart';
import 'vehicle_monitoring_repository.dart';

class PreviousVcrReportsDialog extends ConsumerStatefulWidget {
  const PreviousVcrReportsDialog({
    super.key,
    required this.vehicleNumber,
  });

  final String vehicleNumber;

  static void show(BuildContext context, String vehicleNumber) {
    showDialog(
      context: context,
      builder: (_) => PreviousVcrReportsDialog(vehicleNumber: vehicleNumber),
    );
  }

  @override
  ConsumerState<PreviousVcrReportsDialog> createState() => _PreviousVcrReportsDialogState();
}

class _PreviousVcrReportsDialogState extends ConsumerState<PreviousVcrReportsDialog> {
  late Future<List<Map<String, dynamic>>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient(SecureStorageService());
    final repo = VehicleMonitoringRepository(apiClient: apiClient);
    _reportsFuture = repo.getVcrByVehicle(widget.vehicleNumber);
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('dd/MM/yyyy hh:mm a').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: 650,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0F3260),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_edu, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Previous VCR Reports - ${widget.vehicleNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _reportsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2.5),
                          SizedBox(height: 12),
                          Text('Fetching Previous VCR Reports...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load VCR reports: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    );
                  }

                  final reports = snapshot.data ?? [];
                  if (reports.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No previous VCR reports found.', style: TextStyle(fontSize: 14, color: Colors.black54)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: reports.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = reports[index];
                      final vcrNo = (item['vcrNumber'] ?? item['id'] ?? 'N/A').toString();
                      final issuedDate = _formatDate(item['issuedDate']?.toString());
                      final location = (item['location'] ?? 'N/A').toString();
                      final regNo = (item['registrationNumber'] ?? widget.vehicleNumber).toString();
                      final driverName = (item['driverName'] ?? 'N/A').toString();
                      final licenceNo = (item['licenceNumber'] ?? 'N/A').toString();
                      final offences = (item['offences'] ?? 'N/A').toString();
                      final fineAmt = item['fineAmount'] ?? 0.0;
                      final status = (item['paymentStatus'] ?? 'PENDING').toString();

                      return Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Bar: VCR Number + Status Tag
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.receipt_long, size: 18, color: Color(0xFF0F3260)),
                                      const SizedBox(width: 8),
                                      Text(
                                        vcrNo,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F3260)),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: status.toUpperCase() == 'PAID' ? Colors.green.shade100 : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: status.toUpperCase() == 'PAID' ? Colors.green.shade800 : Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),

                              // Key-Value Grid
                              Wrap(
                                spacing: 20,
                                runSpacing: 10,
                                children: [
                                  _infoChip('Registration No', regNo, Icons.directions_car),
                                  _infoChip('Issued Date', issuedDate, Icons.calendar_today),
                                  _infoChip('Location', location, Icons.location_on),
                                  _infoChip('Driver Name', driverName, Icons.person),
                                  _infoChip('Licence No', licenceNo, Icons.badge),
                                  _infoChip('Fine Amount', '₹$fineAmt', Icons.currency_rupee),
                                ],
                              ),
                              if (offences.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.warning_amber, size: 16, color: Colors.amber),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Offences: $offences',
                                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),
                              // PDF Download Button
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: vcrNo == 'N/A'
                                      ? null
                                      : () async {
                                          try {
                                            final apiClient = ApiClient(SecureStorageService());
                                            final repo = VehicleMonitoringRepository(apiClient: apiClient);
                                            final pdfData = await repo.generatePdf(vcrNo);
                                            await PdfHelper.displayOrDownloadPdf(pdfData, '$vcrNo.pdf');
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Failed to download PDF: $e')),
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.red),
                                  label: const Text('Download PDF', style: TextStyle(fontSize: 12, color: Colors.black87)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value, IconData icon) {
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
