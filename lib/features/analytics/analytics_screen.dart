import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/widgets/loading_overlay.dart';
import '../../core/widgets/page_header_banner.dart';
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

  final List<String> _districts = ['Select All District', 'Nizamabad', 'Adilabad', 'Sangareddy', 'Kamareddy', 'Nirmal'];
  final List<String> _zones = ['Select All Zone', 'Zone 1', 'Zone 2', 'Zone 3'];
  final List<String> _cameras = ['Select All Camera', 'CAM001', 'CAM002', 'CAM003'];
  final List<String> _timeRanges = ['Select All Time Range', 'Today', 'Yesterday', 'Last 7 Days', 'Monthly'];

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
  }) {
    final String? safeValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      height: 42,
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: safeValue,
        isExpanded: true,
        isDense: true,
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Icon(icon, size: 14, color: Colors.grey.shade500),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 20),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetNotifierProvider);
    final notifier = ref.read(budgetNotifierProvider.notifier);

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
        child: SingleChildScrollView(
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
                                _buildFilterDropdown(
                                  value: _selectedDistrict,
                                  items: _districts,
                                  icon: Icons.location_on_outlined,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedDistrict = val);
                                      notifier.updateFilters(district: val);
                                    }
                                  },
                                  width: 140,
                                ),
                                _buildFilterDropdown(
                                  value: _selectedZone,
                                  items: _zones,
                                  icon: Icons.grid_view_outlined,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedZone = val);
                                      notifier.updateFilters(zone: val);
                                    }
                                  },
                                  width: 140,
                                ),
                                _buildFilterDropdown(
                                  value: _selectedCamera,
                                  items: _cameras,
                                  icon: Icons.videocam_outlined,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedCamera = val);
                                      notifier.updateFilters(camera: val);
                                    }
                                  },
                                  width: 140,
                                ),
                                _buildFilterDropdown(
                                  value: _selectedTimeRange,
                                  items: _timeRanges,
                                  icon: Icons.calendar_today_outlined,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedTimeRange = val);
                                      notifier.updateFilters(timeRange: val);
                                    }
                                  },
                                  width: 140,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: FilledButton.icon(
                              onPressed: () {
                                notifier.applyFilters();
                              },
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildFilterDropdown(
                            value: _selectedDistrict,
                            items: _districts,
                            icon: Icons.location_on_outlined,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDistrict = val);
                                notifier.updateFilters(district: val);
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildFilterDropdown(
                            value: _selectedZone,
                            items: _zones,
                            icon: Icons.grid_view_outlined,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedZone = val);
                                notifier.updateFilters(zone: val);
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildFilterDropdown(
                            value: _selectedCamera,
                            items: _cameras,
                            icon: Icons.videocam_outlined,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCamera = val);
                                notifier.updateFilters(camera: val);
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildFilterDropdown(
                            value: _selectedTimeRange,
                            items: _timeRanges,
                            icon: Icons.calendar_today_outlined,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedTimeRange = val);
                                notifier.updateFilters(timeRange: val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 42,
                          child: FilledButton.icon(
                            onPressed: () {
                              notifier.applyFilters();
                            },
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                          ),
                        ),
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

              // Monthly Revenue Bar Chart Card
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
                        'Total Revenue Generated',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0F3260),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 380,
                        child: SfCartesianChart(
                          enableAxisAnimation: true,
                          tooltipBehavior: TooltipBehavior(enable: true, header: ''),
                          primaryXAxis: CategoryAxis(
                            majorGridLines: const MajorGridLines(width: 0),
                            labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
                          ),
                          primaryYAxis: NumericAxis(
                            title: AxisTitle(
                              text: 'Revenue (₹)',
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                            ),
                            numberFormat: NumberFormat.compact(locale: 'en_IN'),
                            axisLine: const AxisLine(width: 0),
                            majorTickLines: const MajorTickLines(size: 0),
                            labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
                          ),
                          series: <ColumnSeries<MonthlyRevenueData, String>>[
                            ColumnSeries<MonthlyRevenueData, String>(
                              dataSource: chartData,
                              xValueMapper: (MonthlyRevenueData data, _) => data.month,
                              yValueMapper: (MonthlyRevenueData data, _) => data.revenue,
                              pointColorMapper: (MonthlyRevenueData data, _) => data.color,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                              dataLabelSettings: DataLabelSettings(
                                isVisible: true,
                                builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                                  final double rev = (data as MonthlyRevenueData).revenue;
                                  if (rev == 0) return const SizedBox.shrink();
                                  final format = NumberFormat.decimalPattern('en_US');
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Text(
                                      '₹${format.format(rev.toInt())}.00',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
