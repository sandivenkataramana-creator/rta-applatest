import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'camera_health_model.dart';
import 'camera_health_provider.dart';

class CameraHealthScreen extends ConsumerStatefulWidget {
  const CameraHealthScreen({super.key});

  @override
  ConsumerState<CameraHealthScreen> createState() => _CameraHealthScreenState();
}

class _CameraHealthScreenState extends ConsumerState<CameraHealthScreen> {
  int? _selectedInterval;
  int _page = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraHealthNotifierProvider.notifier).load();
    });
  }

  void _syncSelectedInterval(CameraHealthModel? data) {
    if (_selectedInterval != null) {
      return;
    }
    final parsed = int.tryParse(data?.checkInterval ?? '');
    _selectedInterval = parsed ?? 15;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cameraHealthNotifierProvider);
    final notifier = ref.read(cameraHealthNotifierProvider.notifier);
    final filteredLocations = ref.watch(cameraHealthFilteredLocationsProvider);
    final width = MediaQuery.of(context).size.width;
    final isCompactPhone = width < 430;
    final isDesktop = width >= 900;
    _syncSelectedInterval(state.data);

    final totalPages = filteredLocations.isEmpty
        ? 1
        : (filteredLocations.length / _pageSize).ceil();
    final safePage = _page >= totalPages ? totalPages - 1 : _page;
    final startIndex = safePage * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(
      0,
      filteredLocations.length,
    );
    final pageItems = filteredLocations.isEmpty
        ? []
        : filteredLocations.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F7),
      appBar: AppBar(
        toolbarHeight: 120,
        backgroundColor: const Color(0xFF0F5D55),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Camera Health',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedInterval ?? 15,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Colors.white),
                        iconEnabledColor: Colors.white,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5 min')),
                          DropdownMenuItem(value: 10, child: Text('10 min')),
                          DropdownMenuItem(value: 15, child: Text('15 min')),
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 60, child: Text('60 min')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedInterval = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        state.isScanning ||
                            state.isLoading ||
                            state.isRefreshing
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final success = await notifier.scanNow();
                            if (!mounted) return;
                            if (success) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Camera scan completed successfully.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else if (state.error != null) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(state.error!),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      minimumSize: const Size(0, 38),
                    ),
                    icon: state.isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: const Text('Scan Now'),
                  ),
                  FilledButton(
                    onPressed:
                        state.isSaving ||
                            state.isScanning ||
                            state.isLoading ||
                            state.isRefreshing
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final selected = _selectedInterval ?? 15;
                            final success = await notifier.saveSettings(
                              selected,
                            );
                            if (!mounted) return;
                            if (success) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Settings saved successfully.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else if (state.error != null) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(state.error!),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F5D55),
                      minimumSize: const Size(0, 38),
                    ),
                    child: state.isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => notifier.refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.isLoading && state.data == null)
                const Center(child: CircularProgressIndicator())
              else if (state.error != null && state.data == null)
                _ErrorState(error: state.error!, onRetry: () => notifier.load())
              else
                Column(
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: isCompactPhone ? 2 : (isDesktop ? 4 : 2),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _MetricCard(
                          title: 'Total Cameras',
                          value: state.data?.totalCameras.toString() ?? '0',
                          icon: Icons.videocam_outlined,
                          color: const Color(0xFF0F5D55),
                        ),
                        _MetricCard(
                          title: 'Active',
                          value: state.data?.activeCameras.toString() ?? '0',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        _MetricCard(
                          title: 'Inactive',
                          value: state.data?.inactiveCameras.toString() ?? '0',
                          icon: Icons.cancel_outlined,
                          color: Colors.red,
                        ),
                        _MetricCard(
                          title: 'Last Scan',
                          value: _formatLastScan(state.data?.lastScanTime),
                          icon: Icons.schedule_outlined,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search district, zone or camera',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: const Color(0xFFF5F7F8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            onChanged: notifier.updateSearch,
                          ),
                          const SizedBox(height: 14),
                          if (state.isLoading && state.data != null)
                            const Center(child: CircularProgressIndicator())
                          else if (state.error != null && state.data != null)
                            _ErrorState(
                              error: state.error!,
                              onRetry: () => notifier.load(),
                            )
                          else if (filteredLocations.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('No camera data available'),
                              ),
                            )
                          else
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Camera Locations',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      '${pageItems.length} shown',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...pageItems.map(
                                  (location) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _CameraCard(location: location),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _PaginationControls(
                                  currentPage: safePage,
                                  totalPages: totalPages,
                                  onPageChanged: (value) {
                                    setState(() {
                                      _page = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastScan(String? value) {
    if (value == null || value.isEmpty) {
      return '--';
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      return value;
    }
    return '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)}\n${_formatTime(date)}';
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _monthName(int month) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.location});

  final CameraHealthLocation location;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = _normalizeStatus(location.status);
    final isActive = normalizedStatus == 'ACTIVE';
    final isInactive = normalizedStatus == 'INACTIVE';
    final badgeColor = isActive
        ? Colors.green
        : isInactive
        ? Colors.red
        : Colors.grey;
    final displayStatus = isActive
        ? 'ACTIVE'
        : isInactive
        ? 'INACTIVE'
        : (normalizedStatus.isEmpty ? 'UNKNOWN' : normalizedStatus);

    debugPrint(
      'CameraHealthUI: id=${location.id}, name=${location.camera}, apiStatus=${location.status}, parsedStatus=$normalizedStatus, displayStatus=$displayStatus',
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  location.camera.isEmpty ? 'Unnamed Camera' : location.camera,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusPill(label: displayStatus, color: badgeColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${location.district.isEmpty ? 'Unknown' : location.district} • ${location.zone.isEmpty ? 'Unknown' : location.zone}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location.lastDataTime.isEmpty
                      ? 'No data'
                      : location.lastDataTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _normalizeStatus(String? value) {
  final trimmedValue = value?.trim() ?? '';
  if (trimmedValue.isEmpty) {
    return '';
  }

  return trimmedValue
      .replaceAll(RegExp(r'[^A-Za-z]+'), ' ')
      .trim()
      .toUpperCase();
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final pages = List<int>.generate(totalPages, (index) => index);

    return Row(
      children: [
        OutlinedButton(
          onPressed: currentPage == 0
              ? null
              : () => onPageChanged(currentPage - 1),
          child: const Text('Previous'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: pages.map((page) {
                final isActive = page == currentPage;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onPageChanged(page),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF0F5D55)
                            : const Color(0xFFF3F6F7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${page + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: currentPage >= totalPages - 1
              ? null
              : () => onPageChanged(currentPage + 1),
          child: const Text('Next'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
