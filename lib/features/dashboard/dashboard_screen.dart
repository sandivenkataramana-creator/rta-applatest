import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';
import '../../core/widgets/loading_overlay.dart';
import 'dashboard_notifier.dart';
import 'dashboard_provider.dart';
import 'models/missing_certificate_model.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();

  static const _districtHint = 'Select All District';
  static const _zoneHint = 'Select All Zone';
  static const _cameraHint = 'Select All Camera';
  static const _timeRangeHint = 'Select All Time Range';

  static const List<String> _timeRangeOptions = [
    'Select All Time Range',
    'Today',
    'This Week',
    'This Month',
    'This Year',
  ];

  String? _selectedDistrict = 'Select All District';
  String? _selectedZone = 'Select All Zone';
  String? _selectedCamera = 'Select All Camera';
  String? _selectedTimeRange = 'Today';
  DateTime _lastUpdatedTime = DateTime.now();
  bool _showOverviewFilters = false;
  String? _expandedComplianceCategory;







  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    
    // Auto Refresh every 15 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _refreshDashboardData();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshDashboardData() {
    if (!mounted) return;
    final state = ref.read(dashboardNotifierProvider);
    final cameraID = state.cameraLocationToId[_selectedCamera];
    final params = MissingCertificatesParams(
      district: _selectedDistrict,
      zone: _selectedZone,
      camera: cameraID,
      timeRange: _selectedTimeRange,
    );
    ref.invalidate(missingCertificatesProvider(params));

    // Background fetch dashboard metrics (KPIs, offences, challans)
    ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
      district: _selectedDistrict,
      zone: _selectedZone,
      camera: cameraID,
      timeRange: _selectedTimeRange,
      isInitial: true,
    );
  }



  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardNotifierProvider);
    final notifier = ref.watch(dashboardNotifierProvider.notifier);
    
    ref.listen<DashboardState>(dashboardNotifierProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (previous != next && !next.isLoading && next.error == null) {
        setState(() {
          _lastUpdatedTime = DateTime.now();
        });
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isMobile = !isDesktop;
    
    final summaryColumnCount = isDesktop ? 4 : 2;
    final donutColumnCount = isDesktop ? 6 : (screenWidth >= 750 ? 3 : 1);

    final cameraID = state.cameraLocationToId[_selectedCamera];
    final params = MissingCertificatesParams(
      district: _selectedDistrict,
      zone: _selectedZone,
      camera: cameraID,
      timeRange: _selectedTimeRange,
    );

    ref.listen<AsyncValue<MissingCertificateModel>>(
      missingCertificatesProvider(params),
      (previous, next) {
        if (next is AsyncData && previous != next) {
          setState(() {
            _lastUpdatedTime = DateTime.now();
          });
        }
      },
    );

    final missingCertificatesAsync = ref.watch(missingCertificatesProvider(params));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F6),

      body: LoadingOverlay(
        isLoading: state.isLoading,
        child: RefreshIndicator(
          onRefresh: () async {
            final camId = state.cameraLocationToId[_selectedCamera];
            final p = MissingCertificatesParams(
              district: _selectedDistrict,
              zone: _selectedZone,
              camera: camId,
            );
            ref.invalidate(missingCertificatesProvider(p));
            await ref.read(missingCertificatesProvider(p).future);
            await notifier.fetchDashboard(
              district: _selectedDistrict,
              zone: _selectedZone,
              camera: camId,
              timeRange: _selectedTimeRange,
            );
            if (mounted) {
              setState(() {
                _lastUpdatedTime = DateTime.now();
              });
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            child: isMobile
                ? _buildMobileLayout(
                    context,
                    state,
                    notifier,
                    missingCertificatesAsync,
                    screenWidth,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Header Bar (Government of Telangana & Live Feed)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 8),
                  child: LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isMobileHeader = headerConstraints.maxWidth < 750;
                      
                      final titleCol = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GOVERNMENT OF TELANGANA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Vehicle Identification & Enforcement Automation System',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F3260),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.verified,
                                color: Colors.teal.shade400,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      );

                      if (isMobileHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleCol,
                            const SizedBox(height: 12),
                            const _LiveFeedClock(),
                          ],
                        );
                      } else {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: titleCol),
                            const SizedBox(width: 16),
                            const _LiveFeedClock(),
                          ],
                        );
                      }
                    }
                  ),
                ),

                // Filter Bar (Transparent Container)
                Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 950;
                      
                      final districtDropdown = _buildDropdownField(
                        hint: _districtHint,
                        value: _selectedDistrict,
                        options: state.districts,
                        onChanged: (value) {
                          setState(() {
                            _selectedDistrict = value;
                            _selectedZone = 'Select All Zone';
                            _selectedCamera = 'Select All Camera';
                          });
                          if (value != null && value != 'Select All District') {
                            ref.read(dashboardNotifierProvider.notifier).fetchZonesForDistrict(value);
                          } else {
                            ref.read(dashboardNotifierProvider.notifier).resetZones();
                          }
                          ref.read(dashboardNotifierProvider.notifier).resetCameras();
                        },
                        prefixIcon: Icons.location_on_outlined,
                      );

                      final zoneDropdown = _buildDropdownField(
                        hint: _zoneHint,
                        value: _selectedZone,
                        options: state.zones,
                        onChanged: (value) {
                          setState(() {
                            _selectedZone = value;
                            _selectedCamera = 'Select All Camera';
                          });
                          if (value != null && value != 'Select All Zone') {
                            ref.read(dashboardNotifierProvider.notifier).fetchCamerasForZone(value);
                          } else {
                            ref.read(dashboardNotifierProvider.notifier).resetCameras();
                          }
                        },
                        prefixIcon: Icons.location_city_outlined,
                      );

                      final cameraDropdown = _buildDropdownField(
                        hint: _cameraHint,
                        value: _selectedCamera,
                        options: state.cameras,
                        onChanged: (value) => setState(() => _selectedCamera = value),
                        prefixIcon: Icons.videocam_outlined,
                      );

                      final timeRangeDropdown = _buildDropdownField(
                        hint: _timeRangeHint,
                        value: _selectedTimeRange,
                        options: _timeRangeOptions,
                        onChanged: (value) => setState(() => _selectedTimeRange = value),
                        prefixIcon: Icons.calendar_today_outlined,
                      );

                      final submitButton = ElevatedButton(
                        onPressed: () {
                          final cameraID = state.cameraLocationToId[_selectedCamera];
                          notifier.fetchDashboard(
                            district: _selectedDistrict,
                            zone: _selectedZone,
                            camera: cameraID,
                            timeRange: _selectedTimeRange,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F5D55),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Apply Filters',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      );

                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(child: districtDropdown),
                            const SizedBox(width: 12),
                            Expanded(child: zoneDropdown),
                            const SizedBox(width: 12),
                            Expanded(child: cameraDropdown),
                            const SizedBox(width: 12),
                            Expanded(child: timeRangeDropdown),
                            const SizedBox(width: 16),
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
                            timeRangeDropdown,
                            const SizedBox(height: 12),
                            submitButton,
                          ],
                        );
                      }
                    },
                  ),
                ),
                
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    20 + MediaQuery.of(context).padding.bottom + 96,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grid of 4 Key Metrics Cards
                      GridView.count(
                        crossAxisCount: summaryColumnCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: isMobile ? (screenWidth < 365 ? 1.35 : 1.5) : 2.8,
                        children: [
                           _buildKeyMetricCard(
                            context,
                            title: 'Total No.of Vehicles',
                            value: missingCertificatesAsync.maybeWhen(
                              data: (data) => NumberFormat.decimalPattern().format(data.vehicleCount),
                              orElse: () => _getTotalVehicles(state.offenceData) > 0
                                  ? _getTotalVehicles(state.offenceData).toString()
                                  : (state.kpis?.totalVehiclesMonth.toString() ?? '66306'),
                            ),
                            icon: Icons.directions_car,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3F42B9), Color(0xFF5B5EE6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          _buildKeyMetricCard(
                            context,
                            title: 'e-Challan',
                            value: state.eChallan,
                            icon: Icons.receipt_long,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B998), Color(0xFF059688)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          _buildKeyMetricCard(
                            context,
                            title: 'Manual Challan',
                            value: state.manualChallan,
                            icon: Icons.payments,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF455A64), Color(0xFF607D8B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          _buildKeyMetricCard(
                            context,
                            title: 'Vehicles Seized',
                            value: state.seizedVehicles,
                            icon: Icons.block,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9E1B32), Color(0xFFC8102E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),



                      // Row/Grid of 6 Circular Charts (including Registration)
                      GridView.count(
                        crossAxisCount: donutColumnCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: isDesktop ? 0.65 : (screenWidth >= 768 ? 0.85 : 2.4),
                        children: _getSummaryMetrics(state.offenceData)
                            .map((metric) => _buildComplianceCard(metric))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      
                      // Bottom Section (Vehicle Distribution and Revenue Generated)
                      if (isMobile) ...[
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 1.5,
                          shadowColor: Colors.black12,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Vehicle Distribution',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _buildChartMenu(context, 'Vehicle Distribution'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 300,
                                  child: missingCertificatesAsync.when(
                                    data: (data) {
                                      final chartData = [
                                        _ChartData('Fitness', data.fitnessCertificateNotFound, const Color(0xFFE28B5C)),
                                        _ChartData('Insurance', data.insuranceCertificateNotFound, const Color(0xFF5CA0F2)),
                                        _ChartData('Road Tax', data.roadTaxCertificateNotFound, const Color(0xFF7A7BF2)),
                                        _ChartData('Permit', data.permitCertificateNotFound, const Color(0xFFD64D81)),
                                        _ChartData('Puc', data.pucCertificateNotFound, const Color(0xFF32353A)),
                                        _ChartData('Registration', data.registrationCertificateNotFound, const Color(0xFFE8D05C)),
                                        _ChartData('All Clear', data.allClearNotFound, const Color(0xFF2FA85C)),
                                        _ChartData('Missing Data', data.weightCertificateNotFound, const Color(0xFFF5D671)),
                                      ];
                                      return SfCircularChart(
                                        legend: Legend(
                                          isVisible: true,
                                          overflowMode: LegendItemOverflowMode.wrap,
                                          position: LegendPosition.bottom,
                                          textStyle: const TextStyle(fontSize: 10),
                                        ),
                                        series: <DoughnutSeries<_ChartData, String>>[
                                          DoughnutSeries<_ChartData, String>(
                                            animationDuration: 0,
                                            dataSource: chartData,
                                            xValueMapper: (data, _) => data.label,
                                            yValueMapper: (data, _) => data.value,
                                            pointColorMapper: (data, _) => data.color,
                                            innerRadius: '60%',
                                            dataLabelSettings: const DataLabelSettings(
                                              isVisible: true,
                                              labelPosition: ChartDataLabelPosition.outside,
                                              textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                            dataLabelMapper: (data, _) => '${data.label}: ${data.value.toInt()}',
                                          ),
                                        ],
                                      );
                                    },
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(color: Color(0xFF0F5D55)),
                                    ),
                                    error: (err, stack) => Center(
                                      child: Text(
                                        'Error loading chart: $err',
                                        style: const TextStyle(color: Colors.red, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 1.5,
                          shadowColor: Colors.black12,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Revenue Generated',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _buildChartMenu(context, 'Total Revenue Generated'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 320,
                                  child: SfCartesianChart(
                                    enableAxisAnimation: false,
                                    primaryXAxis: CategoryAxis(
                                      labelRotation: 45,
                                      majorGridLines: const MajorGridLines(width: 0),
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
                                    series: <ColumnSeries<_ChartData, String>>[
                                      ColumnSeries<_ChartData, String>(
                                        animationDuration: 0,
                                        dataSource: _getRevenueData(state.monthlyRevenue),
                                        xValueMapper: (data, _) => data.label,
                                        yValueMapper: (data, _) => data.value,
                                        pointColorMapper: (data, _) => data.color,
                                        dataLabelMapper: (data, _) => data.value > 0
                                            ? '₹${data.value.toStringAsFixed(2)}'
                                            : '₹0.00',
                                        dataLabelSettings: const DataLabelSettings(
                                          isVisible: true,
                                          showZeroValue: true,
                                          labelPosition: ChartDataLabelPosition.outside,
                                          textStyle: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 1.5,
                                shadowColor: Colors.black12,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Vehicle Distribution',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          _buildChartMenu(context, 'Vehicle Distribution'),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 360,
                                        child: missingCertificatesAsync.when(
                                          data: (data) {
                                            final chartData = [
                                              _ChartData('Fitness', data.fitnessCertificateNotFound, const Color(0xFFE28B5C)),
                                              _ChartData('Insurance', data.insuranceCertificateNotFound, const Color(0xFF5CA0F2)),
                                              _ChartData('Road Tax', data.roadTaxCertificateNotFound, const Color(0xFF7A7BF2)),
                                              _ChartData('Permit', data.permitCertificateNotFound, const Color(0xFFD64D81)),
                                              _ChartData('Puc', data.pucCertificateNotFound, const Color(0xFF32353A)),
                                              _ChartData('Registration', data.registrationCertificateNotFound, const Color(0xFFE8D05C)),
                                              _ChartData('All Clear', data.allClearNotFound, const Color(0xFF2FA85C)),
                                              _ChartData('Missing Data', data.weightCertificateNotFound, const Color(0xFFF5D671)),
                                            ];
                                            return SfCircularChart(
                                              legend: Legend(
                                                isVisible: true,
                                                overflowMode: LegendItemOverflowMode.wrap,
                                                position: LegendPosition.bottom,
                                                textStyle: const TextStyle(fontSize: 10),
                                              ),
                                              series: <DoughnutSeries<_ChartData, String>>[
                                                DoughnutSeries<_ChartData, String>(
                                                  animationDuration: 0,
                                                  dataSource: chartData,
                                                  xValueMapper: (data, _) => data.label,
                                                  yValueMapper: (data, _) => data.value,
                                                  pointColorMapper: (data, _) => data.color,
                                                  innerRadius: '60%',
                                                  dataLabelSettings: const DataLabelSettings(
                                                    isVisible: true,
                                                    labelPosition: ChartDataLabelPosition.outside,
                                                    textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                  dataLabelMapper: (data, _) => '${data.label}: ${data.value.toInt()}',
                                                ),
                                              ],
                                            );
                                          },
                                          loading: () => const Center(
                                            child: CircularProgressIndicator(color: Color(0xFF0F5D55)),
                                          ),
                                          error: (err, stack) => Center(
                                            child: Text(
                                              'Error loading chart: $err',
                                              style: const TextStyle(color: Colors.red, fontSize: 12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 1.5,
                                shadowColor: Colors.black12,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Total Revenue Generated',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          _buildChartMenu(context, 'Total Revenue Generated'),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 360,
                                        child: SfCartesianChart(
                                          enableAxisAnimation: false,
                                          primaryXAxis: CategoryAxis(
                                            labelRotation: 45,
                                            majorGridLines: const MajorGridLines(width: 0),
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
                                          series: <ColumnSeries<_ChartData, String>>[
                                            ColumnSeries<_ChartData, String>(
                                              animationDuration: 0,
                                              dataSource: _getRevenueData(state.monthlyRevenue),
                                              xValueMapper: (data, _) => data.label,
                                              yValueMapper: (data, _) => data.value,
                                              pointColorMapper: (data, _) => data.color,
                                              dataLabelMapper: (data, _) => data.value > 0
                                                  ? '₹${data.value.toStringAsFixed(2)}'
                                                  : '₹0.00',
                                              dataLabelSettings: const DataLabelSettings(
                                                isVisible: true,
                                                showZeroValue: true,
                                                labelPosition: ChartDataLabelPosition.outside,
                                                textStyle: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
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
                          ],
                        ),
                      ],
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

  static Widget _buildDropdownField({
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    required IconData prefixIcon,
  }) {
    final String? safeValue = (value != null && options.contains(value))
        ? value
        : (options.isNotEmpty ? options.first : null);

    final keyString = '${hint}_${options.length}_$safeValue';
    return DropdownButtonFormField<String>(
      key: ValueKey(keyString),
      isExpanded: true,
      isDense: true,
      initialValue: safeValue,
      hint: Text(hint, style: const TextStyle(fontSize: 11)),
      style: const TextStyle(fontSize: 11, color: Colors.black87),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 6, right: 4),
          child: Icon(prefixIcon, color: const Color(0xFF0F5D55), size: 14),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDCECEC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDCECEC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0F5D55)),
        ),
      ),
      selectedItemBuilder: (BuildContext context) {
        return options.map<Widget>((String item) {
          String label = item;
          if (item == 'Select All District') {
            label = 'All Districts';
          } else if (item == 'Select All Zone') {
            label = 'All Zones';
          } else if (item == 'Select All Camera') {
            label = 'All Cameras';
          }
          return Text(
            label,
            style: const TextStyle(fontSize: 10.5, overflow: TextOverflow.ellipsis),
            maxLines: 1,
          );
        }).toList();
      },
      items: options
          .map(
            (option) {
              String label = option;
              if (option == 'Select All District') {
                label = 'All Districts';
              } else if (option == 'Select All Zone') {
                label = 'All Zones';
              } else if (option == 'Select All Camera') {
                label = 'All Cameras';
              }
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          )
          .toList(),
      onChanged: onChanged,
    );
  }
  static Widget _buildKeyMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.0,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getTotalVehicles(Map<String, dynamic>? offenceData) {
    if (offenceData == null || offenceData.isEmpty) {
      return 0;
    }
    if (offenceData.containsKey('totalVehicles')) {
      return (offenceData['totalVehicles'] as num? ?? 0).toInt();
    }
    final reg = offenceData['REGISTRATION_CERTIFICATE'] as Map<String, dynamic>?;
    final found = (reg?['certificateFound'] as num? ?? 0).toInt();
    final expired = (reg?['certificateExpired'] as num? ?? 0).toInt();
    return found + expired;
  }

  List<_SummaryMetric> _getSummaryMetrics(Map<String, dynamic>? offenceData) {
    if (offenceData == null || offenceData.isEmpty) {
      return [
        const _SummaryMetric('Fitness', 0, 0, 0),
        const _SummaryMetric('Permit', 0, 0, 0),
        const _SummaryMetric('Road Tax', 0, 0, 0),
        const _SummaryMetric('Insurance', 0, 0, 0),
        const _SummaryMetric('PUC', 0, 0, 0),
        const _SummaryMetric('Registration', 0, 0, 0),
      ];
    }
    
    _SummaryMetric parseCertificate(String title, Map<String, dynamic>? cert) {
      final found = (cert?['certificateFound'] as num? ?? 0).toInt();
      final expired = (cert?['certificateExpired'] as num? ?? 0).toInt();
      final notFound = (cert?['certificateNotFound'] as num? ?? 0).toInt();
      return _SummaryMetric(title, found, expired, notFound);
    }

    return [
      parseCertificate('Fitness', offenceData['FITNESS_CERTIFICATE'] as Map<String, dynamic>?),
      parseCertificate('Permit', offenceData['PERMITTED_CERTIFICATE'] as Map<String, dynamic>?),
      parseCertificate('Road Tax', offenceData['ROAD_TAX_CERTIFICATE'] as Map<String, dynamic>?),
      parseCertificate('Insurance', offenceData['INSURANCE_CERTIFICATE'] as Map<String, dynamic>?),
      parseCertificate('PUC', offenceData['PUC_CERTIFICATE'] as Map<String, dynamic>?),
      parseCertificate('Registration', offenceData['REGISTRATION_CERTIFICATE'] as Map<String, dynamic>?),
    ];
  }



  List<_ChartData> _getRevenueData(Map<String, double> monthlyRevenue) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final colors = [
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2), // May
      const Color(0xFFED5C7D), // June
      const Color(0xFFE8D05C), // July
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
    ];
    return List.generate(12, (index) {
      final m = months[index];
      final monthKey = (index + 1).toString();
      final val = monthlyRevenue[monthKey] ?? 0.0;
      return _ChartData(m, val, colors[index]);
    });
  }

  IconData _getMetricIcon(String title) {
    switch (title.toLowerCase()) {
      case 'fitness':
        return Icons.check_circle;
      case 'permit':
        return Icons.card_membership;
      case 'road tax':
        return Icons.currency_rupee;
      case 'insurance':
        return Icons.shield;
      case 'puc':
        return Icons.cloud;
      case 'registration':
        return Icons.description;
      default:
        return Icons.info;
    }
  }

  Color _getMetricBorderColor(String title) {
    switch (title.toLowerCase()) {
      case 'fitness':
        return const Color(0xFFED5C7D); // pink/red
      case 'permit':
        return const Color(0xFF7A7BF2); // purple
      case 'road tax':
        return const Color(0xFF0D9F8B); // teal/green
      case 'insurance':
        return const Color(0xFF3B82F6); // blue
      case 'puc':
        return const Color(0xFF0EA5E9); // light blue
      case 'registration':
        return const Color(0xFF991B1B); // dark red/purple
      default:
        return const Color(0xFFE2ECEC); // fallback
    }
  }

  Widget _buildComplianceCard(_SummaryMetric metric) {
    final List<_ChartData> chartData = [
      _ChartData('Compliant', metric.compliant, const Color(0xFF81D8B7)),
      _ChartData('Non-Compliant', metric.nonCompliant, const Color(0xFFE289A3)),
      _ChartData('Missing', metric.missing, const Color(0xFFF5D671)),
    ];

    final total = metric.compliant + metric.nonCompliant + metric.missing;
    final totalText = NumberFormat.decimalPattern().format(total);

    final isMobileLayout = MediaQuery.of(context).size.width < 750;

    final chartWidget = SizedBox(
      width: isMobileLayout ? 100 : double.infinity,
      height: isMobileLayout ? 100 : double.infinity,
      child: SfCircularChart(
        margin: EdgeInsets.zero,
        series: <DoughnutSeries<_ChartData, String>>[
          DoughnutSeries<_ChartData, String>(
            animationDuration: 500,
            dataSource: chartData,
            xValueMapper: (data, _) => data.label,
            yValueMapper: (data, _) => data.value,
            pointColorMapper: (data, _) => data.color,
            innerRadius: '70%',
            radius: '95%',
            dataLabelSettings: const DataLabelSettings(isVisible: false),
          ),
        ],
      ),
    );

    final infoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              metric.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F3260),
              ),
            ),
            Icon(
              _getMetricIcon(metric.title),
              color: const Color(0xFF81D8B7),
              size: 18,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TOTAL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black38,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              totalText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildLegendRow('Compliant', metric.compliant, const Color(0xFF81D8B7)),
        const SizedBox(height: 4),
        _buildLegendRow('Non-Compliant', metric.nonCompliant, const Color(0xFFE289A3)),
        const SizedBox(height: 4),
        _buildLegendRow('${metric.title} Missing Data', metric.missing, const Color(0xFFF5D671)),
      ],
    );

    if (isMobileLayout) {
      return Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _getMetricBorderColor(metric.title), width: 1.5),
        ),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              chartWidget,
              const SizedBox(width: 14),
              Expanded(child: infoWidget),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _getMetricBorderColor(metric.title), width: 1.5),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  metric.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3260),
                  ),
                ),
                Icon(
                  _getMetricIcon(metric.title),
                  color: const Color(0xFF81D8B7),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black38,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  totalText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: SfCircularChart(
                  margin: EdgeInsets.zero,
                  series: <DoughnutSeries<_ChartData, String>>[
                    DoughnutSeries<_ChartData, String>(
                      animationDuration: 500,
                      dataSource: chartData,
                      xValueMapper: (data, _) => data.label,
                      yValueMapper: (data, _) => data.value,
                      pointColorMapper: (data, _) => data.color,
                      innerRadius: '70%',
                      radius: '90%',
                      dataLabelSettings: const DataLabelSettings(isVisible: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendRow('Compliant', metric.compliant, const Color(0xFF81D8B7)),
            const SizedBox(height: 4),
            _buildLegendRow('Non-Compliant', metric.nonCompliant, const Color(0xFFE289A3)),
            const SizedBox(height: 4),
            _buildLegendRow('${metric.title} Missing Data', metric.missing, const Color(0xFFF5D671)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
        const Spacer(),
        Text(
          NumberFormat.decimalPattern().format(value),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildChartMenu(BuildContext context, String chartTitle) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: Color(0xFF666666), size: 20),
      tooltip: 'Chart context menu',
      onSelected: (value) {
        _exportChart(context, chartTitle, value);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'fullscreen',
          child: Text('View in full screen', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: 'png',
          child: Text('Download PNG image', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: 'jpeg',
          child: Text('Download JPEG image', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: 'pdf',
          child: Text('Download PDF document', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: 'svg',
          child: Text('Download SVG vector image', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }



  Widget _buildMobileLayout(
    BuildContext context,
    DashboardState state,
    DashboardNotifier notifier,
    AsyncValue<MissingCertificateModel> missingCertificatesAsync,
    double screenWidth,
  ) {
    final totalVehiclesVal = missingCertificatesAsync.maybeWhen(
      data: (data) => NumberFormat.decimalPattern().format(data.vehicleCount),
      orElse: () => _getTotalVehicles(state.offenceData) > 0
          ? _getTotalVehicles(state.offenceData).toString()
          : (state.kpis?.totalVehiclesMonth.toString() ?? '27,440'),
    );

    final districtDropdown = _buildDropdownField(
      hint: _districtHint,
      value: _selectedDistrict,
      options: state.districts,
      onChanged: (value) {
        setState(() {
          _selectedDistrict = value;
          _selectedZone = 'Select All Zone';
          _selectedCamera = 'Select All Camera';
        });
        if (value != null && value != 'Select All District') {
          ref.read(dashboardNotifierProvider.notifier).fetchZonesForDistrict(value);
        } else {
          ref.read(dashboardNotifierProvider.notifier).resetZones();
        }
        ref.read(dashboardNotifierProvider.notifier).resetCameras();
        
        // Auto-apply
        ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
          district: value,
          zone: 'Select All Zone',
          camera: '',
          timeRange: _selectedTimeRange,
        );
      },
      prefixIcon: Icons.location_on_outlined,
    );

    final zoneDropdown = _buildDropdownField(
      hint: _zoneHint,
      value: _selectedZone,
      options: state.zones,
      onChanged: (value) {
        setState(() {
          _selectedZone = value;
          _selectedCamera = 'Select All Camera';
        });
        if (value != null && value != 'Select All Zone') {
          ref.read(dashboardNotifierProvider.notifier).fetchCamerasForZone(value);
        } else {
          ref.read(dashboardNotifierProvider.notifier).resetCameras();
        }
        
        // Auto-apply
        ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
          district: _selectedDistrict,
          zone: value,
          camera: '',
          timeRange: _selectedTimeRange,
        );
      },
      prefixIcon: Icons.location_city_outlined,
    );

    final cameraDropdown = _buildDropdownField(
      hint: _cameraHint,
      value: _selectedCamera,
      options: state.cameras,
      onChanged: (value) {
        setState(() {
          _selectedCamera = value;
        });
        final cameraID = state.cameraLocationToId[value];
        // Auto-apply
        ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
          district: _selectedDistrict,
          zone: _selectedZone,
          camera: cameraID,
          timeRange: _selectedTimeRange,
        );
      },
      prefixIcon: Icons.videocam_outlined,
    );

    final timeRangeDropdown = _buildDropdownField(
      hint: _timeRangeHint,
      value: _selectedTimeRange,
      options: _timeRangeOptions,
      onChanged: (value) {
        setState(() {
          _selectedTimeRange = value;
        });
        final cameraID = state.cameraLocationToId[_selectedCamera];
        // Auto-apply
        ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
          district: _selectedDistrict,
          zone: _selectedZone,
          camera: cameraID,
          timeRange: value,
        );
      },
      prefixIcon: Icons.calendar_today_outlined,
    );

    final metrics = _getSummaryMetrics(state.offenceData);
    final orderedTitles = ['Registration', 'Permit', 'Road Tax', 'Insurance', 'PUC', 'Fitness'];
    final Map<String, _SummaryMetric> metricMap = {
      for (var m in metrics) m.title: m
    };
    final orderedMetrics = orderedTitles
        .map((title) => metricMap[title])
        .whereType<_SummaryMetric>()
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -16,
                right: -16,
                top: -12,
                child: ClipPath(
                  clipper: HeaderCurveClipper(),
                  child: Container(
                    height: 130,
                    color: const Color(0xFF0F5D55),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildMobileTotalVehiclesCard(context, totalVehiclesVal),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3260),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _showOverviewFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: const Color(0xFF13A89E),
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    _showOverviewFilters = !_showOverviewFilters;
                    // Restart/Reset all selected filters to default values
                    _selectedDistrict = 'Select All District';
                    _selectedZone = 'Select All Zone';
                    _selectedCamera = 'Select All Camera';
                    _selectedTimeRange = 'Today';
                    
                    ref.read(dashboardNotifierProvider.notifier).resetZones();
                    ref.read(dashboardNotifierProvider.notifier).resetCameras();
                    
                    ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
                      district: 'Select All District',
                      zone: 'Select All Zone',
                      camera: '',
                      timeRange: 'Today',
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_showOverviewFilters) ...[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE5ECEC),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    SizedBox(width: 140, child: districtDropdown),
                    const SizedBox(width: 6),
                    SizedBox(width: 140, child: zoneDropdown),
                    const SizedBox(width: 6),
                    SizedBox(width: 140, child: cameraDropdown),
                    const SizedBox(width: 6),
                    SizedBox(width: 140, child: timeRangeDropdown),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildOverviewStatCard(
                  title: 'E-Challan',
                  value: state.eChallan,
                  icon: Icons.receipt_long,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9F8B), Color(0xFF10B998)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  trend: '↑ 12.5% vs Yesterday',
                ),
                const SizedBox(width: 12),
                _buildOverviewStatCard(
                  title: 'Manual Challan',
                  value: state.manualChallan,
                  icon: Icons.payments,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  trend: '— No Change',
                ),
                const SizedBox(width: 12),
                _buildOverviewStatCard(
                  title: 'Vehicles Seized',
                  value: state.seizedVehicles,
                  icon: Icons.block,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFBE123C), Color(0xFFE11D48)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  trend: '— No Change',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Compliance Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3260),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: orderedMetrics.map((metric) => _buildComplianceRow(context, metric)).toList(),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vehicle Distribution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3260),
                ),
              ),
              _buildChartMenu(context, 'Vehicle Distribution'),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 1,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 150,
                      child: missingCertificatesAsync.when(
                        data: (data) {
                          final chartData = [
                            _ChartData('Fitness', data.fitnessCertificateNotFound, const Color(0xFFE28B5C)),
                            _ChartData('Insurance', data.insuranceCertificateNotFound, const Color(0xFF5CA0F2)),
                            _ChartData('Road Tax', data.roadTaxCertificateNotFound, const Color(0xFF7A7BF2)),
                            _ChartData('Permit', data.permitCertificateNotFound, const Color(0xFFD64D81)),
                            _ChartData('Puc', data.pucCertificateNotFound, const Color(0xFF32353A)),
                            _ChartData('Registration', data.registrationCertificateNotFound, const Color(0xFFE8D05C)),
                            _ChartData('All Clear', data.allClearNotFound, const Color(0xFF2FA85C)),
                            _ChartData('Missing Data', data.weightCertificateNotFound, const Color(0xFFF5D671)),
                          ];
                          return SfCircularChart(
                            margin: EdgeInsets.zero,
                            annotations: <CircularChartAnnotation>[
                              CircularChartAnnotation(
                                widget: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      NumberFormat.decimalPattern().format(data.vehicleCount),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F3260),
                                      ),
                                    ),
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.black45,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            series: <DoughnutSeries<_ChartData, String>>[
                              DoughnutSeries<_ChartData, String>(
                                animationDuration: 0,
                                dataSource: chartData,
                                xValueMapper: (data, _) => data.label,
                                yValueMapper: (data, _) => data.value,
                                pointColorMapper: (data, _) => data.color,
                                innerRadius: '60%',
                                dataLabelSettings: const DataLabelSettings(isVisible: false),
                              ),
                            ],
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: Color(0xFF0F5D55)),
                        ),
                        error: (err, stack) => Center(
                          child: Text(
                            'Error: $err',
                            style: const TextStyle(color: Colors.red, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: missingCertificatesAsync.maybeWhen(
                      data: (data) {
                        final items = [
                          _buildDistributionRow('Insurance', data.insuranceCertificateNotFound, const Color(0xFF5CA0F2)),
                          _buildDistributionRow('Road Tax', data.roadTaxCertificateNotFound, const Color(0xFF7A7BF2)),
                          _buildDistributionRow('PUC', data.pucCertificateNotFound, const Color(0xFF32353A)),
                          _buildDistributionRow('Registration', data.registrationCertificateNotFound, const Color(0xFFE8D05C)),
                          _buildDistributionRow('Permit', data.permitCertificateNotFound, const Color(0xFFD64D81)),
                          _buildDistributionRow('Fitness', data.fitnessCertificateNotFound, const Color(0xFFE28B5C)),
                          _buildDistributionRow('Missing Data', data.weightCertificateNotFound, const Color(0xFFF5D671)),
                        ];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: items,
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Revenue Generated',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3260),
                ),
              ),
              _buildChartMenu(context, 'Total Revenue Generated'),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 1,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildRevenueIndicator('₹ 7.65 Cr', 'Jul (Current)', const Color(0xFF7A7BF2)),
                      _buildRevenueIndicator('₹ 43.04 Cr', 'May (Highest)', const Color(0xFFED5C7D)),
                      _buildRevenueIndicator('₹ 2.80 Cr', 'Apr (Previous)', const Color(0xFF2FA85C)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: SfCartesianChart(
                      enableAxisAnimation: false,
                      margin: EdgeInsets.zero,
                      primaryXAxis: CategoryAxis(
                        labelRotation: 0,
                        majorGridLines: const MajorGridLines(width: 0),
                        labelStyle: const TextStyle(fontSize: 8.5),
                      ),
                      primaryYAxis: NumericAxis(
                        title: AxisTitle(
                          text: 'Revenue (₹)',
                          textStyle: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                        numberFormat: NumberFormat.compact(),
                        axisLine: const AxisLine(width: 0),
                        labelStyle: const TextStyle(fontSize: 8.5),
                      ),
                      series: <ColumnSeries<_ChartData, String>>[
                        ColumnSeries<_ChartData, String>(
                          animationDuration: 0,
                          dataSource: _getRevenueData(state.monthlyRevenue),
                          xValueMapper: (data, _) => data.label,
                          yValueMapper: (data, _) => data.value,
                          pointColorMapper: (data, _) => data.color,
                          dataLabelMapper: (data, _) => data.value > 0
                              ? '₹${data.value.toStringAsFixed(1)}'
                              : '₹0.0',
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: true,
                            showZeroValue: false,
                            labelPosition: ChartDataLabelPosition.outside,
                            textStyle: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: TextButton(
                      onPressed: () => context.go('/dashboard/reports'),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F6F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'View Full Report',
                            style: TextStyle(
                              color: Color(0xFF0F5D55),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 14, color: Color(0xFF0F5D55)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMobileTotalVehiclesCard(BuildContext context, String vehicleCount) {
    return Stack(
      children: [
        // Background container with gradient only
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B3A34), Color(0xFF0F5D55)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                        SizedBox(width: 6),
                        Text(
                          'LIVE FEED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Last Updated: ${DateFormat('d MMM, HH:mm:ss').format(_lastUpdatedTime)} IST',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 34,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Vehicles',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicleCount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Across Telangana',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    // Positioned background image of map and Charminar
    Positioned(
      right: 0,
      bottom: 0,
      top: 0,
      width: 180,
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: Opacity(
            opacity: 0.45,
            child: Image.asset(
              'assets/images/vehicles_bg.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
            ),
          ),
        ),
      ),
    ),
  ],
);
}

  Widget _buildOverviewStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
    required String trend,
  }) {
    return Container(
      width: 125,
      height: 140,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 6),
          Text(
            trend,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMetricColor(String title) {
    switch (title.toLowerCase()) {
      case 'registration':
        return const Color(0xFF16A34A);
      case 'permit':
        return const Color(0xFF8B5CF6);
      case 'road tax':
        return const Color(0xFFEC4899);
      case 'insurance':
        return const Color(0xFF3B82F6);
      case 'puc':
        return const Color(0xFFF59E0B);
      case 'fitness':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _buildComplianceRow(BuildContext context, _SummaryMetric metric) {
    final title = metric.title;
    final total = metric.compliant + metric.nonCompliant + metric.missing;
    final color = _getMetricColor(title);
    final icon = _getMetricIcon(title);
    final bgColor = color.withValues(alpha: 0.12);
    final isExpanded = _expandedComplianceCategory == title;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedComplianceCategory = isExpanded ? null : title;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5ECEC), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  // 1. Color-coded Icon Box
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 8),
                  // 2. Metric Title
                  Expanded(
                    flex: 4,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F3260),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 3. Total Value
                  Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          NumberFormat.decimalPattern().format(total),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F3260),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 4. Vertical Divider
                  Container(
                    height: 20,
                    width: 1,
                    color: const Color(0xFFE5ECEC),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  // 5. Compliant, Non-Compliant, Missing Data columns
                  Expanded(
                    flex: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricDetailColumn(metric.compliant, 'Compliant', const Color(0xFF16A34A)),
                        _buildMetricDetailColumn(metric.nonCompliant, 'Non-Compliant', const Color(0xFFDC2626)),
                        _buildMetricDetailColumn(metric.missing, 'Missing Data', const Color(0xFFEA580C)),
                      ],
                    ),
                  ),
                  // 6. Keyboard chevron arrow
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.black38,
                    size: 16,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE5ECEC)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // circular chart
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: SfCircularChart(
                        margin: EdgeInsets.zero,
                        series: <DoughnutSeries<_ChartData, String>>[
                          DoughnutSeries<_ChartData, String>(
                            animationDuration: 300,
                            dataSource: [
                              _ChartData('Compliant', metric.compliant, const Color(0xFF16A34A)),
                              _ChartData('Non-Compliant', metric.nonCompliant, const Color(0xFFDC2626)),
                              _ChartData('Missing', metric.missing, const Color(0xFFEA580C)),
                            ],
                            xValueMapper: (data, _) => data.label,
                            yValueMapper: (data, _) => data.value,
                            pointColorMapper: (data, _) => data.color,
                            innerRadius: '65%',
                            radius: '100%',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendRow('Compliant', metric.compliant, const Color(0xFF16A34A)),
                          const SizedBox(height: 4),
                          _buildLegendRow('Non-Compliant', metric.nonCompliant, const Color(0xFFDC2626)),
                          const SizedBox(height: 4),
                          _buildLegendRow('Missing Data', metric.missing, const Color(0xFFEA580C)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricDetailColumn(int value, String label, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            NumberFormat.decimalPattern().format(value),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 7.0,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }



  Widget _buildDistributionRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            NumberFormat.decimalPattern().format(value),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueIndicator(String amount, String period, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          period,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _exportChart(BuildContext context, String title, String format) {
    if (format == 'fullscreen') {
      final state = ref.read(dashboardNotifierProvider);
      final params = MissingCertificatesParams(
        district: _selectedDistrict,
        zone: _selectedZone,
        camera: state.cameraLocationToId[_selectedCamera],
      );
      final certificatesAsync = ref.read(missingCertificatesProvider(params));
      final certificates = certificatesAsync.value;

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F3260),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  if (title == 'Vehicle Distribution') ...[
                    if (certificates != null) ...[
                      SizedBox(
                        height: 300,
                        child: SfCircularChart(
                          legend: Legend(
                            isVisible: true,
                            position: LegendPosition.bottom,
                            overflowMode: LegendItemOverflowMode.wrap,
                          ),
                          series: <DoughnutSeries<_ChartData, String>>[
                            DoughnutSeries<_ChartData, String>(
                              dataSource: [
                                _ChartData('Fitness', certificates.fitnessCertificateNotFound, const Color(0xFFE28B5C)),
                                _ChartData('Insurance', certificates.insuranceCertificateNotFound, const Color(0xFF5CA0F2)),
                                _ChartData('Road Tax', certificates.roadTaxCertificateNotFound, const Color(0xFF7A7BF2)),
                                _ChartData('Permit', certificates.permitCertificateNotFound, const Color(0xFFD64D81)),
                                _ChartData('Puc', certificates.pucCertificateNotFound, const Color(0xFF32353A)),
                                _ChartData('Registration', certificates.registrationCertificateNotFound, const Color(0xFFE8D05C)),
                                _ChartData('All Clear', certificates.allClearNotFound, const Color(0xFF2FA85C)),
                                _ChartData('Missing Data', certificates.weightCertificateNotFound, const Color(0xFFF5D671)),
                              ],
                              xValueMapper: (data, _) => data.label,
                              yValueMapper: (data, _) => data.value,
                              pointColorMapper: (data, _) => data.color,
                              innerRadius: '60%',
                              radius: '95%',
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                                labelPosition: ChartDataLabelPosition.outside,
                                textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                              dataLabelMapper: (data, _) => '${data.label}: ${data.value.toInt()}',
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Center(child: Text('No data loaded')),
                    ],
                  ] else ...[
                    // Total Revenue Generated
                    SizedBox(
                      height: 300,
                      child: SfCartesianChart(
                        primaryXAxis: CategoryAxis(majorGridLines: const MajorGridLines(width: 0)),
                        primaryYAxis: NumericAxis(
                          numberFormat: NumberFormat.compact(),
                          axisLine: const AxisLine(width: 0),
                        ),
                        series: <ColumnSeries<_ChartData, String>>[
                          ColumnSeries<_ChartData, String>(
                            dataSource: _getRevenueData(state.monthlyRevenue),
                            xValueMapper: (data, _) => data.label,
                            yValueMapper: (data, _) => data.value,
                            pointColorMapper: (data, _) => data.color,
                            dataLabelSettings: const DataLabelSettings(
                              isVisible: true,
                              labelPosition: ChartDataLabelPosition.outside,
                              textStyle: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F5D55),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Successfully downloaded $title as ${format.toUpperCase()}. Saved to downloads.',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

}


class _SummaryMetric {
  const _SummaryMetric(
    this.title,
    this.compliant,
    this.nonCompliant,
    this.missing,
  );

  final String title;
  final int compliant;
  final int nonCompliant;
  final int missing;
}

class _ChartData {
  const _ChartData(this.label, this.value, this.color);

  final String label;
  final num value;
  final Color color;
}

class _LiveFeedClock extends StatefulWidget {
  const _LiveFeedClock();

  @override
  State<_LiveFeedClock> createState() => _LiveFeedClockState();
}

class _LiveFeedClockState extends State<_LiveFeedClock> {
  late DateTime _currentTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCECEC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.red, size: 8),
          const SizedBox(width: 8),
          const Text(
            'LIVE FEED',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${DateFormat('d MMM, HH:mm:ss').format(_currentTime)} IST',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0);
    path.lineTo(0, 40);
    path.quadraticBezierTo(size.width / 2, 140, size.width, 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
