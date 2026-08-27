import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../vehicle_monitoring_screen.dart';

/// Card widget displaying PREVIOUS VCR CHALLANS history records.
class PreviousVcrSection extends StatelessWidget {
  final String vehicleNumber;
  final VehicleMonitoringState state;
  final WidgetRef ref;
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> selectedOffences;
  final Function(String vNo) onViewHistory;

  const PreviousVcrSection({
    super.key,
    required this.vehicleNumber,
    required this.state,
    required this.ref,
    required this.item,
    required this.selectedOffences,
    required this.onViewHistory,
  });

  Future<List<Map<String, dynamic>>> _fetchVcrData() async {
    final list = await ref.read(vehicleMonitoringProvider.notifier).repository.fetchVcrHistory(vehicleNumber);
    if (list.isNotEmpty) {
      final validVcrs = <Map<String, dynamic>>[];
      final seenKeys = <String>{};

      for (final item in list) {
        final notif = (item['notification'] ?? item['offence'] ?? item['violationType'] ?? item['remarks'] ?? '').toString().trim().toLowerCase();
        if (notif == 'all clear' || notif == 'all_clear') continue;

        final rawAmt = item['totalFineAmount'] ?? item['fineAmount'] ?? item['challanAmount'] ?? item['amount'] ?? item['totalAmount'] ?? 0.0;
        final amt = rawAmt is num ? rawAmt.toDouble() : (double.tryParse(rawAmt.toString()) ?? 0.0);

        final id = (item['id'] ?? item['vcrNo'] ?? item['challanNo'] ?? item['vehicleRecordId'] ?? '').toString();
        final key = id.isNotEmpty ? id : '${notif}_$amt';
        if (seenKeys.contains(key)) continue;
        seenKeys.add(key);

        validVcrs.add({
          ...item,
          'vehicleNumber': (item['vehicleNumber'] ?? vehicleNumber).toString(),
          'challanAmount': amt,
          'notification': notif,
        });
      }
      if (validVcrs.isNotEmpty) {
        final double totalAmt = validVcrs.fold(0.0, (sum, it) => sum + (it['challanAmount'] as double? ?? 0.0));
        return [
          {
            'vehicleNumber': vehicleNumber,
            'challanAmount': totalAmt,
            'status': validVcrs.first['status'] ?? 'PENDING',
            'createdTime': validVcrs.first['createdTime'] ?? '',
          }
        ];
      }
    }

    final cleanVehicleNo = vehicleNumber.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final vcrSources = [...state.violations, ...state.notifications];
    final matches = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    for (final it in vcrSources) {
      if (it is Map) {
        final vObj = it['vehicle'];
        String vNo = '';
        if (vObj is Map) {
          vNo = (vObj['vehicleNumber'] ?? vObj['vehicleNo'] ?? vObj['registrationNumber'] ?? '').toString();
        }
        if (vNo.isEmpty) {
          vNo = (it['vehicleNumber'] ?? it['vehicleNo'] ?? it['registrationNumber'] ?? '').toString();
        }
        final cleanVNo = vNo.replaceAll(RegExp(r'\s+'), '').toUpperCase();
        if (cleanVNo == cleanVehicleNo) {
          final notif = (it['notification'] ?? it['offence'] ?? it['remarks'] ?? '').toString().trim().toLowerCase();
          if (notif == 'all clear' || notif == 'all_clear') continue;

          final rawAmt = (it['totalFineAmount'] ?? it['fineAmount'] ?? it['challanAmount'] ?? it['amount'] ?? it['totalAmount'] ?? 0.0);
          final amt = rawAmt is num ? rawAmt.toDouble() : (double.tryParse(rawAmt.toString()) ?? 0.0);

          final id = (it['id'] ?? it['notificationId'] ?? it['vcrNo'] ?? '').toString();
          final key = id.isNotEmpty ? id : '${notif}_$amt';
          if (seenKeys.contains(key)) continue;
          seenKeys.add(key);

          matches.add({
            'vehicleNumber': vehicleNumber,
            'challanAmount': amt,
            'status': it['status'] ?? 'PENDING',
            'createdTime': it['createdTime'] ?? it['timestamp'] ?? it['date'] ?? '',
          });
        }
      }
    }

    if (matches.isNotEmpty) {
      final double totalAmt = matches.fold(0.0, (sum, it) => sum + (it['challanAmount'] as double? ?? 0.0));
      return [
        {
          'vehicleNumber': vehicleNumber,
          'challanAmount': totalAmt,
          'status': matches.first['status'] ?? 'PENDING',
          'createdTime': matches.first['createdTime'] ?? '',
        }
      ];
    }

    // Fallback 2: Build record from current vehicle item offences / fine amount if > 0
    final double offencesAmt = selectedOffences.fold(0.0, (sum, o) => sum + (o['amount'] as num? ?? 0.0).toDouble());
    final rawItemAmt = item['totalFineAmount'] ?? item['fineAmount'] ?? item['challanAmount'] ?? item['amount'] ?? item['totalAmount'];
    final double itemAmt = rawItemAmt is num ? rawItemAmt.toDouble() : (double.tryParse(rawItemAmt?.toString() ?? '') ?? 0.0);
    final double displayAmt = offencesAmt > 0 ? offencesAmt : itemAmt;

    if (displayAmt <= 0) return [];

    return [
      {
        'vehicleNumber': vehicleNumber,
        'challanAmount': displayAmt,
        'status': item['status'] ?? 'PENDING',
        'createdTime': item['createdTime'] ?? item['timestamp'] ?? '',
      }
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchVcrData(),
      builder: (context, snapshot) {
        final vcrList = snapshot.data ?? [];
        final count = vcrList.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.access_time_outlined, size: 18, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PREVIOUS VCR CHALLANS  $count RECORDS',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F3260),
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Navy Blue Table Header
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F3260),
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'VEHICLE',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'PREVIOUS AMOUNT',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'ACTION',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (vcrList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No previous VCR reports for $vehicleNumber.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vcrList.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final record = vcrList[index];
                      final vNo = record['vehicleNumber']?.toString() ?? vehicleNumber;
                      final rawAmt = record['challanAmount'] ?? record['totalFineAmount'] ?? record['fineAmount'] ?? record['amount'] ?? record['totalAmount'] ?? 0;
                      final amtVal = rawAmt is num ? rawAmt.toDouble() : (double.tryParse(rawAmt.toString()) ?? 0.0);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                vNo,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '₹${amtVal.toStringAsFixed(2)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton(
                                  onPressed: () => onViewHistory(vNo),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF007BFF)),
                                    foregroundColor: const Color(0xFF007BFF),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    minimumSize: const Size(0, 30),
                                  ),
                                  child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            );
      },
    );
  }
}
