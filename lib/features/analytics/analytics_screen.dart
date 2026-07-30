import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/widgets/loading_overlay.dart';
import '../../core/widgets/page_header_banner.dart';
import '../dashboard/dashboard_notifier.dart';
import 'budget_state.dart';

class MonthlyRevenueData {
  MonthlyRevenueData(this.month, this.revenue, this.color);
  final String month;
  final double revenue;
  final Color color;
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedDistrict = 'Select All District';
  String _selectedZone = 'Select All Zone';
  String _selectedCamera = 'Select All Camera';
  String _selectedTimeRange = 'Select All Time Range';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  final List<String> _timeRanges = [
    'Select All Time Range',
    'Today',
    'Yesterday',
    'Last 7 Days',
    'Monthly',
    'Custom'
  ];

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D9488),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedTimeRange = 'Custom';
      });
    }
  }

  String _formatAmount(dynamic val) {
    if (val == null) return '₹ 0';
    final numVal = double.tryParse(val.toString()) ?? 0.0;
    if (numVal == 0.0) return '₹ 0';
    final format = NumberFormat.decimalPattern('en_US');
    return '₹ ${format.format(numVal.toInt())}';
  }

  Widget _buildTopCard({
    required IconData icon,
    required String value,
    required String subtitle,
    required Color cardBg,
    bool isMobile = false,
  }) {
    final card = Container(
      width: isMobile ? 240 : null,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
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

  Widget _buildViolationCard({
    required String title,
    required String amount,
    required Color borderColor,
    required Color bgLight,
    bool isMobile = false,
  }) {
    final card = Container(
      width: isMobile ? 160 : null,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF718096),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Total Revenue Generated',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFFA0AEC0),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (isMobile) return card;
    return Expanded(child: card);
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    double? width,
    Widget? suffix,
  }) {
    final String? safeValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      height: 42,
      width: width,
      child: DropdownButtonFormField<String>(
        key: ValueKey('${value}_${items.length}'),
        initialValue: safeValue,
        isExpanded: true,
        isDense: true,
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Icon(icon, size: 14, color: Colors.grey.shade500),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 20),
          suffixIcon: suffix != null
              ? Padding(padding: const EdgeInsets.only(right: 28), child: suffix)
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _onApplyFilters(DashboardState dashboardState) {
    final cameraID = dashboardState.cameraLocationToId[_selectedCamera];
    final notifier = ref.read(budgetNotifierProvider.notifier);
    notifier.updateFilters(
      district: _selectedDistrict,
      zone: _selectedZone,
      camera: cameraID ?? _selectedCamera,
      timeRange: _selectedTimeRange,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
    );
    notifier.applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetNotifierProvider);

    // Live dashboard state for district, zone, camera options
    final dashboardState = ref.watch(dashboardNotifierProvider);

    final districtOptions = dashboardState.districts;
    final zoneOptions = dashboardState.zones;
    final cameraOptions = dashboardState.cameras;

    // Prepare chart series
    final List<MonthlyRevenueData> chartData = [];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final colors = [
      Colors.teal.shade100,
      Colors.teal.shade100,
      Colors.teal.shade100,
      Colors.teal.shade100,
      const Color(0xFF6366F1), // Indigo for Month 5
      const Color(0xFFEC4899), // Pink for Month 6
      const Color(0xFFF59E0B), // Yellow for Month 7
      Colors.teal.shade100,
      Colors.teal.shade100,
      Colors.teal.shade100,
      Colors.teal.shade100,
      Colors.teal.shade100,
    ];
    for (int i = 0; i < 12; i++) {
      final monthKey = (i + 1).toString();
      final revVal = state.monthlyRevenue[monthKey] ?? 0.0;
      chartData.add(MonthlyRevenueData(months[i], revVal, colors[i]));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F6),
      body: LoadingOverlay(
        isLoading: state.isLoading,
        child: RefreshIndicator(
          onRefresh: () async {
            _onApplyFilters(dashboardState);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeaderBanner(
                  title: 'Budget & Revenue Analytics',
                  subtitle: 'Government of Telangana Transport Department',
                ),
                const SizedBox(height: 16),
                // Top Filters Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobileFilters = MediaQuery.of(context).size.width < 750;

                    final districtDropdown = _buildFilterDropdown(
                      value: _selectedDistrict,
                      items: districtOptions,
                      icon: Icons.location_on_outlined,
                      onChanged: (val) async {
                        setState(() {
                          _selectedDistrict = val ?? 'Select All District';
                          _selectedZone = 'Select All Zone';
                          _selectedCamera = 'Select All Camera';
                        });
                        if (val != null && val != 'Select All District') {
                          final autoZone = await ref.read(dashboardNotifierProvider.notifier).fetchZonesForDistrict(val);
                          if (autoZone != null && mounted) {
                            setState(() => _selectedZone = autoZone);
                            ref.read(dashboardNotifierProvider.notifier).fetchCamerasForZone(autoZone);
                          }
                        } else {
                          ref.read(dashboardNotifierProvider.notifier).resetZones();
                        }
                        ref.read(dashboardNotifierProvider.notifier).resetCameras();
                      },
                      width: isMobileFilters ? 140 : null,
                    );

                    final zoneDropdown = _buildFilterDropdown(
                      value: _selectedZone,
                      items: zoneOptions,
                      icon: Icons.grid_view_outlined,
                      onChanged: (val) {
                        setState(() {
                          _selectedZone = val ?? 'Select All Zone';
                          _selectedCamera = 'Select All Camera';
                        });
                        if (val != null && val != 'Select All Zone') {
                          ref.read(dashboardNotifierProvider.notifier).fetchCamerasForZone(val);
                        } else {
                          ref.read(dashboardNotifierProvider.notifier).resetCameras();
                        }
                      },
                      width: isMobileFilters ? 140 : null,
                    );

                    final cameraDropdown = _buildFilterDropdown(
                      value: _selectedCamera,
                      items: cameraOptions,
                      icon: Icons.videocam_outlined,
                      onChanged: (val) {
                        setState(() {
                          _selectedCamera = val ?? 'Select All Camera';
                        });
                      },
                      width: isMobileFilters ? 140 : null,
                    );

                    final timeRangeDropdown = _buildFilterDropdown(
                      value: _selectedTimeRange,
                      items: _timeRanges,
                      icon: Icons.calendar_today_outlined,
                      onChanged: (val) {
                        if (val == 'Custom') {
                          _pickCustomDateRange(context);
                        } else {
                          setState(() {
                            _selectedTimeRange = val ?? 'Select All Time Range';
                            _customStartDate = null;
                            _customEndDate = null;
                          });
                        }
                      },
                      width: isMobileFilters ? 140 : null,
                      suffix: _selectedTimeRange == 'Custom' && _customStartDate != null
                          ? Text(
                              '${_customStartDate!.day}/${_customStartDate!.month} – ${_customEndDate!.day}/${_customEndDate!.month}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF0D9488)),
                            )
                          : null,
                    );

                    final applyBtn = SizedBox(
                      height: 42,
                      width: isMobileFilters ? double.infinity : null,
                      child: FilledButton.icon(
                        onPressed: () => _onApplyFilters(dashboardState),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    );

                    if (isMobileFilters) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5ECEC), width: 1.2),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  districtDropdown,
                                  zoneDropdown,
                                  cameraDropdown,
                                  timeRangeDropdown,
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            applyBtn,
                          ],
                        ),
                      );
                    } else {
                      return Row(
                        children: [
                          Expanded(child: districtDropdown),
                          Expanded(child: zoneDropdown),
                          Expanded(child: cameraDropdown),
                          Expanded(child: timeRangeDropdown),
                          const SizedBox(width: 8),
                          applyBtn,
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Summary Metrics Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = MediaQuery.of(context).size.width < 900;
                    final cards = [
                      _buildTopCard(
                        icon: Icons.directions_car_outlined,
                        value: _formatAmount(state.summary['totalAmount'] ?? state.summary['echallanAmount']),
                        subtitle: 'TOTAL AMOUNT GENERATED',
                        cardBg: const Color(0xFFE54E80),
                        isMobile: isMobile,
                      ),
                      _buildTopCard(
                        icon: Icons.receipt_long_outlined,
                        value: _formatAmount(state.summary['echallanAmount']),
                        subtitle: 'E-CHALLAN AMOUNT GENERATED',
                        cardBg: const Color(0xFF8B5CF6),
                        isMobile: isMobile,
                      ),
                      _buildTopCard(
                        icon: Icons.monetization_on_outlined,
                        value: _formatAmount(state.summary['manualAmount']),
                        subtitle: 'MANUAL CHALLAN AMOUNT GENERATED',
                        cardBg: const Color(0xFF0EA5E9),
                        isMobile: isMobile,
                      ),
                      _buildTopCard(
                        icon: Icons.cancel_presentation_outlined,
                        value: _formatAmount(state.summary['pendingAmount']),
                        subtitle: 'PENDING AMOUNT',
                        cardBg: const Color(0xFFF97316),
                        isMobile: isMobile,
                      ),
                    ];

                    if (isMobile) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: cards),
                      );
                    }
                    return Row(children: cards);
                  },
                ),
                const SizedBox(height: 20),

                // Violation Revenue Category Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = MediaQuery.of(context).size.width < 900;
                    final cards = [
                      _buildViolationCard(
                        title: 'Fitness',
                        amount: _formatAmount(state.violations['fitnessAmount']),
                        borderColor: const Color(0xFFD8B4FE),
                        bgLight: const Color(0xFFFAF5FF),
                        isMobile: isMobile,
                      ),
                      _buildViolationCard(
                        title: 'Permit',
                        amount: _formatAmount(state.violations['permitAmount']),
                        borderColor: const Color(0xFFA5B4FC),
                        bgLight: const Color(0xFFEEF2FF),
                        isMobile: isMobile,
                      ),
                      _buildViolationCard(
                        title: 'Road Tax',
                        amount: _formatAmount(state.violations['roadTaxAmount']),
                        borderColor: const Color(0xFF93C5FD),
                        bgLight: const Color(0xFFEFF6FF),
                        isMobile: isMobile,
                      ),
                      _buildViolationCard(
                        title: 'Insurance',
                        amount: _formatAmount(state.violations['insuranceAmount']),
                        borderColor: const Color(0xFFBAE6FD),
                        bgLight: const Color(0xFFF0F9FF),
                        isMobile: isMobile,
                      ),
                      _buildViolationCard(
                        title: 'PUC',
                        amount: _formatAmount(state.violations['pucAmount']),
                        borderColor: const Color(0xFF99F6E4),
                        bgLight: const Color(0xFFF0FDFA),
                        isMobile: isMobile,
                      ),
                      _buildViolationCard(
                        title: 'Registration',
                        amount: _formatAmount(state.violations['registrationAmount']),
                        borderColor: const Color(0xFFE2E8F0),
                        bgLight: const Color(0xFFF8FAFC),
                        isMobile: isMobile,
                      ),
                    ];

                    if (isMobile) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: cards),
                      );
                    }
                    return Row(children: cards);
                  },
                ),
                const SizedBox(height: 24),

                // Monthly Revenue Chart Card
                Container(
                  padding: const EdgeInsets.all(20),
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
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Revenue Generated',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 320,
                        child: SfCartesianChart(
                          enableAxisAnimation: false,
                          primaryXAxis: CategoryAxis(
                            majorGridLines: const MajorGridLines(width: 0),
                            labelStyle: const TextStyle(fontSize: 10),
                          ),
                          primaryYAxis: NumericAxis(
                            title: AxisTitle(
                              text: 'Revenue (₹)',
                              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            numberFormat: NumberFormat.compact(),
                            axisLine: const AxisLine(width: 0),
                          ),
                          tooltipBehavior: TooltipBehavior(enable: true),
                          series: <ColumnSeries<MonthlyRevenueData, String>>[
                            ColumnSeries<MonthlyRevenueData, String>(
                              animationDuration: 0,
                              dataSource: chartData,
                              xValueMapper: (data, _) => data.month,
                              yValueMapper: (data, _) => data.revenue,
                              pointColorMapper: (data, _) => data.color,
                              dataLabelMapper: (data, _) => data.revenue > 0
                                  ? '₹${NumberFormat.compact().format(data.revenue)}'
                                  : '₹0',
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                                labelPosition: ChartDataLabelPosition.outside,
                                textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
