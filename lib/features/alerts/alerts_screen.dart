import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/loading_overlay.dart';
import '../../core/widgets/network_image_helper.dart';
import 'alerts_state.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  int _currentPage = 1;
  static const int _itemsPerPage = 10;
  String _sortColumn = 'Time';
  bool _sortAscending = false;
  final TextEditingController _searchController = TextEditingController();

  String _localDistrict = 'Select All District';
  String _localZone = 'Select All Zone';
  String _localCamera = 'Select All Camera';

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

  Widget _buildDropdownField({
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final String? safeValue = (value != null && options.contains(value)) ? value : (options.isNotEmpty ? options.first : null);
    return DropdownButtonFormField<String>(
      isExpanded: true,
      isDense: true,
      initialValue: safeValue,
      hint: Text(hint),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
      items: options.map((opt) => DropdownMenuItem<String>(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13)))).toList(),
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

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> item) {
    final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
    final vehicleNumber = vehicle['vehicleNumber']?.toString() ?? 'N/A';
    final cameraName = vehicle['cameraName']?.toString() ?? vehicle['cameraID']?.toString() ?? 'N/A';
    final cameraID = vehicle['cameraID']?.toString() ?? '';
    final detectedAt = _formatDateTime(vehicle['imageDetectionTime']?.toString());
    final imgUrl = vehicle['imageUrl']?.toString() ?? vehicle['vehicleImage']?.toString() ?? item['imageUrl']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFFF3F6F6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
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
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(color: const Color(0xFF0F3260), borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Text(vehicleNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: const Text('UNKNOWN', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ],
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
                          child: Container(
                            color: Colors.black12,
                            child: imgUrl.isNotEmpty
                                ? buildPlatformNetImage(imgUrl, fit: BoxFit.contain)
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
                                _buildDetailRow('Remarks', item['remarks']?.toString() ?? 'N/A'),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertsNotifierProvider);
    final notifier = ref.read(alertsNotifierProvider.notifier);

    final filtered = state.items.where((item) {
      final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
      final matchesDistrict = state.selectedDistrict == 'Select All District' || vehicle['districtName'] == state.selectedDistrict;
      final matchesZone = state.selectedZone == 'Select All Zone' || vehicle['zoneName'] == state.selectedZone;
      final selectedCameraId = state.cameraLocationToId[state.selectedCamera];
      final matchesCamera = state.selectedCamera == 'Select All Camera' || vehicle['cameraID'] == selectedCameraId;

      final searchLower = _searchController.text.toLowerCase();
      final matchesSearch = _searchController.text.isEmpty ||
          (vehicle['vehicleNumber']?.toString().toLowerCase().contains(searchLower) ?? false) ||
          (vehicle['cameraName']?.toString().toLowerCase().contains(searchLower) ?? false) ||
          (item['remarks']?.toString().toLowerCase().contains(searchLower) ?? false);

      return matchesDistrict && matchesZone && matchesCamera && matchesSearch;
    }).toList();

    if (_sortColumn.isNotEmpty) {
      filtered.sort((a, b) {
        final vehicleA = a['vehicle'] as Map<String, dynamic>? ?? {};
        final vehicleB = b['vehicle'] as Map<String, dynamic>? ?? {};
        int cmp = 0;
        if (_sortColumn == 'Time') {
          cmp = (vehicleA['createdTime']?.toString() ?? '').compareTo(vehicleB['createdTime']?.toString() ?? '');
        } else if (_sortColumn == 'VehicleNumber') {
          cmp = (vehicleA['vehicleNumber']?.toString() ?? '').compareTo(vehicleB['vehicleNumber']?.toString() ?? '');
        } else if (_sortColumn == 'Camera') {
          cmp = (vehicleA['cameraName']?.toString() ?? '').compareTo(vehicleB['cameraName']?.toString() ?? '');
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    final totalItems = filtered.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginated = filtered.sublist(startIndex, endIndex > totalItems ? totalItems : endIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F6),
      body: LoadingOverlay(
        isLoading: state.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: const BoxDecoration(color: Color(0xFFF3F6F6)),
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

                    final applyButton = FilledButton(
                      onPressed: () {
                        notifier.updateSelectedFilters(district: _localDistrict, zone: _localZone, camera: _localCamera);
                        setState(() => _currentPage = 1);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5D55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: const Text('Apply Filters  →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: districtDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: zoneDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: cameraDropdown),
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
                          const SizedBox(height: 12),
                          applyButton,
                        ],
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 14, color: Color(0xFFEF4444)),
                          SizedBox(width: 6),
                          Text('Details Not Found', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12)),
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
                              ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchController.clear()))
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
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
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
                            flex: 3,
                            child: Text('Remarks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const Expanded(
                            flex: 3,
                            child: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const Expanded(flex: 1, child: SizedBox()),
                        ],
                      ),
                    ),
                    paginated.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: Text('No details not found records matching search/filters.', style: TextStyle(color: Colors.black54))),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: paginated.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
                            itemBuilder: (context, index) {
                              final item = paginated[index] as Map<String, dynamic>? ?? {};
                              final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
                              final cameraName = vehicle['cameraName']?.toString() ?? vehicle['cameraID']?.toString() ?? 'N/A';

                              return Container(
                                color: index % 2 == 0 ? Colors.white : const Color(0xFFF7FAFA),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(_formatDateTime(vehicle['createdTime']?.toString()), style: const TextStyle(fontSize: 13, color: Colors.black87)),
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
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
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
                                          decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(4)),
                                          child: const Text('UNKNOWN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(cameraName, style: const TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                          child: const Text('DETAILS NOT FOUND.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                          child: const Text('DETAILS NOT FOUND', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: OutlinedButton(
                                          onPressed: () => _showDetailsDialog(context, item),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF0F5D55)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          child: const Text('View', style: TextStyle(color: Color(0xFF0F5D55), fontWeight: FontWeight.bold, fontSize: 13)),
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
              _buildPaginationControls(totalItems, _itemsPerPage, totalPages),
            ],
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
              color: isCurrent ? const Color(0xFF0F5D55) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isCurrent ? const Color(0xFF0F5D55) : Colors.grey.shade300),
            ),
            child: Text('$i', style: TextStyle(color: isCurrent ? Colors.white : Colors.black87, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Showing $startItem-$endItem of $totalItems records', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Row(
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
          ),
        ],
      ),
    );
  }
}
