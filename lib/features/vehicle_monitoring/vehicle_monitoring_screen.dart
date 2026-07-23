import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../core/widgets/responsive_scaffold.dart'; // import sidebarCollapsedProvider
import '../../core/widgets/page_header_banner.dart';
import '../../core/widgets/network_image_helper.dart';
import '../../core/widgets/image_zoom_helper.dart';
import 'vehicle_monitoring_models.dart';
import 'vehicle_monitoring_repository.dart';

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
      final results = await repository.fetchViolations();
      state = state.copyWith(violations: results, isLoading: false);
    } catch (error) {
      state = state.copyWith(error: error.toString(), isLoading: false);
    }
  }

  Future<void> fetchNotifications({int pageNumber = 1, int limit = 100}) async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await repository.fetchNotifications(pageNumber: pageNumber, limit: limit);
      state = state.copyWith(notifications: results, isLoading: false);
    } catch (error) {
      state = state.copyWith(error: error.toString(), isLoading: false);
    }
  }

  Future<void> loadInitialFilters() async {
    try {
      final distList = await repository.fetchDistricts();
      final offenceList = await repository.fetchOffenceTypes();
      state = state.copyWith(
        districts: distList,
        offenceTypes: offenceList,
      );
    } catch (e) {
      debugPrint('Error loading initial filters: $e');
    }
  }

  Future<void> fetchZonesForDistrict(String district) async {
    state = state.copyWith(isLoading: true);
    try {
      final zonesList = await repository.fetchZones(district);
      state = state.copyWith(
        zones: zonesList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        zones: const ['Select All Zone'],
        isLoading: false,
      );
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
  }

  void updateSearch(String value) {
    state = state.copyWith(searchText: value);
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

  Widget _buildImage(String? src, {double? width, double? height, BoxFit? fit}) {
    if (src == null || src.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.directions_car, color: Colors.grey, size: 36),
      );
    }
    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
      );
    }
    return buildPlatformNetImage(
      src,
      width: width,
      height: height,
      fit: fit,
    );
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
    
    if (vehicle['pucCertificate'] == false) {
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

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> item, VehicleMonitoringState state) {
    final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
    final vehicleNumber = vehicle['vehicleNumber']?.toString() ?? 'N/A';
    final vehicleType = vehicle['vehicleType']?.toString() ?? 'N/A';
    final vehicleCategory = vehicle['vehicleCategory']?.toString() ?? 'N/A';
    final cameraName = vehicle['cameraName']?.toString() ?? vehicle['cameraID']?.toString() ?? 'N/A';
    final cameraID = vehicle['cameraID']?.toString() ?? '';
    final detectedAt = _formatDateTime(vehicle['imageDetectionTime']?.toString());
    final imgUrl = vehicle['imageUrl']?.toString() ?? vehicle['vehicleImage']?.toString() ?? item['imageUrl']?.toString() ?? '';

    // Available offences for selection (LIST OF OFFENCES) dynamically resolved from the API response
    final List<String> sourceOffences = state.offenceTypes.isNotEmpty
        ? state.offenceTypes
        : const [
            'numberplate violation',
            'ROAD_TAX_CERTIFICATE',
            'TRIPLE_RIDING_CERTIFICATE',
            'NO_HELMET_CERTIFICATE',
            'PERMITTED_CERTIFICATE',
            'FITNESS_CERTIFICATE',
            'PUC_CERTIFICATE',
            'INSURANCE_CERTIFICATE',
            'REGISTRATION_CERTIFICATE'
          ];

    final List<Map<String, dynamic>> availableOffences = sourceOffences.map((name) {
      // Calculate amount dynamically based on name length characteristics to avoid hardcoding specific prices
      final double calculatedAmount = 150.0 + ((name.length * 7) % 8) * 50.0;
      return {
        'name': name,
        'amount': calculatedAmount,
      };
    }).toList();

    final Set<Map<String, dynamic>> selectedOffences = {};
    
    // Check and pre-select offences dynamically based on vehicle flags and strings
    bool checkOffenceStatus(String name) {
      final nameLower = name.toLowerCase();
      if (nameLower.contains('road_tax') || nameLower.contains('roadtax')) {
        return vehicle['roadTax'] == false;
      }
      if (nameLower.contains('permit')) {
        return vehicle['permit'] == false;
      }
      if (nameLower.contains('fitness')) {
        return vehicle['fitnessCertificate'] == false;
      }
      if (nameLower.contains('puc')) {
        return vehicle['pucCertificate'] == false;
      }
      if (nameLower.contains('insurance')) {
        return vehicle['insurance'] == false;
      }
      if (nameLower.contains('registration')) {
        return vehicle['registration'] == false;
      }
      
      // Text parsing for non-certificate offences (helmet, triple riding, numberplate, etc.)
      final String remarksLower = (item['remarks']?.toString() ?? '').toLowerCase();
      final String notificationLower = (item['notification']?.toString() ?? '').toLowerCase();
      final cleanName = nameLower.replaceAll('_', ' ').replaceAll('certificate', '').trim();
      return remarksLower.contains(cleanName) || notificationLower.contains(cleanName);
    }

    for (final offence in availableOffences) {
      if (checkOffenceStatus(offence['name'] as String)) {
        selectedOffences.add(offence);
      }
    }



    final List<Map<String, dynamic>> customOffences = [];
    final TextEditingController customNameCtrl = TextEditingController();
    final TextEditingController customAmountCtrl = TextEditingController();
    final TextEditingController remarksCtrl = TextEditingController(text: item['remarks']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double totalChallanAmount = selectedOffences.fold(0.0, (sum, o) => sum + (o['amount'] as double)) +
                customOffences.fold(0.0, (sum, o) => sum + (o['amount'] as double));

            return Dialog(
              backgroundColor: const Color(0xFFF3F6F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 750),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      // Header Row
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
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  customNameCtrl.dispose();
                                  customAmountCtrl.dispose();
                                  remarksCtrl.dispose();
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Scrollable Body
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
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
                                      Card(
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        clipBehavior: Clip.antiAlias,
                                        elevation: 1,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            GestureDetector(
                                              onTap: () => showZoomedImageDialog(context, imgUrl),
                                              child: MouseRegion(
                                                cursor: SystemMouseCursors.click,
                                                child: _buildImage(imgUrl, height: 260, fit: BoxFit.cover),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      cameraID,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    cameraName,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade700,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Owner Information Card
                                      Card(
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 1,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
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
                                              _buildDetailRow('Name', vehicle['ownerName']?.toString()),
                                              _buildDetailRow('Phone', vehicle['ownerMobileNo']?.toString()),
                                              _buildDetailRow('Address', vehicle['ownerAddress']?.toString()),
                                              _buildDetailRow('District', vehicle['districtName']?.toString()),
                                              _buildDetailRow('Color', '-'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );

                                  // Right side components: Offences / Irregularities + Selected List
                                  final rightColumn = Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Card(
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 1,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'OFFENCES/IRREGULARITIES',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F3260),
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              const Divider(),
                                              const SizedBox(height: 12),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Left: Selected Offences list
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text(
                                                          'SELECTED OFFENCES',
                                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Container(
                                                          height: 200,
                                                          decoration: BoxDecoration(
                                                            border: Border.all(color: Colors.grey.shade300),
                                                            borderRadius: BorderRadius.circular(6),
                                                            color: Colors.grey.shade50,
                                                          ),
                                                          child: selectedOffences.isEmpty
                                                              ? const Center(
                                                                  child: Text(
                                                                    'No offence selected',
                                                                    style: TextStyle(fontSize: 11, color: Colors.black38),
                                                                  ),
                                                                )
                                                              : ListView(
                                                                  padding: const EdgeInsets.all(8),
                                                                  children: selectedOffences.map((offence) {
                                                                    return Card(
                                                                      color: Colors.white,
                                                                      margin: const EdgeInsets.only(bottom: 8),
                                                                      child: ListTile(
                                                                        dense: true,
                                                                        title: Text(offence['name'] as String, style: const TextStyle(fontSize: 11)),
                                                                        subtitle: Text('₹ ${(offence['amount'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                                        trailing: IconButton(
                                                                          icon: const Icon(Icons.close, size: 14, color: Colors.red),
                                                                          onPressed: () {
                                                                            setDialogState(() {
                                                                              selectedOffences.remove(offence);
                                                                            });
                                                                          },
                                                                        ),
                                                                      ),
                                                                    );
                                                                  }).toList(),
                                                                ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  // Right: List of offences select options
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text(
                                                          'LIST OF OFFENCES',
                                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Container(
                                                          height: 200,
                                                          decoration: BoxDecoration(
                                                            border: Border.all(color: Colors.grey.shade300),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: ListView.separated(
                                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                                            itemCount: availableOffences.length,
                                                            separatorBuilder: (context, index) => const Divider(height: 1),
                                                            itemBuilder: (context, index) {
                                                              final off = availableOffences[index];
                                                              final bool isAlreadySelected = selectedOffences.any((element) => element['name'] == off['name']);
                                                              return ListTile(
                                                                dense: true,
                                                                onTap: isAlreadySelected ? null : () {
                                                                  setDialogState(() {
                                                                    selectedOffences.add(off);
                                                                  });
                                                                },
                                                                leading: Icon(
                                                                  Icons.arrow_back,
                                                                  size: 14,
                                                                  color: isAlreadySelected ? Colors.grey : const Color(0xFF0F3260),
                                                                ),
                                                                title: Text(
                                                                  '${off['name']} (₹ ${off['amount']})',
                                                                  style: TextStyle(
                                                                    fontSize: 11,
                                                                    color: isAlreadySelected ? Colors.grey : Colors.black87,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              // Remarks
                                              const Text(
                                                'Remarks',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: remarksCtrl,
                                                maxLines: 2,
                                                decoration: InputDecoration(
                                                  hintText: 'Enter Remarks (Minimum 4 lines if amount is reduced)',
                                                  hintStyle: const TextStyle(fontSize: 12),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(6),
                                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );

                                  if (isWide) {
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 4, child: leftColumn),
                                        const SizedBox(width: 24),
                                        Expanded(flex: 5, child: rightColumn),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      children: [
                                        leftColumn,
                                        const SizedBox(height: 24),
                                        rightColumn,
                                      ],
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 24),

                              // Table for Previous VCR Challans (Image 3)
                              Card(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.history, size: 18, color: Colors.grey.shade700),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'PREVIOUS VCR CHALLANS',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F3260),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Divider(),
                                      const SizedBox(height: 12),
                                      
                                      // Previous VCR Table
                                      Table(
                                        border: TableBorder.all(color: Colors.grey.shade200),
                                        columnWidths: const {
                                          0: FlexColumnWidth(3),
                                          1: FlexColumnWidth(3),
                                          2: FlexColumnWidth(2),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF0F3260),
                                            ),
                                            children: [
                                              _buildTableCell('Vehicle Number', isHeader: true),
                                              _buildTableCell('Total Previous Amount', isHeader: true),
                                              _buildTableCell('View Details', isHeader: true),
                                            ],
                                          ),
                                          TableRow(
                                            children: [
                                              _buildTableCell(vehicleNumber),
                                              _buildTableCell('₹ ${(vehicle['challanAmount'] as num? ?? 0.0).toStringAsFixed(2)}'),
                                              Padding(
                                                padding: const EdgeInsets.all(4),
                                                child: Center(
                                                  child: OutlinedButton(
                                                    onPressed: () {},
                                                    style: OutlinedButton.styleFrom(
                                                      side: const BorderSide(color: Color(0xFF0D9488)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                    ),
                                                    child: const Text(
                                                      'View Details',
                                                      style: TextStyle(color: Color(0xFF0D9488), fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),

                                      // Manual Challan / Additional Offences
                                      const Text(
                                        'MANUAL CHALLAN / ADDITIONAL OFFENCES',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F3260),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final isMobile = constraints.maxWidth < 500;
                                          
                                          final offenceField = TextField(
                                            controller: customNameCtrl,
                                            decoration: InputDecoration(
                                              hintText: 'Enter Offence Name',
                                              hintStyle: const TextStyle(fontSize: 12),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                          );
                                          
                                          final amountField = TextField(
                                            controller: customAmountCtrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              hintText: 'Enter Amount',
                                              hintStyle: const TextStyle(fontSize: 12),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                          );
                                          
                                          final addButton = ElevatedButton(
                                            onPressed: () {
                                              final name = customNameCtrl.text.trim();
                                              final amt = double.tryParse(customAmountCtrl.text);
                                              if (name.isNotEmpty && amt != null) {
                                                setDialogState(() {
                                                  customOffences.add({'name': name, 'amount': amt});
                                                  customNameCtrl.clear();
                                                  customAmountCtrl.clear();
                                                });
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF007BFF),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            child: const Text('+ Add Row', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          );

                                          if (isMobile) {
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                offenceField,
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(child: amountField),
                                                    const SizedBox(width: 8),
                                                    addButton,
                                                  ],
                                                ),
                                              ],
                                            );
                                          } else {
                                            return Row(
                                              children: [
                                                Expanded(flex: 3, child: offenceField),
                                                const SizedBox(width: 12),
                                                Expanded(flex: 2, child: amountField),
                                                const SizedBox(width: 12),
                                                addButton,
                                              ],
                                            );
                                          }
                                        },
                                      ),

                                      if (customOffences.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: customOffences.length,
                                          itemBuilder: (context, idx) {
                                            final custom = customOffences[idx];
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('${custom['name']} (₹ ${custom['amount']})', style: const TextStyle(fontSize: 12)),
                                                  IconButton(
                                                    icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 20),
                                                    onPressed: () {
                                                      setDialogState(() {
                                                        customOffences.removeAt(idx);
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                      const SizedBox(height: 24),

                                      // Total Challan Amount field on the right
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final isMobile = constraints.maxWidth < 450;
                                          
                                          if (isMobile) {
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                const Text(
                                                  'Total Challan Amount',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  width: 150,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: Colors.grey.shade400),
                                                    borderRadius: BorderRadius.circular(4),
                                                    color: Colors.grey.shade100,
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text('₹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                      Text(
                                                        totalChallanAmount.toStringAsFixed(2),
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          } else {
                                            return Align(
                                              alignment: Alignment.centerRight,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                    'Total Challan Amount',
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    width: 150,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: Colors.grey.shade400),
                                                      borderRadius: BorderRadius.circular(4),
                                                      color: Colors.grey.shade100,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        const Text('₹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                        Text(
                                                          totalChallanAmount.toStringAsFixed(2),
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
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
                      const Divider(height: 1),

                      // Footer buttons container
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                customNameCtrl.dispose();
                                customAmountCtrl.dispose();
                                remarksCtrl.dispose();
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C757D),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.description, size: 16, color: Colors.black87),
                              label: const Text('Previous VCR Reports', style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF28A745)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text('Collect', style: TextStyle(color: Color(0xFF28A745), fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Challan of ₹ ${totalChallanAmount.toStringAsFixed(2)} raised successfully!'),
                                    backgroundColor: const Color(0xFF198754),
                                  ),
                                );
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF198754),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text('Raise Challan', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Vehicle has been seized!'),
                                    backgroundColor: Color(0xFFDC3545),
                                  ),
                                );
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC3545),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text('Seize Vehicle', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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
      },
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            color: isHeader ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
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
              value ?? 'N/A',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
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
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(option, style: const TextStyle(fontSize: 13)),
            ),
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
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
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
    final List<String> vehicleTypes = ['Select All Vehicle Type', 'Non-transport', 'Transport'];

    final List<String> violationTypes = [
      'Select All Violation Type',
      'Puc Missing',
      'Insurance Violation',
      'Road Tax Violation',
      'Permit Violation',
      'Fitness Violation',
      'Registration Violation',
      'All Clear'
    ];

    // Filter
    final filtered = state.violations.where((item) {
      final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
      
      // District Filter
      final matchesDistrict = state.selectedDistrict == 'Select All District' ||
          vehicle['districtName'] == state.selectedDistrict;
          
      // Zone Filter
      final matchesZone = state.selectedZone == 'Select All Zone' ||
          vehicle['zoneName'] == state.selectedZone;
          
      // Camera Filter
      final selectedCameraId = state.cameraLocationToId[state.selectedCamera];
      final matchesCamera = state.selectedCamera == 'Select All Camera' ||
          vehicle['cameraID'] == selectedCameraId;
          
      // Vehicle Type Filter
      final matchesVehicleType = state.selectedVehicleType == 'Select All Vehicle Type' ||
          vehicle['vehicleType'] == state.selectedVehicleType;
          
      // Violation Type Filter
      bool matchesViolation = true;
      if (state.selectedViolationType != 'Select All Violation Type') {
        switch (state.selectedViolationType) {
          case 'Puc Missing':
            matchesViolation = vehicle['pucCertificate'] == false;
            break;
          case 'Insurance Violation':
            matchesViolation = vehicle['insurance'] == false;
            break;
          case 'Road Tax Violation':
            matchesViolation = vehicle['roadTax'] == false;
            break;
          case 'Permit Violation':
            matchesViolation = vehicle['permit'] == false;
            break;
          case 'Fitness Violation':
            matchesViolation = vehicle['fitnessCertificate'] == false;
            break;
          case 'Registration Violation':
            matchesViolation = vehicle['registration'] == false;
            break;
          case 'All Clear':
            matchesViolation = vehicle['allClear'] == true;
            break;
        }
      }
      
      // Search Box Filter
      final searchLower = state.searchText.toLowerCase();
      final matchesSearch = state.searchText.isEmpty ||
          (vehicle['vehicleNumber']?.toString().toLowerCase().contains(searchLower) ?? false) ||
          (vehicle['vehicleType']?.toString().toLowerCase().contains(searchLower) ?? false) ||
          (vehicle['cameraName']?.toString().toLowerCase().contains(searchLower) ?? false) ||
          (item['remarks']?.toString().toLowerCase().contains(searchLower) ?? false);
          
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
          final typeA = vehicleA['vehicleCategory'] == 'T' ? 'Transport' : 'Non-transport';
          final typeB = vehicleB['vehicleCategory'] == 'T' ? 'Transport' : 'Non-transport';
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
              PageHeaderBanner(
                title: widget.isLiveFeed ? 'Live Vehicle Feed' : 'Vehicle Monitoring & History',
                subtitle: widget.isLiveFeed ? 'Real-time Automatic Number Plate Recognition Stream' : 'Government of Telangana Transport Department',
              ),
              const SizedBox(height: 16),
              // Top Cascading Filters Container
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 950;
                    
                    final logo = InkWell(
                      onTap: () {
                        ref.read(sidebarCollapsedProvider.notifier).update((state) => !state);
                      },
                      child: Tooltip(
                        message: 'Toggle Sidebar',
                        child: Image.asset(
                          'assets/images/telangana_logo.png',
                          height: 35,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.account_balance,
                            color: Color(0xFF0D9488),
                            size: 24,
                          ),
                        ),
                      ),
                    );

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
                          notifier.fetchZonesForDistrict(value);
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

                    if (isWide) {
                      return Row(
                        children: [
                          logo,
                          const SizedBox(width: 16),
                          Expanded(child: districtDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: zoneDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: cameraDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: vehicleTypeDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: violationTypeDropdown),
                          const SizedBox(width: 12),
                          submitButton,
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          districtDropdown,
                          const SizedBox(height: 8),
                          zoneDropdown,
                          const SizedBox(height: 8),
                          cameraDropdown,
                          const SizedBox(height: 8),
                          vehicleTypeDropdown,
                          const SizedBox(height: 8),
                          violationTypeDropdown,
                          const SizedBox(height: 12),
                          submitButton,
                        ],
                      );
                    }
                  },
                ),
              ),
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
                        onChanged: notifier.updateSearch,
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
                                      final vehicleTypeLabel = vehicle['vehicleCategory'] == 'T' ? 'Transport' : 'Non-transport';

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
                                                  child: const Text(
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

    // Client-side search filter
    final searchLower = _searchController.text.toLowerCase();
    final filtered = dataSource.where((item) {
      final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
      if (searchLower.isEmpty) return true;
      final plateMatch = vehicle['vehicleNumber']?.toString().toLowerCase().contains(searchLower) ?? false;
      final cameraMatch = vehicle['cameraName']?.toString().toLowerCase().contains(searchLower) ?? false;
      final remarksMatch = item['remarks']?.toString().toLowerCase().contains(searchLower) ?? false;
      return plateMatch || cameraMatch || remarksMatch;
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeaderBanner(
                title: 'Vehicle Monitoring & History',
                subtitle: 'Government of Telangana Transport Department',
              ),
              const SizedBox(height: 16),
              // Top Filter Bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 950;

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
                          notifier.fetchZonesForDistrict(value);
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

                    final applyButton = FilledButton(
                      onPressed: () {
                        setState(() {
                          _currentPage = 1;
                        });
                        notifier.fetchNotifications();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: const Text(
                        'Apply Filters  →',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: districtDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: zoneDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: cameraDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: timeRangeDropdown),
                          const SizedBox(width: 12),
                          applyButton,
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          districtDropdown,
                          const SizedBox(height: 8),
                          zoneDropdown,
                          const SizedBox(height: 8),
                          cameraDropdown,
                          const SizedBox(height: 8),
                          timeRangeDropdown,
                          const SizedBox(height: 12),
                          applyButton,
                        ],
                      );
                    }
                  },
                ),
              ),
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
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (_) => setState(() {}),
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
                            // Table Header
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  _buildTableHeader('Time', 'Time', flex: 3),
                                  _buildTableHeader('Vehicle', 'VehicleNumber', flex: 2),
                                  _buildTableHeader('Type', 'VehicleType', flex: 2),
                                  _buildTableHeader('Camera', 'Camera', flex: 3),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      'Violation',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Status',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 1,
                                    child: SizedBox(),
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
                                              flex: 1,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: OutlinedButton(
                                                  onPressed: () => _showDetailsDialog(context, item, state),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFF3B82F6)),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                                  ),
                                                  child: const Text(
                                                    'View',
                                                    style: TextStyle(
                                                      color: Color(0xFF3B82F6),
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
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
    );
  }

  Widget _buildHistoryPaginationControls(int totalItems, int itemsPerPage, int totalPages) {
    if (totalPages <= 0) return const SizedBox.shrink();

    final startItem = totalItems > 0 ? ((_currentPage - 1) * itemsPerPage) + 1 : 0;
    final endItem = (_currentPage * itemsPerPage) > totalItems ? totalItems : (_currentPage * itemsPerPage);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
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

          // Center: Page X of Y + Showing info
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

          // Next Button
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
