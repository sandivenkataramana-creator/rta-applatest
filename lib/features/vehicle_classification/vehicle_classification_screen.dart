import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/loading_overlay.dart';
import '../../core/utils/uppercase_formatter.dart';
import '../../core/widgets/network_image_helper.dart';
import '../../core/widgets/page_header_banner.dart';
import '../../core/widgets/image_zoom_helper.dart';
import '../../core/utils/pdf_helper.dart';
import 'vehicle_history_state.dart';

class VehicleClassificationScreen extends ConsumerStatefulWidget {
  const VehicleClassificationScreen({super.key});

  @override
  ConsumerState<VehicleClassificationScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends ConsumerState<VehicleClassificationScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  static const int _itemsPerPage = 10;
  String _sortColumn = 'Time';
  bool _sortAscending = false;
  int _activeTab = 0; // 0 = Details, 1 = Challans, 2 = Detection Details

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vehicleHistoryNotifierProvider.notifier).fetchOffenceConfigs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${DateFormat('HH:mm:ss').format(dt)} ${DateFormat('dd/MM/yyyy').format(dt)}';
    } catch (_) {
      return dateStr;
    }
  }

  String _deriveVehicleType(Map<String, dynamic> vehicle) {
    final cat = vehicle['vehicleCategory']?.toString() ?? '';
    final vt = vehicle['vehicleType']?.toString() ?? '';
    if (cat == 'T' || vt.toLowerCase().contains('transport')) return 'TRANSPORT';
    if (cat == 'NT' || vt.toLowerCase().contains('non')) return 'NON-TRANSPORT';
    if (vt.toLowerCase().contains('commercial')) return 'COMMERCIAL';
    if (vehicle['permit'] == false) return 'COMMERCIAL';
    return 'NON-TRANSPORT';
  }

  String _deriveViolationText(Map<String, dynamic> vehicle, Map<String, dynamic> item) {
    final notification = item['notification']?.toString() ?? '';
    final remarks = item['remarks']?.toString() ?? '';
    
    if (notification.toLowerCase().contains('details not found') ||
        remarks.toLowerCase().contains('details not found')) {
      return 'DETAILS NOT FOUND.';
    }

    final List<String> violations = [];
    if (vehicle['pucCertificate'] == false) violations.add('PUC MISSING FROM RTA IN...');
    if (vehicle['insurance'] == false) violations.add('INSURANCE VIOLATION');
    if (vehicle['roadTax'] == false) violations.add('ROAD TAX VIOLATION');
    if (vehicle['permit'] == false) violations.add('PERMIT VIOLATION');
    if (vehicle['fitnessCertificate'] == false) violations.add('FITNESS VIOLATION');
    if (vehicle['registration'] == false) violations.add('REGISTRATION VIOLATION');
    
    if (violations.isEmpty) {
      if (vehicle['allClear'] == true) return 'ALL CLEAR';
      return notification.isNotEmpty ? notification.toUpperCase() : remarks.toUpperCase();
    }
    return violations.join(', ');
  }

  String _deriveStatus(Map<String, dynamic> vehicle, Map<String, dynamic> item) {
    final notification = item['notification']?.toString() ?? '';
    final remarks = item['remarks']?.toString() ?? '';
    
    if (notification.toLowerCase().contains('details not found') ||
        remarks.toLowerCase().contains('details not found')) {
      return 'NA';
    }
    if (vehicle['allClear'] == true) return 'COMPLIANT';
    return 'NON-COMPLIANT';
  }

  double _getChallanAmountForOffence(String offenceKey, List<dynamic> configs) {
    String mappedOffence = '';
    switch (offenceKey) {
      case 'pucCertificate':
        mappedOffence = 'PUC_CERTIFICATE';
        break;
      case 'insurance':
        mappedOffence = 'INSURANCE_CERTIFICATE';
        break;
      case 'roadTax':
        mappedOffence = 'ROAD_TAX_CERTIFICATE';
        break;
      case 'permit':
        mappedOffence = 'PERMITTED_CERTIFICATE';
        break;
      case 'fitnessCertificate':
        mappedOffence = 'FITNESS_CERTIFICATE';
        break;
      case 'registration':
        mappedOffence = 'REGISTRATION_CERTIFICATE';
        break;
    }

    if (mappedOffence.isNotEmpty) {
      final config = configs.firstWhere(
        (c) => c is Map && c['offence']?.toString().toUpperCase() == mappedOffence,
        orElse: () => null,
      );
      if (config != null && config['challanAmount'] != null) {
        return double.tryParse(config['challanAmount'].toString()) ?? 0.0;
      }
    }
    return 0.0;
  }

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> item, List<dynamic> configs) {
    final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
    final vehicleNumber = vehicle['vehicleNumber']?.toString() ?? 'N/A';
    final typeLabel = _deriveVehicleType(vehicle);
    final cameraName = vehicle['cameraName']?.toString() ?? vehicle['cameraID']?.toString() ?? 'N/A';
    final cameraID = vehicle['cameraID']?.toString() ?? '';
    final detectedAt = _formatDateTime(vehicle['imageDetectionTime']?.toString());
    final imgUrl = vehicle['imageUrl']?.toString() ?? vehicle['vehicleImage']?.toString() ?? item['imageUrl']?.toString() ?? '';

    final List<Map<String, dynamic>> violationsList = [];
    final Set<String> addedOffences = {};

    final keys = ['pucCertificate', 'insurance', 'roadTax', 'permit', 'fitnessCertificate', 'registration'];
    final labels = ['PUC Certificate', 'Insurance Certificate', 'Road Tax', 'Permit Certificate', 'Fitness Certificate', 'Registration Certificate'];

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      if (vehicle[key] == false) {
        final amount = _getChallanAmountForOffence(key, configs);
        final label = labels[i];
        violationsList.add({
          'offence': label,
          'amount': amount,
        });
        addedOffences.add(label.toUpperCase());
        switch (key) {
          case 'pucCertificate': addedOffences.add('PUC_CERTIFICATE'); break;
          case 'insurance': addedOffences.add('INSURANCE_CERTIFICATE'); break;
          case 'roadTax': addedOffences.add('ROAD_TAX_CERTIFICATE'); break;
          case 'permit': addedOffences.add('PERMITTED_CERTIFICATE'); break;
          case 'fitnessCertificate': addedOffences.add('FITNESS_CERTIFICATE'); break;
          case 'registration': addedOffences.add('REGISTRATION_CERTIFICATE'); break;
        }
      }
    }

    final remarks = (item['remarks']?.toString() ?? '').toLowerCase();
    final notification = (item['notification']?.toString() ?? '').toLowerCase();

    for (final config in configs) {
      if (config is! Map) continue;
      final offenceName = config['offence']?.toString() ?? '';
      if (offenceName.isEmpty) continue;

      final offenceUpper = offenceName.toUpperCase();
      if (addedOffences.contains(offenceUpper)) continue;

      final cleanName = offenceUpper
          .replaceAll('_', ' ')
          .replaceAll('CERTIFICATE', '')
          .trim()
          .toLowerCase();

      if (cleanName.isNotEmpty && (remarks.contains(cleanName) || notification.contains(cleanName))) {
        final double amount = double.tryParse(config['challanAmount']?.toString() ?? '0.0') ?? 0.0;
        final formattedLabel = offenceName
            .replaceAll('_', ' ')
            .split(' ')
            .map((str) => str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}' : '')
            .join(' ');

        violationsList.add({
          'offence': formattedLabel,
          'amount': amount,
        });
        addedOffences.add(offenceUpper);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFFF3F6F6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850, maxHeight: 650),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(color: const Color(0xFF0F3260), borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Text(vehicleNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: typeLabel == 'TRANSPORT' ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Text(
                                  typeLabel,
                                  style: TextStyle(
                                    color: typeLabel == 'TRANSPORT' ? const Color(0xFF166534) : const Color(0xFF1E40AF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(
                            color: Colors.black12,
                            child: imgUrl.isNotEmpty
                                ? GestureDetector(
                                    onTap: () => showZoomedImageDialog(context, imgUrl),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: buildPlatformNetImage(imgUrl, fit: BoxFit.contain),
                                    ),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('No Image Available', style: TextStyle(color: Colors.black54)),
                                    ],
                                  ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('DETECTION DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F3260))),
                                const SizedBox(height: 16),
                                _buildDetailRow('Camera Name', cameraName),
                                _buildDetailRow('Camera ID', cameraID),
                                _buildDetailRow('Detection Time', detectedAt),
                                _buildDetailRow('District', vehicle['districtName']?.toString() ?? 'N/A'),
                                _buildDetailRow('Zone', vehicle['zoneName']?.toString() ?? 'N/A'),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text('VIOLATIONS / CHALLANS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFDC2626))),
                                const SizedBox(height: 12),
                                if (violationsList.isEmpty)
                                  const Text('No active violations found. (Compliant)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                                else
                                  ...violationsList.map((v) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text(v['offence'].toString(), style: const TextStyle(fontWeight: FontWeight.w500))),
                                            Text('₹${v['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                          ],
                                        ),
                                      )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String label, String columnId, {int flex = 2}) {
    final isSorted = _sortColumn == columnId;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_sortColumn == columnId) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumn = columnId;
              _sortAscending = true;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: isSorted ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 4),
            Icon(
              isSorted ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
              color: isSorted ? Colors.white : Colors.white60,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  String _formatExpiryDate(dynamic dateVal) {
    if (dateVal == null || dateVal.toString().isEmpty) return '';
    try {
      final cleanVal = dateVal.toString().split('T').first;
      final parsed = DateFormat('yyyy-MM-dd').parse(cleanVal);
      return DateFormat('d MMM yyyy').format(parsed);
    } catch (_) {
      return dateVal.toString();
    }
  }

  Map<String, String> _getDocumentStatusAndDate(bool? isValid, dynamic expiryVal, String label) {
    final dateStr = _formatExpiryDate(expiryVal);
    if (isValid == true) {
      return {'status': 'Valid', 'date': dateStr};
    }
    if (dateStr.isNotEmpty) {
      return {'status': 'Expired', 'date': dateStr};
    }
    return {'status': 'N/A', 'date': ''};
  }

  Map<String, dynamic> _getVehicleDetails(String searchNumber, VehicleHistoryState state) {
    final query = searchNumber.trim().toUpperCase();
    final v = state.vehicleDetail;
    final exp = state.expiryDetails.isNotEmpty ? state.expiryDetails.first as Map<String, dynamic> : null;

    final reg = _getDocumentStatusAndDate(
      v?['registration'] as bool?,
      v?['registrationExpiry'] ?? exp?['registrationExpiry'],
      'Registration',
    );
    final fit = _getDocumentStatusAndDate(
      v?['fitnessCertificate'] as bool?,
      v?['fitnessCertificateExpiry'] ?? exp?['fitnessExpiry'],
      'Fitness',
    );
    final ins = _getDocumentStatusAndDate(
      v?['insurance'] as bool?,
      v?['insuranceCertificateExpiry'] ?? exp?['insuranceExpiry'],
      'Insurance',
    );
    final tax = _getDocumentStatusAndDate(
      v?['roadTax'] as bool?,
      v?['roadTaxExpiry'] ?? exp?['roadTaxExpiry'],
      'Road Tax',
    );
    final permit = _getDocumentStatusAndDate(
      v?['permit'] as bool?,
      v?['permitCertificateExpiry'] ?? exp?['permitExpiry'],
      'Permit',
    );

    // Mockup TS28C4445 specific matches
    if (query.contains('TS28C4445')) {
      return {
        'vehicleNumber': 'TS28C4445',
        'ownerName': 'SHAIK TAHER PASHA',
        'ownerAddress': '5-5/A, KOTHAGUMPU ST, JANAMPETA, PINAPAKA(M), BHADRADRI KOTHAGUDEM, TS',
        'vehicleType': 'MOTOR CAR',
        'vehicleCategory': 'N',
        'registration': 'Valid',
        'registrationDate': '11 Sep 2033',
        'fitness': 'N/A',
        'fitnessDate': '',
        'insurance': 'Valid',
        'insuranceDate': '15 Aug 2026',
        'roadTax': 'N/A',
        'roadTaxDate': '',
        'permit': 'N/A',
        'permitDate': '',
      };
    }

    return {
      'vehicleNumber': v?['vehicleNumber']?.toString() ?? query,
      'ownerName': v?['ownerName']?.toString() ?? 'N/A',
      'ownerAddress': v?['ownerAddress']?.toString() ?? 'N/A',
      'vehicleType': v?['vehicleType']?.toString() ?? 'N/A',
      'vehicleCategory': v?['vehicleCategory']?.toString() ?? 'N/A',
      'registration': reg['status'],
      'registrationDate': reg['date'],
      'fitness': fit['status'],
      'fitnessDate': fit['date'],
      'insurance': ins['status'],
      'insuranceDate': ins['date'],
      'roadTax': tax['status'],
      'roadTaxDate': tax['date'],
      'permit': permit['status'],
      'permitDate': permit['date'],
    };
  }

  List<Map<String, dynamic>> _getChallansList(VehicleHistoryState state) {
    final List<Map<String, dynamic>> list = [];
    final rawChallans = state.challanDetails?['challans'];
    if (rawChallans is List) {
      for (final item in rawChallans) {
        if (item is! Map) continue;
        list.add({
          'offence': item['offence']?.toString() ?? item['remarks']?.toString() ?? 'Traffic Violation',
          'amount': double.tryParse(item['challanAmount']?.toString() ?? item['amount']?.toString() ?? '0.0') ?? 0.0,
          'status': item['status']?.toString() ?? 'PENDING',
          'date': _formatDateTime(item['createdTime']?.toString() ?? item['insertTs']?.toString()),
        });
      }
    }
    return list;
  }

  Future<void> _downloadVehicleReport(BuildContext context, VehicleHistoryState state) async {
    final vehicleNo = state.searchText.isEmpty ? 'Vehicle' : state.searchText;
    final vehicle = state.vehicleDetail ?? {};
    final challans = _getChallansList(state);
    final history = state.searchResults;

    final StringBuffer csv = StringBuffer();
    csv.writeln('TELANGANA ANPR PORTAL - VEHICLE HISTORY REPORT');
    csv.writeln('Generated Date,${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}');
    csv.writeln('Vehicle Number,"$vehicleNo"');
    csv.writeln();

    // 1. VEHICLE DETAILS
    csv.writeln('--- VEHICLE DETAILS ---');
    csv.writeln('Field,Value');
    csv.writeln('Owner Name,"${vehicle['ownerName'] ?? 'N/A'}"');
    csv.writeln('Vehicle Category,"${_deriveVehicleType(vehicle)}"');
    csv.writeln('Fuel Type,"${vehicle['fuelType'] ?? 'N/A'}"');
    csv.writeln('Vehicle Class,"${vehicle['vehicleClass'] ?? 'N/A'}"');
    csv.writeln('Maker & Model,"${vehicle['makerName'] ?? 'N/A'} ${vehicle['makerModel'] ?? ''}"');
    csv.writeln('Registration Date,"${_formatDateTime(vehicle['regDate']?.toString())}"');
    csv.writeln('Engine Number,"${vehicle['engineNumber'] ?? 'N/A'}"');
    csv.writeln('Chassis Number,"${vehicle['chassisNumber'] ?? 'N/A'}"');
    csv.writeln();

    // 2. DOCUMENT STATUS
    csv.writeln('--- DOCUMENT STATUS ---');
    csv.writeln('Document,Status,Expiry Date');
    final docList = [
      {'name': 'Registration', 'status': vehicle['registration'] == true ? 'Valid' : 'N/A', 'date': vehicle['regDate']},
      {'name': 'Fitness', 'status': vehicle['fitnessCertificate'] == true ? 'Valid' : 'N/A', 'date': vehicle['fitnessDate']},
      {'name': 'Insurance', 'status': vehicle['insurance'] == true ? 'Valid' : 'N/A', 'date': vehicle['insuranceDate']},
      {'name': 'PUC', 'status': vehicle['pucCertificate'] == true ? 'Valid' : 'N/A', 'date': vehicle['pucDate']},
      {'name': 'Tax', 'status': vehicle['roadTax'] == true ? 'Valid' : 'N/A', 'date': vehicle['roadTaxDate']},
      {'name': 'Permit', 'status': vehicle['permit'] == true ? 'Valid' : 'N/A', 'date': vehicle['permitDate']},
    ];
    for (final doc in docList) {
      csv.writeln('${doc['name']},${doc['status']},"${_formatDateTime(doc['date']?.toString())}"');
    }
    csv.writeln();

    // 3. ACTIVE CHALLANS
    csv.writeln('--- ACTIVE CHALLANS ---');
    csv.writeln('Offence,Amount,Status,Date');
    if (challans.isEmpty) {
      csv.writeln('No active challans found,,,');
    } else {
      for (final c in challans) {
        csv.writeln('"${c['offence']}",₹${c['amount']},"${c['status']}","${c['date']}"');
      }
    }
    csv.writeln();

    // 4. DETECTION HISTORY
    csv.writeln('--- ANPR DETECTION HISTORY ---');
    csv.writeln('S.No,Timestamp,Location / Zone,Camera,Violation / Remarks');
    if (history.isEmpty) {
      csv.writeln('No detection records found,,,,');
    } else {
      for (int i = 0; i < history.length; i++) {
        final item = history[i] is Map<String, dynamic> ? history[i] as Map<String, dynamic> : <String, dynamic>{};
        final date = _formatDateTime(item['insertTs']?.toString() ?? item['createdTime']?.toString());
        final location = item['officeName']?.toString() ?? item['zoneName']?.toString() ?? item['location']?.toString() ?? 'N/A';
        final camera = item['cameraLocation']?.toString() ?? item['cameraID']?.toString() ?? 'N/A';
        final remarks = item['remarks']?.toString() ?? item['notification']?.toString() ?? 'N/A';
        csv.writeln('${i + 1},"$date","$location","$camera","$remarks"');
      }
    }

    final bytes = Uint8List.fromList(utf8.encode(csv.toString()));
    final filename = 'vehicle_history_${vehicleNo.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}.csv';
    await PdfHelper.displayOrDownloadPdf(bytes, filename);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehicle history report downloaded ($filename)'),
          backgroundColor: const Color(0xFF0F5D55),
        ),
      );
    }
  }

  Widget _buildDocumentStatusCard(String title, String status, String date, {bool isMobile = false}) {
    final isValid = status == 'Valid';
    final accentColor = isValid ? const Color(0xFF10B981) : Colors.grey.shade400;
    final badgeBg = isValid ? const Color(0xFFDCFCE7) : const Color(0xFFF1F3F4);
    final badgeText = isValid ? const Color(0xFF166534) : const Color(0xFF5F6368);

    final card = Container(
      width: isMobile ? 180 : null,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A5568),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeText,
                        ),
                      ),
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          date,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isMobile) return card;
    return Expanded(child: card);
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isActive = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF0D9488) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF0D9488) : const Color(0xFF718096),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF0D9488) : const Color(0xFF718096),
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(Map<String, dynamic> info) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow('Vehicle Number:', info['vehicleNumber']?.toString() ?? 'N/A'),
          _buildInfoRow('Owner Name:', info['ownerName']?.toString() ?? 'N/A'),
          _buildInfoRow('Owner Address:', info['ownerAddress']?.toString() ?? 'N/A'),
          _buildInfoRow('Vehicle Type:', info['vehicleType']?.toString() ?? 'N/A'),
          _buildInfoRow('Vehicle Category:', info['vehicleCategory']?.toString() ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDF2F7))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF718096),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2D3748),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallansTab(List<Map<String, dynamic>> challans) {
    if (challans.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
              SizedBox(height: 12),
              Text(
                'No active challans found.',
                style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Challans',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final double minWidth = 800;
              final double contentWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentWidth,
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2),
                      3: FlexColumnWidth(2),
                    },
                    border: TableBorder.all(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade50),
                        children: const [
                          Padding(padding: EdgeInsets.all(12), child: Text('Offence', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(12), child: Text('Challan Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(12), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(12), child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      ...challans.map((c) => TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(12), child: Text(c['offence'].toString())),
                          Padding(padding: const EdgeInsets.all(12), child: Text('₹${c['amount']}')),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              c['status'].toString(),
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(padding: const EdgeInsets.all(12), child: Text(c['date'].toString())),
                        ],
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehicleHistoryNotifierProvider);
    final notifier = ref.read(vehicleHistoryNotifierProvider.notifier);

    // Apply Sorting
    final sorted = List.from(state.searchResults);
    if (_sortColumn.isNotEmpty) {
      sorted.sort((a, b) {
        final vehicleA = a['vehicle'] as Map<String, dynamic>? ?? {};
        final vehicleB = b['vehicle'] as Map<String, dynamic>? ?? {};
        int cmp = 0;
        if (_sortColumn == 'Time') {
          cmp = (vehicleA['createdTime']?.toString() ?? '').compareTo(vehicleB['createdTime']?.toString() ?? '');
        } else if (_sortColumn == 'VehicleNumber') {
          cmp = (vehicleA['vehicleNumber']?.toString() ?? '').compareTo(vehicleB['vehicleNumber']?.toString() ?? '');
        } else if (_sortColumn == 'VehicleType') {
          cmp = _deriveVehicleType(vehicleA).compareTo(_deriveVehicleType(vehicleB));
        } else if (_sortColumn == 'Camera') {
          cmp = (vehicleA['cameraName']?.toString() ?? '').compareTo(vehicleB['cameraName']?.toString() ?? '');
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    // Apply Pagination
    final totalItems = sorted.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginated = sorted.sublist(startIndex, endIndex > totalItems ? totalItems : endIndex);

    // Derive Search Info & Challans list
    final vehicleInfo = _getVehicleDetails(state.searchText, state);
    final challans = _getChallansList(state);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F6),
      body: LoadingOverlay(
        isLoading: state.isLoading,
        child: RefreshIndicator(
          onRefresh: () async {
            if (_searchController.text.trim().isNotEmpty) {
              await notifier.searchVehicle(_searchController.text.trim());
            } else {
              await notifier.fetchOffenceConfigs();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeaderBanner(
                title: 'Vehicle History & Classification',
                subtitle: 'Government of Telangana Transport Department',
              ),
              const SizedBox(height: 16),
              // Top Search Bar Panel
              Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Vehicle Number',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF333333),
                            ),
                          ),
                          Text(
                            ' *',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = MediaQuery.of(context).size.width < 600;
                          
                          void performVehicleSearch(String rawVal) {
                            final val = rawVal.trim();
                            if (val.isEmpty) return;
                            if (!isValidVehicleNumber(val)) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid vehicle number (e.g., TG04AB1234)'),
                                  backgroundColor: Color(0xFFE11D48),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              return;
                            }
                            setState(() => _currentPage = 1);
                            notifier.searchVehicle(val);
                          }

                          final textField = SizedBox(
                            height: 48,
                            child: TextField(
                              controller: _searchController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [VehicleNumberTextFormatter()],
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Enter vehicle number (e.g., TG04AB1234)',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: Color(0xFF5CCAB8)),
                                ),
                              ),
                              onSubmitted: performVehicleSearch,
                            ),
                          );

                          final searchBtn = SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: () => performVehicleSearch(_searchController.text),
                              icon: const Icon(Icons.search, size: 18, color: Colors.white),
                              label: const Text(
                                'Search',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          );

                          final clearBtn = state.isSearched
                              ? SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      _searchController.clear();
                                      notifier.resetSearch();
                                      setState(() {
                                        _currentPage = 1;
                                        _activeTab = 0;
                                      });
                                    },
                                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF0D9488)),
                                    label: const Text(
                                      'Clear',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D9488),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF0D9488)),
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink();

                          if (isMobile) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                textField,
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: searchBtn),
                                    if (state.isSearched) ...[
                                      const SizedBox(width: 12),
                                      Expanded(child: clearBtn),
                                    ],
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: textField),
                              const SizedBox(width: 16),
                              searchBtn,
                              if (state.isSearched) ...[
                                const SizedBox(width: 12),
                                clearBtn,
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Content Area
              if (!state.isSearched)
                // Initial State: Search for a Vehicle placeholder
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 72, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Search for a Vehicle',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Enter a vehicle number above to view its complete history, violations, and records.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Document Status Card
                Card(
                  elevation: 1,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Document Status',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F3260),
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = MediaQuery.of(context).size.width < 900;
                            final children = [
                              _buildDocumentStatusCard('Registration', vehicleInfo['registration'].toString(), vehicleInfo['registrationDate'].toString(), isMobile: isMobile),
                              _buildDocumentStatusCard('Fitness', vehicleInfo['fitness'].toString(), vehicleInfo['fitnessDate'].toString(), isMobile: isMobile),
                              _buildDocumentStatusCard('Insurance', vehicleInfo['insurance'].toString(), vehicleInfo['insuranceDate'].toString(), isMobile: isMobile),
                              _buildDocumentStatusCard('Road Tax', vehicleInfo['roadTax'].toString(), vehicleInfo['roadTaxDate'].toString(), isMobile: isMobile),
                              _buildDocumentStatusCard('Permit', vehicleInfo['permit'].toString(), vehicleInfo['permitDate'].toString(), isMobile: isMobile),
                            ];

                            if (isMobile) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: children),
                              );
                            }
                            return Row(children: children);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Tabbed Card containing details, challans and detection history
                Card(
                  elevation: 1,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tab Headers
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFAFAFA),
                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTabButton(0, Icons.info_outline, 'Details'),
                              _buildTabButton(1, Icons.receipt_long_outlined, 'Challans (${challans.length})'),
                              _buildTabButton(2, Icons.history, 'Detection Details (${state.searchResults.length})'),
                            ],
                          ),
                        ),
                      ),

                      // Tab View Body
                      if (_activeTab == 0)
                        _buildDetailsTab(vehicleInfo)
                      else if (_activeTab == 1)
                        _buildChallansTab(challans)
                      else if (_activeTab == 2) ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double minWidth = 1100;
                            final double contentWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: contentWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Table Header
                                    Container(
                                      color: const Color(0xFF0F3260),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      child: Row(
                                        children: [
                                          _buildTableHeader('Time', 'Time', flex: 3),
                                          _buildTableHeader('Vehicle', 'VehicleNumber', flex: 2),
                                          _buildTableHeader('Type', 'VehicleType', flex: 2),
                                          _buildTableHeader('Camera', 'Camera', flex: 3),
                                          const Expanded(
                                            flex: 4,
                                            child: Text(
                                              'Violation',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Status',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 1,
                                            child: SizedBox(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Table Rows
                                    paginated.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 60),
                                            child: Center(
                                              child: Text(
                                                'No records found for this vehicle.',
                                                style: TextStyle(color: Colors.black54),
                                              ),
                                            ),
                                          )
                                        : ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: paginated.length,
                                            separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
                                            itemBuilder: (context, index) {
                                              final item = paginated[index] as Map<String, dynamic>? ?? {};
                                              final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
                                              final typeLabel = _deriveVehicleType(vehicle);
                                              final violationText = _deriveViolationText(vehicle, item);
                                              final statusText = _deriveStatus(vehicle, item);

                                              Color typeBadgeBg = const Color(0xFFDBEAFE);
                                              Color typeBadgeText = const Color(0xFF1E40AF);
                                              if (typeLabel == 'TRANSPORT') {
                                                typeBadgeBg = const Color(0xFFDCFCE7);
                                                typeBadgeText = const Color(0xFF166534);
                                              }

                                              Color statusColor = const Color(0xFF7C3AED);
                                              if (statusText == 'COMPLIANT') {
                                                statusColor = const Color(0xFF16A34A);
                                              } else if (statusText == 'NON-COMPLIANT') {
                                                statusColor = const Color(0xFFE11D48);
                                              }

                                              return Container(
                                                color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(_formatDateTime(vehicle['createdTime']?.toString()), style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                                                          const SizedBox(width: 4),
                                                          Flexible(
                                                            child: Text(
                                                              vehicle['vehicleNumber']?.toString() ?? 'N/A',
                                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Align(
                                                        alignment: Alignment.centerLeft,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(color: typeBadgeBg, borderRadius: BorderRadius.circular(4)),
                                                          child: Text(typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeBadgeText)),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        vehicle['cameraName']?.toString() ?? vehicle['cameraID']?.toString() ?? 'N/A',
                                                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 4,
                                                      child: Text(
                                                        violationText,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: violationText == 'ALL CLEAR' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                                                    ),
                                                    Expanded(
                                                       flex: 2,
                                                       child: Align(
                                                         alignment: Alignment.centerRight,
                                                         child: OutlinedButton(
                                                           onPressed: () => _showDetailsDialog(context, item, state.offenceConfigs),
                                                           style: OutlinedButton.styleFrom(
                                                             side: const BorderSide(color: Color(0xFF3B82F6)),
                                                             minimumSize: const Size(60, 30),
                                                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                           ),
                                                           child: const FittedBox(
                                                             fit: BoxFit.scaleDown,
                                                             child: Text('View', maxLines: 1, style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600, fontSize: 12)),
                                                           ),
                                                         ),
                                                       ),
                                                     ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        _buildPaginationControls(totalItems, _itemsPerPage, totalPages),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Download & New Search action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _downloadVehicleReport(context, state),
                      icon: const Icon(Icons.download, color: Colors.white, size: 18),
                      label: const Text('Download Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        notifier.resetSearch();
                        setState(() {
                          _currentPage = 1;
                          _activeTab = 0;
                        });
                      },
                      icon: const Icon(Icons.refresh, color: Color(0xFF0D9488), size: 18),
                      label: const Text('New Search', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0D9488)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildPaginationControls(int totalItems, int itemsPerPage, int totalPages) {
    if (totalPages <= 0) return const SizedBox.shrink();
    final startItem = totalItems > 0 ? ((_currentPage - 1) * itemsPerPage) + 1 : 0;
    final endItem = (_currentPage * itemsPerPage) > totalItems ? totalItems : (_currentPage * itemsPerPage);
    final List<Widget> pageButtons = [];
    for (int i = 1; i <= totalPages; i++) {
      final isCurrent = i == _currentPage;
      pageButtons.add(
        InkWell(
          onTap: () => setState(() => _currentPage = i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFF0D9488) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isCurrent ? const Color(0xFF0D9488) : Colors.grey.shade300),
            ),
            child: Text('$i', style: TextStyle(color: isCurrent ? Colors.white : Colors.black87, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
          ),
        ),
      );
    }
    final bool isMobile = MediaQuery.of(context).size.width < 750;
    final showingText = Text(
      'Showing $startItem-$endItem of $totalItems records',
      style: const TextStyle(fontSize: 12, color: Colors.black54),
      textAlign: isMobile ? TextAlign.center : TextAlign.left,
    );

    final controlsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          child: const Text('‹', style: TextStyle(fontSize: 18, color: Colors.black54)),
        ),
        ...pageButtons,
        TextButton(
          onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          child: const Text('›', style: TextStyle(fontSize: 18, color: Colors.black54)),
        ),
      ],
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: isMobile
            ? Column(
                children: [
                  showingText,
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: controlsRow,
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  showingText,
                  controlsRow,
                ],
              ),
      ),
    );
  }
}
