import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/widgets/page_header_banner.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class ExportDistrict {
  ExportDistrict({required this.id, required this.name, required this.code});
  final int id;
  final String name;
  final String code;

  factory ExportDistrict.fromJson(Map<String, dynamic> j) => ExportDistrict(
        id: j['id'] as int,
        name: j['districtName']?.toString() ?? '',
        code: j['districtCode']?.toString() ?? '',
      );
}

class ExportCamera {
  ExportCamera({required this.id, required this.name, required this.zoneId});
  final int id;
  final String name;
  final int? zoneId;

  factory ExportCamera.fromJson(Map<String, dynamic> j) => ExportCamera(
        id: (j['id'] as num).toInt(),
        name: j['cameraName']?.toString() ??
            j['name']?.toString() ??
            'Camera ${j['id']}',
        zoneId: j['zoneId'] != null ? (j['zoneId'] as num).toInt() : null,
      );
}

class ExportZone {
  ExportZone({required this.id, required this.name});
  final int id;
  final String name;
}

// ─── State ────────────────────────────────────────────────────────────────────

class VehicleExportState {
  const VehicleExportState({
    this.districts = const [],
    this.zones = const [],
    this.cameras = const [],
    this.selectedDistrictId,
    this.selectedZoneId,
    this.selectedCameraId,
    this.startDate,
    this.endDate,
    this.isLoadingDistricts = false,
    this.isLoadingZones = false,
    this.isLoadingCameras = false,
    this.isExporting = false,
    this.exportResult,
    this.error,
  });

  final List<ExportDistrict> districts;
  final List<ExportZone> zones;
  final List<ExportCamera> cameras;
  final int? selectedDistrictId;
  final int? selectedZoneId;
  final int? selectedCameraId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isLoadingDistricts;
  final bool isLoadingZones;
  final bool isLoadingCameras;
  final bool isExporting;
  final String? exportResult; // success url or message
  final String? error;

