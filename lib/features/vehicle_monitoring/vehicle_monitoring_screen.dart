import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/uppercase_formatter.dart';
import '../../core/utils/pdf_helper.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../core/widgets/page_header_banner.dart';
import 'vehicle_monitoring_models.dart';
import 'vehicle_monitoring_repository.dart';
import 'previous_vcr_reports_dialog.dart';
import 'widgets/vehicle_image_card.dart';
import 'widgets/owner_information_card.dart';
import 'widgets/offences_section.dart';
import 'widgets/manual_challan_section.dart';
import 'widgets/remarks_section.dart';
import 'widgets/previous_vcr_section.dart';
import 'widgets/vehicle_action_buttons.dart';
import 'widgets/vehicle_header.dart';

final vehicleMonitoringProvider =
    StateNotifierProvider.autoDispose<VehicleMonitoringNotifier, VehicleMonitoringState>((ref) {
      final storage = SecureStorageService();
      final apiClient = ApiClient(storage);
      return VehicleMonitoringNotifier(
        repository: VehicleMonitoringRepository(apiClient: apiClient),
      );
    });

class VehicleMonitoringState {
  VehicleMonitoringState({
    this.detections = const [],
    this.violations = const [],
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.searchText = '',
    this.checkpostFilter = '',
    this.vehicleTypeFilter = '',
    this.selectedDistrict = 'Select All District',
    this.selectedZone = 'Select All Zone',
    this.selectedCamera = 'Select All Camera',
    this.selectedVehicleType = 'Select All Vehicle Type',
    this.selectedViolationType = 'Select All Violation Type',
    this.districts = const ['Select All District'],
    this.zones = const ['Select All Zone'],
    this.cameras = const ['Select All Camera'],
    this.cameraLocationToId = const {},
    this.offenceTypes = const [],
    this.offenceConfigs = const [],
  });

  final List<VehicleDetection> detections;
  final List<dynamic> violations;
  final List<dynamic> notifications;
  final bool isLoading;
  final String? error;
  final String searchText;
  final String checkpostFilter;
  final String vehicleTypeFilter;
  
  final String selectedDistrict;
  final String selectedZone;
  final String selectedCamera;
  final String selectedVehicleType;
  final String selectedViolationType;
  
  final List<String> districts;
  final List<String> zones;
  final List<String> cameras;
  final Map<String, String> cameraLocationToId;
  final List<String> offenceTypes;
  final List<Map<String, dynamic>> offenceConfigs;

  VehicleMonitoringState copyWith({
    List<VehicleDetection>? detections,
    List<dynamic>? violations,
    List<dynamic>? notifications,
    bool? isLoading,
    String? error,
    String? searchText,
    String? checkpostFilter,
    String? vehicleTypeFilter,
    String? selectedDistrict,
    String? selectedZone,
    String? selectedCamera,
    String? selectedVehicleType,
    String? selectedViolationType,
    List<String>? districts,
    List<String>? zones,
    List<String>? cameras,
    Map<String, String>? cameraLocationToId,
    List<String>? offenceTypes,
    List<Map<String, dynamic>>? offenceConfigs,
  }) {
    return VehicleMonitoringState(
      detections: detections ?? this.detections,
      violations: violations ?? this.violations,
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchText: searchText ?? this.searchText,
      checkpostFilter: checkpostFilter ?? this.checkpostFilter,
      vehicleTypeFilter: vehicleTypeFilter ?? this.vehicleTypeFilter,
      selectedDistrict: selectedDistrict ?? this.selectedDistrict,
      selectedZone: selectedZone ?? this.selectedZone,
      selectedCamera: selectedCamera ?? this.selectedCamera,
      selectedVehicleType: selectedVehicleType ?? this.selectedVehicleType,
      selectedViolationType: selectedViolationType ?? this.selectedViolationType,
      districts: districts ?? this.districts,
      zones: zones ?? this.zones,
      cameras: cameras ?? this.cameras,
      cameraLocationToId: cameraLocationToId ?? this.cameraLocationToId,
      offenceTypes: offenceTypes ?? this.offenceTypes,
      offenceConfigs: offenceConfigs ?? this.offenceConfigs,
    );
  }
}

class VehicleMonitoringNotifier extends StateNotifier<VehicleMonitoringState> {
  VehicleMonitoringNotifier({required this.repository})
    : super(VehicleMonitoringState()) {
    fetchDetections();
    fetchViolations();
    loadInitialFilters();
    _startAutoRefresh();
  }

  final VehicleMonitoringRepository repository;
  Timer? _refreshTimer;

  Future<void> fetchDetections() async {
    try {
      final results = await repository.fetchDetections();
      state = state.copyWith(detections: results);
    } catch (e) {
      debugPrint('Error fetching detections: $e');
    }
  }

  Future<void> fetchViolations() async {
    state = state.copyWith(isLoading: true);
    try {
      final selectedCamId = state.cameraLocationToId[state.selectedCamera] ?? state.selectedCamera;
      var results = await repository.fetchViolations(
        violationType: state.selectedViolationType,
        districtName: state.selectedDistrict,
        zoneName: state.selectedZone,
        cameraId: selectedCamId,
        vehicleType: state.selectedVehicleType,
      );

      if (results.isEmpty) {
        final notifs = await repository.fetchNotifications(
          violationType: state.selectedViolationType,
          districtName: state.selectedDistrict,
          zoneName: state.selectedZone,
          cameraId: selectedCamId,
          vehicleType: state.selectedVehicleType,
        );
        if (notifs.isNotEmpty) {
          results = notifs;
        }
      }

      state = state.copyWith(violations: results, isLoading: false);
    } catch (error) {
      state = state.copyWith(error: error.toString(), isLoading: false);
    }
  }

  Future<void> fetchNotifications({
    String? violationType,
    String? districtName,
    String? zoneName,
    String? cameraId,
    String? vehicleType,
    int pageNumber = 1,
    int limit = 100,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await repository.fetchNotifications(
        violationType: violationType,
        districtName: districtName,
        zoneName: zoneName,
        cameraId: cameraId,
        vehicleType: vehicleType,
        pageNumber: pageNumber,
        limit: limit,
      );
      state = state.copyWith(notifications: results, isLoading: false);
    } catch (error) {
      state = state.copyWith(error: error.toString(), isLoading: false);
    }
  }

  Future<void> loadInitialFilters() async {
    try {
      final distList = await repository.fetchDistricts();
      final configs = await repository.fetchOffenceConfigs();
      final offenceList = configs
          .map((item) => item['offence']?.toString())
          .whereType<String>()
          .toList();

      state = state.copyWith(
        districts: distList,
        offenceTypes: offenceList,
        offenceConfigs: configs,
      );
    } catch (e) {
      debugPrint('Error loading initial filters: $e');
    }
  }

  /// Returns the auto-selected zone name when only 1 real zone exists, else null.
  Future<String?> fetchZonesForDistrict(String district) async {
    state = state.copyWith(isLoading: true);
    try {
      final zonesList = await repository.fetchZones(district);
      state = state.copyWith(
        zones: zonesList,
        isLoading: false,
      );
      // Auto-select if only one real zone
      final realZones = zonesList.where((z) => z != 'Select All Zone').toList();
      if (realZones.length == 1) return realZones.first;
      return null;
    } catch (e) {
      state = state.copyWith(
        zones: const ['Select All Zone'],
        isLoading: false,
      );
      return null;
    }
  }

  Future<void> fetchCamerasForZone(String zone) async {
    state = state.copyWith(isLoading: true);
    try {
      final cameraData = await repository.fetchCameras(zone);
      final List<String> camerasList = ['Select All Camera'];
      final Map<String, String> lookup = {};
      for (final item in cameraData) {
        if (item is Map) {
          final id = item['cameraID']?.toString();
          final loc = item['cameraLocation']?.toString();
          if (id != null && loc != null) {
            camerasList.add(loc);
            lookup[loc] = id;
          }
        }
      }
      state = state.copyWith(
        cameras: camerasList,
        cameraLocationToId: lookup,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        cameras: const ['Select All Camera'],
        cameraLocationToId: const {},
        isLoading: false,
      );
    }
  }

  void resetZones() {
    state = state.copyWith(zones: const ['Select All Zone']);
  }

  void resetCameras() {
    state = state.copyWith(
      cameras: const ['Select All Camera'],
      cameraLocationToId: const {},
    );
  }

  void updateSelectedFilters({
    String? district,
    String? zone,
    String? camera,
    String? vehicleType,
    String? violationType,
  }) {
    state = state.copyWith(
      selectedDistrict: district,
      selectedZone: zone,
      selectedCamera: camera,
      selectedVehicleType: vehicleType,
      selectedViolationType: violationType,
    );
    fetchViolations();
  }

  void updateSearch(String value) {
    state = state.copyWith(searchText: value);
    searchVehicleDynamic(value);
  }

