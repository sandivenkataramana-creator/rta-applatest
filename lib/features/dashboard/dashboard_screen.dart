import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

import 'dart:async';
import '../../core/widgets/loading_overlay.dart';
import 'dashboard_notifier.dart';
import 'dashboard_provider.dart';


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

  static final _summaryMetrics = [
    const _SummaryMetric('Fitness', 3537, 215, 10910),
    const _SummaryMetric('Permit', 3700, 52, 0),
    const _SummaryMetric('Road Tax', 2900, 852, 0),
    const _SummaryMetric('Insurance', 11147, 4061, 0),
    const _SummaryMetric('PUC', 4542, 1851, 1815),
    const _SummaryMetric('Registration', 15016, 192, 0),
  ];



  final ValueNotifier<bool> _isAtBottomNotifier = ValueNotifier<bool>(false);

  bool get _isAtBottom {
    return _scrollController.hasClients &&
        _scrollController.offset >=
            _scrollController.position.maxScrollExtent -
                (_scrollController.position.viewportDimension / 4);
  }

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
    
    // Auto Refresh every 5 minutes
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _refreshMissingCertificates();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _isAtBottomNotifier.dispose();
    super.dispose();
  }

  void _refreshMissingCertificates() {
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
  }

  void _onScrollChanged() {
    if (!mounted) return;
    final currentlyAtBottom = _isAtBottom;
    if (_isAtBottomNotifier.value != currentlyAtBottom) {
      _isAtBottomNotifier.value = currentlyAtBottom;
    }
  }

  Future<void> _toggleScroll() async {
    if (!_scrollController.hasClients) return;

    final target = _isAtBottomNotifier.value
        ? 0.0
        : _scrollController.position.maxScrollExtent;
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
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
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isMobile = !isDesktop;
    
    final summaryColumnCount = isDesktop ? 4 : 1;
    final donutColumnCount = isDesktop ? 6 : (screenWidth >= 750 ? 3 : 1);

    final cameraID = state.cameraLocationToId[_selectedCamera];
    final params = MissingCertificatesParams(
      district: _selectedDistrict,
      zone: _selectedZone,
      camera: cameraID,
      timeRange: _selectedTimeRange,
    );
    final missingCertificatesAsync = ref.watch(missingCertificatesProvider(params));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F6),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _isAtBottomNotifier,
        builder: (context, isAtBottom, child) {
          return FloatingActionButton.extended(
            onPressed: _toggleScroll,
            backgroundColor: const Color(0xFF81D8B7),
            foregroundColor: const Color(0xFF0F5D55),
            icon: Icon(isAtBottom ? Icons.arrow_upward : Icons.arrow_downward),
            label: Text(isAtBottom ? 'Scroll Top' : 'Scroll Down'),
          );
        },
      ),
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
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            child: Column(
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
                        childAspectRatio: isMobile ? 2.3 : 2.8,
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
                            gradient: const LinearGradient(colors: [Color(0xFF4A4EBF), Color(0xFF3F42B3)]),
                          ),
                          _buildKeyMetricCard(
                            context,
                            title: 'e-Challan',
                            value: state.eChallan,
                            icon: Icons.receipt_long,
                            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF0F9B8E)]),
                          ),
                          _buildKeyMetricCard(
                            context,
                            title: 'Manual Challan',
                            value: state.manualChallan,
                            icon: Icons.payments,
                            gradient: const LinearGradient(colors: [Color(0xFF6B7280), Color(0xFF4B5563)]),
                          ),
                          _buildKeyMetricCard(
                            context,
                            title: 'Vehicles Seized',
                            value: state.seizedVehicles,
                            icon: Icons.block,
                            gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
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
                        childAspectRatio: isDesktop ? 0.65 : (screenWidth >= 768 ? 0.85 : 1.2),
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
                                        _ChartData('Fitness', data.fitnessCertificateNotFound, const Color(0xFF5CA0F2)),
                                        _ChartData('Insurance', data.insuranceCertificateNotFound, const Color(0xFF32353A)),
                                        _ChartData('Road Tax', data.roadTaxCertificateNotFound, const Color(0xFF90C25B)),
                                        _ChartData('Permit', data.permitCertificateNotFound, const Color(0xFFE28B5C)),
                                        _ChartData('Puc', data.pucCertificateNotFound, const Color(0xFF7A7BF2)),
                                        _ChartData('Registration', data.registrationCertificateNotFound, const Color(0xFFD64D81)),
                                        _ChartData('All Clear', data.allClearNotFound, const Color(0xFF2FA85C)),
                                        _ChartData('Missing Data', data.weightCertificateNotFound, const Color(0xFFE8D05C)),
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
                                              _ChartData('Fitness', data.fitnessCertificateNotFound, const Color(0xFF5CA0F2)),
                                              _ChartData('Insurance', data.insuranceCertificateNotFound, const Color(0xFF32353A)),
                                              _ChartData('Road Tax', data.roadTaxCertificateNotFound, const Color(0xFF90C25B)),
                                              _ChartData('Permit', data.permitCertificateNotFound, const Color(0xFFE28B5C)),
                                              _ChartData('Puc', data.pucCertificateNotFound, const Color(0xFF7A7BF2)),
                                              _ChartData('Registration', data.registrationCertificateNotFound, const Color(0xFFD64D81)),
                                              _ChartData('All Clear', data.allClearNotFound, const Color(0xFF2FA85C)),
                                              _ChartData('Missing Data', data.weightCertificateNotFound, const Color(0xFFE8D05C)),
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
      hint: Text(hint),
      style: const TextStyle(fontSize: 13, color: Colors.black87),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF0F5D55), size: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFDCECEC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFDCECEC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFF0F5D55)),
        ),
      ),
      items: options
          .map(
            (option) =>
                DropdownMenuItem<String>(value: option, child: Text(option, style: const TextStyle(fontSize: 13))),
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
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
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.85),
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
      return _summaryMetrics;
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
      const Color(0xFF7A7BF2),
      const Color(0xFFED5C7D),
      const Color(0xFF7A7BF2),
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

  Widget _buildComplianceCard(_SummaryMetric metric) {
    IconData getMetricIcon(String title) {
      switch (title.toLowerCase()) {
        case 'fitness':
          return Icons.check_circle_outlined;
        case 'permit':
          return Icons.card_membership_outlined;
        case 'road tax':
          return Icons.currency_rupee_outlined;
        case 'insurance':
          return Icons.shield_outlined;
        case 'puc':
          return Icons.cloud_queue_outlined;
        case 'registration':
          return Icons.description_outlined;
        default:
          return Icons.info_outline;
      }
    }

    final List<_ChartData> chartData = [
      _ChartData('Compliant', metric.compliant, const Color(0xFF2FA85C)),
      _ChartData('Non-Compliant', metric.nonCompliant, const Color(0xFFEF4444)),
      _ChartData('Missing', metric.missing, const Color(0xFFFBBF24)),
    ];

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2ECEC), width: 1.0),
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
                  getMetricIcon(metric.title),
                  color: const Color(0xFF5CA0F2),
                  size: 18,
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
            _buildLegendRow('Compliant', metric.compliant, const Color(0xFF2FA85C)),
            const SizedBox(height: 4),
            _buildLegendRow('Non-Compliant', metric.nonCompliant, const Color(0xFFEF4444)),
            const SizedBox(height: 4),
            _buildLegendRow('${metric.title} Missing Data', metric.missing, const Color(0xFFFBBF24)),
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

  void _exportChart(BuildContext context, String title, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading $title as ${format.toUpperCase()}...'),
        duration: const Duration(seconds: 1),
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