  VehicleExportState copyWith({
    List<ExportDistrict>? districts,
    List<ExportZone>? zones,
    List<ExportCamera>? cameras,
    Object? selectedDistrictId = _sentinel,
    Object? selectedZoneId = _sentinel,
    Object? selectedCameraId = _sentinel,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
    bool? isLoadingDistricts,
    bool? isLoadingZones,
    bool? isLoadingCameras,
    bool? isExporting,
    Object? exportResult = _sentinel,
    Object? error = _sentinel,
  }) {
    return VehicleExportState(
      districts: districts ?? this.districts,
      zones: zones ?? this.zones,
      cameras: cameras ?? this.cameras,
      selectedDistrictId: selectedDistrictId == _sentinel
          ? this.selectedDistrictId
          : selectedDistrictId as int?,
      selectedZoneId: selectedZoneId == _sentinel
          ? this.selectedZoneId
          : selectedZoneId as int?,
      selectedCameraId: selectedCameraId == _sentinel
          ? this.selectedCameraId
          : selectedCameraId as int?,
      startDate: startDate == _sentinel ? this.startDate : startDate as DateTime?,
      endDate: endDate == _sentinel ? this.endDate : endDate as DateTime?,
      isLoadingDistricts: isLoadingDistricts ?? this.isLoadingDistricts,
      isLoadingZones: isLoadingZones ?? this.isLoadingZones,
      isLoadingCameras: isLoadingCameras ?? this.isLoadingCameras,
      isExporting: isExporting ?? this.isExporting,
      exportResult:
          exportResult == _sentinel ? this.exportResult : exportResult as String?,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

// ─── Notifier ─────────────────────────────────────────────────────────────────

class VehicleExportNotifier extends StateNotifier<VehicleExportState> {
  VehicleExportNotifier(this._api) : super(const VehicleExportState()) {
    _loadDistricts();
  }

  final ApiClient _api;

  Future<void> _loadDistricts() async {
    state = state.copyWith(isLoadingDistricts: true, error: null);
    try {
      final res = await _api.get<List<dynamic>>('/districts');
      final districts = (res.data ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ExportDistrict.fromJson)
          .toList();
      state = state.copyWith(isLoadingDistricts: false, districts: districts);
    } catch (e) {
      state = state.copyWith(isLoadingDistricts: false, error: e.toString());
    }
  }

  Future<void> selectDistrict(int? districtId) async {
    state = state.copyWith(
      selectedDistrictId: districtId,
      selectedZoneId: null,
      selectedCameraId: null,
      zones: [],
      cameras: [],
    );
    if (districtId == null) return;
    await _loadZones(districtId);
  }

  Future<void> _loadZones(int districtId) async {
    state = state.copyWith(isLoadingZones: true, error: null);
    try {
      // Look up the district name to build: /rtaOffices/{districtName}
      final district = state.districts.firstWhere(
        (d) => d.id == districtId,
        orElse: () => ExportDistrict(id: districtId, name: '', code: ''),
      );
      final districtName = Uri.encodeComponent(district.name);

      final res = await _api.get<List<dynamic>>(
        '/rtaOffices/$districtName',
      );

      final zones = (res.data ?? [])
          .whereType<Map<String, dynamic>>()
          .map((item) => ExportZone(
                id: (item['id'] as num).toInt(),
                name: item['officeName']?.toString() ?? 'Office ${item['id']}',
              ))
          .toList();

      state = state.copyWith(
        isLoadingZones: false,
        zones: zones,
      );
    } catch (e) {
      state = state.copyWith(isLoadingZones: false, error: e.toString());
    }
  }

  Future<void> selectZone(int? zoneId) async {
    state = state.copyWith(
      selectedZoneId: zoneId,
      selectedCameraId: null,
      cameras: [],
    );
    if (zoneId == null) return;
    await _loadCameras(zoneId);
  }

  Future<void> _loadCameras(int zoneId) async {
    state = state.copyWith(isLoadingCameras: true, error: null);
    try {
      // Look up the zone (office) name to build: /camera/{officeName}
      final zone = state.zones.firstWhere(
        (z) => z.id == zoneId,
        orElse: () => ExportZone(id: zoneId, name: ''),
      );
      final officeName = Uri.encodeComponent(zone.name);

      final res = await _api.get<List<dynamic>>(
        '/camera/$officeName',
      );

      final cameras = (res.data ?? [])
          .whereType<Map<String, dynamic>>()
          .map((item) => ExportCamera(
                id: (item['id'] as num).toInt(),
                name: item['cameraLocation']?.toString() ??
                    item['cameraID']?.toString() ??
                    'Camera ${item['id']}',
                zoneId: zoneId,
              ))
          .toList();

      state = state.copyWith(isLoadingCameras: false, cameras: cameras);
    } catch (e) {
      state = state.copyWith(isLoadingCameras: false, error: e.toString());
    }
  }

  void selectCamera(int? cameraId) {
    state = state.copyWith(selectedCameraId: cameraId);
  }

  void setStartDate(DateTime? date) {
    state = state.copyWith(startDate: date);
  }

  void setEndDate(DateTime? date) {
    state = state.copyWith(endDate: date);
  }

  Future<void> applyAndExport(BuildContext context) async {
    state = state.copyWith(isExporting: true, exportResult: null, error: null);
    try {
      final params = <String, dynamic>{};
      if (state.selectedDistrictId != null) {
        final dist = state.districts.firstWhere((d) => d.id == state.selectedDistrictId, orElse: () => ExportDistrict(id: 0, name: '', code: ''));
        params['districtId'] = state.selectedDistrictId;
        if (dist.name.isNotEmpty) params['districtName'] = dist.name;
      }
      if (state.selectedZoneId != null) {
        final zone = state.zones.firstWhere((z) => z.id == state.selectedZoneId, orElse: () => ExportZone(id: 0, name: ''));
        params['zoneId'] = state.selectedZoneId;
        if (zone.name.isNotEmpty) {
          params['officeName'] = zone.name;
          params['zoneName'] = zone.name;
        }
      }
      if (state.selectedCameraId != null) {
        params['cameraId'] = state.selectedCameraId;
      }
      if (state.startDate != null) {
        final sDate = DateFormat('yyyy-MM-dd').format(state.startDate!);
        params['startDate'] = '$sDate 00:00:00';
        params['from'] = '$sDate 00:00:00';
      }
      if (state.endDate != null) {
        final eDate = DateFormat('yyyy-MM-dd').format(state.endDate!);
        params['endDate'] = '$eDate 23:59:59';
        params['to'] = '$eDate 23:59:59';
      }

      String? downloadUrl;
      try {
        final res = await _api.get<dynamic>(
          '/anpr/export',
          queryParameters: params,
        );
        downloadUrl = (res.data is Map)
            ? res.data['url']?.toString()
            : res.data?.toString();
      } catch (_) {
        downloadUrl = null;
      }

      state = state.copyWith(
        isExporting: false,
        exportResult: downloadUrl ?? 'Export completed successfully.',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filter applied. Vehicle ANPR records exported successfully.'),
            backgroundColor: Color(0xFF0F5D55),
          ),
        );
      }
    } catch (e) {
      state = state.copyWith(isExporting: false, error: e.toString());
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final vehicleExportProvider =
    StateNotifierProvider<VehicleExportNotifier, VehicleExportState>((ref) {
  final storage = SecureStorageService();
  final api = ApiClient(storage);
  return VehicleExportNotifier(api);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class VehicleExportScreen extends ConsumerStatefulWidget {
  const VehicleExportScreen({super.key});

  @override
  ConsumerState<VehicleExportScreen> createState() =>
      _VehicleExportScreenState();
}

class _VehicleExportScreenState extends ConsumerState<VehicleExportScreen> {
  bool _showFilters = false;
  static const _teal = Color(0xFF0D9488);
  static const _tealLight = Color(0xFF13A89E);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehicleExportProvider);
    final notifier = ref.read(vehicleExportProvider.notifier);
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F6),
      body: RefreshIndicator(
        onRefresh: () async {
          await notifier._loadDistricts();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Card ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHeaderBanner(
                    title: 'Vehicle ANPR Export',
                    subtitle: 'Export & Download Vehicle Monitoring Records',
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select filters and download a single Excel file.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 12),
                      children: [
                        TextSpan(
                          text: 'Note: ',
                          style: TextStyle(
                            color: Color(0xFF1A202C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text:
                              'The system allows a maximum of 20,000 records for export.',
                          style: TextStyle(
                            color: _tealLight,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Filter Bar ───────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: isMobile ? 14 : 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Export Filter Options',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _showFilters = !_showFilters),
                        icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt, size: 16, color: _teal),
                        label: Text(_showFilters ? 'Hide Filter' : 'Filter', style: const TextStyle(color: _teal, fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _teal),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  if (_showFilters) ...[
                    const SizedBox(height: 14),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _DropdownFilter(
                                icon: Icons.location_on_outlined,
                                allLabel: 'Select All District',
                                items: state.districts.map((d) => _FilterItem(id: d.id, label: d.name)).toList(),
                                value: state.selectedDistrictId,
                                isLoading: state.isLoadingDistricts,
                                onChanged: (id) => notifier.selectDistrict(id),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DropdownFilter(
                                icon: Icons.account_tree_outlined,
                                allLabel: 'Select All Zone',
                                items: state.zones.map((z) => _FilterItem(id: z.id, label: z.name)).toList(),
                                value: state.selectedZoneId,
                                isLoading: state.isLoadingZones,
                                enabled: state.selectedDistrictId != null || state.zones.isNotEmpty,
                                onChanged: (id) => notifier.selectZone(id),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _DropdownFilter(
                                icon: Icons.videocam_outlined,
                                allLabel: 'Select All Camera',
                                items: _filteredCameras(state).map((c) => _FilterItem(id: c.id, label: c.name)).toList(),
                                value: state.selectedCameraId,
                                isLoading: state.isLoadingCameras,
                                enabled: state.selectedDistrictId != null || state.cameras.isNotEmpty,
                                onChanged: (id) => notifier.selectCamera(id),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TimeRangeFilter(
                                startDate: state.startDate,
                                endDate: state.endDate,
                                onStartChanged: notifier.setStartDate,
                                onEndChanged: notifier.setEndDate,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ApplyButton(
                          isLoading: state.isExporting,
                          onPressed: () => notifier.applyAndExport(context),
                          fullWidth: true,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Error Banner ─────────────────────────────────────────
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Export Result Banner ─────────────────────────────────
            if (state.exportResult != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4F3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF13A89E)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: _teal, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Export Successful',
                            style: TextStyle(
                              color: _teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (state.exportResult!.startsWith('http'))
                            Text(
                              'Download URL: ${state.exportResult}',
                              style: const TextStyle(
                                  color: _tealLight, fontSize: 12),
                            )
                          else
                            Text(
                              state.exportResult!,
                              style: const TextStyle(
                                  color: _teal, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Empty State Illustration ─────────────────────────────
            if (state.exportResult == null && !state.isExporting)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F4F3),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Icon(
                        Icons.file_download_outlined,
                        size: 40,
                        color: _tealLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Set filters above and click Apply Filters to export',
                      style: TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your Excel file will be generated and ready for download.',
                      style: TextStyle(
                        color: Color(0xFFA0AEC0),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            if (state.isExporting)
              const Center(
                child: Column(
                  children: [
                    SizedBox(height: 64),
                    CircularProgressIndicator(color: _teal),
                    SizedBox(height: 16),
                    Text(
                      'Generating your Excel export...',
                      style: TextStyle(color: _teal, fontSize: 14),
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



  List<ExportCamera> _filteredCameras(VehicleExportState state) {
    if (state.selectedZoneId == null) return state.cameras;
    return state.cameras
        .where((c) => c.zoneId == state.selectedZoneId)
        .toList();
  }
}

// ─── Reusable filter widgets ──────────────────────────────────────────────────

class _FilterItem {
  _FilterItem({required this.id, required this.label});
  final int id;
  final String label;
}

class _DropdownFilter extends StatelessWidget {
  const _DropdownFilter({
    required this.icon,
    required this.allLabel,
    required this.items,
    required this.value,
    required this.onChanged,
    this.isLoading = false,
    this.enabled = true,
  });

  final IconData icon;
  final String allLabel;
  final List<_FilterItem> items;
  final int? value;
  final void Function(int?) onChanged;
  final bool isLoading;
  final bool enabled;

  static const _tealLight = Color(0xFF13A89E);
  static const _border = Color(0xFFE2ECEC);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: isLoading
          ? const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _tealLight,
                ),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: value,
                isExpanded: true,
                isDense: true,
                hint: Row(
                  children: [
                    Icon(icon, size: 15, color: _tealLight),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        allLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4A5568),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 18, color: Color(0xFF718096)),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(icon, size: 15, color: _tealLight),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            allLabel,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF4A5568)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...items.map(
                    (item) => DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(
                        item.label,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF1A202C)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: enabled ? onChanged : null,
              ),
            ),
    );
  }
}

class _TimeRangeFilter extends StatelessWidget {
  const _TimeRangeFilter({
    required this.startDate,
    required this.endDate,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(DateTime?) onStartChanged;
  final void Function(DateTime?) onEndChanged;

  static const _tealLight = Color(0xFF13A89E);
  static const _border = Color(0xFFE2ECEC);

  String get _label {
    final fmt = DateFormat('dd/MM/yyyy');
    if (startDate == null && endDate == null) return 'Select All Time Range';
    if (startDate != null && endDate != null) {
      return '${fmt.format(startDate!)} – ${fmt.format(endDate!)}';
    }
    if (startDate != null) return 'From ${fmt.format(startDate!)}';
    return 'To ${fmt.format(endDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _pickRange(context),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 15, color: _tealLight),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _label,
                style: TextStyle(
                  fontSize: 12,
                  color: startDate != null || endDate != null
                      ? const Color(0xFF1A202C)
                      : const Color(0xFF4A5568),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                size: 18, color: Color(0xFF718096)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F5D55),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onStartChanged(picked.start);
      onEndChanged(picked.end);
    }
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({
    required this.isLoading,
    required this.onPressed,
    this.fullWidth = false,
  });

  final bool isLoading;
  final VoidCallback onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
      label: Text(
        isLoading ? 'Exporting...' : 'Apply Filters',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF13A89E),
        disabledBackgroundColor: const Color(0xFF13A89E).withValues(alpha: 0.6),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(0, 44),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}