  Future<void> searchVehicleDynamic(String query) async {
    final cleanQuery = query.replaceAll(RegExp(r'\s+'), '').trim();
    if (cleanQuery.isEmpty) {
      fetchViolations();
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final results = await repository.searchVehicle(cleanQuery);
      state = state.copyWith(violations: results, isLoading: false);
    } catch (error) {
      state = state.copyWith(error: error.toString(), isLoading: false);
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        fetchViolations();
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

class VehicleMonitoringScreen extends ConsumerStatefulWidget {
  const VehicleMonitoringScreen({super.key, this.isLiveFeed = false});

  final bool isLiveFeed;

  @override
  ConsumerState<VehicleMonitoringScreen> createState() => _VehicleMonitoringScreenState();
}

class _VehicleMonitoringScreenState extends ConsumerState<VehicleMonitoringScreen> {
  int _currentPage = 1;
  static const int _itemsPerPage = 10;
  String _sortColumn = 'Time';
  bool _sortAscending = false;
  final TextEditingController _searchController = TextEditingController();

  // Temporary local state for selected filters (applied on Submit)
  bool _showFilters = false;
  bool _showHistoryFilters = false;
  String _localDistrict = 'Select All District';
  String _localZone = 'Select All Zone';
  String _localCamera = 'Select All Camera';
  String _localVehicleType = 'Select All Vehicle Type';
  String _localViolationType = 'Select All Violation Type';
  String _localTimeRange = 'Select All Time Range';

  @override
  void initState() {
    super.initState();
    if (!widget.isLiveFeed) {
      // History mode: fetch from /notifications API
      Future.microtask(() {
        ref.read(vehicleMonitoringProvider.notifier).fetchNotifications();
      });
    }
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
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildRemarksRichText(Map<String, dynamic> vehicle) {
    if (vehicle['allClear'] == true) {
      return const Text(
        'All Clear',
        style: TextStyle(color: Color(0xFF2FA85C), fontWeight: FontWeight.w500, fontSize: 13),
      );
    }
    final List<TextSpan> spans = [];
    
    final String notifStr = (vehicle['notification'] ?? vehicle['offence'] ?? vehicle['violationType'] ?? '').toString().toLowerCase();
    final bool hasExplicitPucNotif = notifStr.contains('puc');
    final bool hasOtherViolation = vehicle['insurance'] == false ||
        vehicle['roadTax'] == false ||
        vehicle['permit'] == false ||
        vehicle['fitnessCertificate'] == false ||
        vehicle['registration'] == false;

    if (vehicle['pucCertificate'] == false && (hasExplicitPucNotif || !hasOtherViolation)) {
      spans.add(const TextSpan(text: 'Puc Missing from RTA ', style: TextStyle(color: Color(0xFF333333))));
    }
    if (vehicle['insurance'] == false) {
      spans.add(const TextSpan(text: 'insurance ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)));
      spans.add(const TextSpan(text: 'violation ', style: TextStyle(color: Color(0xFF333333))));
    }
    if (vehicle['roadTax'] == false) {
      spans.add(const TextSpan(text: 'road tax ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)));
      spans.add(const TextSpan(text: 'violation ', style: TextStyle(color: Color(0xFF333333))));
    }
    if (vehicle['permit'] == false) {
      spans.add(const TextSpan(text: 'permit ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)));
      spans.add(const TextSpan(text: 'violation ', style: TextStyle(color: Color(0xFF333333))));
    }
    if (vehicle['fitnessCertificate'] == false) {
      spans.add(const TextSpan(text: 'fitness ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)));
      spans.add(const TextSpan(text: 'violation ', style: TextStyle(color: Color(0xFF333333))));
    }
    if (vehicle['registration'] == false) {
      spans.add(const TextSpan(text: 'registration ', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)));
      spans.add(const TextSpan(text: 'violation ', style: TextStyle(color: Color(0xFF333333))));
    }
    
    if (spans.isEmpty) {
      return const Text(
        'All Clear',
        style: TextStyle(color: Color(0xFF2FA85C), fontWeight: FontWeight.w500, fontSize: 13),
      );
    }
    
    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(fontSize: 13, fontFamily: 'Roboto'),
      ),
    );
  }

  void _showNotificationHistoryDetailsDialog(BuildContext context, String vehicleNumber, VehicleMonitoringState state) {
    final cleanVehicleNo = vehicleNumber.replaceAll(RegExp(r'\s+'), '').toUpperCase();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 800,
              maxHeight: 600,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_list_bulleted, size: 18, color: Color(0xFF0F3260)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Notification History Details - $vehicleNumber',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F3260),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Colors.black54),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Table Body using FutureBuilder to fetch real history records from API + local state fallback
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: ref.read(vehicleMonitoringProvider.notifier).repository.fetchVcrHistory(vehicleNumber).then((list) async {
                      if (list.isNotEmpty) return list;

                      // Local fallback from state.violations & state.notifications
                      final List<Map<String, dynamic>> fallback = [];
                      final allSources = [...state.violations, ...state.notifications];
                      for (final item in allSources) {
                        if (item is Map<String, dynamic>) {
                          final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
                          final vNo = (vehicle['vehicleNumber'] ?? item['vehicleNumber'] ?? '').toString().replaceAll(RegExp(r'\s+'), '').toUpperCase();

                          if (cleanVehicleNo.isNotEmpty && (vNo == cleanVehicleNo || vNo.contains(cleanVehicleNo))) {
                            fallback.add(item);
                          }
                        }
                      }
                      return fallback;
                    }),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }

                      final rawRecords = snapshot.data ?? [];

                      // Filter out "All Clear" non-violation entries
                      final violationRecordsOnly = rawRecords.where((item) {
                        final notifText = (item['notification'] ?? item['offence'] ?? item['violationType'] ?? item['remarks'] ?? '').toString().trim().toLowerCase();
                        return notifText.isNotEmpty && notifText != 'all clear' && notifText != 'all_clear';
                      }).toList();

                      if (violationRecordsOnly.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No violation notifications found for $vehicleNumber',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Format history records for display
                      final historyRecords = violationRecordsOnly.map((item) {
                        final id = (item['id'] ?? item['notificationId'] ?? item['violationId'] ?? item['vcrNo'] ?? item['challanNo'] ?? '').toString();
                        
                        // Parse notification text (e.g. "INSURANCE_CERTIFICATE expired on 2025-09-27")
                        String notification = (item['notification'] ?? item['offence'] ?? item['violationType'] ?? item['remarks'] ?? item['offenceName'] ?? '').toString();
                        if (notification.isEmpty || notification == 'N/A') {
                          notification = 'Violation Record';
                        }

                        // Parse amount with commas formatting (e.g. 650.00 or 0.00)
                        final rawAmt = item['totalFineAmount'] ?? item['fineAmount'] ?? item['amount'] ?? item['challanAmount'] ?? 0;
                        final double amtVal = rawAmt is num ? rawAmt.toDouble() : (double.tryParse(rawAmt.toString()) ?? 0.0);
                        final String amountStr = NumberFormat('#,##0.00').format(amtVal);

                        // Parse date & time
                        final rawDate = item['createdAt'] ?? item['createdTime'] ?? item['dateTime'] ?? item['timestamp'] ?? item['date'];
                        final dateTimeStr = _formatDateTime(rawDate?.toString());

                        // Parse status badge (e.g. "GRACE PERIOD", "DUPLICATE", "UNPAID", "")
                        String statusStr = (item['status'] ?? item['paymentStatus'] ?? '').toString().trim();
                        if (statusStr.isEmpty || statusStr == 'null') {
                          final offStatuses = item['offenceStatuses'];
                          if (offStatuses != null && offStatuses is String && offStatuses.contains(':')) {
                            if (offStatuses.contains('GRACE PERIOD') || offStatuses.contains('GRACE_PERIOD')) {
                              statusStr = 'GRACE PERIOD';
                            } else if (offStatuses.contains('UNPAID')) {
                              statusStr = 'UNPAID';
                            } else if (offStatuses.contains('DUPLICATE')) {
                              statusStr = 'DUPLICATE';
                            } else if (offStatuses.contains('PAID')) {
                              statusStr = 'PAID';
                            }
                          }
                        }
                        if (statusStr == 'null') statusStr = '';

                        return {
                          'id': id.isNotEmpty ? id : 'N/A',
                          'notification': notification,
                          'amount': amountStr,
                          'dateTime': dateTimeStr,
                          'status': statusStr,
                        };
                      }).toList();

                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 760),
                            child: Table(
                              border: TableBorder.all(color: Colors.grey.shade300, width: 0.8),
                              columnWidths: const {
                                0: FlexColumnWidth(1.2), // ID
                                1: FlexColumnWidth(4.2), // Notification
                                2: FlexColumnWidth(1.5), // Amount
                                3: FlexColumnWidth(2.3), // Date & Time
                                4: FlexColumnWidth(1.8), // Status
                              },
                              children: [
                                // Dark Blue Table Header matching Image 2
                                const TableRow(
                                  decoration: BoxDecoration(color: Color(0xFF1E3A8A)),
                                  children: [
                                    Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Text('ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Text('Notification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Text('Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Text('Date & Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                  ],
                                ),

                                // Table Data Rows matching Image 2
                                ...historyRecords.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final record = entry.value;
                                  final status = record['status'] ?? '';
                                  final statusUpper = status.toUpperCase();

                                  Color? badgeBg;
                                  Color? badgeText;
                                  if (statusUpper == 'GRACE PERIOD') {
                                    badgeBg = const Color(0xFFF59E0B);
                                    badgeText = Colors.black87;
                                  } else if (statusUpper == 'DUPLICATE') {
                                    badgeBg = const Color(0xFF10B981);
                                    badgeText = Colors.white;
                                  } else if (statusUpper == 'UNPAID') {
                                    badgeBg = const Color(0xFFEF4444);
                                    badgeText = Colors.white;
                                  } else if (statusUpper == 'PAID' || statusUpper == 'COLLECTED') {
                                    badgeBg = const Color(0xFF28A745);
                                    badgeText = Colors.white;
                                  } else if (statusUpper.isNotEmpty) {
                                    badgeBg = const Color(0xFFF59E0B);
                                    badgeText = Colors.black87;
                                  }

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: idx % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                    ),
                                    children: [
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Text(record['id']!, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Text(record['notification']!, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Text(record['amount']!, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Text(record['dateTime']!, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        child: statusUpper.isNotEmpty && badgeBg != null
                                            ? Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: badgeBg,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: TextStyle(
                                                      color: badgeText,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> item, VehicleMonitoringState state) {
    final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
    final vehicleNumber = vehicle['vehicleNumber']?.toString() ?? 'N/A';
    final vehicleType = vehicle['vehicleType']?.toString() ?? 'N/A';
    final vehicleCategory = vehicle['vehicleCategory']?.toString() ?? 'N/A';
    final cameraName = vehicle['cameraName']?.toString() ?? vehicle['cameraID']?.toString() ?? 'N/A';
    final cameraID = vehicle['cameraID']?.toString() ?? '';
    final detectedAt = _formatDateTime(vehicle['imageDetectionTime']?.toString());
    final String rawImgUrl = vehicle['imageUrl']?.toString() ??
        vehicle['vehicleImage']?.toString() ??
        vehicle['image']?.toString() ??
        item['imageUrl']?.toString() ??
        item['vehicleImage']?.toString() ??
        item['image']?.toString() ??
        item['snapshot']?.toString() ??
        item['cropImage']?.toString() ??
        item['cameraImage']?.toString() ??
        '';
    final String imgUrl = rawImgUrl.trim();

    // Available offences for selection (LIST OF OFFENCES) dynamically resolved from API offence-config
    final List<Map<String, dynamic>> sourceConfigs = state.offenceConfigs;

    final List<Map<String, dynamic>> availableOffences = sourceConfigs.map((cfg) {
      final name = (cfg['offence'] ?? cfg['offenceName'] ?? cfg['name'] ?? '').toString();
      final rawAmt = cfg['challanAmount'] ?? cfg['amount'] ?? cfg['fineAmount'] ?? cfg['penalty'] ?? 0.0;
      final double amount = rawAmt is num ? rawAmt.toDouble() : (double.tryParse(rawAmt.toString()) ?? 0.0);
      return {
        'name': name,
        'amount': amount,
      };
    }).where((e) => (e['name'] as String).isNotEmpty).toList();

    final Set<Map<String, dynamic>> selectedOffences = {};
    
    // Check if vehicle is explicitly marked All Clear
    final bool isAllClear = vehicle['allClear'] == true ||
        (item['notification']?.toString().toLowerCase() == 'all clear') ||
        (item['notification']?.toString().toLowerCase() == 'all_clear');

    if (!isAllClear) {
      // Extract notification text strictly from explicit payload notification/offence fields (NOT from auto-generated remarks)
      final String itemNotifStr = (
        item['notification'] ??
        item['offence'] ??
        item['offenceName'] ??
        item['violationType'] ??
        item['violations'] ??
        ''
      ).toString().trim();
      final String notifLower = itemNotifStr.toLowerCase();

      // Check and pre-select offences dynamically
      bool checkOffenceStatus(String name) {
        final nameLower = name.toLowerCase();
        final cleanName = nameLower.replaceAll('_', ' ').replaceAll('certificate', '').trim();
        
        // 1. If explicit notification/offence text is present on the item record, match against it
        if (notifLower.isNotEmpty &&
            notifLower != 'n/a' &&
            notifLower != 'all clear' &&
            notifLower != 'all_clear' &&
            !notifLower.contains('details not found')) {
          if (notifLower.contains(nameLower) || notifLower.contains(cleanName)) {
            return true;
          }
          if ((nameLower.contains('road_tax') || nameLower.contains('roadtax')) && (notifLower.contains('tax') || notifLower.contains('road'))) {
            return true;
          }
          if (nameLower.contains('permit') && notifLower.contains('permit')) {
            return true;
          }
          if (nameLower.contains('fitness') && notifLower.contains('fitness')) {
            return true;
          }
          if (nameLower.contains('puc') && notifLower.contains('puc')) {
            return true;
          }
          if (nameLower.contains('insurance') && notifLower.contains('insurance')) {
            return true;
          }
          if (nameLower.contains('registration') && notifLower.contains('registration')) {
            return true;
          }
          // Explicit notification text was provided and did not match this offence
          return false;
        }

        // 2. Fallback: If no explicit notification text on item, check vehicle document status flags
        if (nameLower.contains('road_tax') || nameLower.contains('roadtax')) {
          return vehicle['roadTax'] == false;
        }
        if (nameLower.contains('permit')) {
          return vehicle['permit'] == false;
        }
        if (nameLower.contains('fitness')) {
          return vehicle['fitnessCertificate'] == false;
        }
        if (nameLower.contains('insurance')) {
          return vehicle['insurance'] == false;
        }
        if (nameLower.contains('registration')) {
          return vehicle['registration'] == false;
        }
        if (nameLower.contains('puc')) {
          final bool hasOtherDocumentViolation = vehicle['insurance'] == false ||
              vehicle['roadTax'] == false ||
              vehicle['permit'] == false ||
              vehicle['fitnessCertificate'] == false ||
              vehicle['registration'] == false;
          // Only pre-select PUC as fallback if PUC is false AND no other document violation is active
          return vehicle['pucCertificate'] == false && !hasOtherDocumentViolation;
        }

        return false;
      }

      for (final offence in availableOffences) {
        if (checkOffenceStatus(offence['name'] as String)) {
          selectedOffences.add(offence);
        }
      }
    }

    final List<Map<String, dynamic>> customOffences = [];
    String? addRowError;
    final TextEditingController customNameCtrl = TextEditingController();
    final TextEditingController customAmountCtrl = TextEditingController();
    final TextEditingController remarksCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double totalChallanAmount = selectedOffences.fold(0.0, (sum, o) => sum + (o['amount'] as num? ?? 0.0).toDouble());

            return Dialog(
              backgroundColor: const Color(0xFFF3F6F6),
              insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300, maxHeight: 920),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      // Vehicle Header
                      VehicleHeader(
                        vehicleNumber: vehicleNumber,
                        vehicleCategory: vehicleCategory,
                        vehicleType: vehicleType,
                        cameraName: cameraName,
                        detectedAt: detectedAt,
                        onClose: () {
                          customNameCtrl.dispose();
                          customAmountCtrl.dispose();
                          remarksCtrl.dispose();
                          Navigator.of(context).pop();
                        },
                      ),

                      // Scrollable Body
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth >= 750;
                                  
    // Left side components: Vehicle Image + Owner Information
                                  final leftColumn = Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Image Card
                                      VehicleImageCard(
                                        imageUrl: imgUrl,
                                        cameraId: cameraID,
                                        location: cameraName,
                                      ),
                                      const SizedBox(height: 8),
                                       // Owner Information Card
                                       OwnerInformationCard(
                                         ownerName: vehicle['ownerName']?.toString(),
                                         phone: vehicle['ownerMobileNo']?.toString(),
                                         address: vehicle['ownerAddress']?.toString(),
                                         district: vehicle['districtName']?.toString(),
                                         color: '-',
                                       ),
                                    ],
                                  );

                                  // Right side components: Offences / Irregularities + Manual Challan (Single Card)
                                  final rightColumn = Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      OffencesSection(
                                        availableOffences: availableOffences,
                                        selectedOffences: selectedOffences,
                                        onOffenceSelected: (offence) {
                                          setDialogState(() {
                                            selectedOffences.add(offence);
                                          });
                                        },
                                        onOffenceRemoved: (offence) {
                                          setDialogState(() {
                                            selectedOffences.remove(offence);
                                          });
                                        },
                                        manualChallanSection: ManualChallanSection(
                                          customNameCtrl: customNameCtrl,
                                          customAmountCtrl: customAmountCtrl,
                                          customOffences: customOffences,
                                          totalChallanAmount: totalChallanAmount,
                                          addRowError: addRowError,
                                          onAddOffence: () {
                                            final name = customNameCtrl.text.trim();
                                            final amtText = customAmountCtrl.text.trim();
                                            final amt = double.tryParse(amtText) ?? 0.0;
                                            if (name.isNotEmpty) {
                                              setDialogState(() {
                                                final newOffence = <String, dynamic>{'name': name, 'amount': amt};
                                                customOffences.add(newOffence);
                                                selectedOffences.add(newOffence);
                                                customNameCtrl.clear();
                                                customAmountCtrl.clear();
                                                addRowError = null;
                                              });
                                            } else {
                                              setDialogState(() {
                                                addRowError = 'Please enter an offence name before adding';
                                              });
                                            }
                                          },
                                          onRemoveOffence: (idx) {
                                            setDialogState(() {
                                              final removed = customOffences.removeAt(idx);
                                              selectedOffences.removeWhere((item) => item['name'] == removed['name']);
                                            });
                                          },
                                          onClearError: () {
                                            setDialogState(() {
                                              addRowError = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  );

                                  if (isWide) {
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 4, child: leftColumn),
                                        const SizedBox(width: 8),
                                        Expanded(flex: 5, child: rightColumn),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      children: [
                                        leftColumn,
                                        const SizedBox(height: 8),
                                        rightColumn,
                                      ],
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 8),

                              // Combined Card: Remarks + Previous VCR Challans + Action Buttons
                              Card(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RemarksSection(
                                        controller: remarksCtrl,
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),

                                      PreviousVcrSection(
                                        vehicleNumber: vehicleNumber,
                                        state: state,
                                        ref: ref,
                                        item: item,
                                        selectedOffences: selectedOffences.toList(),
                                        onViewHistory: (vNo) {
                                          _showNotificationHistoryDetailsDialog(context, vNo, state);
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),

                                      VehicleActionButtons(
                                        onPreviousVcrReports: () => PreviousVcrReportsDialog.show(context, vehicleNumber),
                                        onCollect: () {
                                          _showDriverDetailsAndSignatureDialog(
                                            context,
                                            actionType: 'Collect Fine',
                                            item: item,
                                            selectedOffences: selectedOffences.toList(),
                                            customOffences: customOffences,
                                            totalChallanAmount: totalChallanAmount,
                                            remarksText: remarksCtrl.text,
                                            ref: ref,
                                          );
                                        },
                                        onRaiseChallan: () async {
                                          final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
                                          final vehicleNumber = (vehicle['vehicleNumber'] ?? vehicle['registrationNumber'] ?? item['vehicleNumber'] ?? '').toString();
                                          final offenceNames = [
                                            ...selectedOffences.map((o) => o['name']?.toString() ?? o['offence']?.toString() ?? ''),
                                            ...customOffences.map((o) => o['name']?.toString() ?? ''),
                                          ].where((s) => s.isNotEmpty).join(',');

                                          final repo = VehicleMonitoringRepository(apiClient: ApiClient(SecureStorageService()));
                                          final dupRes = await repo.checkDuplicateVcr(
                                            registrationNumber: vehicleNumber,
                                            offences: offenceNames,
                                          );

                                          if (dupRes['isDuplicate'] == true) {
                                            if (context.mounted) {
                                              _showPreviousVcrFoundDialog(
                                                context,
                                                duplicateData: dupRes,
                                                vehicleNumber: vehicleNumber,
                                                offenceNames: offenceNames,
                                                item: item,
                                                totalChallanAmount: totalChallanAmount,
                                                remarksText: remarksCtrl.text,
                                                ref: ref,
                                              );
                                            }
                                          } else {
                                            if (context.mounted) {
                                              _executeGenerateChallan(
                                                context,
                                                actionType: 'Raise Challan',
                                                item: item,
                                                offenceNames: offenceNames,
                                                totalChallanAmount: totalChallanAmount,
                                                remarksText: remarksCtrl.text,
                                                ref: ref,
                                              );
                                            }
                                          }
                                        },
                                        onSeizeVehicle: () {
                                          _showDriverDetailsAndSignatureDialog(
                                            context,
                                            actionType: 'Seize Vehicle',
                                            item: item,
                                            selectedOffences: selectedOffences.toList(),
                                            customOffences: customOffences,
                                            totalChallanAmount: totalChallanAmount,
                                            remarksText: remarksCtrl.text,
                                            ref: ref,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                             ],
                           ),
                         ),
                       ),
                     ],
                   ),
                ),
              ),
            );
          },
        );
      },
    );
  }




  Widget _buildDropdownField({
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final String? safeValue = (value != null && options.contains(value))
        ? value
        : (options.isNotEmpty ? options.first : null);

    return DropdownButtonFormField<String>(
      isExpanded: true,
      isDense: true,
      initialValue: safeValue,
      hint: Text(hint),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      items: options
          .map(
            (option) {
              String displayLabel = option;
              if (option == 'Select All District') displayLabel = 'Select District';
              if (option == 'Select All Zone') displayLabel = 'Select Zone';
              if (option == 'Select All Camera') displayLabel = 'Select Camera';
              return DropdownMenuItem<String>(
                value: option,
                child: Text(displayLabel, style: const TextStyle(fontSize: 13)),
              );
            },
          )
          .toList(),
      onChanged: onChanged,
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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSorted
                  ? (_sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
                  : Icons.unfold_more,
              color: isSorted ? Colors.white : Colors.white60,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLiveFeed) {
      return _buildHistoryView();
    }

    final state = ref.watch(vehicleMonitoringProvider);
    final notifier = ref.read(vehicleMonitoringProvider.notifier);

    // Extract dynamic vehicle types
    final List<String> vehicleTypes = ['Select All Vehicle Type', 'Non-Transport', 'Transport'];

    final List<String> violationTypes = [
      'Select All Violation Type',
      ...state.offenceTypes,
    ];

    // Filter
    final sourceItems = state.violations.isNotEmpty ? state.violations : state.notifications;
    final filtered = sourceItems.where((item) {
      final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
      
      // District Filter
      bool matchesDistrict = state.selectedDistrict == 'Select All District' || state.selectedDistrict.isEmpty;
      if (!matchesDistrict) {
        final selDist = state.selectedDistrict.toLowerCase().trim();
        final itemDists = [
          vehicle['districtName']?.toString(),
          vehicle['district']?.toString(),
          vehicle['district_name']?.toString(),
          item['districtName']?.toString(),
          item['district']?.toString(),
          item['district_name']?.toString(),
        ].whereType<String>().map((s) => s.toLowerCase().trim()).toList();

        if (itemDists.isEmpty) {
          matchesDistrict = true;
        } else {
          matchesDistrict = itemDists.any((d) => d == selDist || d.contains(selDist) || selDist.contains(d));
        }
      }
          
      // Zone Filter
      bool matchesZone = state.selectedZone == 'Select All Zone' || state.selectedZone.isEmpty;
      if (!matchesZone) {
        final selZone = state.selectedZone.toLowerCase().trim();
        final itemZones = [
          vehicle['zoneName']?.toString(),
          vehicle['officeName']?.toString(),
          vehicle['zone']?.toString(),
          vehicle['office']?.toString(),
          item['zoneName']?.toString(),
          item['officeName']?.toString(),
          item['zone']?.toString(),
          item['office']?.toString(),
        ].whereType<String>().map((s) => s.toLowerCase().trim()).toList();

        if (itemZones.isEmpty) {
          matchesZone = true;
        } else {
          matchesZone = itemZones.any((z) => z == selZone || z.contains(selZone) || selZone.contains(z));
        }
      }
          
      // Camera Filter
      final selectedCameraId = state.cameraLocationToId[state.selectedCamera];
      final matchesCamera = state.selectedCamera == 'Select All Camera' ||
          vehicle['cameraID'] == selectedCameraId;
          
      // Vehicle Type Filter
      final matchesVehicleType = state.selectedVehicleType == 'Select All Vehicle Type' ||
          vehicle['vehicleType'] == state.selectedVehicleType;
          
      // Dynamic Violation Type Filter
      bool matchesViolation = true;
      if (state.selectedViolationType != 'Select All Violation Type') {
        final sel = state.selectedViolationType;
        final selLower = sel.toLowerCase();

        final String remarksLower = (item['remarks']?.toString() ?? '').toLowerCase();
        final String notificationLower = (item['notification']?.toString() ?? '').toLowerCase();
        final String offenceLower = (item['offence']?.toString() ?? vehicle['offence']?.toString() ?? '').toLowerCase();
        final cleanSel = selLower.replaceAll('_', ' ').replaceAll('certificate', '').trim();

        bool hasTextMatch = remarksLower.contains(cleanSel) ||
            notificationLower.contains(cleanSel) ||
            offenceLower.contains(cleanSel) ||
            offenceLower.contains(selLower) ||
            remarksLower.contains(selLower);

        bool hasFlagMatch = false;
        if (sel == 'Puc Missing' || selLower.contains('puc')) {
          hasFlagMatch = vehicle['pucCertificate'] == false;
        } else if (sel == 'Insurance Violation' || selLower.contains('insurance')) {
          hasFlagMatch = vehicle['insurance'] == false;
        } else if (sel == 'Road Tax Violation' || selLower.contains('road_tax') || selLower.contains('roadtax')) {
          hasFlagMatch = vehicle['roadTax'] == false;
        } else if (sel == 'Permit Violation' || selLower.contains('permit')) {
          hasFlagMatch = vehicle['permit'] == false;
        } else if (sel == 'Fitness Violation' || selLower.contains('fitness')) {
          hasFlagMatch = vehicle['fitnessCertificate'] == false;
        } else if (sel == 'Registration Violation' || selLower.contains('registration')) {
          hasFlagMatch = vehicle['registration'] == false;
        } else if (sel == 'All Clear') {
          hasFlagMatch = vehicle['allClear'] == true;
        }

        matchesViolation = hasTextMatch || hasFlagMatch;
      }
      
      // Search Box Filter (supports raw text & space-cleaned registration numbers)
      final searchTextVal = _searchController.text.trim().toLowerCase();
      final stateSearchVal = state.searchText.trim().toLowerCase();
      final queryText = searchTextVal.isNotEmpty ? searchTextVal : stateSearchVal;
      final cleanQuery = queryText.replaceAll(RegExp(r'[\s\-]+'), '');

      bool matchesSearch = queryText.isEmpty;
      if (!matchesSearch) {
        final rawPlate = (vehicle['vehicleNumber'] ?? vehicle['vehicleNo'] ?? vehicle['registrationNumber'] ?? item['vehicleNumber'] ?? item['vehicleNo'] ?? item['registrationNumber'] ?? '').toString().toLowerCase();
        final cleanPlate = rawPlate.replaceAll(RegExp(r'[\s\-]+'), '');

        final plateMatch = rawPlate.contains(queryText) || (cleanQuery.isNotEmpty && cleanPlate.contains(cleanQuery));
        final cameraMatch = (vehicle['cameraName'] ?? item['cameraName'] ?? '').toString().toLowerCase().contains(queryText);
        final remarksMatch = (item['remarks'] ?? item['notification'] ?? '').toString().toLowerCase().contains(queryText);
        final typeMatch = (vehicle['vehicleType'] ?? item['vehicleType'] ?? '').toString().toLowerCase().contains(queryText);
        final idMatch = (item['id'] ?? item['notificationId'] ?? '').toString().toLowerCase().contains(queryText);

        matchesSearch = plateMatch || cameraMatch || remarksMatch || typeMatch || idMatch;
      }
          
      return matchesDistrict && matchesZone && matchesCamera && matchesVehicleType && matchesViolation && matchesSearch;
    }).toList();

    // Sort the list
    if (_sortColumn.isNotEmpty) {
      filtered.sort((a, b) {
        final vehicleA = a['vehicle'] as Map<String, dynamic>? ?? {};
        final vehicleB = b['vehicle'] as Map<String, dynamic>? ?? {};
        
        int cmp = 0;
        if (_sortColumn == 'Time') {
          final timeA = vehicleA['imageDetectionTime']?.toString() ?? '';
          final timeB = vehicleB['imageDetectionTime']?.toString() ?? '';
          cmp = timeA.compareTo(timeB);
        } else if (_sortColumn == 'VehicleNumber') {
          final plateA = vehicleA['vehicleNumber']?.toString() ?? '';
          final plateB = vehicleB['vehicleNumber']?.toString() ?? '';
          cmp = plateA.compareTo(plateB);
        } else if (_sortColumn == 'VehicleType') {
          final typeA = vehicleA['vehicleCategory'] == 'T' ? 'Transport' : 'Non-Transport';
          final typeB = vehicleB['vehicleCategory'] == 'T' ? 'Transport' : 'Non-Transport';
          cmp = typeA.compareTo(typeB);
        } else if (_sortColumn == 'Camera') {
          final camA = vehicleA['cameraName']?.toString() ?? '';
          final camB = vehicleB['cameraName']?.toString() ?? '';
          cmp = camA.compareTo(camB);
        }
        
        return _sortAscending ? cmp : -cmp;
      });
    }

    // Pagination slice
    final totalItems = filtered.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginated = filtered.sublist(
      startIndex,
      endIndex > totalItems ? totalItems : endIndex,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F6),
      body: LoadingOverlay(
        isLoading: state.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: PageHeaderBanner(
                      title: widget.isLiveFeed ? 'Live Vehicle Feed' : 'Vehicle Monitoring & History',
                      subtitle: widget.isLiveFeed ? 'Real-time Automatic Number Plate Recognition Stream' : 'Government of Telangana Transport Department',
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      final newShow = !_showFilters;
                      setState(() => _showFilters = newShow);
                      notifier.fetchViolations();
                    },
                    icon: Icon(
                      _showFilters ? Icons.filter_alt_off : Icons.filter_alt,
                      size: 18,
                      color: const Color(0xFF0D9488),
                    ),
                    label: Text(
                      _showFilters ? 'Hide Filter' : 'Filter',
                      style: const TextStyle(
                        color: Color(0xFF0D9488),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              if (_showFilters) ...[
                const SizedBox(height: 12),
                // Top Cascading Filters Container
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final districtDropdown = _buildDropdownField(
                        hint: 'Select District',
                        value: _localDistrict,
                        options: state.districts,
                        onChanged: (value) async {
                          setState(() {
                            _localDistrict = value ?? 'Select All District';
                            _localZone = 'Select All Zone';
                            _localCamera = 'Select All Camera';
                          });
                          if (value != null && value != 'Select All District') {
                            final autoZone = await notifier.fetchZonesForDistrict(value);
                            if (autoZone != null && mounted) {
                              setState(() => _localZone = autoZone);
                              notifier.fetchCamerasForZone(autoZone);
                            }
                          } else {
                            notifier.resetZones();
                          }
                          notifier.resetCameras();
                        },
                      );

                      final zoneDropdown = _buildDropdownField(
                        hint: 'Select Zone',
                        value: _localZone,
                        options: state.zones,
                        onChanged: (value) {
                          setState(() {
                            _localZone = value ?? 'Select All Zone';
                            _localCamera = 'Select All Camera';
                          });
                          if (value != null && value != 'Select All Zone') {
                            notifier.fetchCamerasForZone(value);
                          } else {
                            notifier.resetCameras();
                          }
                        },
                      );

                      final cameraDropdown = _buildDropdownField(
                        hint: 'Select Camera',
                        value: _localCamera,
                        options: state.cameras,
                        onChanged: (value) => setState(() => _localCamera = value ?? 'Select All Camera'),
                      );

                      final vehicleTypeDropdown = _buildDropdownField(
                        hint: 'Select Vehicle Type',
                        value: _localVehicleType,
                        options: vehicleTypes,
                        onChanged: (value) => setState(() => _localVehicleType = value ?? 'Select All Vehicle Type'),
                      );

                      final violationTypeDropdown = _buildDropdownField(
                        hint: 'Select Violation Type',
                        value: _localViolationType,
                        options: violationTypes,
                        onChanged: (value) => setState(() => _localViolationType = value ?? 'Select All Violation Type'),
                      );

                      final submitButton = FilledButton(
                        onPressed: () {
                          notifier.updateSelectedFilters(
                            district: _localDistrict,
                            zone: _localZone,
                            camera: _localCamera,
                            vehicleType: _localVehicleType,
                            violationType: _localViolationType,
                          );
                          setState(() {
                            _currentPage = 1;
                          });
                          notifier.fetchViolations();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: districtDropdown),
                                const SizedBox(width: 12),
                                Expanded(child: zoneDropdown),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: cameraDropdown),
                                const SizedBox(width: 12),
                                Expanded(child: vehicleTypeDropdown),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: violationTypeDropdown),
                                const SizedBox(width: 12),
                                Expanded(child: SizedBox(height: 42, child: submitButton)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Sub-header Live indicator + Search Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    // Live Indicator badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.radio_button_checked, size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Live',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        decoration: InputDecoration(
                          hintText: 'Search anything...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    notifier.updateSearch('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (val) {
                          final upper = val.toUpperCase();
                          if (val != upper) {
                            _searchController.value = TextEditingValue(
                              text: upper,
                              selection: TextSelection.collapsed(offset: upper.length),
                            );
                          }
                          notifier.updateSearch(upper);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Table list in white Card
              LayoutBuilder(
                builder: (context, constraints) {
                  final double minWidth = 1100;
                  final double contentWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: contentWidth,
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Navy Table Header
                            Container(
                              color: const Color(0xFF0F3260),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  const SizedBox(width: 24), // Car Icon spacer
                                  _buildTableHeader('Time', 'Time', flex: 2),
                                  _buildTableHeader('Vehicle Number', 'VehicleNumber', flex: 2),
                                  _buildTableHeader('Vehicle Type', 'VehicleType', flex: 2),
                                  _buildTableHeader('Camera', 'Camera', flex: 3),
                                  const Expanded(
                                    flex: 5,
                                    child: Text(
                                      'Remarks',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Status',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 1,
                                    child: Text(
                                      '',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Table rows
                            paginated.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 40),
                                    child: Center(
                                      child: Text(
                                        'No vehicle violations found matching the filters.',
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
                                      final item = paginated[index];
                                      final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
                                      final isCompliant = vehicle['allClear'] == true;
                                      final vehicleTypeLabel = vehicle['vehicleCategory'] == 'T' ? 'Transport' : 'Non-Transport';

                                      return Container(
                                        color: index % 2 == 0 ? Colors.white : const Color(0xFFF7FAFA),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.directions_car,
                                              color: Color(0xFF555555),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatDateTime(vehicle['imageDetectionTime']?.toString()),
                                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                vehicle['vehicleNumber']?.toString() ?? 'N/A',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                vehicleTypeLabel,
                                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                vehicle['cameraName']?.toString() ?? vehicle['cameraID']?.toString() ?? 'N/A',
                                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 5,
                                              child: _buildRemarksRichText(vehicle),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                isCompliant ? 'Compliant' : 'Non-Compliant',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: isCompliant ? const Color(0xFF2FA85C) : const Color(0xFFE289A3),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: OutlinedButton(
                                                  onPressed: () => _showDetailsDialog(context, item, state),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFF0D9488)),
                                                    minimumSize: const Size(60, 30),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  ),
                                                  child: const FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      'View',
                                                      maxLines: 1,
                                                      style: TextStyle(
                                                        color: Color(0xFF0D9488),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12.5,
                                                      ),
                                                    ),
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
                    ),
                  );
                },
              ),

              // Pagination
              _buildPaginationControls(totalItems, _itemsPerPage),
            ],
          ),
        ),
      ),
    );
  }

  String _historyFormatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${DateFormat('HH:mm:ss').format(dt)} ${DateFormat('dd/MM/yyyy').format(dt)}';
    } catch (_) {
      return dateStr;
    }
  }

  String _deriveViolationText(Map<String, dynamic> vehicle, Map<String, dynamic> item) {
    final notification = (item['notification'] ?? item['offence'] ?? item['offenceName'] ?? item['violationType'] ?? '').toString().trim();
    final remarks = (item['remarks'] ?? '').toString().trim();
    
    if (notification.toLowerCase().contains('details not found') ||
        remarks.toLowerCase().contains('details not found')) {
      return 'DETAILS NOT FOUND.';
    }

    if (notification.isNotEmpty &&
        notification != 'N/A' &&
        notification != 'ALL CLEAR' &&
        notification != 'all_clear') {
      return notification.toUpperCase();
    }

    final List<String> violations = [];
    if (vehicle['insurance'] == false) violations.add('INSURANCE VIOLATION');
    if (vehicle['roadTax'] == false) violations.add('ROAD TAX VIOLATION');
    if (vehicle['permit'] == false) violations.add('PERMIT VIOLATION');
    if (vehicle['fitnessCertificate'] == false) violations.add('FITNESS VIOLATION');
    if (vehicle['registration'] == false) violations.add('REGISTRATION VIOLATION');

    final bool hasExplicitPuc = notification.toLowerCase().contains('puc') || remarks.toLowerCase().contains('puc');
    if (vehicle['pucCertificate'] == false && (hasExplicitPuc || violations.isEmpty)) {
      violations.add('PUC MISSING FROM RTA IN...');
    }
    
    if (violations.isEmpty) {
      if (vehicle['allClear'] == true) return 'ALL CLEAR';
      return remarks.isNotEmpty ? remarks.toUpperCase() : 'ALL CLEAR';
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

  String _deriveVehicleType(Map<String, dynamic> vehicle) {
    final cat = vehicle['vehicleCategory']?.toString() ?? '';
    final vt = vehicle['vehicleType']?.toString() ?? '';
    if (cat == 'T' || vt.toLowerCase().contains('transport')) return 'TRANSPORT';
    if (cat == 'NT' || vt.toLowerCase().contains('non')) return 'NON-TRANSPORT';
    if (vt.toLowerCase().contains('commercial')) return 'COMMERCIAL';
    // Fallback: if no vehicleType info, derive from violations
    if (vehicle['permit'] == false) return 'COMMERCIAL';
    return 'NON-TRANSPORT';
  }

  Widget _buildHistoryView() {
    final state = ref.watch(vehicleMonitoringProvider);
    final notifier = ref.read(vehicleMonitoringProvider.notifier);

    final dataSource = state.notifications;

    // Client-side search & dropdown filters
    final searchLower = _searchController.text.toLowerCase();
    final filtered = dataSource.where((item) {
      final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};

      // District Filter
      bool matchesDistrict = _localDistrict == 'Select All District' || _localDistrict.isEmpty;
      if (!matchesDistrict) {
        final selDist = _localDistrict.toLowerCase().trim();
        final itemDists = [
          vehicle['districtName']?.toString(),
          vehicle['district']?.toString(),
          vehicle['district_name']?.toString(),
          item['districtName']?.toString(),
          item['district']?.toString(),
          item['district_name']?.toString(),
        ].whereType<String>().map((s) => s.toLowerCase().trim()).toList();

        if (itemDists.isEmpty) {
          matchesDistrict = true;
        } else {
          matchesDistrict = itemDists.any((d) => d == selDist || d.contains(selDist) || selDist.contains(d));
        }
      }

      // Zone Filter
      bool matchesZone = _localZone == 'Select All Zone' || _localZone.isEmpty;
      if (!matchesZone) {
        final selZone = _localZone.toLowerCase().trim();
        final itemZones = [
          vehicle['zoneName']?.toString(),
          vehicle['officeName']?.toString(),
          vehicle['zone']?.toString(),
          vehicle['office']?.toString(),
          item['zoneName']?.toString(),
          item['officeName']?.toString(),
          item['zone']?.toString(),
          item['office']?.toString(),
        ].whereType<String>().map((s) => s.toLowerCase().trim()).toList();

        if (itemZones.isEmpty) {
          matchesZone = true;
        } else {
          matchesZone = itemZones.any((z) => z == selZone || z.contains(selZone) || selZone.contains(z));
        }
      }

      // Camera Filter
      final selectedCameraId = state.cameraLocationToId[_localCamera];
      bool matchesCamera = _localCamera == 'Select All Camera' || _localCamera.isEmpty;
      if (!matchesCamera) {
        matchesCamera = vehicle['cameraID'] == selectedCameraId ||
            (vehicle['cameraName']?.toString().toLowerCase().contains(_localCamera.toLowerCase()) ?? false);
      }

      // Search Box Filter
      bool matchesSearch = searchLower.isEmpty;
      if (!matchesSearch) {
        final plateMatch = vehicle['vehicleNumber']?.toString().toLowerCase().contains(searchLower) ?? false;
        final cameraMatch = vehicle['cameraName']?.toString().toLowerCase().contains(searchLower) ?? false;
        final remarksMatch = item['remarks']?.toString().toLowerCase().contains(searchLower) ?? false;
        matchesSearch = plateMatch || cameraMatch || remarksMatch;
      }

      return matchesDistrict && matchesZone && matchesCamera && matchesSearch;
    }).toList();

    // Sort
    if (_sortColumn.isNotEmpty) {
      filtered.sort((a, b) {
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

    // Pagination
    final totalItems = filtered.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginated = filtered.sublist(
      startIndex,
      endIndex > totalItems ? totalItems : endIndex,
    );

    final timeRangeOptions = ['Select All Time Range', 'Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days'];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F6),
      body: LoadingOverlay(
        isLoading: state.isLoading,
        child: RefreshIndicator(
          onRefresh: () async {
            if (widget.isLiveFeed) {
              await notifier.fetchViolations();
              await notifier.fetchNotifications();
            } else {
              await notifier.fetchNotifications(
                districtName: _localDistrict,
                zoneName: _localZone,
                cameraId: _localCamera,
              );
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: PageHeaderBanner(
                      title: 'Vehicle Monitoring & History',
                      subtitle: 'Government of Telangana Transport Department',
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      final newShow = !_showHistoryFilters;
                      setState(() => _showHistoryFilters = newShow);
                      notifier.fetchNotifications(
                        districtName: _localDistrict,
                        zoneName: _localZone,
                        cameraId: _localCamera,
                      );
                    },
                    icon: Icon(
                      _showHistoryFilters ? Icons.filter_alt_off : Icons.filter_alt,
                      size: 18,
                      color: const Color(0xFF0D9488),
                    ),
                    label: Text(
                      _showHistoryFilters ? 'Hide Filter' : 'Filter',
                      style: const TextStyle(
                        color: Color(0xFF0D9488),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              if (_showHistoryFilters) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final districtDropdown = _buildDropdownField(
                        hint: 'Select District',
                        value: _localDistrict,
                        options: state.districts,
                        onChanged: (value) {
                          setState(() {
                            _localDistrict = value ?? 'Select All District';
                            _localZone = 'Select All Zone';
                            _localCamera = 'Select All Camera';
                          });
                          if (value != null && value != 'Select All District') {
                            notifier.fetchZonesForDistrict(value).then((autoZone) {
                              if (autoZone != null && mounted) {
                                setState(() => _localZone = autoZone);
                                notifier.fetchCamerasForZone(autoZone);
                              }
                            });
                          } else {
                            notifier.resetZones();
                          }
                          notifier.resetCameras();
                        },
                      );

                      final zoneDropdown = _buildDropdownField(
                        hint: 'Select Zone',
                        value: _localZone,
                        options: state.zones,
                        onChanged: (value) {
                          setState(() {
                            _localZone = value ?? 'Select All Zone';
                            _localCamera = 'Select All Camera';
                          });
                          if (value != null && value != 'Select All Zone') {
                            notifier.fetchCamerasForZone(value);
                          } else {
                            notifier.resetCameras();
                          }
                        },
                      );

                      final cameraDropdown = _buildDropdownField(
                        hint: 'Select Camera',
                        value: _localCamera,
                        options: state.cameras,
                        onChanged: (value) => setState(() => _localCamera = value ?? 'Select All Camera'),
                      );

                      final timeRangeDropdown = _buildDropdownField(
                        hint: 'Select Time Range',
                        value: _localTimeRange,
                        options: timeRangeOptions,
                        onChanged: (value) => setState(() => _localTimeRange = value ?? 'Select All Time Range'),
                      );

                      final applyButton = FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _currentPage = 1;
                          });
                          notifier.fetchNotifications(
                            districtName: _localDistrict,
                            zoneName: _localZone,
                            cameraId: _localCamera,
                          );
                        },
                        icon: const Icon(Icons.check, size: 16, color: Colors.white),
                        label: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: districtDropdown),
                              const SizedBox(width: 12),
                              Expanded(child: zoneDropdown),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: cameraDropdown),
                              const SizedBox(width: 12),
                              Expanded(child: timeRangeDropdown),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: applyButton,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Historical badge + Search bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    // Historical badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Historical',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search anything...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    notifier.updateSearch('');
                                    setState(() {
                                      _currentPage = 1;
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (val) {
                          notifier.updateSearch(val);
                          setState(() {
                            _currentPage = 1;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Data Table
              LayoutBuilder(
                builder: (context, constraints) {
                  final double minWidth = 1100;
                  final double contentWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: contentWidth,
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Table Header (Navy Blue Background)
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
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Status',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Action',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Colors.black12),

                            // Table Rows
                            paginated.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 40),
                                    child: Center(
                                      child: Text(
                                        'No historical records found.',
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

                                      // Type badge color
                                      Color typeBadgeBg;
                                      Color typeBadgeText;
                                      if (typeLabel == 'COMMERCIAL') {
                                        typeBadgeBg = const Color(0xFFDBEAFE);
                                        typeBadgeText = const Color(0xFF1E40AF);
                                      } else if (typeLabel == 'TRANSPORT') {
                                        typeBadgeBg = const Color(0xFFDCFCE7);
                                        typeBadgeText = const Color(0xFF166534);
                                      } else {
                                        typeBadgeBg = const Color(0xFFDCFCE7);
                                        typeBadgeText = const Color(0xFF166534);
                                      }

                                      // Status badge color
                                      Color statusBadgeColor;
                                      if (statusText == 'NA') {
                                        statusBadgeColor = const Color(0xFF7C3AED);
                                      } else if (statusText == 'COMPLIANT') {
                                        statusBadgeColor = const Color(0xFF16A34A);
                                      } else {
                                        statusBadgeColor = const Color(0xFFE11D48);
                                      }

                                      return Container(
                                        color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            // Time
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                _historyFormatTime(vehicle['createdTime']?.toString()),
                                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                              ),
                                            ),
                                            // Vehicle
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
                                            // Type badge
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: typeBadgeBg,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    typeLabel,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: typeBadgeText,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Camera
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                vehicle['cameraName']?.toString() ?? vehicle['cameraID']?.toString() ?? 'N/A',
                                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            // Violation
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
                                            // Status badge
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  statusText,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: statusBadgeColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // View button
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: OutlinedButton(
                                                  onPressed: () => _showDetailsDialog(context, item, state),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFF3B82F6)),
                                                    minimumSize: const Size(60, 30),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  ),
                                                  child: const FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      'View',
                                                      maxLines: 1,
                                                      style: TextStyle(
                                                        color: Color(0xFF3B82F6),
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
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
                    ),
                  );
                },
              ),

              // Pagination
              _buildHistoryPaginationControls(totalItems, _itemsPerPage, totalPages),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildHistoryPaginationControls(int totalItems, int itemsPerPage, int totalPages) {
    if (totalPages <= 0) return const SizedBox.shrink();

    final startItem = totalItems > 0 ? ((_currentPage - 1) * itemsPerPage) + 1 : 0;
    final endItem = (_currentPage * itemsPerPage) > totalItems ? totalItems : (_currentPage * itemsPerPage);

    final bool isMobile = MediaQuery.of(context).size.width < 750;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: isMobile
            ? Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F3260),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Page $_currentPage of $totalPages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Showing $startItem - $endItem of $totalItems total records',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _currentPage > 1
                            ? () => setState(() => _currentPage--)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chevron_left, size: 18, color: _currentPage > 1 ? Colors.black87 : Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Previous',
                              style: TextStyle(color: _currentPage > 1 ? Colors.black87 : Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: _currentPage < totalPages
                            ? () => setState(() => _currentPage++)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Next',
                              style: TextStyle(color: _currentPage < totalPages ? Colors.black87 : Colors.grey),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, size: 18, color: _currentPage < totalPages ? Colors.black87 : Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _currentPage > 1
                        ? () => setState(() => _currentPage--)
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left, size: 18, color: _currentPage > 1 ? Colors.black87 : Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Previous',
                          style: TextStyle(color: _currentPage > 1 ? Colors.black87 : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F3260),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Page $_currentPage of $totalPages',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Showing $startItem - $endItem of $totalItems total records',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _currentPage < totalPages
                        ? () => setState(() => _currentPage++)
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next',
                          style: TextStyle(color: _currentPage < totalPages ? Colors.black87 : Colors.grey),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 18, color: _currentPage < totalPages ? Colors.black87 : Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems, int itemsPerPage) {
    final totalPages = (totalItems / itemsPerPage).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    final List<Widget> children = [];

    // Previous Button
    children.add(
      TextButton(
        onPressed: _currentPage > 1
            ? () {
                setState(() {
                  _currentPage--;
                });
              }
            : null,
        child: const Text('« Previous'),
      ),
    );

    // Page Number Buttons
    for (int i = 1; i <= totalPages; i++) {
      final isCurrent = i == _currentPage;
      children.add(
        InkWell(
          onTap: () {
            setState(() {
              _currentPage = i;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFF0F3260) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isCurrent ? const Color(0xFF0F3260) : Colors.grey.shade300,
              ),
            ),
            child: Text(
              '$i',
              style: TextStyle(
                color: isCurrent ? Colors.white : Colors.black87,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    // Next Button
    children.add(
      TextButton(
        onPressed: _currentPage < totalPages
            ? () {
                setState(() {
                  _currentPage++;
                });
              }
            : null,
        child: const Text('Next »'),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}



Future<String?> _getSignatureBase64(List<Offset?> points) async {
  if (points.isEmpty) return null;
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 400, 200));

    final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 200), bgPaint);

    final paint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(ui.PointMode.points, [points[i]!], paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(400, 200);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    final base64Str = base64Encode(bytes);
    return 'data:image/png;base64,$base64Str';
  } catch (e) {
    debugPrint('Error converting signature to base64: $e');
    return null;
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);
  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}

void _showSignatureCaptureDialog(
  BuildContext context, {
  required void Function(List<Offset?> points) onSigned,
}) {
  final List<Offset?> points = [];
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSig) {
        return AlertDialog(
          title: const Text('Capture Signature', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            height: 220,
            child: Column(
              children: [
                const Text('Draw signature below:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Listener(
                        onPointerDown: (event) {
                          setSig(() {
                            points.add(event.localPosition);
                          });
                        },
                        onPointerMove: (event) {
                          setSig(() {
                            points.add(event.localPosition);
                          });
                        },
                        onPointerUp: (event) {
                          setSig(() {
                            points.add(null);
                          });
                        },
                        child: CustomPaint(
                          painter: _SignaturePainter(List<Offset?>.from(points)),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setSig(() => points.clear()),
              child: const Text('Clear', style: TextStyle(color: Colors.orange)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onSigned(List<Offset?>.from(points));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildDupRow(String label, Widget child) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Align(
          alignment: Alignment.centerRight,
          child: child,
        ),
      ),
    ],
  );
}

void _showPreviousVcrFoundDialog(
  BuildContext context, {
  required Map<String, dynamic> duplicateData,
  required String vehicleNumber,
  required String offenceNames,
  required Map<String, dynamic> item,
  required double totalChallanAmount,
  required String remarksText,
  required WidgetRef ref,
}) {
  final vehicleNoStr = (duplicateData['vehicleNo'] ?? duplicateData['registrationNumber'] ?? vehicleNumber).toString();
  final offenceStr = (duplicateData['offence'] ?? duplicateData['offences'] ?? offenceNames).toString();
  final previousVcrStr = (duplicateData['previousVcr'] ?? duplicateData['vcrNumber'] ?? duplicateData['vcrNo'] ?? '').toString();
  final genDateStr = (duplicateData['generatedDate'] ?? duplicateData['issuedDate'] ?? '').toString();
  final allowedAfterStr = (duplicateData['allowedAfter'] ?? '').toString();
  final statusStr = (duplicateData['status'] ?? 'DUPLICATE PERIOD ACTIVE').toString();

  final hasValidVcr = previousVcrStr.isNotEmpty &&
      previousVcrStr.toLowerCase() != 'none' &&
      previousVcrStr.toLowerCase() != 'null';

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 580,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        color: const Color(0xFFF8FAFC),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Banner
            Container(
              color: const Color(0xFF0F265C),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Previous VCR Found',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content Area
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'For this offence, a VCR is generated and it is in the duplicate days period.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card details box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // VEHICLE NO
                          _buildDupRow(
                            'VEHICLE NO:',
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                vehicleNoStr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),

                          // OFFENCE
                          _buildDupRow(
                            'OFFENCE:',
                            Text(
                              offenceStr,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),

                          // PREVIOUS VCR
                          _buildDupRow(
                            'PREVIOUS VCR:',
                            Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  previousVcrStr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: hasValidVcr ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                  ),
                                ),
                                if (hasValidVcr)
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final repo = VehicleMonitoringRepository(apiClient: ApiClient(SecureStorageService()));
                                      try {
                                        final pdfData = await repo.generatePdf(previousVcrStr);
                                        await PdfHelper.displayOrDownloadPdf(pdfData, '$previousVcrStr.pdf');
                                      } catch (e) {
                                        debugPrint('Error generating PDF: $e');
                                      }
                                    },
                                    icon: const Icon(Icons.picture_as_pdf, size: 14, color: Color(0xFF2563EB)),
                                    label: const Text(
                                      'View VCR',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF2563EB)),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),

                          // GENERATED DATE
                          _buildDupRow(
                            'GENERATED DATE:',
                            Text(
                              genDateStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),

                          // STATUS
                          _buildDupRow(
                            'STATUS:',
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error, size: 14, color: Color(0xFF3730A3)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      statusStr.toUpperCase(),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        color: Color(0xFF3730A3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),

                          // ALLOWED AFTER
                          _buildDupRow(
                            'ALLOWED AFTER:',
                            Text(
                              allowedAfterStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF16A34A),
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

            // Footer Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF94A3B8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _executeGenerateChallan(
                          context,
                          actionType: 'Raise Challan',
                          item: item,
                          offenceNames: offenceNames,
                          totalChallanAmount: totalChallanAmount,
                          remarksText: remarksText,
                          ref: ref,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F265C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'GENERATE ANYWAY',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
}

Future<void> _executeGenerateChallan(
  BuildContext context, {
  required String actionType,
  required Map<String, dynamic> item,
  required String offenceNames,
  required double totalChallanAmount,
  required String remarksText,
  required WidgetRef ref,
}) async {
  final repo = VehicleMonitoringRepository(apiClient: ApiClient(SecureStorageService()));
  final storage = SecureStorageService();
  final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
  final vehicleNumber = (vehicle['vehicleNumber'] ?? vehicle['registrationNumber'] ?? item['vehicleNumber'] ?? '').toString();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    final currentUser = await storage.readUsername() ?? 'tc_user';
    final vehicleClass = (vehicle['vehicleClass'] ?? vehicle['category'] ?? vehicle['vehicleType'] ?? 'Heavy Vehicle').toString();
    final locationName = (vehicle['place'] ?? vehicle['location'] ?? vehicle['districtName'] ?? 'Kamareddy').toString();

    final rawVid = vehicle['id'] ?? vehicle['vehicleId'] ?? item['vehicleId'] ?? item['id'] ?? 0;
    final int vehicleId = rawVid is num ? rawVid.toInt() : (int.tryParse(rawVid.toString()) ?? 0);

    final now = DateTime.now();
    final monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final monthYear = '${monthNames[now.month - 1]}${now.year}';
    final randomId = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
    final clientVcrNumber = 'TG_017/$monthYear/vcr_$randomId';
    final formattedDate = now.toIso8601String().split('.').first;

    // 1. Save VCR API
    final vcrData = {
      'vcrNumber': clientVcrNumber,
      'registrationNumber': vehicleNumber,
      'vehicleClass': vehicleClass,
      'vehicleId': vehicleId,
      'ownerName': (vehicle['ownerName'] ?? '').toString(),
      'driverName': ' ',
      'licenceNumber': ' ',
      'offences': offenceNames,
      'fineAmount': totalChallanAmount,
      'existingChallanAmount': totalChallanAmount,
      'checkingOfficer': currentUser,
      'issuedByUsername': currentUser,
      'issuedBy': 'RTA',
      'location': locationName,
      'issuedDate': formattedDate,
      'remarks': remarksText,
    };
    final vcrResult = await repo.saveVcr(vcrData);
    final vcrNumber = (vcrResult['vcrNumber'] ?? vcrResult['id'] ?? clientVcrNumber).toString();

    // 2. Add Challan API
    if (vcrNumber.isNotEmpty) {
      final String challanTypeVal = actionType == 'Seize Vehicle'
          ? 'SEIZE'
          : (actionType == 'Raise Challan' ? 'RAISE' : 'COLLECT');

      await repo.addChallan({
        'vcrNumber': vcrNumber,
        'challanNumber': vcrNumber,
        'challanAmount': totalChallanAmount,
        'fineAmount': totalChallanAmount,
        'challanType': challanTypeVal,
        'registrationNumber': vehicleNumber,
        'vehicleId': vehicleId,
        'status': 'ISSUED',
        'offenceType': 'GENERAL',
        'issuedDate': formattedDate,
        'remarks': remarksText,
      });
    }

    // 3. Generate PDF API
    if (vcrNumber.isNotEmpty) {
      try {
        final pdfData = await repo.generatePdf(vcrNumber);
        await PdfHelper.displayOrDownloadPdf(pdfData, '$vcrNumber.pdf');
      } catch (e) {
        debugPrint('Warning: generatePdf failed: $e');
      }
    }

    if (context.mounted) Navigator.of(context).pop(); // dismiss loading
    if (context.mounted) Navigator.of(context).pop(); // dismiss details modal if open

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Challan generated successfully!'
            '${vcrNumber.isNotEmpty ? ' VCR #$vcrNumber' : ''}',
          ),
          backgroundColor: const Color(0xFF198754),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) Navigator.of(context).pop(); // dismiss loading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate challan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

void _showDriverDetailsAndSignatureDialog(
  BuildContext context, {
  required String actionType,
  required Map<String, dynamic> item,
  required List<Map<String, dynamic>> selectedOffences,
  required List<Map<String, dynamic>> customOffences,
  required double totalChallanAmount,
  required String remarksText,
  required WidgetRef ref,
}) {
  final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
  final vehicleNumber = vehicle['vehicleNumber']?.toString() ?? 'N/A';

  // Form controllers
  final licenseCtrl = TextEditingController();
  final driverNameCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  List<Offset?> driverSignaturePoints = [];
  bool isSubmitting = false;
  String? submitError;

  Color actionColor;
  IconData actionIcon;
  switch (actionType) {
    case 'Seize Vehicle':
      actionColor = const Color(0xFFDC3545);
      actionIcon = Icons.car_crash;
      break;
    case 'Raise Challan':
      actionColor = const Color(0xFF198754);
      actionIcon = Icons.receipt_long;
      break;
    default: // Collect Fine
      actionColor = const Color(0xFF28A745);
      actionIcon = Icons.payments_outlined;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: actionColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(actionIcon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          actionType == 'Seize Vehicle' ? 'Driver Details' : 'Driver Details & Signature',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          actionType,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                // ── Body ────────────────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Driver Details Section
                          _buildSectionHeader('Driver Details', Icons.person_outline, const Color(0xFF0F3260)),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (_, constraints) {
                              final isMobile = constraints.maxWidth < 480;
                              final licenseField = TextFormField(
                                controller: licenseCtrl,
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: [UpperCaseTextFormatter()],
                                decoration: _inputDecoration('License No. (E.g. TS0123456789012)', Icons.badge_outlined),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter license number' : null,
                              );
                              final nameField = TextFormField(
                                controller: driverNameCtrl,
                                decoration: _inputDecoration('Driver Name', Icons.person_outline),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter driver name' : null,
                              );

                              if (isMobile) {
                                return Column(children: [
                                  licenseField,
                                  const SizedBox(height: 12),
                                  nameField,
                                ]);
                              }
                              return Row(children: [
                                Expanded(child: licenseField),
                                const SizedBox(width: 12),
                                Expanded(child: nameField),
                              ]);
                            },
                          ),

                          if (actionType != 'Seize Vehicle') ...[
                            const SizedBox(height: 20),
                            // Signatures Section
                            _buildSectionHeader('Signatures', Icons.draw_outlined, const Color(0xFF0F3260)),
                            const SizedBox(height: 12),
                            _buildSignatureBox(
                              label: 'Driver / Owner Signature',
                              points: driverSignaturePoints,
                              onCapture: () => _showSignatureCaptureDialog(
                                ctx,
                                onSigned: (pts) => setDlgState(() => driverSignaturePoints = pts),
                              ),
                              onClear: () => setDlgState(() => driverSignaturePoints = []),
                            ),
                          ],

                          if (submitError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFFEEBA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber, color: Color(0xFF856404), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(submitError!, style: const TextStyle(color: Color(0xFF856404), fontSize: 12))),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Footer ──────────────────────────────────────────────
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send, size: 16),
                        label: Text(isSubmitting ? 'Submitting...' : actionType),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) return;
                                        setDlgState(() {
                                          isSubmitting = true;
                                          submitError = null;
                                        });
                                        try {
                                          final storage = SecureStorageService();
                                          final apiClient = ApiClient(storage);
                                          final repo = VehicleMonitoringRepository(apiClient: apiClient);

                                          // Compose offences string
                                          final offenceNames = [
                                            ...selectedOffences.map((o) => o['name']?.toString() ?? o['offence']?.toString() ?? ''),
                                            ...customOffences.map((o) => o['name']?.toString() ?? ''),
                                          ].where((s) => s.isNotEmpty).join(',');

                                          // 1. Check duplicate VCR API (non-blocking warning if fails)
                                          try {
                                            await repo.checkDuplicateVcr(
                                              registrationNumber: vehicleNumber,
                                              offences: offenceNames,
                                            );
                                          } catch (e) {
                                            debugPrint('Warning: checkDuplicateVcr check: $e');
                                          }

                                          // Extract user details & vehicle metadata
                                          final currentUser = await storage.readUsername() ?? 'tc_user';
                                          final vehicleClass = (vehicle['vehicleClass'] ?? vehicle['category'] ?? vehicle['vehicleType'] ?? 'Heavy Vehicle').toString();
                                          final locationName = (vehicle['place'] ?? vehicle['location'] ?? vehicle['districtName'] ?? 'Kamareddy').toString();
                                          
                                          final rawVid = vehicle['id'] ?? vehicle['vehicleId'] ?? item['vehicleId'] ?? item['id'] ?? 0;
                                          final int vehicleId = rawVid is num ? rawVid.toInt() : (int.tryParse(rawVid.toString()) ?? 0);

                                          final now = DateTime.now();
                                          final monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                                          final monthYear = '${monthNames[now.month - 1]}${now.year}';
                                          final randomId = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
                                          final clientVcrNumber = 'TG_017/$monthYear/vcr_$randomId';
                                          final formattedDate = now.toIso8601String().split('.').first;

                                          // 2. Save VCR API
                                          final vcrData = {
                                            'vcrNumber': clientVcrNumber,
                                            'registrationNumber': vehicleNumber,
                                            'vehicleClass': vehicleClass,
                                            'vehicleId': vehicleId,
                                            'ownerName': (vehicle['ownerName'] ?? '').toString(),
                                            'driverName': driverNameCtrl.text.trim(),
                                            'licenceNumber': licenseCtrl.text.trim(),
                                            'offences': offenceNames,
                                            'fineAmount': totalChallanAmount,
                                            'existingChallanAmount': totalChallanAmount,
                                            'checkingOfficer': currentUser,
                                            'issuedByUsername': currentUser,
                                            'issuedBy': 'RTA',
                                            'location': locationName,
                                            'issuedDate': formattedDate,
                                            'remarks': remarksText,
                                          };
                                          final vcrResult = await repo.saveVcr(vcrData);
                                          final vcrNumber = (vcrResult['vcrNumber'] ?? vcrResult['id'] ?? clientVcrNumber).toString();

                                          // 3. Add Challan API
                                          if (vcrNumber.isNotEmpty) {
                                            final String challanTypeVal = actionType == 'Seize Vehicle'
                                                ? 'SEIZE'
                                                : (actionType == 'Raise Challan' ? 'RAISE' : 'COLLECT');

                                            await repo.addChallan({
                                              'vcrNumber': vcrNumber,
                                              'challanNumber': vcrNumber,
                                              'challanAmount': totalChallanAmount,
                                              'fineAmount': totalChallanAmount,
                                              'challanType': challanTypeVal,
                                              'registrationNumber': vehicleNumber,
                                              'vehicleId': vehicleId,
                                              'status': 'ISSUED',
                                              'offenceType': 'GENERAL',
                                              'issuedDate': formattedDate,
                                              'remarks': remarksText,
                                            });
                                          }

                                          // 4. Save Driver Signature API
                                          if (actionType != 'Seize Vehicle' && driverSignaturePoints.isNotEmpty && vcrNumber.isNotEmpty) {
                                            try {
                                              final sigBase64 = await _getSignatureBase64(driverSignaturePoints);
                                              if (sigBase64 != null && sigBase64.isNotEmpty) {
                                                final cleanSig = sigBase64.contains(',') ? sigBase64.split(',').last : sigBase64;
                                                await repo.saveDriverSign(vcrNumber: vcrNumber, driverSign: cleanSig);
                                              }
                                            } catch (e) {
                                              debugPrint('Warning: saveDriverSign failed: $e');
                                            }
                                          }

                                          // 5. Generate PDF API
                                          if (vcrNumber.isNotEmpty) {
                                            try {
                                              final pdfData = await repo.generatePdf(vcrNumber);
                                              await PdfHelper.displayOrDownloadPdf(pdfData, '$vcrNumber.pdf');
                                            } catch (e) {
                                              debugPrint('Warning: generatePdf failed: $e');
                                            }
                                          }

                                          if (ctx.mounted) Navigator.of(ctx).pop();
                                          if (context.mounted) Navigator.of(context).pop();

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${actionType == 'Seize Vehicle' ? 'Vehicle seized' : 'Challan generated'} successfully!'
                                                  '${vcrNumber.isNotEmpty ? ' VCR #$vcrNumber' : ''}',
                                                ),
                                                backgroundColor: actionColor,
                                                behavior: SnackBarBehavior.floating,
                                                duration: const Duration(seconds: 4),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          setDlgState(() {
                                            isSubmitting = false;
                                            submitError = 'Failed to submit: ${e.toString()}';
                                          });
                                        }
                                      },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildSectionHeader(String title, IconData icon, Color color) {
  return Row(
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
      ),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
    ],
  );
}

InputDecoration _inputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12),
    prefixIcon: Icon(icon, size: 18, color: Colors.grey),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF0F3260), width: 1.5),
    ),
    filled: true,
    fillColor: Colors.white,
  );
}

Widget _buildSignatureBox({
  required String label,
  required List<Offset?> points,
  required VoidCallback onCapture,
  required VoidCallback onClear,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
      color: const Color(0xFFF9F9F9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F3260))),
        const SizedBox(height: 8),
        if (points.isNotEmpty)
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CustomPaint(
                painter: _SignaturePainter(points),
                child: Container(),
              ),
            ),
          )
        else
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text('No signature captured', style: TextStyle(color: Colors.black38, fontSize: 12)),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (points.isNotEmpty)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
              ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.draw, size: 14),
              label: Text(points.isEmpty ? 'Capture' : 'Redo', style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F3260),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


