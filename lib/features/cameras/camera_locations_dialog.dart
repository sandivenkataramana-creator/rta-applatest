import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/pdf_helper.dart';
import 'camera_health_model.dart';
import 'camera_health_provider.dart';

class CameraLocationsDialog extends ConsumerStatefulWidget {
  const CameraLocationsDialog({super.key});

  @override
  ConsumerState<CameraLocationsDialog> createState() =>
      _CameraLocationsDialogState();
}

class _CameraLocationsDialogState extends ConsumerState<CameraLocationsDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDistrict = 'All Districts';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openMap(String? url) async {
    if (url == null || url.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map location URL is not available for this camera.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      await PdfHelper.displayOrDownloadPdf(url, 'google_maps');
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Map opened / Link copied: $url'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _exportCsv(List<CameraLocationItem> list) async {
    final StringBuffer csv = StringBuffer();
    csv.writeln(
      '#,District,Place / Location,Camera ID,Latitude,Longitude,Map Location,Channel,Status',
    );
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      final lat = (item.latitude ?? '').replaceAll('"', '""');
      final lon = (item.longitude ?? '').replaceAll('"', '""');
      final dist = (item.districtName ?? '').replaceAll('"', '""');
      final loc = item.cameraLocation.replaceAll('"', '""');
      final cam = item.cameraID.replaceAll('"', '""');
      final mapLink = (item.googleMapLink ?? '').replaceAll('"', '""');
      final chan = (item.channelName ?? '').replaceAll('"', '""');
      final status = item.status ? 'Active' : 'Inactive';
      csv.writeln(
        '${i + 1},"$dist","$loc","$cam","$lat","$lon","$mapLink","$chan","$status"',
      );
    }
    final bytes = Uint8List.fromList(utf8.encode(csv.toString()));
    final filename =
        'camera_locations_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    await PdfHelper.displayOrDownloadPdf(bytes, filename, context: context);
  }

  @override
  Widget build(BuildContext context) {
    final asyncCameras = ref.watch(allCameraLocationsProvider);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1050,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: asyncCameras.when(
          loading:
              () => const SizedBox(
                height: 350,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF0D9488)),
                      SizedBox(height: 16),
                      Text(
                        'Loading Camera Locations...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          error:
              (err, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load camera locations',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed:
                              () => ref.invalidate(allCameraLocationsProvider),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          data: (allCameras) {
            // Extract unique districts
            final districtsSet = <String>{};
            for (final cam in allCameras) {
              if (cam.districtName != null &&
                  cam.districtName!.trim().isNotEmpty) {
                districtsSet.add(cam.districtName!.trim());
              }
            }
            final districts = districtsSet.toList()..sort();

            // Filter
            final query = _searchQuery.trim().toLowerCase();
            final filtered =
                allCameras.where((c) {
                  final matchesDistrict =
                      _selectedDistrict == 'All Districts' ||
                      (c.districtName != null &&
                          c.districtName!.toLowerCase() ==
                              _selectedDistrict.toLowerCase());
                  if (!matchesDistrict) return false;

                  if (query.isEmpty) return true;

                  final dist = (c.districtName ?? '').toLowerCase();
                  final place = c.cameraLocation.toLowerCase();
                  final id = c.cameraID.toLowerCase();
                  final channel = (c.channelName ?? '').toLowerCase();
                  final office = (c.officeName ?? '').toLowerCase();

                  return dist.contains(query) ||
                      place.contains(query) ||
                      id.contains(query) ||
                      channel.contains(query) ||
                      office.contains(query);
                }).toList();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 14 : 20,
                    14,
                    isMobile ? 12 : 16,
                    12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: isMobile ? 38 : 44,
                        height: isMobile ? 38 : 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.location_on,
                            color: const Color(0xFF0D9488),
                            size: isMobile ? 20 : 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'All Camera Locations & Districts',
                              style: TextStyle(
                                fontSize: isMobile ? 15 : 17,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Overview of all 30 locations and 60 cameras with GPS coordinates and maps',
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F7F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF99F6E4)),
                        ),
                        child: Text(
                          '${allCameras.length} Records',
                          style: const TextStyle(
                            color: Color(0xFF0D9488),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                // Controls Bar
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 20,
                    12,
                    isMobile ? 12 : 20,
                    12,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 620;

                      final searchWidget = SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            hintText:
                                'Search by District, Place, Camera ID, Channel...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12.5,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF94A3B8),
                              size: 18,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 34,
                            ),
                            suffixIcon:
                                _searchQuery.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                    : null,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF0D9488),
                                width: 1.4,
                              ),
                            ),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      );

                      final districtDropdown = Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF0D9488),
                            width: 1.4,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDistrict,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF0D9488),
                              size: 18,
                            ),
                            isDense: true,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'All Districts',
                                child: Text(
                                  'All Districts',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...districts.map(
                                (d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(
                                    d,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDistrict = val);
                              }
                            },
                          ),
                        ),
                      );

                      final exportButton = OutlinedButton.icon(
                        onPressed: () => _exportCsv(filtered),
                        icon: const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF0D9488),
                          size: 15,
                        ),
                        label: const Text(
                          'Export CSV',
                          style: TextStyle(
                            color: Color(0xFF0D9488),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF0D9488),
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 38),
                        ),
                      );

                      final refreshButton = OutlinedButton.icon(
                        onPressed:
                            () => ref.invalidate(allCameraLocationsProvider),
                        icon: const Icon(
                          Icons.refresh,
                          color: Color(0xFF334155),
                          size: 15,
                        ),
                        label: const Text(
                          'Refresh',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 38),
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            searchWidget,
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: districtDropdown),
                                const SizedBox(width: 6),
                                exportButton,
                                const SizedBox(width: 6),
                                refreshButton,
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(flex: 3, child: searchWidget),
                          const SizedBox(width: 8),
                          Expanded(flex: 2, child: districtDropdown),
                          const SizedBox(width: 8),
                          exportButton,
                          const SizedBox(width: 8),
                          refreshButton,
                        ],
                      );
                    },
                  ),
                ),

                // Table Header & Rows
                Expanded(
                  child:
                      filtered.isEmpty
                          ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No matching camera locations found.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                          : LayoutBuilder(
                            builder: (context, tableConstraints) {
                              return SizedBox(
                                height: tableConstraints.maxHeight,
                                child: Scrollbar(
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: 1265,
                                      height: tableConstraints.maxHeight,
                                      child: Column(
                                        children: [
                                          // Table Header Row
                                          Container(
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                top: BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                                bottom: BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            child: const Row(
                                        children: [
                                          SizedBox(
                                            width: 45,
                                            child: Text(
                                              '#',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 180,
                                            child: Text(
                                              'District',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 170,
                                            child: Text(
                                              'Place / Location',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              'Camera ID',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 130,
                                            child: Text(
                                              'Latitude',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 130,
                                            child: Text(
                                              'Longitude',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 130,
                                            child: Text(
                                              'Map Location',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 220,
                                            child: Text(
                                              'Channel',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              'Status',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Table Rows
                                    Expanded(
                                      child: ListView.separated(
                                        itemCount: filtered.length,
                                        separatorBuilder:
                                            (context, _) => const Divider(
                                              height: 1,
                                              thickness: 1,
                                              color: Color(0xFFF1F5F9),
                                            ),
                                        itemBuilder: (context, index) {
                                          final item = filtered[index];
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 45,
                                                  child: Text(
                                                    '${index + 1}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF475569),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 180,
                                                  child: Text(
                                                    item.districtName ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 170,
                                                  child: Text(
                                                    item.cameraLocation,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF334155),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 110,
                                                  child: Text(
                                                    item.cameraID,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 130,
                                                  child: Text(
                                                    item.latitude ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF334155),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 130,
                                                  child: Text(
                                                    item.longitude ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF334155),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 130,
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: InkWell(
                                                      onTap: () => _openMap(item.googleMapLink),
                                                      borderRadius: BorderRadius.circular(20),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(
                                                            color: const Color(0xFF0D9488),
                                                            width: 1.2,
                                                          ),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons.location_on,
                                                              color: Color(0xFFE11D48),
                                                              size: 15,
                                                            ),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'View Map',
                                                              style: TextStyle(
                                                                color: Color(0xFF0D9488),
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 220,
                                                  child: Text(
                                                    (item.channelName != null &&
                                                            item.channelName!.trim().isNotEmpty)
                                                        ? item.channelName!
                                                        : '-',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF334155),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 110,
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: item.status
                                                            ? const Color(0xFFE6F7F0)
                                                            : const Color(0xFFFFECEB),
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Text(
                                                        item.status ? 'Active' : 'Inactive',
                                                        style: TextStyle(
                                                          color: item.status
                                                              ? const Color(0xFF166534)
                                                              : const Color(0xFFB91C1C),
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
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
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ),

                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Showing ${filtered.length} of ${allCameras.length} cameras',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF475569),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
